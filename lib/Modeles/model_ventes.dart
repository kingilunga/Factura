// ======================================================================
// --- Modèle Vente (Header de la Facture) ---979899100101102103104105106107108109110111112113114115116117118119120121$0
// ======================================================================

class Vente {
  final int? localId;
  final String venteId;
  final String dateVente;
  final int clientLocalId;
  final String? vendeurNom;

  final String? modePaiement;
  final String? deviseTransaction;
  final double? tauxDeChange;

  final double totalBrut;
  final double reductionPercent;
  final double totalNet;
  final String statut;

  final double? montantEncaisse; // Montant réellement payé

  // Champs de synchronisation
  final String? serverId;
  final String? syncStatus;


  // Calcule le montant monétaire de la réduction à la volée.
  double get montantReduction {
    if (reductionPercent == 0 || totalBrut == 0) return 0.0;
    return totalBrut * (reductionPercent / 100.0);
  }


  Vente({
    this.localId,
    required this.venteId,
    required this.dateVente,
    required this.clientLocalId,
    this.vendeurNom,
    this.modePaiement,
    this.deviseTransaction,
    this.tauxDeChange,
    required this.totalBrut,
    required this.reductionPercent,
    required this.totalNet,
    required this.statut,
    this.montantEncaisse,
    this.serverId,
    this.syncStatus = 'pending',
  });

