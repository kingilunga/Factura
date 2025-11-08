import 'dart:io';
import 'dart:typed_data';

import 'package:factura/DashboardVendor/historique_ventes.dart';
import 'package:factura/DashboardVendor/pdf_preview.dart';
import 'package:factura/pdf_generator_service.dart' as pdf_service;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/Modeles/model_clients.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:factura/Modeles/model_ventes.dart';
import 'package:uuid/uuid.dart';

/// MODELE PANIER
class CartItem {
  final Produit produit;
  int quantity;
  CartItem({required this.produit, this.quantity = 1});
}

/// PAGE ENREGISTREMENT VENTE (avec recherche + suggestions)
class EnregistrementVente extends StatefulWidget {
  const EnregistrementVente({super.key});
  @override
  State<EnregistrementVente> createState() => _EnregistrementVenteState();
}

class _EnregistrementVenteState extends State<EnregistrementVente> {
  final db = DatabaseService.instance;

  // Clients
  List<Client> clients = [];
  List<Client> filteredClients = [];
  Client? selectedClient;
  final TextEditingController clientSearchController = TextEditingController();
  bool _showClientSuggestions = false;

  // Nouveau client
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  bool showNewClientForm = false;

  // Produits & panier
  List<Produit> produits = [];
  List<Produit> filteredProducts = [];
  final TextEditingController productSearchController = TextEditingController();
  bool _showProductSuggestions = false;
  List<CartItem> cart = [];

  // Compteur séquentiel simple
  int _salesCounter = 0;

  // Mode de paiement par défaut
  String _modePaiement = 'CASH';

  // --- Initialisation et Nettoyage ---

  @override
  void initState() {
    super.initState();
    loadClients();
    loadProducts();
    _loadSalesCounter();

    clientSearchController.addListener(() {
      if (clientSearchController.text.isEmpty) {
        setState(() => _showClientSuggestions = false);
      }
    });
    productSearchController.addListener(() {
      if (productSearchController.text.isEmpty) {
        setState(() => _showProductSuggestions = false);
      }
    });
  }

