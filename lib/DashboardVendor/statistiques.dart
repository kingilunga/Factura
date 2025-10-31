import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart'; // Import pour la DB
import 'package:factura/database/model_ventes.dart'; // Supposé exister
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
// Note: J'ai retiré l'import de 'package:factura/api_calls.dart'; car on utilise la DB.

typedef OnNavigate = void Function(int index);

// --- Widget TauxChangeWidget (Mis à jour pour utiliser la DB) ---
class TauxChangeWidget extends StatefulWidget {
  final ValueChanged<double>? onTauxUpdated;

  const TauxChangeWidget({Key? key, this.onTauxUpdated}) : super(key: key);

  @override
  State<TauxChangeWidget> createState() => _TauxChangeWidgetState();
}

class _TauxChangeWidgetState extends State<TauxChangeWidget> {
  // Accès à la DB
  final _db = DatabaseService.instance;
  double? tauxUSD;
  bool isLoading = false;
  // dbFailed remplace apiFailed
  bool dbFailed = false;

  @override
  void initState() {
    super.initState();
    // Le taux doit être chargé au démarrage
    _refreshTaux();
  }

  // MODIFIÉ : Récupération du taux depuis la base de données
  Future<void> _refreshTaux() async {
    setState(() {
      isLoading = true;
      dbFailed = false;
    });

    double? taux;
    try {
      // 💡 FUTURE : Appel à votre méthode réelle de la base de données
      // taux = await _db.getTauxUSD();

      // TEMPORAIRE: Simulation du taux de la DB (doit être remplacé par la ligne ci-dessus)
      await Future.delayed(const Duration(milliseconds: 500));
      taux = 2450.0; // Taux récupéré de la DB (simulé)

    } catch (e) {
      if (kDebugMode) {
        print("Erreur lors de la récupération du taux depuis la DB: $e");
      }
    }


    setState(() {
      if (taux != null && taux! > 0) {
        tauxUSD = taux;
        dbFailed = false;
      } else {
        dbFailed = true;
        // Valeur de secours si la DB échoue ou n'a pas de taux
        tauxUSD = 2500.0;
      }
      isLoading = false;
    });

    if (tauxUSD != null) {
      widget.onTauxUpdated?.call(tauxUSD!);
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
                  // Le libellé est mis à jour pour refléter l'origine du taux
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
                else if (dbFailed)
                  Text(
                    // Message en cas d'échec de la DB (utilise la valeur de secours)
                    "${tauxUSD?.toStringAsFixed(2)} CDF (Défaut)",
                    style: const TextStyle(fontSize: 16, color: Colors.redAccent, fontWeight: FontWeight.bold),
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
              tooltip: "Rafraîchir le taux depuis la base de données",
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
  // Référence à la base de données
  final _db = DatabaseService.instance;
  String _selectedPeriod = 'Jour';
  double chiffreAffairesCDF = 0;
  double chiffreAffairesUSD = 0;
  int ventesEffectuees = 0;
  int nouveauxClients = 0;
  double tauxUSD = 2500.0; // Valeur par défaut (surchargée par TauxChangeWidget)

  List<Map<String, dynamic>> topProduits = [];
  List<Map<String, dynamic>> topClients = [];
  List<Map<String, dynamic>> produitsCritiques = [];

  // Réduction du nombre de décimales pour les montants CDF pour gagner de l'espace
  final NumberFormat currencyCDF = NumberFormat("#,##0", "fr_FR");
  final NumberFormat currencyUSD = NumberFormat("#,##0.00", "en_US");

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Le taux est géré par TauxChangeWidget
  }

  void _updateUSD() {
    // Si la valeur de la DB est zéro ou non initialisée, on évite la division.
    if (tauxUSD > 0) {
      chiffreAffairesUSD = chiffreAffairesCDF / tauxUSD;
    } else {
      chiffreAffairesUSD = 0;
    }
  }

  Future<void> _loadStats() async {
    // Ventes est un placeholder pour le modèle réel de vente
    final allVentes = await _db.getAllVentes();
    final now = DateTime.now();
    // Changé List<Vente> en List<dynamic> pour la simulation
    List<dynamic> filtered = [];

    // Logique de filtrage (inchangée)
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
      // NOTE: J'ai laissé la logique de fold telle quelle, assumant que Vente a bien un champ totalNet
      // Vente n'est pas défini ici, mais on suppose qu'il a le champ 'totalNet'.
      chiffreAffairesCDF = filtered.fold(0.0, (sum, v) => sum + v.totalNet);
      ventesEffectuees = filtered.length;
      // Assume clientLocalId est aussi présent
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

  @override
  Widget build(BuildContext context) {
    // --- Fond gris doux tiré de la palette ---
    const Color softGrayBackground = Color(0xFFA5A9B1);
    // Index de la page "Ventes produits"
    const int ventePageIndex = 3;

    return Scaffold(
      backgroundColor: softGrayBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- NOUVEAU : Row pour les Boutons de Période et le Bouton de Vente ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, // Distribuer l'espace
              children: [
                // 1. Boutons de Période
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

                // 2. Bouton "Vendre des produits" (à l'extrémité droite)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, // Une couleur d'action primaire
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 6,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), // Plus grand
                  ),
                  onPressed: () {
                    // Naviguer vers l'index 3 : Ventes produits
                    widget.onNavigate?.call(ventePageIndex);
                  },
                  icon: const Icon(Icons.shopping_cart, size: 20),
                  label: const Text(
                    "Vendre des produits",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            // --- FIN NOUVELLE ROW ---

            const SizedBox(height: 16),

            // --- TauxChangeWidget avec callback ---
            TauxChangeWidget(
              // Mise à jour du taux via callback
              onTauxUpdated: (double newTaux) {
                setState(() {
                  tauxUSD = newTaux;
                  _updateUSD();
                });
              },
            ),

            const SizedBox(height: 24),

            // --- Cartes de Statistiques (inchangées) ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CA CDF : Flex 3
                Expanded(
                  flex: 3,
                  child: _buildStatCard("Chiffre d'affaires (CDF)",
                      currencyCDF.format(chiffreAffairesCDF), Icons.money, Colors.green.shade700, suffix: "CDF", isSimple: false),
                ),
                const SizedBox(width: 16), // Espacement

                // CA USD : Flex 3
                Expanded(
                  flex: 3,
                  child: _buildStatCard("Chiffre d'affaires (USD)",
                      currencyUSD.format(chiffreAffairesUSD), Icons.attach_money, Colors.teal.shade700, suffix: "\$", isSimple: false),
                ),
                const SizedBox(width: 16), // Espacement

                // Ventes effectuées : Flex 2 (Réduction)
                Expanded(
                  flex: 2,
                  child: _buildStatCard("Ventes effectuées", "$ventesEffectuees",
                      Icons.point_of_sale, Colors.orange.shade700, isSimple: true),
                ),
                const SizedBox(width: 16), // Espacement

                // Nouveaux clients : Flex 2 (Réduction)
                Expanded(
                  flex: 2,
                  child: _buildStatCard("Nouveaux clients", "$nouveauxClients",
                      Icons.people, Colors.blue.shade700, isSimple: true),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- Cartes de Liste (inchangées) ---
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildScrollableListCard(
                      "Produits performants (Top 5)",
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
                      "Clients performants (Top 5)",
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

            const SizedBox(height: 32),

            // --- Suppression de la section Actions rapides (car l'action principale est déplacée) ---
            // _buildQuickActions(),
          ],
        ),
      ),
    );
  }

  // --- Fonctions utilitaires inchangées ---
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
            // Icône
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 12),

            // Contenu (Titre et Valeur)
            Expanded(
              child: isSimple ?
              // 1. Structure pour Ventes et Clients (isSimple = true)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                ],
              )
                  :
              // 2. Structure pour Chiffre d'Affaires (isSimple = false)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Le titre inclut déjà l'unité (ex: Chiffre d'affaires (CDF))
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      // Valeur principale
                      Expanded(
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (suffix != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Text(
                            suffix,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: color.withOpacity(0.7),
                            ),
                          ),
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
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const Divider(height: 16, thickness: 1),
            SizedBox(
              height: 230,
              child: data.isEmpty
                  ? const Center(child: Text("Aucune donnée disponible pour cette période.", style: TextStyle(color: Colors.black54)))
                  : ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final item = data[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: color.withOpacity(0.15),
                      child: Text("${index + 1}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                    ),
                    title: Text(item[keyNom]?.toString() ?? 'N/A', overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text("${item[keyValeur] ?? 0} $suffix",
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- La fonction _buildQuickActions a été retirée car l'action principale est déplacée ---
  // Rendre les actions inutiles si l'action principale n'est plus là.
  // J'ai commenté la fonction pour l'instant.
  // Widget _buildQuickActions() {
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Text(
  //         "Actions rapides",
  //         style: TextStyle(
  //           fontSize: 20,
  //           fontWeight: FontWeight.bold,
  //           color: Color(0xFF13132D),
  //         ),
  //       ),
  //       const SizedBox(height: 16),
  //       Wrap(
  //         spacing: 20,
  //         runSpacing: 20,
  //         children: [
  //           // L'action principale est désormais dans le header
  //           // _buildActionButton("Vendre des produits", Icons.shopping_cart, Colors.indigo.shade600, () {
  //           //   widget.onNavigate?.call(3);
  //           // }),
  //           _buildActionButton("Ajouter des produits", Icons.add_box, Colors.green.shade600, () {
  //             widget.onNavigate?.call(1);
  //           }),
  //           _buildActionButton("Imprimer une facture", Icons.print, Colors.orange.shade600, () {
  //             widget.onNavigate?.call(5);
  //           }),
  //         ],
  //       ),
  //     ],
  //   );
  // }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      label: Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
    );
  }
}
