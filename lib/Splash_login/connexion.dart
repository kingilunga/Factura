import 'package:factura/DashboardVendor/vendeurs_dashboard.dart';
import 'package:factura/Superadmin/SuperAdminDashboard.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/models_utilisateurs.dart';
import 'package:factura/DashboardAdmin/admin_dashboard.dart';

class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _motDePasseController = TextEditingController();

  // Chemins d'assets
  final String _appIconPath = 'assets/images/Icon_FacturaVision.png';
  // >>> ACTIVER LE CHEMIN DE L'IMAGE D'ARRIÈRE-PLAN ICI <<<
  final String? _backgroundImagePath = 'assets/images/arrierephoto.jpg';

  final DatabaseService _databaseService = DatabaseService.instance;

  String? _errorMessage;

  void _login() async {
    final String email = _emailController.text.trim();
    final String motDePasse = _motDePasseController.text;

    setState(() {
      _errorMessage = null;
    });

    if (email.isEmpty || motDePasse.isEmpty) {
      setState(() {
        _errorMessage = "Veuillez remplir tous les champs.";
      });
      return;
    }

    try {
      Utilisateur? user = await _databaseService.findUserByEmailAndVerifyPassword(email, motDePasse);
      if (user != null) {
        // ✅ Gestion des rôles
        if (user.role == 'superadmin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SuperAdminDashboard(user: user),
            ),
          );
        } else if (user.role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => AdminDashboardPage(user: user)),
          );
        } else if (user.role == 'vendeur') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => VendeursDashboardPage(user: user)),
          );
        }
      } else {
        setState(() {
          _errorMessage = "Email ou mot de passe incorrect.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Une erreur est survenue lors de la connexion.";
      });
      debugPrint("Erreur de connexion: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Couleur de fond par défaut (utilisée si l'image n'est pas trouvée)
    const Color defaultBackgroundColor = Color(0xFF13132D); // Couleur de votre thème

    return Scaffold(
      backgroundColor: _backgroundImagePath == null
          ? defaultBackgroundColor
          : Colors.transparent, // Si on utilise une image, le scaffold est transparent

      body: Stack(
        children: [
          // 1. --- LOGIQUE DE L'IMAGE D'ARRIÈRE-PLAN ---
          if (_backgroundImagePath != null)
            Positioned.fill(
              child: Image.asset(
                _backgroundImagePath!,
                fit: BoxFit.cover, // Assure que l'image couvre tout l'écran
                // Ajout d'un errorBuilder pour gérer le cas où l'asset n'est pas trouvé
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: defaultBackgroundColor,
                    child: Center(
                      child: Text(
                        "images: $_backgroundImagePath",
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  );
                },
              ),
            ),

          // 2. --- VOILE SOMBRE (pour améliorer la lisibilité de la carte) ---
          // On applique le voile que l'image soit présente ou non (au cas où elle ne serait pas trouvée)
          Positioned.fill(
            child: Container(
              // Voile noir semi-transparent sur l'image (ou sur le fond si l'image manque)
              color: Colors.black.withOpacity(0.5),
            ),
          ),

          // 3. --- CONTENU PRINCIPAL (Centré) ---
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  // Nous rendons la carte blanche pour qu'elle contraste bien avec l'arrière-plan sombre
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  elevation: 12, // Augmentation de l'élévation pour un effet 3D plus prononcé
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- ICÔNE DE L'APPLICATION ---
                        Image.asset(
                          _appIconPath,
                          height: 80,
                        ),
                        const SizedBox(height: 8),

                        // --- TEXTE GUIDE/BIENVENUE ---
                        const Text(
                          'Bienvenue au Shop Jeadot',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF13132D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Veuillez entrer vos identifiants pour accéder à votre tableau de bord.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24), // Espace avant les champs

                        // --- FORMULAIRE ---
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Adresse e-mail',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.email),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _motDePasseController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Mot de passe',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 24),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF13132D),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Se connecter', style: TextStyle(fontSize: 18)),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // --- BOUTONS DE TEST RAPIDE (Conservés) ---
                        /*Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                final tempSuper = Utilisateur(
                                  nom: 'Root',
                                  prenom: 'SuperAdmin',
                                  email: 'root@factura.com',
                                  motDePasseHash: '',
                                  role: 'superadmin',
                                  nomUtilisateur: '', // Conserve cette ligne
                                  syncStatus: '',
                                );
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => SuperAdminDashboard(user: tempSuper)),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple[700],
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('SuperAdmin'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final tempAdmin = Utilisateur(
                                  nom: 'Admin',
                                  prenom: 'Super',
                                  email: 'admin@factura.com',
                                  motDePasseHash: '',
                                  role: 'admin',
                                  nomUtilisateur: '', // Conserve cette ligne
                                  syncStatus: '',
                                );
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => AdminDashboardPage(user: tempAdmin)),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Admin'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                final tempVendeur = Utilisateur(
                                  nom: 'Vendeur',
                                  prenom: 'Jean',
                                  email: 'vendeur@factura.com',
                                  motDePasseHash: '',
                                  role: 'vendeur',
                                  nomUtilisateur: '', // Conserve cette ligne
                                  syncStatus: '',
                                );
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => VendeursDashboardPage(user: tempVendeur)),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                foregroundColor: Colors.white,
                              ),
                              child: const Text( 'Vendeur'),
                            ),
                          ],
                        ),*/
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("Fonctionnalité 'Mot de passe oublié' en cours de développement.")),
                            );
                          },
                          child: const Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(color: Color(0xFF13132D)),
                          ),
                        ),
                      ],
                    ),
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
