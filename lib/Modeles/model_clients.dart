class Client {
  static Client defaultClient() {
    return Client(
      localId: 1,
      nomClient: 'Client de passage',
      telephone: '',
      adresse: '',
      syncStatus: 'synced',
    );
  }

  int? localId;          // clé primaire locale
  String nomClient;      // entreprise ou particulier
  String? telephone;     // optionnel
  String? adresse;       // optionnel
  int? serverId;         // ID serveur (sync)
  String? syncStatus;    // statut sync: pending, synced

  Client({
    this.localId,
    required this.nomClient,
    this.telephone,
    this.adresse,
    this.serverId,
    this.syncStatus,
  });

  // Convert to JSON
  Map<String, dynamic> toJson({required bool includeLocalId}) => {
    'localId': includeLocalId ? localId : null,
    'nomClient': nomClient,
    'telephone': telephone,
    'adresse': adresse,
    'serverId': serverId,
    'syncStatus': syncStatus,
  };

  // Convertir en Map pour SQLite
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'nomClient': nomClient,
      'telephone': telephone,
      'adresse': adresse,
      'serverId': serverId,
      'syncStatus': syncStatus,
    };
  }

  // Créer un Client depuis SQLite
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      localId: map['localId'] as int?,
      nomClient: map['nomClient'] as String,
      telephone: map['telephone'] as String?,
      adresse: map['adresse'] as String?,
      serverId: map['serverId'] as int?,
      syncStatus: map['syncStatus'] as String?,
    );
  }

  // Copie avec modification
  Client copyWith({
    int? localId,
    String? nomClient,
    String? telephone,
    String? adresse,
    int? serverId,
    String? syncStatus,
  }) {
    return Client(
      localId: localId ?? this.localId,
      nomClient: nomClient ?? this.nomClient,
      telephone: telephone ?? this.telephone,
      adresse: adresse ?? this.adresse,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}
