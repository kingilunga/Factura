import 'package:factura/Modeles/model_utilisateurs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:factura/database/database_service.dart';
import 'package:factura/Modeles/model_ventes.dart';
import 'package:factura/Modeles/model_clients.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:factura/service_pdf.dart' as pdf_service;
import 'package:intl/intl.dart';

class HistoriqueVentes extends StatefulWidget {
  const HistoriqueVentes({super.key, required String typeDocument});

  @override
  State<HistoriqueVentes> createState() => _HistoriqueVentesState();
}

class _HistoriqueVentesState extends State<HistoriqueVentes> {
  final db = DatabaseService.instance;

  List<Vente> ventes = [];
  Map<int, List<LigneVente>> lignesCache = {};
  Map<int, Client?> clientsCache = {};
  final TextEditingController searchController = TextEditingController();
  List<Vente> filteredVentes = [];

  DateTime? startDate;
  DateTime? endDate;

  // Données Statiques de l'Entreprise
  final String nomEntreprise = "Factura Vision S.A.R.L";
  final String adresseEntreprise = "123, Av. du Code, Kinshasa, RDC";
  final String telephoneEntreprise = "+243 81 000 0000";
  final String emailEntreprise = "contact@facturavision.cd";
  final String logoAssetPath = 'assets/images/Icon_FacturaVision.png';

