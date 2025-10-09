// main.dart
import 'package:factura/Splash_login/demarrage.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialisation SQLite pour Desktop
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

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
