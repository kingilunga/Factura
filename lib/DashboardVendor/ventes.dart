import 'package:factura/DashboardVendor/historique_ventes.dart';
import 'package:factura/DashboardVendor/pdf_preview.dart';
import 'package:factura/Modeles/model_clients.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:factura/Modeles/model_ventes.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/pdf_generator_service.dart' as pdf_service;
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

// --- Modèles de support pour ce fichier (essentiel) ---
class CartItem {
  Produit produit;
  int quantity;
  CartItem({required this.produit, this.quantity = 1});
}

// --- CLASSE PRINCIPALE ---
class EnregistrementVente extends StatefulWidget {
  // 1. On déclare la fonction comme une variable obligatoire
  final Function(int) onNavigate;

  // 2. On l'ajoute au constructeur (on retire le "void onNavigate" en bas)
  const EnregistrementVente({super.key, required this.onNavigate});


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
  // 🎯 AJOUT ICI : Le contrôleur pour la remise
  final TextEditingController _remiseController = TextEditingController(text: "0");
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

  // 💰 NOUVEAU : Taux de change USD vers FC (chargé de la BDD)
  double _currentExchangeRate = 0.0;

  // --- Initialisation et Nettoyage ---
  @override
  void initState() {
    super.initState();
    loadClients();
    loadProducts();
    // 💡 MODIFIÉ : Lance le chargement du compteur ET du taux
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
    _remiseController.dispose();
    clientSearchController.dispose();
    productSearchController.dispose();
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }
  // 💰 NOUVEAU : Fonction pour charger le taux de la BDD
  Future<void> _loadExchangeRate() async {
    final realRate = await db.getLatestExchangeRate();
    if (mounted) {
      setState(() {
        // Définit le taux réel ou 1.0 par défaut (USD = 1 FC) si le taux est inconnu
        _currentExchangeRate = realRate ?? 1.0;
      });
    }
  }

