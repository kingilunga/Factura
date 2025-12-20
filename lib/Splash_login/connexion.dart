import 'package:factura/DashboardVendor/vendeurs_dashboard.dart';
import 'package:factura/Splash_login/dialogues_infos.dart';
import 'package:factura/Superadmin/SuperAdminDashboard.dart';
import 'package:flutter/material.dart';
import 'package:factura/database/database_service.dart';
import 'package:factura/Modeles/model_utilisateurs.dart';
import 'package:factura/DashboardAdmin/admin_dashboard.dart';

class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> with TickerProviderStateMixin {

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _motDePasseController = TextEditingController();

  final String _appIconPath = 'assets/images/Icon_FacturaVision.png';
  final String? _backgroundImagePath = 'assets/images/arrierephoto.jpg';
  final String? _commentImagePath = 'assets/images/Icon_FacturaVision.png';

  // 🔥 Animations Glow + Scale + Rotation
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;


  final DatabaseService _databaseService = DatabaseService.instance;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // ⭐️ AJUSTEMENT : Durée plus longue pour un effet plus lent et doux (5 secondes)
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // 5 secondes pour une "respiration" lente
    )..repeat(reverse: true);

    // ⭐️ AJUSTEMENT : Luminosité maximale (end) augmentée à 1.0 (ou 0.9) pour plus de visibilité,
    // mais on garde la courbe douce (Curves.slowMiddle).
    _glowAnimation = Tween<double>(begin: 0.1, end: 0.95).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.slowMiddle),
    );

    // ⭐️ AJUSTEMENT : Le scaling (redimensionnement) est subtil (de 1.0 à 1.05)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.slowMiddle),
    );

    // Rotation inchangée, pour rester subtile
    _rotationAnimation = Tween<double>(begin: 0, end: 0.05).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    _emailController.dispose();
    _motDePasseController.dispose();
    super.dispose();
  }
  // --- LOGIQUE DE CONNEXION (INCHANGÉE) ---
  void _login() async {
    final String email = _emailController.text.trim();
    final String motDePasse = _motDePasseController.text;

    setState(() { _errorMessage = null; });

    if (email.isEmpty || motDePasse.isEmpty) {
      setState(() { _errorMessage = "Veuillez remplir tous les champs."; });
      return;
    }

    try {
      Utilisateur? user = await _databaseService.findUserByEmailAndVerifyPassword(email, motDePasse);
      if (user != null) {
        // ... (Gestion des rôles inchangée)
        if (user.role == 'superadmin') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SuperAdminDashboard(user: user)));
        } else if (user.role == 'admin') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AdminDashboardPage(user: user)));
        } else if (user.role == 'vendeur') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VendeursDashboardPage(user: user)));
        }
      } else {
        setState(() { _errorMessage = "Email ou mot de passe incorrect."; });
      }
    } catch (e) {
      setState(() { _errorMessage = "Une erreur est survenue lors de la connexion."; });
      debugPrint("Erreur de connexion: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isWideScreen = screenWidth > 800;

    const Color primaryColor = Color(0xFF13132D);
    const Color accentColor = Color(0xFF3B82F6);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. --- IMAGE D'ARRIÈRE-PLAN ET VOILE ---
          if (_backgroundImagePath != null)
            Positioned.fill(
              child: Image.asset(_backgroundImagePath!, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) {
                return Container(color: primaryColor);
              },
              ),
            ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(isWideScreen ? 0.3 : 0.6),
            ),
          ),

          // 2. --- CONTENU PRINCIPAL (Split Screen ou Mobile) ---
          Center(
            child: isWideScreen
                ? _buildSplitScreenLayout(primaryColor, accentColor, screenHeight)
                : _buildMobileLayout(primaryColor, accentColor),
          ),

          // ⭐️ 3. --- BOUTONS UTILITAIRES (Centrés en bas) ---
          if (isWideScreen)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _buildUtilityButtons(),
              ),
            ),
        ],
      ),
    );
  }

  // ⭐️ NOUVEAU WIDGET pour gérer l'effet de survol et les info-bulles
  Widget _UtilityButton({
    required IconData icon,
    required String label,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white, // ⭐️ Couleur au clic
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ).copyWith(
          // ⭐️ EFFET DE SURVOL : Change la couleur quand la souris passe dessus
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.hovered)) {
              return Colors.yellowAccent; // Devient jaune au survol (ou blanc pur)
            }
            return Colors.white.withOpacity(0.7); // Blanc doux par défaut
          }),
        ),
        icon: Icon(
          icon,
          size: 20,
          // La couleur est gérée par le foregroundColor au-dessus
        ),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ⭐️ Mise à jour de la fonction pour utiliser le nouveau widget
  Widget _buildUtilityButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // ⭐️ CENTRAGE HORIZONTAL
      children: [
        _UtilityButton(
          icon: Icons.help_outline,
          label: 'Aides',
          tooltip: 'Recevoir de l\'aide sur l\'utilisation de l\'application',
            onPressed: () {
              DialoguesInfo.afficher(
                context,
                titre: "Aides",
                message: "Voici comment utiliser l'application...",
                icone: Icons.help_outline, // L'icône s'affichera
                couleur: Colors.blue,
              );
            }
        ),
        const SizedBox(width: 30), // Espace accru entre les boutons
        _UtilityButton(
          icon: Icons.info_outline,
          label: 'À propos',
          tooltip: 'À propos de l\'application Factura Vision',
          onPressed: () {
            DialoguesInfo.afficher(
              context,
              titre: "Factura Vision",
              message: "Version 1.0.0\n\n"
                  "Solution de gestion commerciale intelligente.\n"
                  "Développée pour optimiser votre facturation et le suivi de vos stocks.\n\n"
                  "© 2025 Factura Vision Team",
              icone: Icons.info_outline,
              couleur: Colors.orange,
              // imagePath: 'assets/images/logo_app.png', // Tu pourras décommenter ça quand tu auras un logo
            );
          },
        ),
        const SizedBox(width: 30),
        _UtilityButton(
          icon: Icons.contact_mail_outlined,
          label: 'Nous contacter',
          tooltip: 'Contacter l\'équipe de développement',
            onPressed: () {
              DialoguesInfo.afficher(
                context,
                titre: "Support Technique",
                message: "Pour vous assister, répondre à votre question ou besoin des nos services, contactez-nous à travers les canaux ci-dessous  :",
                imagePath: 'assets/images/familia.png', // La photo remplacera l'icône
                whatsappNumber: "243821672206",
                emailAddress: "support@facturavision.com",
                couleur: Colors.green,
              );
            }
        ),
      ],
    );
  }

  // ⭐️ Layout pour les grands écrans (Split Screen ajusté - Largeurs conservées)
  Widget _buildSplitScreenLayout(Color primaryColor, Color accentColor, double screenHeight) {
    // ⭐️ Hauteur réduite : Utilise 75% de la hauteur de l'écran pour laisser de l'espace en bas
    final double containerHeight = screenHeight * 0.75;

    // ⭐️ Largeurs ajustées (400px pour éviter l'overflow)
    const double commentPanelWidth = 400; // Largeur accrue pour les commentaires
    const double loginPanelWidth = 400;    // Largeur ajustée pour le formulaire (corrige l'overflow)

    return Container(
      width: commentPanelWidth + loginPanelWidth,
      height: containerHeight, // ⭐️ Hauteur réduite appliquée
      margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- CÔTÉ GAUCHE : Commentaires/Panneau d'information (Largeur accrue) ---
          Container(
            width: commentPanelWidth, // ⭐️ Nouvelle largeur
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              // ⭐️ AJUSTEMENT 1 : Centrage horizontal des éléments
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 1),
                // ⭐️ Le titre doit être centré
                const Text(
                  'Factura Vision',
                  textAlign: TextAlign.center, // Centrage du texte
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 15),
                // ⭐️ La description doit être centrée
                Text(
                  'Bienvenue sur votre portail de gestion commerciale. Connectez-vous pour piloter vos ventes, gérer vos stocks et consulter vos analyses de performance en temps réel.',
                  textAlign: TextAlign.center, // Centrage du texte
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.5,
                  ),
                ),
                const Spacer(flex: 2),
                // ⭐️ AJOUT DE L'IMAGE ANIMÉE AVEC EFFETS
                if (_commentImagePath != null)
                  Center( // Center garantit le centrage de l'icône, même si CrossAxisAlignment.center est déjà là
                    child: AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotationAnimation.value, // Rotation subtile (~5%)
                          child: Transform.scale(
                            scale: _scaleAnimation.value, // Agrandissement / réduction fluide
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withOpacity(_glowAnimation.value), // Glow dynamique
                                    // ⭐️ AJUSTEMENT 2 : Augmentation du Blur Radius pour plus de douceur
                                    blurRadius: 50, // Passé de 35 à 50
                                    spreadRadius: 2, // Passé de 1 à 2 pour l'étaler
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  _commentImagePath!,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                // Fin de l'emplacement d'image
                const SizedBox(height: 90),
                // ⭐️ Le footer est maintenant centré
                Text(
                  'By bht service © Tout droit reservé. Model King2025.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.yellowAccent.withOpacity(0.8),
                    height: 1,
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
          // --- CÔTÉ DROIT : Formulaire de Connexion (Largeur réduite) ---
          //SizedBox(
            //width: loginPanelWidth, // On garde la largeur de 400
            // SUPPRIME LE PADDING ICI
           // child: _buildLoginForm(primaryColor, accentColor, isWideScreen: true),
          //),
          // --- CÔTÉ DROIT : Formulaire de Connexion (Windows) ---
          Expanded(
            child: _buildLoginForm(primaryColor, accentColor, isWideScreen: true),
          ),
        ],
      ),
    );
  }

  // ⭐️ Layout pour les petits écrans (INCHANGÉ)
  Widget _buildLoginForm(Color primaryColor, Color accentColor, {required bool isWideScreen}) {
    return Card(
      clipBehavior: Clip.antiAlias, // Obligatoire pour couper l'image sur les bords arrondis
      elevation: 0,
      margin: EdgeInsets.zero, // Supprime les marges de la carte pour coller aux bords
      shape: const RoundedRectangleBorder(
        // Arrondis seulement sur les coins extérieurs droits pour Windows
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Container(
        width: double.infinity,
        height: double.infinity, // ⭐️ REMPLIT TOUTE LA HAUTEUR
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: const AssetImage('assets/images/shopjeadot.png'),
            fit: BoxFit.cover, // L'image s'étire pour tout couvrir
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.55),
              BlendMode.darken,
            ),
          ),
        ),
        child: Center( // Centre le formulaire au milieu de l'image
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Bienvenue chez nous",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 10, color: Colors.black)],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 35),

                // --- EMAIL ---
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Adresse e-mail',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 16),

                // --- MOT DE PASSE ---
                TextField(
                  controller: _motDePasseController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.lock),
                  ),
                  onSubmitted: (_) => _login(),
                ),

                const SizedBox(height: 24),

                // --- BOUTON CONNEXION ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Se connecter', style: TextStyle(fontSize: 18)),
                  ),
                ),

                // --- LIEN MOT DE PASSE OUBLIÉ ---
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // --- BOUTONS DE TEST ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTestButton(context, 'SA', primaryColor),
                    _buildTestButton(context, 'ADM', Colors.green[700]!),
                    _buildTestButton(context, 'VEN', Colors.blue[700]!),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ⭐️ Fonction pour construire les boutons de test (INCHANGÉE)
  Widget _buildTestButton(BuildContext context, String role, Color color) {
    Utilisateur tempUser;
    if (role == 'SA') {
      tempUser = Utilisateur(nom: 'Root', prenom: 'SuperAdmin', email: 'root@factura.com', motDePasse: '', role: 'superadmin', postnom: '', telephone: '');
    } else if (role == 'ADM') {
      tempUser = Utilisateur(nom: 'Admin', prenom: 'Super', email: 'admin@factura.com', motDePasse: '', role: 'admin', postnom: '', telephone: '');
    } else {
      tempUser = Utilisateur(nom: 'Vendeur', prenom: 'Jean', email: 'vendeur@factura.com', motDePasse: '', role: 'vendeur', postnom: '', telephone: '');
    }
    return ElevatedButton(
      onPressed: () {
        if (role == 'SA') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => SuperAdminDashboard(user: tempUser)));
        } else if (role == 'ADM') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AdminDashboardPage(user: tempUser)));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => VendeursDashboardPage(user: tempUser)));
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: Text(role, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildMobileLayout(Color primaryColor, Color accentColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500), // Largeur max pour rester joli
          child: _buildLoginForm(primaryColor, accentColor, isWideScreen: false),
        ),
      ),
    );
  }
}