import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/model_produits.dart';

class EditeProduits extends StatefulWidget {
  final Produit produit;
  const EditeProduits({super.key, required this.produit});

  @override
  State<EditeProduits> createState() => _EditeProduitsState();
}

class _EditeProduitsState extends State<EditeProduits> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomController;
  late TextEditingController _categorieController;
  late TextEditingController _prixController;
  late TextEditingController _quantiteInitialeController;
  late TextEditingController _imageController;

  final DatabaseService _dbService = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: widget.produit.nom);
    _categorieController = TextEditingController(text: widget.produit.categorie);
    _prixController = TextEditingController(text: widget.produit.prix?.toString());
    _quantiteInitialeController =
        TextEditingController(text: widget.produit.quantiteInitiale?.toString());
    _imageController = TextEditingController(text: widget.produit.imagePath ?? '');
  }

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
    if (_formKey.currentState!.validate()) {
      final updatedProduit = Produit(
        localId: widget.produit.localId,
        nom: _nomController.text.trim(),
        categorie: _categorieController.text.trim(),
        prix: double.tryParse(_prixController.text) ?? 0.0,
        quantiteInitiale: int.tryParse(_quantiteInitialeController.text) ?? 0,
        quantiteActuelle: widget.produit.quantiteActuelle, // on garde l'actuel
        imagePath: _imageController.text.isNotEmpty ? _imageController.text.trim() : null,
        serverId: widget.produit.serverId,
        syncStatus: widget.produit.syncStatus,
        idTransaction: widget.produit.idTransaction,
      );

      try {
        await _dbService.updateProduit(updatedProduit);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produit mis à jour avec succès !')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la mise à jour : $e')),
          );
        }
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
        title: Text('Éditer ${widget.produit.nom}'),
        backgroundColor: const Color(0xFF13132D),
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
              _buildTextField(_quantiteInitialeController, 'Quantité Initiale', isNumber: true),
              const SizedBox(height: 16),

              // Affichage du stock actuel en lecture seule
              Text(
                'Stock actuel : ${widget.produit.quantiteActuelle ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),

              _buildTextField(_imageController, 'Image (chemin ou URL)', isRequired: false),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.save),
                label: const Text('Mettre à jour le produit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13132D),
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
