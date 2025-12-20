import 'package:flutter/material.dart';
import 'package:factura/Modeles/model_clients.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:factura/Modeles/model_ventes.dart';

// Modèle de support
class CartItem {
  Produit produit;
  int quantity;
  CartItem({required this.produit, this.quantity = 1});
}

class PanierFormulaire extends StatelessWidget {
  final Client? selectedClient;
  final List<CartItem> cart;
  final double currentExchangeRate;
  final String deviseSelected;
  final void Function(CartItem, int) onUpdateQuantity;
  final String modePaiement;
  final double remiseSaisie;
  final bool canValidate;
  final Future<void> Function() onValidateVente;

  const PanierFormulaire({
    super.key,
    required this.selectedClient,
    required this.cart,
    required this.currentExchangeRate,
    required this.deviseSelected,
    required this.onUpdateQuantity,
    required this.modePaiement,
    required this.remiseSaisie,
    required this.canValidate,
    required this.onValidateVente,
    // Note: Les anciens paramètres de recherche ont été supprimés ici
  });

  double getPriceVenteFC(Produit produit) {
    return (produit.prix ?? 0.0) * (currentExchangeRate > 0.0 ? currentExchangeRate : 1.0);
  }

  double get total => cart.fold(0, (sum, item) => sum + getPriceVenteFC(item.produit) * item.quantity);
  double get netToPay => total - remiseSaisie;

  Vente createTempVente() {
    return Vente(
      venteId: 'TEMP',
      dateVente: DateTime.now().toIso8601String(),
      clientLocalId: selectedClient?.localId ?? 0,
      vendeurNom: 'Vendeur',
      modePaiement: modePaiement,
      deviseTransaction: deviseSelected,
      tauxDeChange: currentExchangeRate,
      totalBrut: total,
      reductionPercent: remiseSaisie,
      totalNet: netToPay,
      statut: 'brouillon',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tempVente = canValidate ? createTempVente() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- SECTION UNIQUE : PANIER ET TOTAUX ---
        _buildSectionCard(
          title: 'Contenu du Panier',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cart.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Text("Le panier est vide.", style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                _buildCartTable(),

              const SizedBox(height: 20),

              if (canValidate)
                _buildTotalsDisplay(tempVente!)
              else
                const Center(child: Text("Sélectionnez un client et des articles.")),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCartTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowColor: MaterialStateProperty.all(Colors.grey.shade100),
        columns: const [
          DataColumn(label: Text("Produit")),
          DataColumn(label: Text("Prix (FC)")),
          DataColumn(label: Text("Qté")),
          DataColumn(label: Text("Sous-total")),
          DataColumn(label: Text("Actions")),
        ],
        rows: cart.map((item) {
          return DataRow(cells: [
            DataCell(Text(item.produit.nom ?? '')),
            DataCell(Text(getPriceVenteFC(item.produit).toStringAsFixed(0))),
            DataCell(Text("${item.quantity}")),
            DataCell(Text("${(getPriceVenteFC(item.produit) * item.quantity).toStringAsFixed(0)} FC")),
            DataCell(Row(
              children: [
                IconButton(icon: const Icon(Icons.remove_circle_outline, size: 20), onPressed: () => onUpdateQuantity(item, -1)),
                IconButton(icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.green), onPressed: () => onUpdateQuantity(item, 1)),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => onUpdateQuantity(item, -item.quantity)),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildTotalsDisplay(Vente tempVente) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          _rowTotal("Total Brut", tempVente.totalBrut, Colors.black87, 16),
          _rowTotal("Remise", tempVente.reductionPercent, Colors.red, 16),
          const Divider(),
          _rowTotal("NET À PAYER", tempVente.totalNet, Colors.green.shade800, 18, isBold: true),
        ],
      ),
    );
  }

  Widget _rowTotal(String label, double val, Color color, double size, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: size)),
        Text("${val.toStringAsFixed(0)} FC", style: TextStyle(fontSize: size, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget content}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const Divider(),
            content,
          ],
        ),
      ),
    );
  }
}