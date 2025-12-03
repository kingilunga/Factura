import 'package:factura/DashboardAdmin/ajout_fournisseurs.dart';
import 'package:factura/Modeles/model_fournisseurs.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:uuid/uuid.dart';

// IMPORTS POUR PDF ET IMPRESSION
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


class GestionFournisseurs extends StatefulWidget {
  const GestionFournisseurs({super.key});

  @override
  State<GestionFournisseurs> createState() => _GestionFournisseursState();
}

class _GestionFournisseursState extends State<GestionFournisseurs> {
  final DatabaseService _dbService = DatabaseService.instance;
  List<Fournisseur> _fournisseurs = [];
  List<Fournisseur> _filteredFournisseurs = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Définition de la couleur principale pour la cohérence
  static const primaryColor = Color(0xFF13132D);
  static const accentColor = Colors.indigo;

  @override
  void initState() {
    super.initState();
    _loadFournisseurs();
    _searchController.addListener(_filterFournisseurs);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterFournisseurs);
    _searchController.dispose();
    super.dispose();
  }

  // --- Fonctions de base (inchangées) ---
  Future<void> _loadFournisseurs() async {
    setState(() => _isLoading = true);
    try {
      final fournisseurs = await _dbService.getAllFournisseurs();
      setState(() {
        _fournisseurs = fournisseurs;
        _filterFournisseurs();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) print("Erreur lors du chargement des fournisseurs: $e");
    }
  }

  Future<bool> _confirmDeletion(String nom) async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content: Text("Êtes-vous sûr de vouloir supprimer le fournisseur '$nom'?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Annuler"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _deleteFournisseur(Fournisseur fournisseur) async {
    if (fournisseur.localId == null) return;

    final confirmed = await _confirmDeletion(fournisseur.nomEntreprise);
    if (confirmed) {
      try {
        await _dbService.deleteFournisseur(fournisseur.localId!);
        _loadFournisseurs();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Le fournisseur "${fournisseur.nomEntreprise}" a été supprimé.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression : $e')),
          );
        }
      }
    }
  }

  void _filterFournisseurs() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredFournisseurs = _fournisseurs;
      } else {
        _filteredFournisseurs = _fournisseurs.where((f) {
          final nomEntrepriseMatch = f.nomEntreprise.toLowerCase().contains(query);
          final telephoneMatch = (f.telephone ?? '').toLowerCase().contains(query);
          final nomContactMatch = (f.nomContact ?? '').toLowerCase().contains(query);
          return nomEntrepriseMatch || telephoneMatch || nomContactMatch;
        }).toList();
      }
    });
  }

  void _navigateToAddFournisseur() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AjoutFournisseur()),
    );
    if (result == true) {
      _loadFournisseurs();
    }
  }

  void _navigateToEditFournisseur(Fournisseur fournisseur) {
    print("Ouverture de la page de modification pour: ${fournisseur.nomEntreprise}");
    // TODO: Implémenter la navigation vers la page d'édition
  }

  // FONCTION D'EXPORTATION PDF ET D'IMPRESSION (inchangée)
  // Dans la classe _GestionFournisseursState

  Future<void> _exportToPdf(BuildContext context) async {
    final pdf = pw.Document();

    // 1. Définition des nouveaux en-têtes (avec N°)
    final headers = [
      'N°', // ⭐️ NOUVEAU
      'Entreprise',
      'Contact',
      'Téléphone',
      'Email',
    ];

    // 2. Construction des données du tableau
    // Nous utilisons index + 1 pour générer le numéro d'ordre
    final data = _filteredFournisseurs.asMap().entries.map((entry) {
      final index = entry.key;
      final f = entry.value;
      return [
        (index + 1).toString(), // ⭐️ Ajout du N° d'ordre
        f.nomEntreprise,
        f.nomContact ?? 'N/A',
        f.telephone ?? 'N/A',
        f.email ?? 'N/A',
      ];
    }).toList();

    // 3. Construction du contenu du PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Liste des Fournisseurs (${DateTime.now().toLocal().toString().split(' ')[0]})",
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700),
              ),
              pw.SizedBox(height: 20),

              // Tableau de données
              pw.Table.fromTextArray(
                  headers: headers,
                  data: data,
                  border: pw.TableBorder.all(color: PdfColors.grey),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
                  cellHeight: 30,
                  cellAlignments: {
                    // ⭐️ Ajustement des alignements pour inclure le N° (index 0)
                    0: pw.Alignment.center, // N° centré
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.centerLeft,
                    3: pw.Alignment.center,
                    4: pw.Alignment.centerLeft,
                  },
                  columnWidths: {
                    // ⭐️ Ajustement des largeurs pour inclure le N° (index 0)
                    0: const pw.FlexColumnWidth(0.5), // N° prend très peu de place
                    1: const pw.FlexColumnWidth(3.0),
                    2: const pw.FlexColumnWidth(3.0),
                    3: const pw.FlexColumnWidth(2.5),
                    4: const pw.FlexColumnWidth(3.5),
                  }
              ),
              pw.Spacer(),
              pw.Text('Total Fournisseurs: ${_filteredFournisseurs.length}', style: const pw.TextStyle(fontSize: 10)),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Liste_Fournisseurs_${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}.pdf',
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Fournisseurs'),
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        actions: [
          // Bouton Export PDF (couleur mise à jour)
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.deepOrangeAccent),
            tooltip: 'Exporter en PDF / Imprimer',
            onPressed: () => _exportToPdf(context),
          ),
          // Bouton d'ajout de fournisseur
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Ajouter un Fournisseur',
            onPressed: _navigateToAddFournisseur,
          ),
        ],
      ),
      body: Column(
        children: [
          // Champ de recherche
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Rechercher par nom d'entreprise, contact ou téléphone...",
                prefixIcon: const Icon(Icons.search, color: accentColor),
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: accentColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: accentColor, width: 2),
                ),
              ),
            ),
          ),

          _isLoading
              ? const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(color: accentColor),
          ))
              : Expanded(
            child: _filteredFournisseurs.isEmpty
                ? const Center(child: Text("Aucun fournisseur trouvé."))
                : ListView.builder(
              itemCount: _filteredFournisseurs.length,
              // ⭐️ Hauteur ajustée pour l'alignement
              itemExtent: 90.0,
              itemBuilder: (context, index) {
                final fournisseur = _filteredFournisseurs[index];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    // ⭐️ Padding ajusté
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                    leading: const CircleAvatar(
                      radius: 15,
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.business, color: Colors.white, size: 20),
                    ),
                    title: Text(
                      fournisseur.nomEntreprise,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Ligne 1: Contact et Téléphone
                        Text(
                          'Contact: ${fournisseur.nomContact ?? 'N/A'} | Tél: ${fournisseur.telephone ?? 'N/A'}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Ligne 2: Email (sans Padding autour)
                        if (fournisseur.email != null && fournisseur.email!.isNotEmpty)
                          Text(
                            'Email: ${fournisseur.email}',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    trailing: SizedBox(
                      width: 90,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Bouton Modifier
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                            onPressed: () => _navigateToEditFournisseur(fournisseur),
                            tooltip: 'Modifier',
                          ),
                          // Bouton Supprimer
                          IconButton(
                            icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                            onPressed: () => _deleteFournisseur(fournisseur),
                            tooltip: 'Supprimer',
                          ),
                        ],
                      ),
                    ),
                    onTap: () {
                      _navigateToEditFournisseur(fournisseur);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}