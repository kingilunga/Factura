// Fichier contenant tous les modèles de données (Entités et DTOs)
// nécessaires au bon fonctionnement du DatabaseService.

import 'dart:convert';

// ======================================================================
// --- 1. MODÈLES D'ENTITÉS PRINCIPALES (Tables de la DB) ---
// ======================================================================

class Produit {
  final int? localId;
  final String nom;
  final String description;
  final double prix;
  final String categorie;
  final int quantiteInitiale;
  final int? quantiteActuelle; // Peut être mis à jour par les ventes
  final int fournisseurLocalId;

  Produit({
    this.localId,
    required this.nom,
    this.description = '',
    required this.prix,
    required this.categorie,
    required this.quantiteInitiale,
    this.quantiteActuelle,
    required this.fournisseurLocalId,
  });

  // Convertit un Produit en Map pour insertion dans la base de données
  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'nom': nom,
      'description': description,
      'prix': prix,
      'categorie': categorie,
      'quantiteInitiale': quantiteInitiale,
      // Utilise quantiteActuelle si fourni, sinon quantiteInitiale
      'quantiteActuelle': quantiteActuelle ?? quantiteInitiale,
      'fournisseurLocalId': fournisseurLocalId,
    };
  }

  // Crée un Produit à partir d'un Map (résultat de requête DB)
  factory Produit.fromMap(Map<String, dynamic> map) {
    return Produit(
      localId: map['localId'] as int?,
      nom: map['nom'] as String,
      description: map['description'] as String? ?? '',
      prix: (map['prix'] as num).toDouble(),
      categorie: map['categorie'] as String,
      quantiteInitiale: map['quantiteInitiale'] as int,
      quantiteActuelle: map['quantiteActuelle'] as int?,
      fournisseurLocalId: map['fournisseurLocalId'] as int,
    );
  }

  // Fonction utilitaire pour la mise à jour (nécessaire dans updateProductStock)
  Produit copyWith({int? quantiteActuelle}) {
    return Produit(
      localId: localId,
      nom: nom,
      description: description,
      prix: prix,
      categorie: categorie,
      quantiteInitiale: quantiteInitiale,
      quantiteActuelle: quantiteActuelle ?? this.quantiteActuelle,
      fournisseurLocalId: fournisseurLocalId,
    );
  }
}

class Client {
  final int? localId;
  final String nomClient;
  final String contact;
  final String email;

  Client({
    this.localId,
    required this.nomClient,
    this.contact = '',
    this.email = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'nomClient': nomClient,
      'contact': contact,
      'email': email,
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      localId: map['localId'] as int?,
      nomClient: map['nomClient'] as String,
      contact: map['contact'] as String? ?? '',
      email: map['email'] as String? ?? '',
    );
  }
}

class Vente {
  final int? localId;
  final String dateVente; // Stockée en ISO8601 string
  final int? clientLocalId;
  final String clientNom; // Nom pour référence rapide
  final double totalNet;
  final String statut; // e.g., 'validée', 'annulée', 'en_attente'
  final int vendeurLocalId;
  final String vendeurNom;

  Vente({
    this.localId,
    required this.dateVente,
    this.clientLocalId,
    required this.clientNom,
    required this.totalNet,
    this.statut = 'validée',
    required this.vendeurLocalId,
    required this.vendeurNom,
  });

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'dateVente': dateVente,
      'clientLocalId': clientLocalId,
      'clientNom': clientNom,
      'totalNet': totalNet,
      'statut': statut,
      'vendeurLocalId': vendeurLocalId,
      'vendeurNom': vendeurNom,
    };
  }

  factory Vente.fromMap(Map<String, dynamic> map) {
    return Vente(
      localId: map['localId'] as int?,
      dateVente: map['dateVente'] as String,
      clientLocalId: map['clientLocalId'] as int?,
      clientNom: map['clientNom'] as String,
      totalNet: (map['totalNet'] as num).toDouble(),
      statut: map['statut'] as String,
      vendeurLocalId: map['vendeurLocalId'] as int,
      vendeurNom: map['vendeurNom'] as String,
    );
  }
}

class LigneVente {
  final int? ligneVenteId;
  final int venteLocalId;
  final int produitLocalId;
  final String nomProduit;
  final double prixVenteUnitaire;
  final int quantite;
  final double sousTotal;

  LigneVente({
    this.ligneVenteId,
    required this.venteLocalId,
    required this.produitLocalId,
    required this.nomProduit,
    required this.prixVenteUnitaire,
    required this.quantite,
    required this.sousTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'ligneVenteId': ligneVenteId,
      'venteLocalId': venteLocalId,
      'produitLocalId': produitLocalId,
      'nomProduit': nomProduit,
      'prixVenteUnitaire': prixVenteUnitaire,
      'quantite': quantite,
      'sousTotal': sousTotal,
    };
  }

