class Utilisateur {
  final int? localId;
  final String nom;
  final String postnom;
  final String prenom;
  final String telephone;
  final String email;
  final String motDePasse;
  final String role;
  final bool actif;

  Utilisateur({
    this.localId,
    required this.nom,
    required this.postnom,
    required this.prenom,
    required this.telephone,
    required this.email,
    required this.motDePasse,
    required this.role,
    this.actif = true,
  });

  factory Utilisateur.fromMap(Map<String, dynamic> map) {
    return Utilisateur(
      localId: map['localId'],
      nom: map['nom'] ?? '',
      postnom: map['postnom'] ?? '',
      prenom: map['prenom'] ?? '',
      telephone: map['telephone'] ?? '',
      email: map['email'] ?? '',
      motDePasse: map['motDePasse'] ?? '',
      role: map['role'] ?? '',
      actif: map['actif'] == 1 || map['actif'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'nom': nom,
      'postnom': postnom,
      'prenom': prenom,
      'telephone': telephone,
      'email': email,
      'motDePasse': motDePasse,
      'role': role,
      'actif': actif ? 1 : 0,
    };
  }

  // 🧱 Colonnes SQL (utile pour database_service.dart)
  static List<String> get columns => [
    'localId',
    'nom',
    'postnom',
    'prenom',
    'telephone',
    'email',
    'motDePasse',
    'role',
    'actif',
  ];
}
