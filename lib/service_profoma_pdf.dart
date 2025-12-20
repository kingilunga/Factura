import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:flutter/foundation.dart';

// --- Modèles de données simplifiés ---

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

class PdfClient {
  final String? nomClient;
  final String? telephone;
  final String? adresse;

  PdfClient({this.nomClient, this.telephone, this.adresse});
}

// --- Données Statiques ---
const String nomEntreprise = "SHOP JEADOT - S.A.R.L";
const String adresseEntreprise = "PETIT MARCHE MAMA AWUYI, LODJA";
const String telephoneEntreprise = "+243 821672206";
const String emailEntreprise = "contact@facturavision.cd";
const String logoAssetPath = 'assets/images/Icon_FacturaVision.png';
const String devise = "FC";

// --- Chargement des polices et images ---

Future<pw.Font> _loadFont(String path) async {
  final fontData = await rootBundle.load(path);
  return pw.Font.ttf(fontData);
}

Future<Uint8List> _loadAssetImage(String assetPath) async {
  try {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  } catch (e) {
    debugPrint('Erreur image asset: $e');
    return Uint8List(0);
  }
}

// --- 1. Génération de Facture A4 ---

Future<pw.Document> generatePdfA4(
    PdfVente vente, List<PdfLigneVente> lignes, PdfClient client) async {
  final doc = pw.Document(title: 'Facture ${vente.venteId}');

  // Chargement du logo
  final logoImage = await _loadAssetImage(logoAssetPath);

  // 1. Chargement des données brutes (ByteData) depuis les assets
  // Attention : on respecte bien ton chemin avec "Fonts" et "robotto"
  final fontData = await rootBundle.load("assets/Fonts/robotto/Roboto-Regular.ttf");
  final fontBoldData = await rootBundle.load("assets/Fonts/robotto/Roboto-Bold.ttf");

  // 2. Conversion des données en objets Polices (pw.Font)
  // C'est ici qu'on définit fontRegular et fontBold pour corriger tes erreurs
  final fontRegular = pw.Font.ttf(fontData);
  final fontBold = pw.Font.ttf(fontBoldData);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      // 3. Application du thème global avec les polices créées
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
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
                pw.Text(nomEntreprise, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(adresseEntreprise, style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Tél: $telephoneEntreprise', style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Email: $emailEntreprise', style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ],
        ),
        pw.Divider(height: 20),

        // --- Titre ---
        pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(bottom: 20),
          child: pw.Text('FACTURE PROFORMA',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
        ),

        // --- Infos Client et Facture ---
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Facturé à:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(client.nomClient ?? 'Client Anonyme'),
                pw.Text('Tél: ${client.telephone ?? 'N/A'}'),
                pw.Text('Adresse: ${client.adresse ?? 'N/A'}'),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('N°: ${vente.venteId}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text('Date: ${vente.dateVente.split(' ')[0]}'),
                pw.Text('Vendeur: ${vente.vendeurNom}'),
                pw.Text('Paiement: ${vente.modePaiement}'),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 20),

        // --- Tableau des produits ---
        pw.Table.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
          cellStyle: const pw.TextStyle(fontSize: 10),
          headers: ['Produit', 'Prix Unit.', 'Qté', 'Sous-total'],
          data: lignes.map((l) => [
            l.nomProduit,
            '${l.prixVenteUnitaire.toStringAsFixed(0)} $devise',
            l.quantite.toString(),
            '${l.sousTotal.toStringAsFixed(0)} $devise',
          ]).toList(),
        ),

        pw.SizedBox(height: 30),

        // --- Section Totaux ---
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildTotalRow('Total Brut:', vente.totalBrut, false),
                _buildTotalRow('Réduction:', vente.montantReduction, false, isNegative: true),
                pw.SizedBox(width: 150, child: pw.Divider(thickness: 1)),
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
// --- 2. Génération de Reçu Thermique (58mm) ---

Future<pw.Document> generateThermalReceipt(
    PdfVente vente, List<PdfLigneVente> lignes, PdfClient client) async {
  final doc = pw.Document();
  final logoImage = await _loadAssetImage(logoAssetPath);
  final fontRegular = await _loadFont("assets/fonts/Roboto-Regular.ttf");
  final fontBold = await _loadFont("assets/fonts/Roboto-Bold.ttf");

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(58 * PdfPageFormat.mm, double.infinity, marginAll: 2 * PdfPageFormat.mm),
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      build: (context) => pw.Column(
        children: [
          if (logoImage.isNotEmpty) pw.Image(pw.MemoryImage(logoImage), height: 30),
          pw.Text(nomEntreprise, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Divider(thickness: 0.5),
          pw.Text('REÇU ${vente.venteId}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 5),
          ...lignes.map((l) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text(l.nomProduit, style: const pw.TextStyle(fontSize: 7))),
                pw.Text('${l.quantite}x', style: const pw.TextStyle(fontSize: 7)),
                pw.Text('${l.sousTotal.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              ]
          )),
          pw.Divider(thickness: 0.5),
          _buildThermalTotalRow('TOTAL NET:', vente.totalNet, true),
          pw.SizedBox(height: 10),
          pw.Text('MERCI DE VOTRE VISITE', style: const pw.TextStyle(fontSize: 7)),
        ],
      ),
    ),
  );
  return doc;
}

// --- 3. Génération de Rapport de Liste ---

Future<Uint8List> generateListReport({
  required String title,
  required List<Map<String, dynamic>> data,
  Map<String, double> totals = const {},
  Map<String, String> summaryLines = const {},
}) async {
  final doc = pw.Document();
  final fontRegular = await _loadFont("assets/fonts/Roboto-Regular.ttf");
  final fontBold = await _loadFont("assets/fonts/Roboto-Bold.ttf");

  List<String> headers = data.isNotEmpty ? data.first.keys.toList() : [];
  List<List<String>> dataRows = data.map((row) => headers.map((h) => row[h].toString()).toList()).toList();

  doc.addPage(
    pw.MultiPage(
      theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      header: (context) => pw.Center(child: pw.Text(title.toUpperCase(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14))),
      build: (context) => [
        pw.SizedBox(height: 20),
        pw.Table.fromTextArray(
          headers: headers.map((h) => h.toUpperCase()).toList(),
          data: dataRows,
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo600),
          headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
          cellStyle: const pw.TextStyle(fontSize: 9),
        ),
      ],
    ),
  );
  return doc.save();
}

// --- Helpers pour les lignes de totaux ---

pw.Row _buildTotalRow(String label, double amount, bool isFinal, {PdfColor? color, bool isNegative = false}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.SizedBox(width: 100, child: pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal))),
      pw.SizedBox(width: 100, child: pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('${isNegative ? "-" : ""}${amount.toStringAsFixed(0)} $devise',
            style: pw.TextStyle(fontSize: isFinal ? 12 : 10, fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
      )),
    ],
  );
}

pw.Row _buildThermalTotalRow(String label, double amount, bool isFinal, {bool isNegative = false}) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: pw.TextStyle(fontSize: isFinal ? 8 : 7, fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal)),
      pw.Text('${isNegative ? "-" : ""}${amount.toStringAsFixed(0)} $devise',
          style: pw.TextStyle(fontSize: isFinal ? 8 : 7, fontWeight: isFinal ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ],
  );
}