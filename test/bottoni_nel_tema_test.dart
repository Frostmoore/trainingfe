import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/theme/app_theme.dart';
import 'package:training_companion/src/features/onboarding/data/gym_branding.dart';

/// I pulsanti del tema, dentro una riga.
///
/// 🚨 **Il test che avrebbe evitato due schermate bianche.**
///
/// Il tema imponeva a ogni pulsante `minimumSize: Size.fromHeight(48)`, che vale
/// `Size(double.infinity, 48)`: una **larghezza minima infinita**. Dentro una
/// `Column` o una lista non si nota — riempie e basta, che era l'intenzione — ma
/// dentro una `Row` con un figlio flessibile `RenderFlex` misura prima i figli
/// non flessibili con larghezza **illimitata**: il pulsante chiede infinito e il
/// layout lancia.
///
/// E un'eccezione durante il layout non lascia un pulsante storto: fa **sparire
/// l'intera schermata**. Il riepilogo di fine allenamento era completamente
/// bianco, e la riga «Riprendi» portava giù con sé la scheda Allenamento.
void main() {
  Widget conTema(Widget figlio) => MaterialApp(
    theme: AppTheme.light(GymBranding.neutral),
    home: Scaffold(body: figlio),
  );

  /// La disposizione che rompeva: un campo che si allarga e un pulsante
  /// accanto. È quella del riepilogo (calorie + «Salva») e della riga
  /// dell'allenamento in corso (testo + «Riprendi»).
  testWidgets(
    'un FilledButton accanto a un Expanded non fa esplodere il layout',
    (tester) async {
      await tester.pumpWidget(
        conTema(
          Row(
            children: [
              const Expanded(child: TextField()),
              FilledButton(onPressed: () {}, child: const Text('Salva')),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Salva'), findsOneWidget);
    },
  );

  testWidgets('e nemmeno un OutlinedButton', (tester) async {
    await tester.pumpWidget(
      conTema(
        Row(
          children: [
            const Expanded(child: Text('Allenamento in corso')),
            OutlinedButton(onPressed: () {}, child: const Text('Riprendi')),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  /// ⚠️ Il vincolo che conta resta: 48 px è la soglia sotto la quale un
  /// bersaglio diventa difficile da centrare col pollice.
  testWidgets('il bersaglio resta alto almeno 48', (tester) async {
    await tester.pumpWidget(
      conTema(
        Align(
          alignment: Alignment.topLeft,
          child: FilledButton(onPressed: () {}, child: const Text('X')),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  /// Chi vuole tutta la larghezza la chiede: continua a funzionare.
  testWidgets('a tutta larghezza si ottiene ancora, dicendolo', (tester) async {
    await tester.pumpWidget(
      conTema(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Concludi')),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final larghezza = tester.getSize(find.byType(FilledButton)).width;

    expect(larghezza, tester.getSize(find.byType(Scaffold)).width);
  });
}
