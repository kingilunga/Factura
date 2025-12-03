import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:flutter/foundation.dart';

// --- Modèles de données simplifiés pour le PDF ---

// Modèle pour les données de Vente
class PdfVente {
  final String venteId;
  final String dateVente;
  final String vendeurNom;
  final double totalBrut;
  final double montantReduction;
  final double totalNet;
  final String modePaiement;

  PdfVente({
    required this.venteId,
    required this.dateVente,
    required this.vendeurNom,
    required this.totalBrut,
    required this.montantReduction,
    required this.totalNet,
    required this.modePaiement,
  });
}

// Modèle pour les lignes de vente
class PdfLigneVente {
  final String nomProduit;
  final double prixVenteUnitaire;
  final int quantite;
  final double sousTotal;

  PdfLigneVente({
    required this.nomProduit,
    required this.prixVenteUnitaire,
    required this.quantite,
    required this.sousTotal,
  });
}

// Modèle pour les données de Client
class PdfClient {
  final String? nomClient;
  final String? telephone;
  final String? adresse;

  PdfClient({
    this.nomClient,
    this.telephone,
    this.adresse,
  });
}

// --- Données Statiques de l'Entreprise ---
const String nomEntreprise = "Factura Vision Apps - BHT S.A.R.L";
const String adresseEntreprise = "123, Av. Odjidji, Kole, RDC";
const String telephoneEntreprise = "+243 821672206";
const String emailEntreprise = "contact@facturavision.cd";
const String logoAssetPath = 'assets/images/Icon_FacturaVision.png';
const String devise = "FC";

// --- Fonctions utilitaires ---

Future<Uint8List> _loadAssetImage(String assetPath) async {
  try {
    final ByteData data = await rootBundle.load(assetPath);
    // Correction de l'erreur UNDEFINED_METHOD : asUint8list -> asUint8List
    return data.buffer.asUint8List();
  } catch (e) {
    debugPrint('Erreur lors du chargement de l\'asset image: $e');
    // Retourne un tableau vide en cas d'erreur
    return Uint8List(0);
  }
}

// --- 1. Génération de Facture A4 ---

Future<pw.Document> generatePdfA4(
    PdfVente vente, List<PdfLigneVente> lignes, PdfClient client) async {
  final doc = pw.Document(title: 'Facture ${vente.venteId}');
  final logoImage = await _loadAssetImage(logoAssetPath);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        // --- En-tête (Logo et infos entreprise) ---
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            if (logoImage.isNotEmpty)
              pw.Image(pw.MemoryImage(logoImage), height: 50, width: 50),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(nomEntreprise, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text(adresseEntreprise, style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Tél: $telephoneEntreprise', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Email: $emailEntreprise', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.Divider(height: 10),

        // --- Titre et Informations Facture ---
        pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text('FACTURE PROFORMA', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
        ),

        // --- Infos Client et Facture ---
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            // Colonne Client
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Facturé à:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(client.nomClient ?? 'Client Anonyme', style: const pw.TextStyle(fontSize: 11)),
                pw.Text('Tél: ${client.telephone ?? 'N/A'}', style: const pw.TextStyle(fontSize: 11)),
                pw.Text('Adresse: ${client.adresse ?? 'N/A'}', style: const pw.TextStyle(fontSize: 11)),
              ],
            ),

            // Colonne Facture
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('ID Facture: ${vente.venteId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Date: ${vente.dateVente.split(' ')[0]}'),
                pw.Text('Vendeur: ${vente.vendeurNom}'),
                pw.Text('Paiement: ${vente.modePaiement}'),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 20),

        // --- Détails des Lignes de Vente ---
        pw.Table.fromTextArray(
          border: null,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(5),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headerAlignment: pw.Alignment.centerLeft,
          columnWidths: {
            0: const pw.FlexColumnWidth(3), // Produit
            1: const pw.FlexColumnWidth(1.5), // Prix Unitaire
            2: const pw.FlexColumnWidth(1), // Quantité
            3: const pw.FlexColumnWidth(1.5), // Sous-total
          },
          headers: ['Produit', 'Prix Unitaire', 'Quantité', 'Sous-total'],
          data: lignes.map((l) => [
            l.nomProduit,
            '${l.prixVenteUnitaire.toStringAsFixed(0)} $devise',
            l.quantite.toString(),
            '${l.sousTotal.toStringAsFixed(0)} $devise',
          ]).toList(),
        ),

        pw.SizedBox(height: 30),

        // --- Totaux ---
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildTotalRow('Total Brut:', vente.totalBrut, false),
                _buildTotalRow('Réduction:', vente.montantReduction, false, isNegative: true),
                pw.Divider(height: 10, thickness: 1, color: PdfColors.black),
                _buildTotalRow('NET À PAYER:', vente.totalNet, true, color: PdfColors.blue700),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 40),

        // --- Note de bas de page ---
        pw.Center(
          child: pw.Text(
            'Merci de votre confiance. Paiement dû à la réception.',
            style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic),
          ),
        ),
      ],
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'Page ${context.pageNumber} sur ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
      ),
    ),
  );

  return doc;
}

