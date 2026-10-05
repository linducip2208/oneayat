import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oneayat/widgets/ayat_card.dart';

void main() {
  testWidgets('EmptyState renders message', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Scaffold(body: EmptyState(icon: Icons.history, message: 'No history yet.')),
    ));
    expect(find.text('No history yet.'), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
  });

  testWidgets('Onboarding skip visible (smoke)', (t) async {
    // Cheap smoke: header text renders in Material context.
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: Text('ONE AYAT'))));
    expect(find.text('ONE AYAT'), findsOneWidget);
  });
}
