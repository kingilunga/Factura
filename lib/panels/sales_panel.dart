import 'package:factura/database/database_service.dart';
import 'package:flutter/material.dart';
import '../database/models_utilisateurs.dart';

Widget buildSalesPanel({
  required List<VenteRecenteApercu> recentSales,
  required int displayLimit,
  required void Function(int) goToSection,
}) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ventes Récentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
              ElevatedButton.icon(
                onPressed: () => goToSection(4),
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Voir toutes les Factures'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: recentSales.isEmpty
                ? Center(child: Text('Aucune vente récente trouvée (Top $displayLimit).'))
                : ListView.separated(
              itemCount: recentSales.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final s = recentSales[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.receipt, color: Colors.blueGrey),
                  title: Text('${s.produitNom} (Vendu par ${s.vendeurNom})'),
                  subtitle: Text(s.dateVente),
                  trailing: Text('${s.montantNet.toStringAsFixed(2)} CDF', style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