  @override
  void initState() {
    super.initState();
    searchController.addListener(() => filterVentes(searchController.text));
    loadVentes();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadVentes() async {
    final loaded = await db.getAllVentes(
      startDate: startDate,
      endDate: endDate,
    );
    if (!mounted) return;
    setState(() {
      ventes = loaded;
      filterVentes(searchController.text);
    });
  }

  void filterVentes(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => filteredVentes = List<Vente>.from(ventes));
      return;
    }
    setState(() {
      _loadClientsForFiltering();
      filteredVentes = ventes.where((v) {
        final clientName = clientsCache[v.localId]?.nomClient?.toLowerCase() ?? '';
        return clientName.contains(q) || v.venteId.toLowerCase().contains(q);
      }).toList();
    });
  }

  Future<void> _loadClientsForFiltering() async {
    for (var vente in ventes) {
      if (vente.clientLocalId != null && !clientsCache.containsKey(vente.localId)) {
        final client = await db.getClientById(vente.clientLocalId!);
        if (mounted) {
          setState(() {
            clientsCache[vente.localId!] = client;
          });
        }
      }
    }
  }

  // --- LOGIQUE DE SUPPRESSION ---
  Future<void> deleteVente(Vente vente) async {
    if (vente.localId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur: ID de vente local manquant.')),
      );
      return;
    }

    try {
      await db.deleteVente(vente.localId!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Facture ${vente.venteId} supprimée avec succès.')),
      );

      lignesCache.remove(vente.localId!);
      clientsCache.remove(vente.localId!);
      await loadVentes();

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e')),
      );
    }
  }

  // --- APERÇU DÉTAILS (CORRIGÉ POUR LA REMISE) ---
  Future<void> showVenteDetails(Vente vente) async {
    Client? client;
    if (vente.clientLocalId != null && !clientsCache.containsKey(vente.localId)) {
      client = await db.getClientById(vente.clientLocalId!);
      clientsCache[vente.localId!] = client;
    } else {
      client = clientsCache[vente.localId];
    }

    List<LigneVente> lignes = [];
    if (vente.localId != null && !lignesCache.containsKey(vente.localId)) {
      lignes = await db.getLignesByVente(vente.localId!);
      lignesCache[vente.localId!] = lignes;
    } else if (vente.localId != null) {
      lignes = lignesCache[vente.localId!]!;
    }

    if (!mounted) return;

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
                    DataCell(Text('${l.prixVenteUnitaire?.toStringAsFixed(0) ?? '0'} F')),
                    DataCell(Text('${l.quantite}')),
                    DataCell(Text('${l.sousTotal?.toStringAsFixed(0) ?? '0'} F')),
                  ]);
                }).toList(),
              ),
              const Divider(),
              Text("Total Brut: ${vente.totalBrut.toStringAsFixed(0)} F"),
              // 🎯 ICI : On utilise directement la valeur saisie en remise
              Text("Réduction: ${vente.reductionPercent.toStringAsFixed(0)} F"),
              const SizedBox(height: 4),
              Text(
                "NET À PAYER: ${vente.totalNet.toStringAsFixed(0)} F",
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
          // Bouton Exporter/Partager PDF (A4)
          TextButton(
            onPressed: () async {
              if (client == null) return;
              final pdfVente = pdf_service.PdfVente(
                venteId: vente.venteId,
                dateVente: vente.dateVente,
                vendeurNom: vente.vendeurNom ?? 'N/A',
                totalBrut: vente.totalBrut,
                montantReduction: vente.reductionPercent,
                totalNet: vente.totalNet,
                modePaiement: vente.modePaiement ?? 'CASH',
              );
              final pdfLignes = lignes.map((l) => pdf_service.PdfLigneVente(
                nomProduit: l.nomProduit ?? '',
                prixVenteUnitaire: l.prixVenteUnitaire ?? 0,
                quantite: l.quantite,
                sousTotal: l.sousTotal ?? 0,
              )).toList();
              final pdfClient = pdf_service.PdfClient(
                  nomClient: client.nomClient,
                  telephone: client.telephone,
                  adresse: client.adresse
              );
              final pdfDoc = await pdf_service.generatePdfA4(pdfVente, pdfLignes, pdfClient);
              await Printing.sharePdf(bytes: await pdfDoc.save(), filename: 'facture_A4_${vente.venteId}.pdf');
              if(mounted) Navigator.pop(context);
            },
            child: const Text("Exporter PDF"),
          ),
          // Bouton Imprimer Reçu
          TextButton(
            onPressed: () async {
              if (client == null) return;
              final pdfVente = pdf_service.PdfVente(
                venteId: vente.venteId,
                dateVente: vente.dateVente,
                vendeurNom: vente.vendeurNom ?? 'N/A',
                totalBrut: vente.totalBrut,
                montantReduction: vente.reductionPercent,
                totalNet: vente.totalNet,
                modePaiement: vente.modePaiement ?? 'CASH',
              );
              final pdfLignes = lignes.map((l) => pdf_service.PdfLigneVente(
                nomProduit: l.nomProduit ?? '',
                prixVenteUnitaire: l.prixVenteUnitaire ?? 0,
                quantite: l.quantite,
                sousTotal: l.sousTotal ?? 0,
              )).toList();
              final pdfClient = pdf_service.PdfClient(
                  nomClient: client.nomClient,
                  telephone: client.telephone,
                  adresse: client.adresse
              );
              final pdfDoc = await pdf_service.generateThermalReceipt(pdfVente, pdfLignes, pdfClient);
              await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => await pdfDoc.save(), name: 'Reçu_${vente.venteId}');
              if(mounted) Navigator.pop(context);
            },
            child: const Text("Imprimer Reçu"),
          ),
        ],
      ),
    );
  }

  // Fonctions Rapport (PDF & Print)
  List<Map<String, dynamic>> _prepareDataForReport() {
    return filteredVentes.map((v) {
      final clientName = clientsCache[v.localId]?.nomClient ?? 'N/A';
      return {
        "ID Facture": v.venteId,
        "Date": v.dateVente.substring(0, 10),
        "Client": clientName,
        "Total Net (FC)": v.totalNet.toStringAsFixed(0),
        "Statut": v.statut ?? 'En attente',
      };
    }).toList();
  }

  void exportListToPdf() async {
    final reportData = _prepareDataForReport();
    if (reportData.isEmpty) return;
    final title = "Rapport des Ventes";
    try {
      final totals = _calculateTotals();
      final totalsForReport = {
        'Transactions': totals['totalFactures']?.toStringAsFixed(0) ?? '0',
        'Valeur Facturée': '${totals['totalFactureFC']?.toStringAsFixed(0) ?? '0'} FC',
        'Valeur Encaissée': '${totals['totalEncaisseFC']?.toStringAsFixed(0) ?? '0'} FC',
      };
      final pdfBytes = await pdf_service.generateListReport(title: title, data: reportData, summaryLines: totalsForReport);
      await Printing.sharePdf(bytes: pdfBytes, filename: 'rapport_ventes.pdf');
    } catch (e) {
      print(e);
    }
  }

  void printList() async {
    final reportData = _prepareDataForReport();
    if (reportData.isEmpty) return;
    final title = "Rapport des Ventes";
    try {
      final totals = _calculateTotals();
      final totalsForReport = {
        'Transactions': totals['totalFactures']?.toStringAsFixed(0) ?? '0',
        'Valeur Facturée': '${totals['totalFactureFC']?.toStringAsFixed(0) ?? '0'} FC',
        'Valeur Encaissée': '${totals['totalEncaisseFC']?.toStringAsFixed(0) ?? '0'} FC',
      };
      final pdfBytes = await pdf_service.generateListReport(title: title, data: reportData, summaryLines: totalsForReport);
      await Printing.layoutPdf(onLayout: (format) async => pdfBytes, name: 'Impression_Rapport');
    } catch (e) {
      print(e);
    }
  }

  // --- LOGIQUE CALCUL TOTAUX ---
  Map<String, double> _calculateTotals() {
    final totalFactures = filteredVentes.length.toDouble();
    double totalFactureFC = 0;
    double totalEncaisseFC = 0;
    for (var vente in filteredVentes) {
      totalFactureFC += vente.totalNet;
      if (['CASH', 'TRANSFERT'].contains(vente.modePaiement?.toUpperCase())) {
        totalEncaisseFC += vente.totalNet;
      }
    }
    return {
      'totalFactures': totalFactures,
      'totalArticlesVendues': 0,
      'totalFactureFC': totalFactureFC,
      'totalEncaisseFC': totalEncaisseFC,
    };
  }

  // --- WIDGETS UI (DESIGN ORIGINAL) ---
  Widget _buildTotalsRow(Map<String, double> totals) {
    final f = NumberFormat("#,###", "fr_FR");
    final creances = totals['totalFactureFC']! - totals['totalEncaisseFC']!;
    final stats = [
      _TotalStat(title: 'Stock Articles', value: '0', isQuantity: true),
      _TotalStat(title: 'Transactions', value: totals['totalFactures']!.toInt().toString(), isQuantity: true),
      _TotalStat(title: 'Facturé', value: '${f.format(totals['totalFactureFC'])} FC'),
      _TotalStat(title: 'Encaissé', value: '${f.format(totals['totalEncaisseFC'])} FC', isBold: true, fontSize: 18),
      _TotalStat(title: 'Créances', value: '${f.format(creances)} FC', color: creances > 0 ? Colors.red : Colors.green, isBold: true),
    ];

    return Container(
      padding: const EdgeInsets.all(15.0),
      decoration: BoxDecoration(color: Colors.lightGreen.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.lightGreen.shade200)),
      child: Row(
        children: [
          const Text('TOTAUX :', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF13132D), fontSize: 20)),
          const SizedBox(height: 50, child: VerticalDivider(thickness: 2, color: Colors.lightGreen)),
          const SizedBox(width: 10),
          Expanded(child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: stats.map((s) => Expanded(child: s)).toList())),
        ],
      ),
    );
  }

  Widget _TotalStat({required String title, required String value, Color color = Colors.black87, bool isBold = false, bool isQuantity = false, double fontSize = 16}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
        Row(
          children: [
            Icon(isQuantity ? Icons.shopping_cart : Icons.monetization_on, size: 16, color: Colors.black45),
            const SizedBox(width: 4),
            Expanded(child: Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: color), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Future.microtask(_loadClientsForFiltering);
    final totals = _calculateTotals();
    return Scaffold(
      appBar: AppBar(title: const Text("Historique des ventes"), backgroundColor: Colors.blueGrey.shade800, foregroundColor: Colors.white),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildTotalsRow(totals),
            const SizedBox(height: 20),
            _buildSearchSection(),
            const SizedBox(height: 16),
            Expanded(child: _buildDataTable()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Rechercher...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
        IconButton(icon: const Icon(Icons.calendar_today), onPressed: _showDatePicker),
        IconButton(icon: const Icon(Icons.picture_as_pdf, color: Colors.red), onPressed: exportListToPdf),
        IconButton(icon: const Icon(Icons.print, color: Colors.blueGrey), onPressed: printList),
      ],
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDateRangePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime.now());
    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end.add(const Duration(hours: 23, minutes: 59));
      });
      loadVentes();
    }
  }

  Widget _buildDataTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade50),
        columns: const [
          DataColumn(label: Text("ID Facture")),
          DataColumn(label: Text("Date")),
          DataColumn(label: Text("Client")),
          DataColumn(label: Text("Total Net")),
          DataColumn(label: Text("Mode")),
          DataColumn(label: Text("Statut")),
          DataColumn(label: Text("Détails")),
          DataColumn(label: Text("Supprimer")),
        ],
        rows: filteredVentes.map((v) {
          return DataRow(cells: [
            DataCell(Text(v.venteId)),
            DataCell(Text(v.dateVente.substring(0, 10))),
            DataCell(Text(clientsCache[v.localId]?.nomClient ?? 'Chargement...')),
            DataCell(Text('${v.totalNet.toStringAsFixed(0)} FC', style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(v.modePaiement ?? 'CASH')),
            DataCell(Text(v.statut ?? 'validée', style: TextStyle(color: v.statut == 'annulée' ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
            DataCell(IconButton(icon: const Icon(Icons.remove_red_eye, color: Colors.blue), onPressed: () => showVenteDetails(v))),
            DataCell(IconButton(icon: const Icon(Icons.delete_forever, color: Colors.red), onPressed: () => _confirmerSuppressionSecurisee(context, v))),
          ]);
        }).toList(),
      ),
    );
  }

  // --- DIALOGUE DE SÉCURITÉ ---
  Future<void> _confirmerSuppressionSecurisee(BuildContext context, Vente vente) async {
    TextEditingController _pwd = TextEditingController();
    final utilisateurs = await db.getUtilisateurs();
    Utilisateur? cible;
    try {
      cible = utilisateurs.firstWhere((u) => u.role == 'admin' || u.role == 'superadmin');
    } catch (e) {
      cible = null;
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("VÉRIFICATION GÉRANT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Mot de passe de ${cible?.prenom ?? 'Admin'} requis."),
            const SizedBox(height: 15),
            TextField(controller: _pwd, obscureText: true, decoration: _proInput("Mot de passe", Icons.lock_person)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANNULER")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (_pwd.text == (cible?.motDePasse ?? "0000")) {
                Navigator.pop(context);
                deleteVente(vente);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect !")));
              }
            },
            child: const Text("AUTORISER", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  InputDecoration _proInput(String label, IconData icon) {
    return InputDecoration(
      labelText: label, prefixIcon: Icon(icon, color: Colors.indigo), filled: true, fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}