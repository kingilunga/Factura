import 'package:factura/service_pdf.dart' as pdf_service;
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart'; // Import pour la DB
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

// Importez vos modèles Clients et Ventes ici si nécessaire pour le TauxChangeWidget
// (Je suppose que ces classes sont définies ailleurs dans votre projet)

typedef OnNavigate = void Function(int index);

// --- Widget TauxChangeWidget (Connecté à la BDD) ---
class TauxChangeWidget extends StatefulWidget {
  final ValueChanged<double>? onTauxUpdated;

  const TauxChangeWidget({Key? key, this.onTauxUpdated}) : super(key: key);

  @override
  State<TauxChangeWidget> createState() => _TauxChangeWidgetState();
}

class _TauxChangeWidgetState extends State<TauxChangeWidget> {
  final _db = DatabaseService.instance;
  double? tauxUSD;
  bool isLoading = false;
  bool dbFailed = false;

  @override
  void initState() {
    super.initState();
    _refreshTaux();
  }

  // 🔄 MODIFIÉ : Récupération réelle depuis la BDD
  Future<void> _refreshTaux() async {
    setState(() {
      isLoading = true;
      dbFailed = false;
    });

    double? taux;
    try {
      // 💡 Appel à la méthode fiable que nous avons créée ensemble
      taux = await _db.getLatestExchangeRate();
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la récupération du taux depuis la DB: $e");
      }
    }

    if (mounted) {
      setState(() {
        if (taux != null && taux > 0) {
          tauxUSD = taux;
          dbFailed = false;
        } else {
          dbFailed = true;
          // Valeur par défaut si aucune donnée (1.0 pour éviter la division par zéro)
          tauxUSD = 1.0;
        }
        isLoading = false;
      });

      if (tauxUSD != null) {
        widget.onTauxUpdated?.call(tauxUSD!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.monetization_on, color: Color(0xFF13132D)),
                const SizedBox(width: 10),
                const Text(
                  "Taux de change USD/CDF:",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
                ),
                const SizedBox(width: 10),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF13132D)),
                  )
                else if (dbFailed || tauxUSD == 1.0)
                  const Text(
                    "Non défini (1.0)",
                    style: TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold),
                  )
                else
                  Text(
                    "${tauxUSD?.toStringAsFixed(2)} CDF",
                    style: const TextStyle(fontSize: 18, color: Color(0xFF13132D), fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            IconButton(
              icon: isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
              )
                  : const Icon(Icons.refresh, color: Colors.indigo),
              onPressed: isLoading ? null : _refreshTaux,
              tooltip: "Actualiser le taux",
            ),
          ],
        ),
      ),
    );
  }
}

// --- Statistiques ---
class Statistiques extends StatefulWidget {
  final OnNavigate? onNavigate;
  final int currentVendeurId;

  const Statistiques({super.key, this.onNavigate, required this.currentVendeurId});

  @override
  State<Statistiques> createState() => _StatistiquesState();
}

class _StatistiquesState extends State<Statistiques> {
  final _db = DatabaseService.instance;
  String _selectedPeriod = 'Jour';
  double chiffreAffairesCDF = 0;
  double chiffreAffairesUSD = 0;
  int ventesEffectuees = 0;
  int nouveauxClients = 0;
  double tauxUSD = 1.0; // Initialisation safe

  List<Map<String, dynamic>> topProduits = [];
  List<Map<String, dynamic>> topClients = [];
  List<Map<String, dynamic>> produitsCritiques = [];

  final NumberFormat currencyCDF = NumberFormat("#,##0", "fr_FR");
  final NumberFormat currencyUSD = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _updateUSD() {
    if (tauxUSD > 0) {
      chiffreAffairesUSD = chiffreAffairesCDF / tauxUSD;
    } else {
      chiffreAffairesUSD = 0;
    }
  }

  Future<void> _loadStats() async {
    // ⚠️ TODO: Implémenter réellement getAllVentes dans DatabaseService et les modèles Vente.
    // Pour l'instant, on utilise des listes vides ou des données de démo si la BDD n'est pas prête.
    final allVentes = await _db.getAllVentes();
    final now = DateTime.now();
    List<dynamic> filtered = [];

    switch (_selectedPeriod) {
      case 'Jour':
        filtered = allVentes.where((v) {
          final date = DateTime.parse(v.dateVente);
          return date.year == now.year && date.month == now.month && date.day == now.day;
        }).toList();
        break;
      case 'Semaine':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        filtered = allVentes.where((v) {
          final date = DateTime.parse(v.dateVente);
          return date.isAfter(weekStart.subtract(const Duration(seconds: 1))) &&
              date.isBefore(weekEnd.add(const Duration(days: 1)));
        }).toList();
        break;
      case 'Mois':
        filtered = allVentes.where((v) =>
        DateTime.parse(v.dateVente).year == now.year &&
            DateTime.parse(v.dateVente).month == now.month).toList();
        break;
      case 'Année':
        filtered = allVentes.where((v) => DateTime.parse(v.dateVente).year == now.year).toList();
        break;
    }

    setState(() {
      // ⚠️ Assurez-vous que l'objet Vente a bien une propriété 'totalNet' et 'clientLocalId'
      chiffreAffairesCDF = filtered.fold(0.0, (sum, v) => sum + v.totalNet);
      ventesEffectuees = filtered.length;
      nouveauxClients = filtered.map((v) => v.clientLocalId).toSet().length;
    });

    _updateUSD();
    await _loadTops();
  }

