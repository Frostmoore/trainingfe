/// 🧱 **I mattoni del corpo delle pagine** — `plan_interfaccia.md` I1,
/// 19/11/2026.
///
/// | Caso | Cosa difende |
/// |---|---|
/// | due tessere diverse, alte uguali | il colpo d'occhio delle coppie (§3.3) |
/// | il titolo di sezione in maiuscolo | si scrive normale, si mostra in maiuscolo |
/// | freccia avanti spenta | regola 3b-O.1b.2: niente giorni futuri |
/// | il testo riporta a oggi | un tocco invece di tante frecce |
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/ui/barra_della_data.dart';
import 'package:training_companion/src/core/ui/sezioni.dart';

void main() {
  Future<void> monta(WidgetTester tester, Widget figlio) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(children: [figlio]),
      ),
    ),
  );

  testWidgets('una coppia di tessere diverse è alta uguale', (tester) async {
    await monta(
      tester,
      const Coppia(
        sinistra: Tessera(
          key: Key('sx'),
          etichetta: 'Passi',
          child: SizedBox(height: 20),
        ),
        destra: Tessera(
          key: Key('dx'),
          etichetta: 'Sonno',
          child: SizedBox(height: 140),
        ),
      ),
    );

    final sinistra = tester.getSize(find.byKey(const Key('sx'))).height;
    final destra = tester.getSize(find.byKey(const Key('dx'))).height;

    expect(sinistra, destra);
  });

  testWidgets('il titolo di sezione si mostra in maiuscolo', (tester) async {
    await monta(
      tester,
      const TitoloDiSezione('Energia di oggi', nota: 'ore 13:30'),
    );

    expect(find.text('ENERGIA DI OGGI'), findsOneWidget);
    expect(find.text('ore 13:30'), findsOneWidget);
  });

  testWidgets('senza onDopo la freccia avanti è spenta', (tester) async {
    await monta(
      tester,
      BarraDellaData(testo: 'Oggi · 19 novembre', onPrima: () {}),
    );

    final avanti = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
    );

    expect(avanti.onPressed, isNull);
  });

  testWidgets('toccare il testo chiama onTesto', (tester) async {
    var tornatoAOggi = false;

    await monta(
      tester,
      BarraDellaData(
        testo: 'Lunedì 17 novembre',
        onPrima: () {},
        onDopo: () {},
        onTesto: () => tornatoAOggi = true,
      ),
    );

    await tester.tap(find.text('Lunedì 17 novembre'));

    expect(tornatoAOggi, isTrue);
  });
}
