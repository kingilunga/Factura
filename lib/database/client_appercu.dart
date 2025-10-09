class ClientApercu {
  final int id;
  final String nom;
  final String? telephone;
  final double totalVentes;

  ClientApercu({
    required this.id,
    required this.nom,
    this.telephone,
    required this.totalVentes,
  });

  factory ClientApercu.fromMap(Map<String, dynamic> map) {
    return ClientApercu(
      id: map['id'] as int,
      nom: map['nom'] as String,
      telephone: map['telephone'] as String?,
      totalVentes: (map['totalVentes'] as num).toDouble(),
    );
  }
}
