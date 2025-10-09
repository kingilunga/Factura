import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:factura/database/model_ventes.dart';
import 'package:factura/database/model_clients.dart';

// --- Données Statiques de l'Entreprise pour la Facture (Centralisé) ---
const String nomEntreprise = "Factura Vision S.A.R.L";
const String adresseEntreprise = "123, Av. du Code, Kinshasa, RDC";
const String telephoneEntreprise = "+243 81 000 0000";
const String emailEntreprise = "contact@facturavision.cd";
// Chemin du logo mis à jour pour être utilisé partout
const String logoAssetPath = 'assets/images/Icon_FacturaVision.png';
// ---------------------------------------------------------------------


// Fonction utilitaire pour charger l'image asset
Future<Uint8List> _loadAssetImage(String assetPath) async {
  try {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  } catch (e) {
    debugPrint('Erreur lors du chargement de l\'asset image: $e');
    // Retourner un tableau de bytes vide pour éviter un crash
    return Uint8List(0);
  }
}

// Helper pour créer les lignes de totaux dans le PDF
pw.Widget _buildTotalRow(String label, double amount, bool isFinal) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: isFinal
              ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)
              : const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          '${amount.toStringAsFixed(0)} FC',
          style: isFinal
              ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColor.fromInt(Colors.blue.value))
              : const pw.TextStyle(fontSize: 10),
        ),
      ],
    ),
  );
}


/// Génère le document PDF de la facture à partir des données de vente et client.
/// Cette fonction est maintenant réutilisable.
Future<pw.Document> generatePdf(Vente vente, List<LigneVente> lignes, Client client) async {
  final pdf = pw.Document();

  // 1. Charger le logo en mémoire
  final Uint8List logoBytes = await _loadAssetImage(logoAssetPath);
  final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);


  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // --- EN-TÊTE DE LA FACTURE (Logo et Infos Entreprise) ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // LOGO : Utilisation de l'asset chargé
                  if (logoBytes.isNotEmpty) pw.Image(logoImage, height: 50),
                  pw.SizedBox(height: 5),

                  // Informations Entreprise
                  pw.Text(nomEntreprise, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(adresseEntreprise, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Tél: $telephoneEntreprise', style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Email: $emailEntreprise', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("FACTURE N°", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                    // Numéro de Facture au format désiré
                    pw.Text(vente.venteId, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(Colors.blue.value))),
                    pw.SizedBox(height: 8),
                    pw.Text("Date: ${vente.dateVente}"),
                  ]
              ),
            ],
          ),

          pw.Divider(thickness: 1.5, height: 20),

          // --- SECTION CLIENT ---
          pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(color: PdfColor.fromInt(Colors.grey.shade100.value), border: pw.Border.all(color: PdfColor.fromInt(Colors.grey.value))),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Facturé à:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                    pw.Text(client.nomClient, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text("Téléphone: ${client.telephone ?? 'N/A'}"),
                    pw.Text("Adresse: ${client.adresse ?? 'N/A'}"),
                  ]
              )
          ),

          pw.SizedBox(height: 20),

          // --- TABLEAU DES ARTICLES ---
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(Colors.blueGrey.shade100.value)),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 10),
            columnWidths: {
              0: const pw.FlexColumnWidth(3), // Désignation
              1: const pw.FlexColumnWidth(1.5), // Prix Unit.
              2: const pw.FlexColumnWidth(1), // Quantité
              3: const pw.FlexColumnWidth(1.5), // Sous-Total
            },
            headers: ["Désignation", "Prix Unit. (FC)", "Quantité", "Sous-Total (FC)"],
            data: lignes.map((l) => [
              l.nomProduit,
              l.prixVenteUnitaire.toStringAsFixed(0),
              l.quantite.toString(),
              l.sousTotal.toStringAsFixed(0),
            ]).toList(),
          ),

          pw.SizedBox(height: 30),

          // --- TOTALS ET PIED DE PAGE ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 250,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _buildTotalRow("Total Brut:", vente.totalBrut, false),
                    _buildTotalRow("Rabais / Réduction:", vente.reductionPercent, false),
                    pw.Divider(thickness: 1, height: 10),
                    // Total Net A Payer en gras et en couleur
                    pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(
                          color: PdfColor.fromInt(Colors.blue.shade50.value),
                          border: pw.Border.all(color: PdfColor.fromInt(Colors.blue.value))
                      ),
                      child: _buildTotalRow("NET À PAYER (FC):", vente.totalNet, true),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.Spacer(),

          pw.Divider(thickness: 1, height: 10),

          // Mention de non-retour/échange
          pw.Text(
            "La marchandise vendue et vérifiée ne peut être ni retournée ni échangée !",
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red700),
          ),

          pw.SizedBox(height: 5),

          pw.Text(
            "Merci pour votre achat. Paiement effectué par: ${vente.vendeurNom}",
            style: const pw.TextStyle(fontSize: 9),
          ),
          pw.Text(
            "Conditions: Facture payable immédiatement. Sans garantie après 7 jours.",
            style:  pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text("--- Factura Vision ---", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          )
        ],
      ),
    ),
  );
  return pdf;
}