  Future<void> _loadTops() async {
    try {
      // ⚠️ Assurez-vous que les méthodes BDD existent et retournent les listes appropriées
      final produits = await _db.fetchTopSellingProducts();
      final clients = await _db.fetchClientOverview();
      final critiques = await _db.fetchCriticalStock(limit: 10);

      setState(() {
        topProduits = produits.map((p) => {
          'nom': p.nom,
          'quantiteVendue': p.stock, // Assurez-vous que le modèle produit a un champ 'stock' pour la vente totale
          'prix': p.prix,
          'statut': p.statut,
        }).toList();

        topClients = clients.map((c) => {
          'nomClient': c.nomClient,
          'totalOperations': c.totalOperations,
          'type': c.type,
        }).toList();

        produitsCritiques = critiques;
      });
    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors du chargement des tops: $e");
      }
      setState(() {
        topProduits = [];
        topClients = [];
        produitsCritiques = [];
      });
    }
  }

  void _selectPeriod(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _loadStats();
  }

  // --- LOGIQUE D'EXPORT ET IMPRESSION ---
  List<Map<String, dynamic>> _formatDataForPdf(String title, List<Map<String, dynamic>> rawData) {
    return rawData.map((item) {
      if (title.contains("Produits performants")) {
        return {
          "Produit": item['nom'] ?? 'N/A',
          "Ventes": "${item['quantiteVendue'] ?? 0}",
          "Prix (USD)": "${item['prix'] ?? 0}",
        };
      } else if (title.contains("Clients performants")) {
        return {
          "Client": item['nomClient'] ?? 'N/A',
          "Opérations": "${item['totalOperations'] ?? 0}",
          "Type": item['type'] ?? 'Standard',
        };
      } else if (title.contains("Stocks critiques")) {
        return {
          "Produit": item['nom'] ?? 'N/A',
          "Stock Restant": "${item['quantiteActuelle'] ?? 0}",
          "Alerte": "CRITIQUE",
        };
      }
      return item;
    }).toList();
  }

  void _exportListToPdf(String title, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune donnée à exporter.")));
      return;
    }
    final cleanData = _formatDataForPdf(title, data);
    try {
      final pdfBytes = await pdf_service.generateListReport(
        title: "Rapport : $title",
        data: cleanData,
      );
      await Printing.sharePdf(bytes: pdfBytes, filename: 'rapport_${DateTime.now().millisecondsSinceEpoch}.pdf');
    } catch (e) {
      if (kDebugMode) print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur export: $e"), backgroundColor: Colors.red));
    }
  }

  void _printList(String title, List<Map<String, dynamic>> data) async {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Aucune donnée à imprimer.")));
      return;
    }
    final cleanData = _formatDataForPdf(title, data);
    try {
      final pdfBytes = await pdf_service.generateListReport(
        title: "Rapport : $title",
        data: cleanData,
      );
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Impression - $title',
      );
    } catch (e) {
      if (kDebugMode) print(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur impression: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color softGrayBackground = Color(0xFFA5A9B1);
    const int ventePageIndex = 2;
    const int proFormaPageIndex = 3; // 💡 NOUVEL INDEX pour la Pro-Forma

    return Scaffold(
      backgroundColor: softGrayBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- En-tête Périodes et Boutons d'Action (MODIFIÉ) ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 1. SÉLECTION DES PÉRIODES
                Row(
                  children: ['Jour', 'Semaine', 'Mois', 'Année'].map((p) {
                    final selected = _selectedPeriod == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selected ? Colors.indigo.shade600 : Colors.white,
                          foregroundColor: selected ? Colors.white : Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                            side: BorderSide(
                              color: selected ? Colors.indigo.shade600 : Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          elevation: selected ? 4 : 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                        onPressed: () => _selectPeriod(p),
                        child: Text(p, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    );
                  }).toList(),
                ),

                // 2. BOUTONS D'ACCÈS RAPIDE (AJOUT DU BOUTON PRO-FORMA)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // NOUVEAU BOUTON : Pro-Forma
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700, // Couleur Pro-Forma
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 6,
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                      ),
                      onPressed: () => widget.onNavigate?.call(proFormaPageIndex),
                      icon: const Icon(Icons.description, size: 20),
                      label: const Text(
                        "Pro-Forma",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // BOUTON EXISTANT : Vendre
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 6,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                      onPressed: () => widget.onNavigate?.call(ventePageIndex),
                      icon: const Icon(Icons.shopping_cart, size: 20),
                      label: const Text(
                        "Vendre des produits",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- Widget Taux de Change ---
            TauxChangeWidget(
              onTauxUpdated: (double newTaux) {
                setState(() {
                  tauxUSD = newTaux;
                  _updateUSD(); // Recalcule les stats USD quand le taux change
                });
              },
            ),

            const SizedBox(height: 24),

            // --- Cartes KPI ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: _buildStatCard("Chiffre d'affaires (CDF)",
                      currencyCDF.format(chiffreAffairesCDF), Icons.money, Colors.green.shade700, suffix: "CDF"),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: _buildStatCard("Chiffre d'affaires (USD)",
                      currencyUSD.format(chiffreAffairesUSD), Icons.attach_money, Colors.teal.shade700, suffix: "\$"),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildStatCard("Ventes effectuées", "$ventesEffectuees",
                      Icons.point_of_sale, Colors.orange.shade700, isSimple: true),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _buildStatCard("Nouveaux clients", "$nouveauxClients",
                      Icons.people, Colors.blue.shade700, isSimple: true),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- Listes Déroulantes avec Boutons Actions ---
            LayoutBuilder(
              builder: (context, constraints) {
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildScrollableListCard(
                      "Produits performants (Top 10)",
                      Icons.trending_up,
                      topProduits,
                      "nom",
                      "quantiteVendue",
                      "unités",
                      Colors.green.shade700,
                    ),
                    _buildScrollableListCard(
                      "Stocks critiques (≤10)",
                      Icons.warning_amber_rounded,
                      produitsCritiques,
                      "nom",
                      "quantiteActuelle",
                      "restants",
                      Colors.red.shade700,
                    ),
                    _buildScrollableListCard(
                      "Clients performants (Top 10)",
                      Icons.people_alt,
                      topClients,
                      "nomClient",
                      "totalOperations",
                      "achats",
                      Colors.blue.shade700,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool isSimple = false, String? suffix}) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.15), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: isSimple
                  ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
                ],
              )
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87), overflow: TextOverflow.ellipsis),
                      ),
                      if (suffix != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(suffix, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color.withOpacity(0.7))),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollableListCard(String title, IconData icon, List<Map<String, dynamic>> data,
      String keyNom, String keyValeur, String suffix, Color color) {

    const double containerHeight = 450.0;

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.15), width: 1.5),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête (Titre + Boutons)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 18),
                      tooltip: "Exporter en PDF",
                      onPressed: () => _exportListToPdf(title, data),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.blueGrey, size: 18),
                      tooltip: "Imprimer",
                      onPressed: () => _printList(title, data),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 12, thickness: 1),

            // Zone de liste avec hauteur fixe
            SizedBox(
              height: containerHeight,
              child: data.isEmpty
                  ? const Center(child: Text("Aucune donnée disponible.", style: TextStyle(color: Colors.black54, fontSize: 12)))
                  : ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: data.length,
                separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, index) {
                  final item = data[index];
                  final rank = index + 1;

                  Color rankColor;
                  FontWeight fontWeight;

                  if (rank == 1) {
                    rankColor = const Color(0xFFD4AF37);
                    fontWeight = FontWeight.w900;
                  } else if (rank == 2) {
                    rankColor = const Color(0xFF9E9E9E);
                    fontWeight = FontWeight.w800;
                  } else if (rank == 3) {
                    rankColor = const Color(0xFFA0522D);
                    fontWeight = FontWeight.w700;
                  } else {
                    rankColor = Colors.black87;
                    fontWeight = FontWeight.normal;
                  }

                  return ListTile(
                    visualDensity: const VisualDensity(horizontal: 0, vertical: -4),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    dense: true,

                    leading: SizedBox(
                      width: 20,
                      child: Text(
                        "$rank.",
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: rank <= 3 ? rankColor : Colors.grey
                        ),
                      ),
                    ),

                    title: Text(
                      item[keyNom]?.toString() ?? 'N/A',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: fontWeight,
                        color: rank <= 3 ? rankColor : Colors.black87,
                      ),
                    ),

                    trailing: Text(
                      "${item[keyValeur] ?? 0} $suffix",
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w600,
                          fontSize: 12
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}