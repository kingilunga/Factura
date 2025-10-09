import 'dart:convert';

import 'package:factura/DashboardAdmin/gestion_clients.dart';
import 'package:factura/DashboardAdmin/gestion_factures.dart';
import 'package:factura/DashboardAdmin/gestion_utilisateurs.dart';
import 'package:factura/DashboardAdmin/gestion_produits.dart';
import 'package:factura/DashboardAdmin/paramettres.dart';
import 'package:factura/DashboardAdmin/rapports_page.dart';
import 'package:flutter/material.dart';
import 'package:factura/Splash_login/connexion.dart';
import 'package:factura/database/models_utilisateurs.dart';
// Import du service et des modèles pour le tableau de bord
import 'package:factura/database/database_service.dart';
import 'package:http/http.dart' as http;

// CLASSE CONTENEUR PRINCIPAL DE L'ADMIN
class AdminDashboardPage extends StatefulWidget {
  final Utilisateur user;
  const AdminDashboardPage({super.key, required this.user});

  // 1. HELPER STATIQUE : Permet aux widgets enfants de naviguer (ex: TableauDeBordAdmin)
  static _AdminDashboardPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<_AdminDashboardPageState>();
  }

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;

  // Méthode pour changer de section, appelée par les widgets enfants.
  void selectSection(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // J'ai besoin de déclarer la page du tableau de bord ici
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    // Initialisation des pages du Dashboard Admin
    _pages = [
      const TableauDeBordAdmin(),                   // Accueil
      GestionUtilisateurs(currentUser: widget.user), // Utilisateurs (user obligatoire)
      const GestionProduits(),                      // Produits
      const GestionClients(),                       // Clients & Fournisseurs
      GestionFactures(),                            // Factures
      RapportsPage(typeDocument: "Facture"),        // Rapports
      const ParametresAdminPage(),                  // Paramètres
    ];
  }


  @override
  Widget build(BuildContext context) {
    final bool isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: isSmallScreen
          ? AppBar(
        title: const Text('Tableau de bord Admin'),
        backgroundColor: const Color(0xFF13132D),
        foregroundColor: Colors.white,
      )
          : null,
      drawer: isSmallScreen ? _buildDrawer(context) : null,
      body: Row(
        children: <Widget>[
          if (!isSmallScreen) _buildDrawer(context),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final String fullName =
        '${widget.user.prenom ?? ''}${(widget.user.postNom != null && widget.user.postNom!.isNotEmpty) ? ' ${widget.user.postNom!}' : ''} ${widget.user.nom ?? ''}';

    return Container(
      width: 250,
      color: const Color(0xFF13132D),
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          UserAccountsDrawerHeader(
            accountName: Text(fullName, style: const TextStyle(color: Colors.white)),
            accountEmail: Text(widget.user.email ?? '', style: const TextStyle(color: Colors.white70)),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.person,
                size: 50,
                color: Color(0xFF13132D),
              ),
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF13132D),
            ),
          ),
          _DrawerItem(
            icon: Icons.dashboard,
            title: 'Tableau de bord',
            index: 0,
            selectedIndex: _selectedIndex,
            onTap: () {
              selectSection(0);
              if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
            },
          ),
          _DrawerItem(
            icon: Icons.people,
            title: 'Utilisateurs',
            index: 1,
            selectedIndex: _selectedIndex,
            onTap: () {
              selectSection(1);
              if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
            },
          ),
          _DrawerItem(
            icon: Icons.inventory_2,
            title: 'Produits',
            index: 2,
            selectedIndex: _selectedIndex,
            onTap: () {
              selectSection(2);
              if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
            },
          ),
          _DrawerItem(
            icon: Icons.business,
            title: 'Clients & Fournisseurs',
            index: 3,
            selectedIndex: _selectedIndex,
            onTap: () {
              selectSection(3);
              if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
            },
          ),
          _DrawerItem(
            icon: Icons.receipt,
            title: 'Factures',
            index: 4,
            selectedIndex: _selectedIndex,
            onTap: () {
              selectSection(4);
              if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
            },
          ),
          _DrawerItem(
            icon: Icons.bar_chart,
            title: 'Rapports',
            index: 5,
            selectedIndex: _selectedIndex,
            onTap: () {
              selectSection(5);
              if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
            },
          ),
          const Divider(color: Colors.white54),
          _DrawerItem(
            icon: Icons.settings,
            title: 'Paramètres',
            index: 6,
            selectedIndex: _selectedIndex,
            onTap: () {
              selectSection(6);
              if (MediaQuery.of(context).size.width < 600) Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white),
            title: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Déconnexion"),
          content: const Text("Êtes-vous sûr de vouloir vous déconnecter?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Annuler"),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text("Déconnexion"),
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const ConnexionPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------
// CLASSE DE CONTENU : TABLEAU DE BORD ADMINISTRATEUR (Index 0)
// ---------------------------------------------------------------------

class TableauDeBordAdmin extends StatefulWidget {
  const TableauDeBordAdmin({super.key});

  @override
  State<TableauDeBordAdmin> createState() => _TableauDeBordAdminState();
}

class _TableauDeBordAdminState extends State<TableauDeBordAdmin> {
  // --- VARIABLES D'ÉTAT POUR LES DONNÉES RÉELLES ---
  final DatabaseService _db = DatabaseService.instance;

  AdminStats _stats = AdminStats();
  List<VenteRecenteApercu> _recentSales = [];
  List<ProduitApercu> _lowStockProducts = [];
  List<ClientApercu> _clientOverview = [];
  List<ProduitApercu> _topSellingProducts = [];
  List<VenteTendance> _salesTrends = [];

  bool _isLoading = true;
  String _selectedPeriod = 'Semaine';

  // ✅ NOUVEAU : Taux de change et CA calculé en USD/CDF
  double _exchangeRateUSDCDF = 0.0; // Taux 1 USD = X CDF
  double _caEnCDF = 0.0;
  double _caEnUSD = 0.0;


  // MISE À JOUR CRITIQUE : Mappage complet et correct
  final Map<String, String> _periodMap = {
    'Jour': 'Journalière',
    'Semaine': 'Hebdomadaire',
    'Mois': 'Mensuelle',
    'Année': 'Annuelle',
  };

  late final List<String> _displayPeriods;

  // CONSTANTE : Limite d'affichage pour les aperçus Top et Low
  static const int _displayLimit = 5;

  @override
  void initState() {
    super.initState();
    _displayPeriods = _periodMap.keys.toList();
    _fetchDashboardData();
  }

  // 1. ✅ NOUVELLE FONCTION : Récupérer le taux de change
  Future<double> _fetchExchangeRate() async {
    // 🚨 ATTENTION : Ceci est une valeur simulée (taux fixe de la BDC par exemple).
    // Dans la réalité, vous devriez utiliser un package comme 'http'
    // pour appeler une API (ex: Open Exchange Rates, Fixer, ou celle de votre banque).

    // Exemple de taux simulé : 1 USD = 2800 CDF
    await Future.delayed(const Duration(milliseconds: 50)); // Simuler le temps de l'API
    const double simulatedRate = 2800.0;

    return simulatedRate;
  }


  // --- LOGIQUE DE RÉCUPÉRATION DES DONNÉES ---
  // --- DANS LA CLASSE _TableauDeBordAdminState ---
  Future<double> _fetchExchangeRateFromApi() async {
    const String url = "https://api.exemple.com/taux_usd_cdf"; // Remplace par ton endpoint réel

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['USD_CDF'] != null) {
          return (data['USD_CDF'] as num).toDouble();
        } else {
          throw Exception("Clé USD_CDF manquante dans la réponse");
        }
      } else {
        throw Exception("Erreur HTTP: ${response.statusCode}");
      }
    } catch (e) {
      print("Erreur fetchExchangeRateFromApi: $e");
      throw e; // On remonte l'erreur
    }
  }

