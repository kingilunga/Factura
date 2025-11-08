import 'package:factura/Modeles/model_produits.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';

class AjoutProduitsPage extends StatefulWidget {
  const AjoutProduitsPage({super.key});

  @override
  State<AjoutProduitsPage> createState() => _AjoutProduitsPageState();
}

class _AjoutProduitsPageState extends State<AjoutProduitsPage> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _categorieController = TextEditingController();
  final _prixController = TextEditingController();
  final _quantiteInitialeController = TextEditingController();
  final _imageController = TextEditingController();

  final DatabaseService _dbService = DatabaseService.instance;

  @override
  void dispose() {
    _nomController.dispose();
    _categorieController.dispose();
    _prixController.dispose();
    _quantiteInitialeController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final double prix = double.tryParse(_prixController.text.trim()) ?? 0.0;
    final int quantiteInitiale = int.tryParse(
        _quantiteInitialeController.text.trim()) ?? 0;

    final produit = Produit(
      nom: _nomController.text.trim(),
      categorie: _categorieController.text.trim(),
      prix: prix,
      quantiteInitiale: quantiteInitiale,
      quantiteActuelle: quantiteInitiale,
      // Stock initial = Stock actuel
      imagePath: _imageController.text
          .trim()
          .isNotEmpty ? _imageController.text.trim() : null,
    );

    try {
      await _dbService.insertProduit(produit);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produit ajouté avec succès !')),
      );

      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit ajouté avec succès !')),
        );
      }

    } catch (e, stack) {
      // Affiche l'erreur complète dans la console
      print('🔥 ERREUR ajout produit : $e');
      print(stack);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ajout : $e')),
        );
      }
    }
  }

    Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: isRequired
          ? (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Veuillez entrer $label';
        }
        return null;
      }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un produit'),
        backgroundColor: Colors.grey,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(_nomController, 'Nom du produit'),
              const SizedBox(height: 16),
              _buildTextField(_categorieController, 'Catégorie'),
              const SizedBox(height: 16),
              _buildTextField(_prixController, 'Prix', isNumber: true),
              const SizedBox(height: 16),
              _buildTextField(_quantiteInitialeController, 'Quantité initiale', isNumber: true),
              const SizedBox(height: 16),
              _buildTextField(_imageController, 'Image (chemin ou URL - facultatif)', isRequired: false),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter le produit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:  Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
