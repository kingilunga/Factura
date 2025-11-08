import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/Modeles/model_utilisateurs.dart';

class SuperAdminUserAdd extends StatefulWidget {
  final String defaultRole; // rôle par défaut

  const SuperAdminUserAdd({super.key, this.defaultRole = 'vendeur'});

  @override
  State<SuperAdminUserAdd> createState() => _SuperAdminUserAddState();
}

class _SuperAdminUserAddState extends State<SuperAdminUserAdd> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _postNomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late String _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.defaultRole;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _postNomController.dispose();
    _prenomController.dispose();
    _telephoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      final newUser = Utilisateur(
        nom: _nomController.text,
        postnom: _postNomController.text,
        prenom: _prenomController.text,
        telephone: _telephoneController.text,
        email: _emailController.text,
        motDePasse: _passwordController.text,
        role: _selectedRole,

      );

      final dbService = DatabaseService.instance;

      try {
        await dbService.insertUser(newUser);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur ajouté avec succès !')),
        );
        Navigator.pop(context, true); // retourne true pour reload
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ajout : $e')),
        );
      }
    }
  }

  Widget _buildTextFormField(
      TextEditingController controller, String label, IconData icon,
      {bool isEmail = false, bool isPassword = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[200],
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez entrer le $label.';
        }
        if (isEmail && !value.contains('@')) {
          return 'Veuillez entrer une adresse e-mail valide.';
        }
        return null;
      },
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: 'Rôle',
        prefixIcon: const Icon(Icons.work),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[200],
      ),
      value: _selectedRole,
      items: const [
        DropdownMenuItem(value: 'superadmin', child: Text('SuperAdmin')),
        DropdownMenuItem(value: 'admin', child: Text('Admin')),
        DropdownMenuItem(value: 'vendeur', child: Text('Vendeur')),
      ],
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedRole = newValue;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un utilisateur'),
        backgroundColor: const Color(0xFF13132D),
        foregroundColor: Colors.lightBlueAccent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Informations personnelles',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF13132D)),
              ),
              const SizedBox(height: 16),
              _buildTextFormField(_nomController, 'Nom', Icons.person),
              const SizedBox(height: 16),
              _buildTextFormField(_postNomController, 'Post-nom', Icons.person),
              const SizedBox(height: 16),
              _buildTextFormField(_prenomController, 'Prénom', Icons.person),
              const SizedBox(height: 16),
              _buildTextFormField(_telephoneController, 'Téléphone', Icons.phone),
              const SizedBox(height: 16),
              const Text(
                'Informations de connexion',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF13132D)),
              ),
              const SizedBox(height: 16),
              _buildTextFormField(_emailController, 'Adresse E-mail', Icons.email,
                  isEmail: true),
              const SizedBox(height: 16),
              _buildTextFormField(_passwordController, 'Mot de passe', Icons.lock,
                  isPassword: true),
              const SizedBox(height: 16),
              _buildRoleDropdown(),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.person_add),
                label: const Text('Ajouter l\'utilisateur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF13132D),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