  @override
  void dispose() {
    clientSearchController.dispose();
    productSearchController.dispose();
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  // --- Gestion du compteur (Simulation) ---
  Future<void> _loadSalesCounter() async {
    // Récupère le nombre de ventes déjà enregistrées pour initialiser le compteur
    final totalSales = await db.getTotalVentesCount();
    if (mounted) {
      setState(() {
        _salesCounter = totalSales;
      });
    }
  }


  // --- Chargement et Filtrage ---

  Future<void> loadClients() async {
    final loaded = await db.getAllClients();
    if (!mounted) return;
    setState(() {
      clients = loaded;
      filteredClients = List<Client>.from(clients);
      if (selectedClient != null && !clients.any((c) => c.localId == selectedClient!.localId)) {
        selectedClient = null;
        clientSearchController.clear();
      }
    });
  }

  Future<void> loadProducts() async {
    final loaded = await db.getAllProduits();
    if (!mounted) return;
    setState(() {
      produits = loaded;
      filteredProducts = List<Produit>.from(produits);
    });
  }

  void filterClients(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        filteredClients = List<Client>.from(clients);
        _showClientSuggestions = false;
      });
      return;
    }

    final results = clients.where((c) {
      final name = (c.nomClient ?? '').toLowerCase();
      final phone = (c.telephone ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    setState(() {
      filteredClients = results;
      _showClientSuggestions = true;
    });
  }

  void filterProducts(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        filteredProducts = List<Produit>.from(produits);
        _showProductSuggestions = false;
      });
      return;
    }

    final results = produits.where((p) {
      final name = (p.nom ?? '').toLowerCase();
      final cat = (p.categorie ?? '').toLowerCase();
      return name.contains(q) || cat.contains(q);
    }).toList();

    setState(() {
      filteredProducts = results;
      _showProductSuggestions = true;
    });
  }

  // --- Logique Panier et Client ---

  Future<void> addClient() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return;

    final newClient = Client(
      nomClient: name,
      telephone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
      adresse: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
    );

    try {
      final localId = await db.insertClient(newClient);
      await loadClients();
      final justAdded = clients.firstWhere((c) => c.localId == localId, orElse: () => newClient);
      if (!mounted) return;
      setState(() {
        showNewClientForm = false;
        selectedClient = justAdded;
        clientSearchController.text = selectedClient?.nomClient ?? '';
        _showClientSuggestions = false;
        filteredClients = List<Client>.from(clients);
      });
      nameController.clear();
      phoneController.clear();
      addressController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur ajout client: $e')));
    }
  }

  void addProductToCart(Produit produit) {
    // ⚙️ VÉRIFICATION DE STOCK LÉGÈRE AVANT D'AJOUTER
    final stockDispo = produit.quantiteActuelle ?? 0;
    final existingItem = cart.indexWhere((c) => c.produit.localId == produit.localId);
    final currentQuantity = existingItem >= 0 ? cart[existingItem].quantity : 0;

    if (currentQuantity >= stockDispo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Stock maximal atteint pour ${produit.nom}. Stock disponible: $stockDispo")),
        );
      }
      return;
    }

    setState(() {
      if (existingItem >= 0) {
        cart[existingItem].quantity += 1;
      } else {
        cart.add(CartItem(produit: produit));
      }
      productSearchController.clear();
      _showProductSuggestions = false;
      filteredProducts = List<Produit>.from(produits);
    });
  }

  void updateQuantity(CartItem item, int delta) {
    // ⚙️ VÉRIFICATION DE STOCK LORS DE L'AUGMENTATION
    final stockDispo = item.produit.quantiteActuelle ?? 0;
    final newQuantity = item.quantity + delta;

    if (delta > 0 && newQuantity > stockDispo) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Stock maximal atteint pour ${item.produit.nom}. Stock disponible: $stockDispo")),
        );
      }
      return;
    }

    setState(() {
      item.quantity = newQuantity;
      if (item.quantity <= 0) cart.remove(item);
    });
  }

  // --- Calculs ---
  double get total => cart.fold(0, (sum, item) => sum + (item.produit.prix ?? 0) * item.quantity);
  // ⚙️ Votre logique de réduction : 8% du total brut
  double get discountAmount => total * 0.06;
  double get netToPay => total - discountAmount;

  // --- Création vente / lignes ---

  Vente createVente({bool isDraft = false}) {
    // ⚙️ LOGIQUE POUR UN NUMÉRO SÉQUENTIEL SIMPLE (FV-001, FV-002...)
    final sequence = (_salesCounter + (isDraft ? 1 : 1)).toString().padLeft(3, '0');
    final newVenteId = 'FV-$sequence';

    return Vente(
      venteId: newVenteId,
      dateVente: DateTime.now().toIso8601String(),
      clientLocalId: selectedClient!.localId!,
      vendeurNom: 'Vendeur', // À remplacer par le nom de l'utilisateur connecté
      totalBrut: total,
      reductionPercent: discountAmount, // Stocke le montant de la réduction
      totalNet: netToPay,
      statut: isDraft ? 'brouillon' : 'validée',
    );
  }

  List<LigneVente> createLignes(Vente vente) {
    return cart.map((item) {
      return LigneVente(
        ligneVenteId: const Uuid().v4(),
        venteLocalId: vente.localId ?? 0,
        produitLocalId: item.produit.localId!,
        nomProduit: item.produit.nom!,
        prixVenteUnitaire: item.produit.prix ?? 0,
        quantite: item.quantity,
        sousTotal: (item.produit.prix ?? 0) * item.quantity,
      );
    }).toList();
  }

  // --- MAPPING VERS LES MODÈLES PDF SIMPLIFIÉS ---
  pdf_service.PdfClient _mapClient(Client appClient) {
    return pdf_service.PdfClient(
      nomClient: appClient.nomClient ?? 'Client Anonyme',
      telephone: appClient.telephone,
      adresse: appClient.adresse,
    );
  }

  List<pdf_service.PdfLigneVente> _mapLignes(List<LigneVente> appLignes) {
    return appLignes.map((l) => pdf_service.PdfLigneVente(
      nomProduit: l.nomProduit,
      prixVenteUnitaire: l.prixVenteUnitaire,
      quantite: l.quantite,
      sousTotal: l.sousTotal,
    )).toList();
  }

  pdf_service.PdfVente _mapVente(Vente appVente) {
    return pdf_service.PdfVente(
      venteId: appVente.venteId,
      dateVente: appVente.dateVente,
      vendeurNom: appVente.vendeurNom ?? '---',
      modePaiement: _modePaiement, // Utilisation du mode de paiement sélectionné
      totalBrut: appVente.totalBrut,
      montantReduction: appVente.reductionPercent,
      totalNet: appVente.totalNet,
    );
  }

  // --- Générer PDF (Utilise le service externe) ---
  Future<Uint8List> _generatePdfBytes(Vente vente, List<LigneVente> lignes, Client client, bool isThermal) async {
    final pdfClient = _mapClient(client);
    final pdfVente = _mapVente(vente);
    final pdfLignes = _mapLignes(lignes);

    if (isThermal) {
      final doc = await pdf_service.generateThermalReceipt(pdfVente, pdfLignes, pdfClient);
      return doc.save();
    } else {
      final doc = await pdf_service.generatePdfA4(pdfVente, pdfLignes, pdfClient);
      return doc.save();
    }
  }


  // --- Sauvegarde PDF (Archivage) ---
  Future<void> savePdfLocally(Uint8List bytes, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      // Utiliser un sous-répertoire pour l'archivage
      final archiveDir = Directory('${directory.path}/factures_archive');
      if (!await archiveDir.exists()) {
        await archiveDir.create(recursive: true);
      }
      final file = File('${archiveDir.path}/$fileName.pdf');
      await file.writeAsBytes(bytes);
      print('PDF enregistré : ${file.path}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Facture PDF archivée : ${file.path}')),
        );
      }
    } catch (e) {
      print('Erreur sauvegarde PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur sauvegarde facture: $e')),
        );
      }
    }
  }

  // ⚙️ NOUVELLE FONCTION: Prévisualisation du PDF A4 et Thermal
  void _previewPdf(Vente vente, List<LigneVente> lignes, Client client) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewPage(
          title: 'Facture N° ${vente.venteId}',
          // Fonction qui appelle notre service en fonction du type de reçu demandé
          generatePdfBytes: (isThermal) => _generatePdfBytes(vente, lignes, client, isThermal),
        ),
      ),
    );
  }

  // ⚙️ FONCTION: Impression Directe (pour le thermal)
  Future<void> printOrPreviewThermalPdf(Vente vente, List<LigneVente> lignes, Client client) async {
    try {
      // 1. Générer le document thermique (isThermal=true)
      final pdfBytes = await _generatePdfBytes(vente, lignes, client, true);

      // 2. Définir le format thermique 80mm
      const thermalFormat = PdfPageFormat(226, double.infinity, marginAll: 5);

      // 3. Imprimer directement sur ce format
      await Printing.layoutPdf(
        name: 'Facture N° ${vente.venteId}',
        format: thermalFormat, // Important: spécifier le format ici
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
      print('Facture N° ${vente.venteId} envoyée à l\'imprimante thermique.');
    } catch (e) {
      print('Erreur d\'impression: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'impression : $e')),
        );
      }
    }
  }

  // --- Valider vente (le chef d'orchestre) ---
  Future<void> validateSale() async {
    if (selectedClient == null || cart.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez sélectionner un client et ajouter des produits au panier.")),
        );
      }
      return;
    }

    final client = selectedClient!;

    // ⚙️ Vérification des stocks : SÉCURITÉ
    for (var item in cart) {
      final stockDispo = item.produit.quantiteActuelle ?? 0;
      if (item.quantity > stockDispo) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Stock insuffisant pour ${item.produit.nom}. Stock disponible: $stockDispo")),
          );
        }
        return;
      }
    }

    // Création de la vente pour l'enregistrement
    final vente = createVente(isDraft: false);
    final lignes = createLignes(vente);

    // 1. Insertion en BDD (qui inclut la déduction de stock)
    await db.insertVenteTransaction(vente: vente, lignesVente: lignes);

    // 2. Mettre à jour le compteur après une insertion réussie
    await _loadSalesCounter();

    // 3. Génération et impression
    // On génère la version A4 pour l'archivage local
    final pdfA4Bytes = await _generatePdfBytes(vente, lignes, client, false);
    await savePdfLocally(pdfA4Bytes, 'facture_${vente.venteId}');

    // On imprime la version THERMIQUE stabilisée
    await printOrPreviewThermalPdf(vente, lignes, client);


    // 4. Réinitialisation
    if (mounted) {
      setState(() {
        cart.clear();
        selectedClient = null;
        _showClientSuggestions = false;
        _showProductSuggestions = false;
        clientSearchController.clear();
        productSearchController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vente validée et Reçu Thermique imprimé !")));
    }
  }


  // --- Widgets d'aide ---
  Widget _buildClientSuggestions(double maxHeight) {
    if (!_showClientSuggestions || filteredClients.isEmpty) {
      return const SizedBox.shrink();
    }
    final height = filteredClients.length > 6 ? maxHeight : filteredClients.length * 56.0;
    // On conserve la structure de la suggestion pour qu'elle soit superposée et nette
    return Container(
      constraints: BoxConstraints(maxHeight: height),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade200), // Bordure plus douce
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black26.withOpacity(0.1), blurRadius: 10)], // Ombre plus prononcée pour l'effet "flottant"
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: filteredClients.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 8, endIndent: 8),
        itemBuilder: (context, idx) {
          final c = filteredClients[idx];
          return ListTile(
            title: Text(c.nomClient ?? 'Client sans nom'),
            subtitle: Text(c.telephone ?? 'N/A'),
            onTap: () {
              setState(() {
                selectedClient = c;
                clientSearchController.text = c.nomClient ?? '';
                _showClientSuggestions = false;
                filteredClients = List<Client>.from(clients);
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildProductSuggestions(double maxHeight) {
    // Similaire au widget client
    if (!_showProductSuggestions || filteredProducts.isEmpty) {
      return const SizedBox.shrink();
    }
    final height = filteredProducts.length > 6 ? maxHeight : filteredProducts.length * 56.0;
    return Container(
      constraints: BoxConstraints(maxHeight: height),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade200),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black26.withOpacity(0.1), blurRadius: 10)],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: filteredProducts.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 8, endIndent: 8),
        itemBuilder: (context, idx) {
          final p = filteredProducts[idx];
          // Vérification du stock pour l'affichage (alerte orange si stock < 5, même si vente autorisée)
          final stockDispo = p.quantiteActuelle ?? 0;
          final stockColor = stockDispo <= 0 ? Colors.red : (stockDispo < 5 ? Colors.orange : Colors.green);
          final stockText = stockDispo <= 0 ? 'RUPTURE' : 'Stock: $stockDispo';
          final isOutOfStock = stockDispo <= 0;

          return ListTile(
            leading: p.imagePath != null && p.imagePath!.isNotEmpty ? SizedBox(width: 40, height: 40, child: Image.network(p.imagePath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))) : const Icon(Icons.inventory_2),
            title: Text(p.nom ?? ''),
            subtitle: Text('Prix: ${p.prix?.toStringAsFixed(0) ?? '0'} FC - $stockText', style: TextStyle(color: stockColor, fontWeight: FontWeight.bold)),
            trailing: isOutOfStock ? const Icon(Icons.warning, color: Colors.red) : null,
            onTap: isOutOfStock ? null : () {
              addProductToCart(p);
            },
            tileColor: isOutOfStock ? Colors.grey[100] : null,
          );
        },
      ),
    );
  }

  // WIDGET: envelopper les sections dans des Cartes
  Widget _buildSectionCard({required String title, required Widget content, EdgeInsets? padding, Color? color}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // Retiré la marge du bas ici pour mieux gérer l'espacement dans la Row
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color ?? Colors.blueGrey.shade700,
              ),
            ),
            const Divider(height: 20, color: Colors.blueGrey),
            content,
          ],
        ),
      ),
    );
  }

  // WIDGET: afficher les totaux
  Widget _buildTotalsDisplay(Vente? vente) {
    if (vente == null) {
      return const Center(child: Text("Ajouter des articles pour voir les totaux.", style: TextStyle(fontSize: 16, color: Colors.grey)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Total Brut
        _buildTotalLine("Total Brut", total, Colors.blueGrey.shade700, false),
        // Réduction
        _buildTotalLine("Réduction (6%)", vente.reductionPercent, Colors.red, false),
        const Divider(color: Colors.black, thickness: 1.5, height: 10),
        // Total Net
        _buildTotalLine("TOTAL À PAYER", vente.totalNet, Colors.green.shade700, true),
      ],
    );
  }

  // Widget utilitaire pour une ligne de total
  Widget _buildTotalLine(String label, double amount, Color color, bool isBig) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$label :',
            style: TextStyle(
              fontSize: isBig ? 20 : 16,
              fontWeight: isBig ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${amount.toStringAsFixed(0)} FC',
            style: TextStyle(
              fontSize: isBig ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET pour les boutons de validation (ancre fixe)
  Widget _buildValidationButtons(bool canValidate, Vente? vente, List<LigneVente>? lignes, Client? client) {
    return Container(
      // Zone fixe en bas de l'écran, avec une ombre pour la surélever
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, -5), // Ombre vers le haut
          ),
        ],
      ),
      padding: const EdgeInsets.only(top: 15, bottom: 25, left: 16, right: 16),
      width: double.infinity,
      child: SafeArea( // S'assure de ne pas chevaucher les barres de navigation du système
        child: Center(
          child: ConstrainedBox( // Limite la largeur des boutons sur grand écran
            constraints: const BoxConstraints(maxWidth: 800),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Bouton 1: Aperçu A4
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text("Aperçu Facture", overflow: TextOverflow.ellipsis),
                    onPressed: canValidate ? () => _previewPdf(vente!, lignes!, client!) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      textStyle: const TextStyle(fontSize: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Bouton 2: Valider et Imprimer (Action Principale)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("VALIDER ET IMPRIMER LA VENTE", overflow: TextOverflow.ellipsis),
                    onPressed: canValidate ? validateSale : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // On augmente un peu la taille du container pour mieux profiter de l'écran
    final containerWidth = screenWidth > 900 ? 900.0 : screenWidth * 0.95;
    final suggestionMaxHeight = 350.0;

    // Détermination de l'état de validation
    final canValidate = selectedClient != null && cart.isNotEmpty;
    final tempVente = canValidate ? createVente(isDraft: true) : null;
    final tempLignes = canValidate ? createLignes(tempVente!) : null;
    final client = selectedClient;

    // Hauteur estimée de la barre d'actions fixes + padding
    const double fixedButtonHeight = 110.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouvelle Vente"),
        centerTitle: true,
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoriqueVentes()),
              );
            },
            tooltip: "Historique des ventes",
          ),
        ],
      ),
      body: Container(
        color: Colors.blueGrey.shade50,
        child: Stack(
          children: [
            // 1. Contenu défilant
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, fixedButtonHeight),
                child: Center(
                  child: SizedBox(
                    width: containerWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // 1. SECTION CLIENT
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: _buildSectionCard(
                            title: '1. Sélectionner ou ajouter un Client',
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Champ de recherche Client
                                TextField(
                                  controller: clientSearchController,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search),
                                    hintText: selectedClient == null ? 'Rechercher un client (nom ou téléphone)' : selectedClient!.nomClient,
                                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                    suffixIcon: selectedClient != null ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          selectedClient = null;
                                          clientSearchController.clear();
                                          _showClientSuggestions = false;
                                        });
                                      },
                                    ) : null,
                                  ),
                                  onChanged: filterClients,
                                  onTap: () {
                                    if (clientSearchController.text.isNotEmpty) setState(() => _showClientSuggestions = true);
                                  },
                                ),
                                // suggestions
                                _buildClientSuggestions(suggestionMaxHeight),
                                const SizedBox(height: 8),

                                // NOUVEAU CLIENT toggle
                                TextButton.icon(
                                  icon: Icon(showNewClientForm ? Icons.close : Icons.person_add, color: Colors.blue),
                                  label: Text(showNewClientForm ? "Annuler l'ajout d'un client" : "Ajouter un nouveau client", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                                  onPressed: () => setState(() => showNewClientForm = !showNewClientForm),
                                ),

                                if (showNewClientForm) ...[
                                  const SizedBox(height: 12),
                                  TextField(controller: nameController, decoration: InputDecoration(labelText: "Nom du client", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                                  const SizedBox(height: 8),
                                  TextField(controller: phoneController, decoration: InputDecoration(labelText: "Téléphone", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))), keyboardType: TextInputType.phone),
                                  const SizedBox(height: 8),
                                  TextField(controller: addressController, decoration: InputDecoration(labelText: "Adresse", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)))),
                                  const SizedBox(height: 16),
                                  Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(
                                    icon: const Icon(Icons.check),
                                    label: const Text("Ajouter client"),
                                    onPressed: addClient,
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                  )),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // NOUVEAU BLOC: Sections 2 et 3 sur la même ligne (Row)
                        // On n'applique pas de Row sur les petits écrans pour rester lisible (mobile-first)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 600) {
                              // Affichage en colonne pour les petits écrans
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10.0),
                                    child: _buildSectionCard(
                                      title: '2. Mode de Paiement',
                                      content: DropdownButtonFormField<String>(
                                        value: _modePaiement,
                                        items: ['CASH', 'TRANSFERT', 'CRÉDIT']
                                            .map((label) => DropdownMenuItem(value: label, child: Text(label, style: const TextStyle(fontSize: 16))))
                                            .toList(),
                                        onChanged: (value) {
                                          if (value != null) setState(() => _modePaiement = value);
                                        },
                                        decoration: const InputDecoration(
                                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10.0),
                                    child: _buildSectionCard(
                                      title: '3. Sélectionner des produits',
                                      content: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TextField(
                                                  controller: productSearchController,
                                                  decoration: InputDecoration(
                                                      prefixIcon: const Icon(Icons.search),
                                                      hintText: 'Rechercher un produit',
                                                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))
                                                  ),
                                                  onChanged: filterProducts,
                                                  onTap: () {
                                                    if (productSearchController.text.isNotEmpty) setState(() => _showProductSuggestions = true);
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  color: Colors.blueGrey.shade100,
                                                ),
                                                child: IconButton(
                                                  icon: Icon(Icons.qr_code_scanner, color: Colors.blueGrey.shade700),
                                                  onPressed: () {/* TODO: scanner */},
                                                  tooltip: "Scanner le code-barres",
                                                ),
                                              ),
                                            ],
                                          ),
                                          _buildProductSuggestions(suggestionMaxHeight),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              // Affichage en Row (Ligne) pour les grands écrans
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 2. SECTION PAIEMENT (Expanded pour prendre 50% de l'espace)
                                    Expanded(
                                      child: _buildSectionCard(
                                        title: '2. Mode de Paiement',
                                        content: DropdownButtonFormField<String>(
                                          value: _modePaiement,
                                          items: ['CASH', 'TRANSFERT', 'CRÉDIT']
                                              .map((label) => DropdownMenuItem(value: label, child: Text(label, style: const TextStyle(fontSize: 16))))
                                              .toList(),
                                          onChanged: (value) {
                                            if (value != null) setState(() => _modePaiement = value);
                                          },
                                          decoration: const InputDecoration(
                                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 15), // Espace entre les deux cartes

                                    // 3. SECTION PRODUIT (Expanded pour prendre 50% de l'espace)
                                    Expanded(
                                      child: _buildSectionCard(
                                        title: '3. Sélectionner des produits',
                                        content: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextField(
                                                    controller: productSearchController,
                                                    decoration: InputDecoration(
                                                        prefixIcon: const Icon(Icons.search),
                                                        hintText: 'Rechercher un produit',
                                                        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))
                                                    ),
                                                    onChanged: filterProducts,
                                                    onTap: () {
                                                      if (productSearchController.text.isNotEmpty) setState(() => _showProductSuggestions = true);
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Container(
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                    color: Colors.blueGrey.shade100,
                                                  ),
                                                  child: IconButton(
                                                    icon: Icon(Icons.qr_code_scanner, color: Colors.blueGrey.shade700),
                                                    onPressed: () {/* TODO: scanner */},
                                                    tooltip: "Scanner le code-barres",
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // La suggestion doit rester visible même si elle est dans une carte
                                            _buildProductSuggestions(suggestionMaxHeight),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),

                        // 4. SECTION PANIER et TOTAUX
                        _buildSectionCard(
                          title: '4. Panier et Totaux',
                          content: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // PANIER TABLEAU
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columnSpacing: 18,
                                  headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade50),
                                  columns: const [
                                    DataColumn(label: Text("Produit", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Prix", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Stock", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Qté", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("S.total", style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: cart.map((item) {
                                    final stockDispo = item.produit.quantiteActuelle ?? 0;
                                    final stockColor = stockDispo <= 0 ? Colors.red : (stockDispo < 5 ? Colors.orange : Colors.green);
                                    return DataRow(cells: [
                                      DataCell(Text(item.produit.nom ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                                      DataCell(Text("${item.produit.prix?.toStringAsFixed(0) ?? '0'} F")),
                                      DataCell(Text(stockDispo.toString(), style: TextStyle(color: stockColor, fontWeight: FontWeight.bold))),
                                      DataCell(Text("${item.quantity}")),
                                      DataCell(Text("${((item.produit.prix ?? 0) * item.quantity).toStringAsFixed(0)} F", style: const TextStyle(fontWeight: FontWeight.bold))),
                                      DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Boutons d'ajustement de quantité
                                          SizedBox(
                                            width: 32, height: 32,
                                            child: IconButton(
                                              icon: const Icon(Icons.remove, size: 18),
                                              onPressed: () => updateQuantity(item, -1),
                                            ),
                                          ),
                                          // Bouton d'ajout (avec vérification stock pour +1)
                                          SizedBox(
                                            width: 32, height: 32,
                                            child: IconButton(
                                              icon: const Icon(Icons.add, size: 18),
                                              // Autoriser l'ajout tant que la quantité actuelle est strictement inférieure au stock disponible
                                              onPressed: item.quantity < stockDispo ? () => updateQuantity(item, 1) : null,
                                              color: item.quantity < stockDispo ? Colors.green : Colors.grey,
                                            ),
                                          ),
                                          // Bouton Supprimer Ligne
                                          SizedBox(
                                            width: 32, height: 32,
                                            child: IconButton(
                                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                              onPressed: () => updateQuantity(item, -item.quantity),
                                            ),
                                          ),
                                        ],
                                      )),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                              // --- FIN PANIER TABLEAU ---
                              const SizedBox(height: 15),
                              // RAPPEL TOTAUX
                              _buildTotalsDisplay(tempVente),
                            ],
                          ),
                        ),

                        // Espaceur final
                        const SizedBox(height: 10),

                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Barre d'actions fixe (Positionnée en bas)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildValidationButtons(canValidate, tempVente, tempLignes, client),
            ),
          ],
        ),
      ),
    );
  }
}
