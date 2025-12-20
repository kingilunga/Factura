import 'package:factura/Modeles/model_produits.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';

class MouvementStock extends StatefulWidget {
  const MouvementStock({super.key});

  @override
  State<MouvementStock> createState() => _MouvementStockState();
}

class _MouvementStockState extends State<MouvementStock> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _categorieController = TextEditingController();
  final _prixController = TextEditingController();
  final _quantiteInitialeController = TextEditingController();
  final _imageController = TextEditingController(); // On garde seulement la Quantité Initiale

  // On utilise DatabaseService.instance, comme dans votre code initial
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

  // CORRECTION : La fonction ne doit pas prendre de paramètre pour être utilisée par onPressed
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final produit = Produit(
        nom: _nomController.text,
        categorie: _categorieController.text,
        prix: double.tryParse(_prixController.text) ?? 0.0,
        quantiteInitiale: int.tryParse(_quantiteInitialeController.text) ?? 0,
        // On ne passe plus quantiteActuelle. Le modèle le mettra par défaut à quantiteInitiale.
        // IMAGE FACULTATIVE : Si le champ est vide, on passe null.
        imagePath: _imageController.text.isNotEmpty ? _imageController.text : null,
      );

      try {
        await _dbService.insertProduit(produit);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produit ajouté avec succès !')),
          );
          Navigator.pop(context, true); // Retour avec succès
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de l\'ajout : $e')),
          );
        }
      }
    }
  }

  // Fonction utilitaire pour construire les champs de texte
  Widget _buildTextField(
      TextEditingController controller,
      String label,
      {bool isNumber = false, String? Function(String?)? validator})
  {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      // Utilise le validator passé en paramètre, ou le validator par défaut
      validator: validator ?? (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer $label';
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un produit'),
        backgroundColor: Colors.blueGrey,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(_nomController, 'Nom du produit'),
              const SizedBox(height: 16),
              _buildTextField(_categorieController, 'Catégorie'),
              const SizedBox(height: 16),
              _buildTextField(_prixController, 'Prix', isNumber: true),
              const SizedBox(height: 16),
              // Renommé en Quantité Initiale pour plus de clarté
              _buildTextField(_quantiteInitialeController, 'Quantité Initiale', isNumber: true),
              const SizedBox(height: 16),

              // IMAGE : Utilisation d'un validator personnalisé pour la rendre facultative (accepte un champ vide)
              _buildTextField(
                _imageController,
                'Image (chemin ou URL - Facultatif)',
                validator: (value) => null, // Toujours valide, même si vide
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  // CORRECTION : Appel de la fonction sans arguments
                  onPressed: _submitForm,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Ajouter le produit', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
