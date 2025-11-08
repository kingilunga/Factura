import 'package:factura/Modeles/model_clients.dart';
import 'package:factura/Modeles/model_produits.dart';

class CartItem {
  final Produit produit;
  int quantity;

  CartItem({required this.produit, this.quantity = 1});
}

class Facture {
  final Client client;
  final List<CartItem> items;
  final double total;
  final double discount;
  final double netToPay;
  final DateTime date;

  Facture({
    required this.client,
    required this.items,
    required this.total,
    required this.discount,
    required this.netToPay,
    required this.date,
  });

  // Méthode pour générer un résumé simple
  String summary() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('Facture pour: ${client.nomClient}');
    buffer.writeln('Date: ${date.toLocal()}');
    buffer.writeln('Produits:');
    for (var item in items) {
      buffer.writeln(
          '- ${item.produit.nom} x${item.quantity} : ${(item.produit.prix ?? 0) * item.quantity} F');
    }
    buffer.writeln('Total: $total F');
    buffer.writeln('Rabais: $discount F');
    buffer.writeln('Net à payer: $netToPay F');
    return buffer.toString();
  }
}
