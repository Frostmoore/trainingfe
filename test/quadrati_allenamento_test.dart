import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/dashboard/ui/widgets/today_cards.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';

/// Gli allenamenti in quadrati, quattro per riga — 22/08/2026.
///
/// ══ 🚨 PERCHÉ QUESTO TEST ESISTE ══════════════════════════════════════════
///
/// 📌 Il committente: *«gli allenamenti li vorrei in dei quadrati, 4 per riga,
/// massimo 8»*.
///
/// ⚠️ **«Quattro per riga» è la classe di difetto che questo progetto continua a
/// incontrare**: una cosa che compila, passa l'analizzatore e a schermo ne fa
/// tre. È successo il giorno stesso, nella scheda sopra: cinque voci larghe 76
/// px fisse davano tre sopra e una sotto, e nessuno strumento lo diceva.
///
/// 🚨 Un `Wrap` con larghezze **calcolate** ha lo stesso rischio del `Wrap` con
/// larghezze fisse: basta un pixel di troppo — un margine dimenticato, uno
/// `spacing` cambiato — e il quarto quadrato va a capo. ⛔ L'unico modo di
/// saperlo è **misurare le posizioni vere** dopo aver disegnato.
void main() {
  setUpAll(() => initializeDateFormatting('it'));

  /// Un allenamento dell'orologio, che è il caso più povero: nessuna seduta
  /// dell'app dietro, solo un blocco di tempo e delle calorie.
  VoceStorico voce(int giorno, {int? kcal}) => VoceStorico(
    sedute: const [],
    dalPolso: [
      AllenamentoDaOrologio(
        id: giorno,
        fonte: 'com.google.android.apps.fitness',
        tipo: 'STRENGTH_TRAINING',
        iniziatoIl: DateTime(2026, 8, giorno, 18),
        finitoIl: DateTime(2026, 8, giorno, 19),
        kcal: kcal,
        nascosto: false,
        staccato: false,
      ),
    ],
  );

  /// Disegna la griglia dentro una larghezza precisa, come dentro la scheda.
  Future<void> disegna(
    WidgetTester tester,
    List<VoceStorico> voci, {
    double larghezza = 360,
  }) async {
    // ⚠️ La scheda ha 16 px di margine per lato: la griglia non vede mai la
    // larghezza dello schermo, ma quella dentro la scheda.
    tester.view.physicalSize = Size(larghezza, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: GrigliaAllenamenti(voci: voci),
          ),
        ),
      ),
    );
  }

  testWidgets('quattro allenamenti stanno tutti sulla stessa riga', (
    tester,
  ) async {
    await disegna(tester, [for (var g = 17; g <= 20; g++) voce(g, kcal: 320)]);

    final quadrati = tester
        .widgetList<QuadratoAllenamento>(find.byType(QuadratoAllenamento))
        .toList();
    expect(quadrati, hasLength(4));

    /*
     * 🚨 **La riga si misura, non si deduce.** Quattro quadrati esistono anche
     * quando sono tre sopra e uno sotto: la differenza sta nella `y`, e questa
     * è l'unica asserzione che la vede.
     */
    final y = find
        .byType(QuadratoAllenamento)
        .evaluate()
        .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy)
        .toSet();

    expect(
      y,
      hasLength(1),
      reason:
          'quattro quadrati su una riga sola: una sola coordinata verticale',
    );
  });

  testWidgets('anche a 280 px restano quattro per riga', (tester) async {
    // ⚠️ Il telefono più stretto che sosteniamo. Con larghezze fisse qui ne
    // entravano due, ed era il difetto di prima.
    await disegna(tester, [
      for (var g = 17; g <= 20; g++) voce(g, kcal: 200),
    ], larghezza: 280);

    final y = find
        .byType(QuadratoAllenamento)
        .evaluate()
        .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dy)
        .toSet();

    expect(y, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('otto è il tetto, e il nono non sparisce in silenzio', (
    tester,
  ) async {
    await disegna(tester, [for (var g = 10; g <= 20; g++) voce(g, kcal: 250)]);

    // 💡 Undici allenamenti: otto quadrati, e i tre restanti in un cartellino.
    expect(find.byType(QuadratoAllenamento), findsNWidgets(8));

    /*
     * ⛔ **Questa è l'asserzione che conta.** Troncare a otto senza dirlo è la
     * bugia per omissione: chi si allena ogni giorno crede di aver perso tre
     * allenamenti, e la scheda sembra rotta invece che sintetica.
     */
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('con otto esatti non compare nessun «+0»', (tester) async {
    await disegna(tester, [for (var g = 13; g <= 20; g++) voce(g, kcal: 250)]);

    expect(find.byType(QuadratoAllenamento), findsNWidgets(8));
    expect(find.byType(QuadratoAltri), findsNothing);
  });

  testWidgets('senza calorie mostra i minuti, non uno zero', (tester) async {
    /*
     * 🚨 Uno zero direbbe «non hai bruciato niente», che è falso: vuol dire solo
     * che né l'orologio né la persona ce l'hanno detto. ⛔ Ed è lo stesso
     * principio per cui i giorni senza diario non valgono zero nel grafico.
     */
    await disegna(tester, [voce(20)]);

    expect(find.text('60 min'), findsOneWidget);
    expect(find.text('0 kcal'), findsNothing);
  });

  testWidgets('niente sfora, nemmeno con otto quadrati a 280 px', (
    tester,
  ) async {
    /*
     * 🚨 **Questo test ha trovato un difetto vero, il giorno stesso.** Con
     * icona e testo di misura fissa il contenuto chiedeva 60 px; a 280 px di
     * schermo il quadrato ne ha 56, e sforava. ⛔ Sul telefono di sviluppo, dove
     * il lato è 76, non si sarebbe visto mai — ed è esattamente il motivo per
     * cui le larghezze si misurano invece di guardarle.
     */
    await disegna(tester, [
      for (var g = 13; g <= 20; g++) voce(g, kcal: 1200),
    ], larghezza: 280);

    expect(tester.takeException(), isNull);
  });

  testWidgets('nemmeno a carattere ingrandito', (tester) async {
    // ⚠️ Nessun calcolo fatto sul lato può prevedere l'altezza vera quando il
    // sistema ingrandisce il testo del doppio: lì la rete è il `FittedBox`.
    tester.view.physicalSize = const Size(280, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: GrigliaAllenamenti(
                voci: [for (var g = 13; g <= 20; g++) voce(g, kcal: 1200)],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
