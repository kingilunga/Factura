import 'package:factura/Superadmin/logs_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // --- Préférences ---
  bool darkMode = false;
  bool devMode = false;
  bool verboseLogging = false;
  bool twoFA = false;

  // --- Informations système ---
  String appVersion = 'v1.0.0';
  String dbVersion = '1.0.0';
  String localStoragePath = '/storage/emulated/0/FacturaVision';
  double tva = 16.0;
  String currentUser = 'SuperAdmin';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      darkMode = prefs.getBool('darkMode') ?? false;
      devMode = prefs.getBool('devMode') ?? false;
      verboseLogging = prefs.getBool('verboseLogging') ?? false;
      twoFA = prefs.getBool('twoFA') ?? false;
      tva = prefs.getDouble('tva') ?? 16.0;
    });
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  Future<void> _resetLocalDB() async {
    // Ici tu peux appeler ta méthode de reset DB
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Base locale réinitialisée !')),
    );
  }

  Future<void> _clearCache() async {
    // Ici tu peux vider le cache local
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache local vidé !')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Paramètres SuperAdmin")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle("Général"),
          SwitchListTile(
            title: const Text("Mode sombre"),
            value: darkMode,
            onChanged: (v) {
              setState(() => darkMode = v);
              _savePref('darkMode', v);
            },
          ),
          SwitchListTile(
            title: const Text("Mode développeur"),
            value: devMode,
            onChanged: (v) {
              setState(() => devMode = v);
              _savePref('devMode', v);
            },
          ),
          SwitchListTile(
            title: const Text("Verbose logging"),
            value: verboseLogging,
            onChanged: (v) {
              setState(() => verboseLogging = v);
              _savePref('verboseLogging', v);
            },
          ),
          const Divider(),

          _sectionTitle("Sécurité"),
          SwitchListTile(
            title: const Text("Double authentification (2FA)"),
            value: twoFA,
            onChanged: (v) {
              setState(() => twoFA = v);
              _savePref('twoFA', v);
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Changer mot de passe SuperAdmin"),
            onTap: () {
              // Ouvre modal de modification mot de passe
            },
          ),
          const Divider(),

          _sectionTitle("Maintenance"),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text("Voir les logs internes"),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsPage()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text("Vider le cache local"),
            onTap: _clearCache,
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text("Réinitialiser la base locale"),
            onTap: _resetLocalDB,
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text("Vérifier les mises à jour"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Vérification des mises à jour en cours...")),
              );
            },
          ),
          const Divider(),

          _sectionTitle("Informations Système"),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text("Version de l'application"),
            subtitle: Text(appVersion),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text("Version de la base"),
            subtitle: Text(dbVersion),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text("Chemin stockage local"),
            subtitle: Text(localStoragePath),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Utilisateur courant"),
            subtitle: Text(currentUser),
          ),
          ListTile(
            leading: const Icon(Icons.percent),
            title: const Text("Taux TVA (%)"),
            subtitle: Text(tva.toStringAsFixed(1)),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final ctrl = TextEditingController(text: tva.toString());
                await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text("Modifier le taux de TVA"),
                    content: TextField(
                      controller: ctrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(suffixText: "%"),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                      TextButton(
                        onPressed: () {
                          final val = double.tryParse(ctrl.text);
                          if (val != null) setState(() => tva = val);
                          Navigator.pop(context);
                        },
                        child: const Text("Enregistrer"),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Text(title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
  );
}
