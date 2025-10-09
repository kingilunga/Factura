import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

// Constantes de couleur (assurez-vous qu'elles correspondent au dashboard)
const Color kPrimaryColor = Color(0xFF1565C0);
const Color kAccentColor = Color(0xFFFFB300);
const Color kBackgroundColor = Color(0xFFF5F5F5);
const Color kConsoleBackground = Color(0xFF1E1E1E); // Fond sombre pour la console

// --- MODÈLES ET LOGIQUE DE DONNÉES ---

enum LogType { info, warning, error, success }

class LogEntry {
  final DateTime timestamp;
  final String action;
  final String user;
  final LogType type;

  LogEntry({
    required this.timestamp,
    required this.action,
    required this.user,
    required this.type,
  });

  // Pour l'affichage formaté dans la console
  String get formattedMessage {
    final time = "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
    final typeStr = type.toString().split('.').last.toUpperCase().padRight(7);
    return "[$time] [$typeStr] $user | $action";
  }
}

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final List<LogEntry> _logs = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Nous conservons la simulation live
    _startSimulatedLogs();
  }

  // Génère un LogEntry aléatoire
  LogEntry _generateRandomLog() {
    final type = LogType.values[_random.nextInt(LogType.values.length)];
    String action;
    String user = 'utilisateur.${_random.nextInt(5) + 1}';

    switch (type) {
      case LogType.success:
        action = "Opération DB réussie : Sauvegarde complète.";
        user = 'SYSTEM';
        break;
      case LogType.warning:
        action = "Tentative de connexion échouée (user: inconnu).";
        break;
      case LogType.error:
        action = "ERREUR FATALE: La licence #4001 est expirée et bloque l'accès.";
        user = 'SYSTEM';
        break;
      case LogType.info:
        action = "Mise à jour d'une configuration pour la licence #$_random.";
        break;
      default:
        action = "Événement de log simulé.";
    }

    return LogEntry(
      timestamp: DateTime.now(),
      action: action,
      user: user,
      type: type,
    );
  }

  void _startSimulatedLogs() {
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      setState(() {
        _logs.insert(0, _generateRandomLog()); // Ajout en haut
        // Limiter la taille pour ne pas surcharger la mémoire
        if (_logs.length > 50) {
          _logs.removeLast();
        }
      });
      // Faire un petit délai avant de scroller pour s'assurer que l'UI a eu le temps de se construire
      Future.delayed(const Duration(milliseconds: 50), _scrollToBottom);
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      // Pour une console live, on scroll au maximum de l'extension
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Color _getLogColor(LogType type) {
    switch (type) {
      case LogType.error:
        return Colors.redAccent;
      case LogType.warning:
        return kAccentColor; // Jaune-Orange
      case LogType.success:
        return Colors.greenAccent;
      case LogType.info:
      default:
        return Colors.cyanAccent; // Couleur vive pour un fond sombre
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _clearLogs() {
    setState(() => _logs.clear());
  }

  @override
  Widget build(BuildContext context) {
    // Note: Pas de Scaffold/AppBar car c'est géré par SuperAdminDashboard
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Bouton de Contrôle (Barre d'actions)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          color: kPrimaryColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Console de logs en direct",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              ElevatedButton.icon(
                onPressed: _clearLogs,
                icon: const Icon(Icons.cleaning_services, size: 18),
                label: const Text("Vider la console"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  foregroundColor: kConsoleBackground, // Texte sombre sur bouton clair
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 5,
                ),
              ),
            ],
          ),
        ),

        // Console de Logs
        Expanded(
          child: Container(
            color: kConsoleBackground,
            padding: const EdgeInsets.all(8.0),
            child: _logs.isEmpty
                ? const Center(
              child: Text(
                "En attente d'événements...",
                style: TextStyle(color: Colors.white70, fontFamily: 'Courier', fontSize: 16),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              itemCount: _logs.length,
              // Affichage des logs du plus ancien au plus récent (du bas vers le haut)
              reverse: true,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Text(
                  log.formattedMessage,
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 13,
                    color: _getLogColor(log.type),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
