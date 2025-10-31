import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, ByteData;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:typed_data';

// Note: Ces classes sont des modèles simplifiés utilisés uniquement par le moteur PDF.
// Elles sont nécessaires pour séparer la logique de la base de données de la logique de présentation.

// --- Modèle Client pour le PDF ---
class PdfClient {
  String nomClient;
  String? telephone;
  String? adresse;
  PdfClient({required this.nomClient, this.telephone, this.adresse});
}

// --- Modèle LigneVente pour le PDF ---
class PdfLigneVente {
  final String nomProduit;
  final double prixVenteUnitaire;
  final int quantite;
  final double sousTotal;
  PdfLigneVente({required this.nomProduit, required this.prixVenteUnitaire, required this.quantite, required this.sousTotal});
}

// --- Modèle Vente pour le PDF ---
class PdfVente {
  final String venteId; // Numéro de Facture/Reçu
  final String dateVente;
  final String vendeurNom;
  final String modePaiement;
  final double totalBrut;
  final double montantReduction; // Montant en FC (Votre code utilise reductionPercent pour le montant)
  final double totalNet; // Net à payer

  PdfVente({
    required this.venteId,
    required this.dateVente,
    required this.vendeurNom,
    this.modePaiement = 'CASH',
    required this.totalBrut,
    required this.montantReduction,
    required this.totalNet,
  });
}


// =========================================================================
// 2. CONFIGURATION ET CONSTANTES (SHOP-JEADOT)
// =========================================================================

const String nomEntreprise = "SHOP-JEADOT S.A.R.L";
const String adresseEntreprise = "013, Av. MAMA AWUYI, LODJA, RDC";
const String telephoneEntreprise = "+243 81 1521891";
const String emailEntreprise = "contact@shop-jeadot.cd";
// Le logo est conservé en tant que variable mais sera ignoré dans la fonction generateThermalReceipt
const String logoAssetPath = 'assets/images/Icon_FacturaVision.png';

// --- FORMAT SPÉCIFIQUE THERMIQUE (80mm) ---
// 220 points pour 80mm est la largeur totale.
const double _thermal80mmWidth = 220;

// Marge très réduite à 3 points pour la compatibilité thermique
const PdfPageFormat _thermalPageFormat =
PdfPageFormat(_thermal80mmWidth, double.infinity, marginAll: 3);
// Espace utilisable théorique : 220 - (3 * 2) = 214 points.

// Largeur maximale de contenu sécurisée: 185 points (Compromis)
const double _thermalContentWidth = 185;


// =========================================================================
// 3. FONCTIONS UTILITAIRES
// =========================================================================

Future<Uint8List> _loadAssetImage(String assetPath) async {
  try {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  } catch (e) {
    debugPrint('Erreur lors du chargement de l\'asset image: $e');
    return Uint8List(0);
  }
}

// Helper pour les lignes de totaux dans la FACTURE A4
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
              ? pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
              color: PdfColors.blue700)
              : const pw.TextStyle(fontSize: 10),
        ),
      ],
    ),
  );
}

// Helper pour les lignes de totaux dans le REÇU THERMIQUE (Compact)
pw.Widget _buildThermalTotalRow(String label, double amount, bool isFinal) {

  final double finalFontSize = 7.5;
  final double defaultFontSize = 6.5;

  return pw.Container(
    // Utilisation de la largeur de contenu sécurisée: 185 points
    width: _thermalContentWidth,
    child: pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(
              label,
              style: isFinal
                  ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: finalFontSize)
                  : pw.TextStyle(fontSize: defaultFontSize),
            ),
          ),
          pw.Text(
            '${amount.toStringAsFixed(0)} FC',
            style: isFinal
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: finalFontSize)
                : pw.TextStyle(fontSize: defaultFontSize),
          ),
        ],
      ),
    ),
  );
}

