// Fichier: lib/pages/admin/gestion_factures.dart

import 'package:flutter/material.dart';

class GestionFactures extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestion des factures'),
      ),
      body: Center(
        child: Text(
          'Page de gestion des factures',
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
