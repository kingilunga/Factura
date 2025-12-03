import 'package:factura/Modeles/model_achat_produits.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/Modeles/model_fournisseurs.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';

// =================================================================
// --- MODÈLES MINIMAUX ET SERVICES (À IMPORTER DANS VOTRE PROJET RÉEL) ---

// =================================================================
// --- SERVICE LOCAL (Logique Transactionnelle Mise à Jour) ---
// Assurez-vous que les noms des tables (produitsTable, achatsProduitTable)
// sont correctement définis dans votre DatabaseService.
// =================================================================
class AchatsProduitService {
  static final AchatsProduitService instance = AchatsProduitService._init();
  AchatsProduitService._init();

  final DatabaseService _dbService = DatabaseService.instance;

  /// Enregistre l'achat dans l'historique ET met à jour le stock dans la table produits.
  Future<int> insertAchatTransaction({required AchatsProduit achat}) async {
    final db = await _dbService.database;
    int produitLocalId = achat.produitLocalId;

    return await db.transaction((txn) async {
      // ----------------------------------------------------
      // ÉTAPE 1 : GESTION DU PRODUIT (CREATE OU GET ID)
      // ----------------------------------------------------

      if (produitLocalId <= 0) {
        final nouveauProduit = Produit(
          nom: achat.nomProduit,
          categorie: achat.type,
          prix: achat.prixVente,
          quantiteActuelle: 0,
          quantiteInitiale: 0,
          prixAchatUSD: (achat.devise == 'USD') ? achat.prixAchatUnitaire : null,
          fraisAchatUSD: (achat.devise == 'USD') ? achat.fraisAchatUnitaire : null,
        );

        // Insertion du nouveau produit de base (dans la transaction)
        produitLocalId = await txn.insert(
          'produits', // Utilisez le nom réel de votre table produits
          nouveauProduit.toMap(),
          conflictAlgorithm: ConflictAlgorithm.fail,
        );
      } else {
        final existMap = await txn.query(
            'produits', // Utilisez le nom réel de votre table produits
            columns: ['localId'],
            where: 'localId = ?',
            whereArgs: [produitLocalId]
        );
        if (existMap.isEmpty) {
          throw Exception("Le produit (ID $produitLocalId) sélectionné n'existe pas.");
        }
      }

      final achatToInsert = achat.copyWith(produitLocalId: produitLocalId);

      // ----------------------------------------------------
      // ÉTAPE 2 : ENREGISTREMENT DE L'ACHAT (HISTORIQUE)
      // ----------------------------------------------------
      final achatLocalId = await txn.insert(
        'achats_produit', // Utilisez le nom réel de votre table achats_produit
        achatToInsert.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // ----------------------------------------------------
      // ÉTAPE 3 : MISE À JOUR DU STOCK ET PRIX (COMPTEUR PRODUITS)
      // ⭐️ MISE À JOUR : On incrémente quantiteActuelle ET quantiteInitiale (Stock Reçu)
      // ----------------------------------------------------
      await txn.rawUpdate(
        '''
        UPDATE produits 
        SET quantiteActuelle = quantiteActuelle + ?,
            quantiteInitiale = quantiteInitiale + ?, 
            prix = ?,
            prixAchatUSD = ?,
            fraisAchatUSD = ? 
        WHERE localId = ?
        ''',
        [
          achat.quantiteAchetee, // quantiteActuelle
          achat.quantiteAchetee, // quantiteInitiale (Stock Reçu)
          achat.prixVente,
          (achat.devise == 'USD') ? achat.prixAchatUnitaire : null,
          (achat.devise == 'USD') ? achat.fraisAchatUnitaire : null,
          produitLocalId
        ],
      );

      return achatLocalId;
    });
  }
}

// =================================================================
// --- WIDGET PRINCIPAL ---
// =================================================================
class AchatsProduitsPage extends StatefulWidget {
  const AchatsProduitsPage({super.key});

  @override
  State<AchatsProduitsPage> createState() => _AchatsProduitsPageState();
}

class _AchatsProduitsPageState extends State<AchatsProduitsPage> {
  final _formKey = GlobalKey<FormState>();
  final AchatsProduitService _service = AchatsProduitService.instance;
  final DatabaseService _dbService = DatabaseService.instance;

  DateTime _dateAchat = DateTime.now();
  DateTime? _datePeremption;

