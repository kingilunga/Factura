import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:factura/DashboardVendor/historique_ventes.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/model_clients.dart';
import 'package:factura/database/model_produits.dart';
import 'package:factura/database/model_ventes.dart';
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


  // --- Initialisation et Nettoyage ---

  @override
  void initState() {
    super.initState();
    loadClients();
    loadProducts();
    _loadSalesCounter(); // Charger le dernier compteur utilisé

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


  // --- Chargement et Filtrage (Reste inchangé) ---

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

  // --- Logique Panier et Client (Reste inchangé) ---

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
    setState(() {
      final index = cart.indexWhere((c) => c.produit.localId == produit.localId);
      if (index >= 0) {
        cart[index].quantity += 1;
      } else {
        cart.add(CartItem(produit: produit));
      }
      productSearchController.clear();
      _showProductSuggestions = false;
      filteredProducts = List<Produit>.from(produits);
    });
  }

  void updateQuantity(CartItem item, int delta) {
    setState(() {
      item.quantity += delta;
      if (item.quantity <= 0) cart.remove(item);
    });
  }

  // --- Calculs ---
  double get total => cart.fold(0, (sum, item) => sum + (item.produit.prix ?? 0) * item.quantity);
  double get discount => total * 0.002;
  double get netToPay => total - discount;

  // --- Création vente / lignes ---

  Vente createVente({bool isDraft = false}) {
    // ⚙️ NOUVELLE LOGIQUE POUR UN NUMÉRO SÉQUENTIEL SIMPLE (FV-001, FV-002...)
    // Si c'est un brouillon, on utilise un ID temporaire
    final sequence = (_salesCounter + (isDraft ? 1 : 1)).toString().padLeft(3, '0');
    final newVenteId = 'FV-$sequence';

    return Vente(
      venteId: newVenteId, // Numéro de facture simple
      dateVente: DateTime.now().toIso8601String(),
      clientLocalId: selectedClient!.localId!,
      vendeurNom: 'Vendeur',
      totalBrut: total,
      reductionPercent: discount,
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

  // --- Info Société (pour le PDF) ---
  pw.Widget buildCompanyInfo(pw.Context context) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Simuler un logo (on utilise un texte coloré ici, car les images sont complexes sans asset)
        pw.Text("LOGO", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.red)),
        pw.Text("Nom de votre société", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text("Adresse: 123 Rue de l'Exemple", style: const pw.TextStyle(fontSize: 8)),
        pw.Text("Tél: +243 000 000 000", style: const pw.TextStyle(fontSize: 8)),
        pw.Text("Email: contact@votreentreprise.cd", style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }


  // --- Générer PDF (Intégration Logo + Mention Légale) ---
  Future<pw.Document> generatePdf(Vente vente, List<LigneVente> lignes) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5, // Passage à un format A5 pour mieux intégrer les infos
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER (Logo + Infos Facture)
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  buildCompanyInfo(context),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("FACTURE N° ${vente.venteId}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red700)),
                      pw.SizedBox(height: 8),
                      pw.Text("Date: ${vente.dateVente.substring(0, 10)}", style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1),

              // Infos Client
              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text("Client: ${selectedClient?.nomClient ?? 'Anonyme'}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      if (selectedClient?.adresse != null && selectedClient!.adresse!.isNotEmpty) pw.Text("Adresse: ${selectedClient!.adresse!}"),
                      if (selectedClient?.telephone != null && selectedClient!.telephone!.isNotEmpty) pw.Text("Tél: ${selectedClient!.telephone!}"),
                    ]
                ),
              ),

              pw.SizedBox(height: 15),

              // Tableau des articles
              pw.Table.fromTextArray(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey600),
                cellStyle: const pw.TextStyle(fontSize: 9),
                rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // Produit
                  1: const pw.FlexColumnWidth(1), // Prix
                  2: const pw.FlexColumnWidth(1), // Quantité
                  3: const pw.FlexColumnWidth(1.5), // Sous-total
                },
                headers: ["Désignation", "Prix Unitaire (FC)", "Qté", "Montant (FC)"],
                data: lignes.map((c) => [
                  c.nomProduit,
                  c.prixVenteUnitaire.toStringAsFixed(0),
                  c.quantite.toString(),
                  c.sousTotal.toStringAsFixed(0),
                ]).toList(),
              ),
              pw.SizedBox(height: 10),

              // Totaux et Mentions
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Mention Légale
                  pw.Container(
                    width: PdfPageFormat.a5.width / 2.5,
                    padding: const pw.EdgeInsets.all(5),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red, width: 0.5)),
                    child: pw.Text(
                        "ATTENTION: Toutes marchandises vendues et vérifiées ne peuvent plus être retournées ni échangées.",
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.red800)
                    ),
                  ),

                  // Totaux
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      _buildTotalLine("Total Brut:", vente.totalBrut, PdfColors.black),
                      if (vente.reductionPercent > 0)
                        _buildTotalLine("Réduction (0.2%):", vente.reductionPercent, PdfColors.red),
                      pw.SizedBox(height: 5),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(5),
                        decoration: const pw.BoxDecoration(color: PdfColors.yellow200),
                        child: _buildTotalLine("NET À PAYER:", vente.totalNet, PdfColors.black, isBold: true, size: 12),
                      ),
                    ],
                  ),
                ],
              ),

              pw.Spacer(),
              pw.Center(child: pw.Text("Merci de votre confiance!",
                  style:  pw.TextStyle(fontSize: 9,
                      fontStyle: pw.FontStyle.italic))),
            ],
          );
        },
      ),
    );
    return pdf;
  }

  // Fonction d'aide pour les lignes de totaux
  pw.Widget _buildTotalLine(String label, double amount, PdfColor color, {bool isBold = false, double size = 9}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: size, color: color, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        pw.SizedBox(width: 5),
        pw.Text("${amount.toStringAsFixed(0)} FC", style: pw.TextStyle(fontSize: size, color: color, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ],
    );
  }


  // --- Sauvegarde PDF (Archivage, Reste inchangé) ---
  Future<void> savePdfLocally(pw.Document pdf, String fileName) async {
    try {
      final bytes = await pdf.save();
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

  // ⚙️ NOUVELLE FONCTION: Prévisualisation du PDF
  void _previewPdf(Vente vente, List<LigneVente> lignes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfPreviewPage(
          title: 'Facture N° ${vente.venteId}',
          generatePdf: (format) => generatePdf(vente, lignes).then((doc) => doc.save()),
        ),
      ),
    );
  }

  // ⚙️ FONCTION: Impression Directe
  Future<void> printOrPreviewPdf(pw.Document pdf, String venteId, {bool isPrinting = false}) async {
    try {
      if (isPrinting) {
        await Printing.layoutPdf(
          name: 'Reçu Vente N° $venteId',
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
        print('Facture N° $venteId envoyée à l\'imprimante.');
      }
    } catch (e) {
      print('Erreur d\'impression: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'impression : $e')),
        );
      }
    }
  }

  // --- Valider vente (le chef d'orchestre, Mise à jour pour impression) ---
  Future<void> validateSale() async {
    if (selectedClient == null || cart.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez sélectionner un client et ajouter des produits au panier.")),
        );
      }
      return;
    }

    // Vérification des stocks
    for (var item in cart) {
      final stockDispo = item.produit.quantiteActuelle ?? 0;
      if (item.quantity > stockDispo) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Stock insuffisant pour ${item.produit.nom}. Stock disponible: $stockDispo")),
          );
        }
        return; // Stop validation
      }
    }

    // Création de la vente pour l'enregistrement
    final vente = createVente(isDraft: false);
    final lignes = createLignes(vente);

    // 1. Insertion en BDD (qui inclut la déduction de stock)
    // Nous récupérons l'ID de la vente après l'insertion pour s'assurer que les lignes y sont liées correctement.
    await db.insertVenteTransaction(vente: vente, lignesVente: lignes);

    // 2. Mettre à jour le compteur après une insertion réussie
    await _loadSalesCounter();

    // 3. Génération et impression
    final pdf = await generatePdf(vente, lignes);
    await savePdfLocally(pdf, 'facture_${vente.venteId}');
    await printOrPreviewPdf(pdf, vente.venteId, isPrinting: true);

    // 4. Réinitialisation
    if (mounted) {
      setState(() {
        cart.clear();
        selectedClient = null;
        // On s'assure de masquer les suggestions après la vente
        _showClientSuggestions = false;
        _showProductSuggestions = false;
        clientSearchController.clear();
        productSearchController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vente validée et imprimée !")));
    }
  }


  // --- Widgets d'aide (Reste inchangé) ---
  Widget _buildClientSuggestions(double maxHeight) {
    if (!_showClientSuggestions || filteredClients.isEmpty) {
      return const SizedBox.shrink();
    }
    final height = filteredClients.length > 6 ? maxHeight : filteredClients.length * 56.0;
    return Container(
      constraints: BoxConstraints(maxHeight: height),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black26.withOpacity(0.03), blurRadius: 8)]),
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
    if (!_showProductSuggestions || filteredProducts.isEmpty) {
      return const SizedBox.shrink();
    }
    final height = filteredProducts.length > 6 ? maxHeight : filteredProducts.length * 56.0;
    return Container(
      constraints: BoxConstraints(maxHeight: height),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black26.withOpacity(0.03), blurRadius: 8)]),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: filteredProducts.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 8, endIndent: 8),
        itemBuilder: (context, idx) {
          final p = filteredProducts[idx];
          // Vérification du stock pour l'affichage
          final stockColor = (p.quantiteActuelle ?? 0) <= 0 ? Colors.red : ((p.quantiteActuelle ?? 0) < 5 ? Colors.orange : Colors.green);
          final stockText = (p.quantiteActuelle ?? 0) <= 0 ? 'RUPTURE' : 'Stock: ${p.quantiteActuelle}';
          final isOutOfStock = (p.quantiteActuelle ?? 0) <= 0;

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
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth > 650 ? 650.0 : screenWidth * 0.9;
    final suggestionMaxHeight = 300.0;

    // Détermination de l'état de validation
    final canValidate = selectedClient != null && cart.isNotEmpty;
    final tempVente = canValidate ? createVente(isDraft: true) : null;
    final tempLignes = canValidate ? createLignes(tempVente!) : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouvelle Vente"),
        centerTitle: true,
        backgroundColor: Colors.grey,
        actions: [
          // Option d'archivage PDF
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: canValidate ? () async {
              final pdf = await generatePdf(tempVente!, tempLignes!);
              await savePdfLocally(pdf, 'preview_${tempVente.venteId}');
            } : null,
            tooltip: "Archiver PDF (Prévisualisation)",
          ),
          // Navigation vers l'historique
          IconButton(
            icon: const Icon(Icons.history),
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: containerWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // CLIENT SEARCH
                          const Text('Client', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: clientSearchController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search),
                              hintText: selectedClient == null ? 'Rechercher un client (nom ou téléphone)' : selectedClient!.nomClient,
                              border: const OutlineInputBorder(),
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

                          // NEW CLIENT FORM toggle
                          TextButton.icon(
                            icon: Icon(showNewClientForm ? Icons.close : Icons.person_add),
                            label: Text(showNewClientForm ? "Annuler ajout" : "Nouveau client"),
                            onPressed: () => setState(() => showNewClientForm = !showNewClientForm),
                          ),
                          if (showNewClientForm) ...[
                            const SizedBox(height: 8),
                            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Nom du client", border: OutlineInputBorder())),
                            const SizedBox(height: 8),
                            TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Téléphone", border: OutlineInputBorder()), keyboardType: TextInputType.phone),
                            const SizedBox(height: 8),
                            TextField(controller: addressController, decoration: const InputDecoration(labelText: "Adresse", border: OutlineInputBorder())),
                            const SizedBox(height: 8),
                            Align(alignment: Alignment.centerRight, child: ElevatedButton.icon(icon: const Icon(Icons.check), label: const Text("Ajouter client"), onPressed: addClient)),
                          ],

                          const SizedBox(height: 16),

                          // PRODUCT SEARCH
                          const Text('Produit', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: productSearchController,
                                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher un produit (nom / catégorie)', border: OutlineInputBorder()),
                                  onChanged: filterProducts,
                                  onTap: () {
                                    if (productSearchController.text.isNotEmpty) setState(() => _showProductSuggestions = true);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(icon: const Icon(Icons.qr_code_scanner), onPressed: () {/* TODO: scanner */}),
                            ],
                          ),
                          _buildProductSuggestions(suggestionMaxHeight),

                          const SizedBox(height: 16),

                          // PANIER
                          const Text('Panier', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text("Produit")),
                                DataColumn(label: Text("Prix")),
                                DataColumn(label: Text("Stock")), // Ajout de la colonne stock
                                DataColumn(label: Text("Qté")),
                                DataColumn(label: Text("S.total")),
                                DataColumn(label: Text("Actions")),
                              ],
                              rows: cart.map((item) {
                                final stockDispo = item.produit.quantiteActuelle ?? 0;
                                final stockColor = stockDispo <= 0 ? Colors.red : (stockDispo < 5 ? Colors.orange : Colors.green);
                                return DataRow(cells: [
                                  DataCell(Text(item.produit.nom ?? '')),
                                  DataCell(Text("${item.produit.prix?.toStringAsFixed(0) ?? '0'} FC")),
                                  DataCell(Text(stockDispo.toString(), style: TextStyle(color: stockColor, fontWeight: FontWeight.bold))),
                                  DataCell(Text("${item.quantity}")),
                                  DataCell(Text("${((item.produit.prix ?? 0) * item.quantity).toStringAsFixed(0)} FC")),
                                  DataCell(Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Bouton Moins
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 20),
                                        onPressed: () => updateQuantity(item, -1),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      // Bouton Plus (limité au stock disponible)
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 20),
                                        onPressed: item.quantity < stockDispo ? () => updateQuantity(item, 1) : null,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      // Bouton Supprimer
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                        onPressed: () => setState(() => cart.remove(item)),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  )),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Totaux & validation
              Container(
                width: containerWidth,
                padding: const EdgeInsets.all(16),
                color: Colors.grey[200],
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text("Total Brut: ${total.toStringAsFixed(0)} FC", textAlign: TextAlign.right),
                    Text("Réduction (0.2%): ${discount.toStringAsFixed(0)} FC", textAlign: TextAlign.right, style: const TextStyle(color: Colors.red)),
                    Text("Net à payer: ${netToPay.toStringAsFixed(0)} FC", textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green)),
                    const SizedBox(height: 12),
                    // Ligne des actions
                    Row(
                      children: [
                        // Prévisualisation PDF
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.visibility),
                            label: const Text("Prévisualiser"),
                            onPressed: canValidate ? () => _previewPdf(tempVente!, tempLignes!) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Validation & Impression
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.print),
                            label: const Text("Valider et Imprimer"),
                            onPressed: canValidate ? validateSale : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canValidate ? Colors.blue : Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// NOUVELLE PAGE POUR AFFICHER LA PRÉVISUALISATION PDF
class PdfPreviewPage extends StatelessWidget {
  const PdfPreviewPage({
    super.key,
    required this.title,
    required this.generatePdf,
  });

  final String title;
  final Future<Uint8List> Function(PdfPageFormat format) generatePdf;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue,
      ),
      body: PdfPreview(
        build: generatePdf,
        allowPrinting: true, // Permet l'impression depuis la prévisualisation
        allowSharing: true,  // Permet le partage/l'export
        maxPageWidth: 700,
        canChangePageFormat: false,
        canChangeOrientation: false,
        pdfFileName: title.replaceAll(' ', '_') + '.pdf',
      ),
    );
  }
}
