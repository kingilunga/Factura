import 'package:factura/DashboardAdmin/ajout_produits.dart';
import 'package:factura/service_pdf.dart';
import 'package:flutter/material.dart';
import 'package:factura/DashboardVendor/edite_produits_page.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class GestionStockProduits extends StatefulWidget {
  const GestionStockProduits({super.key});

  @override
  State<GestionStockProduits> createState() => _GestionStockProduitsState();
}

class _GestionStockProduitsState extends State<GestionStockProduits> {
  final DatabaseService _dbService = DatabaseService.instance;
  List<Produit> _produits = [];
  List<Produit> _filteredProduits = [];

  bool _isLoading = true;
  double _tauxUSD = 1.0;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategorie = 'Toutes les catégories';
  List<String> _categories = ['Toutes les catégories'];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterProduits);
    _loadProduits();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterProduits);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProduits() async {
    setState(() => _isLoading = true);

    try {
      final produits = await _dbService.getAllProduits();
      final tauxRecupere = await _dbService.fetchTauxChange('USD');

      Set<String> categoriesSet = {};

      for (var produit in produits) {
        if (produit.categorie != null && produit.categorie!.isNotEmpty) {
          categoriesSet.add(produit.categorie!);
        }
      }

      setState(() {
        _produits = produits;
        _filteredProduits = produits;
        _categories = ['Toutes les catégories', ...categoriesSet];
        _tauxUSD = tauxRecupere;
        _isLoading = false;
      });
      _filterProduits();
    } catch (e) {
      debugPrint("Erreur chargement: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur de chargement: ${e.toString()}")),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _filterProduits() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProduits = _produits.where((p) {
        final matchesName = p.nom.toLowerCase().contains(query);
        final matchesCategorie = _selectedCategorie == 'Toutes les catégories'
            ? true
            : (p.categorie == _selectedCategorie);
        return matchesName && matchesCategorie;
      }).toList();
    });
  }

  // --- LOGIQUE DE CALCUL DES TOTAUX ---
  Map<String, double> _calculateTotals() {
    double totalValeurAchatFC = 0;
    double totalValeurVenteFC = 0;
    double totalStockReceptionne = 0;
    double totalStockDisponible = 0;

    for (var produit in _filteredProduits) {
      final prixAchatUSD = produit.prixAchatUSD ?? 0.0;
      final prixVenteUSD = produit.prix ?? 0.0;

      final stockReceptionne = (produit.quantiteInitiale ?? 0).toDouble();
      final stockDisponible = (produit.quantiteActuelle ?? 0).toDouble();

      // Conversion en FC
      final prixAchatFC = prixAchatUSD * _tauxUSD;
      final prixVenteFC = prixVenteUSD * _tauxUSD;

      // Valeur totale du stock actuel (multiplié par stockDisponible car c'est la valeur du stock restant)
      totalValeurAchatFC += prixAchatFC * stockDisponible;
      totalValeurVenteFC += prixVenteFC * stockDisponible;

      totalStockReceptionne += stockReceptionne;
      totalStockDisponible += stockDisponible;
    }

    // Calcul de la marge globale potentielle
    final margeTotaleFC = totalValeurVenteFC - totalValeurAchatFC;

    return {
      'totalValeurAchatFC': totalValeurAchatFC,
      'totalValeurVenteFC': totalValeurVenteFC,
      'totalStockReceptionne': totalStockReceptionne,
      'totalStockDisponible': totalStockDisponible,
      'margeTotaleFC': margeTotaleFC,
    };
  }

  // --- ACTIONS D'EXPORT (Inchangé) ---

  List<Map<String, dynamic>> _formatDataForReport() {
    return _filteredProduits.map((p) {
      final stockReceptionne = p.quantiteInitiale ?? 0;
      final stockDisponible = p.quantiteActuelle ?? 0;
      final prixAchatFC = (p.prixAchatUSD ?? 0.0) * _tauxUSD;
      final prixVenteFC = (p.prix ?? 0.0) * _tauxUSD;
      final valeurStockFC = prixVenteFC * stockDisponible;

      return {
        'Nom du Produit': p.nom,
        'Catégorie': p.categorie ?? '',
        'P. Achat (FC)': prixAchatFC.toStringAsFixed(0),
        'P. Vente (FC)': prixVenteFC.toStringAsFixed(0),
        'Reçu': stockReceptionne.toString(),
        'Dispo': stockDisponible.toString(),
        'Valeur Stock (FC)': valeurStockFC.toStringAsFixed(0),
      };
    }).toList();
  }

  void _exportInventairePdf() async {
    if (_filteredProduits.isEmpty) return;
    final reportData = _formatDataForReport();
    final totals = _calculateTotals();

    final pdfBytes = await generateListReport(
      title: 'INVENTAIRE STOCK (Taux: 1 USD = ${_tauxUSD.toStringAsFixed(0)} FC)',
      data: reportData,
      totals: totals,
    );

    await Printing.sharePdf(bytes: pdfBytes, filename: 'inventaire.pdf');
  }

  void _printInventaire() async {
    if (_filteredProduits.isEmpty) return;
    final reportData = _formatDataForReport();
    final totals = _calculateTotals();

    await Printing.layoutPdf(
      onLayout: (format) async => generateListReport(
        title: 'INVENTAIRE STOCK',
        data: reportData,
        totals: totals,
      ),
    );
  }

  // --- CRUD (Inchangé) ---
  void _navigateToAddProduit() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AjoutProduits()),
    );
    if (result == true) _loadProduits();
  }

  void _navigateToEditProduit(Produit produit) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditeProduits(produit: produit)),
    );
    if (result == true) _loadProduits();
  }

  Future<void> _deleteProduit(Produit produit) async {
    if (produit.localId == null) return;
    final confirmed = await _confirmDeletion(produit.nom);
    if (confirmed) {
      try {
        await _dbService.deleteProduit(produit.localId!);
        _loadProduits();
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Produit supprimé.')));
      } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible de supprimer.')));
      }
    }
  }

  Future<bool> _confirmDeletion(String nomProduit) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: Text("Supprimer '$nomProduit'?"),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Annuler")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Supprimer", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }

  // --- ⭐️ MISE À JOUR : COULEURS NOIRES ET CLAIRES POUR LES AGRÉGATS ⭐️ ---
  Widget _buildTotalsRow(Map<String, double> totals) {
    // Formatage pour lisibilité (ex: 1 000 000)
    final f = NumberFormat("#,###", "fr_FR");

    final totalAchat = totals['totalValeurAchatFC'] ?? 0.0;
    final totalVente = totals['totalValeurVenteFC'] ?? 0.0;
    final totalMarge = totals['margeTotaleFC'] ?? 0.0;

    // Pour les quantités, on peut utiliser toStringAsFixed(0) car ce sont des entiers
    final totalRecu = totals['totalStockReceptionne']?.toStringAsFixed(0) ?? '0';
    final totalDispo = totals['totalStockDisponible']?.toStringAsFixed(0) ?? '0';

    // Définition de la couleur noire claire
    const Color clearBlack = Colors.black87;

    // Liste des agrégats pour les 4 colonnes
    final totalStats = [
      _TotalStat(title: 'Qté Reçue', value: totalRecu, color: clearBlack, isQuantity: true),
      _TotalStat(title: 'Qté Disponible', value: totalDispo, color: clearBlack, isQuantity: true), // Couleur uniforme
      _TotalStat(title: 'Valeur Achat Totale', value: '${f.format(totalAchat)} FC', color: clearBlack), // Couleur uniforme
      _TotalStat(title: 'Valeur Vente Totale', value: '${f.format(totalVente)} FC', color: clearBlack), // Couleur uniforme
    ];

    return Container(
      padding: const EdgeInsets.all(15.0),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Colonne du Titre (COTÉ GAUCHE)
          const Padding(
            padding: EdgeInsets.only(right: 20.0),
            child: Text(
                'TOTAUX :',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF13132D), // Noir profond
                    fontSize: 20
                )
            ),
          ),

          const VerticalDivider(thickness: 2, color: Colors.indigo),

          // 2. Les 4 Agrégats en colonnes égales (Expanded pour prendre l'espace)
          Expanded(
            flex: 8, // Donne plus d'espace pour les 4 colonnes
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: totalStats.map((stat) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: stat,
                ),
              )).toList(),
            ),
          ),

          // 3. Colonne de la Marge (Reste en rouge pour le contraste)
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 20.0),
              child: Card(
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: _TotalStat(
                    title: 'Marge Potentielle',
                    value: '${f.format(totalMarge)} FC',
                    color: Colors.red.shade700,
                    isBold: true,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET PRINCIPAL BUILD (Inchangé) ---
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- EN-TÊTE ET BOUTON AJOUTER ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gestion des produits',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
              ),
              ElevatedButton.icon(
                onPressed: _navigateToAddProduit,
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                label: const Text('Ajouter un produit',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Taux
          Card(
            color: Colors.indigo.shade50,
            child: ListTile(
              leading: const Icon(Icons.currency_exchange, color: Colors.indigo),
              title: const Text("Taux de change appliqué", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
              subtitle: Text("1 USD = ${_tauxUSD.toStringAsFixed(0)} FC", style: TextStyle(color: Colors.indigo.shade700)),
            ),
          ),
          const SizedBox(height: 20),

          // Recherche
          Row(
            children: [
              Expanded(flex: 3, child: TextField(
                controller: _searchController,
                decoration: InputDecoration(hintText: 'Rechercher...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: DropdownButtonFormField<String>(
                value: _selectedCategorie,
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) { setState(() => _selectedCategorie = v!); _filterProduits(); },
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
              )),
              const SizedBox(width: 20),
              IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30), onPressed: _exportInventairePdf, tooltip: 'PDF'),
              IconButton(icon: const Icon(Icons.print, color: Colors.blue, size: 30), onPressed: _printInventaire, tooltip: 'Imprimer'),
            ],
          ),
          const SizedBox(height: 30),
          const Text('Liste des produits en stock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),

          // Tableau
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.indigo.shade50),
                    dataRowMaxHeight: 60,
                    columns: const [
                      DataColumn(label: Text('Image')),
                      DataColumn(label: Text('Nom du produit')),
                      DataColumn(label: Text('Catégorie')),
                      DataColumn(label: Text('Prix Achat (FC)')),
                      DataColumn(label: Text('Prix Vente (FC)')),
                      DataColumn(label: Text('Stock reçu')),
                      DataColumn(label: Text('Stock Dispo')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: _filteredProduits.map((p) {
                      final prixAchatFC = (p.prixAchatUSD ?? 0) * _tauxUSD;
                      final prixVenteFC = (p.prix ?? 0) * _tauxUSD;
                      final stockDispo = p.quantiteActuelle ?? 0;

                      final rowColor = stockDispo <= 5 ? Colors.orange.shade50 : Colors.white;

                      return DataRow(
                          color: MaterialStateProperty.resolveWith((states) => rowColor),
                          cells: [
                            DataCell(const Icon(Icons.image_not_supported, color: Colors.grey)),
                            DataCell(Text(p.nom, style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(p.categorie ?? '')),
                            DataCell(Text('${prixAchatFC.toStringAsFixed(0)} FC')),
                            DataCell(Text('${prixVenteFC.toStringAsFixed(0)} FC')),
                            DataCell(Text((p.quantiteInitiale ?? 0).toString())),
                            DataCell(Text(stockDispo.toString(), style: TextStyle(color: stockDispo <= 5 ? Colors.orange.shade800 : Colors.green.shade800, fontWeight: FontWeight.bold))),
                            DataCell(Row(children: [
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _navigateToEditProduit(p)),
                              IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduit(p)),
                            ])),
                          ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // BARRE DE TOTAUX MISE À JOUR
          _buildTotalsRow(_calculateTotals()),
        ],
      ),
    );
  }
}

// --- WIDGET STATISTIQUE RÉUTILISABLE (Inchangé) ---
class _TotalStat extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final bool isBold;
  final bool isQuantity;
  final double fontSize;

  const _TotalStat({
    required this.title,
    required this.value,
    required this.color,
    this.isBold = false,
    this.isQuantity = false,
    this.fontSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            // Icône basée sur le type de statistique (Quantité ou Monétaire)
            if(isQuantity) const Icon(Icons.inventory_2, size: 16, color: Colors.black45),
            if(!isQuantity) const Icon(Icons.monetization_on, size: 16, color: Colors.black45),
            const SizedBox(width: 4),
            Expanded( // Permet au texte de se couper si l'espace est limité
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}