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
        // ✅ Ajout du SuperAdmin ici
        if (user.role == 'superadmin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => SuperAdminDashboard(user: user), // ✅ passage du user ici
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
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 60, color: Color(0xFF13132D)),
                    const SizedBox(height: 16),
                    const Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF13132D),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // ✅ Bouton de test SuperAdmin (aucun impact visuel)
                        ElevatedButton(
                          onPressed: () {
                            final tempSuper = Utilisateur(
                              nom: 'Root',
                              prenom: 'SuperAdmin',
                              email: 'root@factura.com',
                              motDePasseHash: '',
                              role: 'superadmin',
                              nomUtilisateur: '',
                              nomUtil: '',
                              nomUtilisateurisateur: '',
                              syncStatus: '',
                            );
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => SuperAdminDashboard(user: tempSuper)), // ✅ corrigé
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
                              nomUtilisateur: '',
                              nomUtil: '',
                              nomUtilisateurisateur: '',
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
                              nomUtilisateur: '',
                              nomUtil: '',
                              nomUtilisateurisateur: '',
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
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Fonctionnalité en cours de développement.")),
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
    );
  }
}
