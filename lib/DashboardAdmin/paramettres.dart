import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_service.dart'; // Assure-toi que DatabaseService existe

class ParametresAdminPage extends StatefulWidget {
  const ParametresAdminPage({super.key});

  @override
  State<ParametresAdminPage> createState() => _ParametresAdminPageState();
}

class _ParametresAdminPageState extends State<ParametresAdminPage> {
  // --- Variables des paramètres ---
  bool syncAuto = false;
  bool darkMode = false;
  String langue = 'Français';
  bool notifStockFaible = true;
  bool notifVente = true;
  bool notifSauvegarde = false;
  double tva = 16.0;
  String nomEntreprise = 'Factura Vision';
  String logoPath = '';

  // --- Taux de change ---
  final TextEditingController _tauxCtrl = TextEditingController();
  String _deviseSelected = 'USD';
  final List<String> _devises = ['USD', 'EUR', 'CDF', 'FCFA'];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadTauxChange();
  }

  // --- Chargement des préférences ---
  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      syncAuto = prefs.getBool('syncAuto') ?? false;
      darkMode = prefs.getBool('darkMode') ?? false;
      langue = prefs.getString('langue') ?? 'Français';
      notifStockFaible = prefs.getBool('notifStockFaible') ?? true;
      notifVente = prefs.getBool('notifVente') ?? true;
      notifSauvegarde = prefs.getBool('notifSauvegarde') ?? false;
      tva = prefs.getDouble('tva') ?? 16.0;
      nomEntreprise = prefs.getString('nomEntreprise') ?? 'Factura Vision';
      logoPath = prefs.getString('logoPath') ?? '';
    });
  }

  // --- Sauvegarde préférences simples ---
  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String) await prefs.setString(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  // --- Sélection du logo ---
  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      setState(() {
        logoPath = result.files.single.path!;
      });
      _savePref('logoPath', logoPath);
    }
  }

  // --- Chargement du taux depuis la base ---
  Future<void> _loadTauxChange() async {
    final dbService = DatabaseService.instance;
    double taux = await dbService.fetchTauxChange(_deviseSelected);
    setState(() {
      _tauxCtrl.text = taux.toString();
    });
  }

  // --- Sauvegarde du taux ---
  Future<void> _saveTauxChange() async {
    final dbService = DatabaseService.instance;
    final taux = double.tryParse(_tauxCtrl.text);
    if (taux != null) {
      await dbService.upsertTauxChange(_deviseSelected, taux);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taux de change enregistré avec succès')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez saisir un taux valide')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Paramètres administrateur")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // 🧩 SECTION GÉNÉRAL
          _sectionTitle("Général"),
          SwitchListTile(
            title: const Text("Synchronisation automatique"),
            value: syncAuto,
            onChanged: (v) => setState(() {
              syncAuto = v;
              _savePref('syncAuto', v);
            }),
          ),
          SwitchListTile(
            title: const Text("Mode sombre"),
            value: darkMode,
            onChanged: (v) => setState(() {
              darkMode = v;
              _savePref('darkMode', v);
            }),
          ),
          ListTile(
            title: const Text("Langue"),
            trailing: DropdownButton<String>(
              value: langue,
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    langue = v;
                    _savePref('langue', v);
                  });
                }
              },
              items: const [
                DropdownMenuItem(value: 'Français', child: Text('Français')),
                DropdownMenuItem(value: 'Anglais', child: Text('Anglais')),
              ],
            ),
          ),

          const Divider(),

          // 👤 SECTION COMPTE & SÉCURITÉ
          _sectionTitle("Comptes et Sécurité"),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Changer le mot de passe"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.group),
            title: const Text("Gérer les utilisateurs"),
            onTap: () {},
          ),
          SwitchListTile(
            title: const Text("Double authentification (2FA)"),
            value: false,
            onChanged: (v) {},
          ),

          const Divider(),

          // --- SECTION TAUX DE CHANGE ---
          _sectionTitle("Taux de change"),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _deviseSelected,
                  decoration: const InputDecoration(labelText: 'Devise'),
                  items: _devises.map((e) =>
                      DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _deviseSelected = v;
                        _loadTauxChange(); // charge le taux correspondant
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _tauxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Taux'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.save, color: Colors.green),
                onPressed: _saveTauxChange,
              ),
            ],
          ),

          const Divider(),

          // 🏷️ SECTION GESTION & CONFIG
          _sectionTitle("Gestion et Configuration"),
          ListTile(
            title: const Text("Nom de l’entreprise"),
            subtitle: Text(nomEntreprise),
            trailing: const Icon(Icons.edit),
            onTap: () async {
              final ctrl = TextEditingController(text: nomEntreprise);
              await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Nom de l’entreprise"),
                  content: TextField(controller: ctrl),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler")),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          nomEntreprise = ctrl.text;
                          _savePref('nomEntreprise', nomEntreprise);
                        });
                        Navigator.pop(context);
                      },
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            title: const Text("Logo de l’entreprise"),
            subtitle: Text(logoPath.isEmpty ? "Aucun logo sélectionné" : logoPath),
            trailing: const Icon(Icons.image),
            onTap: _pickLogo,
          ),
          ListTile(
            title: const Text("Taux de TVA (%)"),
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
                          if (val != null) {
                            setState(() {
                              tva = val;
                              _savePref('tva', tva);
                            });
                          }
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

          const Divider(),

          // 🔔 SECTION NOTIFICATIONS
          _sectionTitle("Notifications"),
          SwitchListTile(
            title: const Text("Alerte de stock faible"),
            value: notifStockFaible,
            onChanged: (v) => setState(() {
              notifStockFaible = v;
              _savePref('notifStockFaible', v);
            }),
          ),
          SwitchListTile(
            title: const Text("Notification de nouvelle vente"),
            value: notifVente,
            onChanged: (v) => setState(() {
              notifVente = v;
              _savePref('notifVente', v);
            }),
          ),
          SwitchListTile(
            title: const Text("Rappel de sauvegarde"),
            value: notifSauvegarde,
            onChanged: (v) => setState(() {
              notifSauvegarde = v;
              _savePref('notifSauvegarde', v);
            }),
          ),

          const Divider(),

          // 🧰 SECTION MAINTENANCE
          _sectionTitle("Maintenance"),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text("Vider le cache local"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.sync),
            title: const Text("Réinitialiser la base locale"),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text("Vérifier les mises à jour"),
            onTap: () {},
          ),

          const Divider(),

          // ℹ️ SECTION À PROPOS
          _sectionTitle("À propos"),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text("Factura Vision – v1.0.0"),
            subtitle: Text("Système de facturation et de gestion des ventes."),
          ),
          const ListTile(
            leading: Icon(Icons.mail_outline),
            title: Text("Assistance technique"),
            subtitle: Text("support@factura-vision.com"),
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