// Helper pour la présentation compacte des articles dans le REÇU THERMIQUE (VERSION STABLE)
pw.Widget _buildThermalReceiptItem(PdfLigneVente ligne) {

  // Utilisation de la largeur de contenu sécurisée: 185 points
  const double itemWidth = _thermalContentWidth;

  const double nameFontSize = 7.0;
  const double detailFontSize = 6.0;
  const double subtotalFontSize = 7.0;

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      // Ligne 1: Nom du produit (Aligné à gauche)
      pw.SizedBox(
        width: itemWidth,
        child: pw.Text(
            ligne.nomProduit,
            style: pw.TextStyle(fontSize: nameFontSize, fontWeight: pw.FontWeight.bold),
            maxLines: 2,
            overflow: pw.TextOverflow.clip
        ),
      ),
      // Ligne 2: Détail Quantité x Prix Unitaire (gauche) et Sous-Total (droite)
      pw.SizedBox(
        width: itemWidth,
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              '${ligne.quantite} x ${ligne.prixVenteUnitaire.toStringAsFixed(0)} FC',
              style: pw.TextStyle(fontSize: detailFontSize, color: PdfColors.grey700),
            ),
            pw.Text(
              ligne.sousTotal.toStringAsFixed(0) + ' F',
              style: pw.TextStyle(fontSize: subtotalFontSize, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
      // On utilise le Divider vectoriel car il est requis pour la détection de l'imprimante
      pw.Divider(height: 5, thickness: 0.5, color: PdfColors.grey300),
    ],
  );
}


// =========================================================================
// 4. FONCTIONS DE GÉNÉRATION PRINCIPALES
// =========================================================================

/// FONCTION 1 : GÉNÉRATION PDF A4 (Facture détaillée)
Future<pw.Document> generatePdfA4(
    PdfVente vente, List<PdfLigneVente> lignes, PdfClient client) async {
  final pdf = pw.Document();

  //final Uint8List logoBytes = await _loadAssetImage(logoAssetPath);
  //final pw.MemoryImage logoImage = pw.MemoryImage(logoBytes);

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
                  //if (logoBytes.isNotEmpty) pw.Image(logoImage, height: 50),
                  pw.SizedBox(height: 5),

                  pw.Text(nomEntreprise,
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text(adresseEntreprise,
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Tél: $telephoneEntreprise',
                      style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Email: $emailEntreprise',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text("FACTURE N°",
                    style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                // Numéro de Facture
                pw.Text(vente.venteId,
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue700)),
                pw.SizedBox(height: 8),
                // Utilisation de substring pour la date
                pw.Text("Lodja,le : ${vente.dateVente.substring(0, 10)}"),
              ]),
            ],
          ),

          pw.Divider(thickness: 1.5, height: 20),

          // --- SECTION CLIENT ---
          pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  border: pw.Border.all(color: PdfColors.grey400)),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Facturé à:",
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 9)),
                    pw.Text(client.nomClient,
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text("Téléphone: ${client.telephone ?? 'N/A'}"),
                    pw.Text("Adresse: ${client.adresse ?? 'N/A'}"),
                  ])),

          pw.SizedBox(height: 18),

          // --- TABLEAU DES ARTICLES ---
          pw.Table.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey100),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            columnWidths: {
              0: const pw.FlexColumnWidth(3), // Désignation
              1: const pw.FlexColumnWidth(1.5), // Prix Unit.
              2: const pw.FlexColumnWidth(1), // Quantité
              3: const pw.FlexColumnWidth(1.5), // Sous-Total
            },
            headers: ["Désignation", "P.U.(F)", "Qté", "Total (F)"],
            data: lignes
                .map((l) => [
              l.nomProduit,
              l.prixVenteUnitaire.toStringAsFixed(0),
              l.quantite.toString(),
              l.sousTotal.toStringAsFixed(0),
            ])
                .toList(),
          ),

          pw.SizedBox(height: 30),

          // --- TOTALS ET PIED DE PAGE ---
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 240,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    _buildTotalRow("Total Brut:", vente.totalBrut, false),
                    _buildTotalRow("Réduction:", vente.montantReduction, false),
                    pw.Divider(thickness: 1, height: 10),
                    pw.Container(
                      padding: const pw.EdgeInsets.all(5),
                      decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          border: pw.Border.all(
                              color: PdfColors.blue)),
                      child: _buildTotalRow("NET À PAYER (F):", vente.totalNet, true),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.Spacer(),

          pw.Divider(thickness: 1, height: 10),

          pw.Text(
            "La marchandise vendue et vérifiée ne peut être ni retournée ni échangée !",
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.red700),
          ),

          pw.SizedBox(height: 5),

          pw.Text(
            "Merci pour votre achat. Vendeur: ${vente.vendeurNom}",
            style: const pw.TextStyle(fontSize: 8),
          ),
          pw.Text(
            "Mode de paiement: ${vente.modePaiement}",
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            "Conditions: Facture payable immédiatement. Sans garantie après 7 jours.",
            style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 10),
          pw.Center(
            child: pw.Text("--- SHOP-JEADOT ---",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          )
        ],
      ),
    ),
  );
  return pdf;
}