  // Convertit l'objet Vente en Map (pour l'insertion dans SQLite)
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'venteId': venteId,
      'dateVente': dateVente,
      'clientLocalId': clientLocalId,
      'vendeurNom': vendeurNom,
      'modePaiement': modePaiement,
      'deviseTransaction': deviseTransaction,
      'tauxDeChange': tauxDeChange,
      'totalBrut': totalBrut,
      'reductionPercent': reductionPercent,
      'totalNet': totalNet,
      'statut': statut,
      // Utilisation de ?? 0.0 pour garantir que ce n'est pas NULL lors de l'écriture
      'montantEncaisse': montantEncaisse ?? 0.0,
      'serverId': serverId,
      'syncStatus': syncStatus,
    };
  }

  // Crée un objet Vente à partir d'un Map (récupération depuis SQLite)
  factory Vente.fromMap(Map<String, dynamic> map) {
    // ⭐️ FONCTION DE SÉCURITÉ CONTRE LES ERREURS DE TYPE 'STRING'
    double _safeToDouble(dynamic value, {double defaultValue = 0.0}) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) {
        // Tente la conversion de la String en double, sinon retourne la valeur par défaut.
        return double.tryParse(value) ?? defaultValue;
      }
      return defaultValue; // Fallback général
    }

    // ⭐️ FONCTION DE SÉCURITÉ POUR LES CHAMPS NULLABLES
    double? _safeToNullableDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      if (value is String) {
        // Tente la conversion, sinon retourne null.
        return double.tryParse(value);
      }
      return null; // Fallback général
    }

    return Vente(
      localId: map['localId'] as int?,
      venteId: map['venteId'] as String,
      dateVente: map['dateVente'] as String,
      clientLocalId: map['clientLocalId'] as int,
      vendeurNom: map['vendeurNom'] as String?,
      modePaiement: map['modePaiement'] as String?,
      deviseTransaction: map['deviseTransaction'] as String?,

      // Utilisation des fonctions sécurisées pour tous les doubles
      tauxDeChange: _safeToNullableDouble(map['tauxDeChange']),

      // Pour les champs non-nullable (requis), on utilise _safeToDouble
      totalBrut: _safeToDouble(map['totalBrut']),
      reductionPercent: _safeToDouble(map['reductionPercent']),
      totalNet: _safeToDouble(map['totalNet']),
      statut: map['statut'] as String,

      // Correction de l'erreur ici (utilise _safeToNullableDouble)
      montantEncaisse: _safeToNullableDouble(map['montantEncaisse']),

      serverId: map['serverId'] as String?,
      syncStatus: map['syncStatus'] as String?,
    );
  }

  // Ajout de la méthode copyWith pour Vente
  Vente copyWith({
    int? localId,
    String? venteId,
    String? dateVente,
    int? clientLocalId,
    String? vendeurNom,
    String? modePaiement,
    String? deviseTransaction,
    double? tauxDeChange,
    double? totalBrut,
    double? reductionPercent,
    double? totalNet,
    String? statut,
    double? montantEncaisse,
    String? serverId,
    String? syncStatus,
  }) {
    return Vente(
      localId: localId ?? this.localId,
      venteId: venteId ?? this.venteId,
      dateVente: dateVente ?? this.dateVente,
      clientLocalId: clientLocalId ?? this.clientLocalId,
      vendeurNom: vendeurNom ?? this.vendeurNom,
      modePaiement: modePaiement ?? this.modePaiement,
      deviseTransaction: deviseTransaction ?? this.deviseTransaction,
      tauxDeChange: tauxDeChange ?? this.tauxDeChange,
      totalBrut: totalBrut ?? this.totalBrut,
      reductionPercent: reductionPercent ?? this.reductionPercent,
      totalNet: totalNet ?? this.totalNet,
      statut: statut ?? this.statut,
      montantEncaisse: montantEncaisse ?? this.montantEncaisse,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

// ======================================================================
// --- Modèle LigneVente (Détail du Produit Vendu) ---
// Note: Pas de changement, mais on sécurise aussi la lecture des doubles
// ======================================================================

class LigneVente {
  final int? localId; // ID local SQLite (PRIMARY KEY)
  final String ligneVenteId; // ID unique pour la synchronisation
  final int venteLocalId; // Clé étrangère: Référence au header Vente
  final int produitLocalId; // Référence au produit vendu
  final String nomProduit; // Nom du produit au moment de la vente (pour historique)
  final double prixVenteUnitaire;
  final int quantite;
  final double sousTotal; // Prix total de cette ligne (prix * quantité)

  // Champs de synchronisation
  final String? serverId;
  final String? syncStatus;

  LigneVente({
    this.localId,
    required this.ligneVenteId,
    required this.venteLocalId,
    required this.produitLocalId,
    required this.nomProduit,
    required this.prixVenteUnitaire,
    required this.quantite,
    required this.sousTotal,
    this.serverId,
    this.syncStatus = 'pending',
  });

  // Convertit l'objet LigneVente en Map
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'ligneVenteId': ligneVenteId,
      'venteLocalId': venteLocalId,
      'produitLocalId': produitLocalId,
      'nomProduit': nomProduit,
      'prixVenteUnitaire': prixVenteUnitaire,
      'quantite': quantite,
      'sousTotal': sousTotal,
      'serverId': serverId,
      'syncStatus': syncStatus,
    };
  }

  // Crée un objet LigneVente à partir d'un Map
  factory LigneVente.fromMap(Map<String, dynamic> map) {
    // Fonction de sécurité locale
    double _safeToDouble(dynamic value, {double defaultValue = 0.0}) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      if (value is String) {
        return double.tryParse(value) ?? defaultValue;
      }
      return defaultValue;
    }

    return LigneVente(
      localId: map['localId'] as int?,
      ligneVenteId: map['ligneVenteId'] as String,
      venteLocalId: map['venteLocalId'] as int,
      produitLocalId: map['produitLocalId'] as int,
      nomProduit: map['nomProduit'] as String,
      // Application de la lecture sécurisée aux doubles
      prixVenteUnitaire: _safeToDouble(map['prixVenteUnitaire']),
      quantite: map['quantite'] as int, // Ints sont généralement sûrs
      sousTotal: _safeToDouble(map['sousTotal']),
      serverId: map['serverId'] as String?,
      syncStatus: map['syncStatus'] as String?,
    );
  }

  // Ajout de la méthode copyWith pour LigneVente
  LigneVente copyWith({
    int? localId,
    String? ligneVenteId,
    int? venteLocalId,
    int? produitLocalId,
    String? nomProduit,
    double? prixVenteUnitaire,
    int? quantite,
    double? sousTotal,
    String? serverId,
    String? syncStatus,
  }) {
    return LigneVente(
      localId: localId ?? this.localId,
      ligneVenteId: ligneVenteId ?? this.ligneVenteId,
      venteLocalId: venteLocalId ?? this.venteLocalId,
      produitLocalId: produitLocalId ?? this.produitLocalId,
      nomProduit: nomProduit ?? this.nomProduit,
      prixVenteUnitaire: prixVenteUnitaire ?? this.prixVenteUnitaire,
      quantite: quantite ?? this.quantite,
      sousTotal: sousTotal ?? this.sousTotal,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}