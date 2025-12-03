import 'package:factura/DashboardVendor/panier_formulaire.dart';
import 'package:factura/Modeles/model_clients.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:factura/Modeles/model_proforma.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/service_pdf.dart' as pdf_service;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:printing/printing.dart';

// Classe CartItem locale si elle n'est pas importée depuis un fichier modèle commun

class EnregistrementProForma extends StatefulWidget {
  const EnregistrementProForma({super.key});

  @override
  State<EnregistrementProForma> createState() => _EnregistrementProFormaState();
}

class _EnregistrementProFormaState extends State<EnregistrementProForma> {
  final db = DatabaseService.instance;

  // --- VARIABLES D'ÉTAT CLIENT ---
  List<Client> clients = [];
  Client? selectedClient;
  final TextEditingController clientSearchController = TextEditingController();
  List<Client> filteredClients = [];
  bool _showClientSuggestions = false;

  // [NOUVEAU] Variables pour le formulaire "Nouveau Client"
  bool showNewClientForm = false;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // --- VARIABLES D'ÉTAT PRODUITS & PANIER ---
  List<Produit> produits = [];
  List<Produit> filteredProducts = [];
  final TextEditingController productSearchController = TextEditingController();
  bool _showProductSuggestions = false;
  List<CartItem> cart = [];

  // --- VARIABLES D'ÉTAT TRANSACTION ---
  double _currentExchangeRate = 0.0;
  String _deviseSelected = 'CDF';
  // ignore: unused_field
  final List<String> _deviseOptions = ['CDF', 'USD'];
  String _modePaiement = 'A CREDIT';

  int _salesCounter = 0;

  @override
  void initState() {
    super.initState();
    _loadData();

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
    // Nettoyage des contrôleurs
    clientSearchController.dispose();
    productSearchController.dispose();
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final totalSales = await db.getTotalVentesCount();
    final realRate = await db.getLatestExchangeRate();
    await loadClients();
    await loadProducts();

    if (mounted) {
      setState(() {
        _salesCounter = totalSales;
        _currentExchangeRate = realRate ?? 1.0;
      });
    }
  }

  // --- LOGIQUE DE SÉLECTION ET AJOUT DE CLIENT ---

  Future<void> loadClients() async {
    final list = await db.getAllClients();
    if (mounted) {
      setState(() {
        clients = list;
        filteredClients = list;
      });
    }
  }

