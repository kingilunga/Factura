import 'package:factura/DashboardAdmin/edit_achats_dialog.dart';
import 'package:factura/Modeles/model_achat_produits.dart';
import 'package:flutter/material.dart';
// Correction des imports nécessaires pour les dépendances :
import 'package:factura/database/database_service.dart';
// Note : AchatsProduitsPage doit exister dans votre projet pour le bouton d'ajout.
import 'package:factura/DashboardAdmin/achats_produits.dart';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class GestionStockAchatsPage extends StatefulWidget {
  const GestionStockAchatsPage({Key? key}) : super(key: key);

  @override
  State<GestionStockAchatsPage> createState() => _GestionStockAchatsPageState();
}

class _GestionStockAchatsPageState extends State<GestionStockAchatsPage> {
  // Correction: Utilisation du constructeur par défaut 'DatabaseService()'
  final DatabaseService dbService = DatabaseService();
  List<AchatsProduit> achatsProduits = [];
  List<AchatsProduit> filteredProduits = [];
  final TextEditingController searchController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchatsProduits();
  }

  // --- CRUD/LOGIQUE DE STOCK ---

  Future<void> _loadAchatsProduits() async {
    setState(() => _isLoading = true);
    try {
      // Correction: La méthode getAllAchatsProduits est maintenant disponible
      final fetched = await dbService.getAllAchatsProduits();
      setState(() {
        achatsProduits = fetched;
        filteredProduits = fetched;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) print("Erreur de chargement des achats: $e");
      setState(() { _isLoading = false; });
    }
  }

  void _searchProduit(String query) {
    final filtered = achatsProduits.where((p) {
      final nom = p.nomProduit.toLowerCase();
      final fournisseur = p.nomFournisseur.toLowerCase();
      return nom.contains(query.toLowerCase()) || fournisseur.contains(query.toLowerCase());
    }).toList();

    setState(() {
      filteredProduits = filtered;
    });
  }

  // --- LOGIQUE ET CALCULS ---

  String get devisePrincipale => filteredProduits.isNotEmpty ? filteredProduits.first.devise : 'USD';

  int get totalQuantite {
    return filteredProduits.fold(0, (sum, p) => sum + p.quantiteAchetee);
  }

  double get totalPrixAchat {
    return filteredProduits.fold(0.0, (sum, p) => sum + (p.prixAchatUnitaire * p.quantiteAchetee));
  }

  double get totalFrais {
    return filteredProduits.fold(0.0, (sum, p) => sum + (p.fraisAchatUnitaire * p.quantiteAchetee));
  }

  // Correction: Utilisation du getter 'totalCoutLot' qui est maintenant présent dans AchatsProduit
  double get totalCoutLotGlobal {
    // Le fold additionne le totalCoutLot de chaque achat à la somme globale
    return filteredProduits.fold(0.0, (sum, p) => sum + p.totalCoutLot);
  }

  double get totalMarge {
    // Calcul de la marge potentielle totale : (Prix Vente Total) - (Coût Lot Total)
    return totalPrixVente - totalCoutLotGlobal;
  }

  double get totalPrixVente {
    return filteredProduits.fold(0.0, (sum, p) => sum + (p.prixVente * p.quantiteAchetee));
  }

  String _formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _formatCurrency(double amount, String currency) {
    // Utilisation d'un NumberFormat pour un meilleur affichage monétaire
    final formatter = NumberFormat.currency(
      locale: 'fr_FR',
      symbol: currency,
      decimalDigits: 2,
    );
    return formatter.format(amount).replaceAll(' ', ' ');
  }


  // --- LOGIQUE DE SUPPRESSION (DELETE) ---

  /// Affiche une boîte de dialogue pour confirmer la suppression et appelle la fonction transactionnelle.
  Future<void> _confirmDeleteAchat(AchatsProduit achat) async {
    final bool? confirmation = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer l\'achat de ${achat.quantiteAchetee}x ${achat.nomProduit} ? Le stock sera ajusté.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
    if (confirmation == true) {
      try {
        // La méthode est définie dans database_service.dart
        await dbService.supprimerAchatEtAjusterStock(
          achatId: achat.localId ?? -1, // Utiliser localId si disponible, sinon -1
          produitId: achat.produitLocalId,
          quantiteSupprimee: achat.quantiteAchetee,
        );
        // Recharger les données
        await _loadAchatsProduits();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Achat supprimé. Stock ajusté.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de suppression: $e')),
          );
        }
      }
    }
  }
  // Dans votre fichier gestion_stock_achats_page.dart
  void _showEditAchatDialog(AchatsProduit achat) {
    showDialog(
      context: context,
      builder: (context) {
        return AchatEditDialog(
          achat: achat,
          onAchatUpdated: () {
            // Remplacer setState(() {}); par _loadAchats() si elle existe.
            setState(() {});
          },
        );
      },
    );
  }

