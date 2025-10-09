import 'package:factura/DashboardAdmin/ajout_produits.dart';
import 'package:flutter/material.dart';
import 'package:factura/DashboardVendor/edite_produits_page.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/model_produits.dart';

class GestionProduits extends StatefulWidget {
  const GestionProduits({super.key});

  @override
  State<GestionProduits> createState() => _GestionProduitsState();
}

class _GestionProduitsState extends State<GestionProduits> {
  final DatabaseService _dbService = DatabaseService.instance;
  List<Produit> _produits = [];
  List<Produit> _filteredProduits = [];
  Map<int, int> _stockActuelMap = {};
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  String _selectedCategorie = 'Toutes les catégories';
  List<String> _categories = ['Toutes les catégories'];

  @override
  void initState() {
    super.initState();
    _loadProduits();
  }

  Future<void> _loadProduits() async {
    setState(() => _isLoading = true);

    try {
      final produits = await _dbService.getAllProduits();
      Map<int, int> stockMap = {};
      Set<String> categoriesSet = {};

      for (var produit in produits) {
        if (produit.localId != null) {
          final vendu = await _dbService.getStockVendu(produit.localId!);
          final stockActuel = (produit.quantiteInitiale ?? 0) - vendu;
          stockMap[produit.localId!] = stockActuel >= 0 ? stockActuel : 0;
        }
        if (produit.categorie != null && produit.categorie!.isNotEmpty) {
          categoriesSet.add(produit.categorie!);
        }
      }

      setState(() {
        _produits = produits;
        _filteredProduits = produits;
        _stockActuelMap = stockMap;
        _categories = ['Toutes les catégories', ...categoriesSet];
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des produits: $e");
      setState(() => _isLoading = false);
    }
  }

  void _filterProduits() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProduits = _produits.where((p) {
        final matchesName = p.nom?.toLowerCase().contains(query) ?? false;
        final matchesCategorie = _selectedCategorie == 'Toutes les catégories'
            ? true
            : (p.categorie == _selectedCategorie);
        return matchesName && matchesCategorie;
      }).toList();
    });
  }

  void _navigateToAddProduit() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AjoutProduits()),
    );
    if (result == true) _loadProduits();
  }

  void _navigateToEditProduit(Produit produit) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditeProduits(produit: produit),
      ),
    );
    if (result == true) _loadProduits();
  }

  Future<void> _deleteProduit(Produit produit) async {
    if (produit.localId == null) return;

    final confirmed = await _confirmDeletion(produit.nom ?? 'ce produit');
    if (confirmed) {
      try {
        await _dbService.deleteProduit(produit.localId!);
        _loadProduits();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Le produit "${produit.nom}" a été supprimé.')),
        );
      } catch (e) {
        print("Erreur lors de la suppression du produit: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression : $e')),
        );
      }
    }
  }

  Future<bool> _confirmDeletion(String nomProduit) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content: Text("Êtes-vous sûr de vouloir supprimer le produit '$nomProduit'?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Annuler"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre et bouton Ajouter
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
          const SizedBox(height: 20),

          // Barre de recherche + filtre catégorie
          Row(
            children: [
              // Champ de recherche
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => _filterProduits(),
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.indigo, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Filtre catégorie
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _selectedCategorie,
                  onChanged: (value) {
                    setState(() => _selectedCategorie = value!);
                    _filterProduits();
                  },
                  items: _categories
                      .map((cat) => DropdownMenuItem<String>(
                    value: cat,
                    child: Text(cat),
                  ))
                      .toList(),
                  decoration: InputDecoration(
                    labelText: 'Catégorie',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),
          const Text(
            'Liste des produits en stock',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 16),

          // Tableau avec défilement vertical + horizontal
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
                  : _filteredProduits.isEmpty
                  ? const Center(child: Text('Aucun produit trouvé.'))
                  : SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.resolveWith(
                            (states) => Colors.indigo.shade50),
                    dataRowMaxHeight: 60,
                    columnSpacing: 30,
                    columns: const [
                      DataColumn(
                          label: Text('Image',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo))),
                      DataColumn(
                          label: Text('Nom',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo))),
                      DataColumn(
                          label: Text('Catégorie',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo))),
                      DataColumn(
                          label: Text('Prix',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo)),
                          numeric: true),
                      DataColumn(
                          label: Text('Stock Initial',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo)),
                          numeric: true),
                      DataColumn(
                          label: Text('Stock Actuel',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo)),
                          numeric: true),
                      DataColumn(
                          label: Text('Actions',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo))),
                    ],
                    rows: _filteredProduits.map((produit) {
                      final stockActuel = produit.localId != null
                          ? (_stockActuelMap[produit.localId!] ?? 0)
                          : 0;
                      final stockInitial = produit.quantiteInitiale ?? 0;
                      final rowColor = stockActuel <= 5
                          ? Colors.red.shade50
                          : Colors.white;

                      return DataRow(
                        color: MaterialStateProperty.resolveWith(
                                (states) => rowColor),
                        cells: [
                          DataCell(
                            (produit.imagePath != null &&
                                produit.imagePath!.isNotEmpty)
                                ? SizedBox(
                              width: 40,
                              height: 40,
                              child: ClipRRect(
                                borderRadius:
                                BorderRadius.circular(8.0),
                                child: Image.network(
                                  produit.imagePath!,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                              ),
                            )
                                : const Icon(Icons.image_not_supported,
                                color: Colors.grey),
                          ),
                          DataCell(Text(produit.nom ?? 'Inconnu')),
                          DataCell(Text(produit.categorie ?? '')),
                          DataCell(Text(produit.prix?.toStringAsFixed(2) ?? '0.00')),
                          DataCell(Text(stockInitial.toString())),
                          DataCell(Text(
                            stockActuel.toString(),
                            style: TextStyle(
                                color: stockActuel <= 5
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                                fontWeight: FontWeight.bold),
                          )),
                          DataCell(Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.blue, size: 20),
                                onPressed: () => _navigateToEditProduit(produit),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red, size: 20),
                                onPressed: () => _deleteProduit(produit),
                              ),
                            ],
                          )),
                        ],
                      );
                    }).toList(),
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
