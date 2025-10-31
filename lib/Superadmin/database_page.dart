import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DatabasePage extends StatefulWidget {
  const DatabasePage({super.key});

  @override
  State<DatabasePage> createState() => _DatabasePageState();
}

class _DatabasePageState extends State<DatabasePage> {
  final DatabaseService _dbService = DatabaseService.instance;
  String _dbSize = '---';
  String _dbPath = '';

  @override
  void initState() {
    super.initState();
    _loadDbInfo();
  }

  Future<void> _loadDbInfo() async {
    try {
      final db = await _dbService.database;
      final path = db.path;
      final file = File(path);
      final size = await file.length();
      setState(() {
        _dbPath = path;
        _dbSize = '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
      });
    } catch (e) {
      debugPrint('Erreur lors de la récupération des infos DB: $e');
    }
  }

  Future<void> _backupDB() async {
    try {
      final db = await _dbService.database;
      final dbFile = File(db.path);

      final directory = await getApplicationDocumentsDirectory();
      final backupPath = '${directory.path}/backup_factura.db';

      await dbFile.copy(backupPath);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Backup créé: $backupPath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur backup: $e')),
      );
    }
  }

  Future<void> _restoreDB() async {
    try {
      final db = await _dbService.database;
      final dbFile = File(db.path);

      final directory = await getApplicationDocumentsDirectory();
      final backupPath = '${directory.path}/backup_factura.db';

      final backupFile = File(backupPath);
      if (await backupFile.exists()) {
        await backupFile.copy(dbFile.path);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Base restaurée avec succès')),
        );
        _loadDbInfo();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠ Aucun backup trouvé')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur restauration: $e')),
      );
    }
  }

  Future<void> _purgeDB() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer la purge'),
        content: const Text(
            'Voulez-vous vraiment vider toutes les tables SAUF la table des utilisateurs ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _dbService.clearAllExceptUsers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🧹 Base purgée (utilisateurs conservés)')),
      );
      _loadDbInfo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gestion de la base de données',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _backupDB,
                icon: const Icon(Icons.backup),
                label: const Text('Backup'),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: _restoreDB,
                icon: const Icon(Icons.restore),
                label: const Text('Restauration'),
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                onPressed: _purgeDB,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Purge sauf users'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Informations sur la base:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('📍 Emplacement : $_dbPath'),
          Text('📦 Taille : $_dbSize'),
        ],
      ),
    );
  }
}
