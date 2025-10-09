import 'package:factura/database/model_clients.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';

/// 📊 Panel pour afficher les Top 5 Clients
/// Utilise le modèle existant `Client`
/// `clientPurchases` = Map<Client.localId, totalAchats>
Widget buildTopClientsPanel({
  required List<Client> clients,
  required Map<int, int> clientPurchases,
  required void Function(int) goToSection, required List<ClientApercu> topClients,
}) {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🧑‍🤝‍🧑 En-tête du panel
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Clients (Top 5)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => goToSection(3),
                icon: const Icon(Icons.supervisor_account),
                label: const Text("Gérer les clients"),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 📝 Liste des top clients
          SizedBox(
            height: 200,
            child: clients.isEmpty
                ? const Center(
              child: Text(
                'Aucun client enregistré pour l’aperçu.',
                style: TextStyle(color: Colors.grey),
              ),
            )
                : ListView.separated(
              itemCount: clients.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final client = clients[index];
                final totalAchats = clientPurchases[client.localId] ?? 0;

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      '#${index + 1}',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(client.nomClient),
                  subtitle: Text(
                    'Téléphone: ${client.telephone ?? '—'}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '$totalAchats achats',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
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