// Nouvelle version de _fetchExchangeRate() qui gère l'erreur

// Mise à jour du tableau de bord
  Future<void> _fetchDashboardData({bool reloadTrends = false}) async {
    if (!reloadTrends) setState(() => _isLoading = true);

    final dbPeriod = _periodMap[_selectedPeriod] ?? 'Hebdomadaire';

    try {
      // ✅ Récupérer le taux depuis la base
      final rate = await _db.fetchExchangeRate();

      // 2️⃣ Récupérer les stats Admin
      final statsResult = await _db.fetchAdminStats(period: dbPeriod);

      // 3️⃣ Calcul des conversions
      final caCDF = statsResult.totalChiffreAffaires;
      final caUSD = rate > 0 ? caCDF / rate : 0.0;

      // 4️⃣ Autres données
      final salesResult = await _db.fetchRecentSales(limit: _displayLimit);
      final stockResult = await _db.fetchLowStockProducts(threshold: 5, limit: _displayLimit);
      final topProductsResult = await _db.fetchTopSellingProducts(limit: _displayLimit);
      final clientResult = await _db.fetchClientOverview(limit: _displayLimit);
      final trendsResult = await _db.fetchSalesTrends(dbPeriod);

      if (mounted) {
        setState(() {
          _exchangeRateUSDCDF = rate;
          _caEnCDF = caCDF;
          _caEnUSD = caUSD;

          _stats = statsResult;
          _recentSales = salesResult;
          _lowStockProducts = stockResult;
          _topSellingProducts = topProductsResult;
          _clientOverview = clientResult;
          _salesTrends = trendsResult;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur de chargement du dashboard: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }


// --- DANS _buildExchangeRateBar() ---
  Widget _buildExchangeRateBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.lightGreen.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.lightGreen.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.monetization_on, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text(
            'Taux du jour: 1 USD = ${_exchangeRateUSDCDF.toStringAsFixed(2)} CDF',
            style: TextStyle(fontSize: 14, color: Colors.green.shade900, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          InkWell(
            onTap: () => _fetchDashboardData(reloadTrends: true),
            child: const Tooltip(
              message: "Recharger le taux de change",
              child: Icon(Icons.refresh, size: 20, color: Colors.green),
            ),
          )
        ],
      ),
    );
  }

  // Helper pour naviguer vers une autre section du Dashboard Admin
  void _goToSection(int index) {
    AdminDashboardPage.of(context)?.selectSection(index);
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    // Afficher un loader pendant le chargement initial
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          // Afficher le taux de change
          _buildExchangeRateBar(),
          const SizedBox(height: 16),
          // 2. Ligne des KPI
          _buildKpiRow(),
          const SizedBox(height: 16),
          // 3. Rangée du haut (Ventes Récentes & Stock Critique)
          isWide ? _buildWideGridTop() : _buildNarrowColumnTop(),
          const SizedBox(height: 16),
          // 4. Rangée du milieu (Produits Performants & Clients Performants)
          isWide ? _buildWideGridMiddle() : _buildNarrowColumnMiddle(),
          const SizedBox(height: 16),
          // 5. Dernière rangée de contenu (Tendance de Ventes & Actions Rapides)
          _buildBottomRow(isWide),
        ],
      ),
    );
  }

  // ✅ NOUVEAU : Barre d'information sur le taux de change
  /*Widget _buildExchangeRateBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.lightGreen.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.lightGreen.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.monetization_on, color: Colors.green.shade700),
          const SizedBox(width: 8),
          Text(
            'Taux du jour: 1 USD = ${_exchangeRateUSDCDF.toStringAsFixed(2)} CDF',
            style: TextStyle(fontSize: 14, color: Colors.green.shade900, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          // Bouton pour recharger le taux
          InkWell(
            onTap: () => _fetchDashboardData(reloadTrends: true),
            child: const Tooltip(
              message: "Recharger le taux de change",
              child: Icon(Icons.refresh, size: 20, color: Colors.green),
            ),
          )
        ],
      ),
    );
  }*/
  // En-tête (Nom de l'Admin + Sélecteur de période)
  Widget _buildHeader() {
    final periods = _displayPeriods;
    final isSelectedList = periods.map((p) => p == _selectedPeriod).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(
                backgroundColor: Colors.lightBlueAccent,
                child: Icon(Icons.verified_user, color: Colors.white)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tableau de bord, Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Text('Vue consolidée des opérations', style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            // SÉLECTEUR DE PÉRIODE COMPACT ET ACTIF
            ToggleButtons(
              isSelected: isSelectedList,
              onPressed: (i) {
                String newPeriod = periods[i];
                if (newPeriod != _selectedPeriod) {
                  setState(() {
                    _selectedPeriod = newPeriod;
                  });
                  _fetchDashboardData(reloadTrends: true);
                }
              },
              borderRadius: BorderRadius.circular(8),
              constraints: const BoxConstraints(minHeight: 38.0, minWidth: 60.0), // Contraintes pour compacter
              color: Colors.black54,
              selectedColor: Colors.white,
              fillColor: Colors.indigo, // Couleur de fond principale
              selectedBorderColor: Colors.indigo.shade700,
              children: periods.map((p) => Text(p, style: const TextStyle(fontWeight: FontWeight.w600))).toList(),
            ),
          ],
        ),
      ],
    );
  }

  // Widget pour les cartes KPI Administrateur
  Widget _buildKpiRow() {
    final lowStockIsCritical = _lowStockProducts.isNotEmpty;
    // Ajout de l'unité de temps pour les cartes
    final periodUnit = _selectedPeriod == 'Jour' ? '' : ' - $_selectedPeriod';

    return Column(
      children: [
        // ✅ NOUVELLE LIGNE DE KPI (CA en CDF et USD)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _KpiCard(
              label: 'CA Net (CDF)',
              value: _caEnCDF.toStringAsFixed(2),
              unit: 'CDF $periodUnit',
              color: Colors.blue.shade700, // Couleur différente pour le CA
            ),
            _KpiCard(
              label: 'CA Net (USD)',
              value: _caEnUSD.toStringAsFixed(2),
              unit: 'USD $periodUnit',
              color: Colors.green.shade700, // Couleur différente pour le CA
            ),
            // Les deux autres cartes prennent le reste de l'espace (inchangé)
            _KpiCard(label: 'Total Ventes', value: _stats.totalVentes.toString(), unit: periodUnit),
            _KpiCard(label: 'Total Clients', value: _stats.totalClients.toString(), unit: periodUnit),
          ],
        ),
        const SizedBox(height: 16),
        // Ligne pour le stock critique (décalée pour l'espace)
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Stock Critique',
                value: _lowStockProducts.length.toString(),
                color: lowStockIsCritical ? Colors.red.shade700 : Colors.indigo,
                unit: ' (${_displayLimit} articles)',
              ),
            ),
            const Spacer(flex: 3), // Remplit l'espace des 3 autres cartes de la première ligne
          ],
        ),
      ],
    );
  }

  // Layout large - Rangée du haut (Ventes Récentes & Stock Critique)
  Widget _buildWideGridTop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildSalesPanel()),
        const SizedBox(width: 12),
        Expanded(child: _buildLowStockPanel()),
      ],
    );
  }

  // Layout étroit - Rangée du haut (Ventes Récentes & Stock Critique)
  Widget _buildNarrowColumnTop() {
    return Column(
      children: [
        _buildSalesPanel(),
        const SizedBox(height: 12),
        _buildLowStockPanel(),
      ],
    );
  }

  // Layout large - Rangée du milieu (Produits Performants & Clients Performants)
  Widget _buildWideGridMiddle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildTopProductsPanel()), // NOUVEAU
        const SizedBox(width: 12),
        Expanded(child: _buildClientOverviewPanel()), // Anciennement _buildBottomRow.contactsCard
      ],
    );
  }

  // Layout étroit - Rangée du milieu (Produits Performants & Clients Performants)
  Widget _buildNarrowColumnMiddle() {
    return Column(
      children: [
        _buildTopProductsPanel(), // NOUVEAU
        const SizedBox(height: 12),
        _buildClientOverviewPanel(), // Anciennement _buildBottomRow.contactsCard
      ],
    );
  }

  // Section pour afficher les ventes récentes (Admin : lien vers les Factures)
  Widget _buildSalesPanel() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ventes Récentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                ElevatedButton.icon(
                  onPressed: () => _goToSection(4), // Index 4: Factures
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Voir toutes les Factures'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: _recentSales.isEmpty
                  ? Center(child: Text('Aucune vente récente trouvée (Top $_displayLimit).'))
                  : ListView.separated(
                itemCount: _recentSales.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final s = _recentSales[index];
                  // Afficher le montant dans la devise par défaut de la facture (ex: CDF)
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.receipt, color: Colors.blueGrey),
                    title: Text('${s.produitNom} (Vendu par ${s.vendeurNom})'),
                    subtitle: Text(s.dateVente),
                    trailing: Text('${s.montantNet.toStringAsFixed(2)} CDF', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section pour afficher le stock critique (Admin : lien vers Produits)
  Widget _buildLowStockPanel() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Stock Critique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                OutlinedButton.icon(
                  onPressed: () => _goToSection(2), // Index 2: Produits
                  icon: const Icon(Icons.inventory_2),
                  label: const Text('Gérer Produits'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180, // Hauteur ajustée pour correspondre à _buildSalesPanel
              child: _lowStockProducts.isEmpty
                  ? const Center(child: Text('Tous les produits sont bien en stock!'))
                  : ListView.separated(
                itemCount: _lowStockProducts.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final p = _lowStockProducts[index];
                  final isLowStock = p.stock <= 5 && p.stock > 0;
                  final isOutOfStock = p.stock == 0;

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: isOutOfStock ? Colors.red.shade200 : isLowStock ? Colors.orange.shade200 : Colors.indigo.shade100,
                      child: Icon(Icons.warning, size: 18, color: isOutOfStock ? Colors.red : isLowStock ? Colors.orange : Colors.indigo),
                    ),
                    title: Text(p.nom, style: const TextStyle(fontSize: 14)),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Stock: ${p.stock}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isOutOfStock ? Colors.red : Colors.orange)),
                      ],
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

  // NOUVEAU : Section pour afficher les produits les plus vendus (Top 5)
  Widget _buildTopProductsPanel() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Produits Performants (Top 5)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                OutlinedButton.icon(
                  onPressed: () => _goToSection(2), // Index 2: Produits
                  icon: const Icon(Icons.trending_up),
                  label: const Text('Rapport Produits'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200, // Hauteur fixe pour alignement
              child: _topSellingProducts.isEmpty
                  ? const Center(child: Text('Aucun produit n\'a encore été vendu pour l\'analyse.'))
                  : ListView.separated(
                itemCount: _topSellingProducts.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final p = _topSellingProducts[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Text('#${index + 1}', style: TextStyle(color: Colors.indigo.shade900, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(p.nom),
                    trailing: Text('${p.stock} unités vendues', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section pour afficher l'aperçu clients (Top 5)
  Widget _buildClientOverviewPanel() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Clients Performants (Top 5)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                OutlinedButton.icon(
                  onPressed: () => _goToSection(3), // Index 3: Clients & Fournisseurs
                  icon: const Icon(Icons.supervisor_account),
                  label: const Text("Gérer les contacts"),
                )
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200, // Hauteur fixe pour alignement avec _buildTopProductsPanel
              child: _clientOverview.isEmpty
                  ? Center(child: Text('Aucun client enregistré pour l\'aperçu (Top $_displayLimit).'))
                  : ListView.separated(
                itemCount: _clientOverview.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final c = _clientOverview[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.person_outline, color: Colors.blue),
                    ),
                    title: Text(c.nomClient),
                    trailing: Text('${c.totalOperations} achats', style: const TextStyle(fontWeight: FontWeight.w500)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Section Tendance de Ventes et Actions Rapides
  Widget _buildBottomRow(bool isWide) {
    // Dans cette version, l'Action Card prend toute la largeur
    final actionsCard = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tendance de Ventes (${_selectedPeriod})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 12),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                // PLaceholder pour le graphique. Les données sont dans _salesTrends.
                child: _salesTrends.isEmpty
                    ? Text('Données de tendance de ventes non disponibles pour $_selectedPeriod.')
                    : const Text('Graphique de Tendance de Ventes (À Implémenter)'),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Actions Rapides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(onPressed: () => _goToSection(4), icon: const Icon(Icons.add_box), label: const Text('Nouvelle Facture')),
                OutlinedButton.icon(onPressed: () => _goToSection(1), icon: const Icon(Icons.people), label: const Text('Gérer Utilisateurs')),
                OutlinedButton.icon(onPressed: () => _goToSection(2), icon: const Icon(Icons.inventory_2), label: const Text('Ajouter Produit')),
                OutlinedButton.icon(onPressed: () => _goToSection(5), icon: const Icon(Icons.assessment), label: const Text('Rapports Détaillés')),
              ],
            )
          ],
        ),
      ),
    );

    // La carte Actions/Tendance prend la pleine largeur
    return actionsCard;
  }
}

// Petite carte KPI réutilisable (MODIFIÉE pour accepter une unité/période)
class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String unit; // ✅ Pour afficher la période ou la devise
  final double fontSize;

  const _KpiCard({
    required this.label,
    required this.value,
    this.color = Colors.indigo,
    this.unit = '',
    this.fontSize = 24, // Permet de réduire la taille du texte si nécessaire
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1: Label
              Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              // Ligne 2: Valeur + Unité
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Unité (ex: CDF - Semaine)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Text(
                      unit,
                      style: TextStyle(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget pour les items du drawer (couleur renforcée)
class _DrawerItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final int index;
  final int selectedIndex;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.index,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _isHovering = false;
  // Définition d'une couleur plus forte pour la sélection
  static const Color _selectedColor = Color.fromARGB(255, 30, 30, 60); // Un bleu marine très foncé/noir bleu
  static const Color _hoverColor = Color.fromARGB(255, 38, 38, 76); // Un peu plus clair pour le survol

  @override
  Widget build(BuildContext context) {
    // Si l'élément est sélectionné, on utilise une couleur très foncée (similaire à la couleur de fond du Drawer, mais légèrement différente)
    final bool isSelected = widget.selectedIndex == widget.index;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: Container(
        color: isSelected ? _selectedColor : (_isHovering ? _hoverColor : null),
        child: ListTile(
          leading: Icon(widget.icon, color: Colors.white),
          title: Text(widget.title, style: const TextStyle(color: Colors.white)),
          onTap: widget.onTap,
        ),
      ),
    );
  }
}
