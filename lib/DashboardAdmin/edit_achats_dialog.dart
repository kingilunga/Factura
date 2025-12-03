// Fichier: AchatEditDialog.dart

import 'package:flutter/material.dart';
import 'package:factura/Modeles/model_achat_produits.dart';
import 'package:factura/database/database_service.dart';
import 'package:intl/intl.dart';

class AchatEditDialog extends StatefulWidget {
  final AchatsProduit achat;
  final Function() onAchatUpdated; // Callback pour recharger les données

  const AchatEditDialog({
    Key? key,
    required this.achat,
    required this.onAchatUpdated,
  }) : super(key: key);

  @override
  State<AchatEditDialog> createState() => _AchatEditDialogState();
}

class _AchatEditDialogState extends State<AchatEditDialog> {
  final DatabaseService dbService = DatabaseService.instance;
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs pour les champs modifiables
  late TextEditingController _quantiteController;
  late TextEditingController _prixAchatController;
  late TextEditingController _fraisAchatController;
  late TextEditingController _prixVenteController;
  late DateTime _selectedDateAchat;
  late DateTime? _selectedDatePeremption;

  // Stocke la quantité initiale pour le calcul de la différence de stock
  late int _ancienneQuantite;

  @override
  void initState() {
    super.initState();
    // Initialisation des contrôleurs avec les valeurs existantes
    _ancienneQuantite = widget.achat.quantiteAchetee;
    _quantiteController = TextEditingController(text: widget.achat.quantiteAchetee.toString());
    _prixAchatController = TextEditingController(text: widget.achat.prixAchatUnitaire.toString());
    _fraisAchatController = TextEditingController(text: widget.achat.fraisAchatUnitaire.toString());
    _prixVenteController = TextEditingController(text: widget.achat.prixVente.toString());

    // Assurez-vous que les dates sont initialisées correctement
    _selectedDateAchat = widget.achat.dateAchat;
    _selectedDatePeremption = widget.achat.datePeremption;
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _prixAchatController.dispose();
    _fraisAchatController.dispose();
    _prixVenteController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE SAUVEGARDE (UPDATE TRANSACTIONNEL) ---

  Future<void> _saveAchat() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int nouvelleQuantite = int.parse(_quantiteController.text);
    final double nouvelleMarge = (double.parse(_prixVenteController.text) -
        double.parse(_prixAchatController.text) -
        double.parse(_fraisAchatController.text));

    // 1. Créer les nouvelles données de la ligne d'achat (pour la table achats_produit)
    final nouvellesDonneesAchat = {
      'quantiteAchetee': nouvelleQuantite,
      'prixAchatUnitaire': double.parse(_prixAchatController.text),
      'fraisAchatUnitaire': double.parse(_fraisAchatController.text),
      'prixVente': double.parse(_prixVenteController.text),
      'margeBeneficiaire': nouvelleMarge, // Recalculé
      'dateAchat': _selectedDateAchat.toIso8601String(),
      // Gérer la péremption qui peut être nulle
      'datePeremption': _selectedDatePeremption?.toIso8601String(),
    };

    try {
      // 2. Appel à la fonction transactionnelle du service
      await dbService.modifierAchatEtAjusterStock(
        achatId: widget.achat.localId!,
        produitId: widget.achat.produitLocalId, // ID du produit
        ancienneQuantite: _ancienneQuantite, // Ancienne quantité lue à l'ouverture du dialogue
        nouvelleQuantite: nouvelleQuantite,
        nouvellesDonneesAchat: nouvellesDonneesAchat,
      );

      widget.onAchatUpdated(); // Déclenche le rechargement dans la page parente
      if (mounted) Navigator.of(context).pop(); // Fermer la boîte de dialogue

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Achat modifié et stock ajusté avec succès.')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de modification: $e')),
      );
    }
  }

  // --- WIDGETS DE SÉLECTION DE DATE (inchangé) ---

  Future<void> _selectDateAchat(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateAchat,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDateAchat = picked;
      });
    }
  }

  Future<void> _selectDatePeremption(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDatePeremption ?? DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDatePeremption = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Modifier Achat : ${widget.achat.nomProduit}"),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min, // 🚀 CORRECTION APPLIQUÉE ICI
              children: <Widget>[
                // Informations clés (Non modifiables ici)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Fournisseur: ${widget.achat.nomFournisseur}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Type: ${widget.achat.type} | ID Produit: ${widget.achat.produitLocalId}"),
                ),

                const Divider(),

                // Champs de Saisie
                TextFormField(
                  controller: _quantiteController,
                  decoration: const InputDecoration(labelText: 'Quantité Achetée', suffixText: 'unités'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || int.tryParse(value) == null || int.parse(value) <= 0) {
                      return 'Veuillez entrer une quantité valide (> 0).';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _prixAchatController,
                  decoration: InputDecoration(labelText: 'Prix Achat Unitaire', suffixText: widget.achat.devise),
                  keyboardType: TextInputType.number,
                  validator: (value) => (value == null || double.tryParse(value) == null) ? 'Prix invalide.' : null,
                ),
                TextFormField(
                  controller: _prixVenteController,
                  decoration: InputDecoration(labelText: 'Prix Vente (Unitaire)', suffixText: widget.achat.devise),
                  keyboardType: TextInputType.number,
                  validator: (value) => (value == null || double.tryParse(value) == null) ? 'Prix de vente invalide.' : null,
                ),
                TextFormField(
                  controller: _fraisAchatController,
                  decoration: InputDecoration(labelText: 'Frais Achat Unitaire', suffixText: widget.achat.devise),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 10),

                // Sélecteurs de Date
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text("Date d'Achat"),
                        subtitle: Text(DateFormat('yyyy-MM-dd').format(_selectedDateAchat)),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDateAchat(context),
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text("Date de Péremption"),
                        subtitle: Text(_selectedDatePeremption != null
                            ? DateFormat('yyyy-MM-dd').format(_selectedDatePeremption!)
                            : 'Aucune'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () => _selectDatePeremption(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('Enregistrer'),
          onPressed: _saveAchat, // ⭐️ Connexion à la fonction de sauvegarde transactionnelle
        ),
      ],
    );
  }
}