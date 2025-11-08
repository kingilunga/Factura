// Fichier: lib/database/database_service.dart
// Service SQLite complet pour Factura Vision (Desktop/Web)

import 'dart:io';
import 'package:factura/Modeles/model_clients.dart';
import 'package:factura/Modeles/model_utilisateurs.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:factura/Modeles/model_fournisseurs.dart';
import 'package:factura/Modeles/model_ventes.dart';
import 'package:factura/Modeles/model_taux_change.dart';

// ======================================================================
// --- MODÈLES D'APERÇU SIMPLIFIÉS POUR LE TABLEAU DE BORD ---
// ======================================================================

class AdminStats {
  final double totalChiffreAffaires;
  final int totalVentes;
  final int totalClients;
  final int totalProduits;

  AdminStats({
    this.totalChiffreAffaires = 0.0,
    this.totalVentes = 0,
    this.totalClients = 0,
    this.totalProduits = 0,
  });
}

class VenteRecenteApercu {
  final String dateVente;
  final String produitNom;
  final String vendeurNom;
  final double montantNet;

  VenteRecenteApercu({
    required this.dateVente,
    required this.produitNom,
    required this.vendeurNom,
    required this.montantNet,
  });
}

class ProduitApercu {
  final String nom;
  final double prix;
  final int stock; // Représente la quantité en stock OU la quantité vendue (pour le top vente)
  final String statut;

  ProduitApercu({
    required this.nom,
    required this.prix,
    required this.stock,
    required this.statut,
  });
}

class ClientApercu {
  final String nomClient;
  final String type; // Toujours 'Client' ici, peut être étendu plus tard
  final int totalOperations;

  ClientApercu({
    required this.nomClient,
    required this.type,
    required this.totalOperations,
  });
}

// MODÈLE POUR LES DONNÉES DE GRAPHIQUE (Histogramme)
class VenteTendance {
  final String label; // Ex: '2025-01', 'Lun', '2024'
  final double montant;

  VenteTendance({required this.label, required this.montant});
}

// ======================================================================
// --- DATABASE SERVICE CLASS ---
// ======================================================================

class DatabaseService {
  // --- Singleton ---
  static final DatabaseService instance = DatabaseService._init();
  DatabaseService._init();

  static Database? _database;

  // --- Noms des tables ---
  final String usersTable = 'utilisateurs';
  final String produitsTable = 'produits';
  final String clientsTable = 'clients';
  final String fournisseursTable = 'fournisseurs';
  final String ventesTable = 'ventes';
  final String lignesVenteTable = 'lignes_vente';

