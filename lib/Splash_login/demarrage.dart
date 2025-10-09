// lib/Splash_login/demarrage.dart
import 'package:factura/Splash_login/connexion.dart';
import 'package:factura/database/database_service.dart';
import 'package:flutter/material.dart';

class DemarragePage extends StatefulWidget {
  const DemarragePage({super.key});

  @override
  State<DemarragePage> createState() => _DemarragePageState();
}

class _DemarragePageState extends State<DemarragePage> {
  // Singleton pour accéder à la base de données
  final DatabaseService _dbService = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialisation de la base de données
    await _dbService.database;

    // Attendre un petit délai pour simuler le splash screen
    await Future.delayed(const Duration(seconds: 4));

    if (mounted) {
      // Navigation vers la page de connexion
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ConnexionPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Image de fond
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/arrierephoto.jpg"),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          // Overlay sombre pour la lisibilité
          color: Colors.black.withOpacity(0.3),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 100,
                  color: Colors.white,
                ),
                SizedBox(height: 20),
                Text(
                  'Factura Vision',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 50),
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
                SizedBox(height: 20),
                Text(
                  'Chargement...',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