  int _quantiteAchetee = 0;
  double _prixAchatUnitaire = 0.0;
  double _fraisAchatUnitaire = 0.0;
  double _margeBeneficiairePercent = 0.0;
  double _prixVenteCalcule = 0.0;
  String _devise = 'USD';
  String _emballage = 'Unité';

  // IDs pour la gestion des sélections Autocomplete
  int _selectedProduitLocalId = 0; // 0 signifie nouveau produit
  int? _selectedFournisseurLocalId; // null signifie nouveau fournisseur

  // Listes pour l'Autocomplétion
  List<Fournisseur> _fournisseursList = [];
  bool _isLoadingFournisseurs = true;
  List<Produit> _produitsList = [];
  bool _isLoadingProduits = true;

  final List<String> _emballagesList = ['Unité', 'Carton', 'Sac', 'Kg'];
  final List<String> _devisesList = ['USD', 'CDF', 'EUR'];

  // Contrôleurs
  final TextEditingController _produitNomController = TextEditingController(text: '');
  final TextEditingController _fournisseurNomController = TextEditingController(text: '');
  final TextEditingController _typeController = TextEditingController(text: '');
  final TextEditingController _fournisseurTelephoneController = TextEditingController(text: '');
  final TextEditingController _quantiteController = TextEditingController(text: '');
  final TextEditingController _prixAchatController = TextEditingController(text: '');
  final TextEditingController _fraisController = TextEditingController(text: '');
  final TextEditingController _margeController = TextEditingController(text: '');

  Future<void> _loadFournisseurs() async {
    setState(() {
      _isLoadingFournisseurs = true;
    });
    try {
      final fournisseurs = await _dbService.getAllFournisseurs();
      setState(() {
        _fournisseursList = fournisseurs;
        _isLoadingFournisseurs = false;
      });
    } catch (e) {
      if (mounted) print("Erreur lors du chargement des fournisseurs: $e");
      setState(() => _isLoadingFournisseurs = false);
    }
  }

  Future<void> _loadProduits() async {
    setState(() {
      _isLoadingProduits = true;
    });
    try {
      // NOTE IMPORTANTE : Assurez-vous que votre DatabaseService contient bien une méthode
      // Future<List<Produit>> getAllProduits() { ... }
      final produits = await _dbService.getAllProduits();

      setState(() {
        // Le cast .cast<Produit>() n'est nécessaire que si la méthode retourne List<dynamic>
        _produitsList = produits.cast<Produit>();
        _isLoadingProduits = false;
      });
    } catch (e) {
      if (mounted) print("Erreur lors du chargement des produits: $e");
      setState(() => _isLoadingProduits = false);
    }
  }


  @override
  void initState() {
    super.initState();
    _loadFournisseurs();
    _loadProduits();
    _calculatePrice();
    _prixAchatController.addListener(_calculatePrice);
    _fraisController.addListener(_calculatePrice);
    _margeController.addListener(_calculatePrice);
  }


  @override
  void dispose() {
    _fournisseurNomController.dispose();
    _fournisseurTelephoneController.dispose();
    _prixAchatController.removeListener(_calculatePrice);
    _fraisController.removeListener(_calculatePrice);
    _margeController.removeListener(_calculatePrice);
    _produitNomController.dispose();
    _typeController.dispose();
    _quantiteController.dispose();
    _prixAchatController.dispose();
    _fraisController.dispose();
    _margeController.dispose();
    super.dispose();
  }

  void _calculatePrice() {
    final prixAchat = double.tryParse(_prixAchatController.text) ?? 0.0;
    final frais = double.tryParse(_fraisController.text) ?? 0.0;
    final marge = double.tryParse(_margeController.text) ?? 0.0;

    final coutTotalUnitaire = prixAchat + frais;
    final prixVenteCalcule = coutTotalUnitaire * (1 + marge / 100);

    setState(() {
      _prixAchatUnitaire = prixAchat;
      _fraisAchatUnitaire = frais;
      _margeBeneficiairePercent = marge;
      _prixVenteCalcule = double.parse(prixVenteCalcule.toStringAsFixed(2));
    });
  }

  Future<void> _enregistrerAchat() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();
    _calculatePrice();

    final nomProduit = _produitNomController.text.trim();
    final nomFournisseur = _fournisseurNomController.text.trim();
    final telephoneFournisseur = _fournisseurTelephoneController.text.trim();
    final type = _typeController.text.trim();

