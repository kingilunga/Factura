import 'package:factura/Modeles/model_fournisseurs.dart';
import 'package:flutter/material.dart';// Assurez-vous d'avoir ce chemin correct
import 'package:factura/database/database_service.dart';

class AjoutFournisseur extends StatefulWidget {
  const AjoutFournisseur({super.key});

  @override
  State<AjoutFournisseur> createState() => _AjoutFournisseurState();
}

class _AjoutFournisseurState extends State<AjoutFournisseur> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService.instance;
  bool _isLoading = false;

  // Contrôleurs pour les champs de saisie
  final TextEditingController _nomEntrepriseController = TextEditingController();
  final TextEditingController _nomContactController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _nomEntrepriseController.dispose();
    _nomContactController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  // --- Fonction d'enregistrement du fournisseur ---
  Future<void> _enregistrerFournisseur() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // Création de l'objet Fournisseur à partir des contrôleurs
      final nouveauFournisseur = Fournisseur(
        nomEntreprise: _nomEntrepriseController.text.trim(),
        nomContact: _nomContactController.text.trim().isNotEmpty ? _nomContactController.text.trim() : null,
        telephone: _telephoneController.text.trim().isNotEmpty ? _telephoneController.text.trim() : null,
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        syncStatus: 'pending',
      );

      try {
        final id = await _dbService.insertFournisseur(nouveauFournisseur);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fournisseur "${nouveauFournisseur.nomEntreprise}" ajouté avec ID: $id')),
          );
          // Retourne 'true' pour indiquer que l'opération a réussi et déclencher un rechargement si nécessaire
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')),
          );
        }
        print("Erreur d'insertion du fournisseur: $e");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un Nouveau Fournisseur'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Text(
                "Informations de Base",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const Divider(),
              const SizedBox(height: 15),

              // Champ Nom de l'Entreprise (Obligatoire)
              TextFormField(
                controller: _nomEntrepriseController,
                decoration: const InputDecoration(
                  labelText: 'Nom de l\'Entreprise *',
                  hintText: 'Ex: Global Trading SARL',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Veuillez entrer le nom de l\'entreprise.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Champ Nom du Contact
              TextFormField(
                controller: _nomContactController,
                decoration: const InputDecoration(
                  labelText: 'Nom du Contact (Optionnel)',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Champ Téléphone
              TextFormField(
                controller: _telephoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Champ Email
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Veuillez entrer un email valide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // Bouton d'enregistrement
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _enregistrerFournisseur,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isLoading ? 'Enregistrement...' : 'ENREGISTRER LE FOURNISSEUR',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}