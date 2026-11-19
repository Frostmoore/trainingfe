/// 🌗 **Il semicerchio di un macro** — `plan_interfaccia.md` I3, 19/11/2026.
///
/// | Caso | Cosa difende |
/// |---|---|
/// | sotto l'obiettivo non dice niente in più | il «+» compare solo se si sfora |
/// | oltre l'obiettivo dice di quanto | A4.1: *«la barra non si ferma a fine corsa»* — l'arco sì, quindi lo dice un numero |
/// | senza obiettivo non inventa niente | *«uno zero inventato è peggio di un'assenza dichiarata»* |
/// | dentro il quadrato | 22/08: *«i macro devono essere dentro dei quadrati»* |
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/diary/ui/widgets/semicerchio_macro.dart';

void main() {
  Future<void> monta(WidgetTester tester, double grammi, double? obiettivo) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SemicerchioMacro(
              grammi: grammi,
              obiettivo: obiettivo,
              colore: Colors.teal,
            ),
          ),
        ),
      );

  group('il conto dello sforo', () {
    test('sotto o pari all’obiettivo non c’è sforo', () {
      expect(SemicerchioMacro.sforo(50, 100), isNull);
      expect(SemicerchioMacro.sforo(100, 100), isNull);
    });

    test('oltre, è quanto si è passati', () {
      expect(SemicerchioMacro.sforo(120, 100), 20);
    });

    test('senza obiettivo non si inventa', () {
      expect(SemicerchioMacro.sforo(120, null), isNull);
      expect(SemicerchioMacro.sforo(120, 0), isNull);
    });
  });

  testWidgets('sotto l’obiettivo non scrive niente in più', (tester) async {
    await monta(tester, 50, 100);

    expect(find.textContaining('+'), findsNothing);
  });

  testWidgets('oltre l’obiettivo dice di quanto, in rosso', (tester) async {
    await monta(tester, 120, 100);

    final testo = tester.widget<Text>(find.text('+20 g'));
    final errore = Theme.of(
      tester.element(find.byType(SemicerchioMacro)),
    ).colorScheme.error;

    expect(testo.style?.color, errore);
  });

  test('sta dentro i quadrati dei macro, non al loro posto', () {
    /*
     * 🔑 Il quadrato è la regola del 22/08; il semicerchio sta **dentro**. Se un
     * giorno qualcuno lo mettesse al posto del quadrato, questo lo dice.
     */
    final riepilogo = File(
      'lib/src/features/diary/ui/widgets/macro_summary.dart',
    ).readAsStringSync();

    final macro = riepilogo.substring(riepilogo.indexOf('class _Macro'));

    expect(macro, contains('SemicerchioMacro('));
    expect(macro, contains('borderRadius: BorderRadius.circular(Gap.radiusSm)'));
  });
}
