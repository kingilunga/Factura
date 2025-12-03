// Fichier: lib/database/model_proforma.dart

// Note : Structure identique à Vente, mais séparée pour éviter la confusion en DB.

class ProForma {
  final int? localId;
  final String proFormaId; // Ex: PF-001
  final String dateCreation;
  final int clientLocalId;
  final String? vendeurNom;
  final String? deviseTransaction;
  final double? tauxDeChange;
  final double totalBrut;
  final double reductionPercent;
  final double totalNet;
  final String? modePaiement; // Optionnel

  final String? serverId;
  final String? syncStatus;

  ProForma({
    this.localId,
    required this.proFormaId,
    required this.dateCreation,
    required this.clientLocalId,
    this.vendeurNom,
    this.deviseTransaction,
    this.tauxDeChange,
    required this.totalBrut,
    required this.reductionPercent,
    required this.totalNet,
    this.modePaiement,
    this.serverId,
    this.syncStatus = 'pending',
  });

  // Convertit l'objet ProForma en Map
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'proFormaId': proFormaId,
      'dateCreation': dateCreation,
      'clientLocalId': clientLocalId,
      'vendeurNom': vendeurNom,
      'deviseTransaction': deviseTransaction,
      'tauxDeChange': tauxDeChange,
      'totalBrut': totalBrut,
      'reductionPercent': reductionPercent,
      'totalNet': totalNet,
      'modePaiement': modePaiement,
      'serverId': serverId,
      'syncStatus': syncStatus,
    };
  }

  // Crée un objet ProForma à partir d'un Map
  factory ProForma.fromMap(Map<String, dynamic> map) {
    return ProForma(
      localId: map['localId'] as int?,
      proFormaId: map['proFormaId'] as String,
      dateCreation: map['dateCreation'] as String,
      clientLocalId: map['clientLocalId'] as int,
      vendeurNom: map['vendeurNom'] as String?,
      deviseTransaction: map['deviseTransaction'] as String?,
      tauxDeChange: (map['tauxDeChange'] as num?)?.toDouble(),
      totalBrut: (map['totalBrut'] as num).toDouble(),
      reductionPercent: (map['reductionPercent'] as num).toDouble(),
      totalNet: (map['totalNet'] as num).toDouble(),
      modePaiement: map['modePaiement'] as String?,
      serverId: map['serverId'] as String?,
      syncStatus: map['syncStatus'] as String?,
    );
  }
}

// Modèle pour les lignes de détail de la ProForma
class LigneProForma {
  final int? localId;
  final String ligneProFormaId;
  final int proFormaLocalId; // Clé étrangère: Référence au header ProForma
  final int produitLocalId;
  final String nomProduit;
  final double prixVenteUnitaire;
  final int quantite;
  final double sousTotal;

  final String? serverId;
  final String? syncStatus;

  LigneProForma({
    this.localId,
    required this.ligneProFormaId,
    required this.proFormaLocalId,
    required this.produitLocalId,
    required this.nomProduit,
    required this.prixVenteUnitaire,
    required this.quantite,
    required this.sousTotal,
    this.serverId,
    this.syncStatus = 'pending',
  });

  // Convertit l'objet LigneProForma en Map
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'ligneProFormaId': ligneProFormaId,
      'proFormaLocalId': proFormaLocalId,
      'produitLocalId': produitLocalId,
      'nomProduit': nomProduit,
      'prixVenteUnitaire': prixVenteUnitaire,
      'quantite': quantite,
      'sousTotal': sousTotal,
      'serverId': serverId,
      'syncStatus': syncStatus,
    };
  }

  // Crée un objet LigneProForma à partir d'un Map
  factory LigneProForma.fromMap(Map<String, dynamic> map) {
    return LigneProForma(
      localId: map['localId'] as int?,
      ligneProFormaId: map['ligneProFormaId'] as String,
      proFormaLocalId: map['proFormaLocalId'] as int,
      produitLocalId: map['produitLocalId'] as int,
      nomProduit: map['nomProduit'] as String,
      prixVenteUnitaire: (map['prixVenteUnitaire'] as num).toDouble(),
      quantite: map['quantite'] as int,
      sousTotal: (map['sousTotal'] as num).toDouble(),
      serverId: map['serverId'] as String?,
      syncStatus: map['syncStatus'] as String?,
    );
  }
}