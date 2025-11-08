// Modèle de données pour les Produits
class Produit {
  final int? localId; // Identifiant local (SQLite)
  final String nom;
  final String? categorie;
  final double? prix; // Prix de vente en CDF
  final int? quantiteInitiale;
  final int? quantiteActuelle;
  final String? imagePath;
  final int? idTransaction;
  final int? serverId; // Identifiant sur le serveur distant
  final String? syncStatus; // Statut de synchronisation

  // NOUVEAUX CHAMPS pour la gestion des coûts en USD
  final double? prixAchatUSD; // Coût de base du produit en USD
  final double? fraisAchatUSD; // Frais additionnels (transport, douane) en USD

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
    // Initialisation des nouveaux champs (rendus optionnels pour la compatibilité initiale)
    this.prixAchatUSD,
    this.fraisAchatUSD,
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
    // Ajout des nouveaux champs dans copyWith
    double? prixAchatUSD,
    double? fraisAchatUSD,
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
      // Copie des nouveaux champs
      prixAchatUSD: prixAchatUSD ?? this.prixAchatUSD,
      fraisAchatUSD: fraisAchatUSD ?? this.fraisAchatUSD,
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
      // Ajout des nouveaux champs à la Map
      'prixAchatUSD': prixAchatUSD,
      'fraisAchatUSD': fraisAchatUSD,
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
      // Récupération des nouveaux champs (avec valeur par défaut si non présent)
      prixAchatUSD: (map['prixAchatUSD'] as num?)?.toDouble(),
      fraisAchatUSD: (map['fraisAchatUSD'] as num?)?.toDouble(),
    );
  }
}