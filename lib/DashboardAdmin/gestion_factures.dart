import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:factura/database/database_service.dart';
import 'package:factura/Modeles/model_ventes.dart';
import 'package:factura/Modeles/model_clients.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:factura/service_pdf.dart' as pdf_service;
import 'package:intl/intl.dart';

class GestionFactures extends StatefulWidget {
  const GestionFactures({super.key});

  @override
  State<GestionFactures> createState() => _GestionFacturesState();
}

class _GestionFacturesState extends State<GestionFactures> {
  final db = DatabaseService.instance;

  List<Vente> ventes = [];
  Map<int, List<LigneVente>> lignesCache = {};
  Map<int, Client?> clientsCache = {};
  final TextEditingController searchController = TextEditingController();
  List<Vente> filteredVentes = [];

  DateTime? startDate;
  DateTime? endDate;

  // Données Statiques de l'Entreprise (à adapter si nécessaire)
  final String nomEntreprise = "Factura Vision S.A.R.L";
  final String adresseEntreprise = "123, Av. du Code, Kinshasa, RDC";
  final String telephoneEntreprise = "+243 81 000 0000";
  final String emailEntreprise = "contact@facturavision.cd";
  final String logoAssetPath = 'assets/images/Icon_FacturaVision.png';
  // ---------------------------------------------------------------------

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

  void _showDeleteConfirmationDialog(Vente vente) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text('Êtes-vous sûr de vouloir supprimer la facture ${vente.venteId} et tous ses détails ? Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
                deleteVente(vente);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }
  // --- FIN LOGIQUE DE SUPPRESSION ---

