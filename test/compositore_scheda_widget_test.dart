import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/ui/compositore_scheda.dart';

/// Il compositore delle schede su uno schermo stretto — G7.6.
///
/// ── 🚨 Perché 328 px, e perché è un numero e non «piccolo» ────────────────
///
/// È la larghezza utile dello Xiaomi del committente: è lì che il difetto delle
/// tendine del profilo è stato **misurato**, non immaginato. Un test su una
/// larghezza generosa non proverebbe niente — l'overflow si vede solo quando lo
/// spazio manca davvero.
///
/// ⚠️ Un `RenderFlex overflowed` non è una striscia gialla estetica: è un layout
/// che ha smesso di funzionare, e nessun test sui modelli lo prende perché il
/// dato è giusto ed è il **disegno** a rompersi.
void main() {
  Widget suUnoSchermoStretto(Widget figlio) => ProviderScope(
    child: MaterialApp(
      home: Center(
        child: SizedBox(width: 328, child: figlio),
      ),
    ),
  );

  testWidgets('una scheda nuova si apre senza sforare a 328 px', (tester) async {
    tester.view.physicalSize = const Size(656, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(suUnoSchermoStretto(const CompositoreScheda()));
    await tester.pump();

    // 🚨 `pumpWidget` non fallisce da solo su un overflow: l'eccezione finisce
    // in `takeException()`, e va guardata esplicitamente.
    expect(tester.takeException(), isNull);

    // Una scheda nuova nasce con un giorno e un esercizio: cominciare da zero
    // vorrebbe dire mostrare una schermata vuota a chi ha appena premuto
    // «nuova scheda».
    expect(find.text('Nuova scheda'), findsOneWidget);
    expect(find.text('Esercizio'), findsOneWidget);
  });

  testWidgets('serie e ripetizioni stanno su due righe da due, non una da quattro', (tester) async {
    tester.view.physicalSize = const Size(656, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(suUnoSchermoStretto(const CompositoreScheda()));
    await tester.pump();

    /*
     * ⚠️ `plan_editor_screen.dart` mette serie/ripetizioni/recupero/kg tutti in
     * fila: a questa larghezza quattro etichette si accavallano. Qui sono due
     * righe da due, e questo test è ciò che impedisce a qualcuno di
     * «compattarle» un giorno.
     */
    expect(find.text('serie'), findsOneWidget);
    expect(find.text('ripetizioni'), findsOneWidget);
    expect(find.text('recupero (s)'), findsOneWidget);
    expect(find.text('kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('il Rif. Allievo dice che resta sul server', (tester) async {
    tester.view.physicalSize = const Size(656, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(suUnoSchermoStretto(const CompositoreScheda()));
    await tester.pump();

    /*
     * 🚨 **L'avvertenza è una misura di privacy, non una cortesia.** Il campo
     * sta in chiaro sul server e da una scheda post-infortunio si capisce cos'è
     * successo a chi la esegue: la DPIA (R8) conta su questa riga per dire che
     * il residuo è dichiarato all'utente.
     */
    expect(find.text('Rif. Allievo'), findsOneWidget);
    expect(find.textContaining('resta sul server'), findsOneWidget);
  });

  testWidgets('aggiungere un giorno non rompe la striscia', (tester) async {
    tester.view.physicalSize = const Size(656, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(suUnoSchermoStretto(const CompositoreScheda()));
    await tester.pump();

    await tester.tap(find.text('Giorno'));
    await tester.pump();

    // 💡 Due giorni, e la striscia scorre in orizzontale: è ciò che rende
    // possibile «un giorno alla volta» senza mai mostrare l'albero intero.
    expect(find.text('Giorno 1'), findsOneWidget);
    expect(find.text('Giorno 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('il foglio delle alternative si apre e si ferma a tre', (tester) async {
    tester.view.physicalSize = const Size(656, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(suUnoSchermoStretto(const CompositoreScheda()));
    await tester.pump();

    // ⚠️ `ensureVisible` prima del tocco: il pulsante sta in fondo alla carta
    // dell'esercizio, quindi su uno schermo stretto è **sotto la piega**. Un
    // `tap()` su qualcosa fuori schermo non fallisce — avvisa e non fa niente,
    // che è il modo peggiore di sbagliare un test.
    await tester.ensureVisible(find.text('Alternative'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alternative'));
    await tester.pumpAndSettle();

    expect(find.text('Nessuna alternativa.'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Aggiungi alternativa'));
      await tester.pumpAndSettle();
    }

    /*
     * 🚨 **Il limite di tre lo applica anche il server** (`AlMassimoTreAlternative`).
     * Qui il pulsante sparisce: un pulsante che porta a un errore di validazione
     * è peggio di un pulsante assente.
     */
    expect(find.text('Aggiungi alternativa'), findsNothing);
    expect(find.textContaining('Massimo 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
