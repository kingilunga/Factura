import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';

// Définition du type de fonction pour générer le PDF (A4 ou Thermal)
typedef LayoutCallback = Future<Uint8List> Function(PdfPageFormat format);

/// Page pour afficher la prévisualisation du PDF A4 et Thermal.
class PdfPreviewPage extends StatefulWidget {
  final String title;
  // La fonction de génération doit prendre en compte le format demandé (A4 ou Thermal)
  // Pour notre usage, nous allons modifier ceci pour supporter nos deux fonctions
  final Future<Uint8List> Function(bool isThermal) generatePdfBytes;

  const PdfPreviewPage({
    super.key,
    required this.title,
    required this.generatePdfBytes,
  });

  @override
  State<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends State<PdfPreviewPage> {
  // 0 = A4 (Facture détaillée), 1 = Thermal (Reçu de caisse)
  int _selectedFormat = 0;

  // Définit le format PDF à utiliser pour l'aperçu
  PdfPageFormat get _currentFormat {
    if (_selectedFormat == 1) {
      // Format thermique 80mm (largeur 226 points)
      return const PdfPageFormat(226, double.infinity, marginAll: 5);
    }
    // Format A4 standard
    return PdfPageFormat.a4;
  }

  // Adapte l'appel à la fonction de génération en fonction du format sélectionné
  Future<Uint8List> _layoutPdf(PdfPageFormat format) {
    // Note: On passe 'true' si le format est thermique, 'false' pour A4
    final isThermal = _selectedFormat == 1;
    return widget.generatePdfBytes(isThermal);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.grey,
        actions: [
          // Bouton pour basculer entre A4 et Thermal
          ToggleButtons(
            isSelected: [_selectedFormat == 0, _selectedFormat == 1],
            onPressed: (index) {
              setState(() {
                _selectedFormat = index;
              });
            },
            borderRadius: BorderRadius.circular(8),
            selectedColor: Colors.white,
            fillColor: Colors.blueGrey,
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Facture A4", style: TextStyle(fontSize: 12))),
              Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text("Reçu Thermal", style: TextStyle(fontSize: 12))),
            ],
          ),
          const SizedBox(width: 16),
        ],
      ),
      // Le widget PdfPreview est l'outil principal
      body: PdfPreview(
        build: _layoutPdf,
        allowPrinting: true,
        allowSharing: true,
        initialPageFormat: _currentFormat,
        // Si c'est un reçu thermique, on utilise le mode d'affichage "taille réelle"
        maxPageWidth: _selectedFormat == 1 ? 400 : null,
      ),
    );
  }
}
