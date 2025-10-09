// Fichier: lib/database/model_ventes.dart
// Modèles de données pour les Ventes (Header) et les Lignes de Vente (Détails)


// ======================================================================
// --- Modèle Vente (Header de la Facture) ---
// ======================================================================

class Vente {
  final int? localId; // ID local SQLite (PRIMARY KEY)
  final String venteId; // ID unique (UUID) pour la synchronisation serveur
  final String dateVente;
  final int clientLocalId; // Référence au client dans la table 'clients'
  final String? vendeurNom; // Nom du vendeur/utilisateur
  final double totalBrut;
  final double reductionPercent; // Réduction appliquée (ex: 5.0 pour 5%)
  final double totalNet;
  final String statut; // Ex: 'Enregistrée', 'Payée', 'Annulée'

  // Champs de synchronisation (non requis pour le fonctionnement local)
  final String? serverId;
  final String? syncStatus; // Ex: 'pending', 'synced'

  Vente({
    this.localId,
    required this.venteId,
    required this.dateVente,
    required this.clientLocalId,
    this.vendeurNom,
    required this.totalBrut,
    required this.reductionPercent,
    required this.totalNet,
    required this.statut,
    this.serverId,
    this.syncStatus = 'pending',
  });

  // Convertit l'objet Vente en Map (pour l'insertion dans SQLite)
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'venteId': venteId,
      'dateVente': dateVente,
      'clientLocalId': clientLocalId,
      'vendeurNom': vendeurNom,
      'totalBrut': totalBrut,
      'reductionPercent': reductionPercent,
      'totalNet': totalNet,
      'statut': statut,
      'serverId': serverId,
      'syncStatus': syncStatus,
    };
  }

  // Crée un objet Vente à partir d'un Map (récupération depuis SQLite)
  factory Vente.fromMap(Map<String, dynamic> map) {
    return Vente(
      localId: map['localId'] as int?,
      venteId: map['venteId'] as String,
      dateVente: map['dateVente'] as String,
      clientLocalId: map['clientLocalId'] as int,
      vendeurNom: map['vendeurNom'] as String?,
      totalBrut: map['totalBrut'] as double,
      reductionPercent: map['reductionPercent'] as double,
      totalNet: map['totalNet'] as double,
      statut: map['statut'] as String,
      serverId: map['serverId'] as String?,
      syncStatus: map['syncStatus'] as String?,
    );
  }
}

// ======================================================================
// --- Modèle LigneVente (Détail du Produit Vendu) ---
// ======================================================================

class LigneVente {
  final int? localId; // ID local SQLite (PRIMARY KEY)
  final String ligneVenteId; // ID unique pour la synchronisation
  final int venteLocalId; // Clé étrangère: Référence au header Vente
  final int produitLocalId; // Référence au produit vendu
  final String nomProduit; // Nom du produit au moment de la vente (pour historique)
  final double prixVenteUnitaire;
  final int quantite;
  final double sousTotal; // Prix total de cette ligne (prix * quantité)

  // Champs de synchronisation
  final String? serverId;
  final String? syncStatus;

  LigneVente({
    this.localId,
    required this.ligneVenteId,
    required this.venteLocalId,
    required this.produitLocalId,
    required this.nomProduit,
    required this.prixVenteUnitaire,
    required this.quantite,
    required this.sousTotal,
    this.serverId,
    this.syncStatus = 'pending',
  });

  // Convertit l'objet LigneVente en Map
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'ligneVenteId': ligneVenteId,
      'venteLocalId': venteLocalId,
      'produitLocalId': produitLocalId,
      'nomProduit': nomProduit,
      'prixVenteUnitaire': prixVenteUnitaire,
      'quantite': quantite,
      'sousTotal': sousTotal,
      'serverId': serverId,
      'syncStatus': syncStatus,
    };
  }

  // Crée un objet LigneVente à partir d'un Map
  factory LigneVente.fromMap(Map<String, dynamic> map) {
    return LigneVente(
      localId: map['localId'] as int?,
      ligneVenteId: map['ligneVenteId'] as String,
      venteLocalId: map['venteLocalId'] as int,
      produitLocalId: map['produitLocalId'] as int,
      nomProduit: map['nomProduit'] as String,
      prixVenteUnitaire: map['prixVenteUnitaire'] as double,
      quantite: map['quantite'] as int,
      sousTotal: map['sousTotal'] as double,
      serverId: map['serverId'] as String?,
      syncStatus: map['syncStatus'] as String?,
    );
  }
}
