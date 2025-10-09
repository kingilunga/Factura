import 'package:flutter/material.dart';
import 'package:factura/DashboardAdmin/ajout_utilisateurs.dart';
import 'package:factura/DashboardAdmin/edite_utilisateurs.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/database/models_utilisateurs.dart';

class GestionUtilisateurs extends StatefulWidget {
  final Utilisateur currentUser; // rôle de l'utilisateur connecté

  const GestionUtilisateurs({super.key, required this.currentUser});

  @override
  State<GestionUtilisateurs> createState() => _GestionUtilisateursState();
}

class _GestionUtilisateursState extends State<GestionUtilisateurs> {
  final DatabaseService _dbService = DatabaseService.instance;
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
      final allUsers = await _dbService.getUtilisateurs();
      List<Utilisateur> filteredUsers;

      if (widget.currentUser.role == 'superadmin') {
        // SuperAdmin voit tout
        filteredUsers = allUsers;
      } else if (widget.currentUser.role == 'admin') {
        // Admin voit lui-même et les vendeurs
        filteredUsers = allUsers.where((u) {
          final isVendeur = u.role == 'vendeur';
          final isSelf = (u.localId != null && u.localId == widget.currentUser.localId)
              || u.email == widget.currentUser.email;
          return isVendeur || isSelf;
        }).toList();
      } else {
        // Vendeur voit seulement lui-même
        filteredUsers = allUsers.where((u) => u.email == widget.currentUser.email).toList();
      }

      setState(() {
        _utilisateurs = filteredUsers;
        _isLoading = false;
      });

      // Debug pour vérifier les utilisateurs visibles
      debugPrint("Current user: ${widget.currentUser.nom} (${widget.currentUser.role})");
      for (var u in filteredUsers) {
        debugPrint("Visible user: ${u.nom} (${u.role}, id=${u.localId})");
      }

    } catch (e) {
      print("Erreur lors du chargement des utilisateurs: $e");
      setState(() => _isLoading = false);
    }
  }


  void _navigateToAddUser() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AjoutUtilisateurs(
          // Admin peut créer uniquement des vendeurs
          defaultRole: widget.currentUser.role == 'admin' ? 'vendeur' : null,
        ),
      ),
    );

    if (result == true) _loadUtilisateurs();
  }

  Future<void> _deleteUser(int localId) async {
    final confirmed = await _confirmDeletion();
    if (confirmed) {
      try {
        await _dbService.deleteUser(localId);
        _loadUtilisateurs();
      } catch (e) {
        print("Erreur lors de la suppression de l'utilisateur: $e");
      }
    }
  }

  Future<bool> _confirmDeletion() async {
    return await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirmer la suppression"),
          content: const Text("Êtes-vous sûr de vouloir supprimer cet utilisateur?"),
          actions: <Widget>[
            TextButton(
              child: const Text("Annuler"),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text("Supprimer", style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre + bouton Ajouter
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
                  backgroundColor: Colors.indigo,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Liste des utilisateurs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black54),
            ),
          ),
          const SizedBox(height: 20),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _utilisateurs.isEmpty
              ? const Center(child: Text('Aucun utilisateur enregistré.'))
              : Expanded(
            child: ListView.builder(
              itemCount: _utilisateurs.length,
              itemBuilder: (context, index) {
                final user = _utilisateurs[index];

                final String initial = user.prenom?.isNotEmpty == true
                    ? user.prenom![0].toUpperCase()
                    : '?';
                final String fullName =
                    '${user.nom ?? ''} ${user.postNom ?? ''} ${user.prenom ?? ''}';
                final String subtitle =
                    '${user.email ?? 'Email manquant'} - Rôle: ${user.role}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  elevation: 2,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: user.role == 'admin'
                          ? Colors.red.shade400
                          : Colors.indigo.shade400,
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
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    EditeUtilisateurs(utilisateur: user),
                              ),
                            ).then((value) => _loadUtilisateurs());
                          },
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
