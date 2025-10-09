import 'package:factura/Superadmin/superadmin_edite_users.dart';
import 'package:factura/Superadmin/superadmin_users_add.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/models_utilisateurs.dart';


class SuperadminUsersPage extends StatefulWidget {
  const SuperadminUsersPage({super.key});

  @override
  State<SuperadminUsersPage> createState() => _SuperadminUsersPageState();
}

class _SuperadminUsersPageState extends State<SuperadminUsersPage> {
  final DatabaseService _dbService = DatabaseService.instance;
  List<Utilisateur> _utilisateurs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUtilisateurs();
  }

  Future<void> _loadUtilisateurs() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _dbService.getAllUtilisateurs(); // Récupère tous les utilisateurs
      setState(() {
        _utilisateurs = users;
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur lors du chargement des utilisateurs : $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(int localId) async {
    final confirmed = await _confirmDeletion();
    if (confirmed) {
      try {
        await _dbService.deleteUser(localId);
        _loadUtilisateurs();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la suppression : $e")),
        );
      }
    }
  }

  Future<bool> _confirmDeletion() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmer la suppression"),
        content: const Text("Êtes-vous sûr de vouloir supprimer cet utilisateur ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Annuler"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _navigateToAddUser() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SuperAdminUserAdd()),
    );
    if (result == true) _loadUtilisateurs();
  }

  void _navigateToEditUser(Utilisateur user) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SuperAdminEditUser(user: user, utilisateur: user,), // paramètre nommé 'user'
      ),
    );

    if (result == true) {
      _loadUtilisateurs(); // Recharge la liste après édition
    }
  }



  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Gestion des utilisateurs',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _navigateToAddUser,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Ajouter', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _utilisateurs.isEmpty
              ? const Center(child: Text('Aucun utilisateur enregistré.'))
              : Expanded(
            child: ListView.builder(
              itemCount: _utilisateurs.length,
              itemBuilder: (context, index) {
                final user = _utilisateurs[index];
                final initial = user.prenom?.isNotEmpty == true
                    ? user.prenom![0].toUpperCase()
                    : '?';
                final fullName =
                    '${user.nom ?? ''} ${user.postNom ?? ''} ${user.prenom ?? ''}';
                final subtitle = '${user.email ?? 'Email manquant'} - Rôle: ${user.role}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user.role == 'superadmin'
                          ? Colors.green
                          : user.role == 'admin'
                          ? Colors.red
                          : Colors.indigo,
                      child: Text(
                        initial,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(fullName),
                    subtitle: Text(subtitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _navigateToEditUser(user),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteUser(user.localId ?? 0),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
