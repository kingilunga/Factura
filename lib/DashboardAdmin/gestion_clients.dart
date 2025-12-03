import 'package:factura/Modeles/model_clients.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
// Imports nécessaires pour la génération et l'impression PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart' as sql;
import 'package:uuid/uuid.dart';
// L'import de la page 'modifier_client_page.dart' a été supprimé pour éviter l'erreur.

class GestionClients extends StatefulWidget {
  const GestionClients({super.key});

  @override
  State<GestionClients> createState() => _GestionClientsState();
}

// Petit modèle pour contenir les statistiques d'un client
class ClientStats {
  final int totalAchats;
  final double chiffreAffaires;

  ClientStats({this.totalAchats = 0, this.chiffreAffaires = 0.0});
}

// Modèle étendu pour lier Client et Stats pour le rapport PDF
class ClientData {
  final Client client;
  final ClientStats stats;

  ClientData(this.client, this.stats);
}

class _GestionClientsState extends State<GestionClients> {
  final DatabaseService _dbService = DatabaseService.instance;
  List<Client> _clients = [];
  List<Client> _filteredClients = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final Uuid _uuid = const Uuid();

  // --- SIMULATION DE RÔLE : Si cet utilisateur est un simple vendeur, cette variable est false. ---
  final bool _canEditOrDelete = false;

  // Message personnalisé affiché si l'utilisateur clique sans permission.
  static const String _permissionMessage =
      'Action non autorisée. Veuillez contacter l\'administrateur pour modifier ou supprimer des clients.';

