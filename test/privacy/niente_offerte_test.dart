import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/privacy/consensi_controller.dart';
import 'package:training_companion/src/features/privacy/ui/schermata_consensi.dart';

import '../aiuto/intestazione.dart';

/// 🔕 **«Non mandarmi offerte»** — voce 43, DPIA R16, 25/09/2026.
///
/// ══ 🚨 COSA GUARDANO QUESTI TEST ════════════════════════════════════════════
///
/// ⛔ Non «l'interruttore si accende»: che sia **al verso giusto** e che dica
/// **la verità su cosa spegne**.
///
/// ⚠️ Un opt-out letto al contrario spegne le promozioni a tutti in silenzio; e
/// un interruttore che non dichiara cosa lascia acceso fa temere a chi lo tocca
/// di perdere l'avviso che l'abbonamento sta per scadere.
void main() {
  final cambiati = <(String, bool)>[];

  setUp(cambiati.clear);

  Future<void> apri(WidgetTester tester, Consensi dati) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await intestazioneFinta(),
          consensiProvider.overrideWith((ref) async => dati),
          cambiaConsensoProvider.overrideWith(
            (ref) =>
                (String quale, bool dato, {bool presaDAtto = false}) async {
                  cambiati.add((quale, dato));
                },
          ),
        ],
        child: const MaterialApp(home: SchermataConsensi()),
      ),
    );

    await tester.pumpAndSettle();

    /*
     * 🚨 **Si scorre fino in fondo, o il blocco non esiste.** La schermata
     * è una `ListView` **lazy**: quello che sta sotto il bordo non viene
     * costruito, e `find.text` non lo trova. ⚠️ Senza questa riga il test
     * fallirebbe dicendo «non c'è» su una cosa che c'è — la diagnosi
     * sbagliata più facile da credere.
     */
    await tester.dragUntilVisible(
      find.text('Non mandarmi offerte'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
  }

  /// L'interruttore delle offerte, dentro la sua scheda.
  Finder ilSuoInterruttore() => find.descendant(
    of: find.ancestor(
      of: find.text('Non mandarmi offerte'),
      matching: find.byType(Card),
    ),
    matching: find.byType(Switch),
  );

  /// ⚖️ **Di serie le offerte arrivano**: è un opt-out, non un consenso.
  ///
  /// ⛔ Il verso sbagliato spegnerebbe le promozioni a chi non ha chiesto
  /// niente — e nessuno se ne accorgerebbe, perché il sintomo è che *non*
  /// succede qualcosa.
  testWidgets('di serie l\'interruttore è spento', (tester) async {
    await apri(tester, const Consensi());

    expect(tester.widget<Switch>(ilSuoInterruttore()).value, isFalse);
  });

  /// 🚨 **Dice cosa NON spegne**, e va scritto a schermo: se non gliel'ho
  /// detto qui, lo scoprirà non ricevendolo.
  testWidgets('dichiara cosa resta acceso', (tester) async {
    await apri(tester, const Consensi());

    expect(find.textContaining('Restano gli avvisi di servizio'), findsOneWidget);
    expect(find.textContaining('notifiche dei messaggi'), findsOneWidget);
    expect(find.textContaining('password, inviti, ricevute'), findsOneWidget);
  });

  /// 💡 **Le promozioni continuano ad arrivare**: si spegne l'annuncio, non il
  /// regalo. ⛔ Chi crede di perdere i regali non spegnerà mai la pubblicità,
  /// e il diritto resta sulla carta.
  testWidgets('spiega che la promozione arriva comunque', (tester) async {
    await apri(tester, const Consensi());

    expect(find.textContaining('la trovi comunque nel tuo saldo'), findsOneWidget);
  });

  testWidgets('accendendolo lo dice al server col nome giusto', (tester) async {
    await apri(tester, const Consensi());

    await tester.tap(ilSuoInterruttore());
    await tester.pumpAndSettle();

    expect(cambiati, [('niente_offerte', true)]);
  });

  /// 💡 Quando vale: serve a chi rilegge la schermata e non ricorda cosa ha
  /// deciso.
  testWidgets('quando è acceso dice da quando', (tester) async {
    await apri(
      tester,
      Consensi(nienteOfferte: true, nienteOfferteDal: DateTime(2026, 9, 25)),
    );

    expect(find.textContaining('Scelto il 25/9/2026'), findsOneWidget);
  });

  /// 🚨 **Sta sotto un titolo suo**, separato dai consensi.
  ///
  /// ⚠️ L'art. 21(4) vuole che il diritto di opporsi al marketing sia
  /// presentato «chiaramente e separatamente». ⛔ Infilato fra i consensi
  /// diventerebbe uno dei tanti interruttori — che è ciò che la norma vieta.
  testWidgets('ha un titolo suo, staccato dai consensi', (tester) async {
    await apri(tester, const Consensi());

    expect(find.text('Le offerte'), findsOneWidget);
  });
}
