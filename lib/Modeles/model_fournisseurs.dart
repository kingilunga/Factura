class Fournisseur {
  final int? localId;
  final String nomEntreprise;
  final String? nomContact;
  final String? telephone;
  final String? email;
  final int? serverId;
  final String? syncStatus;
  // Le champ 'nom' a été supprimé comme demandé.

  Fournisseur({
    this.localId,
    required this.nomEntreprise,
    this.nomContact,
    this.telephone,
    this.email,
    this.serverId,
    this.syncStatus,
  });

  // Conversion vers Map pour SQLite
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'nomEntreprise': nomEntreprise,
      'nomContact': nomContact,
      'telephone': telephone,
      'email': email,
      'serverId': serverId,
      'syncStatus': syncStatus,
      // 'nom' a été retiré de la Map
    };
  }

  // Création à partir d'une Map SQLite
  factory Fournisseur.fromMap(Map<String, dynamic> map) {
    // Assure que 'nomEntreprise' est géré comme champ requis non-nullable
    return Fournisseur(
      localId: map['localId'] as int?,
      nomEntreprise: map['nomEntreprise'] as String? ?? '',
      nomContact: map['nomContact'] as String?,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      serverId: map['serverId'] as int?,
      syncStatus: map['syncStatus'] as String?,
    );
  }

  // Colonnes utilisées dans la DB
  static final columns = [
    'localId',
    'nomEntreprise',
    'nomContact',
    'telephone',
    'email',
    'serverId',
    'syncStatus',
    // 'nom' a été retiré des colonnes
  ];

  // Copie pour faciliter la mise à jour
  Fournisseur copyWith({
    int? localId,
    String? nomEntreprise,
    String? nomContact,
    String? telephone,
    String? email,
    int? serverId,
    String? syncStatus,
  }) {
    return Fournisseur(
      localId: localId ?? this.localId,
      nomEntreprise: nomEntreprise ?? this.nomEntreprise,
      nomContact: nomContact ?? this.nomContact,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
      // 'nom' a été retiré de copyWith
    );
  }
}