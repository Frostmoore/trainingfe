import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/ui/intestazione_app.dart';

import 'aiuto/intestazione.dart';

/// L'intestazione condivisa, su tutte le pagine — 3b-O.1a.6, 21/08/2026.
///
/// ══ 🚨 COSA DIFENDE DAVVERO QUESTO FILE ═══════════════════════════════════
///
/// 📌 Il committente: *«questa parte va su TUTTE le pagine, non solo su Oggi»*.
///
/// ⚠️ Il rischio non è che la conversione sia sbagliata **oggi** — quella si
/// guarda sul telefono. È che **la prossima schermata** nasca con un'`AppBar`,
/// perché è quello che ogni esempio di Flutter scrive e quello che l'editor
/// suggerisce. 🚨 Una sola pagina grigia in mezzo a trenta con il colore della
/// palestra si nota più di trenta pagine grigie: sembra un pezzo rotto.
///
/// 💡 Per questo il test più importante qui non guarda i pixel: **legge il
/// sorgente** e fallisce se compare un'`AppBar` fuori dalle quattro schermate
/// in cui resta di proposito.
void main() {
  /*
   * ⛔ Le quattro eccezioni, con il motivo scritto anche **dentro** ogni file.
   *
   * 🚨 Aggiungerne una qui è una decisione, non una scorciatoia: chi lo fa deve
   * poter spiegare perché quella schermata non è dell'app.
   */
  const eccezioni = {
    // Prima della registrazione non c'è un utente: gettoni e avatar del
    // profilo non avrebbero niente da mostrare.
    'lib/src/features/auth/ui/register_screen.dart',

    // Contenuto effimero a schermo pieno su fondo scuro.
    'lib/src/features/chat/ui/widgets/usa_e_getta.dart',

    // Schermate immersive su nero: il nero serve a giudicare i colori di
    // quello che si inquadra o si ritaglia.
    'lib/src/features/fotocamera/ui/schermata_fotocamera.dart',
    'lib/src/features/fotocamera/ui/schermata_ingrandimento.dart',
  };

  test('nessuna schermata usa una AppBar fuori dalle quattro eccezioni', () {
    final colpevoli = <String>[];

    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;

      final percorso = file.path.replaceAll(r'\', '/');
      if (eccezioni.contains(percorso)) continue;

      if (file.readAsStringSync().contains('AppBar(')) {
        colpevoli.add(percorso);
      }
    }

    expect(
      colpevoli,
      isEmpty,
      reason:
          'Usa IntestazioneApp: porta il colore e il logo della palestra, il '
          'saldo dei gettoni e il profilo. Se questa schermata è davvero '
          "un'eccezione, aggiungila all'elenco qui sopra con il motivo.",
    );
  });

  /// 💡 Monta una pagina qualunque con l'intestazione dentro.
  ///
  /// ⚠️ Con [dentroUnaPila] la pagina viene messa **sopra un'altra**: è l'unico
  /// modo per far dire `true` a `Navigator.canPop()`, che è quello che decide
  /// se la freccia indietro si disegna.
  Future<void> apri(
    WidgetTester tester, {
    String? titolo,
    List<Widget> azioni = const [],
    bool indietro = true,
    bool dentroUnaPila = false,
  }) async {
    final overrides = await intestazioneFinta();

    final pagina = Scaffold(
      appBar: IntestazioneApp(
        titolo: titolo,
        azioni: azioni,
        indietro: indietro,
      ),
      body: const SizedBox(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: dentroUnaPila
              ? Navigator(
                  onGenerateInitialRoutes: (nav, _) => [
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: SizedBox()),
                    ),
                    MaterialPageRoute<void>(builder: (_) => pagina),
                  ],
                )
              : pagina,
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('il titolo della pagina si vede', (tester) async {
    await apri(tester, titolo: 'Diario');

    expect(find.text('Diario'), findsOneWidget);
  });

  testWidgets('senza titolo non c\'è la riga della navigazione', (
    tester,
  ) async {
    await apri(tester);

    /*
     * 🚨 È il caso di «Oggi»: nessun titolo, nessuna freccia, e
     * l'intestazione è alta solo la riga dell'identità.
     */
    expect(
      const IntestazioneApp().preferredSize.height,
      IntestazioneApp.altezzaIdentita,
    );

    expect(
      const IntestazioneApp(titolo: 'X').preferredSize.height,
      IntestazioneApp.altezzaIdentita + IntestazioneApp.altezzaTitolo,
    );
  });

  testWidgets('la freccia indietro NON compare su una radice', (tester) async {
    await apri(tester, titolo: 'Oggi');

    /*
     * ⛔ Le schermate della barra in basso sono radici: non c'è dove tornare.
     * ⚠️ Disegnare una freccia che non fa niente è peggio di non disegnarla —
     * promette un'azione che non esiste.
     */
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('la freccia indietro compare quando c\'è dove tornare', (
    tester,
  ) async {
    await apri(tester, titolo: 'Dettaglio', dentroUnaPila: true);

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
  });

  testWidgets('`indietro: false` toglie la freccia anche potendo tornare', (
    tester,
  ) async {
    // ⛔ Il caso della password di recupero: saltare il passo lascerebbe un
    // account a metà, quindi la freccia non c'è **anche se** si potrebbe.
    await apri(
      tester,
      titolo: 'Password di recupero',
      indietro: false,
      dentroUnaPila: true,
    );

    expect(find.text('Password di recupero'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
  });

  testWidgets('le azioni della vecchia AppBar si vedono ancora', (
    tester,
  ) async {
    await apri(
      tester,
      titolo: 'Controlla il piano',
      azioni: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.picture_as_pdf_outlined),
        ),
      ],
    );

    expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
  });

  testWidgets('a 280 px un titolo lungo taglia, non sfora', (tester) async {
    tester.view.physicalSize = const Size(280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await apri(
      tester,
      titolo: 'Un titolo molto molto lungo che non ci sta di sicuro',
      azioni: [
        IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined)),
      ],
    );

    /*
     * 🚨 280 px è la larghezza su cui questo progetto ha già misurato **tre**
     * difetti di disegno. ⚠️ E un `RenderFlex overflowed` non è una striscia
     * gialla estetica: è un layout che ha smesso di funzionare.
     */
    expect(tester.takeException(), isNull);
  });
}