// Widget utilitaire pour les lignes de totaux
pw.Row _buildTotalRow(String label, double amount, bool isFinal, {PdfColor? color, bool isNegative = false}) {
  final displayAmount = isNegative ? -amount : amount; // Assurer que la réduction est affichée positivement
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Container(
        width: 100,
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ),
      pw.Container(
        width: 100,
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.all(3),
        child: pw.Text(
          '${displayAmount.toStringAsFixed(0)} $devise',
          style: pw.TextStyle(
            fontSize: isFinal ? 12 : 10,
            fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color,
          ),
        ),
      ),
    ],
  );
}

// --- 2. Génération de Reçu Thermique (58mm) ---

Future<pw.Document> generateThermalReceipt(
    PdfVente vente, List<PdfLigneVente> lignes, PdfClient client) async {
  // Correction de l'erreur undefined_named_parameter (marginAll n'existe pas)
  // Utilisation des marges (margin:) si besoin, sinon utiliser copyWith pour les redéfinir.
  final thermalFormat = PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm);
  final doc = pw.Document(title: 'Reçu ${vente.venteId}');
  final logoImage = await _loadAssetImage(logoAssetPath);

  doc.addPage(
    pw.Page(
      pageFormat: thermalFormat,
      build: (context) =>
        pw.Center(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              if (logoImage.isNotEmpty)
                pw.Image(pw.MemoryImage(logoImage), height: 30, width: 30, fit: pw.BoxFit.contain),

              pw.SizedBox(height: 5),
              pw.Text(nomEntreprise, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              // Suppression du mot clé 'final' devant pw.TextStyle
              pw.Text(adresseEntreprise, style:  pw.TextStyle(fontSize: 6)),
              pw.Text('Tél: $telephoneEntreprise', style:  pw.TextStyle(fontSize: 6)),
              pw.SizedBox(height: 5),
              pw.Divider(height: 1, thickness: 0.5),

              // --- Infos Transaction ---
              pw.Container(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('REÇU DE VENTE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        // Suppression du mot clé 'final' devant pw.TextStyle
                        pw.Text('Facture ID: ${vente.venteId}', style:  pw.TextStyle(fontSize: 7)),
                        pw.Text('Date: ${vente.dateVente.split(' ')[0]} ${vente.dateVente.split(' ')[1].substring(0, 5)}', style: const pw.TextStyle(fontSize: 7)),
                        // Suppression du mot clé 'final' devant pw.TextStyle
                        pw.Text('Client: ${client.nomClient ?? 'Anonyme'}', style: const pw.TextStyle(fontSize: 7)),
                        // Suppression du mot clé 'final' devant pw.TextStyle
                        pw.Text('Vendeur: ${vente.vendeurNom}', style: const pw.TextStyle(fontSize: 7)),
                      ]
                  )
              ),

              pw.Divider(height: 5, thickness: 0.5),

              // --- Lignes de Produits (Utilisation d'un tableau manuel pour la flexibilité) ---
              ...lignes.map((l) => pw.Column(
                  children: [
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Container(
                            width: 70,
                            child: pw.Text(l.nomProduit, style: const pw.TextStyle(fontSize: 7)),
                          ),
                          pw.Text('${l.quantite} x ${l.prixVenteUnitaire.toStringAsFixed(0)}', style: const pw.TextStyle(fontSize: 7)),
                          pw.Text('${l.sousTotal.toStringAsFixed(0)} $devise', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                        ]
                    ),
                    pw.SizedBox(height: 2),
                  ]
              )),

              pw.Divider(height: 5, thickness: 0.5),

              // --- Totaux ---
              _buildThermalTotalRow('Total Brut:', vente.totalBrut, false),
              _buildThermalTotalRow('Réduction:', vente.montantReduction, false, isNegative: true),
              _buildThermalTotalRow('NET À PAYER:', vente.totalNet, true),
              pw.SizedBox(height: 5),
              // Suppression du mot clé 'final' devant pw.TextStyle
              pw.Text('Mode: ${vente.modePaiement}', style: const pw.TextStyle(fontSize: 8)),

              pw.Divider(height: 5, thickness: 0.5),

              // --- Bas de page ---
              pw.Text('MERCI DE VOTRE VISITE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              // Suppression du mot clé 'final' devant pw.TextStyle
              pw.Text('Conservez ce reçu comme preuve d\'achat.', style:  pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic)),
              pw.SizedBox(height: 10),
            ],
          ),
        ),
    ),
  );
  return doc;
}

