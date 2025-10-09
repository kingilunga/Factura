class Utilisateur {
  // L'ID local (SQLite), clé primaire auto-incrémentée
  int? localId;

  // Champs classiques
  String? nom;
  String? postNom;
  String? prenom;
  String? telephone;
  String? email;
  String? motDePasseHash;
  String role;

  // Champs de synchro avec Supabase
  String? serverId;     // ID généré côté serveur (Supabase)
  String syncStatus;    // "pending", "synced", "updated", etc.

  // Autres champs optionnels
  String? nomUtil;
  String? nomUtilisateurisateur; // (à clarifier ? doublon ?)
  String? nomUtilisateur;

  // Colonnes SQLite
  static final List<String> columns = [
    'localId',
    'nom',
    'postNom',
    'prenom',
    'telephone',
    'email',
    'motDePasseHash',
    'role',
    'serverId',
    'syncStatus',
  ];

  Utilisateur({
    this.localId,
    this.nom,
    this.postNom,
    this.prenom,
    this.telephone,
    this.email,
    this.motDePasseHash,
    required this.role,
    this.serverId,
    this.syncStatus = "pending", // par défaut en attente de synchro
    this.nomUtil,
    this.nomUtilisateurisateur,
    this.nomUtilisateur,
  });

  // Conversion objet → Map (pour SQLite / Supabase)
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'nom': nom,
      'postNom': postNom,
      'prenom': prenom,
      'telephone': telephone,
      'email': email,
      'motDePasseHash': motDePasseHash,
      'role': role,
      'serverId': serverId,
      'syncStatus': syncStatus,
    };
  }

  // Conversion Map → objet (résultat d'une requête DB)
  factory Utilisateur.fromMap(Map<String, dynamic> map) {
    return Utilisateur(
      localId: map['localId'] as int?,
      nom: map['nom'] as String?,
      postNom: map['postNom'] as String?,
      prenom: map['prenom'] as String?,
      telephone: map['telephone'] as String?,
      email: map['email'] as String?,
      motDePasseHash: map['motDePasseHash'] as String?,
      role: map['role'] as String? ?? 'vendeur',
      serverId: map['serverId'] as String?,
      syncStatus: map['syncStatus'] as String? ?? "pending",
    );
  }
}
