// Fichier: AchatEditDialog.dart (VERSION FINALE ET CORRIGÉE)

import 'package:factura/achats_produit_service.dart';
import 'package:flutter/material.dart';
import 'package:factura/Modeles/model_achat_produits.dart';
import 'package:intl/intl.dart';

// Supposons que AchatsProduitService contienne maintenant la logique de sécurité et la MAJ du produit

class AchatEditDialog extends StatefulWidget {
  final AchatsProduit achat;
  final Function() onAchatUpdated;

  const AchatEditDialog({
    Key? key,
    required this.achat,
    required this.onAchatUpdated,
  }) : super(key: key);

  @override
  State<AchatEditDialog> createState() => _AchatEditDialogState();
}

class _AchatEditDialogState extends State<AchatEditDialog> {

  final AchatsProduitService _achatService = AchatsProduitService.instance;
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs de la TRANSACTION D'ACHAT (Existants)
  late TextEditingController _quantiteController;
  late TextEditingController _prixAchatController;
  late TextEditingController _fraisAchatController;
  late TextEditingController _prixVenteController;
  late DateTime _selectedDateAchat;
  late DateTime? _selectedDatePeremption;

  // NOUVEAUX CONTRÔLEURS DE LA FICHE PRODUIT
  late TextEditingController _nomProduitController;
  late TextEditingController _categorieController;

  // VARIABLES DE CONTRÔLE
  late int _ancienneQuantite;
  bool _isLoading = true;
  bool _venteExiste = false; // Indicateur de sécurité

  @override
  void initState() {
    super.initState();
    // Initialisation des contrôleurs de la transaction
    _ancienneQuantite = widget.achat.quantiteAchetee;
    _quantiteController = TextEditingController(text: widget.achat.quantiteAchetee.toString());
    _prixAchatController = TextEditingController(text: widget.achat.prixAchatUnitaire.toString());
    _fraisAchatController = TextEditingController(text: widget.achat.fraisAchatUnitaire.toString());
    _prixVenteController = TextEditingController(text: widget.achat.prixVente.toString());

    // Initialisation des contrôleurs de la FICHE PRODUIT
    _nomProduitController = TextEditingController(text: widget.achat.nomProduit);
    _categorieController = TextEditingController(text: widget.achat.type);

    _selectedDateAchat = widget.achat.dateAchat;
    _selectedDatePeremption = widget.achat.datePeremption;

    _loadSecurityData(); // Lancer la vérification de sécurité
  }