// Widget utilitaire pour les lignes de totaux thermiques
pw.Row _buildThermalTotalRow(String label, double amount, bool isFinal, {bool isNegative = false}) {
  final displayAmount = isNegative ? -amount : amount;
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: isFinal ? 9 : 8,
          fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
      pw.Text(
        '${displayAmount.toStringAsFixed(0)} $devise',
        style: pw.TextStyle(
          fontSize: isFinal ? 9 : 8,
          fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  );
}
// --- 3. Génération de Rapport de Liste (Inventaire ou Ventes) ---
/// Génère un rapport PDF A4 pour une liste de données (Ventes, Produits, etc.).
/// [totals] est une map optionnelle pour afficher une section de résumé, typiquement utilisée pour l'inventaire.
Future<Uint8List> generateListReport({
  required String title,
  required List<Map<String, dynamic>> data,
  Map<String, double> totals = const {},
  Map<String, String> summaryLines = const {},
}) async {
  final doc = pw.Document(title: title);
  final logoImage = await _loadAssetImage(logoAssetPath);
  final showTotals = totals.isNotEmpty;
  final showSummary = summaryLines.isNotEmpty;

  // Extraction des en-têtes (clé de la première ligne de données)
  List<String> headers = data.isNotEmpty ? data.first.keys.toList() : [];

  // Conversion des données en List<List<String>>
  List<List<String>> dataRows = data.map((row) {
    return headers.map((header) => row[header].toString()).toList();
  }).toList();

  // Calculs supplémentaires pour l'affichage des totaux (principalement pour l'inventaire)
  double totalAchat = totals['totalValeurAchats'] ?? 0.0;
  double totalVente = totals['totalValeurVentes'] ?? 0.0;
  double margeTotale = totalVente - totalAchat;


  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(
          marginBottom: 30, marginTop: 40, marginLeft: 30, marginRight: 30),
      header: (context) => pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (logoImage.isNotEmpty)
                pw.Image(pw.MemoryImage(logoImage), height: 30, width: 30),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(nomEntreprise, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(adresseEntreprise, style: const pw.TextStyle(fontSize: 8)),
                  ]
              ),
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Center(
            child: pw.Text(
              title.toUpperCase(),
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Divider(height: 1, thickness: 0.5),
        ],
      ),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.center,
        child: pw.Text(
          'Généré le ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} - Page ${context.pageNumber} sur ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
        ),
      ),
      build: (context) => [
        // 1. TABLEAU PRINCIPAL (Liste des produits/ventes)
        pw.Table.fromTextArray(
          headers: headers.map((h) => h.toUpperCase()).toList(),
          data: dataRows,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo600),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(5),
          cellStyle: const pw.TextStyle(fontSize: 10),
          rowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
        ),

        if (showSummary) ...[
          pw.SizedBox(height: 20),
          pw.Text("RÉSUMÉ", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          pw.Table.fromTextArray(
            headers: ['LIBELLÉ', 'VALEUR'],
            data: summaryLines.entries.map((e) => [e.key, e.value]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],

        // 2. ⭐️ TABLEAU DES TOTAUX (Affiché uniquement si la map 'totals' n'est pas vide) ⭐️
        if (showTotals) ...[
          pw.SizedBox(height: 20),

          pw.Text("RÉSUMÉ GLOBAL DE L'INVENTAIRE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),

          pw.Table.fromTextArray(
              headers: ['TOTAUX', 'Qté Reçue', 'Qté Dispo', 'Valeur Achats', 'Valeur Vente', 'Marge'],

              data: [[
                '---',
                totals['totalStockReceptionne']!.toStringAsFixed(0),
                totals['totalStockDisponible']!.toStringAsFixed(0),
                '${totalAchat.toStringAsFixed(0)} $devise',
                '${totalVente.toStringAsFixed(0)} $devise',
                '${margeTotale.toStringAsFixed(0)} $devise', // Marge
              ]],

              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
              cellStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellAlignment: pw.Alignment.center,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.5),
                5: const pw.FlexColumnWidth(1.5),
              }
          ),
        ],
      ],
    ),
  );

  return doc.save();
}