  void filterClients(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredClients = clients;
        _showClientSuggestions = false;
      } else {
        filteredClients = clients.where((client) =>
        (client.nomClient?.toLowerCase().contains(query.toLowerCase()) ?? false) ||
            (client.telephone?.contains(query) ?? false)
        ).toList();
        _showClientSuggestions = filteredClients.isNotEmpty;
      }
    });
  }

  void selectClient(Client client) {
    setState(() {
      selectedClient = client;
      clientSearchController.text = client.nomClient ?? '';
      _showClientSuggestions = false;
      showNewClientForm = false; // Fermer le formulaire si on sélectionne un existant
    });
  }

  // [NOUVEAU] Fonction pour ajouter un client rapidement
  Future<void> addClient() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le nom du client est obligatoire')));
      return;
    }

    final newClient = Client(
      nomClient: name,
      telephone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
      adresse: addressController.text.trim().isEmpty ? null : addressController.text.trim(),
    );

    try {
      // Insertion en BDD
      final localId = await db.insertClient(newClient);

      // Rechargement de la liste
      await loadClients();

      // Sélection automatique du nouveau client
      // On cherche le client qu'on vient d'ajouter (par ID ou par nom si ID pas retourné)
      final justAdded = clients.firstWhere(
              (c) => c.localId == localId,
          orElse: () => clients.last // Fallback
      );

      if (!mounted) return;
      setState(() {
        showNewClientForm = false;
        selectedClient = justAdded;
        clientSearchController.text = selectedClient?.nomClient ?? '';
        _showClientSuggestions = false;

        // Vider les champs
        nameController.clear();
        phoneController.clear();
        addressController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Client ajouté avec succès !')));

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur ajout client: $e')));
    }
  }

  // --- LOGIQUE DE PRODUITS ET PANIER ---

  Future<void> loadProducts() async {
    final list = await db.getAllProduits();
    if (mounted) {
      setState(() => produits = list);
    }
  }

  void filterProducts(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredProducts = [];
        _showProductSuggestions = false;
      } else {
        filteredProducts = produits.where((p) =>
            p.nom!.toLowerCase().contains(query.toLowerCase())
        ).toList();
        _showProductSuggestions = filteredProducts.isNotEmpty;
      }
    });
  }

  void addProductToCart(Produit produit) {
    int existingIndex = cart.indexWhere((item) => item.produit.localId == produit.localId);
    final maxQuantity = produit.quantiteActuelle ?? 0;

    if (existingIndex != -1) {
      if (cart[existingIndex].quantity < maxQuantity) {
        setState(() {
          cart[existingIndex].quantity++;
          productSearchController.clear();
          _showProductSuggestions = false;
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock maximum atteint.")));
      }
    } else {
      if (maxQuantity > 0) {
        setState(() {
          cart.add(CartItem(produit: produit, quantity: 1));
          productSearchController.clear();
          _showProductSuggestions = false;
        });
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Produit en rupture de stock.")));
      }
    }
  }

  void updateQuantity(CartItem item, int delta) {
    setState(() {
      final newQuantity = item.quantity + delta;
      if (newQuantity <= 0) {
        cart.remove(item);
      } else {
        final maxQuantity = item.produit.quantiteActuelle ?? 0;
        if (newQuantity <= maxQuantity) {
          item.quantity = newQuantity;
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Stock maximum atteint pour ce produit.")),
            );
          }
        }
      }
    });
  }


  // --- LOGIQUE DE PRO-FORMA ---

  double get total => cart.fold(0, (sum, item) => sum + (item.produit.prix ?? 0.0) * (item.quantity));
  double get discountAmount => total * 0.06;
  double get netToPay => total - discountAmount;

  ProForma createProFormaModel() {
    final sequence = (_salesCounter + 1).toString().padLeft(3, '0');
    final newProFormaId = 'PF-${DateTime.now().year}-$sequence';

    return ProForma(
      proFormaId: newProFormaId,
      dateCreation: DateTime.now().toIso8601String(),
      clientLocalId: selectedClient!.localId!,
      vendeurNom: 'Vendeur',
      modePaiement: _modePaiement,
      deviseTransaction: _deviseSelected,
      tauxDeChange: _currentExchangeRate,
      totalBrut: total,
      reductionPercent: discountAmount,
      totalNet: netToPay,
    );
  }

  List<LigneProForma> createLignesProForma(ProForma proForma) {
    return cart.map((item) {
      final prixUnitaireUSD = item.produit.prix ?? 0.0;
      return LigneProForma(
        ligneProFormaId: const Uuid().v4(),
        proFormaLocalId: proForma.localId ?? 0,
        produitLocalId: item.produit.localId!,
        nomProduit: item.produit.nom!,
        prixVenteUnitaire: prixUnitaireUSD,
        quantite: item.quantity,
        sousTotal: prixUnitaireUSD * item.quantity,
      );
    }).toList();
  }


  Future<void> validateProForma() async {
    if (selectedClient == null || cart.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez sélectionner un client et ajouter des produits au panier.")),
        );
      }
      return;
    }

    final client = selectedClient!;
    final proForma = createProFormaModel();
    final lignes = createLignesProForma(proForma);

    // Insertion en BDD (Assurez-vous que la méthode existe dans DatabaseService)
    await db.insertProForma(proForma, lignes);

    // Génération PDF
    final pdfProFormaData = pdf_service.PdfVente(
      venteId: proForma.proFormaId,
      dateVente: proForma.dateCreation,
      vendeurNom: proForma.vendeurNom ?? '---',
      modePaiement: proForma.modePaiement ?? _modePaiement,
      totalBrut: proForma.totalBrut,
      montantReduction: proForma.reductionPercent,
      totalNet: proForma.totalNet,
    );

    final pdfLignes = lignes.map((l) => pdf_service.PdfLigneVente(
      nomProduit: l.nomProduit,
      prixVenteUnitaire: l.prixVenteUnitaire,
      quantite: l.quantite,
      sousTotal: l.sousTotal,
    )).toList();

    final pdfClientData = pdf_service.PdfClient(
      nomClient: client.nomClient ?? 'Client Inconnu',
      telephone: client.telephone,
      adresse: client.adresse,
    );

    final doc = await pdf_service.generatePdfA4(pdfProFormaData, pdfLignes, pdfClientData);

    await Printing.sharePdf(bytes: await doc.save(), filename: 'proforma_${proForma.proFormaId}.pdf');

    if (mounted) {
      setState(() {
        cart.clear();
        selectedClient = null;
        clientSearchController.clear();
        _salesCounter++;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pro-Forma créée et partagée (Stock inchangé).")));
    }
  }

  // --- WIDGETS D'AIDE (MODIFIÉ AVEC AJOUT CLIENT) ---

  Widget _buildClientSelection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. Sélection du Client', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey.shade700)),
            const Divider(height: 20, color: Colors.blueGrey),

            // Zone de Recherche
            TextField(
              controller: clientSearchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_search),
                hintText: selectedClient == null ? 'Rechercher un client par nom/téléphone' : selectedClient!.nomClient,
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

            // Liste de suggestions
            if (_showClientSuggestions)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                margin: const EdgeInsets.only(top: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filteredClients.length,
                  itemBuilder: (context, index) {
                    final client = filteredClients[index];
                    return ListTile(
                      title: Text(client.nomClient ?? 'Client sans nom'),
                      subtitle: Text(client.telephone ?? 'N/A'),
                      onTap: () => selectClient(client),
                    );
                  },
                ),
              ),

            const SizedBox(height: 10),

            // [NOUVEAU] BOUTON POUR BASCULER LE FORMULAIRE NOUVEAU CLIENT
            TextButton.icon(
              icon: Icon(showNewClientForm ? Icons.close : Icons.person_add, color: Colors.blue),
              label: Text(
                  showNewClientForm ? "Annuler l'ajout" : "Ajouter un nouveau client",
                  style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)
              ),
              onPressed: () => setState(() => showNewClientForm = !showNewClientForm),
            ),

            // [NOUVEAU] FORMULAIRE D'AJOUT (VISIBLE SI showNewClientForm est TRUE)
            if (showNewClientForm) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  children: [
                    TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: "Nom du client *", filled: true, fillColor: Colors.white)
                    ),
                    const SizedBox(height: 8),
                    TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(labelText: "Téléphone", filled: true, fillColor: Colors.white),
                        keyboardType: TextInputType.phone
                    ),
                    const SizedBox(height: 8),
                    TextField(
                        controller: addressController,
                        decoration: const InputDecoration(labelText: "Adresse", filled: true, fillColor: Colors.white)
                    ),
                    const SizedBox(height: 12),
                    Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.save),
                          label: const Text("Enregistrer et Sélectionner"),
                          onPressed: addClient,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        )
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const suggestionMaxHeight = 350.0;
    const fixedButtonHeight = 110.0;
    final canValidate = selectedClient != null && cart.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nouvelle Pro-Forma"),
        centerTitle: true,
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                "Taux: ${_currentExchangeRate.toStringAsFixed(2)}",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, fixedButtonHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. SECTION CLIENT (Avec formulaire embarqué)
                      _buildClientSelection(),

                      // 2. UTILISATION DU WIDGET RÉUTILISABLE
                      PanierFormulaire(
                        selectedClient: selectedClient,
                        cart: cart,
                        currentExchangeRate: _currentExchangeRate,
                        deviseSelected: _deviseSelected,
                        onAddProduct: addProductToCart,
                        onUpdateQuantity: updateQuantity,
                        onFilterProducts: filterProducts,
                        filteredProducts: filteredProducts,
                        showProductSuggestions: _showProductSuggestions,
                        suggestionMaxHeight: suggestionMaxHeight,
                        productSearchController: productSearchController,
                        modePaiement: _modePaiement,
                        canValidate: canValidate,
                        onValidateVente: validateProForma,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // BARRE D'ACTION FIXE
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, -5))],
              ),
              padding: const EdgeInsets.only(top: 15, bottom: 25, left: 16, right: 16),
              width: double.infinity,
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.description, size: 24),
                      label: const Text("ENREGISTRER ET PARTAGER LA PRO-FORMA", overflow: TextOverflow.ellipsis),
                      onPressed: canValidate ? validateProForma : null,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 6
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}