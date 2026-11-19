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
      home: Scaffold(body: Column(children: [figlio])),
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

  /// 🆕 I9, 19/11/2026 — visto sul giro col carattere a 2,0: «ABBONAMENTO»
  /// in mezza larghezza andava a capo a metà parola. ⚠️ Si misura l'altezza
  /// dell'etichetta: deve essere quella di **una** riga, come un'etichetta
  /// corta nella tessera accanto.
  testWidgets('col carattere grande l\'etichetta resta su una riga', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, figlio) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: figlio!,
        ),
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Coppia(
                  sinistra: Tessera(
                    etichetta: 'Palestra',
                    child: SizedBox(height: 10),
                  ),
                  destra: Tessera(
                    etichetta: 'Abbonamento',
                    child: SizedBox(height: 10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    /*
     * ⚠️ **Contro l'altezza di una riga, non contro l'altra etichetta**: la
     * prima stesura confrontava le due etichette, e passava anche col difetto,
     * perché nel font dei test va a capo **anche** «PALESTRA» — 64 px tutte e
     * due. Una riga di `labelSmall` (11) col carattere a 2 è alta 32.
     */
    const unaRiga = 33.0;
    final corta = tester.getSize(find.text('PALESTRA')).height;
    final lunga = tester.getRect(find.text('ABBONAMENTO'));

    expect(corta, lessThanOrEqualTo(unaRiga));
    expect(lunga.height, lessThanOrEqualTo(unaRiga));
    // ⚠️ E resta dentro la sua tessera, non sborda.
    final tessera = tester.getRect(
      find.ancestor(of: find.text('ABBONAMENTO'), matching: find.byType(Card)),
    );
    expect(lunga.right, lessThanOrEqualTo(tessera.right));
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
