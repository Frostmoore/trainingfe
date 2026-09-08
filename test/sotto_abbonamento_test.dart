import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/acquisti/data/gate_dell_abbonamento.dart';
import 'package:training_companion/src/features/acquisti/ui/widgets/sotto_abbonamento.dart';

/// 🔒 La card sfumata e il banner — 08/09/2026.
///
/// ══ 🚨 COSA DIFENDE ═══════════════════════════════════════════════════════
///
/// ⛔ **Non l'aspetto**: quello si guarda a schermo, e infatti la prima
/// sfumatura è stata rifatta proprio perché *«si vedono comunque i dati»*.
///
/// 🚨 Difende le proprietà che **non si vedono guardando**:
///
/// 1. per un abbonato il widget è **trasparente** — nessuno strato in mezzo;
/// 2. per gli altri il contenuto è **fuori dalla semantica**, cioè lo screen
///    reader non lo legge. ⚠️ Senza, la sfumatura sarebbe una tenda davanti a
///    una porta aperta: chi usa TalkBack sentirebbe i numeri per intero;
/// 3. il contenuto **non si tocca**: sotto ci sono card che si aprono, e un
///    tocco deve portare al listino, non dentro la schermata che il gate
///    dovrebbe chiudere;
/// 4. il banner **non esplode né quando brilla né quando sparisce** — e il
///    secondo caso è un difetto vero che questo file ha trovato.
void main() {
  /// Una card qualunque con dentro un numero riconoscibile.
  Widget conGate({required bool abbonato}) => ProviderScope(
    overrides: [abbonatoProvider.overrideWithValue(abbonato)],
    child: const MaterialApp(
      home: Scaffold(
        body: SottoAbbonamento(
          motivo: 'Recupero',
          child: Card(child: Text('72')),
        ),
      ),
    ),
  );

  Widget conBanner({required bool abbonato}) => ProviderScope(
    overrides: [abbonatoProvider.overrideWithValue(abbonato)],
    child: const MaterialApp(home: Scaffold(body: BannerAbbonamento())),
  );

  testWidgets('✅ per un abbonato non c\'è nessuno strato in mezzo', (
    tester,
  ) async {
    await tester.pumpWidget(conGate(abbonato: true));

    expect(find.text('72'), findsOneWidget);
    expect(find.text('Sblocca Recupero'), findsNothing);
    expect(find.byType(ImageFiltered), findsNothing);
  });

  testWidgets('🔒 senza abbonamento: sfumato, non toccabile, non letto', (
    tester,
  ) async {
    await tester.pumpWidget(conGate(abbonato: false));

    expect(find.byType(ImageFiltered), findsOneWidget);
    /* Terzo giro: il nome della card e' tornato sul pulsante, perche' adesso
     * la sfumatura copre davvero e quel titolo non si legge piu' da nessuna
     * altra parte. */
    expect(find.text('Sblocca Recupero'), findsOneWidget);

    /*
     * 🚨 **`ExcludeSemantics` è la parte che non si vede.** Una sfumatura ferma
     * gli occhi e basta: senza questa, TalkBack leggerebbe «72» a voce alta
     * attraverso il gate.
     *
     * ⚠️ `findsWidgets` e non `findsOneWidget`: `Card`, `Material` e `InkWell`
     * ne annidano di loro, e pretendere che sia uno solo verificherebbe **come
     * è fatto Flutter**, non il nostro gate.
     */
    expect(find.byType(ExcludeSemantics), findsWidgets);

    // ⛔ E il contenuto non deve rispondere al tocco.
    expect(find.byType(AbsorbPointer), findsWidgets);
  });

  testWidgets('💳 il banner sparisce per chi è già abbonato, e si spegne', (
    tester,
  ) async {
    await tester.pumpWidget(conBanner(abbonato: true));

    expect(find.text('Sblocca le analisi dei tuoi dati'), findsNothing);

    /*
     * ══ 🚨 IL DIFETTO CHE QUESTO TEST HA TROVATO ══════════════════════════
     *
     * ⛔ Il controllore dell'animazione era `late final … = AnimationController`,
     * cioè creato al **primo uso**. Per un abbonato il primo uso non arriva
     * mai — `build` esce subito — e allora l'unico a toccarlo era `dispose()`:
     * nasceva **dentro il proprio smontaggio**, chiedendo un `vsync` a uno
     * `State` già staccato.
     *
     * 💡 A schermo sarebbe successo solo **chiudendo** la pagina da abbonato,
     * cioè nel momento in cui uno non guarda più.
     */
    await tester.pumpWidget(const SizedBox.shrink());

    expect(tester.takeException(), isNull);
  });

  testWidgets('💳 e per gli altri brilla, senza rompersi ai bordi', (
    tester,
  ) async {
    await tester.pumpWidget(conBanner(abbonato: false));

    expect(find.text('Sblocca le analisi dei tuoi dati'), findsOneWidget);

    /*
     * 🚨 **Il giro completo dell'animazione, a passi.** Le fermate del gradiente
     * si calcolano da un valore che va da 0 a 1, e `LinearGradient` **lancia**
     * se non sono ordinate o escono da [0, 1]: succederebbe proprio quando la
     * banda entra ed esce dal bordo, cioè due volte a giro.
     *
     * 💡 Un `pump` solo non lo vedrebbe: si attraversa tutta l'animazione.
     */
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }

    expect(tester.takeException(), isNull);
  });
}
