/// 🌑 **La testata scura** — `plan_interfaccia.md` I1, 19/11/2026.
///
/// Ogni caso difende una delle ragioni per cui `TestataScura` è fatta così, e
/// che a guardarla sul telefono non si vedrebbero finché non si rompono:
///
/// | Caso | Cosa difende |
/// |---|---|
/// | il tema dentro è scuro | gli strumenti si ridisegnano da soli (§3.1) |
/// | i testi senza stile sono chiari | la trappola del `DefaultTextStyle` dello `Scaffold` |
/// | contiene un `IntestazioneApp` | la riga d'identità su tutte le pagine (R2) |
/// | l'avvertenza sta sopra gli strumenti | decisione D-2s/B (R3) |
/// | lo sfondo col telefono in chiaro | il colore delle tavole |
/// | lo sfondo col telefono in scuro | la testata non sparisce nel corpo scuro (R6) |
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/theme/app_theme.dart';
import 'package:training_companion/src/core/ui/intestazione_app.dart';
import 'package:training_companion/src/core/ui/testata_scura.dart';
import 'package:training_companion/src/features/onboarding/data/gym_branding.dart';

import 'aiuto/intestazione.dart';

void main() {
  Future<void> monta(
    WidgetTester tester,
    Widget testata, {
    ThemeMode modo = ThemeMode.light,
  }) async {
    final overrides = await intestazioneFinta();

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: AppTheme.light(GymBranding.neutral),
          darkTheme: AppTheme.dark(GymBranding.neutral),
          themeMode: modo,
          home: Scaffold(body: ListView(children: [testata])),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Color sfondoDellaTestata(WidgetTester tester) {
    final scatola = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(TestataScura),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );

    return (scatola.decoration as BoxDecoration).color!;
  }

  testWidgets('dentro la testata il tema è scuro, anche col telefono in chiaro', (
    tester,
  ) async {
    Brightness? dentro;

    await monta(
      tester,
      TestataScura(
        titolo: 'Diario',
        strumenti: Builder(
          builder: (context) {
            dentro = Theme.of(context).brightness;
            return const SizedBox(height: 10);
          },
        ),
      ),
    );

    expect(dentro, Brightness.dark);
  });

  testWidgets('un testo senza stile proprio è chiaro, non nero su nero', (
    tester,
  ) async {
    /*
     * 🚨 **La trappola che questo caso tiene chiusa**: il colore di un `Text`
     * senza stile viene dal `DefaultTextStyle`, e quello lo mette lo
     * `Scaffold` di fuori — scuro. Il `Theme` da solo non lo cambia.
     */
    await monta(tester, const TestataScura(strumenti: Text('prova')));

    final stile = DefaultTextStyle.of(tester.element(find.text('prova'))).style;

    expect(
      ThemeData.estimateBrightnessForColor(stile.color!),
      Brightness.light,
      reason: 'sul fondo quasi nero il testo deve essere chiaro',
    );
  });

  testWidgets('contiene un IntestazioneApp: la riga d’identità non si copia', (
    tester,
  ) async {
    await monta(tester, const TestataScura(titolo: 'Diario'));

    expect(
      find.descendant(
        of: find.byType(TestataScura),
        matching: find.byType(IntestazioneApp),
      ),
      findsOneWidget,
    );
  });

  testWidgets('l’avvertenza sta sopra gli strumenti', (tester) async {
    await monta(
      tester,
      const TestataScura(
        avvertenza: SizedBox(key: Key('avvertenza'), height: 20),
        strumenti: SizedBox(key: Key('strumenti'), height: 20),
      ),
    );

    final avvertenza = tester.getTopLeft(find.byKey(const Key('avvertenza')));
    final strumenti = tester.getTopLeft(find.byKey(const Key('strumenti')));

    expect(avvertenza.dy, lessThan(strumenti.dy));
  });

  testWidgets('col telefono in chiaro lo sfondo è il quasi nero delle tavole', (
    tester,
  ) async {
    await monta(tester, const TestataScura(titolo: 'Diario'));

    expect(sfondoDellaTestata(tester), TestataScura.sfondoInChiaro);
  });

  testWidgets('il seguito della testata è scuro e arrotondato come lei', (
    tester,
  ) async {
    /*
     * 🌑 I4: in Allenamento la testata sta ferma in alto e gli strumenti
     * scorrono in un seguito separato. Se il seguito non fosse scuro, o non
     * avesse il tema scuro, si vedrebbe un blocco chiaro attaccato a uno nero.
     */
    Brightness? dentro;

    await monta(
      tester,
      CodaDellaTestata(
        child: Builder(
          builder: (context) {
            dentro = Theme.of(context).brightness;
            return const SizedBox(height: 10);
          },
        ),
      ),
    );

    final scatola = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(CodaDellaTestata),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decorazione = scatola.decoration as BoxDecoration;

    expect(dentro, Brightness.dark);
    expect(decorazione.color, TestataScura.sfondoInChiaro);
    expect(
      decorazione.borderRadius,
      const BorderRadius.vertical(
        bottom: Radius.circular(TestataScura.raggio),
      ),
    );
  });

  testWidgets('col telefono in scuro la testata resta diversa dal corpo', (
    tester,
  ) async {
    await monta(
      tester,
      const TestataScura(titolo: 'Diario'),
      modo: ThemeMode.dark,
    );

    final corpo = Theme.of(
      tester.element(find.byType(Scaffold)),
    ).colorScheme.surface;

    expect(sfondoDellaTestata(tester), isNot(corpo));
  });
}