  @override
  void initState() {
    super.initState();
    _loadClients();
    _searchController.addListener(_filterClients);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterClients);
    _searchController.dispose();
    super.dispose();
  }

  // Fonction utilitaire pour afficher le message de permission refusée
  void _showPermissionDeniedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_permissionMessage),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Chargement initial des clients ---
  Future<void> _loadClients() async {
    setState(() => _isLoading = true);
    try {
      final clients = await _dbService.getAllClients();
      setState(() {
        _clients = clients;
        _filterClients();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Erreur lors du chargement des clients: $e");
    }
  }

  // --- Fonction pour récupérer les statistiques de vente par client ---
  Future<ClientStats> _fetchClientStats(int clientLocalId) async {
    try {
      final db = await _dbService.database;

      final List<Map<String, dynamic>> result = await db.query(
        _dbService.ventesTable,
        columns: ['COUNT(localId) as totalAchats', 'SUM(totalNet) as chiffreAffaires'],
        where: 'clientLocalId = ?',
        whereArgs: [clientLocalId],
      );

      if (result.isNotEmpty && result.first.isNotEmpty) {
        final int totalAchats = (result.first['totalAchats'] as num?)?.toInt() ?? 0;
        final double chiffreAffaires = (result.first['chiffreAffaires'] as num?)?.toDouble() ?? 0.0;

        return ClientStats(
          totalAchats: totalAchats,
          chiffreAffaires: chiffreAffaires,
        );
      }
      return ClientStats();
    } catch (e) {
      print('Erreur SQL lors du calcul des stats client $clientLocalId: $e');
      return ClientStats();
    }
  }

  // --- Insertion des Ventes de Test ---
  Future<void> _insertDummySales() async {
    if (_clients.isEmpty) return;

    setState(() => _isLoading = true);
    final db = await _dbService.database;
    int salesCount = 0;

    Future<void> insertSale(int clientId, double amount) async {
      await db.insert(
        _dbService.ventesTable,
        {
          'venteId': _uuid.v4(),
          'dateVente': DateTime.now().toIso8601String(),
          'clientLocalId': clientId,
          'vendeurNom': 'TestUser',
          'totalBrut': amount,
          'reductionPercent': 0.0,
          'totalNet': amount,
          'statut': 'Terminée',
          'serverId': null,
          'syncStatus': 'pending',
        },
        conflictAlgorithm: sql.ConflictAlgorithm.replace,
      );
      salesCount++;
    }

    if (_clients.first.localId != null) {
      for (int i = 1; i <= 5; i++) {
        await insertSale(_clients.first.localId!, 10000.0 + 5000.0 * i);
      }
    }
    if (_clients.length > 1 && _clients[1].localId != null) {
      await insertSale(_clients[1].localId!, 50000.0);
      await insertSale(_clients[1].localId!, 30000.0);
    }

    await _loadClients();
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$salesCount ventes de test insérées. Les statistiques devraient se mettre à jour !')),
    );
  }

  // --- Logique de suppression d'un client (Avec vérification de rôle) ---
  Future<bool> _confirmDeletion(String nomClient) async {
    if (!_canEditOrDelete) {
      _showPermissionDeniedMessage();
      return false;
    }

    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content: Text("Êtes-vous sûr de vouloir supprimer le client '$nomClient'? Cette action est irréversible et supprimera toutes les données associées (ventes, etc.)."),
          actions: <Widget>[
            TextButton(
              child: const Text("Annuler"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  Future<void> _deleteClient(Client client) async {
    if (client.localId == null) return;

    if (!_canEditOrDelete) {
      _showPermissionDeniedMessage();
      return;
    }

    final confirmed = await _confirmDeletion(client.nomClient);
    if (confirmed) {
      try {
        await _dbService.deleteClient(client.localId!);
        _loadClients();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Le client "${client.nomClient}" a été supprimé.')),
          );
        }
      } catch (e) {
        print("Erreur lors de la suppression du client: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur lors de la suppression : $e')),
          );
        }
      }
    }
  }


  // --- Logique de recherche / filtrage des clients ---
  void _filterClients() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredClients = _clients;
      } else {
        _filteredClients = _clients.where((client) {
          final nomMatch = client.nomClient.toLowerCase().contains(query);
          final telMatch = (client.telephone ?? '').toLowerCase().contains(query);
          return nomMatch || telMatch;
        }).toList();
      }
    });
  }

  // --- Gestion de la navigation vers la page d'édition (Simulation) ---
  void _openEditClientPage(Client client) {
    // 1. Vérification des droits (Vendeur)
    if (!_canEditOrDelete) {
      _showPermissionDeniedMessage();
      return;
    }

    // 2. Si l'utilisateur est Admin, nous SIMULONS l'ouverture de la page de modification.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modification du client : ${client.nomClient}'),
        content: const Text(
            'Cette boîte de dialogue SIMULE la page "ModifierClientPage". '
                'Elle serait normalement implémentée ici pour permettre à l\'administrateur de mettre à jour les données du client.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer la simulation'),
          )
        ],
      ),
    );
  }

  // --- Génération du Rapport PDF (Non modifié) ---
  Future<void> _generateClientReportPdf() async {
    setState(() => _isLoading = true);

    List<ClientData> dataForPdf = [];
    for (var client in _filteredClients) {
      if (client.localId != null) {
        final stats = await _fetchClientStats(client.localId!);
        dataForPdf.add(ClientData(client, stats));
      }
    }

    dataForPdf.sort((a, b) => b.stats.chiffreAffaires.compareTo(a.stats.chiffreAffaires));

    final pdf = pw.Document();

    final headers = [
      'Nom du client',
      'Téléphone',
      'Achats (Nb)',
      'Chiffre d\'Affaires (FC)'
    ];

    final data = dataForPdf.map((item) {
      return [
        item.client.nomClient,
        item.client.telephone ?? 'N/A',
        item.stats.totalAchats.toString(),
        item.stats.chiffreAffaires.toStringAsFixed(0),
      ];
    }).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Rapport Clients & Performance',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('13132D')),
              ),
              pw.SizedBox(height: 20),
              pw.Table.fromTextArray(
                  headers: headers,
                  data: data,
                  border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF13132D)),
                  cellHeight: 30,
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.center,
                    2: pw.Alignment.center,
                    3: pw.Alignment.centerRight,
                  },
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2.5),
                    1: const pw.FlexColumnWidth(2),
                    2: const pw.FlexColumnWidth(1.5),
                    3: const pw.FlexColumnWidth(2),
                  }
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'Généré le: ${DateTime.now().toLocal().toString().split(' ')[0]}',
                style: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    setState(() => _isLoading = false);

    await Printing.sharePdf(filename: 'Rapport_Clients.pdf', bytes: await pdf.save());
  }
  // --- Fin Génération PDF ---


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des Clients'),
        backgroundColor: const Color(0xFF13132D),
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading && _clients.isNotEmpty)
          //IconButton(
          //icon: const Icon(Icons.add_shopping_cart),
          //tooltip: 'Insérer Ventes Test',
          //onPressed: _insertDummySales,
          //),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Imprimer la liste des clients',
              onPressed: _filteredClients.isNotEmpty && !_isLoading
                  ? _generateClientReportPdf
                  : null,
            ),
        ],
      ),
      body: Column(
        children: [
          // Champ de recherche
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Rechercher par nom ou téléphone...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF13132D)),
                contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF13132D)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF13132D), width: 2),
                ),
              ),
            ),
          ),

          _isLoading
              ? const Center(child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(color: Color(0xFF13132D)),
          ))
              : Expanded(
            child: _filteredClients.isEmpty
                ? const Center(child: Text("Aucun client trouvé correspondant à la recherche."))
                : ListView.builder(
              itemCount: _filteredClients.length,
              itemExtent: 100.0,
              itemBuilder: (context, index) {
                final client = _filteredClients[index];

                return FutureBuilder<ClientStats>(
                  future: client.localId != null ? _fetchClientStats(client.localId!) : Future.value(ClientStats()),
                  builder: (context, snapshot) {
                    final stats = snapshot.data ?? ClientStats();

                    final isTopClient = stats.totalAchats >= 5 || stats.chiffreAffaires > 50000;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: isTopClient ? BorderSide(color: Colors.green.shade600, width: 2) : BorderSide.none,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: isTopClient ? Colors.green.shade600 : const Color(0xFF13132D),
                          child: Icon(isTopClient ? Icons.star : Icons.person, color: Colors.white, size: 20),
                        ),
                        title: Text(
                          client.nomClient,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            // Ligne 1: Téléphone et Adresse condensés
                            Text(
                              (client.telephone ?? 'N/A') +
                                  (client.adresse != null && client.adresse!.isNotEmpty ? ' | ${client.adresse}' : ''),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),

                            // Ligne 2: Statistiques (Achats et CA) côte à côte
                            snapshot.connectionState == ConnectionState.done || snapshot.hasData
                                ? Row(
                              children: [
                                // Stat Achats
                                _buildStatChip(context, Icons.shopping_cart, "Achats: ${stats.totalAchats}", isTopClient ? Colors.green.shade100 : Colors.blue.shade100, isTopClient ? Colors.green.shade800 : Colors.blue.shade800),
                                const SizedBox(width: 8),
                                // Stat Chiffre d'Affaires (CA)
                                _buildStatChip(context, Icons.payments, "CA: ${stats.chiffreAffaires.toStringAsFixed(0)} FC", isTopClient ? Colors.green.shade100 : Colors.red.shade100, isTopClient ? Colors.green.shade800 : Colors.red.shade800),
                              ],
                            )
                                : const SizedBox(
                                width: 100,
                                child: LinearProgressIndicator(color: Color(0xFF13132D), backgroundColor: Colors.white)
                            ),
                          ],
                        ),

                        // --- ESPACE BOUTONS (TOUJOURS VISIBLE) ---
                        trailing: SizedBox(
                          width: 90,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Bouton Modifier
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                onPressed: () => _openEditClientPage(client),
                                tooltip: 'Modifier',
                              ),
                              // Bouton Supprimer
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () => _deleteClient(client),
                                tooltip: 'Supprimer',
                              ),
                            ],
                          ),
                        ),

                        // Action principale au clic (modification)
                        onTap: () => _openEditClientPage(client),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget utilitaire pour afficher les statistiques sous forme de "puce" compacte
  Widget _buildStatChip(BuildContext context, IconData icon, String text, Color bgColor, Color fgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fgColor.withOpacity(0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fgColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: fgColor,
            ),
          ),
        ],
      ),
    );
  }
}
