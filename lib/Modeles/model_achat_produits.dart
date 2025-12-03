class AchatsProduit {
  final int? localId;
  final String? achatId;
  final String nomProduit;
  final String nomFournisseur;
  final String? telephoneFournisseur;
  final String type;
  final String emballage;
  final int quantiteAchetee;
  final double prixAchatUnitaire;
  final double fraisAchatUnitaire;
  final double margeBeneficiaire;
  final double prixVente;
  final String devise;
  final DateTime dateAchat;
  final DateTime? datePeremption;
  final int? fournisseurLocalId;
  final int produitLocalId;
  final String? syncStatus;

  AchatsProduit({
    this.localId,
    required this.achatId,
    required this.nomProduit,
    required this.nomFournisseur,
    this.telephoneFournisseur,
    required this.type,
    required this.emballage,
    required this.quantiteAchetee,
    required this.prixAchatUnitaire,
    required this.fraisAchatUnitaire,
    required this.margeBeneficiaire,
    required this.prixVente,
    required this.devise,
    required this.dateAchat,
    this.datePeremption,
    this.fournisseurLocalId,
    required this.produitLocalId,
    this.syncStatus = 'pending',
  });

  // Correction pour les erreurs 'undefined_getter'
  // Propriété calculée pour le coût total du lot (Capital + Frais)
  double get totalCoutLot {
    final double capitalCost = quantiteAchetee * prixAchatUnitaire;
    final double totalFraisCost = quantiteAchetee * fraisAchatUnitaire;
    return capitalCost + totalFraisCost;
  }

  // Correction pour l'erreur 'copyWith' (méthode de modification d'objet immutable)
  AchatsProduit copyWith({
    int? localId,
    String? achatId,
    String? nomProduit,
    String? nomFournisseur,
    String? telephoneFournisseur,
    String? type,
    String? emballage,
    int? quantiteAchetee,
    double? prixAchatUnitaire,
    double? fraisAchatUnitaire,
    double? margeBeneficiaire,
    double? prixVente,
    String? devise,
    DateTime? dateAchat,
    DateTime? datePeremption,
    int? fournisseurLocalId,
    int? produitLocalId,
    String? syncStatus,
  }) {
    return AchatsProduit(
      localId: localId ?? this.localId,
      achatId: achatId ?? this.achatId,
      nomProduit: nomProduit ?? this.nomProduit,
      nomFournisseur: nomFournisseur ?? this.nomFournisseur,
      telephoneFournisseur: telephoneFournisseur ?? this.telephoneFournisseur,
      type: type ?? this.type,
      emballage: emballage ?? this.emballage,
      quantiteAchetee: quantiteAchetee ?? this.quantiteAchetee,
      prixAchatUnitaire: prixAchatUnitaire ?? this.prixAchatUnitaire,
      fraisAchatUnitaire: fraisAchatUnitaire ?? this.fraisAchatUnitaire,
      margeBeneficiaire: margeBeneficiaire ?? this.margeBeneficiaire,
      prixVente: prixVente ?? this.prixVente,
      devise: devise ?? this.devise,
      dateAchat: dateAchat ?? this.dateAchat,
      datePeremption: datePeremption ?? this.datePeremption,
      fournisseurLocalId: fournisseurLocalId ?? this.fournisseurLocalId,
      produitLocalId: produitLocalId ?? this.produitLocalId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }


  // toMap et fromMap sont requis pour la persistence (SQLite/Firestore)
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'achatId': achatId,
      'nomProduit': nomProduit,
      'nomFournisseur': nomFournisseur,
      'telephoneFournisseur': telephoneFournisseur,
      'type': type,
      'emballage': emballage,
      'quantiteAchetee': quantiteAchetee,
      'prixAchatUnitaire': prixAchatUnitaire,
      'fraisAchatUnitaire': fraisAchatUnitaire,
      'margeBeneficiaire': margeBeneficiaire,
      'prixVente': prixVente,
      'devise': devise,
      'dateAchat': dateAchat.toIso8601String(),
      'datePeremption': datePeremption?.toIso8601String(),
      'fournisseurLocalId': fournisseurLocalId,
      'produitLocalId': produitLocalId,
      'syncStatus': syncStatus,
    };
  }

  factory AchatsProduit.fromMap(Map<String, dynamic> map) {
    final int id = map['produitLocalId'] as int? ?? 0;

    return AchatsProduit(
      localId: map['localId'] as int?,
      achatId: map['achatId'] as String?,
      nomProduit: map['nomProduit'] as String,
      nomFournisseur: map['nomFournisseur'] as String,
      telephoneFournisseur: map['telephoneFournisseur'] as String?,
      type: map['type'] as String,
      emballage: map['emballage'] as String,
      quantiteAchetee: map['quantiteAchetee'] as int,
      prixAchatUnitaire: (map['prixAchatUnitaire'] as num).toDouble(),
      fraisAchatUnitaire: (map['fraisAchatUnitaire'] as num).toDouble(),
      margeBeneficiaire: (map['margeBeneficiaire'] as num).toDouble(),
      prixVente: (map['prixVente'] as num).toDouble(),
      devise: map['devise'] as String,
      dateAchat: DateTime.parse(map['dateAchat']),
      datePeremption: map['datePeremption'] != null ? DateTime.parse(map['datePeremption']) : null,
      fournisseurLocalId: map['fournisseurLocalId'] as int?,
      produitLocalId: id,
      syncStatus: map['syncStatus'] as String?,
    );
  }
}