import 'package:factura/Splash_login/dialogues_infos.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Pour la création du PDF
import 'package:printing/printing.dart'; // Pour l'impression directe

class StockProduits extends StatefulWidget {
  const StockProduits({super.key});

  @override
  State<StockProduits> createState() => _StockProduitsState();
}

class _StockProduitsState extends State<StockProduits> {
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
    } catch (e) {
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

  // ⭐️ LOGIQUE PDF ET IMPRESSION (REFAITE)
  Future<pw.Document> _generatePdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, child: pw.Text("Inventaire de Stock - Vendeur")),
          pw.TableHelper.fromTextArray(
            headers: ['Produit', 'Catégorie', 'Prix Vente (FC)', 'Reçu', 'Dispo'],
            data: _filteredProduits.map((p) => [
              p.nom,
              p.categorie ?? '',
              '${((p.prix ?? 0) * _tauxUSD).toStringAsFixed(0)} FC',
              p.quantiteInitiale.toString(),
              p.quantiteActuelle.toString(),
            ]).toList(),
          ),
        ],
      ),
    );
    return pdf;
  }

  void _exportInventairePdf() async {
    final pdf = await _generatePdf();
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'inventaire_stock.pdf');
  }

  void _printInventaire() async {
    final pdf = await _generatePdf();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }

  void _deleteProduit(Produit produit) {
    DialoguesInfo.afficher(
      context,
      titre: "Action refusée",
      message: "Veuillez contacter l'Admin pour supprimer un produit.",
      couleur: Colors.orange,
    );
  }

  Map<String, double> _calculateTotals() {
    double totalVenteFC = 0;
    double totalRecu = 0;
    double totalDispo = 0;

    for (var p in _filteredProduits) {
      totalVenteFC += (p.prix ?? 0) * _tauxUSD * (p.quantiteActuelle ?? 0);
      totalRecu += (p.quantiteInitiale ?? 0).toDouble();
      totalDispo += (p.quantiteActuelle ?? 0).toDouble();
    }
    return {'totalVente': totalVenteFC, 'totalRecu': totalRecu, 'totalDispo': totalDispo};
  }

  @override
  Widget build(BuildContext context) {
    final totals = _calculateTotals();
    final f = NumberFormat("#,###", "fr_FR");

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stock produits (Vendeur)', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
          const SizedBox(height: 15),

          // ⭐️ WIDGET TAUX DE CHANGE
          Card(
            color: Colors.indigo.shade50,
            child: ListTile(
              leading: const Icon(Icons.currency_exchange, color: Colors.indigo),
              title: Text("1 USD = ${_tauxUSD.toStringAsFixed(0)} FC", style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),

          // ⭐️ RECHERCHE + PDF + PRINT (Comme sur image_1b6129.png)
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
              const SizedBox(width: 10),
              IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28), onPressed: _exportInventairePdf),
              IconButton(icon: const Icon(Icons.print, color: Colors.blue, size: 28), onPressed: _printInventaire),
            ],
          ),
          const SizedBox(height: 20),

          // ⭐️ TABLEAU (7 COLONNES - Résout image_1b4ea0.png)
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
                    columns: const [
                      DataColumn(label: Text('Image')),       // 1
                      DataColumn(label: Text('Produit')),     // 2
                      DataColumn(label: Text('Catégorie')),   // 3
                      DataColumn(label: Text('Prix Vente')),  // 4
                      DataColumn(label: Text('Reçu')),        // 5
                      DataColumn(label: Text('Dispo')),       // 6
                      DataColumn(label: Text('Actions')),     // 7
                    ],
                    rows: _filteredProduits.map((p) {
                      final prixVenteFC = (p.prix ?? 0) * _tauxUSD;
                      return DataRow(cells: [
                        const DataCell(Icon(Icons.image_not_supported)), // 1
                        DataCell(Text(p.nom, style: const TextStyle(fontWeight: FontWeight.bold))), // 2
                        DataCell(Text(p.categorie ?? '')), // 3
                        DataCell(Text('${prixVenteFC.toStringAsFixed(0)} FC')), // 4
                        DataCell(Text((p.quantiteInitiale ?? 0).toString())), // 5
                        DataCell(Text((p.quantiteActuelle ?? 0).toString(), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))), // 6
                        DataCell(IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteProduit(p))), // 7
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ⭐️ AGRÉGATS (Comme sur image_1bbb65.png)
          const Text('TOTAUX :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(label: 'Qté Reçue', value: totals['totalRecu']!.toStringAsFixed(0), icon: Icons.inventory_2),
                _StatItem(label: 'Qté Disponible', value: totals['totalDispo']!.toStringAsFixed(0), icon: Icons.check_circle, color: Colors.green),
                _StatItem(label: 'Valeur de Vente', value: '${f.format(totals['totalVente'])} FC', icon: Icons.monetization_on, color: Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const _StatItem({required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      const SizedBox(height: 5),
      Row(children: [
        Icon(icon, size: 16, color: Colors.black38),
        const SizedBox(width: 5),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color ?? Colors.black87)),
      ]),
    ]);
  }
}