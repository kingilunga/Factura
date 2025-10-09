import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/model_ventes.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class Rapports extends StatefulWidget {
  const Rapports({super.key});

  @override
  State<Rapports> createState() => _RapportsState();
}

class _RapportsState extends State<Rapports> {
  final DatabaseService _db = DatabaseService.instance;
  String _selectedPeriod = 'Jour';
  List<Map<String, dynamic>> _ventes = [];
  bool _isLoading = true;

  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadVentes();
  }

  Future<void> _loadVentes() async {
    setState(() => _isLoading = true);
    final allVentes = await _db.getAllVentes();
    final now = DateTime.now();

    List<Vente> filtered = [];

    switch (_selectedPeriod) {
      case 'Jour':
        filtered = allVentes.where((v) {
          final date = DateTime.parse(v.dateVente);
          return date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        }).toList();
        break;
      case 'Semaine':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        filtered = allVentes.where((v) {
          final date = DateTime.parse(v.dateVente);
          return !date.isBefore(weekStart) && !date.isAfter(weekEnd);
        }).toList();
        break;
      case 'Mois':
        filtered = allVentes.where((v) =>
        DateTime.parse(v.dateVente).year == now.year &&
            DateTime.parse(v.dateVente).month == now.month).toList();
        break;
      case 'Année':
        filtered = allVentes.where((v) => DateTime.parse(v.dateVente).year == now.year).toList();
        break;
    }

    // Récupérer les noms des clients et ajouter typeDocument
    List<Map<String, dynamic>> ventesAvecClients = [];
    for (var v in filtered) {
      final client = await _db.getClientById(v.clientLocalId);
      ventesAvecClients.add({
        'vente': v,
        'clientNom': client?.nomClient ?? 'Inconnu',
        'typeDocument': 'Facture', // valeur par défaut, à adapter si besoin
      });
    }

    if (mounted) {
      setState(() {
        _ventes = ventesAvecClients;
        _isLoading = false;
      });
    }
  }

  void _selectPeriod(String period) {
    setState(() {
      _selectedPeriod = period;
    });
    _loadVentes();
  }

  Future<void> _imprimerVentes() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Rapport de Ventes ($_selectedPeriod)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Table.fromTextArray(
                headers: ['Date', 'Client', 'Type', 'Montant'],
                data: _ventes.map((e) {
                  final v = e['vente'] as Vente;
                  final clientNom = e['clientNom'] as String;
                  final typeDoc = e['typeDocument'] as String;
                  return [
                    _dateFormat.format(DateTime.parse(v.dateVente)),
                    clientNom,
                    typeDoc,
                    v.totalNet.toStringAsFixed(2) + ' €'
                  ];
                }).toList(),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  @override
  Widget build(BuildContext context) {
    final periods = ['Jour', 'Semaine', 'Mois', 'Année'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _ventes.isEmpty ? null : _imprimerVentes,
            tooltip: 'Imprimer le rapport',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sélecteur de période
            Row(
              children: periods.map((p) {
                final selected = _selectedPeriod == p;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected ? Colors.indigo : Colors.grey[300],
                      foregroundColor: selected ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => _selectPeriod(p),
                    child: Text(p),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Liste des ventes
            Expanded(
              child: _ventes.isEmpty
                  ? const Center(child: Text('Aucune vente disponible pour cette période.'))
                  : ListView.separated(
                itemCount: _ventes.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final e = _ventes[index];
                  final v = e['vente'] as Vente;
                  final clientNom = e['clientNom'] as String;
                  final typeDoc = e['typeDocument'] as String;

                  return ListTile(
                    leading: const Icon(Icons.receipt_long, color: Colors.indigo),
                    title: Text('$typeDoc - $clientNom'),
                    subtitle: Text(_dateFormat.format(DateTime.parse(v.dateVente))),
                    trailing: Text('${v.totalNet.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