/// FONCTION 2 : GÉNÉRATION REÇU THERMIQUE (80mm) - VERSION STABLE ET SANS LOGO
Future<pw.Document> generateThermalReceipt(
    PdfVente vente, List<PdfLigneVente> lignes, PdfClient client) async {
  final pdf = pw.Document();

  // Suppression de l'utilisation du logo

  // Tailles de police optimisées pour la compacité
  const double infoFontSize = 6.0;
  const double shopNameFontSize = 8.0;
  const double shopInfoFontSize = 6.0;

  pdf.addPage(
    pw.Page(
      pageFormat: _thermalPageFormat,
      build: (context) => pw.Column(
        // Le corps entier est centré
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // --- EN-TÊTE DU REÇU (Centralisé SANS Logo) ---
          pw.Container(
            width: _thermalContentWidth, // 185 points
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center, // Centralisation des infos
              children: [
                pw.Text(nomEntreprise,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: shopNameFontSize, fontWeight: pw.FontWeight.bold)),
                pw.Text(adresseEntreprise,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: shopInfoFontSize)),
                pw.Text('Tél: $telephoneEntreprise',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: shopInfoFontSize)),
                pw.Text('Email: $emailEntreprise',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: shopInfoFontSize)),
              ],
            ),
          ),


          pw.SizedBox(height: 8),
          // On revient au Divider vectoriel
          pw.Divider(thickness: 1, height: 10, color: PdfColors.black),

          // --- INFORMATIONS DU REÇU ET CLIENT (CÔTE À CÔTE, très compact) ---
          pw.Container(
            width: _thermalContentWidth, // 185 points
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Colonne de gauche: Infos Facture
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("Facture N°: ${vente.venteId.trim()}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: infoFontSize)),
                    // Affichage raccourci de la date et l'heure (YYYY-MM-DD HH:MM)
                    pw.Text("Date: ${vente.dateVente.substring(0, 16).replaceFirst('T', ' ')}", style: pw.TextStyle(fontSize: infoFontSize)),
                    pw.Text("Vendeur: ${vente.vendeurNom}", style: pw.TextStyle(fontSize: infoFontSize)),
                  ],
                ),
                // Colonne de droite: Infos Client
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    // Ligne du client
                    pw.Text(client.nomClient,
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: infoFontSize)),
                    pw.Text("Tél: ${client.telephone ?? 'N/A'}",
                        style: pw.TextStyle(fontSize: infoFontSize)),
                    pw.Text("Paiement: ${vente.modePaiement}",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: infoFontSize, color: PdfColors.blue700)),
                  ],
                )
              ],
            ),
          ),


          pw.Divider(thickness: 1, height: 10),

          // --- ARTICLES ---
          pw.Text("DÉTAIL DES ARTICLES",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7)),
          pw.SizedBox(height: 5),
          // On utilise la fonction qui réintègre pw.Divider
          ...lignes.map((l) => _buildThermalReceiptItem(l)).toList(),

          pw.SizedBox(height: 5),
          pw.Divider(thickness: 1, height: 10),

          // --- TOTALS ---
          pw.Container(
            // Utilisation de la largeur de contenu sécurisée (185 points)
            width: _thermalContentWidth,
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _buildThermalTotalRow("Total Brut:", vente.totalBrut, false),
                if (vente.montantReduction > 0)
                  _buildThermalTotalRow("Réduction:", vente.montantReduction, false),
                pw.Divider(thickness: 1, height: 5, color: PdfColors.black),

                // NET À PAYER mis en évidence
                pw.Container(
                  // Bordure plus fine et moins d'espacement pour gagner de la place
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
                  padding: const pw.EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                  child: _buildThermalTotalRow("NET À PAYER (F):", vente.totalNet, true),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // --- PIED DE PAGE ---
          pw.Text("MERCI DE VOTRE CONFIANCE !",
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8)),
          pw.SizedBox(height: 5),
          pw.Text(
            "La marchandise vendue ne peut être ni retournée ni échangée.",
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
          pw.Text(
            "Conditions: Payable immédiatement.",
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            "Iprimée à l'aide de l'Application Factura Vision",
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic, color: PdfColors.blue700),
          )
        ],
      ),
    ),
  );
  return pdf;
}
