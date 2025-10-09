import 'package:factura/database/database_service.dart';
import 'package:flutter/material.dart';

Widget buildLowStockPanel({
  required List<ProduitApercu> lowStockProducts,
  required int displayLimit,
  required void Function(int) goToSection, required List produits,
}) {
  final lowStock = lowStockProducts;

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
              const Text('Stock critique', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              OutlinedButton.icon(
                onPressed: () => goToSection(2),
                icon: const Icon(Icons.inventory_2),
                label: const Text('Gérer Produits'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: lowStock.isEmpty
                ? const Center(child: Text('Tous les produits sont bien en stock!'))
                : ListView.separated(
              itemCount: lowStock.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final p = lowStock[index];
                final isLow = p.stock <= 5 && p.stock > 0;
                final isOut = p.stock == 0;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isOut
                        ? Colors.red.shade200
                        : isLow
                        ? Colors.orange.shade200
                        : Colors.indigo.shade100,
                    child: Icon(Icons.warning, color: isOut ? Colors.red : Colors.orange),
                  ),
                  title: Text(p.nom),
                  trailing: Text(
                    'Stock: ${p.stock}',
                    style: TextStyle(
                      color: isOut ? Colors.red : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
