import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/models_utilisateurs.dart';
import 'dart:math';

class PasswordsPage extends StatefulWidget {
  const PasswordsPage({super.key});

  @override
  State<PasswordsPage> createState() => _PasswordsPageState();
}

class _PasswordsPageState extends State<PasswordsPage> {
  final DatabaseService _db = DatabaseService.instance;
  List<Utilisateur> _utilisateurs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUtilisateurs();
  }

  Future<void> _loadUtilisateurs() async {
    setState(() => _isLoading = true);
    try {
      final users = await _db.getUtilisateurs();
      setState(() {
        _utilisateurs = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement des utilisateurs: $e')),
      );
    }
  }

  String _generateSecurePassword() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#%*?';
    final rand = Random.secure();
    return List.generate(12, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> _resetPassword(Utilisateur user) async {
    final newPassword = _generateSecurePassword();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Réinitialiser le mot de passe'),
        content: Text(
            'Voulez-vous vraiment réinitialiser le mot de passe de ${user.nom} ?\n\n'
                'Nouveau mot de passe proposé :\n\n$newPassword'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.updatePassword(user.localId!, newPassword);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mot de passe réinitialisé pour ${user.nom}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _manualResetPassword(Utilisateur user) async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouveau mot de passe pour ${user.nom}'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Entrer le nouveau mot de passe',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmer')),
        ],
      ),
    );

    if (confirm == true && controller.text.isNotEmpty) {
      try {
        await _db.updatePassword(user.localId!, controller.text);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mot de passe modifié pour ${user.nom}')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des mots de passe'),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUtilisateurs,
            tooltip: 'Rafraîchir la liste',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _utilisateurs.isEmpty
          ? const Center(child: Text('Aucun utilisateur trouvé'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _utilisateurs.length,
        itemBuilder: (context, index) {
          final user = _utilisateurs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.lock),
              title: Text('${user.nom ?? ''} ${user.prenom ?? ''}'),
              subtitle: Text('Rôle: ${user.role}'),
              trailing: PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'auto') _resetPassword(user);
                  if (val == 'manual') _manualResetPassword(user);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'auto',
                    child: Row(
                      children: [
                        Icon(Icons.lock_reset, color: Colors.indigo),
                        SizedBox(width: 8),
                        Text('Réinitialiser automatiquement'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'manual',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Définir manuellement'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