  // showVenteDetails (inchangée - seulement pour l'aperçu)
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
              if (client == null) {
                if(mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Impossible d\'exporter : Client non trouvé.')),
                  );
                }
                return;
              }

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

              await Printing.sharePdf(
                  bytes: await pdfDoc.save(),
                  filename: 'facture_A4_${vente.venteId}.pdf'
              );

              if(mounted) Navigator.pop(context);

              if(mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Facture générée et prête à être partagée.'), backgroundColor: Colors.green));
              }
            },
            child: const Text("Exporter/Partager PDF"),
          ),
          // Bouton Imprimer Reçu (Thermique)
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

              await Printing.layoutPdf(
                onLayout: (PdfPageFormat format) async => await pdfDoc.save(),
                name: 'Reçu Thermique ${vente.venteId}',
              );

              if(mounted) Navigator.pop(context);
            },
            child: const Text("Imprimer Reçu"),
          ),
        ],
      ),
    );
  }
  // Fin showVenteDetails

  // Fonctions pour l'export/impression de liste (Rapport périodique) - Inchangé
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
    if (reportData.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucune vente à exporter."), backgroundColor: Colors.orange));
      }
      return;
    }

    final dateRange = startDate != null && endDate != null
        ? ' du ${startDate!.day}/${startDate!.month}/${startDate!.year} au ${endDate!.day}/${endDate!.month}/${endDate!.year}'
        : ' (Historique Complet)';
    final title = "Rapport des Ventes $dateRange";

    try {
      final totals = _calculateTotals();
      final totalsForReport = {
        'Stock Articles Vendus': totals['totalArticlesVendues']?.toStringAsFixed(0) ?? '0',
        'Nb Transactions': totals['totalFactures']?.toStringAsFixed(0) ?? '0',
        'Valeur Facturée': '${totals['totalFactureFC']?.toStringAsFixed(0) ?? '0'} FC',
        'Valeur Encaissée': '${totals['totalEncaisseFC']?.toStringAsFixed(0) ?? '0'} FC',
        'Créances Restantes': '${(totals['totalFactureFC']! - totals['totalEncaisseFC']!).toStringAsFixed(0)} FC',
      };

      final pdfBytes = await pdf_service.generateListReport(
        title: title,
        data: reportData,
        summaryLines: totalsForReport,
      );

      await Printing.sharePdf(bytes: pdfBytes, filename: 'rapport_ventes.pdf');

      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Rapport PDF généré et prêt à être partagé !"), backgroundColor: Colors.green));
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'export PDF : $e"), backgroundColor: Colors.red));
    }
  }

  void printList() async {
    final reportData = _prepareDataForReport();
    if (reportData.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucune vente à imprimer."), backgroundColor: Colors.orange));
      }
      return;
    }

    final dateRange = startDate != null && endDate != null
        ? ' du ${startDate!.day}/${startDate!.month}/${startDate!.year} au ${endDate!.day}/${endDate!.month}/${endDate!.year}'
        : ' (Historique Complet)';
    final title = "Rapport des Ventes $dateRange";

    try {
      final totals = _calculateTotals();
      final totalsForReport = {
        'Stock Articles Vendus': totals['totalArticlesVendues']?.toStringAsFixed(0) ?? '0',
        'Nb Transactions': totals['totalFactures']?.toStringAsFixed(0) ?? '0',
        'Valeur Facturée': '${totals['totalFactureFC']?.toStringAsFixed(0) ?? '0'} FC',
        'Valeur Encaissée': '${totals['totalEncaisseFC']?.toStringAsFixed(0) ?? '0'} FC',
        'Créances Restantes': '${(totals['totalFactureFC']! - totals['totalEncaisseFC']!).toStringAsFixed(0)} FC',
      };

      final pdfBytes = await pdf_service.generateListReport(
        title: title,
        data: reportData,
        summaryLines: totalsForReport,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: 'Impression - Rapport Ventes',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'impression : $e"), backgroundColor: Colors.red));
    }
  }
  // Fin Fonctions rapport

  // --- LOGIQUE DE CALCUL DES TOTAUX Ventes (CORRIGÉE AVEC modePaiement) ---
  Map<String, double> _calculateTotals() {
    final totalFactures = filteredVentes.length.toDouble();
    double totalArticlesVendues = 0;

    double totalFactureFC = 0;
    double totalEncaisseFC = 0;

    for (var vente in filteredVentes) {
      totalFactureFC += vente.totalNet;

      final modePaiement = vente.modePaiement?.toUpperCase() ?? 'INCONNU';

      // Si le mode est CASH ou TRANSFERT, on suppose que le montant NET est intégralement encaissé.
      if (modePaiement == 'CASH' || modePaiement == 'TRANSFERT') {
        totalEncaisseFC += vente.totalNet;
      }
      // Si 'CREDIT' ou 'INCONNU', totalEncaisseFC n'augmente pas.
    }

    return {
      'totalFactures': totalFactures,
      'totalArticlesVendues': totalArticlesVendues,
      'totalFactureFC': totalFactureFC,
      'totalEncaisseFC': totalEncaisseFC,
    };
  }

  // --- WIDGET D'AFFICHAGE DES TOTAUX (Simplifié, Créances en ligne) ---
  Widget _buildTotalsRow(Map<String, double> totals) {
    final f = NumberFormat("#,###", "fr_FR");
    const Color clearBlack = Colors.black87;

    final totalArticles = totals['totalArticlesVendues']?.toStringAsFixed(0) ?? '0';
    final totalTransactions = totals['totalFactures']?.toStringAsFixed(0) ?? '0';
    final totalFacture = totals['totalFactureFC'] ?? 0.0;
    final totalCash = totals['totalEncaisseFC'] ?? 0.0;

    final creancesRestantes = totalFacture - totalCash;
    // Rouge si créance (> 0), Vert si soldé (<= 0)
    final colorCreances = creancesRestantes > 0 ? Colors.red.shade700 : Colors.green.shade700;

    // Liste des CINQ agrégats pour les colonnes
    final totalStats = [
      _TotalStat(title: 'Stock Articles Vendus', value: totalArticles, color: clearBlack, isQuantity: true),
      _TotalStat(title: 'Nb Transactions (Factures)', value: totalTransactions, color: clearBlack, isQuantity: true),
      _TotalStat(title: 'Valeur Totale Facturée', value: '${f.format(totalFacture)} FC', color: clearBlack),
      _TotalStat(title: 'Valeur Totale Encaissée', value: '${f.format(totalCash)} FC', color: clearBlack, isBold: true, fontSize: 18),

      // NOUVEL AGRÉGAT : Créances, maintenant en ligne et démarqué
      _TotalStat(
        title: 'Créances/Dette Restante',
        value: '${f.format(creancesRestantes)} FC',
        color: colorCreances,
        isBold: true,
        fontSize: 16,
        isQuantity: false,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(15.0),
      decoration: BoxDecoration(
        color: Colors.lightGreen.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.lightGreen.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Colonne du Titre
          const Padding(
            padding: EdgeInsets.only(right: 20.0),
            child: Text(
                'TOTAUX :',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF13132D),
                    fontSize: 20
                )
            ),
          ),

          // Séparateur vertical.
          const SizedBox(
            height: 50,
            child: VerticalDivider(thickness: 2, color: Colors.lightGreen),
          ),
          const SizedBox(width: 10),

          // Les 5 Agrégats en colonnes égales
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: totalStats.map((stat) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: stat,
                ),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET STATISTIQUE RÉUTILISABLE (Inchangé) ---
  Widget _TotalStat({
    required String title,
    required String value,
    required Color color,
    bool isBold = false,
    bool isQuantity = false,
    double fontSize = 16,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if(isQuantity) const Icon(Icons.shopping_cart, size: 16, color: Colors.black45),
            if(!isQuantity) const Icon(Icons.monetization_on, size: 16, color: Colors.black45),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                  color: color,
                ),
              ),
            ),
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
      appBar: AppBar(
        title: const Text("Historique des ventes"),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- SECTION DES TOTAUX (Maintenant simplifié) ---
            _buildTotalsRow(totals),
            const SizedBox(height: 20),
            // --- FIN SECTION DES TOTAUX ---

            // Row pour la recherche et les boutons
            Row(
              children: [
                // 1. Zone de Recherche
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Rechercher par client ou ID (ex: FV-001)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    ),
                    onChanged: filterVentes,
                  ),
                ),
                const SizedBox(width: 8),

                // 2. Bouton de sélection de Période (Date Range Picker)
                Tooltip(
                  message: startDate != null
                      ? 'Filtre actif: du ${startDate!.day}/${startDate!.month} au ${endDate!.day}/${endDate!.month}. Cliquez pour modifier/réinitialiser.'
                      : 'Filtrer par période',
                  child: IconButton(
                    icon: Icon(
                      Icons.calendar_today,
                      color: startDate != null ? Colors.blue : Colors.grey.shade700,
                    ),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                        initialDateRange: startDate != null && endDate != null
                            ? DateTimeRange(start: startDate!, end: endDate!)
                            : null,
                      );

                      if (picked != null) {
                        startDate = picked.start;
                        endDate = picked.end.add(const Duration(hours: 23, minutes: 59));
                      } else {
                        if (startDate != null || endDate != null) {
                          startDate = null;
                          endDate = null;
                        } else {
                          return;
                        }
                      }
                      loadVentes();
                    },
                  ),
                ),

                // 3. Bouton PDF (Rapport de liste)
                Tooltip(
                  message: 'Exporter la liste actuelle en PDF',
                  child: IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                    onPressed: exportListToPdf,
                  ),
                ),

                // 4. Bouton Imprimer (Rapport de liste)
                Tooltip(
                  message: 'Imprimer la liste actuelle',
                  child: IconButton(
                    icon: const Icon(Icons.print, color: Colors.blueGrey),
                    onPressed: printList,
                  ),
                ),
              ],
            ),
            // Fin Row

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
                    DataColumn(label: Text("Mode Paiement")),
                    DataColumn(label: Text("Statut")),
                    DataColumn(label: Text("Détails")),
                    DataColumn(label: Text("Supprimer")),
                  ],
                  rows: filteredVentes.map((v) {
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
                      DataCell(Text(v.dateVente.split(' ')[0])),
                      DataCell(Text(clientName)),
                      DataCell(Text('${v.totalNet.toStringAsFixed(0)} FC', style: const TextStyle(fontWeight: FontWeight.bold))),

                      DataCell(Text(v.modePaiement ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600))),

                      DataCell(Text(v.statut ?? '', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))),
                      DataCell(IconButton(
                        icon: Icon(Icons.remove_red_eye, color: Colors.blue.shade700),
                        onPressed: () => showVenteDetails(v),
                        tooltip: 'Voir les détails et exporter',
                      )),
                      DataCell(IconButton(
                        icon: Icon(Icons.delete_forever, color: Colors.red.shade700),
                        onPressed: () => _showDeleteConfirmationDialog(v),
                        tooltip: 'Supprimer cette vente',
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