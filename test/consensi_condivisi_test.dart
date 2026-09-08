import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/acquisti/ui/widgets/hai_sbloccato_lai.dart';
import 'package:training_companion/src/features/privacy/consensi_controller.dart';
import 'package:training_companion/src/features/privacy/ui/widgets/elenco_dei_consensi.dart';

/// ⚖️ I consensi condivisi e la modale del pagamento — 08/09/2026.
///
/// ══ 🚨 COSA DIFENDE ═══════════════════════════════════════════════════════
///
/// 1. **Sono tre, e si vedono tutti e tre.** 📌 *«devono essere tutti i miei
///    consensi, parliamo di dati sanitari»*. ⛔ Uno che sparisce dentro un `if`
///    non dà nessun errore: la schermata resta bella e la persona ha deciso su
///    due cose invece che su tre.
/// 2. **Il «concedi tutto» non sostituisce i tre.** 🚨 Se un giorno qualcuno lo
///    trasformasse nell'unico interruttore, sarebbe consenso a strascico —
///    nullo ai sensi dell'art. 9(2)(a). Il test pretende che gli altri restino.
/// 3. **La modale del pagamento riflette lo stato vero.** ⚠️ Un interruttore che
///    parte acceso «perché hai pagato» sarebbe il difetto grave: l'abbonamento
///    non è il consenso.
void main() {
  Widget conElenco(Consensi dati) => ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: ElencoDeiConsensi(dati: dati)),
      ),
    ),
  );

  Widget conLaModale(Consensi dati) => ProviderScope(
    overrides: [consensiProvider.overrideWith((ref) async => dati)],
    child: const MaterialApp(home: Scaffold(body: HaiSbloccatoLAi())),
  );

  testWidgets('⚖️ i consensi sono tre, più il «concedi tutto»', (tester) async {
    await tester.pumpWidget(conElenco(const Consensi()));
    await tester.pumpAndSettle();

    for (final titolo in [
      'Concedi tutto',
      'Dati su sonno e recupero',
      'Consiglio del giorno e riconoscimento dei pasti',
      'Sonno e recupero nel consiglio del giorno',
    ]) {
      expect(find.text(titolo), findsOneWidget, reason: 'manca «$titolo»');
    }

    /*
     * 🚨 **Quattro interruttori, non uno.** ⛔ Se il «concedi tutto»
     * sostituisse i tre, questo numero scenderebbe — ed è esattamente il
     * consenso a strascico che l'art. 9(2)(a) non ammette.
     */
    expect(find.byType(Switch), findsNWidgets(4));
  });

  testWidgets('🚫 il terzo è spento finché l\'AI è spenta', (tester) async {
    await tester.pumpWidget(conElenco(const Consensi()));
    await tester.pumpAndSettle();

    /*
     * ⚠️ **Non è cortesia d'interfaccia.** Accendere il sonno mentre l'AI è
     * spenta scriverebbe una data su un consenso che non può valere, e il
     * giorno che l'AI si riaccende quel consenso tornerebbe attivo **senza che
     * nessuno l'abbia riconfermato**.
     */
    expect(
      find.text('Per attivarlo serve prima il consenso qui sopra.'),
      findsOneWidget,
    );
  });

  testWidgets(
    '🎉 la modale del pagamento parte SPENTA se il consenso non c\'era',
    (tester) async {
      await tester.pumpWidget(conLaModale(const Consensi()));
      await _lascialaArrivare(tester);

      expect(find.textContaining('Hai sbloccato le '), findsOneWidget);
      expect(find.text('Funzionalità IA'), findsOneWidget);

      /*
     * ══ ⚖️ IL PUNTO LEGALE DI TUTTA LA MODALE ═════════════════════════════
     *
     * ⛔ **Pagare non è acconsentire.** Chi ha appena pagato *si aspetta* che
     * tutto funzioni, e un interruttore che parte acceso «perché hai pagato»
     * sarebbe in regola con il contratto e fuori legge sul GDPR.
     */
      final interruttore = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );

      expect(interruttore.value, isFalse);
    },
  );

  testWidgets(
    '🎉 e parte ACCESA se il consenso c\'era già, restando spegnibile',
    (tester) async {
      await tester.pumpWidget(
        conLaModale(
          Consensi(
            ai: DateTime(2026, 9, 1),
            aiPresaDAtto: DateTime(2026, 9, 1),
          ),
        ),
      );
      await _lascialaArrivare(tester);

      final interruttore = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );

      expect(interruttore.value, isTrue);

      // 📌 *«l'utente deve poterlo mettere su off»*: `onChanged` non è `null`.
      expect(interruttore.onChanged, isNotNull);
    },
  );

  testWidgets('✨ e l\'intestazione rosa brilla senza rompersi ai bordi', (
    tester,
  ) async {
    await tester.pumpWidget(conLaModale(const Consensi()));
    await _lascialaArrivare(tester);

    /*
     * 🚨 Le fermate del gradiente si calcolano da un valore che va da 0 a 1, e
     * `LinearGradient` **lancia** se escono da [0, 1]: succede proprio quando
     * la banda entra ed esce dal bordo, cioè due volte a giro.
     */
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(tester.takeException(), isNull);
  });
}

/// Fa arrivare i consensi, senza aspettare la fine dell'animazione.
///
/// == ATTENZIONE: `pumpAndSettle` QUI VA IN TIMEOUT, E NON E' UN DIFETTO ==
///
/// `pumpAndSettle` aspetta che **non ci siano piu' fotogrammi da disegnare**.
/// L'intestazione rosa brilla in continuo, quindi quel momento non arriva mai:
/// il test moriva dopo dieci secondi con un errore che non parlava di consensi.
///
/// Due `pump` bastano: il primo costruisce, il secondo raccoglie il valore del
/// `FutureProvider` sovrascritto.
Future<void> _lascialaArrivare(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}
