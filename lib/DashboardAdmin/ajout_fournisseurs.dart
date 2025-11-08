import 'package:factura/Modeles/model_fournisseurs.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';

class AjoutFournisseurs extends StatefulWidget {
  const AjoutFournisseurs({super.key});

  @override
  State<AjoutFournisseurs> createState() => _AjoutFournisseursState();
}

class _AjoutFournisseursState extends State<AjoutFournisseurs> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService.instance;

  final TextEditingController nomEntrepriseController = TextEditingController();
  final TextEditingController nomContactController = TextEditingController();
  final TextEditingController telephoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  void _saveFournisseur() async {
    if (_formKey.currentState!.validate()) {
      final newFournisseur = Fournisseur(
        nomEntreprise: nomEntrepriseController.text.trim(),
        nomContact: nomContactController.text.isEmpty ? null : nomContactController.text.trim(),
        telephone: telephoneController.text.isEmpty ? null : telephoneController.text.trim(),
        email: emailController.text.isEmpty ? null : emailController.text.trim(),
        syncStatus: 'pending',
      );

      await _dbService.insertFournisseur(newFournisseur);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un fournisseur'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nomEntrepriseController,
                decoration: const InputDecoration(
                  labelText: 'Nom de l’entreprise',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: nomContactController,
                decoration: const InputDecoration(
                  labelText: 'Nom du contact',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: telephoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Ajouter'),
                  onPressed: _saveFournisseur,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