  Future<void> _loadSalesCounter() async {
    // Récupère le nombre de ventes déjà enregistrées pour initialiser le compteur
    final totalSales = await db.getTotalVentesCount();
    if (mounted) {
      setState(() {
        _salesCounter = totalSales;
      });
    }
    // 💡 AJOUT : Charge le taux de change juste après
    await _loadExchangeRate();
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
      final name = (c.nomClient ).toLowerCase();
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
      final name = (p.nom ).toLowerCase();
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

  // 💰 NOUVEAU : Conversion du Prix de Vente USD en FC
  double getPriceVenteFC(Produit produit) {
    // produit.prix est le prix de vente en USD
    // On multiplie par le taux chargé, ou par 1.0 si le taux est toujours à 0.0 (en attente)
    return (produit.prix ?? 0.0) * (_currentExchangeRate > 0.0 ? _currentExchangeRate : 1.0);
  }
  // ✅ Remplace le bloc du haut par celui-ci :
  double get total => cart.fold(0, (sum, item) => sum + getPriceVenteFC(item.produit) * item.quantity);
// 🎯 On lie enfin discountAmount à ton champ de texte (pourcentage)
  double get discountAmount {
    double pourcent = double.tryParse(_remiseController.text) ?? 0.0;
    return total * (pourcent / 100);
  }
  double get netToPay => total - discountAmount;

  // Dans _EnregistrementVenteState.createVente

  Vente createVente({bool isDraft = false}) {
    // ⚙️ LOGIQUE POUR UN NUMÉRO SÉQUENTIEL SIMPLE (FV-001, FV-002...)
    final sequence = (_salesCounter + (isDraft ? 1 : 1)).toString().padLeft(3, '0');
    final newVenteId = 'FV-$sequence';

    return Vente(
      venteId: newVenteId,
      dateVente: DateTime.now().toIso8601String(),
      clientLocalId: selectedClient!.localId!,
      vendeurNom: 'Vendeur',
      // ⭐️ CORRECTION : AJOUT DES DEUX CHAMPS MANQUANTS ⭐️
      deviseTransaction: 'FC', // Devise de la transaction finale
      modePaiement: _modePaiement, // 🎯 LIAISON DE LA VARIABLE D'ÉTAT !
      tauxDeChange: _currentExchangeRate, // Le taux chargé de la BDD (même s'il est 1.0)

      totalBrut: total,
      reductionPercent: discountAmount,
      totalNet: netToPay,
      statut: isDraft ? 'brouillon' : 'validée',
    );
  }

  List<LigneVente> createLignes(Vente vente) {
    return cart.map((item) {
      // 💡 NOUVEAU : Récupère le prix unitaire converti en FC
      final prixUnitaireFC = getPriceVenteFC(item.produit);

      return LigneVente(
        ligneVenteId: const Uuid().v4(),
        venteLocalId: vente.localId ?? 0,
        produitLocalId: item.produit.localId!,
        nomProduit: item.produit.nom!,
        prixVenteUnitaire: prixUnitaireFC, // 💡 STOCKE LA VALEUR CONVERTIE EN FC
        quantite: item.quantity,
        sousTotal: prixUnitaireFC * item.quantity, // 💡 CALCULE LE SOUS-TOTAL EN FC
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
        _modePaiement = 'CASH'; // 👈 AJOUTEZ CETTE LIGNE ICI
        _showClientSuggestions = false;
        _showProductSuggestions = false;
        clientSearchController.clear();
        productSearchController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Vente validée et Reçu Thermique imprimé !")));
    }
  }
  // --- Widgets d'aide (Utilisent maintenant le taux FC) ---

  Widget _buildExchangeRateDisplay() {
    // Affiche un indicateur de chargement si le taux est toujours à 0.0 (initialisation)
    if (_currentExchangeRate == 0.0) {
      return const Padding(
        padding: EdgeInsets.only(right: 8.0),
        child: SizedBox(
          width: 15, height: 15,
          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
        ),
      );
    }

    // Affiche le taux converti en entier
    final rateText = _currentExchangeRate.toStringAsFixed(0);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0), // Marge à droite pour le séparer du bouton Historique
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade800, // Fond foncé pour le contraste
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.currency_exchange, color: Colors.white, size: 16),
            const SizedBox(width: 4),
            // 💡 AMÉLIORÉ : Le texte est plus lisible
            Text(
              '$rateText FC / USD', // Affiche le taux FC pour 1 USD
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientSuggestions(double maxHeight) {
    if (!_showClientSuggestions || filteredClients.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.blueGrey.shade100),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: filteredClients.length,
        itemBuilder: (context, idx) {
          final c = filteredClients[idx];
          return ListTile(
            dense: true, // 👈 Ligne plus fine
            visualDensity: VisualDensity.compact,
            title: Text(c.nomClient ?? '', style: const TextStyle(fontSize: 13)),
            subtitle: Text(c.telephone ?? '', style: const TextStyle(fontSize: 11)),
            onTap: () {
              setState(() {
                selectedClient = c;
                clientSearchController.text = c.nomClient ?? '';
                _showClientSuggestions = false;
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
          // Vérification du stock pour l'affichage
          final stockDispo = p.quantiteActuelle ?? 0;
          final stockColor = stockDispo <= 0 ? Colors.red : (stockDispo < 5 ? Colors.orange : Colors.green);
          final stockText = stockDispo <= 0 ? 'RUPTURE' : 'Stock: $stockDispo';
          final isOutOfStock = stockDispo <= 0;

          // 💰 NOUVEAU : Affichage du prix en USD pour l'information
          final priceUSDText = p.prix?.toStringAsFixed(0) ?? '0';


          return ListTile(
            leading: p.imagePath != null && p.imagePath!.isNotEmpty ? SizedBox(width: 40, height: 40, child: Image.network(p.imagePath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image))) : const Icon(Icons.inventory_2),
            title: Text(p.nom ?? ''),
            // 💡 CORRIGÉ : Affichage du prix en USD pour l'information, car le prix stocké dans Produit est en USD
            subtitle: Text('Prix: $priceUSDText USD - $stockText', style: TextStyle(color: stockColor, fontWeight: FontWeight.bold)),
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

  Widget _buildTotalLine(String label, double amount, Color color, bool isBig) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: isBig ? 16 : 13, fontWeight: isBig ? FontWeight.bold : FontWeight.normal)),
        Text(
          '${amount.toStringAsFixed(0)} FC',
          style: TextStyle(fontSize: isBig ? 18 : 14, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildValidationButtons(bool canValidate, Vente? vente, List<LigneVente>? lignes, Client? client) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // 1. BOUTON APERÇU (Version Compacte)
            SizedBox(
              height: 45,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.remove_red_eye, size: 18),
                label: const Text("Aperçu", style: TextStyle(fontSize: 12)),
                onPressed: canValidate ? () => _previewPdf(vente!, lignes!, client!) : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: const BorderSide(color: Colors.indigo),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 2. BOUTON VALIDER (Prend toute la place restante)
            Expanded(
              child: SizedBox(
                height: 45,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle),
                  label: const Text("VALIDER ET IMPRIMER", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: canValidate ? validateSale : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Largeur maîtrisée pour éviter l'éparpillement visuel sur PC
    final double contentWidth = screenWidth > 1000 ? 900 : screenWidth * 0.96;

    final canValidate = selectedClient != null && cart.isNotEmpty;
    final tempVente = canValidate ? createVente(isDraft: true) : null;
    final tempLignes = canValidate ? createLignes(tempVente!) : null;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 70,
        // 1. GAUCHE : TAUX + HISTORIQUE
        leadingWidth: 280,
        leading: Row(
          children: [
            const SizedBox(width: 15),
            _buildExchangeRateDisplay(), // Votre widget Taux
            const SizedBox(width: 12),
            // BOUTON HISTORIQUE (Style discret mais accessible)
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                icon: const Icon(Icons.history, color: Colors.orangeAccent, size: 20),
                tooltip: "Historique des ventes",
                onPressed: () => widget.onNavigate(6), // Vers l'index 6 ajouté au Dashboard
              ),
            ),
          ],
        ),

        // 2. CENTRE : TITRE
        title: const Text("ENREGISTRER UNE VENTE",
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.white)),
        centerTitle: true,

        // 3. DROITE : TOTAL COMPACT
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Center(child: _buildCompactHeaderTotal()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    children: [
                      // --- BLOC 1 : CLIENT & PAIEMENT ---
                      _buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("INFOS CLIENT & PAIEMENT"),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextField(
                                    controller: clientSearchController,
                                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                    onChanged: filterClients,
                                    decoration: _proInput("Sélectionner un client...", Icons.person_add_alt_1).copyWith(
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          showNewClientForm ? Icons.cancel : Icons.add_circle,
                                          color: showNewClientForm ? Colors.red : Colors.blue.shade700,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            showNewClientForm = !showNewClientForm;
                                            if (showNewClientForm) selectedClient = null;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  flex: 2,
                                  child: Wrap(
                                    spacing: 8,
                                    children: ['CASH', 'TRANSFERT', 'CRÉDIT'].map((m) => _buildPaymentOption(m)).toList(),
                                  ),
                                ),
                              ],
                            ),
                            _buildClientSuggestions(200),
                            if (showNewClientForm && selectedClient == null)
                              _buildCompactNewClientForm(),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // --- BLOC 2 : RECHERCHE ARTICLES + RÉDUCTION ---
                      _buildFormCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle("AJOUTER DES PRODUITS"),
                            Row(
                              children: [
                                // 1. RECHERCHE PRODUIT (Prend le plus d'espace)
                                Expanded(
                                  flex: 5,
                                  child: TextField(
                                    controller: productSearchController,
                                    decoration: _proInput("Rechercher un article...", Icons.search),
                                    onChanged: filterProducts,
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // 2. CHAMP RÉDUCTION (Nouveau : entre recherche et scan)
                                // 2. CHAMP RÉDUCTION (La version qui fonctionne)
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: _remiseController, // 🎯 INDISPENSABLE : On lie le champ au contrôleur global
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                                    decoration: _proInput("Remise", Icons.percent).copyWith(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    onChanged: (val) {
                                      // 🎯 On appelle setState vide.
                                      // Comme _remiseController contient déjà le texte tapé,
                                      // setState force l'AppBar à se redessiner en appelant getNetAPayer().
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // 3. BOUTON SCANNER
                                _buildScannerButton(),
                              ],
                            ),
                            _buildProductSuggestions(250),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // --- BLOC 3 : LE PANIER ---
                      _buildFormCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: _buildSectionTitle("CONTENU DU PANIER"),
                            ),
                            _buildProCartTable(),
                          ],
                        ),
                      ),

                      // Note: Le Bloc 4 (Résumé noir) a été supprimé car il est maintenant en haut à droite (AppBar)
                    ],
                  ),
                ),
              ),
            ),
          ),

          // --- BARRE DE VALIDATION FIXE ---
          _buildFixedBottomBar(canValidate, tempVente, tempLignes),
        ],
      ),
    );
  }

