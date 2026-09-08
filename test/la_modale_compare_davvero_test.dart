import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/router/app_router.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/local_cache.dart';
import 'package:training_companion/src/features/acquisti/data/spia_dell_abbonamento.dart';
import 'package:training_companion/src/features/acquisti/ui/widgets/ricontrollo_al_rientro.dart';
import 'package:training_companion/src/features/privacy/consensi_controller.dart';

/// 🚨 La modale compare **davvero**, nella struttura vera dell'app.
///
/// ══ ⛔ PERCHÉ ESISTE, ED È UNA LEZIONE ════════════════════════════════════
///
/// Il committente, per la seconda volta: *«se disdico l'abbonamento dal
/// pannello GOD mi deve apparire la modale! E se lo riabilito, mi deve apparire
/// la modale che ho accesso all'AI!»*.
///
/// 🚨 **`spia_dell_abbonamento_test` era verde, e la modale non compariva.**
/// Quel file verifica che la spia *riconosca* il cambiamento — e lo fa bene. Ma
/// riconoscere non è mostrare: fra il `true` che torna dalla spia e la finestra
/// che si apre c'è un widget montato in un posto preciso dell'albero, e **è lì
/// che si rompeva**.
///
/// ⛔ Un test che verifica il pezzo giusto e si ferma un passo prima è il modo
/// più efficace di credere che una cosa funzioni: dà tutta la sicurezza di un
/// test verde e nessuna delle sue garanzie.
///
/// 💡 Questo file monta `RicontrolloAlRientro` **dove sta davvero** — nel
/// `builder` di `MaterialApp`, che è un antenato del `Navigator` — e pretende
/// di vedere la finestra a schermo.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// L'albero come lo costruisce `app.dart`: il ricontrollo **sopra** il router.
  Widget comeNellApp({
    required LocalCache cache,
    required bool? abbonato,
    required ProviderContainer contenitore,
  }) => UncontrolledProviderScope(
    container: contenitore,
    child: MaterialApp(
      /*
       * 🔑 **La chiave come nell'app vera**, dove la tiene `GoRouter`. ⚠️ Senza,
       * questo test non riprodurrebbe la struttura reale: `currentContext`
       * sarebbe `null` e il difetto sarebbe un altro.
       */
      navigatorKey: chiaveDelNavigatore,

      // 🚨 È questa riga il punto: nel `builder` il figlio è il `Navigator`,
      // quindi chi ci sta dentro ha il navigatore **sotto** di sé, non sopra.
      builder: (context, figlio) =>
          RicontrolloAlRientro(child: figlio ?? const SizedBox.shrink()),
      home: const Scaffold(body: Text('Oggi')),
    ),
  );

  Future<void> provaIlPassaggio(
    WidgetTester tester, {
    required bool prima,
    required bool dopo,
    required String testoAtteso,
  }) async {
    final cache = await LocalCache.open();
    await cache.setBool(SpiaDellAbbonamento.chiave, value: prima);

    final noto = StateController<bool?>(dopo);

    final contenitore = ProviderContainer(
      overrides: [
        localCacheProvider.overrideWithValue(cache),
        abbonatoNotoProvider.overrideWith((ref) => noto.state),

        // 💡 La modale dell'AI legge i consensi: senza questo andrebbe in rete.
        consensiProvider.overrideWith((ref) async => const Consensi()),
      ],
    );

    addTearDown(contenitore.dispose);

    await tester.pumpWidget(
      comeNellApp(cache: cache, abbonato: dopo, contenitore: contenitore),
    );

    // ⚠️ Tre giri: il post-frame di `initState`, la spia (asincrona), e
    // l'apertura della finestra.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 350));
    }

    expect(
      find.textContaining(testoAtteso),
      findsOneWidget,
      reason: 'la modale non è comparsa: è esattamente il difetto riferito',
    );
  }

  testWidgets('🎉 mi riabilito l\'abbonamento → «Hai sbloccato»', (
    tester,
  ) async {
    await provaIlPassaggio(
      tester,
      prima: false,
      dopo: true,
      testoAtteso: 'Hai sbloccato le ',
    );
  });

  testWidgets('🛑 mi disdico dal pannello → «è scaduto»', (tester) async {
    await provaIlPassaggio(
      tester,
      prima: true,
      dopo: false,
      testoAtteso: 'Il tuo abbonamento è scaduto',
    );
  });
}