  factory LigneVente.fromMap(Map<String, dynamic> map) {
    return LigneVente(
      ligneVenteId: map['ligneVenteId'] as int?,
      venteLocalId: map['venteLocalId'] as int,
      produitLocalId: map['produitLocalId'] as int,
      nomProduit: map['nomProduit'] as String,
      prixVenteUnitaire: (map['prixVenteUnitaire'] as num).toDouble(),
      quantite: map['quantite'] as int,
      sousTotal: (map['sousTotal'] as num).toDouble(),
    );
  }
}

class Utilisateur {
  final int? localId;
  final String nom;
  final String email;
  final String motDePasseHash; // Haché pour la sécurité
  final String role; // e.g., 'Admin', 'Vendeur'
  final String telephone;

  Utilisateur({
    this.localId,
    required this.nom,
    required this.email,
    required this.motDePasseHash,
    this.role = 'Vendeur',
    this.telephone = '',
  });

  // Colonnes pour les requêtes SELECT
  static final List<String> columns = [
    'localId',
    'nom',
    'email',
    'motDePasseHash',
    'role',
    'telephone'
  ];

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'nom': nom,
      'email': email,
      'motDePasseHash': motDePasseHash,
      'role': role,
      'telephone': telephone,
    };
  }

  factory Utilisateur.fromMap(Map<String, dynamic> map) {
    return Utilisateur(
      localId: map['localId'] as int?,
      nom: map['nom'] as String,
      email: map['email'] as String,
      motDePasseHash: map['motDePasseHash'] as String,
      role: map['role'] as String? ?? 'Vendeur',
      telephone: map['telephone'] as String? ?? '',
    );
  }
}

class Fournisseur {
  final int? localId;
  final String nomEntreprise;
  final String contactNom;
  final String telephone;
  final String email;

  Fournisseur({
    this.localId,
    required this.nomEntreprise,
    this.contactNom = '',
    this.telephone = '',
    this.email = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'nomEntreprise': nomEntreprise,
      'contactNom': contactNom,
      'telephone': telephone,
      'email': email,
    };
  }

  factory Fournisseur.fromMap(Map<String, dynamic> map) {
    return Fournisseur(
      localId: map['localId'] as int?,
      nomEntreprise: map['nomEntreprise'] as String,
      contactNom: map['contactNom'] as String? ?? '',
      telephone: map['telephone'] as String? ?? '',
      email: map['email'] as String? ?? '',
    );
  }
}

class AchatsProduit {
  final int? localId;
  final String achatId; // ID unique de l'achat (peut être fourni par l'utilisateur)
  final int produitLocalId;
  final int fournisseurLocalId;
  final String dateAchat; // Stockée en ISO8601 string
  final int quantiteAchetee;
  final double coutUnitaire; // Coût réel d'achat

  AchatsProduit({
    this.localId,
    required this.achatId,
    required this.produitLocalId,
    required this.fournisseurLocalId,
    required this.dateAchat,
    required this.quantiteAchetee,
    required this.coutUnitaire,
  });

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'achatId': achatId,
      'produitLocalId': produitLocalId,
      'fournisseurLocalId': fournisseurLocalId,
      'dateAchat': dateAchat,
      'quantiteAchetee': quantiteAchetee,
      'coutUnitaire': coutUnitaire,
    };
  }

  factory AchatsProduit.fromMap(Map<String, dynamic> map) {
    return AchatsProduit(
      localId: map['localId'] as int?,
      achatId: map['achatId'] as String,
      produitLocalId: map['produitLocalId'] as int,
      fournisseurLocalId: map['fournisseurLocalId'] as int,
      dateAchat: map['dateAchat'] as String,
      quantiteAchetee: map['quantiteAchetee'] as int,
      coutUnitaire: (map['coutUnitaire'] as num).toDouble(),
    );
  }
}

class TauxChange {
  final int? id;
  final String devise; // USD, EUR, CDF, etc.
  final double taux; // Taux par rapport à la devise de base (e.g., CDF)
  final String dateMiseAJour;

  TauxChange({
    this.id,
    required this.devise,
    required this.taux,
    required this.dateMiseAJour,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'devise': devise,
      'taux': taux,
      'dateMiseAJour': dateMiseAJour,
    };
  }

