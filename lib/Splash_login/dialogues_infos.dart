import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // INDISPENSABLE pour copier
import 'package:url_launcher/url_launcher.dart';

class DialoguesInfo {
  // 1. Fonction pour ouvrir les liens externes
  static Future<void> _lancerLien(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
  // 2. Fonction pour copier le texte (Le moteur du bouton de copie)
  static void _copier(BuildContext context, String texte) {
    Clipboard.setData(ClipboardData(text: texte));
    // Affiche une petite barre noire en bas pour confirmer la copie
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$texte copié !"),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void afficher(BuildContext context, {
    required String titre,
    required String message,
    required Color couleur,
    IconData? icone,
    String? imagePath,
    String? whatsappNumber,
    String? emailAddress,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 400, // Important pour la stabilité sur Windows
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- IMAGE ---
                  if (imagePath != null)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Image.asset(
                        imagePath,
                        height: 180,
                        width: 400,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(
                            height: 50,
                            color: Colors.grey[100],
                            child: const Icon(Icons.image_not_supported)
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(titre, style: TextStyle(color: couleur, fontWeight: FontWeight.bold, fontSize: 20)),
                        const SizedBox(height: 8),
                        Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700])),

                        const SizedBox(height: 20),
                        const Divider(height: 1),

                        // --- WHATSAPP ---
                        // --- SECTION WHATSAPP (IMAGE ASSET) ---
                        if (whatsappNumber != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Image.asset(
                              'assets/Icons/whatsapp-logo-icon.png', // Ton fichier image
                              width: 35,
                              height: 35,
                              // Si l'image n'est pas trouvée, on affiche un carré vert pour ne pas crash
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(width: 35, height: 35, color: Colors.green),
                            ),
                            title: Text("+$whatsappNumber", style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("WhatsApp - Cliquez pour discuter"),
                            onTap: () => _lancerLien("https://wa.me/$whatsappNumber"),
                            trailing: IconButton(
                              icon: Icon(Icons.copy, size: 20, color: Colors.blue),
                              onPressed: () => _copier(context, "+$whatsappNumber"),
                            ),
                          ),

                        // --- SECTION EMAIL (IMAGE ASSET) ---
                        if (emailAddress != null)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Image.asset(
                              'assets/Icons/email-app-icon.png', // Ton fichier image
                              width: 35,
                              height: 35,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(width: 35, height: 35, color: Colors.red),
                            ),
                            title: Text(emailAddress, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            subtitle: Text("Email - Cliquez pour écrire"),
                            onTap: () => _lancerLien("mailto:$emailAddress"),
                            trailing: IconButton(
                              icon: Icon(Icons.copy, size: 20, color: Colors.blue),
                              onPressed: () => _copier(context, emailAddress),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text("FERMER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}