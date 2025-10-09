import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle; // Pour charger l'image asset
import 'package:factura/database/database_service.dart';
import 'package:factura/database/model_ventes.dart';
import 'package:factura/database/model_clients.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart'; // Ajouté pour les couleurs et le format d'image
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data'; // Pour le type d'image

class HistoriqueVentes extends StatefulWidget {
  const HistoriqueVentes({super.key});

  @override
  State<HistoriqueVentes> createState() => _HistoriqueVentesState();
}

class _HistoriqueVentesState extends State<HistoriqueVentes> {
  final db = DatabaseService.instance;

  List<Vente> ventes = [];
  Map<int, List<LigneVente>> lignesCache = {}; // cache pour détails
  Map<int, Client?> clientsCache = {}; // cache pour clients
  final TextEditingController searchController = TextEditingController();
  List<Vente> filteredVentes = [];

  // --- Données Statiques de l'Entreprise pour la Facture (À adapter) ---
  final String nomEntreprise = "Factura Vision S.A.R.L";
  final String adresseEntreprise = "123, Av. du Code, Kinshasa, RDC";
  final String telephoneEntreprise = "+243 81 000 0000";
  final String emailEntreprise = "contact@facturavision.cd";
  // Chemin de votre logo dans les assets. ASSUREZ-VOUS DE METTRE LE BON CHEMIN
  final String logoAssetPath = 'assets/images/Icon_FacturaVision.png';
  // ---------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    loadVentes();
  }

  Future<void> loadVentes() async {
    final loaded = await db.getAllVentes(); // à adapter selon ta DB
    if (!mounted) return;
    setState(() {
      ventes = loaded;
      filteredVentes = List<Vente>.from(ventes);
    });
  }

  void filterVentes(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => filteredVentes = List<Vente>.from(ventes));
      return;
    }
    setState(() {
      filteredVentes = ventes.where((v) {
        // Pour s'assurer que le nom du client est dans le cache pour la recherche
        final clientName = clientsCache[v.localId]?.nomClient?.toLowerCase() ?? '';
        return clientName.contains(q) || v.venteId.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> showVenteDetails(Vente vente) async {
    // 1. Récupérer et cacher le client
    Client? client;
    if (vente.clientLocalId != null && !clientsCache.containsKey(vente.localId)) {
      client = await db.getClientById(vente.clientLocalId!);
      clientsCache[vente.localId!] = client;
    } else {
      client = clientsCache[vente.localId];
    }

    // 2. Récupérer et cacher les lignes de vente
    List<LigneVente> lignes = [];
    if (vente.localId != null && !lignesCache.containsKey(vente.localId)) {
      lignes = await db.getLignesByVente(vente.localId!);
      lignesCache[vente.localId!] = lignes;
    } else if (vente.localId != null) {
      lignes = lignesCache[vente.localId!]!;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Détails vente - ${vente.venteId}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("ID Facture: ${vente.venteId}"),
              Text("Date: ${vente.dateVente}"),
              Text("Vendeur: ${vente.vendeurNom ?? 'N/A'}"),
              const SizedBox(height: 8),
              Text("Client: ${client?.nomClient ?? "Client Inconnu"}"),
              Text("Téléphone: ${client?.telephone ?? ''}"),
              const Divider(),
              const Text("Articles Vendus", style: TextStyle(fontWeight: FontWeight.bold)),
              DataTable(
                columnSpacing: 12,
                horizontalMargin: 12,
                columns: const [
                  DataColumn(label: Text("Produit")),
                  DataColumn(label: Text("Prix")),
                  DataColumn(label: Text("Qté")),
                  DataColumn(label: Text("S.total")),
                ],
                rows: lignes.map((l) {
                  return DataRow(cells: [
                    DataCell(Text(l.nomProduit ?? '')),
                    DataCell(Text('${l.prixVenteUnitaire?.toStringAsFixed(0) ?? '0'} FC')),
                    DataCell(Text('${l.quantite}')),
                    DataCell(Text('${l.sousTotal?.toStringAsFixed(0) ?? '0'} FC')),
                  ]);
                }).toList(),
              ),
              const Divider(),
              Text("Total Brut: ${vente.totalBrut.toStringAsFixed(0)} FC"),
              Text("Réduction: ${vente.reductionPercent.toStringAsFixed(0)} FC"),
              const SizedBox(height: 4),
              Text(
                "NET À PAYER: ${vente.totalNet.toStringAsFixed(0)} FC",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
          TextButton(
            onPressed: () async {
              if (client == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Impossible d\'exporter : Client non trouvé.')),
                );
                return;
              }
              final pdf = await generatePdf(vente, lignes, client!);
              await savePdfLocally(pdf, 'facture_${vente.venteId}');
              Navigator.pop(context);
            },
            child: const Text("Exporter PDF"),
          ),
        ],
      ),
    );
  }

  // Fonction utilitaire pour charger l'image asset
  Future<Uint8List> _loadAssetImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

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
                    pw.Image(logoImage, height: 50),
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

            // Nouvelle mention ajoutée ici
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

  Future<void> savePdfLocally(pw.Document pdf, String fileName) async {
    // ... (Reste de la fonction savePdfLocally inchangé)
    final bytes = await pdf.save();
    // Assure-toi que le nom du fichier ne contient pas de caractères invalides
    final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s]+'), '_');

    // Obtient le répertoire de téléchargement ou de documents
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$safeFileName.pdf');
    await file.writeAsBytes(bytes);

    // Afficher un message de succès
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Facture sauvegardée avec succès : ${file.path}'),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    // Pré-charger les clients pour l'affichage initial
    Future.microtask(() async {
      // Nous utilisons un Map pour suivre les IDs déjà demandés pour éviter les appels répétitifs
      Set<int> requestedClientIds = {};

      for (var vente in ventes) {
        if (vente.clientLocalId != null &&
            !clientsCache.containsKey(vente.localId) &&
            !requestedClientIds.contains(vente.localId)) {

          requestedClientIds.add(vente.localId!);
          final client = await db.getClientById(vente.clientLocalId!);
          if (mounted) {
            setState(() {
              clientsCache[vente.localId!] = client;
            });
          }
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Historique des ventes"),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Rechercher par client ou ID (ex: FV-001)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: filterVentes,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.blueGrey.shade50),
                  columns: const [
                    DataColumn(label: Text("ID Facture")),
                    DataColumn(label: Text("Date")),
                    DataColumn(label: Text("Client")),
                    DataColumn(label: Text("Total Net")),
                    DataColumn(label: Text("Statut")),
                    DataColumn(label: Text("Détails")),
                  ],
                  rows: filteredVentes.map((v) {
                    // S'assurer que le client est chargé pour l'affichage
                    final clientName = clientsCache[v.localId]?.nomClient ?? 'Chargement...';

                    Color statusColor;
                    if (v.statut == 'validée') {
                      statusColor = Colors.green.shade700;
                    } else if (v.statut == 'annulée') {
                      statusColor = Colors.red.shade700;
                    } else {
                      statusColor = Colors.orange.shade700;
                    }

                    return DataRow(cells: [
                      DataCell(Text(v.venteId)),
                      DataCell(Text(v.dateVente.split(' ')[0])), // Affiche la date seule
                      DataCell(Text(clientName)),
                      DataCell(Text('${v.totalNet.toStringAsFixed(0)} FC', style: const TextStyle(fontWeight: FontWeight.bold))),
                      // Correction si vous aviez un 'const' devant ce TextStyle
                      DataCell(Text(v.statut ?? '', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
                      DataCell(IconButton(
                        icon: Icon(Icons.remove_red_eye, color: Colors.blue.shade700),
                        onPressed: () => showVenteDetails(v),
                        tooltip: 'Voir les détails et exporter',
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
