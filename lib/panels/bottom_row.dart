import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';

/// 📊 Panel bas du tableau de bord
/// Contient : graphique tendance des ventes + actions rapides
Widget buildBottomRowPanel({
  required List<VenteTendance> salesTrends,
  required String selectedPeriod,
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
          // 📈 Titre
          Text(
            'Tendance des ventes ($selectedPeriod)',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 12),

          // 📊 Graphique ou placeholder
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: salesTrends.isEmpty
                  ? Text(
                'Aucune donnée disponible pour $selectedPeriod.',
                style: const TextStyle(color: Colors.grey),
              )
                  : const Text(
                '📊 Graphique de tendance des ventes (à implémenter)',
                style: TextStyle(color: Colors.indigo),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ⚡ Actions rapides
          const Text(
            'Actions rapides',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildQuickAction(
                icon: Icons.add_box,
                label: 'Nouvelle Facture',
                onTap: () => goToSection(4),
              ),
              _buildQuickAction(
                icon: Icons.people,
                label: 'Gérer Utilisateurs',
                onTap: () => goToSection(1),
              ),
              _buildQuickAction(
                icon: Icons.inventory_2,
                label: 'Ajouter Produit',
                onTap: () => goToSection(2),
              ),
              _buildQuickAction(
                icon: Icons.assessment,
                label: 'Rapports Détaillés',
                onTap: () => goToSection(5),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 🧩 Widget utilitaire pour une action rapide
Widget _buildQuickAction({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 20),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      side: BorderSide(color: Colors.indigo.shade300),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
