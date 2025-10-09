import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/model_produits.dart';
import 'package:factura/database/model_clients.dart';
import 'package:factura/database/model_ventes.dart';

class RapportsPage extends StatefulWidget {
  final String typeDocument; // ex: "Facture", "Clients", "Produits", "Clients Performants"

  const RapportsPage({super.key, required this.typeDocument});

  @override
  State<RapportsPage> createState() => _RapportsPageState();
}

class _RapportsPageState extends State<RapportsPage> {
  final db = DatabaseService.instance;
  List<dynamic> data = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    switch (widget.typeDocument) {
      case "Facture":
        data = await db.getAllVentes();
        break;
      case "Clients":
        data = await db.getAllClients();
        break;
      case "Clients Performants":
        data = await db.fetchClientOverview(limit: 10);
        break;
      case "Produits":
        data = await db.getAllProduits();
        break;
      case "Produits Performants":
        data = await db.fetchTopSellingProducts(limit: 10);
        break;
      default:
        data = [];
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: Text("Rapport : ${widget.typeDocument}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: data.isEmpty
            ? const Center(child: Text("Aucune donnée disponible"))
            : SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor:
            MaterialStateColor.resolveWith((states) => Colors.indigo.shade50),
            columns: _buildColumns(),
            rows: _buildRows(),
            dataRowColor: MaterialStateColor.resolveWith(
                    (states) => Colors.white.withOpacity(0.9)),
            dividerThickness: 1,
            columnSpacing: 24,
          ),
        ),
      ),
    );
  }

  List<DataColumn> _buildColumns() {
    if (data.isEmpty) return [];

    final first = data.first;
    if (first is Produit) return [
      const DataColumn(label: Text("Nom")),
      const DataColumn(label: Text("Catégorie")),
      const DataColumn(label: Text("Prix")),
      const DataColumn(label: Text("Stock")),
    ];
    if (first is Client) return [
      const DataColumn(label: Text("Nom")),
      const DataColumn(label: Text("Téléphone")),
      const DataColumn(label: Text("Adresse")),
      const DataColumn(label: Text("Total Achats")),
    ];
    if (first is ClientApercu) return [
      const DataColumn(label: Text("Nom")),
      const DataColumn(label: Text("Type")),
      const DataColumn(label: Text("Total Opérations")),
      const DataColumn(label: Text("")),
    ];
    if (first is Vente) return [
      const DataColumn(label: Text("ID Vente")),
      const DataColumn(label: Text("Client")),
      const DataColumn(label: Text("Date")),
      const DataColumn(label: Text("Total Net")),
    ];

    return [];
  }

  List<DataRow> _buildRows() {
    return data.map((item) {
      if (item is Produit) {
        return DataRow(cells: [
          DataCell(Text(item.nom)),
          DataCell(Text(item.categorie ?? "")),
          DataCell(Text(item.prix!.toStringAsFixed(2))),
          DataCell(Text(item.quantiteActuelle.toString())),
        ]);
      }
      if (item is Client) {
        return DataRow(cells: [
          DataCell(Text(item.nomClient)),
          DataCell(Text(item.telephone ?? "")),
          DataCell(Text(item.adresse ?? "")),
          DataCell(Text("N/A")),
        ]);
      }
      if (item is ClientApercu) {
        return DataRow(cells: [
          DataCell(Text(item.nomClient)),
          DataCell(Text(item.type)),
          DataCell(Text(item.totalOperations.toString())),
          const DataCell(Text("")),
        ]);
      }
      if (item is Vente) {
        return DataRow(cells: [
          DataCell(Text(item.venteId)),
          DataCell(Text(item.clientLocalId.toString())),
          DataCell(Text(item.dateVente)),
          DataCell(Text(item.totalNet.toStringAsFixed(2))),
        ]);
      }
      return const DataRow(cells: []);
    }).toList();
  }
}