// --- COMPOSANTS DE STYLE ---

  Widget _buildFormCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 1.1)),
    );
  }

  InputDecoration _proInput(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.black87, size: 20),
      filled: true,
      fillColor: Colors.grey.shade50,
      isDense: true, // 👈 Réduit la hauteur interne
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12), // 👈 Ajustement fin
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black12)
      ),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.black, width: 1.5)
      ),
    );
  }

  Widget _buildProCartTable() {
    if (cart.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(30.0),
        // À la ligne 892 environ :
        child: Text("Panier vide", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
      );
    }
    return Container(
      width: double.infinity,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
        dataRowHeight: 60,
        columns: const [
          DataColumn(label: Text("ARTICLE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
          DataColumn(label: Text("PRIX UNIT.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
          DataColumn(label: Text("QTÉ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
          DataColumn(label: Text("TOTAL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
          DataColumn(label: Text("", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
        ],
        rows: cart.map((item) {
          final price = getPriceVenteFC(item.produit);
          return DataRow(cells: [
            DataCell(Text(item.produit.nom ?? '', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black))),
            DataCell(Text("${price.toStringAsFixed(0)} FC")),
            DataCell(_buildQtySelector(item)),
            DataCell(Text("${(price * item.quantity).toStringAsFixed(0)} FC", style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => updateQuantity(item, -item.quantity))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildQtySelector(CartItem item) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: () => updateQuantity(item, -1)),
          Text("${item.quantity}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(icon: const Icon(Icons.add, size: 18), onPressed: () => updateQuantity(item, 1)),
        ],
      ),
    );
  }

  Widget _buildFixedBottomBar(bool can, Vente? v, List<LigneVente>? l) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
      child: Center(
        child: SizedBox(
          width: 600,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: can ? () => _previewPdf(v!, l!, selectedClient!) : null,
                  icon: const Icon(Icons.visibility),
                  label: const Text("APERÇU PDF"),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 20), side: const BorderSide(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: can ? validateSale : null,
                  icon: const Icon(Icons.print),
                  label: const Text("VALIDER ET IMPRIMER"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  // --- FORMULAIRE NOUVEAU CLIENT (Optimisé) ---
  Widget _buildCompactNewClientForm() {
    // 💡 PRÉCISION : Cache le formulaire si un client est déjà choisi ou si le bouton n'est pas activé
    if (!showNewClientForm || selectedClient != null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Row(
        children: [
          Expanded(flex: 2, child: TextField(controller: nameController, decoration: _proInput("Nom", Icons.badge))),
          const SizedBox(width: 8),
          Expanded(flex: 2, child: TextField(controller: phoneController, decoration: _proInput("Tél", Icons.phone))),
          const SizedBox(width: 8),
          Expanded(flex: 3, child: TextField(controller: addressController, decoration: _proInput("Adresse", Icons.location_on))),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: addClient,
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)) // Design plus "Windows"
            ),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }// --- FORMULAIRE NOUVEAU CLIENT (3 champs sur une ligne) ---

// 2. Bouton Scanner manquant
  Widget _buildScannerButton() {
    return Container(
      decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
      child: IconButton(
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        onPressed: () {
          // Logique de scan ici
        },
      ),
    );
  }
  // À ajouter dans la classe _EnregistrementVenteState
  Widget _buildPaymentOption(String mode) {
    final isSelected = _modePaiement == mode;
    return ChoiceChip(
      label: Text(mode),
      selected: isSelected,
      selectedColor: Colors.blue.shade100,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _modePaiement = mode; // 🎯 Met à jour la variable d'état
          });
        }
      },
      labelStyle: TextStyle(
        color: isSelected ? Colors.blue.shade900 : Colors.black,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
  Widget _buildCompactHeaderTotal() {
    // 🎯 On appelle la fonction unique, plus de calcul manuel ici !
    double netAPayer = getNetAPayer();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF2196F3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("N. PAYER : ",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
          Text("${netAPayer.toStringAsFixed(0)} FC",
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900, color: Color(0xFF02192C))),
        ],
      ),
    );
  }
  double getNetAPayer() {
    // 1. Somme du panier
    double totalBrut = cart.fold(0, (sum, item) => sum + (getPriceVenteFC(item.produit) * item.quantity));
    // 2. Récupération de la remise
    double remisePourcent = double.tryParse(_remiseController.text) ?? 0.0;
    // 3. Calcul du net
    return totalBrut - (totalBrut * (remisePourcent / 100));
  }
}