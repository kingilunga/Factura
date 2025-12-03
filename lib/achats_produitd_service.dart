// DANS VOTRE FICHIER achats_produit_service.dart

import 'package:factura/Modeles/model_achat_produits.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:factura/database/database_service.dart';
import 'package:sqflite/sqflite.dart';


// =================================================================
// --- SERVICE D'ACHAT TRANSACTIONNEL (Anti-Doublon et Stock) ---
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

  // --- LOGIQUE TRANSACTIONNELLE PRINCIPALE : ENREGISTREMENT ET MISE À JOUR DU STOCK ---
  Future<int> insertAchatTransaction({required AchatsProduit achat}) async {
    final db = await _dbService.database;
    int produitLocalId = achat.produitLocalId;

    return await db.transaction((txn) async {
      // ÉTAPE 1 : Trouver ou créer l'ID final du produit (anti-doublon)
      // ⭐️ Ceci utilise la nouvelle logique de recherche par nom
      produitLocalId = await _getOrCreateAndUpdatedProduitId(txn, achat, produitLocalId);

      final achatToInsert = achat.copyWith(produitLocalId: produitLocalId);

      // ÉTAPE 2 : ENREGISTREMENT DE L'ACHAT (Historique)
      final achatLocalId = await txn.insert(
        _achatsTable,
        achatToInsert.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // ÉTAPE 3 : MISE À JOUR DU STOCK (pour l'ID final trouvé)
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
}