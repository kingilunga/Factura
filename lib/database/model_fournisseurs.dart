// Fichier: lib/database/models_fournisseurs.dart

class Fournisseur {
  int? localId;
  String? nomEntreprise;
  String? nomContact;
  String? telephone;
  String? email;
  int? serverId;
  String? syncStatus;

  Fournisseur({
    this.localId,
    required this.nomEntreprise,
    this.nomContact,
    this.telephone,
    this.email,
    this.serverId,
    this.syncStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'nomEntreprise': nomEntreprise,
      'nomContact': nomContact,
      'telephone': telephone,
      'email': email,
      'serverId': serverId,
      'syncStatus': syncStatus,
    };
  }

  factory Fournisseur.fromMap(Map<String, dynamic> map) {
    return Fournisseur(
      localId: map['localId'] as int?,
      nomEntreprise: map['nomEntreprise'] as String?,
      nomContact: map['nomContact'] as String?,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      serverId: map['serverId'] as int?,
      syncStatus: map['syncStatus'] as String?,
    );
  }

  static final columns = [
    'localId',
    'nomEntreprise',
    'nomContact',
    'telephone',
    'email',
    'serverId',
    'syncStatus',
  ];
}
