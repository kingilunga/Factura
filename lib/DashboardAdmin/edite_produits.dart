import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/model_produits.dart';

class AdminEditeProduits extends StatefulWidget {
  final Produit produit;

  const AdminEditeProduits({super.key, required this.produit});

  @override
  State<AdminEditeProduits> createState() => _AdminEditeProduitsState();
}

class _AdminEditeProduitsState extends State<AdminEditeProduits> {
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
    _quantiteInitialeController = TextEditingController(
        text: widget.produit.quantiteInitiale?.toString() ?? '0');
    _imageController = TextEditingController(text: widget.produit.imagePath ?? '');
  }

  Future<void> _updateProduct() async {
    if (_formKey.currentState!.validate()) {
      final updatedProduct = Produit(
        localId: widget.produit.localId,
        nom: _nomController.text,
        categorie: _categorieController.text,
        prix: double.tryParse(_prixController.text) ?? 0.0,
        quantiteInitiale: int.tryParse(_quantiteInitialeController.text) ?? 0,
        // 🔒 on NE touche PAS à quantiteActuelle ici
        imagePath: _imageController.text.isNotEmpty ? _imageController.text : null,
        serverId: widget.produit.serverId,
        syncStatus: widget.produit.syncStatus,
        idTransaction: widget.produit.idTransaction,
      );

      try {
        await _dbService.updateProduit(updatedProduct);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produit mis à jour avec succès!')),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la mise à jour: $e')),
          );
        }
      }
    }
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
        if (value == null || value.isEmpty) {
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
        backgroundColor: Colors.blueGrey,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildTextField(_nomController, 'Nom du Produit'),
              const SizedBox(height: 12),
              _buildTextField(_categorieController, 'Catégorie'),
              const SizedBox(height: 12),
              _buildTextField(_prixController, 'Prix', isNumber: true),
              const SizedBox(height: 12),
              _buildTextField(_quantiteInitialeController, 'Quantité Initiale', isNumber: true),
              const SizedBox(height: 12),

              // 🔒 Quantité Actuelle affichée en lecture seule
              Text(
                'Quantité Actuelle (Stock) : ${widget.produit.quantiteActuelle ?? 0}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _buildTextField(_imageController, 'Image (facultatif)', isRequired: false),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _updateProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Mettre à Jour',
                  style: TextStyle(fontSize: 18, color: Colors.white),

                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
