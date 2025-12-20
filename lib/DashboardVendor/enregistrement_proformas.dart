import 'package:factura/DashboardVendor/panier_formulaire.dart';
import 'package:factura/Modeles/model_clients.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:factura/Modeles/model_proforma.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/service_profoma_pdf.dart' as pdf_service;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:printing/printing.dart';

class EnregistrementProForma extends StatefulWidget {
  const EnregistrementProForma({super.key});

  @override
  State<EnregistrementProForma> createState() => _EnregistrementProFormaState();
}

class _EnregistrementProFormaState extends State<EnregistrementProForma> {
  final db = DatabaseService.instance;

  // --- CONTROLLERS ---
  final TextEditingController clientSearchController = TextEditingController();
  final TextEditingController productSearchController = TextEditingController();
  final TextEditingController _remiseController = TextEditingController(text: "0");

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  // --- ÉTAT ---
  List<Client> clients = [];
  List<Client> filteredClients = [];
  Client? selectedClient;
  bool _showClientSuggestions = false;
  bool showNewClientForm = false;

  List<Produit> produits = [];
  List<Produit> filteredProducts = [];
  bool _showProductSuggestions = false;
  List<CartItem> cart = [];

  double _currentExchangeRate = 0.0;
  String _modePaiement = 'CASH';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final realRate = await db.getLatestExchangeRate();
    final allClients = await db.getAllClients();
    final allProducts = await db.getAllProduits();
    if (mounted) {
      setState(() {
        clients = allClients;
        produits = allProducts;
        _currentExchangeRate = realRate ?? 1.0;
      });
    }
  }

  Future<void> addClient() async {
    if (nameController.text.isEmpty) return;

    final nouveau = Client(
      nomClient: nameController.text,
      telephone: phoneController.text,
      adresse: addressController.text,
    );

    await db.insertClient(nouveau);
    final allClients = await db.getAllClients();

    setState(() {
      clients = allClients;
      selectedClient = nouveau;
      clientSearchController.text = nouveau.nomClient!;
      showNewClientForm = false;
      nameController.clear();
      phoneController.clear();
      addressController.clear();
    });
  }

  double getPriceVenteFC(Produit p) => (p.prix ?? 0.0) * (_currentExchangeRate > 0 ? _currentExchangeRate : 1.0);
  double get total => cart.fold(0, (sum, item) => sum + (getPriceVenteFC(item.produit) * item.quantity));
  double get discountAmount => total * ((double.tryParse(_remiseController.text) ?? 0) / 100);
  double get netToPay => total - discountAmount;

  Future<void> validateProForma() async {
    // 1. Vérification de sécurité avant de commencer
    if (selectedClient == null) {
      debugPrint("Erreur : Aucun client sélectionné");
      return;
    }
    if (cart.isEmpty) {
      debugPrint("Erreur : Le panier est vide");
      return;
    }

    try {
      final now = DateTime.now();
      final String genId = 'PF-${now.year}${now.month}${now.day}-${now.hour}${now.minute}${now.second}';

      // 💡 On utilise 'selectedClient?.localId' avec une valeur par défaut (0) ou on gère l'absence
      final int clientID = selectedClient?.localId ?? 0;

      final proForma = ProForma(
        proFormaId: genId,
        dateCreation: now.toIso8601String(),
        clientLocalId: clientID, // On utilise la variable sécurisée
        vendeurNom: 'Vendeur',
        modePaiement: _modePaiement,
        deviseTransaction: 'FC',
        tauxDeChange: _currentExchangeRate,
        totalBrut: total,
        reductionPercent: (double.tryParse(_remiseController.text) ?? 0),
        totalNet: netToPay,
      );

      final lignes = cart.map((item) {
        // Sécurité sur l'ID du produit
        final int produitID = item.produit.localId ?? 0;

        return LigneProForma(
          ligneProFormaId: const Uuid().v4(),
          proFormaLocalId: 0,
          produitLocalId: produitID,
          nomProduit: item.produit.nom ?? "Produit sans nom",
          prixVenteUnitaire: getPriceVenteFC(item.produit),
          quantite: item.quantity,
          sousTotal: getPriceVenteFC(item.produit) * item.quantity,
        );
      }).toList();

      await db.insertProForma(proForma, lignes);

      final doc = await pdf_service.generatePdfA4(
        pdf_service.PdfVente(
            venteId: proForma.proFormaId,
            dateVente: proForma.dateCreation,
            vendeurNom: 'Vendeur',
            modePaiement: 'PRO-FORMA',
            totalBrut: total,
            montantReduction: discountAmount,
            totalNet: netToPay
        ),
        lignes.map((l) => pdf_service.PdfLigneVente(
            nomProduit: l.nomProduit,
            prixVenteUnitaire: l.prixVenteUnitaire,
            quantite: l.quantite,
            sousTotal: l.sousTotal
        )).toList(),
        pdf_service.PdfClient(
            nomClient: selectedClient?.nomClient ?? "Client inconnu",
            telephone: selectedClient?.telephone
        ),
      );

      await Printing.sharePdf(bytes: await doc.save(), filename: '${proForma.proFormaId}.pdf');

      if (mounted) {
        setState(() => cart.clear());
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Erreur validation réelle : $e");
    }
  }

  InputDecoration _proInput(String hint, IconData? icon) {
    return InputDecoration(
      prefixIcon: icon != null ? Icon(icon, color: Colors.blueGrey, size: 18) : null,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade200)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double contentWidth = screenWidth > 1000 ? screenWidth * 0.5 : screenWidth * 0.95;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F4),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text("NOUVELLE PRO-FORMA", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: Text("${netToPay.toStringAsFixed(0)} FC", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),

      // 1. Le corps contient uniquement le formulaire défilant
      body: Center(
        child: SizedBox(
          width: contentWidth,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), // On laisse de la place en bas pour le bouton
            child: Column(
              children: [
                _buildSectionCard(
                  title: "INFOS CLIENT & PAIEMENT",
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: clientSearchController,
                              decoration: _proInput("Sélectionner un client...", Icons.person_outline).copyWith(
                                suffixIcon: IconButton(
                                  icon: Icon(showNewClientForm ? Icons.remove_circle : Icons.add_circle, color: Colors.blue),
                                  onPressed: () => setState(() => showNewClientForm = !showNewClientForm),
                                ),
                              ),
                              onChanged: (v) => setState(() {
                                filteredClients = clients.where((c) => c.nomClient!.toLowerCase().contains(v.toLowerCase())).toList();
                                _showClientSuggestions = v.isNotEmpty;
                              }),
                            ),
                          ),
                          const SizedBox(width: 15),
                          _buildPaymentToggle(),
                        ],
                      ),
                      if (showNewClientForm) _buildCompactNewClientForm(),
                      if (_showClientSuggestions && !showNewClientForm) _buildClientSuggestionsList(),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                _buildSectionCard(
                  title: "AJOUTER DES PRODUITS",
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: productSearchController,
                          decoration: _proInput("Rechercher un article...", Icons.search),
                          onChanged: (v) => setState(() {
                            filteredProducts = produits.where((p) => p.nom!.toLowerCase().contains(v.toLowerCase())).toList();
                            _showProductSuggestions = v.isNotEmpty;
                          }),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _remiseController,
                          textAlign: TextAlign.center,
                          decoration: _proInput("%", null),
                          onChanged: (v) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const CircleAvatar(backgroundColor: Colors.black, radius: 25, child: Icon(Icons.qr_code_scanner, color: Colors.white)),
                    ],
                  ),
                ),
                if (_showProductSuggestions) _buildProductSuggestionsList(),
                const SizedBox(height: 15),

                // Ici on affiche le tableau du panier (il est dans la zone scrollable)
                _buildSectionCard(
                  title: "CONTENU DU PANIER",
                  child: PanierFormulaire(
                    selectedClient: selectedClient,
                    cart: cart,
                    currentExchangeRate: _currentExchangeRate,
                    deviseSelected: 'FC',
                    onUpdateQuantity: (item, delta) => setState(() { item.quantity += delta; if (item.quantity <= 0) cart.remove(item); }),
                    modePaiement: _modePaiement,
                    remiseSaisie: discountAmount,
                    canValidate: (selectedClient != null && cart.isNotEmpty),
                    onValidateVente: validateProForma,
                    //isProformaView: true, // Optionnel selon ton composant
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // 2. LE BOUTON FIXÉ EN BAS (Modifié pour le changement de couleur)
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: contentWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Builder(
                  builder: (context) {
                    // On définit la condition de validation
                    final bool isReady = selectedClient != null && cart.isNotEmpty;

                    return ElevatedButton.icon(
                      onPressed: isReady ? validateProForma : null,
                      icon: Icon(
                        Icons.check_circle_outline,
                        // L'icône devient blanche quand c'est prêt
                        color: isReady ? Colors.white : Colors.black54,
                      ),
                      label: Text(
                        "ENREGISTRER LA PRO-FORMA",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          // Le texte devient blanc quand c'est prêt
                          color: isReady ? Colors.white : Colors.black54,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        // 🔥 ICI : Si isReady est vrai -> Vert, sinon -> Gris
                        backgroundColor: isReady ? Colors.green : const Color(0xFFEEEEEE),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: isReady ? 4 : 0, // Un peu d'ombre quand c'est actif
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }

  Widget _buildCompactNewClientForm() {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Row(
        children: [
          Expanded(child: TextField(controller: nameController, decoration: _proInput("Nom", null))),
          const SizedBox(width: 5),
          Expanded(child: TextField(controller: phoneController, decoration: _proInput("Tél", null))),
          const SizedBox(width: 5),
          Expanded(child: TextField(controller: addressController, decoration: _proInput("Adresse", null))),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: addClient,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 20)),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentToggle() {
    return Row(children: ["CASH", "CRÉDIT"].map((m) => GestureDetector(
      onTap: () => setState(() => _modePaiement = m),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: _modePaiement == m ? const Color(0xFFEDE7F6) : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _modePaiement == m ? const Color(0xFF673AB7) : Colors.grey.shade300),
        ),
        child: Text(m, style: TextStyle(color: _modePaiement == m ? const Color(0xFF673AB7) : Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    )).toList());
  }

  Widget _buildClientSuggestionsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      child: ListView(shrinkWrap: true, children: filteredClients.map((c) => ListTile(
        title: Text(c.nomClient!, style: const TextStyle(fontSize: 13)),
        onTap: () => setState(() { selectedClient = c; clientSearchController.text = c.nomClient!; _showClientSuggestions = false; }),
      )).toList()),
    );
  }

  Widget _buildProductSuggestionsList() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200)),
      child: ListView.builder(shrinkWrap: true, itemCount: filteredProducts.length, itemBuilder: (context, index) {
        final p = filteredProducts[index];
        return ListTile(title: Text(p.nom!), subtitle: Text("${getPriceVenteFC(p)} FC"), onTap: () => setState(() {
          int idx = cart.indexWhere((item) => item.produit.localId == p.localId);
          if (idx != -1) { cart[idx].quantity++; } else { cart.add(CartItem(produit: p, quantity: 1)); }
          productSearchController.clear(); _showProductSuggestions = false;
        }));
      }),
    );
  }
}