  // MÉTHODE DE CHARGEMENT ET DE SÉCURITÉ
  Future<void> _loadSecurityData() async {
    try {
      final bool existe = await _achatService.produitADejaEteVendu(widget.achat.produitLocalId);
      if (mounted) {
        setState(() {
          _venteExiste = existe;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur de chargement des données de sécurité: $e");
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _quantiteController.dispose();
    _prixAchatController.dispose();
    _fraisAchatController.dispose();
    _prixVenteController.dispose();
    _nomProduitController.dispose();
    _categorieController.dispose();
    super.dispose();
  }

  // --- LOGIQUE DE SAUVEGARDE (UPDATE TRANSACTIONNEL) ---

  Future<void> _saveAchat() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int nouvelleQuantite = int.parse(_quantiteController.text);
    final double prixAchat = double.parse(_prixAchatController.text);
    final double fraisAchat = double.parse(_fraisAchatController.text);
    final double nouveauPrixVente = double.parse(_prixVenteController.text);

    // Calculs de marge
    final double margeBrute = nouveauPrixVente - prixAchat - fraisAchat;
    final double coutUnitaire = prixAchat + fraisAchat;
    final double margeBeneficiairePercent = coutUnitaire > 0
        ? (margeBrute / coutUnitaire) * 100
        : 0.0;

    // 1. Données de la FICHE PRODUIT
    final Map<String, dynamic> nouvellesDonneesProduit = {
      'nom': _nomProduitController.text,
      'categorie': _categorieController.text,
    };

    // 2. Données de la LIGNE D'ACHAT
    final Map<String, dynamic> nouvellesDonneesAchat = {
      'quantiteAchetee': nouvelleQuantite,
      'prixAchatUnitaire': prixAchat,
      'fraisAchatUnitaire': fraisAchat,
      'prixVente': nouveauPrixVente,
      'margeBeneficiaire': double.parse(margeBeneficiairePercent.toStringAsFixed(2)),
      'dateAchat': _selectedDateAchat.toIso8601String(),
      'datePeremption': _selectedDatePeremption?.toIso8601String(),
    };

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Modification en cours...")),
      );

      // ÉTAPE 1 : MISE À JOUR DE LA FICHE PRODUIT (Nom/Catégorie)
      await _achatService.updateProduitFiche(
        produitId: widget.achat.produitLocalId,
        nouvellesDonnees: nouvellesDonneesProduit,
      );

      // ÉTAPE 2 : MISE À JOUR DE LA TRANSACTION ET DU STOCK
      await _achatService.modifierAchatEtAjusterStock(
        achatId: widget.achat.localId!,
        produitId: widget.achat.produitLocalId,
        devise: widget.achat.devise,
        ancienneQuantite: _ancienneQuantite,
        nouvelleQuantite: nouvelleQuantite,
        nouvellesDonneesAchat: nouvellesDonneesAchat,
      );

      widget.onAchatUpdated();
      if (mounted) Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Achat et Fiche Produit modifiés avec succès.'), backgroundColor: Colors.green),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur de modification: ${e.toString()}'), backgroundColor: Colors.red),
      );
      debugPrint("Erreur de modification d'achat: $e");
    }
  }

  // --- WIDGETS DE SÉLECTION DE DATE (fonctions manquantes ajoutées) ---

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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return AlertDialog(
      title: Text("Modifier Achat : ${widget.achat.nomProduit}"),

      // ⭐️ CORRECTION AFFICHAGE : Utilisation de ConstrainedBox pour éviter l'overflow ⭐️
      content: ConstrainedBox(
        constraints: BoxConstraints(
          // Limite la hauteur maximale du contenu à 60% de la hauteur de l'écran.
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // --- Fiche Produit ---
                const Text('Fiche Produit', style: TextStyle(fontWeight: FontWeight.bold)),
                TextFormField(
                  controller: _nomProduitController,
                  decoration: const InputDecoration(labelText: 'Nom du Produit'),
                  validator: (value) => (value == null || value.isEmpty) ? 'Le nom est obligatoire.' : null,
                ),
                TextFormField(
                  controller: _categorieController,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  validator: (value) => (value == null || value.isEmpty) ? 'La catégorie est obligatoire.' : null,
                ),

                const Divider(),
                const Text('Détails de la Transaction', style: TextStyle(fontWeight: FontWeight.bold)),

                // Informations clés (Lecture Seule)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Fournisseur: ${widget.achat.nomFournisseur}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("ID Produit: ${widget.achat.produitLocalId}"),
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
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) => (value == null || double.tryParse(value) == null) ? 'Prix invalide.' : null,
                ),

                // 🛡️ CHAMP PRIX DE VENTE SÉCURISÉ 🛡️
                TextFormField(
                  controller: _prixVenteController,
                  decoration: InputDecoration(
                    labelText: 'Prix Vente (Unitaire)',
                    suffixText: widget.achat.devise,
                    suffixIcon: _venteExiste
                        ? const Icon(Icons.lock, color: Colors.red)
                        : null,
                    hintText: _venteExiste
                        ? "Prix bloqué (ventes existantes)."
                        : "Modifiable.",
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  readOnly: _venteExiste, // Blocage si des ventes existent
                  style: TextStyle(
                    color: _venteExiste ? Colors.grey : Colors.black,
                  ),
                  validator: (value) => (value == null || double.tryParse(value) == null) ? 'Prix de vente invalide.' : null,
                ),

                TextFormField(
                  controller: _fraisAchatController,
                  decoration: InputDecoration(labelText: 'Frais Achat Unitaire', suffixText: widget.achat.devise),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
          onPressed: _saveAchat, // Connexion à la fonction de sauvegarde transactionnelle
        ),
      ],
    );
  }
}