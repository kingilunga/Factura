import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
// NOTE: Vous devrez ajuster ces imports à vos modèles existants !
// Assurez-vous que ces fichiers existent :
import 'package:factura/Modeles/model_clients.dart';
import 'package:factura/Modeles/model_produits.dart';
import 'package:factura/Modeles/model_ventes.dart';
import 'package:factura/Modeles/model_proforma.dart';

// Modèle de support pour ce fichier
class CartItem {
  Produit produit;
  int quantity;
  CartItem({required this.produit, this.quantity = 1});
}

// --- INTERFACE DU WIDGET RÉUTILISABLE ---

class PanierFormulaire extends StatelessWidget {
  // Données requises
  final Client? selectedClient;
  final List<CartItem> cart;
  final double currentExchangeRate;
  final String deviseSelected;

  // Fonctions d'action requises
  final void Function(Produit) onAddProduct;
  final void Function(CartItem, int) onUpdateQuantity;
  final void Function(String) onFilterProducts;
  final List<Produit> filteredProducts;
  final bool showProductSuggestions;
  final double suggestionMaxHeight;
  final TextEditingController productSearchController;
  final String modePaiement;

  // Fonctions de validation (Action finale)
  final bool canValidate;
  final Future<void> Function() onValidateVente; // Pour Vente ou Proforma (action principale)
  final Future<void> Function()? onValidateProForma; // Optionnel (pour ajouter le bouton Proforma à côté de Vente)

  const PanierFormulaire({
    super.key,
    required this.selectedClient,
    required this.cart,
    required this.currentExchangeRate,
    required this.deviseSelected,
    required this.onAddProduct,
    required this.onUpdateQuantity,
    required this.onFilterProducts,
    required this.filteredProducts,
    required this.showProductSuggestions,
    required this.suggestionMaxHeight,
    required this.productSearchController,
    required this.modePaiement,
    required this.canValidate,
    required this.onValidateVente,
    this.onValidateProForma,
  });

  // --- LOGIQUE INTERNE (Extrait de EnregistrementVente) ---

  // 💰 Conversion du Prix de Vente USD en FC
  double getPriceVenteFC(Produit produit) {
    return (produit.prix ?? 0.0) * (currentExchangeRate > 0.0 ? currentExchangeRate : 1.0);
  }

  // Calculs
  double get total => cart.fold(0, (sum, item) => sum + getPriceVenteFC(item.produit) * item.quantity);
  double get discountAmount => total * 0.06;
  double get netToPay => total - discountAmount;

  // Création d'une vente temporaire (pour affichage des totaux)
  // ⚠️ Supposons que Vente est un modèle général qui peut être utilisé pour l'affichage des totaux
  Vente createTempVente() {
    return Vente(
      venteId: 'TEMP',
      dateVente: DateTime.now().toIso8601String(),
      clientLocalId: selectedClient!.localId ?? 0,
      vendeurNom: 'Vendeur',
      modePaiement: modePaiement,
      deviseTransaction: deviseSelected,
      tauxDeChange: currentExchangeRate,
      totalBrut: total,
      reductionPercent: discountAmount,
      totalNet: netToPay,
      statut: 'brouillon',
    );
  }

