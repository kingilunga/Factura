import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/Modeles/model_ventes.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// Définition des types de rapport pour la navigation
enum RapportType {
  ventes,
  stock,
  clients,
  fournisseurs,
}

class Rapports extends StatefulWidget {
  final String typeDocument;
  const Rapports({super.key, required this.typeDocument});

  @override
  State<Rapports> createState() => _RapportsState();
}

class _RapportsState extends State<Rapports> {
  // État de la navigation (par défaut: Ventes)
  RapportType _selectedRapport = RapportType.ventes;

  final DatabaseService _db = DatabaseService.instance;
  // --- FILTRES ACTIFS pour le Rapport Ventes ---
  String _selectedPeriod = 'Année';
  DateTime _startDate = DateTime(DateTime.now().year, 1, 1);
  DateTime _endDate = DateTime.now();

  // --- DONNÉES ET ÉTAT ---
  List<Map<String, dynamic>> _ventes = [];
  bool _isLoading = true;

  final List<String> _periods = ['Jour', 'Semaine', 'Mois', 'Année'];
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Map des configurations de rapports pour la barre d'onglets
  final Map<RapportType, Map<String, dynamic>> _rapportConfigs = {
    RapportType.ventes: {'label': 'Rapport de Ventes', 'icon': Icons.bar_chart},
    RapportType.stock: {'label': 'Rapport de Stocks', 'icon': Icons.inventory_2},
    RapportType.clients: {'label': 'Rapport Clients', 'icon': Icons.people},
    RapportType.fournisseurs: {'label': 'Rapport Fournisseurs', 'icon': Icons.local_shipping},
  };

  @override
  void initState() {
    super.initState();
    _loadVentes();
  }

  // --- LOGIQUE DE CHARGEMENT DES VENTES (Inchngée) ---

