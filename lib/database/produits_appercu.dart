class ProduitApercu {
  final int id;
  final String nom;
  final String? categorie;
  final int quantiteActuelle;
  final int totalVendu;

  ProduitApercu({
    required this.id,
    required this.nom,
    this.categorie,
    required this.quantiteActuelle,
    required this.totalVendu,
  });

  factory ProduitApercu.fromMap(Map<String, dynamic> map) {
    return ProduitApercu(
      id: map['id'] as int,
      nom: map['nom'] as String,
      categorie: map['categorie'] as String?,
      quantiteActuelle: map['quantiteActuelle'] as int,
      totalVendu: map['totalVendu'] as int,
    );
  }
}