  // --- Getter DB ---
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('factura_vision.db');
    return _database!;
  }

  // --- Initialisation DB ---
  Future<Database> _initDB(String filePath) async {
    // Note: getApplicationDocumentsDirectory() fonctionne pour Flutter Desktop/Mobile
    // Pour une version Web, l'implémentation sqflite_common_ffi doit être gérée différemment.
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  // --- Création des tables ---
  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT';
    const realType = 'REAL';
    const integerType = 'INTEGER';
    const textNotNull = 'TEXT NOT NULL';
    const integerNotNull = 'INTEGER NOT NULL';
    const realNotNull = 'REAL NOT NULL';

    // --- Table Utilisateurs ---
    await db.execute('''
      CREATE TABLE $usersTable (
        localId $idType,
        nom $textType,
        postNom $textType,
        prenom $textType,
        telephone $textType,
        email $textNotNull UNIQUE,
        motDePasseHash $textNotNull,
        role $textNotNull,
        serverId $textType,
        syncStatus $textType
      )
    ''');
    await db.execute('''
      CREATE TABLE $produitsTable (
        localId INTEGER PRIMARY KEY AUTOINCREMENT,
        nom TEXT NOT NULL,
        categorie TEXT,
        prix REAL,
        quantiteInitiale INTEGER,
        quantiteActuelle INTEGER,
        imagePath TEXT,
        idTransaction INTEGER DEFAULT 0,
        serverId INTEGER,
        syncStatus TEXT DEFAULT 'pending'
      )
    ''');


    // --- Table Clients ---
    await db.execute('''
      CREATE TABLE $clientsTable (
        localId $idType,
        nomClient $textNotNull,
        telephone $textType,
        adresse $textType,
        serverId $integerType,
        syncStatus $textType
      )
    ''');

    // --- Table Fournisseurs ---
    await db.execute('''
      CREATE TABLE $fournisseursTable (
        localId $idType,
        nomEntreprise $textNotNull,
        nomContact $textNotNull,
        email $textType,
        telephone $textType,
        serverId $integerType,
        syncStatus $textType
      )
    ''');

    // --- Table Ventes (ATTENTION: dateVente DOIT être un ISO String 'YYYY-MM-DD HH:MM:SS.SSS') ---
    await db.execute('''
      CREATE TABLE $ventesTable (
        localId $idType,
        venteId $textNotNull UNIQUE,
        dateVente $textNotNull,
        clientLocalId $integerNotNull,
        vendeurNom $textType,
        totalBrut $realNotNull,
        reductionPercent $realNotNull,
        totalNet $realNotNull,
        statut $textNotNull,
        serverId $textType,
        syncStatus $textType
      )
    ''');

    // --- Table Lignes de Vente ---
    await db.execute('''
      CREATE TABLE $lignesVenteTable (
        localId $idType,
        ligneVenteId $textNotNull UNIQUE,
        venteLocalId $integerNotNull,
        produitLocalId $integerNotNull,
        nomProduit $textNotNull,
        prixVenteUnitaire $realNotNull,
        quantite $integerNotNull,
        sousTotal $realNotNull,
        serverId $textType,
        syncStatus $textType,
        FOREIGN KEY(venteLocalId) REFERENCES $ventesTable(localId) ON DELETE CASCADE
      )
    ''');

    // --- Table TauxChange ---
    await db.execute('''
      CREATE TABLE IF NOT EXISTS taux_change (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        devise TEXT NOT NULL UNIQUE,
        taux REAL NOT NULL,
        dateMiseAJour TEXT NOT NULL
      )
    ''');

    print("✅ Base de données créée et toutes les tables initialisées.");
  }

  // ======================================================================
  // --- NOUVELLE LOGIQUE DE FILTRAGE TEMPOREL ---
  // ======================================================================

  /// Helper pour calculer la date de début de la période
  String _getDateStartOfPeriod(String period) {
    DateTime now = DateTime.now();
    DateTime startDate;

    switch (period) {
      case 'Journalière': // Jour
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'Hebdomadaire': // Semaine (7 derniers jours)
        startDate = now.subtract(const Duration(days: 7));
        break;
      case 'Mensuelle': // Mois
        startDate = DateTime(now.year, now.month, 1);
        break;
      case 'Annuelle': // Année
        startDate = DateTime(now.year, 1, 1);
        break;
      default:
      // Par défaut, nous prenons la dernière semaine
        startDate = now.subtract(const Duration(days: 7));
        break;
    }
    // Formatte la date en chaîne ISO8601 pour la comparaison SQL
    return startDate.toIso8601String();
  }


  // ======================================================================
  // --- FONCTIONS DU TABLEAU DE BORD MISES À JOUR ---
  // ======================================================================

  /// 1. Calcul des Statistiques Globales (KPIs) - MIS À JOUR
  Future<AdminStats> fetchAdminStats({required String period}) async {
    final db = await database;
    final startDateString = _getDateStartOfPeriod(period);

    try {
      final salesResult = await db.rawQuery('''
        SELECT 
          SUM(totalNet) as totalCA,
          COUNT(localId) as totalVentes
        FROM $ventesTable
        WHERE statut = 'validée'
        AND dateVente >= ?
      ''', [startDateString]); // Utilisation de la date de début

      // Les KPIs Client et Produit ne changent pas selon la période (stock/total)
      final clientResult = await db.rawQuery('SELECT COUNT(localId) as totalClients FROM $clientsTable');
      final productResult = await db.rawQuery('SELECT COUNT(localId) as totalProduits FROM $produitsTable');

      final totalCA = (salesResult.first['totalCA'] as num?)?.toDouble() ?? 0.0;
      final totalVentes = (salesResult.first['totalVentes'] as num?)?.toInt() ?? 0;
      final totalClients = (clientResult.first['totalClients'] as num?)?.toInt() ?? 0;
      final totalProduits = (productResult.first['totalProduits'] as num?)?.toInt() ?? 0;

      return AdminStats(
        totalChiffreAffaires: totalCA,
        totalVentes: totalVentes,
        totalClients: totalClients,
        totalProduits: totalProduits,
      );
    } catch (e) {
      print("Erreur lors du calcul des statistiques admin ($period): $e");
      return AdminStats();
    }
  }

  /// 2. Aperçu des Ventes Récentes - MIS À JOUR (filtré par temps)
  Future<List<VenteRecenteApercu>> fetchRecentSales({int limit = 5, String period = 'Hebdomadaire'}) async {
    final db = await database;
    final startDateString = _getDateStartOfPeriod(period);

    final result = await db.rawQuery('''
      SELECT 
        V.dateVente, 
        LV.nomProduit, 
        V.vendeurNom, 
        LV.sousTotal
      FROM $lignesVenteTable LV
      JOIN $ventesTable V ON LV.venteLocalId = V.localId
      WHERE V.statut = 'validée'
      AND V.dateVente >= ?
      ORDER BY V.dateVente DESC
      LIMIT ?
    ''', [startDateString, limit]);

    return result.map((item) => VenteRecenteApercu(
      dateVente: item['dateVente'] as String? ?? 'N/A',
      produitNom: item['nomProduit'] as String? ?? 'Produit Inconnu',
      vendeurNom: item['vendeurNom'] as String? ?? 'Vendeur Inconnu',
      montantNet: (item['sousTotal'] as num?)?.toDouble() ?? 0.0,
    )).toList();
  }

  /// 3. Produits en Stock Critique (Ne nécessite PAS de filtre temporel)
  Future<List<ProduitApercu>> fetchLowStockProducts({int threshold = 5, int limit = 5}) async {
    final db = await database;
    final result = await db.query(
      produitsTable,
      columns: ['nom', 'prix', 'quantiteActuelle'],
      where: 'quantiteActuelle <= ?',
      whereArgs: [threshold],
      limit: limit,
      orderBy: 'quantiteActuelle ASC',
    );

    return result.map((item) {
      final stock = (item['quantiteActuelle'] as num?)?.toInt() ?? 0;
      final statut = stock == 0 ? 'Rupture' : 'Critique';

      return ProduitApercu(
        nom: item['nom'] as String,
        prix: (item['prix'] as num?)?.toDouble() ?? 0.0,
        stock: stock,
        statut: statut,
      );
    }).toList();
  }

  /// 4. Produits les Plus Vendus - MIS À JOUR (filtré par temps)
  Future<List<ProduitApercu>> fetchTopSellingProducts({int limit = 5, String period = 'Hebdomadaire'}) async {
    final db = await database;
    final startDateString = _getDateStartOfPeriod(period);

    // Jointure entre les lignes de vente et les produits pour agréger la quantité vendue
    final result = await db.rawQuery('''
      SELECT 
        P.nom, 
        P.prix, 
        SUM(LV.quantite) as totalQuantiteVendue
      FROM $lignesVenteTable LV
      JOIN $produitsTable P ON LV.produitLocalId = P.localId
      JOIN $ventesTable V ON LV.venteLocalId = V.localId
      WHERE V.dateVente >= ?
      GROUP BY P.localId, P.nom, P.prix
      ORDER BY totalQuantiteVendue DESC
      LIMIT ?
    ''', [startDateString, limit]);

    return result.map((item) => ProduitApercu(
      nom: item['nom'] as String,
      prix: (item['prix'] as num?)?.toDouble() ?? 0.0,
      // On utilise 'stock' pour représenter la quantité vendue dans ce contexte
      stock: (item['totalQuantiteVendue'] as num?)?.toInt() ?? 0,
      statut: 'Top Vente',
    )).toList();
  }


  /// 5. Aperçu des Clients (Top acheteurs) - MIS À JOUR (filtré par temps)
  Future<List<ClientApercu>> fetchClientOverview({int limit = 5, String period = 'Hebdomadaire'}) async {
    final db = await database;
    final startDateString = _getDateStartOfPeriod(period);

    final result = await db.rawQuery('''
      SELECT 
        C.nomClient, 
        COUNT(V.localId) as totalOperations 
      FROM $clientsTable C
      LEFT JOIN $ventesTable V 
      ON C.localId = V.clientLocalId AND V.dateVente >= ?
      GROUP BY C.nomClient
      ORDER BY totalOperations DESC, C.nomClient ASC
      LIMIT ?
    ''', [startDateString, limit]);

    return result.map((item) => ClientApercu(
      nomClient: item['nomClient'] as String,
      type: 'Client',
      totalOperations: (item['totalOperations'] as num?)?.toInt() ?? 0,
    )).toList();
  }


  /// 6. TENDANCES DE VENTES POUR GRAPHIQUE (AGRÉGATION SQL RÉELLE) (Inchangé, car déjà filtré)
  Future<List<VenteTendance>> fetchSalesTrends(String period) async {
    final db = await database;
    String dateGroupFormat;
    String startDateString;

    switch (period) {
      case 'Annuelle':
        dateGroupFormat = '%Y'; // Groupe par Année
        // On prend les 5 dernières années, donc on recule
        startDateString = DateTime(DateTime.now().year - 4, 1, 1).toIso8601String();
        break;
      case 'Mensuelle':
        dateGroupFormat = '%Y-%m'; // Groupe par Année-Mois
        // On prend les 12 derniers mois
        startDateString = DateTime(DateTime.now().year, DateTime.now().month - 11, 1).toIso8601String();
        break;
      case 'Hebdomadaire':
      default:
        dateGroupFormat = '%Y-%m-%d'; // Groupe par Jour (pour avoir la tendance Hebdo)
        // On prend les 7 derniers jours
        startDateString = DateTime.now().subtract(const Duration(days: 6)).toIso8601String().split('T').first;
        break;
    }

    try {
      // Requete SQL utilisant strftime pour grouper la date
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT 
          strftime('$dateGroupFormat', dateVente) AS dateLabel, 
          SUM(totalNet) AS total
        FROM $ventesTable
        WHERE statut = 'validée'
        AND dateVente >= ?
        GROUP BY dateLabel
        ORDER BY dateLabel DESC
      ''', [startDateString]);

      // Note: On utilise result.reversed.toList() pour s'assurer que les dates sont dans l'ordre croissant pour le graphique.
      return result.reversed.map((item) => VenteTendance(
        label: item['dateLabel'] as String,
        montant: (item['total'] as num?)?.toDouble() ?? 0.0,
      )).toList();

    } catch (e) {
      print("Erreur lors de la récupération des tendances de ventes ($period): $e");
      return [];
    }
  }

  // ======================================================================
  // --- FIN DES MISES À JOUR DU TABLEAU DE BORD ---
  // ======================================================================

  // ======================================================================
  // --- MISE À JOUR DU STOCK (Existantes) ---
  // ======================================================================
  Future<void> updateProductStock(int produitLocalId, int quantiteVendue, {Transaction? txn}) async {
    final dbClient = txn ?? await instance.database;

    final rowsAffected = await dbClient.rawUpdate(
      'UPDATE $produitsTable SET quantiteActuelle = quantiteActuelle - ? WHERE localId = ? AND quantiteActuelle >= ?',
      [quantiteVendue, produitLocalId, quantiteVendue],
    );

    if (rowsAffected == 0) {
      final currentStock = await dbClient.rawQuery(
        'SELECT quantiteActuelle FROM $produitsTable WHERE localId = ?',
        [produitLocalId],
      );

      final stock = currentStock.isNotEmpty ? (currentStock.first['quantiteActuelle'] as int?) : null;

      if (stock != null && stock < quantiteVendue) {
        throw Exception("Stock insuffisant. Demande: $quantiteVendue, Disponible: $stock.");
      } else {
        throw Exception("Produit $produitLocalId non trouvé ou stock négatif impossible.");
      }
    }
  }

  // ======================================================================
  // --- CRUD PRODUITS (Existantes) ---
  // ======================================================================
  Future<int> insertProduit(Produit produit) async {
    final db = await instance.database;
    // Si quantiteActuelle n'est pas fournie, on la met à quantiteInitiale
    final produitToInsert = produit.copyWith(
      quantiteActuelle: produit.quantiteActuelle ?? produit.quantiteInitiale,
    );
    return await db.insert(produitsTable, produitToInsert.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateProduit(Produit produit) async {
    final db = await instance.database;
    if (produit.localId == null) throw Exception("Produit sans ID");
    return db.update(produitsTable, produit.toMap(), where: 'localId = ?', whereArgs: [produit.localId]);
  }

  Future<Produit?> getProduitById(int localId) async {
    final db = await instance.database;
    final maps = await db.query(produitsTable, where: 'localId = ?', whereArgs: [localId]);
    if (maps.isNotEmpty) return Produit.fromMap(maps.first);
    return null;
  }

  Future<List<Produit>> getAllProduits() async {
    final db = await instance.database;
    final result = await db.query(produitsTable, orderBy: 'nom ASC');
    return result.map((json) => Produit.fromMap(json)).toList();
  }

  Future<int> deleteProduit(int localId) async {
    final db = await instance.database;
    return await db.delete(produitsTable, where: 'localId = ?', whereArgs: [localId]);
  }

  // ======================================================================
  // --- CRUD UTILISATEURS (Existantes) ---
  // ======================================================================
  Future<int> insertUser(Utilisateur user) async {
    final db = await instance.database;
    return await db.insert(usersTable, user.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Utilisateur?> findUserByEmailAndVerifyPassword(String email, String motDePasseHash) async {
    final db = await instance.database;
    final maps = await db.query(usersTable, columns: Utilisateur.columns, where: 'email = ? AND motDePasseHash = ?', whereArgs: [email, motDePasseHash]);
    if (maps.isNotEmpty) return Utilisateur.fromMap(maps.first);
    return null;
  }

  // Renommée de getUtilisateurs() pour être cohérent avec le dashboard
  Future<List<Utilisateur>> fetchAllUsers() async {
    final db = await instance.database;
    final result = await db.query(usersTable, orderBy: 'nom ASC');
    return result.map((json) => Utilisateur.fromMap(json)).toList();
  }

  // Ancien nom pour compatibilité si nécessaire
  Future<List<Utilisateur>> getUtilisateurs() => fetchAllUsers();


  Future<int> updateUtilisateur(Utilisateur updatedUser) async {
    final db = await instance.database;
    return db.update(usersTable, updatedUser.toMap(), where: 'localId = ?', whereArgs: [updatedUser.localId]);
  }

  Future<int> deleteUser(int localId) async {
    final db = await instance.database;
    return await db.delete(usersTable, where: 'localId = ?', whereArgs: [localId]);
  }

  // ======================================================================
  // --- CRUD CLIENTS (Existantes) ---
  // ======================================================================
  Future<int> insertClient(Client client) async {
    final db = await instance.database;
    return await db.insert(clientsTable, client.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Client>> getAllClients() async {
    final db = await instance.database;
    final result = await db.query(clientsTable, orderBy: 'nomClient ASC');
    return result.map((json) => Client.fromMap(json)).toList();
  }

  Future<Client?> getClientById(int localId) async {
    final db = await instance.database;
    final maps = await db.query(clientsTable, where: 'localId = ?', whereArgs: [localId]);
    if (maps.isNotEmpty) return Client.fromMap(maps.first);
    return null;
  }

  Future<int> updateClient(Client client) async {
    final db = await instance.database;
    if (client.localId == null) throw Exception("Client sans ID");
    return db.update(clientsTable, client.toMap(), where: 'localId = ?', whereArgs: [client.localId]);
  }

  Future<int> deleteClient(int localId) async {
    final db = await instance.database;
    return await db.delete(clientsTable, where: 'localId = ?', whereArgs: [localId]);
  }

  // ======================================================================
  // --- CRUD FOURNISSEURS (Existantes) ---
  // ======================================================================
  Future<int> insertFournisseur(Fournisseur fournisseur) async {
    final db = await instance.database;
    return await db.insert(fournisseursTable, fournisseur.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Fournisseur>> getAllFournisseurs() async {
    final db = await instance.database;
    final result = await db.query(fournisseursTable, orderBy: 'nomEntreprise ASC');
    return result.map((json) => Fournisseur.fromMap(json)).toList();
  }

  Future<int> updateFournisseur(Fournisseur fournisseur) async {
    final db = await instance.database;
    if (fournisseur.localId == null) throw Exception("Fournisseur sans ID");
    return db.update(fournisseursTable, fournisseur.toMap(), where: 'localId = ?', whereArgs: [fournisseur.localId]);
  }

  Future<int> deleteFournisseur(int localId) async {
    final db = await instance.database;
    return await db.delete(fournisseursTable, where: 'localId = ?', whereArgs: [localId]);
  }

  // ======================================================================
  // --- CRUD VENTES (Existantes) ---
  // ======================================================================
  Future<int> insertVenteTransaction({
    required Vente vente,
    required List<LigneVente> lignesVente,
  }) async {
    final db = await instance.database;
    int venteLocalId = 0;

    await db.transaction((txn) async {
      venteLocalId = await txn.insert(ventesTable, vente.toMap());

      for (var ligne in lignesVente) {
        final ligneToInsert = LigneVente(
          ligneVenteId: ligne.ligneVenteId,
          venteLocalId: venteLocalId,
          produitLocalId: ligne.produitLocalId,
          nomProduit: ligne.nomProduit,
          prixVenteUnitaire: ligne.prixVenteUnitaire,
          quantite: ligne.quantite,
          sousTotal: ligne.sousTotal,
        );

        await txn.insert(lignesVenteTable, ligneToInsert.toMap());
        await updateProductStock(ligne.produitLocalId, ligne.quantite, txn: txn);
      }
    });

    return venteLocalId;
  }

  Future<Map<String, dynamic>?> getVenteDetails(int venteLocalId) async {
    final db = await instance.database;
    final venteMap = await db.query(ventesTable, where: 'localId = ?', whereArgs: [venteLocalId]);
    if (venteMap.isEmpty) return null;
    final lignesMap = await db.query(lignesVenteTable, where: 'venteLocalId = ?', whereArgs: [venteLocalId]);
    return {
      'vente': Vente.fromMap(venteMap.first),
      'lignes': lignesMap.map((map) => LigneVente.fromMap(map)).toList(),
    };
  }

  Future<List<Vente>> getAllVentes() async {
    final db = await instance.database;
    final result = await db.query(ventesTable, orderBy: 'dateVente DESC');
    return result.map((json) => Vente.fromMap(json)).toList();
  }

  Future<List<Vente>> getVentesByDate(DateTime date) async {
    final db = await database;
    final dateStr = date.toIso8601String().split('T').first;
    final result = await db.query(
      ventesTable,
      where: 'dateVente LIKE ?',
      whereArgs: ['$dateStr%'],
      orderBy: 'dateVente DESC',
    );
    return result.map((json) => Vente.fromMap(json)).toList();
  }

  Future<void> deleteVente(int localId) async {
    final db = await database;
    await db.delete(lignesVenteTable, where: 'venteLocalId = ?', whereArgs: [localId]);
    await db.delete(ventesTable, where: 'localId = ?', whereArgs: [localId]);
  }

  // ======================================================================
  // --- Outils (Existantes) ---
  // ======================================================================

  /// Calcule le nombre total de ventes enregistrées dans la base de données.
  Future<int> getTotalVentesCount() async {
    final db = await instance.database;
    // Utilisation de la table des ventes (ventesTable) pour le comptage.
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $ventesTable')
    );
    // Retourne le nombre trouvé, ou 0 si la table est vide.
    return count ?? 0;
  }

  Future<void> clearTable(String tableName) async {
    final db = await instance.database;
    await db.delete(tableName);
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }

  /// Calcule la quantité totale vendue pour un produit donné.
  Future<int> getStockVendu(int produitLocalId) async {
    final db = await database;

    const colQuantiteVendue = 'quantite';
    const colProduitLocalId = 'produitLocalId';

    try {
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT SUM($colQuantiteVendue) as totalVendu
        FROM $lignesVenteTable 
        WHERE $colProduitLocalId = ?
      ''', [produitLocalId]);

      if (result.isNotEmpty && result.first['totalVendu'] != null) {
        return (result.first['totalVendu'] as num).toInt();
      }

      return 0;

    } catch (e) {
      print("Erreur SQL lors du calcul du stock vendu pour produit $produitLocalId: $e");
      return 0;
    }
  }
  // Récupère toutes les lignes d'une vente via son localId
  Future<List<LigneVente>> getLignesByVente(int venteLocalId) async {
    final dbClient = await database;
    final result = await dbClient.query(
      lignesVenteTable, // Correction du nom de la table
      where: 'venteLocalId = ?',
      whereArgs: [venteLocalId],
    );

    return result.map((map) => LigneVente.fromMap(map)).toList();
  }
  // --- Récupérer toutes les ventes d'un vendeur précis ---
  Future<List<Vente>> getVentesByVendeur(int vendeurId) async {
    final db = await database;
    final maps = await db.query(
      'ventes',
      where: 'vendeurLocalId = ?',
      whereArgs: [vendeurId],
    );

    return maps.map((map) => Vente.fromMap(map)).toList();
  }

