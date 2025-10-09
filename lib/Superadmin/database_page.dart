import 'package:flutter/material.dart';

class DatabasePage extends StatelessWidget {
  const DatabasePage({super.key});

  void _backupDB(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Backup effectué')),
    );
  }

  void _restoreDB(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Restauration effectuée')),
    );
  }

  void _purgeDB(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Base de données purgée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gestion de la base de données', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(onPressed: () => _backupDB(context), icon: const Icon(Icons.backup), label: const Text('Backup')),
              const SizedBox(width: 20),
              ElevatedButton.icon(onPressed: () => _restoreDB(context), icon: const Icon(Icons.restore), label: const Text('Restauration')),
              const SizedBox(width: 20),
              ElevatedButton.icon(onPressed: () => _purgeDB(context), icon: const Icon(Icons.delete_forever), label: const Text('Purge')),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Informations sur la base:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Taille: 12 MB'),
          const Text('Nombre de tables: 10'),
          const Text('Dernier backup: 08/10/2025'),
        ],
      ),
    );
  }
}
