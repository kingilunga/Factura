import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/model_ventes.dart';
import 'package:factura/database/model_clients.dart';
import 'package:factura/database/model_produits.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class DetailsVentePage extends StatefulWidget {
  final Vente vente;

  const DetailsVentePage({super.key, required this.vente});

  @override
  State<DetailsVentePage> createState() => _DetailsVentePageState();
}

class _DetailsVentePageState extends State<DetailsVentePage> {
  final db = DatabaseService.instance;
  Client? client;
  List<LigneVente> lignes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDetails();
  }

  Future<void> loadDetails() async {
    final fetchedLignes = await db.getLignesByVente(widget.vente.localId ?? 0);
    final fetchedClient = await db.getClientById(widget.vente.clientLocalId);

    if (!mounted) return;
    setState(() {
      lignes = fetchedLignes;
      client = fetchedClient;
      isLoading = false;
    });
  }

  double get total => lignes.fold(0, (sum, item) => sum + item.sousTotal);

  double get discount => total * 0.07;

  double get net => total - discount;

  Future<void> generatePdf() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Facture", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text("Client: ${client?.nomClient ?? 'Inconnu'}"),
            pw.Text("Téléphone: ${client?.telephone ?? ''}"),
            pw.Text("Adresse: ${client?.adresse ?? ''}"),
            pw.SizedBox(height: 16),
            pw.Table.fromTextArray(
              headers: ["Produit", "Prix", "Qté", "Sous-total"],
              data: lignes.map((l) => [
                l.nomProduit,
                l.prixVenteUnitaire.toStringAsFixed(0),
                l.quantite.toString(),
                l.sousTotal.toStringAsFixed(0),
              ]).toList(),
            ),
            pw.SizedBox(height: 16),
            pw.Text("Total: ${total.toStringAsFixed(0)} F"),
            pw.Text("Rabais: ${discount.toStringAsFixed(0)} F"),
            pw.Text("Net à payer: ${net.toStringAsFixed(0)} F"),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Détails de la vente"),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: generatePdf,
            tooltip: "Exporter PDF",
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Client: ${client?.nomClient ?? 'Inconnu'}", style: const TextStyle(fontWeight: FontWeight.bold)),
            Text("Téléphone: ${client?.telephone ?? ''}"),
            Text("Adresse: ${client?.adresse ?? ''}"),
            const SizedBox(height: 16),
            const Text("Produits:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: lignes.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final l = lignes[index];
                  return ListTile(
                    title: Text(l.nomProduit),
                    subtitle: Text("Prix: ${l.prixVenteUnitaire.toStringAsFixed(0)}  • Qté: ${l.quantite}"),
                    trailing: Text("${l.sousTotal.toStringAsFixed(0)} F"),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Total: ${total.toStringAsFixed(0)} F"),
                  Text("Rabais: ${discount.toStringAsFixed(0)} F"),
                  Text("Net à payer: ${net.toStringAsFixed(0)} F", style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
