/*import 'package:factura/database/model_clients.dart';
import 'package:factura/database/model_produits.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/models_utilisateurs.dart';
import 'package:factura/Splash_login/connexion.dart';

// Panels
import 'package:factura/panels/low_stocks.dart';
import 'package:factura/panels/sales_panel.dart';
import 'package:factura/panels/top_clients.dart';
import 'package:factura/panels/top_produits.dart';


class AdminDashboardPage extends StatefulWidget {
  final Utilisateur user;
  const AdminDashboardPage({super.key, required this.user});

  static _AdminDashboardPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<_AdminDashboardPageState>();
  }

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;

  // Database
  final DatabaseService _db = DatabaseService.instance;

  // Dashboard Data
  List<VenteRecenteApercu> _recentSales = [];
  List<Produit> _lowStockProducts = [];
  List<Produit> _topSellingProducts = [];
  List<Client> _topClients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final recentSales = await _db.fetchRecentSales(limit: 5);
      final lowStock = await _db.fetchLowStockProducts(limit: 5);
      final topProducts = await _db.fetchTopSellingProducts(limit: 5);
      final topClients = await _db.fetchTopClients(limit: 5);

      if (mounted) {
        setState(() {
          _recentSales = recentSales;
          _lowStockProducts = lowStock.cast<Produit>();
          _topSellingProducts = topProducts.cast<Produit>();
          _topClients = topClients.cast<Client>();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur dashboard: $e");
      setState(() => _isLoading = false);
    }
  }

  void selectSection(int index) => setState(() => _selectedIndex = index);
  void _goToSection(int index) => AdminDashboardPage.of(context)?.selectSection(index);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord Admin'),
        backgroundColor: const Color(0xFF13132D),
      ),
      drawer: _buildDrawer(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ✅ Ventes récentes
            buildSalesPanel(
              recentSales: _recentSales,
              goToSection: _goToSection, displayLimit: null,
            ),

            const SizedBox(height: 12),

            // ✅ Produits en stock critique
            buildLowStockPanel(
              lowStockProducts: _lowStockProducts,
              goToSection: _goToSection,
              displayLimit: 5, produits: [],
            ),

            const SizedBox(height: 12),

            // ✅ Top produits
            buildTopProduitsPanel(
              topSellingProducts: _topSellingProducts,
              goToSection: _goToSection,
            ),

            const SizedBox(height: 12),

            // ✅ Top clients
            buildTopClientsPanel(
              topClients: _topClients,
              goToSection: _goToSection, clients: [], clientPurchases: {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final fullName =
        '${widget.user.prenom ?? ''} ${widget.user.postNom ?? ''} ${widget.user.nom ?? ''}';
    return Drawer(
      child: ListView(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(fullName),
            accountEmail: Text(widget.user.email ?? ''),
            currentAccountPicture: const CircleAvatar(
              child: Icon(Icons.person),
            ),
          ),
          _drawerItem(Icons.dashboard, 'Tableau de bord', 0),
          _drawerItem(Icons.people, 'Utilisateurs', 1),
          _drawerItem(Icons.inventory_2, 'Produits', 2),
          _drawerItem(Icons.business, 'Clients', 3),
          _drawerItem(Icons.receipt, 'Factures', 4),
          _drawerItem(Icons.bar_chart, 'Rapports', 5),
          _drawerItem(Icons.settings, 'Paramètres', 6),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Déconnexion'),
            onTap: () {
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const ConnexionPage()));
            },
          )
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, int index) {
    final selected = _selectedIndex == index;
    return ListTile(
      leading: Icon(icon, color: selected ? Colors.indigo : Colors.black54),
      title: Text(title, style: TextStyle(color: selected ? Colors.indigo : Colors.black)),
      onTap: () => selectSection(index),
    );
  }
}*/