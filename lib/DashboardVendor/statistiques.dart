import 'package:factura/api_calls.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/model_ventes.dart';
import 'package:intl/intl.dart';

typedef OnNavigate = void Function(int index);

// --- Widget TauxChangeWidget déjà modifié pour API dynamique ---
class TauxChangeWidget extends StatefulWidget {
  final ValueChanged<double>? onTauxUpdated;

  const TauxChangeWidget({Key? key, this.onTauxUpdated}) : super(key: key);

  @override
  State<TauxChangeWidget> createState() => _TauxChangeWidgetState();
}

class _TauxChangeWidgetState extends State<TauxChangeWidget> {
  double? tauxUSD;
  bool isLoading = false;
  bool apiFailed = false;

  @override
  void initState() {
    super.initState();
    _refreshTaux();
  }

  Future<void> _refreshTaux() async {
    setState(() {
      isLoading = true;
      apiFailed = false;
    });

    double? taux = await fetchTauxBCC();

    setState(() {
      if (taux != null) {
        tauxUSD = taux;
        apiFailed = false;
      } else {
        apiFailed = true;
        tauxUSD = 2500.0; // valeur de secours
      }
      isLoading = false;
    });

    if (taux != null) {
      widget.onTauxUpdated?.call(tauxUSD!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.monetization_on, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  "Taux USD :",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                if (isLoading)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (apiFailed)
                  Text(
                    "${tauxUSD?.toStringAsFixed(2)} CDF",
                    style: const TextStyle(fontSize: 16, color: Colors.redAccent),
                  )
                else
                  Text(
                    "${tauxUSD?.toStringAsFixed(2)} CDF",
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
              ],
            ),
            IconButton(
              icon: isLoading
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.refresh, color: Colors.blue),
              onPressed: isLoading ? null : _refreshTaux,
              tooltip: "Rafraîchir le taux",
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
  String _selectedPeriod = 'Jour';
  double chiffreAffairesCDF = 0;
  double chiffreAffairesUSD = 0;
  int ventesEffectuees = 0;
  int nouveauxClients = 0;
  double tauxUSD = 2500.0; // Valeur par défaut

  List<Map<String, dynamic>> topProduits = [];
  List<Map<String, dynamic>> topClients = [];
  List<Map<String, dynamic>> produitsCritiques = [];
  final _db = DatabaseService.instance;

  final NumberFormat currencyCDF = NumberFormat("#,##0.00", "fr_FR");
  final NumberFormat currencyUSD = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  void _updateUSD() {
    if (tauxUSD > 0) {
      chiffreAffairesUSD = chiffreAffairesCDF / tauxUSD;
    }
  }

  Future<void> _loadStats() async {
    final allVentes = await _db.getAllVentes();
    final now = DateTime.now();
    List<Vente> filtered = [];

    switch (_selectedPeriod) {
      case 'Jour':
        filtered = allVentes.where((v) {
          final date = DateTime.parse(v.dateVente);
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
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
      chiffreAffairesCDF = filtered.fold(0.0, (sum, v) => sum + v.totalNet);
      ventesEffectuees = filtered.length;
      nouveauxClients = filtered.map((v) => v.clientLocalId).toSet().length;
    });

    _updateUSD();
    await _loadTops();
  }

  Future<void> _loadTops() async {
    try {
      final produits = await _db.fetchTopSellingProducts();
      final clients = await _db.fetchClientOverview();
      final critiques = await _db.fetchCriticalStock(limit: 10);

      setState(() {
        topProduits = produits.map((p) => {
          'nom': p.nom,
          'quantiteVendue': p.stock,
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
      print("Erreur lors du chargement des tops: $e");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: ['Jour', 'Semaine', 'Mois', 'Année'].map((p) {
                final selected = _selectedPeriod == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected ? Colors.indigo : Colors.grey[300],
                      foregroundColor: selected ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => _selectPeriod(p),
                    child: Text(p),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // --- TauxChangeWidget avec callback ---
            TauxChangeWidget(
              onTauxUpdated: (double newTaux) {
                setState(() {
                  tauxUSD = newTaux;
                  _updateUSD();
                });
              },
            ),

            const SizedBox(height: 24),

            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildStatCard("Chiffre d'affaires (CDF)",
                    "${currencyCDF.format(chiffreAffairesCDF)} CDF", Icons.money, Colors.green),
                _buildStatCard("Chiffre d'affaires (USD)",
                    "${currencyUSD.format(chiffreAffairesUSD)} \$", Icons.attach_money, Colors.teal),
                _buildStatCard("Ventes effectuées", "$ventesEffectuees",
                    Icons.point_of_sale, Colors.orange),
                _buildStatCard("Nouveaux clients", "$nouveauxClients",
                    Icons.people, Colors.blue),
              ],
            ),

            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final int crossAxisCount = width > 1000
                    ? 3
                    : width > 500
                    ? 2
                    : 1;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildScrollableListCard(
                      "Produits performants (Top 5)",
                      Icons.star,
                      topProduits,
                      "nom",
                      "quantiteVendue",
                      "unités",
                      Colors.green,
                    ),
                    _buildScrollableListCard(
                      "Stocks critiques (≤10)",
                      Icons.warning_amber_rounded,
                      produitsCritiques,
                      "nom",
                      "quantiteActuelle",
                      "restants",
                      Colors.redAccent,
                    ),
                    _buildScrollableListCard(
                      "Clients performants (Top 5)",
                      Icons.people_alt,
                      topClients,
                      "nomClient",
                      "totalOperations",
                      "achats",
                      Colors.blue,
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 32),

            _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  // --- Fonctions utilitaires (_buildStatCard, _buildScrollableListCard, _buildQuickActions, _buildActionButton) ---
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 250,
              child: data.isEmpty
                  ? const Center(child: Text("Aucune donnée disponible."))
                  : ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final item = data[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.1),
                      child: Icon(Icons.trending_up, color: color),
                    ),
                    title: Text(item[keyNom]?.toString() ?? 'N/A', overflow: TextOverflow.ellipsis),
                    trailing: Text("${item[keyValeur] ?? 0} $suffix",
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Actions rapides", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildActionButton("Vendre des produits", Icons.shopping_cart, Colors.indigo, () {
              widget.onNavigate?.call(3);
            }),
            _buildActionButton("Ajouter des produits", Icons.add_box, Colors.green, () {
              widget.onNavigate?.call(1);
            }),
            _buildActionButton("Imprimer une facture", Icons.print, Colors.orange, () {
              widget.onNavigate?.call(5);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 22),
      label: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }
}
