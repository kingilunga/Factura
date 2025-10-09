import 'package:factura/database/model_produits.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';

/// Panel des produits performants (Top 5)
Widget buildTopProduitsPanel({
  required List<Produit> topSellingProducts,
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
          // Titre et bouton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Produits Performants (Top 5)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => goToSection(2),
                icon: const Icon(Icons.trending_up),
                label: const Text('Rapport Produits'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Liste des produits
          SizedBox(
            height: 220,
            child: topSellingProducts.isEmpty
                ? const Center(
              child: Text(
                'Aucun produit vendu pour l’analyse.',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.separated(
              itemCount: topSellingProducts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final produit = topSellingProducts[index];

                // ⚠️ totalVendu doit venir d'une requête ou calcul
                final totalVendu = (produit.quantiteInitiale ?? 0) - (produit.quantiteActuelle ?? 0);

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        color: Colors.indigo.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    produit.nom,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    produit.categorie ?? 'Sans catégorie',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Text(
                    '$totalVendu unités',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
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
