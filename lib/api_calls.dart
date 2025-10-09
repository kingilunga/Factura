// lib/api_calls/fetch_taux.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Appelle l'API de la BCC pour récupérer le taux USD -> CDF
Future<double?> fetchTauxBCC() async {
  try {
    final response = await http.get(Uri.parse('https://www.bcc.cd/api/taux-de-change'));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      // Adapte cette ligne selon la structure exacte de la réponse JSON
      // Ici on suppose que la clé est "USD_CDF"
      return (data['USD_CDF'] != null) ? data['USD_CDF'].toDouble() : null;
    } else {
      print('Erreur API BCC : status ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('Erreur lors de l\'appel API BCC : $e');
    return null;
  }
}

/// Sauvegarde le taux localement pour éviter un appel API à chaque fois
Future<void> saveTaux(double taux) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('tauxUSD', taux);
}

/// Récupère le taux sauvegardé localement
Future<double?> getSavedTaux() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble('tauxUSD');
}

/// Récupère le taux, priorisant l'API, sinon prend la valeur locale ou un défaut
Future<double> getTaux() async {
  double defaultTaux = 2500.0;

  // Essayer l'API
  double? apiTaux = await fetchTauxBCC();
  if (apiTaux != null) {
    await saveTaux(apiTaux);
    return apiTaux;
  }

  // Sinon utiliser le taux sauvegardé
  double? savedTaux = await getSavedTaux();
  if (savedTaux != null) return savedTaux;

  // Sinon valeur par défaut
  return defaultTaux;
}
