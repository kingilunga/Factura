// Modèle de données pour enregistrer le taux de change USD vers CDF
// Ce taux est crucial pour calculer le coût réel des produits.
class TauxDeChange {
  final int? id; // L'identifiant dans la base de données SQLite
  final double taux; // Le taux USD vers CDF (ex: 1 USD = 2500 CDF)
  final DateTime dateEnregistrement; // La date à laquelle ce taux a été enregistré

  TauxDeChange({
    this.id,
    required this.taux,
    required this.dateEnregistrement,
  });

  // Convertit un TauxDeChange en Map pour l'enregistrement dans la base de données SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taux': taux,
      'dateEnregistrement': dateEnregistrement.toIso8601String(),
    };
  }

  // Crée un objet TauxDeChange à partir d'une Map (lecture depuis la base de données)
  factory TauxDeChange.fromMap(Map<String, dynamic> map) {
    return TauxDeChange(
      id: map['id'] as int?,
      taux: map['taux'] as double,
      // Stocké comme une chaîne ISO 8601, donc nous devons la re-parser en DateTime
      dateEnregistrement: DateTime.parse(map['dateEnregistrement'] as String),
    );
  }
}