    if (nomProduit.isEmpty || nomFournisseur.isEmpty || _quantiteAchetee <= 0 || _prixVenteCalcule <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir le nom du Produit, du Fournisseur, la Quantité et un Prix de Vente valide.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Enregistrement en cours...")),
    );

    try {
      // ÉTAPE 1: GESTION DU FOURNISSEUR (Création à la volée si nécessaire)
      int finalFournisseurLocalId = _selectedFournisseurLocalId ?? 0;

      // Si _selectedFournisseurLocalId est null, on considère que c'est une saisie manuelle d'un nouveau
      if (_selectedFournisseurLocalId == null) {
        final nouveauFournisseur = Fournisseur(
          nomEntreprise: nomFournisseur,
          // Utilisez le 'nomContact' par défaut si vous l'avez rendu NOT NULL dans votre DB
          nomContact: nomFournisseur,
          telephone: telephoneFournisseur.isNotEmpty ? telephoneFournisseur : null,
          // email: null,
        );

        // Insérer le nouveau fournisseur et récupérer son ID
        finalFournisseurLocalId = await _dbService.insertFournisseur(nouveauFournisseur);

        setState(() {
          _selectedFournisseurLocalId = finalFournisseurLocalId;
        });
        _loadFournisseurs();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Nouveau fournisseur "$nomFournisseur" créé à la volée.')),
          );
        }
      }

      if (finalFournisseurLocalId <= 0) {
        throw Exception("Impossible d'obtenir un ID Fournisseur valide pour la transaction.");
      }
      // ÉTAPE 2: CRÉATION DE L'OBJET ACHAT AVEC L'ID FINAL
      final achat = AchatsProduit(
        achatId: 'ACH-${DateTime.now().millisecondsSinceEpoch}',
        produitLocalId: _selectedProduitLocalId,
        fournisseurLocalId: finalFournisseurLocalId,
        nomProduit: nomProduit,
        nomFournisseur: nomFournisseur,
        telephoneFournisseur: telephoneFournisseur.isNotEmpty ? telephoneFournisseur : null,
        type: type,
        emballage: _emballage,
        quantiteAchetee: _quantiteAchetee,
        prixAchatUnitaire: _prixAchatUnitaire,
        fraisAchatUnitaire: _fraisAchatUnitaire,
        margeBeneficiaire: _margeBeneficiairePercent,
        prixVente: _prixVenteCalcule,
        devise: _devise,
        dateAchat: _dateAchat,
        datePeremption: _datePeremption,
      );

