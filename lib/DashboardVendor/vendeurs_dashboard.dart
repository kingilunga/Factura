import 'package:factura/DashboardVendor/afficher_clients.dart';
import 'package:factura/DashboardVendor/ajout_produitsPage.dart';
import 'package:factura/DashboardVendor/enregistrement_proformas.dart';
import 'package:factura/DashboardVendor/gestion_produitsPage.dart';
import 'package:factura/DashboardVendor/statistiques.dart';
import 'package:factura/DashboardVendor/ventes.dart'; // Alias: EnregistrementVente
// [AJOUT] Import de la page Pro-Forma
import 'package:flutter/material.dart';
import 'package:factura/Splash_login/connexion.dart';
import 'package:factura/Modeles/model_utilisateurs.dart';
import 'package:factura/DashboardVendor/rapports.dart';

/// CONTENEUR PRINCIPAL DU TABLEAU DE BORD VENDEUR
class VendeursDashboardPage extends StatefulWidget {
  final Utilisateur? user;

  const VendeursDashboardPage({super.key, this.user});

  @override
  State<VendeursDashboardPage> createState() => _VendeurDashboardPageState();
}

class _VendeurDashboardPageState extends State<VendeursDashboardPage> {

  // Fonction de navigation utilisée par les sous-pages
  void _changePage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  int _selectedIndex = 0;

  // [MODIFICATION] Mise à jour de la liste des titres
  final List<String> _sectionsTitles = [
    "Tableau de bord du vendeur", // Index 0
    "Ajout des Produits",         // Index 1
    "Nos Clients",                // Index 2
    "Ventes produits",            // Index 3
    "Factures Pro-Forma",         // Index 4 (NOUVEAU)
    "Stock produits",             // Index 5 (Décalé)
    "Rapports détaillés"          // Index 6 (Décalé)
  ];

  // 💡 TEMPORAIRE : ID du vendeur
  final int currentVendeurId = 1;

  // [MODIFICATION] Mise à jour de la liste des Widgets
  late final List<Widget> _sectionsContent = [
    // 0. Statistiques
    Statistiques(onNavigate: _changePage, currentVendeurId: currentVendeurId),
    // 1. Ajout Produits
    const AjoutProduitsPage(),
    // 2. Clients
    const AfficherClientsPage(),
    // 3. Ventes (Facturation)
    const EnregistrementVente(),
    // 4. [NOUVEAU] Pro-Forma
    const EnregistrementProForma(),
    // 5. Stock (Décalé)
    const GestionStockProduitsVendor(),
    // 6. Rapports (Décalé)
    const Rapports(typeDocument: '',),
  ];

  void _deconnexion() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const ConnexionPage()),
          (route) => false,
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Confirmer la déconnexion'),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Déconnexion'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      _deconnexion();
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;
    final userName = widget.user?.prenom ?? "Vendeur";

    return Scaffold(
      appBar: AppBar(
        title: Text(_sectionsTitles[_selectedIndex]),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Déconnexion',
              onPressed: () => _confirmLogout(context),
            ),
        ],
      ),

      // Drawer pour Web/Desktop
      drawer: !isMobile
          ? Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.indigo),
              child: Text(
                "Bienvenue $userName",
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            for (int i = 0; i < _sectionsTitles.length; i++)
              ListTile(
                leading: _getIconForIndex(i),
                title: Text(_sectionsTitles[i]),
                selected: _selectedIndex == i,
                onTap: () {
                  setState(() => _selectedIndex = i);
                  Navigator.pop(context);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmLogout(context);
              },
            ),
          ],
        ),
      )
          : null,

      // BottomNavigation pour Mobile
      bottomNavigationBar: isMobile
          ? BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        items: [
          for (int i = 0; i < _sectionsTitles.length; i++)
            BottomNavigationBarItem(
              icon: _getIconForIndex(i),
              label: _sectionsTitles[i],
            ),
        ],
      )
          : null,

      body: _sectionsContent[_selectedIndex],
    );
  }

  // [MODIFICATION] Mise à jour des icônes pour correspondre aux nouveaux index
  Icon _getIconForIndex(int index) {
    switch(index) {
      case 0: return const Icon(Icons.dashboard);
      case 1: return const Icon(Icons.add);
      case 2: return const Icon(Icons.people);
      case 3: return const Icon(Icons.point_of_sale);
      case 4: return const Icon(Icons.description); // Icône Pro-Forma (Index 4)
      case 5: return const Icon(Icons.inventory);   // Icône Stock (Index 5)
      case 6: return const Icon(Icons.analytics);   // Icône Rapports (Index 6)
      default: return const Icon(Icons.help);
    }
  }
}