// --- Produits les plus vendus par ce vendeur ---
  Future<List<Map<String, dynamic>>> fetchTopProductsByVendeur(int vendeurId) async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT p.nom AS produitNom, SUM(vp.quantiteVendue) AS totalVendu
    FROM ventes_produits vp
    JOIN produits p ON vp.produitLocalId = p.localId
    JOIN ventes v ON vp.venteLocalId = v.localId
    WHERE v.vendeurLocalId = ?
    GROUP BY p.nom
    ORDER BY totalVendu DESC
    LIMIT 5
  ''', [vendeurId]);

    return result;
  }

// --- Clients les plus fidèles (Top 5) ---
  Future<List<Map<String, dynamic>>> fetchTopClientsByVendeur(int vendeurId) async {
    final db = await database;

    final result = await db.rawQuery('''
    SELECT c.nom AS clientNom, COUNT(v.localId) AS achats
    FROM ventes v
    JOIN clients c ON v.clientLocalId = c.localId
    WHERE v.vendeurLocalId = ?
    GROUP BY c.nom
    ORDER BY achats DESC
    LIMIT 5
  ''', [vendeurId]);

    return result;
  }
  // --- Produits critiques (stock faible) ---
  Future<List<Map<String, dynamic>>> fetchCriticalStock({int limit = 5}) async {
    final db = await database;

    final result = await db.query(
      'produits',
      columns: ['nom', 'quantiteActuelle', 'quantiteInitiale', 'categorie'],
      where: 'quantiteActuelle <= ?',
      whereArgs: [10],
      orderBy: 'quantiteActuelle ASC',
      limit: limit,
    );

    return result;
  }
  // ======================================================================
// --- MÉTHODES TOP PRODUITS / TOP CLIENTS POUR VENDOR (filtrables) ---
// ======================================================================

  /// Top produits vendus, optionnellement filtrés par vendeur
  Future<List<ProduitApercu>> fetchTopProducts({int? vendeurId, int limit = 5}) async {
    final db = await database;

    String query = '''
    SELECT 
      P.nom, 
      P.prix, 
      SUM(LV.quantite) as totalQuantiteVendue
    FROM $lignesVenteTable LV
    JOIN $produitsTable P ON LV.produitLocalId = P.localId
    JOIN $ventesTable V ON LV.venteLocalId = V.localId
  ''';

    List<dynamic> args = [];
    if (vendeurId != null) {
      query += ' WHERE V.vendeurLocalId = ?';
      args.add(vendeurId);
    }

    query += ' GROUP BY P.localId, P.nom, P.prix ORDER BY totalQuantiteVendue DESC LIMIT ?';
    args.add(limit);

    final result = await db.rawQuery(query, args);

    return result.map((item) => ProduitApercu(
      nom: item['nom'] as String,
      prix: (item['prix'] as num?)?.toDouble() ?? 0.0,
      stock: (item['totalQuantiteVendue'] as num?)?.toInt() ?? 0,
      statut: 'Top Vente',
    )).toList();
  }

  /// Top clients, optionnellement filtrés par vendeur
  Future<List<ClientApercu>> fetchTopClients({int? vendeurId, int limit = 5}) async {
    final db = await database;

    String query = '''
    SELECT 
      C.nomClient, 
      COUNT(V.localId) as totalOperations
    FROM $clientsTable C
    LEFT JOIN $ventesTable V ON C.localId = V.clientLocalId
  ''';

    List<dynamic> args = [];
    if (vendeurId != null) {
      query += ' WHERE V.vendeurLocalId = ?';
      args.add(vendeurId);
    }

    query += ' GROUP BY C.nomClient ORDER BY totalOperations DESC, C.nomClient ASC LIMIT ?';
    args.add(limit);

    final result = await db.rawQuery(query, args);

    return result.map((item) => ClientApercu(
      nomClient: item['nomClient'] as String,
      type: 'Client',
      totalOperations: (item['totalOperations'] as num?)?.toInt() ?? 0,
    )).toList();
  }
  // Ajouter ou mettre à jour le taux
  Future<void> upsertTauxChange(String devise, double taux) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.rawInsert('''
    INSERT OR REPLACE INTO taux_change (id, devise, taux, dateMiseAJour)
    VALUES (
      COALESCE((SELECT id FROM taux_change WHERE devise = ?), NULL),
      ?, ?, ?
    )
  ''', [devise, devise, taux, now]);
  }

// Récupérer le dernier taux
  Future<double> fetchTauxChange(String devise) async {
    final db = await database;
    final result = await db.query(
      'taux_change',
      where: 'devise = ?',
      whereArgs: [devise],
      orderBy: 'dateMiseAJour DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return (result.first['taux'] as num).toDouble();
    }

    // Valeur par défaut selon la devise
    final defaultTaux = {
      'USD': 2800.0,
      'EUR': 3000.0,
      'CDF': 1.0,
      'FCFA': 1.0,
    };

    return defaultTaux[devise] ?? 1.0;
  }
  /// Récupère le dernier taux de change USD -> CDF
  Future<double> fetchExchangeRate() async {
    final db = await database;
    final result = await db.query(
      'taux_change',
      where: 'devise = ?',
      whereArgs: ['USD'],
      orderBy: 'dateMiseAJour DESC',
      limit: 1,
    );

    if (result.isNotEmpty) {
      return (result.first['taux'] as num).toDouble();
    }

    // Valeur par défaut si aucun taux trouvé
    return 2800.0;
  }
  // Ajoute ceci dans la section CRUD Utilisateurs
  Future<List<Utilisateur>> getAllUtilisateurs() async {
    return await fetchAllUsers();
  }

  // 📁 database_service.dart

  Future<void> updatePassword(int localId, String newPassword) async {
    final db = await instance.database;
    await db.update(
      usersTable, // ⚠️ nom de ta table utilisateurs
      {
        'motDePasseHash': newPassword,
      },
      where: 'localId = ?',
      whereArgs: [localId],
    );
  }
  Future<String> getDatabasePath() async {
    final db = await database;
    return db.path;
  }
  Future<int> getTableCount() async {
    final db = await database;
    final result = await db.rawQuery("SELECT count(*) as count FROM sqlite_master WHERE type='table'");
    return Sqflite.firstIntValue(result) ?? 0;
  }
  Future<void> reinitializeDatabase() async {
    await close();
    await database; // cela recrée la base au prochain accès
  }
  Future<void> clearAllExceptUsers() async {
    final db = await database;

    // Récupérer toutes les tables
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
    );

    for (var table in tables) {
      final tableName = table['name'] as String;

      // Ne pas supprimer les utilisateurs
      if (tableName != usersTable) { // Utiliser la variable de classe
        await db.delete(tableName);
      }
    }
  }

  Future<void> resetDatabase() async {
    final db = await database; // ta référence SQLite
    await db.execute("DELETE FROM produits");
    await db.execute("DELETE FROM clients");
    await db.execute("DELETE FROM ventes");
    // répéter pour toutes les tables
  }
  /// Met à jour le mot de passe du SuperAdmin
  Future<void> updateSuperAdminPassword(String newPassword) async {
    final db = await instance.database; // récupère l'instance SQLite ouverte
    await db.update(
      'superadmin',                  // nom de la table
      {'password': newPassword},     // nouvelle valeur
      where: 'username = ?',         // condition
      whereArgs: ['SuperAdmin'],     // valeur pour la condition
    );
  }

}
