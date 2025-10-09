
import 'package:flutter/material.dart';

class LicencesPage extends StatelessWidget {
  const LicencesPage({super.key});

  void _addLicence(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ajouter / activer une licence')),
    );
  }

  void _deleteLicence(BuildContext context, String licence) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Licence $licence supprimée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final licences = List.generate(5, (index) => 'LIC-${index + 1001}');
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Gestion des licences', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _addLicence(context),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter une licence'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: licences.map((licence) => ListTile(
                leading: const Icon(Icons.vpn_key),
                title: Text(licence),
                subtitle: const Text('Statut: Actif'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteLicence(context, licence),
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
