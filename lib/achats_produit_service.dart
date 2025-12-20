// Fichier: achats_produit_service.dart

import 'package:factura/Modeles/model_achat_produits.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:factura/database/database_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:sqflite/sqflite.dart';


// =================================================================
// --- SERVICE D'ACHAT TRANSACTIONNEL (Anti-Doublon, Stock, Edition) ---
// =================================================================
class AchatsProduitService {
  static final AchatsProduitService instance = AchatsProduitService._init();
  AchatsProduitService._init();

  final DatabaseService _dbService = DatabaseService.instance;
  static const String _produitsTable = 'produits';
  static const String _achatsTable = 'achats_produit';

  // --- LOGIQUE ANTI-DOUBLON : TROUVER OU CRÉER L'ID DU PRODUIT ---
  Future<int> _getOrCreateAndUpdatedProduitId(
      Transaction txn,
      AchatsProduit achat,
      int existingProduitLocalId) async {

    if (existingProduitLocalId > 0) {
      // 1. ID SÉLECTIONNÉ PAR AUTOCOMPLÉTION : On confirme son existence
      final existMap = await txn.query(_produitsTable,
          columns: ['localId'],
          where: 'localId = ?',
          whereArgs: [existingProduitLocalId]
      );
      if (existMap.isEmpty) {
        throw Exception("Le produit sélectionné (ID $existingProduitLocalId) n'existe plus.");
      }
      return existingProduitLocalId;

    } else {
      // 2. ID = 0 : Saisie manuelle ou nouveau. On cherche par nom (insensible à la casse)
      final List<Map<String, dynamic>> existing = await txn.query(
        _produitsTable,
        where: 'LOWER(nom) = ?',
        whereArgs: [achat.nomProduit.trim().toLowerCase()],
      );

      if (existing.isNotEmpty) {
        // CAS A : LE PRODUIT EXISTE (on a trouvé un doublon par le nom)
        return existing.first['localId'] as int;

      } else {
        // CAS B : VRAIMENT NOUVEAU PRODUIT
        final nouveauProduit = Produit(
          nom: achat.nomProduit,
          categorie: achat.type,
          prix: achat.prixVente,
          quantiteActuelle: 0,
          quantiteInitiale: 0,
          prixAchatUSD: (achat.devise == 'USD') ? achat.prixAchatUnitaire : null,
          fraisAchatUSD: (achat.devise == 'USD') ? achat.fraisAchatUnitaire : null,
          // Laissez les autres champs (imagePath, serverId, etc.) à null ou à leur valeur par défaut
        );
        // Insertion et récupération de l'ID
        return await txn.insert(
          _produitsTable,
          nouveauProduit.toMap(),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );
      }
    }
  }
  // =================================================================
  // --- MÉTHODE 1 : ENREGISTREMENT D'UN NOUVEL ACHAT ---
  // =================================================================
  Future<int> insertAchatTransaction({required AchatsProduit achat}) async {
    final db = await _dbService.database;
    int produitLocalId = achat.produitLocalId;

    return await db.transaction((txn) async {
      // ÉTAPE 1 : Trouver ou créer l'ID final du produit (anti-doublon)
      produitLocalId = await _getOrCreateAndUpdatedProduitId(txn, achat, produitLocalId);

      final achatToInsert = achat.copyWith(produitLocalId: produitLocalId);

      // ÉTAPE 2 : ENREGISTREMENT DE L'ACHAT (Historique)
      final achatLocalId = await txn.insert(
        _achatsTable,
        achatToInsert.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // ÉTAPE 3 : MISE À JOUR DU STOCK (pour l'ID final trouvé)
      // Incrémentation de quantiteActuelle ET quantiteInitiale
      await txn.rawUpdate(
        '''
        UPDATE $_produitsTable 
        SET quantiteActuelle = quantiteActuelle + ?,
            quantiteInitiale = quantiteInitiale + ?, 
            prix = ?,
            prixAchatUSD = ?,
            fraisAchatUSD = ? 
        WHERE localId = ?
        ''',
        [
          achat.quantiteAchetee, // quantiteActuelle
          achat.quantiteAchetee, // quantiteInitiale
          achat.prixVente,
          (achat.devise == 'USD') ? achat.prixAchatUnitaire : null,
          (achat.devise == 'USD') ? achat.fraisAchatUnitaire : null,
          produitLocalId
        ],
      );

      return achatLocalId;
    });
  }

  // =================================================================
// --- MÉTHODE 2 : MODIFICATION D'UN ACHAT EXISTANT (CORRIGÉE) ---
// =================================================================
  /// Gère la modification d'un achat existant et ajuste le stock du produit dans une transaction.
  Future<void> modifierAchatEtAjusterStock({
    required int achatId,
    required int produitId,
    required String devise,
    required int ancienneQuantite,
    required int nouvelleQuantite,
    required Map<String, dynamic> nouvellesDonneesAchat, // Contient les prix, la marge et les dates
  }) async {
    final db = await _dbService.database;
    final produitLocalId = produitId;

    // Calcul de l'ajustement net du stock
    final int ajustementQuantite = nouvelleQuantite - ancienneQuantite;

    // Récupération des données nécessaires pour la mise à jour du produit
    final double nouveauPrixVente = nouvellesDonneesAchat['prixVente'] as double;
    final double prixAchatUnitaire = nouvellesDonneesAchat['prixAchatUnitaire'] as double;
    final double fraisAchatUnitaire = nouvellesDonneesAchat['fraisAchatUnitaire'] as double;

    if (produitLocalId <= 0 || achatId <= 0) {
      throw Exception("IDs de Produit ou d'Achat non valides pour la modification.");
    }

    // Début de la transaction
    return await db.transaction((txn) async {

      // 1.1 Vérification de la disponibilité du stock si la quantité diminue (ajustementQuantite < 0)
      // On vérifie que le Stock Dispo après la modification reste >= 0.
      if (ajustementQuantite < 0) {
        final stockActuelMap = await txn.query(
          _produitsTable,
          columns: ['quantiteActuelle'],
          where: 'localId = ?',
          whereArgs: [produitLocalId],
        );

        if (stockActuelMap.isEmpty) {
          throw Exception("Produit (ID $produitLocalId) introuvable pour la vérification de stock.");
        }

        final int stockActuel = stockActuelMap.first['quantiteActuelle'] as int;
        final int stockApresRetrait = stockActuel + ajustementQuantite; // 'ajustementQuantite' est négatif ici

        if (stockApresRetrait < 0) {
          throw Exception("Erreur: Le retrait de ${ancienneQuantite - nouvelleQuantite} unités rendrait le stock négatif ($stockApresRetrait).");
        }
      }

      // 2. MISE À JOUR DU PRODUIT (FICHE STOCK)
      // ⭐️ CORRECTION CONFIRMÉE : qtéActuelle ET qtéInitiale sont ajustées ensemble ⭐️
      await txn.rawUpdate(
        '''
      UPDATE $_produitsTable 
      SET quantiteInitiale = quantiteInitiale + ?, 
          quantiteActuelle = quantiteActuelle + ?, 
          prix = ?,
          prixAchatUSD = ?,
          fraisAchatUSD = ? 
      WHERE localId = ?
      ''',
        [
          ajustementQuantite, // Ajout/Retrait sur la quantité Initiale (Stock Reçu)
          ajustementQuantite, // Ajout/Retrait sur la quantité Actuelle (Stock Dispo)
          nouveauPrixVente,
          (devise == 'USD') ? prixAchatUnitaire : null,
          (devise == 'USD') ? fraisAchatUnitaire : null,
          produitLocalId
        ],
      );

      // 3. MISE À JOUR DE LA LIGNE D'ACHAT (HISTORIQUE)
      final updateCount = await txn.update(
        'achats_produit', // ️ CORRECTION : Utilisation du nom littéral de la table
        nouvellesDonneesAchat,
        where: 'localId = ?',
        whereArgs: [achatId],
      );

      if (updateCount != 1) {
        throw Exception("Erreur: Impossible de mettre à jour la transaction d'achat (ID $achatId).");
      }
    }); // Fin de la transaction
  }

  Future<void> updateProduitFiche({
    required int produitId,
    required Map<String, dynamic> nouvellesDonnees,
  }) async {
    final db = await _dbService.database;
    // Prépare les données pour la mise à jour.
    final Map<String, dynamic> dataToUpdate = {
      'nom': nouvellesDonnees['nom'],
      'categorie': nouvellesDonnees['categorie'],
      // Si vous aviez d'autres champs de fiche produit à modifier ici (imagePath, etc.), vous les ajouteriez là
    };

    // Exécute la mise à jour
    final updateCount = await db.update(
      _produitsTable,
      dataToUpdate,
      where: 'localId = ?',
      whereArgs: [produitId],
    );

    if (updateCount != 1) {
      // Il est critique que l'on ait mis à jour exactement un produit.
      throw Exception("Erreur: Impossible de trouver ou de mettre à jour la fiche produit (ID $produitId).");
    }
  }

  Future<bool> produitADejaEteVendu(int produitId) async {
    final db = await _dbService.database;
    // ⚠️ TRÈS IMPORTANT : Vérifiez que 'ventes_produit' est le nom exact de votre table de ventes
    const String ventesTable = 'lignes_vente';

    try {
      final List<Map<String, dynamic>> result = await db.query(
        ventesTable,
        columns: ['COUNT(*)'],
        where: 'produitLocalId = ?',
        whereArgs: [produitId],
      );

      final int count = Sqflite.firstIntValue(result) ?? 0;
      return count > 0;
    } catch (e) {
      // Mesure de sécurité en cas d'erreur (ex: table non encore créée)
      debugPrint("Erreur lors de la vérification de vente: $e");
      return false;
    }
  }
}