  factory TauxChange.fromMap(Map<String, dynamic> map) {
    return TauxChange(
      id: map['id'] as int?,
      devise: map['devise'] as String,
      taux: (map['taux'] as num).toDouble(),
      dateMiseAJour: map['dateMiseAJour'] as String,
    );
  }
}

// ======================================================================
// --- MODÈLES PRO FORMA (Devis) ---
// ======================================================================

class ProForma {
  final int? localId;
  final String dateCreation; // ISO8601 string
  final int? clientLocalId;
  final String clientNom;
  final double totalEstime;
  final String statut; // e.g., 'créé', 'envoyé', 'validé'
  final int redacteurLocalId; // Vendeur/Utilisateur qui crée la proforma
  final String redacteurNom;

  ProForma({
    this.localId,
    required this.dateCreation,
    this.clientLocalId,
    required this.clientNom,
    required this.totalEstime,
    this.statut = 'créé',
    required this.redacteurLocalId,
    required this.redacteurNom,
  });

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'dateCreation': dateCreation,
      'clientLocalId': clientLocalId,
      'clientNom': clientNom,
      'totalEstime': totalEstime,
      'statut': statut,
      'redacteurLocalId': redacteurLocalId,
      'redacteurNom': redacteurNom,
    };
  }

  factory ProForma.fromMap(Map<String, dynamic> map) {
    return ProForma(
      localId: map['localId'] as int?,
      dateCreation: map['dateCreation'] as String,
      clientLocalId: map['clientLocalId'] as int?,
      clientNom: map['clientNom'] as String,
      totalEstime: (map['totalEstime'] as num).toDouble(),
      statut: map['statut'] as String,
      redacteurLocalId: map['redacteurLocalId'] as int,
      redacteurNom: map['redacteurNom'] as String,
    );
  }
}

class LigneProForma {
  final int? ligneProFormaId;
  final int proFormaLocalId;
  final int produitLocalId;
  final String nomProduit;
  final double prixVenteUnitaire;
  final int quantite;
  final double sousTotal;

  LigneProForma({
    this.ligneProFormaId,
    required this.proFormaLocalId,
    required this.produitLocalId,
    required this.nomProduit,
    required this.prixVenteUnitaire,
    required this.quantite,
    required this.sousTotal,
  });

  Map<String, dynamic> toMap() {
    return {
      'ligneProFormaId': ligneProFormaId,
      'proFormaLocalId': proFormaLocalId,
      'produitLocalId': produitLocalId,
      'nomProduit': nomProduit,
      'prixVenteUnitaire': prixVenteUnitaire,
      'quantite': quantite,
      'sousTotal': sousTotal,
    };
  }

  factory LigneProForma.fromMap(Map<String, dynamic> map) {
    return LigneProForma(
      ligneProFormaId: map['ligneProFormaId'] as int?,
      proFormaLocalId: map['proFormaLocalId'] as int,
      produitLocalId: map['produitLocalId'] as int,
      nomProduit: map['nomProduit'] as String,
      prixVenteUnitaire: (map['prixVenteUnitaire'] as num).toDouble(),
      quantite: map['quantite'] as int,
      sousTotal: (map['sousTotal'] as num).toDouble(),
    );
  }
}

// ======================================================================
// --- MODÈLES D'APERÇU / DTOs (Data Transfer Objects pour le Dashboard) ---
// ======================================================================

class AdminStats {
  final double totalChiffreAffaires;
  final int totalVentes;
  final int totalClients;
  final int totalProduits;

  AdminStats({
    this.totalChiffreAffaires = 0.0,
    this.totalVentes = 0,
    this.totalClients = 0,
    this.totalProduits = 0,
  });
}

class VenteRecenteApercu {
  final String dateVente;
  final String produitNom;
  final String vendeurNom;
  final double montantNet;

  VenteRecenteApercu({
    required this.dateVente,
    required this.produitNom,
    required this.vendeurNom,
    required this.montantNet,
  });
}

class ProduitApercu {
  final String nom;
  final double prix;
  final int stock; // Utilisé pour stock réel OU quantité vendue (Top Selling)
  final String statut; // 'Critique', 'Rupture', 'Top Vente'

  ProduitApercu({
    required this.nom,
    required this.prix,
    required this.stock,
    required this.statut,
  });
}

class ClientApercu {
  final String nomClient;
  final String type;
  final int totalOperations;

  ClientApercu({
    required this.nomClient,
    required this.type,
    required this.totalOperations,
  });
}

class VenteTendance {
  final String label; // e.g., '2023-10-25' ou '2023-10'
  final double montant;

  VenteTendance({
    required this.label,
    required this.montant,
  });
}