      // ÉTAPE 3: APPEL DE LA TRANSACTION
      final achatLocalId = await _service.insertAchatTransaction(achat: achat);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Achat $achatLocalId enregistré. Stock, Fiche Produit et Fournisseur mis à jour."),
          backgroundColor: Colors.green,
        ),
      );

      // ÉTAPE 4: NETTOYAGE
      _formKey.currentState!.reset();

      // Nettoyage spécifique des contrôleurs
      _fournisseurNomController.clear();
      _fournisseurTelephoneController.clear();

      setState(() {
        _selectedFournisseurLocalId = null;
        _selectedProduitLocalId = 0;
        _datePeremption = null;
        _dateAchat = DateTime.now();
        _produitNomController.clear();
        _typeController.clear();
        _quantiteController.clear();
        _prixAchatController.clear();
        _fraisController.clear();
        _margeController.clear();
        _quantiteAchetee = 0;
        _prixVenteCalcule = 0.0;
        _devise = 'USD';
      });
      // Rechargement des produits et fournisseurs si l'un a été créé à la volée
      _loadFournisseurs();
      _loadProduits();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Erreur transactionnelle : ${e.toString()}"), backgroundColor: Colors.red),
      );
      debugPrint("Erreur d'enregistrement d'achat: $e");
    }
  }

  // --- Composants d'UI réutilisables ---

  static const OutlineInputBorder _uniformBorder = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12.0)),
    borderSide: BorderSide(color: Colors.blueGrey, width: 1.0),
  );

  Widget _buildDropdown<T>({
    T? value,
    required String label,
    required List<T> items,
    required Function(T?) onChanged,
    required String Function(T) itemBuilder,
    String? Function(T?)? validator,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.blueGrey) : null,
          border: _uniformBorder,
          enabledBorder: _uniformBorder,
          focusedBorder: _uniformBorder.copyWith(borderSide: const BorderSide(color: Colors.blue, width: 2.0)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        isExpanded: true,
        items: items.map((T item) {
          return DropdownMenuItem<T>(
            value: item,
            child: Text(itemBuilder(item), overflow: TextOverflow.ellipsis),
          );
        }).toList(),
        onChanged: onChanged,
        validator: validator ?? (val) => val == null ? 'Veuillez sélectionner une option' : null,
      ),
    );
  }

  Widget _buildDateField({required String label, DateTime? date, required Function(DateTime) onDateSelected, bool required = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
          );
          if (picked != null) onDateSelected(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: _uniformBorder,
            enabledBorder: _uniformBorder,
            focusedBorder: _uniformBorder.copyWith(borderSide: const BorderSide(color: Colors.blue, width: 2.0)),
            suffixIcon: const Icon(Icons.calendar_today),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          child: Text(
            date == null && !required ? 'Non défini' : DateFormat('dd/MM/yyyy').format(date ?? DateTime.now()),
            style: TextStyle(color: date == null && required ? Colors.red : Colors.black),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    Function(String?)? onSaved,
    FocusNode? focusNode,
    Function(String)? onFieldSubmitted,
    Function(String)? onChanged,
    bool readOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onSaved: onSaved,
        focusNode: focusNode,
        onFieldSubmitted: onFieldSubmitted,
        onChanged: onChanged,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blueGrey),
          border: _uniformBorder,
          enabledBorder: _uniformBorder,
          focusedBorder: _uniformBorder.copyWith(borderSide: const BorderSide(color: Colors.blue, width: 2.0)),
        ),
        validator: validator ?? (v) => v!.trim().isEmpty ? 'Ce champ est requis' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🔄 Enregistrement d'un Achat"),
        backgroundColor: Colors.blueGrey,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Informations de Base", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("ID Produit pour enregistrement : ${_selectedProduitLocalId == 0 ? 'Nouveau Produit (Création à la volée)' : _selectedProduitLocalId}", style: TextStyle(fontSize: 12, color: _selectedProduitLocalId == 0 ? Colors.red.shade700 : Colors.orange)),
              const Divider(height: 10),

              // =========================================================
              // ✅ AUTOCOMPLÉTION FOURNISSEUR
              // =========================================================
              if (_isLoadingFournisseurs)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: LinearProgressIndicator(),
                ))
              else
                Row(
                  children: [
                    Expanded(
                      child: Autocomplete<Fournisseur>(
                        displayStringForOption: (Fournisseur option) => option.nomEntreprise,
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Fournisseur>.empty();
                          }
                          return _fournisseursList.where((Fournisseur option) {
                            return option.nomEntreprise.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },
                        onSelected: (Fournisseur selection) {
                          setState(() {
                            _fournisseurNomController.text = selection.nomEntreprise;
                            _fournisseurTelephoneController.text = selection.telephone ?? '';
                            _selectedFournisseurLocalId = selection.localId;
                          });
                          FocusScope.of(context).nextFocus();
                        },
                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          _fournisseurNomController.text = textEditingController.text;

                          return _buildTextField(
                            controller: textEditingController,
                            label: 'Nom du Fournisseur *',
                            icon: Icons.local_shipping,
                            focusNode: focusNode,
                            onFieldSubmitted: (v) => onFieldSubmitted(),
                            validator: (value) => value!.trim().isEmpty ? 'Nom du fournisseur requis.' : null,
                            onChanged: (value) {
                              if (_selectedFournisseurLocalId != null) {
                                setState(() {
                                  _selectedFournisseurLocalId = null;
                                  _fournisseurTelephoneController.clear();
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _fournisseurTelephoneController,
                        label: 'Téléphone du Fournisseur',
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (v) => null,
                        readOnly: _selectedFournisseurLocalId != null,
                      ),
                    ),
                  ],
                ),

              // ----------------------------------------------------------------------------------
              // =========================================================
              // ✅ AUTOCOMPLÉTION PRODUIT (Code Réel Corrigé et Sécurisé)
              // =========================================================
              if (_isLoadingProduits)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: LinearProgressIndicator(),
                ))
              else
                Row(
                  children: [
                    Expanded(
                      child: Autocomplete<Produit>(
                        displayStringForOption: (Produit option) => option.nom,

                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<Produit>.empty();
                          }
                          return _produitsList.where((Produit option) {
                            // 🚨 DOUBLE SÉCURITÉ : On vérifie que le nom n'est pas vide avant de chercher
                            final nomProduit = option.nom;
                            return nomProduit.isNotEmpty &&
                                nomProduit.toLowerCase().contains(textEditingValue.text.toLowerCase());
                          });
                        },

                        onSelected: (Produit selection) {
                          setState(() {
                            _produitNomController.text = selection.nom;
                            _typeController.text = selection.categorie ?? '';
                            _selectedProduitLocalId = selection.localId ?? 0;
                          });
                          FocusScope.of(context).nextFocus();
                        },

                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                          _produitNomController.text = textEditingController.text;

                          return _buildTextField(
                            controller: textEditingController,
                            label: 'Nom du Produit *',
                            icon: Icons.inventory_2,
                            focusNode: focusNode,
                            onFieldSubmitted: (v) => onFieldSubmitted(),
                            validator: (value) => value!.trim().isEmpty ? 'Nom du produit requis.' : null,
                            onChanged: (value) {
                              if (_selectedProduitLocalId != 0) {
                                setState(() {
                                  _selectedProduitLocalId = 0;
                                  _typeController.clear();
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(
                        controller: _typeController,
                        label: 'Type de produit',
                        icon: Icons.type_specimen,
                        keyboardType: TextInputType.text,
                        validator: (v) => null,
                        readOnly: _selectedProduitLocalId != 0,
                      ),
                    ),
                  ],
                ),
              // FIN DU BLOC PRODUIT
              const SizedBox(height: 12),
              const Text("Détails et Prix d’Achat", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdown<String>(
                      value: _devise,
                      label: 'Devise d\'Achat *',
                      items: _devisesList,
                      onChanged: (v) => setState(() { _devise = v!; _calculatePrice(); }),
                      itemBuilder: (v) => v,
                      icon: Icons.monetization_on,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _quantiteController,
                      label: "Quantité Achetée *",
                      icon: Icons.numbers,
                      keyboardType: TextInputType.number,
                      onSaved: (v) => _quantiteAchetee = int.tryParse(v ?? '0') ?? 0,
                      validator: (v) => (int.tryParse(v ?? '0') ?? 0) <= 0 ? "Qté > 0" : null,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(controller: _prixAchatController, label: "Prix d’Achat Unitaire (${_devise}) *", icon: Icons.attach_money, keyboardType: const TextInputType.numberWithOptions(decimal: true), onSaved: (v) => _prixAchatUnitaire = double.tryParse(v ?? '0.0') ?? 0.0, validator: (v) => (double.tryParse(v ?? '0.0') ?? 0.0) <= 0 ? "Prix > 0" : null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(controller: _fraisController, label: "Frais Unitaires (${_devise})", icon: Icons.local_shipping_outlined, keyboardType: const TextInputType.numberWithOptions(decimal: true), onSaved: (v) => _fraisAchatUnitaire = double.tryParse(v ?? '0.0') ?? 0.0),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(controller: _margeController, label: "Marge Bénéficiaire (%) *", icon: Icons.trending_up, keyboardType: const TextInputType.numberWithOptions(decimal: true), onSaved: (v) => _margeBeneficiairePercent = double.tryParse(v ?? '0.0') ?? 0.0, validator: (v) => (double.tryParse(v ?? '0.0') ?? 0.0) <= 0 ? "Marge > 0%" : null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDropdown<String>(value: _emballage, label: 'Emballage', items: _emballagesList, onChanged: (v) => setState(() => _emballage = v!), itemBuilder: (v) => v, icon: Icons.inventory),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Prix de Vente Unitaire Suggéré : ${_prixVenteCalcule.toStringAsFixed(2)} $_devise (Calculé)",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              const Text("Autres Détails", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildDateField(label: 'Date d\'Achat *', date: _dateAchat, required: true, onDateSelected: (d) => setState(() => _dateAchat = d)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateField(label: 'Date de Péremption (Optionnel)',
                        date: _datePeremption, onDateSelected: (d) => setState(() => _datePeremption = d)),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _enregistrerAchat,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text("ENREGISTRER L’ACHAT"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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