  Future<void> _loadVentes() async {
    if (_selectedRapport != RapportType.ventes) return;

    setState(() => _isLoading = true);
    final allVentes = await _db.getAllVentes();
    final now = DateTime.now();

    List<Vente> filtered = [];

    switch (_selectedPeriod) {
      case 'Jour':
        filtered = allVentes.where((v) {
          final date = DateTime.parse(v.dateVente);
          return date.year == now.year && date.month == now.month && date.day == now.day;
        }).toList();
        break;
      case 'Semaine':
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekEnd = weekStart.add(const Duration(days: 6));
        filtered = allVentes.where((v) {
          final date = DateTime.parse(v.dateVente);
          return !date.isBefore(weekStart) && !date.isAfter(weekEnd.add(const Duration(days: 1)));
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
      case 'Personnalisé':
        filtered = allVentes.where((v) {
          final date = DateTime.parse(v.dateVente);
          return !date.isBefore(_startDate) && !date.isAfter(_endDate.add(const Duration(days: 1)));
        }).toList();
        break;
    }

    // Récupérer les noms des clients
    List<Map<String, dynamic>> ventesAvecClients = [];
    for (var v in filtered) {
      final client = await _db.getClientById(v.clientLocalId);
      ventesAvecClients.add({
        'vente': v,
        'clientNom': client?.nomClient ?? 'Inconnu',
        'typeDocument': 'Facture',
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
      _loadVentes();
    });
  }

  // --- LOGIQUE D'IMPRESSION PDF (Inchngée) ---
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
              if (_ventes.isNotEmpty)
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
                )
              else
                pw.Center(
                  child: pw.Text("Aucune vente à imprimer pour cette période.", style: const pw.TextStyle(fontSize: 14)),
                )
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  // --- WIDGET POUR LA BARRE D'ONGLETS HORIZONTALE ---
  Widget _buildHorizontalTabs() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: _rapportConfigs.entries.map((entry) {
              final type = entry.key;
              final config = entry.value;
              final isSelected = _selectedRapport == type;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: TextButton.icon(
                  icon: Icon(config['icon'], size: 20),
                  label: Text(config['label']),
                  style: TextButton.styleFrom(
                    foregroundColor: isSelected ? Colors.white : Colors.indigo.shade900,
                    backgroundColor: isSelected ? Colors.indigo.shade700 : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    textStyle: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedRapport = type;
                      if (type == RapportType.ventes) {
                        _loadVentes();
                      } else {
                        _isLoading = false;
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // --- WIDGET POUR LE CONTENU DÉTAILLÉ DU RAPPORT SÉLECTIONNÉ ---
  Widget _buildRapportContent() {
    // Affiche l'indicateur de chargement uniquement pour le rapport de Ventes s'il est sélectionné
    if (_selectedRapport == RapportType.ventes && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Le contenu spécifique au rapport
    switch (_selectedRapport) {
      case RapportType.ventes:
        return _buildVentesRapport();
      case RapportType.stock:
        return _buildPlaceholderRapport('Rapport de Stocks', 'Affichage de l\'état actuel et historique des mouvements de stock.');
      case RapportType.clients:
        return _buildPlaceholderRapport('Rapport Clients', 'Analyse du Top Clients, du CA par client et des créances.');
      case RapportType.fournisseurs:
        return _buildPlaceholderRapport('Rapport Fournisseurs', 'Suivi des achats effectués et des dettes envers les fournisseurs.');
    }
  }

  // --- WIDGET SPÉCIFIQUE AU RAPPORT DE VENTES (Contenu principal) ---
  Widget _buildVentesRapport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. En-tête du Rapport de Ventes
          const Text(
            'Analyse des Transactions',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF13132D)),
          ),
          Text(
            'Filtres de période actifs: $_selectedPeriod',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const Divider(),

          // 2. Barres de Filtres de Période et Exportation
          _buildFiltersBar(),
          const SizedBox(height: 20),

          // 3. Espace Graphique (Visualisation)
          _buildChartArea(),
          const SizedBox(height: 20),

          // 4. Titre du Tableau
          Text(
            'Transactions Récentes (${_ventes.length} trouvées)',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF13132D)),
          ),
          const SizedBox(height: 10),

          // 5. Tableau des Données
          _buildDataTable(),
        ],
      ),
    );
  }

  // --- WIDGETS DE COMPOSANTS (Inchngés) ---

  Widget _buildFiltersBar() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          alignment: WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Sélecteur de Période
            ..._periods.map((p) {
              final selected = _selectedPeriod == p;
              return ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: selected ? Colors.indigo.shade700 : Colors.indigo.shade100,
                  foregroundColor: selected ? Colors.white : Colors.indigo.shade900,
                  elevation: selected ? 4 : 1,
                ),
                onPressed: () => _selectPeriod(p),
                child: Text(p),
              );
            }).toList(),

            const SizedBox(width: 30),

            // Bouton pour imprimer/exporter PDF
            ElevatedButton.icon(
              onPressed: _ventes.isEmpty ? null : _imprimerVentes,
              icon: const Icon(Icons.print),
              label: const Text('Imprimer/Exporter PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartArea() {
    final double totalCA = _ventes.fold(0.0, (sum, item) {
      final v = item['vente'] as Vente;
      return sum + v.totalNet;
    });

    return Card(
      elevation: 2,
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(16),
        height: 350,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Row(
          children: [
            // Affichage du KPI principal
            Container(
              width: 200,
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chiffre d\'Affaires Net', style: TextStyle(fontSize: 16, color: Colors.indigo)),
                  const Spacer(),
                  Text(
                    '${totalCA.toStringAsFixed(2)} CDF',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                  ),
                  const Spacer(),
                  Text('${_ventes.length} transactions pour cette période.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Espace pour le graphique
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Graphique de Tendance (À Implémenter)',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Visualisation du CA par jour/semaine/mois pour la période $_selectedPeriod',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 200,
                      color: Colors.transparent,
                      child: const Center(child: Text('Placeholder du Graphique')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_ventes.isEmpty) {
      return const Center(child: Text("Aucune vente à afficher pour les filtres sélectionnés."));
    }

    return Card(
      elevation: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.resolveWith((states) => Colors.indigo.shade50),
          dataRowHeight: 48,
          columnSpacing: 24,
          horizontalMargin: 12,

          columns: const [
            DataColumn(label: Text('ID Facture', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Client', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Montant Net', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right), numeric: true),
          ],
          rows: _ventes.map((e) {
            final v = e['vente'] as Vente;
            final clientNom = e['clientNom'] as String;

            // Utilisation de clientLocalId comme ID de document temporaire
            final int documentId = v.clientLocalId;

            return DataRow(
              cells: [
                // Correction de l'erreur : convertir l'INT en STRING
                DataCell(Text(documentId.toString())),
                DataCell(Text(_dateFormat.format(DateTime.parse(v.dateVente)))),
                DataCell(Text(clientNom)),
                DataCell(Text('${v.totalNet.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green))),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPlaceholderRapport(String title, String description) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(30),
        constraints: const BoxConstraints(maxWidth: 600),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300)
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction, size: 50, color: Colors.orange.shade700),
            const SizedBox(height: 15),
            Text(
              title,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange.shade800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              'Fonctionnalité en cours de construction.',
              style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.orange.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET PRINCIPAL (Structure à onglets horizontaux) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapports d\'Activité'),
        backgroundColor: Colors.indigo,
        elevation: 0, // Enlève l'ombre de l'AppBar
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Barre d'Onglets Horizontaux
          _buildHorizontalTabs(),

          // 2. Zone d'Affichage du Contenu (prend le reste de l'espace)
          Expanded(
            child: Container(
              color: Colors.grey.shade50, // Fond gris clair pour l'espace de contenu
              child: _buildRapportContent(),
            ),
          ),
        ],
      ),
    );
  }
}