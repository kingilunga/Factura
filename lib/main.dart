// main.dart
import 'package:factura/Splash_login/demarrage.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ⚠️ Assurez-vous d'importer correctement votre classe de service de base de données
import 'package:factura/database/database_service.dart';

Future<void> main() async { // 1. main() est maintenant ASYNCHRONE

  // Ligne OBLIGATOIRE avant tout appel asynchrone (comme la DB)
  WidgetsFlutterBinding.ensureInitialized();
  // Initialisation SQLite pour Desktop (Ceci est correct)
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // 2. 🔑 CORRECTION (Remplacé 'init()' par 'database')
  try {
    print('Ouverture de la connexion à la base de données...');
    // Ceci appelle le getter asynchrone 'database' et ATTEND qu'il soit prêt.
    await DatabaseService.instance.database;
    print('Connexion établie. Démarrage de l\'application...');
  } catch (e) {
    print('ERREUR CRITIQUE D\'INITIALISATION DE LA DB : $e');
    // En cas d'échec, vous pourriez afficher un écran d'erreur ici si nécessaire.
  }

  // 3. runApp ne se lance que lorsque la DB est initialisée.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Factura',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DemarragePage(),
    );
  }
}