import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/profile/ui/edit_profile_screen.dart';

/// La tendina del profilo non sfora — 13/08/2026.
///
/// 🚨 **Perché serve un widget test.** Il difetto riferito dal committente —
/// *«il livello sedentario va in overflow nel campo dove appare»* — è un
/// `RenderFlex overflowed`: non lo prende nessun test sui modelli, perché il
/// dato è giusto ed è il **disegno** a rompersi.
///
/// ⚠️ È la stessa forma del primo widget test dell'app (`rest_bar_widget_test`):
/// un overflow non è solo una striscia gialla, è un layout che smette di
/// funzionare.
void main() {
  const livelli = {
    'sedentary': 'Sedentario (lavoro da fermo, niente allenamenti)',
    'light': 'Leggermente attivo (1-2 allenamenti a settimana)',
    'moderate': 'Moderatamente attivo (3-4 a settimana)',
    'active': 'Molto attivo (5-6 a settimana)',
    'very_active': 'Estremamente attivo (ogni giorno, o due sedute)',
  };

  /// Uno schermo **stretto** apposta: l'overflow si vede solo quando lo spazio
  /// manca davvero, e un test su una larghezza generosa non proverebbe niente.
  Widget suUnoSchermoStretto(Widget figlio) => MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 320, child: figlio)),
    ),
  );

  testWidgets('l\'etichetta lunga non manda in overflow il campo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      suUnoSchermoStretto(
        TendinaProfilo(
          etichetta: 'Quanto ti muovi',
          icona: Icons.directions_run_rounded,
          voci: livelli,
          scelta: 'sedentary',
          onCambio: (_) {},
        ),
      ),
    );

    // 🚨 `pumpWidget` non fallisce da solo su un overflow: l'eccezione finisce
    // in `takeException()`, e va guardata esplicitamente.
    expect(tester.takeException(), isNull);
  });

  /// 🚨 **Il campo chiuso mostra il nome intero, non i puntini.**
  ///
  /// Con il solo `isExpanded` il testo verrebbe troncato — «Sedentario (lavoro
  /// da fer…» — che è brutto ma soprattutto inutile. Il `selectedItemBuilder`
  /// mostra la parte prima della parentesi: il **nome del livello**, per intero.
  testWidgets('chiuso mostra il nome breve, per intero', (tester) async {
    await tester.pumpWidget(
      suUnoSchermoStretto(
        TendinaProfilo(
          etichetta: 'Quanto ti muovi',
          icona: Icons.directions_run_rounded,
          voci: livelli,
          scelta: 'sedentary',
          onCambio: (_) {},
        ),
      ),
    );

    expect(find.text('Sedentario'), findsOneWidget);
    expect(find.text(livelli['sedentary']!), findsNothing);
  });

  /// 💡 Aperta invece si legge tutto: è l'unico momento in cui la spiegazione
  /// serve davvero, cioè quando si sta scegliendo.
  testWidgets('aperta mostra la spiegazione per intero', (tester) async {
    await tester.pumpWidget(
      suUnoSchermoStretto(
        TendinaProfilo(
          etichetta: 'Quanto ti muovi',
          icona: Icons.directions_run_rounded,
          voci: livelli,
          scelta: 'sedentary',
          onCambio: (_) {},
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.text(livelli['moderate']!), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  /// ⚠️ Gli obiettivi **non hanno la parentesi**: la scorciatoia che accorcia
  /// il testo non deve mangiarsi l'etichetta quando non c'è niente da tagliare.
  testWidgets('un\'etichetta senza parentesi resta intera', (tester) async {
    await tester.pumpWidget(
      suUnoSchermoStretto(
        TendinaProfilo(
          etichetta: 'Obiettivo',
          icona: Icons.flag_outlined,
          voci: const {
            'lose_slow': 'Dimagrimento graduale',
            'maintain': 'Mantenimento',
          },
          scelta: 'lose_slow',
          onCambio: (_) {},
        ),
      ),
    );

    expect(find.text('Dimagrimento graduale'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// 🚨 **Il carattere ingrandito** — 13/08/2026.
  ///
  /// Il test qui sopra gira a scala 1.0, che è l'unica in cui una voce su due
  /// righe **ci sta per un pelo**: `DropdownButtonFormField` dà agli item del
  /// menu un'altezza fissa (`kMinInteractiveDimension`, 48 px) e due righe a
  /// 16 sp ne misurano 48 esatti. ⚠️ Chi ha alzato la dimensione del testo nelle
  /// impostazioni di Android le vede sforare.
  ///
  /// 💡 1.3 non è un numero scelto per far passare il test: è dentro la forbice
  /// che Android offre di serie (fino a 1.3 senza accessibilità, oltre con).
  testWidgets('a carattere ingrandito il menu aperto non sfora', (
    tester,
  ) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
        child: suUnoSchermoStretto(
          TendinaProfilo(
            etichetta: 'Quanto ti muovi',
            icona: Icons.directions_run_rounded,
            voci: livelli,
            scelta: 'sedentary',
            onCambio: (_) {},
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull, reason: 'il campo chiuso');

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull, reason: 'il menu aperto');
  });

  /// ⚠️ Le larghezze vere dei telefoni in circolazione, non una a caso.
  ///
  /// Lo Xiaomi di prova sta a 360 dp meno i 16 di padding per lato = **328**.
  /// I 320 usati sopra sono già più stretti del vero; qui si scende a **280**,
  /// che è il caso peggiore realistico (schermo piccolo **e** finestra divisa).
  for (final larghezza in [280.0, 328.0, 360.0]) {
    testWidgets('nessuno sforo a ${larghezza.toInt()} px di larghezza', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: larghezza,
                  child: TendinaProfilo(
                    etichetta: 'Quanto ti muovi',
                    icona: Icons.directions_run_rounded,
                    voci: livelli,
                    scelta: 'very_active',
                    onCambio: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  }

  /// 🚨 Una scelta che il server non conosce più non deve far esplodere la
  /// tendina: `DropdownButton` va in assert se il valore non è fra gli item.
  testWidgets('una scelta sconosciuta non rompe la tendina', (tester) async {
    await tester.pumpWidget(
      suUnoSchermoStretto(
        TendinaProfilo(
          etichetta: 'Obiettivo',
          icona: Icons.flag_outlined,
          voci: const {'maintain': 'Mantenimento'},
          // Il vocabolario vecchio, su un profilo non ancora migrato.
          scelta: 'lose_weight',
          onCambio: (_) {},
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
