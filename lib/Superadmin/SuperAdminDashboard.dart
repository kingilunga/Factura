import 'package:factura/Splash_login/connexion.dart';
import 'package:factura/Superadmin/database_page.dart';
import 'package:factura/Superadmin/licences_page.dart';
import 'package:factura/Superadmin/logs_page.dart';
import 'package:factura/Superadmin/passwords_page.dart';
import 'package:factura/Superadmin/settings_page.dart';
import 'package:factura/Superadmin/users_page.dart';
import 'package:flutter/material.dart';
import 'package:factura/Modeles/model_utilisateurs.dart';

// --- CONSTANTES DE STYLE ADMIN ---
const Color kPrimaryColor = Color(0xFF1565C0); // Bleu foncé pour un look professionnel
const Color kAccentColor = Color(0xFFFFB300); // Jaune-Orange pour l'accentuation
const Color kCardColor = Colors.white;
const Color kBackgroundColor = Color(0xFFF5F5F5);

// --- MODÈLES ET DONNÉES FICTIVES POUR LA PAGE D'ACCUEIL ---

class AdminCardData {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;
  AdminCardData({required this.title, required this.value, required this.icon, required this.color, required this.subtitle});
}

final List<AdminCardData> mockAdminData = [
  AdminCardData(title: "Ventes Annuelles", value: "1.2 M FC", icon: Icons.attach_money, color: Colors.green, subtitle: "+15% par rapport à l'année dernière"),
  AdminCardData(title: "Licences Actives", value: "847", icon: Icons.vpn_key, color: kPrimaryColor, subtitle: "Nouveaux clients ce mois: 32"),
  AdminCardData(title: "Erreurs Critiques", value: "12 Logs", icon: Icons.bug_report, color: Colors.redAccent, subtitle: "Dernière alerte il y a 5 min"),
  AdminCardData(title: "Admin Connectés", value: "5", icon: Icons.admin_panel_settings, color: kAccentColor, subtitle: "Audit de sécurité OK"),
];

// --- NOUVELLE PAGE D'ACCUEIL PROFESSIONNELLE (Index 0) ---
class SuperAdminHomePage extends StatelessWidget {
  final Utilisateur user;
  const SuperAdminHomePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // Padding global pour toute la page
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête de bienvenue
          Text(
            'Bienvenue Super Admin, ${user.prenom ?? ''} ${user.nom ?? ''} !',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: kPrimaryColor,
            ),
          ),
          const Divider(height: 30, thickness: 2),

          // Titre de la section
          Text(
            "Vue d'ensemble et Statistiques Clés",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 15),

          // Grille des cartes responsive
          _buildCardsGrid(),

          const SizedBox(height: 40),

          // Placeholder pour les Tableaux/Graphiques
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(15),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: Center(
              child: Text(
                "Espace pour Tableaux de Supervision et Rapports d'Alertes",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Crée la grille des cartes
  Widget _buildCardsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: mockAdminData.length,
      // Détermine la taille maximale d'une carte (350px) pour le responsive
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 3 / 2, // Ratio pour que la carte soit rectangulaire
      ),
      itemBuilder: (context, index) {
        return _buildInfoCard(mockAdminData[index]);
      },
    );
  }

  // Construit une carte d'information
  Widget _buildInfoCard(AdminCardData data) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          // Barre latérale colorée pour l'identification rapide
          border: Border(left: BorderSide(color: data.color, width: 6)),
          color: kCardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data.title, style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                Icon(data.icon, color: data.color, size: 30),
              ],
            ),
            const SizedBox(height: 10),
            // Valeur principale
            Text(data.value, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: kPrimaryColor)),
            // Sous-titre / Statut
            Text(data.subtitle, style: TextStyle(fontSize: 12, color: data.color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}


// --- WIDGET PRINCIPAL : BASÉ SUR VOTRE CODE ORIGINAL ---

class SuperAdminDashboard extends StatefulWidget {
  final Utilisateur user; // SuperAdmin connecté

  const SuperAdminDashboard({super.key, required this.user});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _selectedIndex = 0;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      // Utilisation de la nouvelle page d'accueil professionnelle
      SuperAdminHomePage(user: widget.user),
      const LicencesPage(),
      const DatabasePage(),
      const SuperadminUsersPage(),
      const PasswordsPage(),
      const LogsPage(),
      const SettingsPage(),
    ];
  }

  final List<String> _titles = [
    'Accueil',
    'Licences',
    'Base de données',
    'Comptes utilisateurs',
    'Mots de passe',
    'Accès & Logs',
    'Paramètres avancés',
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor, // Couleur de fond pour un look plus pro
      appBar: AppBar(
        // Utilisation des titres de votre liste
        title: Text(_titles[_selectedIndex]),
        // Changement de la couleur pour s'adapter au nouveau thème
        backgroundColor: kPrimaryColor,
        foregroundColor: kCardColor, // Texte et icônes blanches
        actions: [
          IconButton(
            // Utilisation de la couleur d'accentuation pour le bouton
            icon: const Icon(Icons.logout, color: kAccentColor),
            onPressed: () {
              // Assurez-vous que ConnexionPage est importé correctement
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const ConnexionPage()),
                    (Route<dynamic> route) => false,
              );
            },
          )
        ],
      ),

      // Affichage de la page sélectionnée
      body: _pages[_selectedIndex],

      // Votre BottomNavigationBar d'origine (Non Responsive, comme demandé)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        // Utilisation du thème de couleur
        selectedItemColor: kPrimaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(icon: Icon(Icons.vpn_key), label: 'Licences'),
          BottomNavigationBarItem(icon: Icon(Icons.storage), label: 'DB'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Utilisateurs'),
          BottomNavigationBarItem(icon: Icon(Icons.lock), label: 'Mots de passe'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Logs'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Paramètres'),
        ],
      ),
    );
  }
}
