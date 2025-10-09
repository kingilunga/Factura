class Produit {
  final int? localId;
  final String nom;
  final String? categorie;
  final double? prix;
  final int? quantiteInitiale;
  final int? quantiteActuelle;
  final String? imagePath;
  final int? idTransaction;
  final int? serverId;
  final String? syncStatus;

  Produit({
    this.localId,
    required this.nom,
    this.categorie,
    this.prix,
    this.quantiteInitiale,
    this.quantiteActuelle,
    this.imagePath,
    this.idTransaction,
    this.serverId,
    this.syncStatus,
  });

  // Méthode copyWith pour faciliter les mises à jour
  Produit copyWith({
    int? localId,
    String? nom,
    String? categorie,
    double? prix,
    int? quantiteInitiale,
    int? quantiteActuelle,
    String? imagePath,
    int? idTransaction,
    int? serverId,
    String? syncStatus,
  }) {
    return Produit(
      localId: localId ?? this.localId,
      nom: nom ?? this.nom,
      categorie: categorie ?? this.categorie,
      prix: prix ?? this.prix,
      quantiteInitiale: quantiteInitiale ?? this.quantiteInitiale,
      quantiteActuelle: quantiteActuelle ?? this.quantiteActuelle,
      imagePath: imagePath ?? this.imagePath,
      idTransaction: idTransaction ?? this.idTransaction,
      serverId: serverId ?? this.serverId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  // Convertir un Produit en Map pour SQLite
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'nom': nom,
      'categorie': categorie,
      'prix': prix,
      'quantiteInitiale': quantiteInitiale,
      'quantiteActuelle': quantiteActuelle,
      'imagePath': imagePath,
      'idTransaction': idTransaction,
      'serverId': serverId,
      'syncStatus': syncStatus,
    };
  }

  // Créer un Produit à partir d'une Map SQLite
  factory Produit.fromMap(Map<String, dynamic> map) {
    return Produit(
      localId: map['localId'] as int?,
      nom: map['nom'] as String,
      categorie: map['categorie'] as String?,
      prix: (map['prix'] as num?)?.toDouble(),
      quantiteInitiale: map['quantiteInitiale'] as int?,
      quantiteActuelle: map['quantiteActuelle'] as int?,
      imagePath: map['imagePath'] as String?,
      idTransaction: map['idTransaction'] as int?,
      serverId: map['serverId'] as int?,
      syncStatus: map['syncStatus'] as String?,
    );
  }
}
