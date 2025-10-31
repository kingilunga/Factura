import 'package:factura/Splash_login/connexion.dart';
import 'package:factura/database/database_service.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart'; // ✅ Lottie importé

class DemarragePage extends StatefulWidget {
  const DemarragePage({super.key});

  @override
  State<DemarragePage> createState() => _DemarragePageState();
}

class _DemarragePageState extends State<DemarragePage> {
  final DatabaseService _dbService = DatabaseService.instance;

  final String _appIconPath = 'assets/images/Icon_FacturaVision.png';
  final String _lottieAnimationPath = 'assets/lottie/boules_align.json';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _dbService.database;
    await Future.delayed(const Duration(seconds: 4));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ConnexionPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌄 Image de fond
          Image.asset(
            "assets/images/arrierephoto.jpg",
            fit: BoxFit.cover,
          ),
          // Overlay sombre pour lisibilité
          Container(color: Colors.black.withOpacity(0.6)),

          // 🌟 Contenu principal centré
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- 1. Logo ---
                Image.asset(
                  _appIconPath,
                  height: 120,
                ),
                const SizedBox(height: 20),

                // --- 2. Nom de l'application ---
                const Text(
                  'Factura Vision',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 50),

                // --- 3. Animation Lottie ---
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Lottie.asset(
                    _lottieAnimationPath,
                    repeat: true,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 20),
                Text(
                  'Shop jeannot en cours de chargement...',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