  // Widget pour le tableau du panier
  Widget _buildCartTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 18,
        headingRowColor: MaterialStateProperty.all(Colors.blueGrey.shade50),
        columns: [
          const DataColumn(label: Text("Produit", style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text("Prix ($deviseSelected)", style: const TextStyle(fontWeight: FontWeight.bold))),
          const DataColumn(label: Text("Stock", style: TextStyle(fontWeight: FontWeight.bold))),
          const DataColumn(label: Text("Qté", style: TextStyle(fontWeight: FontWeight.bold))),
          const DataColumn(label: Text("S.total (FC)", style: TextStyle(fontWeight: FontWeight.bold))),
          const DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: cart.map((item) {
          final stockDispo = item.produit.quantiteActuelle ?? 0;
          final stockColor = stockDispo <= 0 ? Colors.red : (stockDispo < 5 ? Colors.orange : Colors.green);

          final priceUnit = deviseSelected == 'USD'
              ? item.produit.prix ?? 0.0
              : getPriceVenteFC(item.produit);

          final sousTotalFC = getPriceVenteFC(item.produit) * item.quantity;
          final isOutOfStock = stockDispo <= 0;

          return DataRow(cells: [
            DataCell(Text(item.produit.nom ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),

            DataCell(Text("${priceUnit.toStringAsFixed(deviseSelected == 'USD' ? 2 : 0)} F")),

            DataCell(Text(stockDispo.toString(), style: TextStyle(color: stockColor, fontWeight: FontWeight.bold))),
            DataCell(Text("${item.quantity}")),

            DataCell(Text("${sousTotalFC.toStringAsFixed(0)} FC", style: const TextStyle(fontWeight: FontWeight.bold))),

            DataCell(Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 32, height: 32, child: IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: () => onUpdateQuantity(item, -1))),
                SizedBox(width: 32, height: 32, child: IconButton(icon: const Icon(Icons.add, size: 18), onPressed: isOutOfStock || item.quantity >= stockDispo ? null : () => onUpdateQuantity(item, 1), color: isOutOfStock || item.quantity >= stockDispo ? Colors.grey : Colors.green)),
                SizedBox(width: 32, height: 32, child: IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => onUpdateQuantity(item, -item.quantity))),
              ],
            )),
          ]);
        }).toList(),
      ),
    );
  }

  // WIDGET pour afficher les totaux
  Widget _buildTotalsDisplay(Vente tempVente) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Total Brut
        _buildTotalLine("Total Brut", tempVente.totalBrut, Colors.blueGrey.shade700, false),
        // Réduction
        _buildTotalLine("Réduction (6%)", tempVente.reductionPercent, Colors.red, false),
        const Divider(color: Colors.black, thickness: 1.5, height: 10),
        // Total Net
        _buildTotalLine("TOTAL À PAYER", tempVente.totalNet, Colors.green.shade700, true),
      ],
    );
  }

  Widget _buildTotalLine(String label, double amount, Color color, bool isBig) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '$label :',
            style: TextStyle(
              fontSize: isBig ? 20 : 16,
              fontWeight: isBig ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${amount.toStringAsFixed(0)} FC',
            style: TextStyle(
              fontSize: isBig ? 22 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // WIDGET pour les suggestions de produits
  Widget _buildProductSuggestions(double maxHeight) {
    if (!showProductSuggestions || filteredProducts.isEmpty) {
      return const SizedBox.shrink();
    }
    final height = filteredProducts.length > 6 ? maxHeight : filteredProducts.length * 56.0;

    return Container(
      constraints: BoxConstraints(maxHeight: height),
      margin: const EdgeInsets.only(top: 8),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: filteredProducts.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 8, endIndent: 8),
        itemBuilder: (context, idx) {
          final p = filteredProducts[idx];
          final stockDispo = p.quantiteActuelle ?? 0;
          final stockColor = stockDispo <= 0 ? Colors.red : (stockDispo < 5 ? Colors.orange : Colors.green);
          final stockText = stockDispo <= 0 ? 'RUPTURE' : 'Stock: $stockDispo';
          final isOutOfStock = stockDispo <= 0;
          final priceUSDText = p.prix?.toStringAsFixed(0) ?? '0';

          return ListTile(
            title: Text(p.nom ?? ''),
            subtitle: Text('Prix: $priceUSDText USD - $stockText', style: TextStyle(color: stockColor, fontWeight: FontWeight.bold)),
            trailing: isOutOfStock ? const Icon(Icons.warning, color: Colors.red) : null,
            onTap: isOutOfStock ? null : () => onAddProduct(p),
            tileColor: isOutOfStock ? Colors.grey[100] : null,
          );
        },
      ),
    );
  }

  // WIDGET pour envelopper les sections
  Widget _buildSectionCard({required String title, required Widget content}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueGrey.shade700)),
            const Divider(height: 20, color: Colors.blueGrey),
            content,
          ],
        ),
      ),
    );
  }

  // WIDGET pour les boutons de validation (ancre fixe)
  Widget buildActionButtons() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, -5))],
      ),
      padding: const EdgeInsets.only(top: 15, bottom: 25, left: 16, right: 16),
      width: double.infinity,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Bouton 1: Aperçu Facture (A4)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text("Aperçu Facture", overflow: TextOverflow.ellipsis),
                    onPressed: canValidate ? onValidateVente : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15), textStyle: const TextStyle(fontSize: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                ),
                const SizedBox(width: 16),

                // Bouton 2: Pro-Forma (Affiché si la fonction est fournie)
                if (onValidateProForma != null) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.description),
                      label: const Text("ENREGISTRER PRO-FORMA", overflow: TextOverflow.ellipsis),
                      onPressed: canValidate ? onValidateProForma : null,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15), textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 6),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],

                // Bouton 3: Valider et Imprimer (Action Principale)
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text("VALIDER ET IMPRIMER LA VENTE", overflow: TextOverflow.ellipsis),
                    onPressed: canValidate ? onValidateVente : null,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET BUILD PRINCIPAL ---

  @override
  Widget build(BuildContext context) {
    final tempVente = canValidate ? createTempVente() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. SECTION PRODUITS
        _buildSectionCard(
          title: 'Sélectionner des produits',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: productSearchController,
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Rechercher un produit',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)))
                      ),
                      onChanged: onFilterProducts,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: Colors.blueGrey.shade100),
                    child: IconButton(icon: Icon(Icons.qr_code_scanner, color: Colors.blueGrey.shade700), onPressed: () {/* TODO: scanner */}, tooltip: "Scanner le code-barres"),
                  ),
                ],
              ),
              _buildProductSuggestions(suggestionMaxHeight),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. SECTION PANIER et TOTAUX
        _buildSectionCard(
          title: 'Panier et Totaux',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // PANIER TABLEAU
              cart.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Le panier est vide. Ajoutez des produits.", style: TextStyle(fontSize: 16, color: Colors.grey))))
                  : _buildCartTable(),

              const SizedBox(height: 15),
              // RAPPEL TOTAUX
              canValidate
                  ? _buildTotalsDisplay(tempVente!)
                  : const Center(child: Text("Ajouter des articles pour voir les totaux.", style: TextStyle(fontSize: 16, color: Colors.grey))),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // 3. Barre d'actions fixe (appelée dans la page parente)
      ],
    );
  }
}