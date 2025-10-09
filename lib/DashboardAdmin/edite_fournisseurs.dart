import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/model_clients.dart';

class EditeFournisseurs extends StatefulWidget {
  final Client client;

  const EditeFournisseurs({super.key, required this.client});

  @override
  State<EditeFournisseurs> createState() => _EditeFournisseursState();
}

class _EditeFournisseursState extends State<EditeFournisseurs> {
  final _formKey = GlobalKey<FormState>();
  final _dbService = DatabaseService.instance;

  late String nomClient;
  late String telephone;
  late String adresse;

  @override
  void initState() {
    super.initState();
    nomClient = widget.client.nomClient;
    telephone = widget.client.telephone ?? '';
    adresse = widget.client.adresse ?? '';
  }

  void _updateClient() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final updatedClient = Client(
        localId: widget.client.localId,
        nomClient: nomClient,
        telephone: telephone.isEmpty ? null : telephone,
        adresse: adresse.isEmpty ? null : adresse,
        serverId: widget.client.serverId,
        syncStatus: widget.client.syncStatus,
      );

      await _dbService.updateClient(updatedClient);
      Navigator.of(context).pop(true); // Retour pour rafraîchir la liste
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditer le client'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Nom client (entreprise ou particulier)
              TextFormField(
                initialValue: nomClient,
                decoration: const InputDecoration(labelText: 'Nom du client'),
                validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                onSaved: (value) => nomClient = value!.trim(),
              ),
              const SizedBox(height: 8),

              // Téléphone
              TextFormField(
                initialValue: telephone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
                onSaved: (value) => telephone = value?.trim() ?? '',
              ),
              const SizedBox(height: 8),

              // Adresse
              TextFormField(
                initialValue: adresse,
                decoration: const InputDecoration(labelText: 'Adresse'),
                onSaved: (value) => adresse = value?.trim() ?? '',
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _updateClient,
                child: const Text('Mettre à jour'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
