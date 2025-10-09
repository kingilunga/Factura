import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart'; // Assure-toi que le chemin est correct

void main() {
  testWidgets('Test de fumée : chargement de l\'app', (WidgetTester tester) async {
    // Construire l'application
    await tester.pumpWidget(const MyApp());

    // Vérifier la présence du logo ou du texte de démarrage
    expect(find.text('Factura Vision'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long), findsOneWidget);

    // Vérifier la présence du CircularProgressIndicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