// Fonction qui crée la section de résumé des totaux pour le PDF
  pw.Widget _buildTotalSummaryPDF() {
    final totals = {
      'Qté Totale': totalQuantite.toString(),
      'Capital Investi (P.A. Total)': _formatCurrency(totalPrixAchat, devisePrincipale),
      'Total Frais': _formatCurrency(totalFrais, devisePrincipale),
      // Correction: Utilisation du getter 'totalCoutLotGlobal'
      'COÛT TOTAL LOTS': _formatCurrency(totalCoutLotGlobal, devisePrincipale),
      'Prix Vente Potentiel': _formatCurrency(totalPrixVente, devisePrincipale),
      'Marge Bénéficiaire Pot.': _formatCurrency(totalMarge, devisePrincipale),
    };

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        border: pw.Border.all(color: PdfColors.blueGrey200),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('RÉSUMÉ DES TOTAUX', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blueGrey800)),
          pw.SizedBox(height: 5),
          pw.Table.fromTextArray(
            data: totals.entries.map((e) => [e.key, e.value]).toList(),
            cellStyle: const pw.TextStyle(fontSize: 8),
            columnWidths: {
              0: const pw.FlexColumnWidth(2.5),
              1: const pw.FlexColumnWidth(2.0),
            },
            border: pw.TableBorder.all(color: PdfColors.white, width: 0),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
  }
  // Fonction qui crée le tableau des achats pour le PDF (détaillé)
  pw.Widget _buildAchatTablePDF(pw.Context context) {
    const tableHeaders = [
      'Fournisseur',
      'Produit (Type)',
      'Qté',
      'Prix U.',
      'Frais U.',
      'Coût total', // COLONNE COÛT TOTAL
      'Marge (%)',
      'P. Vente U.',
      'Date',
      'Expir.',
    ];
    final data = filteredProduits.map((achat) {
      final dateAchatStr = _formatDate(achat.dateAchat);
      final datePeremptionStr = achat.datePeremption != null
          ? _formatDate(achat.datePeremption!)
          : 'N/A';

      // Correction: Utilisation du getter 'totalCoutLot'
      final coutTotalLot = _formatCurrency(achat.totalCoutLot, achat.devise);

      return [
        achat.nomFournisseur,
        '${achat.nomProduit} (${achat.type})',
        achat.quantiteAchetee.toString(),
        _formatCurrency(achat.prixAchatUnitaire, achat.devise),
        _formatCurrency(achat.fraisAchatUnitaire, achat.devise),
        coutTotalLot,
        '${achat.margeBeneficiaire.toStringAsFixed(1)}%',
        _formatCurrency(achat.prixVente, achat.devise),
        dateAchatStr,
        datePeremptionStr,
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: tableHeaders,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 6),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellHeight: 18,
      cellStyle: const pw.TextStyle(fontSize: 6),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.8),
        1: const pw.FlexColumnWidth(2.0),
        2: const pw.FlexColumnWidth(0.8),
        3: const pw.FlexColumnWidth(1.2),
        4: const pw.FlexColumnWidth(1.0),
        5: const pw.FlexColumnWidth(1.4), // Espace pour le Coût Total
        6: const pw.FlexColumnWidth(0.9),
        7: const pw.FlexColumnWidth(1.2),
        8: const pw.FlexColumnWidth(1.5),
        9: const pw.FlexColumnWidth(1.5),
      },
      cellAlignments: {
        0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight, 4: pw.Alignment.centerRight, 5: pw.Alignment.centerRight,
        6: pw.Alignment.centerRight, 7: pw.Alignment.centerRight, 8: pw.Alignment.center, 9: pw.Alignment.center,
      },
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
    );
  }
  // Méthode appelée par le bouton "Exporter PDF"
  Future<void> _exportPDF() async {
    if (filteredProduits.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Aucun achat à exporter.")),
        );
      }
      return;
    }

    final pdf = pw.Document();
    final dateStr = _formatDate(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape, // Format Paysage pour plus de colonnes
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // En-tête du document
              pw.Header(
                level: 0,
                text: "Historique des Achats (${filteredProduits.length} transactions)",
                textStyle: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
              ),
              pw.SizedBox(height: 15),

              // RÉSUMÉ DES TOTAUX MIS À JOUR
              _buildTotalSummaryPDF(),

              pw.SizedBox(height: 15),

              // Titre du tableau
              pw.Text("Détails des transactions:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.SizedBox(height: 5),

              // Tableau des achats
              _buildAchatTablePDF(context),

              pw.Spacer(),
              pw.Text("Exporté le $dateStr", style: const pw.TextStyle(fontSize: 8)),
            ],
          );
        },
      ),
    );

    // Ouvre l'aperçu du PDF pour l'impression/le partage
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'historique_achats_${dateStr}.pdf');
  }

  // --- WIDGET _buildTotalCard ---
  Widget _buildTotalCard({
    required String title,
    required String value,
    required Color color,
    String? unit,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (unit != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2, left: 4),
                    child: Text(
                      unit,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET DU TABLEAU DE TRANSACTIONS (Avec Coût Total Lot) ---
  Widget _buildTransactionTable(List<AchatsProduit> achats) {
    final columns = [
      'Fournisseur', 'Produit', 'Type', 'Qté', 'P. Achat.',
      'Frais ', 'Coût total', 'Marge', 'P.Vente', 'Date',
      'Expir.', 'Actions'
    ];
    final rows = achats.map((p) {
      // Correction: Utilisation du getter 'totalCoutLot'
      final coutTotalLot = _formatCurrency(p.totalCoutLot, p.devise);
      return DataRow(
        color: MaterialStateProperty.resolveWith<Color?>((Set<MaterialState> states) {
          if (achats.indexOf(p).isEven) {
            return Colors.grey.shade50;
          }
          return null;
        }),
        cells: [
          DataCell(Text(p.nomFournisseur)),
          DataCell(Text(p.nomProduit)),
          DataCell(Text(p.type)),
          DataCell(Text(p.quantiteAchetee.toString(), textAlign: TextAlign.right)),
          DataCell(Text(_formatCurrency(p.prixAchatUnitaire, p.devise), textAlign: TextAlign.right)),
          DataCell(Text(p.fraisAchatUnitaire.toStringAsFixed(2), textAlign: TextAlign.right)),
          // CELLULE COÛT TOTAL LOT
          DataCell(Text(coutTotalLot,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)
          )),
          DataCell(Text(p.margeBeneficiaire.toStringAsFixed(2), textAlign: TextAlign.right)),
          DataCell(Text(p.prixVente.toStringAsFixed(2), textAlign: TextAlign.right)),
          DataCell(Text(_formatDate(p.dateAchat))),
          DataCell(Text(p.datePeremption != null ? _formatDate(p.datePeremption!) : 'N/A')),
          DataCell(
            // Ajout des boutons Modifier et Supprimer
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                  tooltip: "Modifier l'achat",
                  onPressed: () => _showEditAchatDialog(p), // Connexion à la logique UPDATE
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                  tooltip: "Supprimer l'achat",
                  onPressed: () => _confirmDeleteAchat(p), // Connexion à la logique DELETE
                ),
              ],
            ),
          ),
        ],
      );
    }).toList();

    return DataTable(
      columnSpacing: 18,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 60,
      columns: columns.map((column) {
        TextAlign align = TextAlign.left;
        if (column.contains('Qté') || column.contains('Prix') || column.contains('COÛT')) {
          align = TextAlign.right;
        }
        return DataColumn(
          label: Expanded(
            child: Text(
              column,
              textAlign: align,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      }).toList(),
      rows: rows,
    );
  }

  // --- WIDGET BUILD FINAL (Défilement Corrigé) ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Historique des Transactions d'Achat")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des Transactions d'Achat"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Ligne des cartes de totaux
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotalCard(title: "Qté. TOTALE", value: totalQuantite.toString(), color: Colors.indigo, unit: 'Unités'),
                _buildTotalCard(title: "CAPITAL INVESTI", value: totalPrixAchat.toStringAsFixed(2), color: Colors.blue, unit: devisePrincipale),
                _buildTotalCard(title: "TOTAL FRAIS", value: totalFrais.toStringAsFixed(2), color: Colors.orange, unit: devisePrincipale),
                // CARTE COÛT TOTAL LOT
                _buildTotalCard(title: "COÛT TOTAL LOT", value: totalCoutLotGlobal.toStringAsFixed(2), color: Colors.red.shade700, unit: devisePrincipale),
                // FIN CARTE
                _buildTotalCard(title: "PRIX DE VENTE POT.", value: totalPrixVente.toStringAsFixed(2), color: Colors.purple, unit: devisePrincipale),
                _buildTotalCard(title: "MARGE BÉNÉF. POT.", value: totalMarge.toStringAsFixed(2), color: Colors.green, unit: devisePrincipale),
              ].sublist(0, 6), // S'assure que les 6 cartes sont visibles
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // 2. Actions et Recherche
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: const InputDecoration(
                      labelText: "Recherche produit ou fournisseur",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _searchProduit,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text("Exporter PDF"),
                  onPressed: _exportPDF,
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Text("Nouvel Achat"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    // AchatsProduitsPage doit être un StatefulWidget ou StatelessWidget
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const AchatsProduitsPage()),
                    );
                    if (result == true) {
                      _loadAchatsProduits(); // Recharge après un nouvel achat réussi
                    }
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // 3. Le Tableau de Données (Défilement VERTICAL et HORIZONTAL)
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: filteredProduits.isEmpty
                      ? const Center(child: Text("Aucune transaction d'achat trouvée."))
                      : _buildTransactionTable(filteredProduits),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}