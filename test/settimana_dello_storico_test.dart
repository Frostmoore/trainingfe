import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';
import 'package:training_companion/src/features/training/settimana_scelta.dart';
import 'package:training_companion/src/features/training/storico_unificato_controller.dart';
import 'package:training_companion/src/features/training/ui/widgets/barra_settimana.dart';

/// Lo storico per settimana — 3b-A.4, 24/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// 📌 Il committente: *«Va aggiunto, nell'header, un navigatore per settimana e
/// lo storico deve essere ordinato per settimana»*.
///
/// ⚠️ Il difetto da prendere **non è di calcolo**: è una seduta che finisce
/// nella settimana sbagliata, e a schermo si vede come «quella volta che mi
/// sono allenato di domenica non c'è più».
void main() {
  setUpAll(() => initializeDateFormatting('it'));

  VoceStorico voce(DateTime quando) => VoceStorico(
    sedute: const [],
    dalPolso: [
      AllenamentoDaOrologio(
        id: quando.millisecondsSinceEpoch ~/ 1000,
        fonte: 'com.google.android.apps.fitness',
        tipo: 'STRENGTH_TRAINING',
        iniziatoIl: quando,
        finitoIl: quando.add(const Duration(hours: 1)),
        nascosto: false,
        staccato: false,
        contaComeExtra: false,
      ),
    ],
  );

  // ───────────────────────── il lunedì ─────────────────────────

  group('lunediDi', () {
    /// 💡 Il 24/08/2026 è un lunedì: è il riferimento di tutto il file.
    test('su un lunedì resta quel lunedì, a mezzanotte', () {
      expect(lunediDi(DateTime(2026, 8, 24, 15, 42)), DateTime(2026, 8, 24));
    });

    test('su un mercoledì torna indietro al lunedì', () {
      expect(lunediDi(DateTime(2026, 8, 26, 7)), DateTime(2026, 8, 24));
    });

    /// ══ 🚨 LA DOMENICA SERA È IL CASO CHE SI SBAGLIA ══════════════════════
    ///
    /// ⚠️ Una seduta di domenica alle 22:00 appartiene alla settimana che sta
    /// **finendo**, non a quella dopo. ⛔ `weekday` della domenica vale 7, e
    /// chi scrive `- d.weekday` invece di `- (d.weekday - 1)` la sposta di una
    /// settimana intera senza che niente si lamenti.
    test('la domenica sera resta nella settimana che finisce', () {
      expect(lunediDi(DateTime(2026, 8, 30, 22)), DateTime(2026, 8, 24));
    });

    /// 🚨 E il lunedì alle 00:30 appartiene alla settimana che **comincia**.
    /// È il caso simmetrico, ed è quello che il fuso orario rompeva: su un
    /// `DateTime` in UTC i componenti sono quelli UTC, e quella mezzanotte e
    /// mezza diventava la domenica prima.
    test('il lunedì a mezzanotte e mezza è già la settimana nuova', () {
      expect(lunediDi(DateTime(2026, 8, 31, 0, 30)), DateTime(2026, 8, 31));
    });

    test('e attraversa il cambio di mese senza scomporsi', () {
      // Martedì 1 settembre 2026 → lunedì 31 agosto.
      expect(lunediDi(DateTime(2026, 9, 1)), DateTime(2026, 8, 31));
    });
  });

  // ───────────────────────── il navigatore ─────────────────────────

  group('SettimanaScelta', () {
    late ProviderContainer c;

    setUp(() {
      c = ProviderContainer();
      addTearDown(c.dispose);
    });

    test('comincia dalla settimana in corso', () {
      expect(c.read(settimanaSceltaProvider), lunediDi(DateTime.now()));
      expect(c.read(settimanaSceltaProvider.notifier).eQuesta, isTrue);
    });

    test('indietro toglie sette giorni', () {
      final da = c.read(settimanaSceltaProvider);

      c.read(settimanaSceltaProvider.notifier).indietro();

      expect(
        c.read(settimanaSceltaProvider),
        da.subtract(const Duration(days: 7)),
      );
    });

    /// ⛔ **Non si va nel futuro**, ed è la stessa scelta di `GiornoScelto`: un
    /// allenamento della settimana prossima non esiste, e portarci darebbe una
    /// schermata vuota che sembra un guasto.
    test('avanti non supera la settimana in corso', () {
      final controllo = c.read(settimanaSceltaProvider.notifier);
      final questa = c.read(settimanaSceltaProvider);

      controllo.avanti();

      expect(c.read(settimanaSceltaProvider), questa);
    });

    test('ma da indietro si torna avanti', () {
      final controllo = c.read(settimanaSceltaProvider.notifier)
        ..indietro()
        ..indietro()
        ..avanti();

      expect(
        c.read(settimanaSceltaProvider),
        lunediDi(DateTime.now()).subtract(const Duration(days: 7)),
      );
      expect(controllo.eQuesta, isFalse);
    });

    test('e «questa» ci riporta in un colpo', () {
      c.read(settimanaSceltaProvider.notifier)
        ..indietro()
        ..indietro()
        ..indietro()
        ..questa();

      expect(c.read(settimanaSceltaProvider), lunediDi(DateTime.now()));
    });

    /// 💡 Serve allo stato vuoto: chi si è fermato un mese non deve premere la
    /// freccia indietro finché non ricompare qualcosa.
    test('vaiA porta al lunedì della data, non alla data', () {
      c
          .read(settimanaSceltaProvider.notifier)
          .vaiA(DateTime(2026, 8, 26, 19, 30));

      expect(c.read(settimanaSceltaProvider), DateTime(2026, 8, 24));
    });
  });

  // ───────────────────────── la barra ─────────────────────────

  group('La barra nell intestazione', () {
    Widget attorno(
      List<VoceStorico> voci, {
      double larghezza = 328,
    }) => ProviderScope(
      overrides: [storicoUnificatoProvider.overrideWith((ref) async => voci)],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: larghezza, child: const BarraSettimana()),
          ),
        ),
      ),
    );

    testWidgets('sulla settimana in corso dice «Questa settimana»', (
      tester,
    ) async {
      await tester.pumpWidget(attorno(const []));
      await tester.pumpAndSettle();

      expect(find.textContaining('Questa settimana'), findsOneWidget);
    });

    /// 🚨 **Il conteggio è la domanda che ci si fa guardando lo storico**:
    /// «quante volte mi sono allenato questa settimana». Prima stava sopra
    /// l'elenco; con il navigatore starebbe due volte nello stesso schermo, e
    /// quindi si è spostato qui.
    testWidgets('e conta solo le sedute della settimana mostrata', (
      tester,
    ) async {
      /*
       * ⚠️ **Questo test all'inizio non provava niente**: ricalcolava il filtro
       * a mano e verificava la propria aritmetica. Un test che riscrive il
       * codice che dovrebbe controllare dice sempre di sì.
       *
       * 💡 Adesso legge l'etichetta vera: due allenamenti in settimane diverse,
       * e la barra deve dirne **uno**.
       */
      final lunedi = lunediDi(DateTime.now());

      await tester.pumpWidget(
        attorno([
          voce(lunedi.add(const Duration(days: 2))),
          voce(lunedi.subtract(const Duration(days: 3))),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('1 seduta'), findsOneWidget);
      expect(find.textContaining('2 sedute'), findsNothing);
    });

    /// 🚨 **Mentre carica non si scrive «0 sedute»**: sarebbe un numero falso,
    /// e chi lo legge crede di non essersi allenato.
    testWidgets('e mentre carica non inventa uno zero', (tester) async {
      // ⚠️ Un `Future` che **non si completa**: con uno già risolto Riverpod
      // consegna il valore nello stesso microtask e lo stato «sto caricando»
      // non si vede mai — il test passerebbe senza aver guardato niente.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storicoUnificatoProvider.overrideWith(
              (ref) => Completer<List<VoceStorico>>().future,
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SizedBox(width: 328, child: BarraSettimana())),
          ),
        ),
      );
      await tester.pump(Duration.zero);

      expect(find.textContaining('sedute'), findsNothing);
      expect(find.textContaining('Questa settimana'), findsOneWidget);
    });

    /// ⛔ **La freccia avanti è spenta sulla settimana in corso**, e si deve
    /// vedere: un pulsante che c'è e non fa niente è peggio di uno assente.
    testWidgets('la freccia avanti è spenta su questa settimana', (
      tester,
    ) async {
      await tester.pumpWidget(attorno(const []));
      await tester.pumpAndSettle();

      final avanti = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.chevron_right_rounded),
          matching: find.byType(IconButton),
        ),
      );

      expect(avanti.onPressed, isNull);
    });

    /// ⚠️ 328 px è la larghezza utile dello Xiaomi del committente: è lì che i
    /// difetti di disposizione di questo progetto si **misurano**, non si
    /// immaginano.
    testWidgets('e non sfora a 328 px', (tester) async {
      await tester.pumpWidget(attorno(const []));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('nemmeno a 280 px', (tester) async {
      await tester.pumpWidget(attorno(const [], larghezza: 280));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
