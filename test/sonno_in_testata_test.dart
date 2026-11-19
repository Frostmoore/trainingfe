import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:training_companion/src/core/ui/sezioni.dart';
import 'package:training_companion/src/core/ui/testata_scura.dart';
import 'package:training_companion/src/features/health/sessioni_di_sonno.dart';
import 'package:training_companion/src/features/sleep/sleep_controller.dart';
import 'package:training_companion/src/features/sleep/ui/sleep_screen.dart';

import 'aiuto/intestazione.dart';

/// 🌙 **Il Sonno con la testata scura** — `plan_interfaccia.md` I8,
/// 19/11/2026.
///
/// 🚨 Quello che difende:
/// - **I8.D2** — le ore, l'orario e l'ipnogramma stanno in testata, e
///   l'ipnogramma ha **larghezze proporzionali alla durata** (C14): un risveglio
///   di 2 minuti e uno di 40 devono vedersi diversi.
/// - **I8.D3** — i riposi brevi restano **separati e visibili**: hanno la loro
///   sezione, e la frase che dice che non entrano nella notte.
void main() {
  setUpAll(() => initializeDateFormatting('it'));

  final inizio = DateTime(2026, 11, 18, 23, 0);

  SleepBlock blocco(int daMinuto, int minuti, int fase, String nome) =>
      SleepBlock(
        from: inizio.add(Duration(minutes: daMinuto)),
        to: inizio.add(Duration(minutes: daMinuto + minuti)),
        stage: fase,
        label: nome,
        minutes: minuti,
      );

  // 💡 Una notte di 7 ore con due risvegli: uno da 2 minuti, uno da 40.
  final notte = SleepNight(
    night: DateTime(2026, 11, 19),
    from: inizio,
    to: inizio.add(const Duration(hours: 7)),
    asleepMinutes: 378,
    awakeMinutes: 42,
    lightMinutes: 240,
    deepMinutes: 60,
    remMinutes: 78,
    deepPct: 16,
    remPct: 21,
    ratings: const {},
    overall: 'ok',
    hypnogram: [
      blocco(0, 100, 2, 'Leggero'),
      blocco(100, 2, 1, 'Sveglio'),
      blocco(102, 60, 3, 'Profondo'),
      blocco(162, 40, 1, 'Sveglio'),
      blocco(202, 78, 4, 'REM'),
      blocco(280, 140, 2, 'Leggero'),
    ],
  );

  Future<void> apri(
    WidgetTester tester, {
    List<SessioneSonno> pisolini = const [],
  }) async {
    tester.view.physicalSize = const Size(1080, 4400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await intestazioneFinta(),
          sleepProvider.overrideWith((ref) async => notte),
          pisoliniProvider.overrideWith((ref) async => pisolini),
        ],
        child: const MaterialApp(home: SleepScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('ore, orario e ipnogramma stanno nel seguito scuro', (
    tester,
  ) async {
    await apri(tester);

    final testata = find.byType(CodaDellaTestata);

    expect(
      find.descendant(of: testata, matching: find.text(notte.durata)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: testata, matching: find.text('23:00 → 06:00')),
      findsOneWidget,
    );
    // I nomi delle righe accanto al grafico.
    for (final nome in ['Sveglio', 'REM', 'Leggero', 'Profondo']) {
      expect(
        find.descendant(of: testata, matching: find.text(nome)),
        findsOneWidget,
        reason: nome,
      );
    }
  });

  testWidgets('un risveglio di 40 minuti è venti volte più largo di uno di 2', (
    tester,
  ) async {
    await apri(tester);

    // Le bande dell'ipnogramma sono `ColoredBox` dentro la testata.
    final bande = tester
        .widgetList<ColoredBox>(
          find.descendant(
            of: find.byType(CodaDellaTestata),
            matching: find.byType(ColoredBox),
          ),
        )
        .toList();

    final sveglio = <double>[];
    for (final b in bande) {
      if (b.color == const Color(0xFFE5564A)) {
        sveglio.add(tester.getSize(find.byWidget(b)).width);
      }
    }

    expect(sveglio, hasLength(2));
    expect(sveglio[1] / sveglio[0], closeTo(20, 0.5));
  });

  testWidgets('le fasi sono quattro tessere, a coppie', (tester) async {
    await apri(tester);

    expect(find.text('LE FASI'), findsOneWidget);
    expect(find.byType(Coppia), findsNWidgets(2));
    for (final nome in ['PROFONDO', 'REM', 'LEGGERO', 'SVEGLIO']) {
      expect(
        find.ancestor(of: find.text(nome), matching: find.byType(Tessera)),
        findsOneWidget,
        reason: nome,
      );
    }
  });

  testWidgets(
    'i riposi brevi hanno la loro sezione, e non entrano nella notte',
    (tester) async {
      await apri(
        tester,
        pisolini: [
          SessioneSonno(
            inizio: DateTime(2026, 11, 18, 14, 10),
            fine: DateTime(2026, 11, 18, 14, 35),
            eNotte: false,
          ),
        ],
      );

      expect(find.text('RIPOSI BREVI'), findsOneWidget);
      expect(find.textContaining('non entrano nel totale'), findsOneWidget);
      // ⛔ La durata della notte non cambia: i 25 minuti non si sommano.
      expect(find.text(notte.durata), findsOneWidget);
    },
  );

  testWidgets('senza riposi brevi non c\'è nemmeno il titolo', (tester) async {
    await apri(tester);

    expect(find.text('RIPOSI BREVI'), findsNothing);
  });
}
