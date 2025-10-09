import 'package:factura/DashboardAdmin/gestion_produits.dart';
import 'package:factura/DashboardVendor/afficher_clients.dart';
import 'package:factura/DashboardVendor/ajout_produitsPage.dart';
import 'package:factura/DashboardVendor/gestion_produitsPage.dart';
import 'package:factura/DashboardVendor/statistiques.dart';
import 'package:factura/DashboardVendor/ventes.dart';
import 'package:flutter/material.dart';
import 'package:factura/DashboardAdmin/rapports_page.dart';
import 'package:factura/Splash_login/connexion.dart';
import 'package:factura/database/models_utilisateurs.dart';
import 'package:factura/DashboardVendor/rapports.dart';

// Import des vues spécifiques au Vendeur
// Import de la page Clients (anciennement Fournisseurs)


/// CONTENEUR PRINCIPAL DU TABLEAU DE BORD VENDEUR
/// Cette page gère la navigation (Drawer/BottomNavBar) et affiche les différentes sections.
class VendeursDashboardPage extends StatefulWidget {
  final Utilisateur? user; // Rendre l'utilisateur optionnel pour les tests

  const VendeursDashboardPage({super.key, this.user});

  @override
  State<VendeursDashboardPage> createState() => _VendeurDashboardPageState();
}

class _VendeurDashboardPageState extends State<VendeursDashboardPage> {
  // Fonction de changement d'index qui sera passée aux sous-pages comme Statistiques
  void _changePage(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  int _selectedIndex = 0;

  // Liste des titres de sections
  final List<String> _sectionsTitles = [
    "Tableau de bord du vendeur",
    "Ajout des Produits", // Titre mis à jour
    "Nos Clients",
    "Ventes produits",
    "Stock produits",
    "Rapports détaillés"
  ];

  // 💡 TEMPORAIRE : ID du vendeur à remplacer par l'ID réel après connexion
  final int currentVendeurId = 1;

  // Liste des pages de contenu
  late final List<Widget> _sectionsContent = [
    // Statistiques doit pouvoir changer l'index (l'onglet)
    Statistiques(onNavigate: _changePage, currentVendeurId: currentVendeurId),
    const AjoutProduitsPage(), // Contenu réel
    const AfficherClientsPage(),  // Contenu réel
    const EnregistrementVente(),// Page réelle
    const GestionProduitsPage(),
    const Rapports(), // Page des rapports
  ];

  void _deconnexion() {
    // Revenir à la page de connexion
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const ConnexionPage()),
          (route) => false,
    );
  }

  // 🛠️ LA MÉTHODE _confirmLogout POUR LA DÉCONNEXION SÉCURISÉE 🛠️
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
              onPressed: () => Navigator.of(context).pop(false), // Annuler
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).pop(true), // Confirmer
              child: const Text('Déconnexion'),
            ),
          ],
        );
      },
    );

    // Si la déconnexion est confirmée, appeler la méthode _deconnexion qui fait la redirection.
    if (confirmed == true) {
      _deconnexion();
    }
  }


  @override
  Widget build(BuildContext context) {
    bool isMobile = MediaQuery.of(context).size.width < 600;

    // Nom de l'utilisateur (prend 'Vendeur' si l'utilisateur est null)
    final userName = widget.user?.prenom ?? "Vendeur";

    return Scaffold(
      appBar: AppBar(
        title: Text(_sectionsTitles[_selectedIndex]), // Titre dynamique
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          // Bouton Déconnexion seulement sur Mobile/Tablette si pas de Drawer visible
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Déconnexion',
              onPressed: () => _confirmLogout(context), // Appel corrigé
            ),
        ],
      ),

      // Drawer pour Web/Desktop (menu latéral)
      drawer: !isMobile
          ? Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.indigo),
              child: Text(
                "Bienvenue $userName",
                style:
                const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ),
            for (int i = 0; i < _sectionsTitles.length; i++)
              ListTile(
                leading: _getIconForIndex(i), // Ajout d'une icône
                title: Text(_sectionsTitles[i]),
                selected: _selectedIndex == i,
                onTap: () {
                  setState(() => _selectedIndex = i);
                  Navigator.pop(context);
                },
              ),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red), // Utiliser rouge pour l'action
              title: const Text('Déconnexion', style: TextStyle(color: Colors.red)), // Utiliser rouge pour l'action
              onTap: () {
                Navigator.pop(context); // Fermer le drawer avant le dialogue
                _confirmLogout(context); // Appel corrigé
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
        type: BottomNavigationBarType.fixed, // Permet plus de 3 éléments
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

      // Affichage du contenu sélectionné
      body: _sectionsContent[_selectedIndex],
    );
  }

  // Fonction utilitaire pour obtenir l'icône
  Icon _getIconForIndex(int index) {
    switch(index) {
      case 0: return const Icon(Icons.dashboard);
      case 1: return const Icon(Icons.add);
      case 2: return const Icon(Icons.people);
      case 3: return const Icon(Icons.point_of_sale);
      case 4: return const Icon(Icons.inventory );
      case 5: return const Icon(Icons.analytics);
      default: return const Icon(Icons.help);
    }
  }
}
