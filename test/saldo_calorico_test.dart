import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/saldo_calorico.dart';

/// Il saldo calorico, e il movimento contato due volte — 3b-F, 26/08/2026.
///
/// ══ 📌 LA SEGNALAZIONE ════════════════════════════════════════════════════
///
/// *«se passo il dito sull'ultimo giorno mi dice che sono sotto di 570 kcal. Le
/// calorie effettivamente consumate sono 2259 e quelle bruciate 2403 (secondo la
/// prima card delle calorie), quindi non capisco bene cosa stia succedendo»*.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// ⛔ Il difetto era `assunte − TDEE − attive`: il **TDEE è già
/// `BMR × fattore di attività`**, quindi togliergli sopra le calorie attive
/// misurate conta lo stesso movimento due volte.
///
/// ⚠️ **Nessun test poteva accorgersene**, e il motivo va detto: il numero
/// restava **plausibile**. −570 invece di −144 è un deficit credibile, di quelli
/// che si guardano e si accettano — e intanto ogni giorno dichiarava 426 kcal di
/// dimagrimento che non erano successe.
void main() {
  group('🔢 il saldo di un giorno', () {
    /// 🚨 **I numeri della segnalazione**, con il basale intero: 2259 mangiate,
    /// 1760 di basale, 717 attive → 2403 bruciate davvero, −144 di saldo.
    test('è mangiate meno bruciate, e basta', () {
      expect(
        saldoDelGiorno(assunte: 2259, basale: 1686, attive: 717),
        closeTo(-144, 1),
      );
    });

    test('un surplus è positivo', () {
      expect(saldoDelGiorno(assunte: 2600, basale: 1700, attive: 300), 600);
    });

    /// ⚠️ Chi non si è mosso ha comunque bruciato il basale: **non è zero**.
    test('e senza movimento resta il basale', () {
      expect(saldoDelGiorno(assunte: 2000, basale: 1700, attive: 0), 300);
    });
  });

  group('🕐 il basale del giorno', () {
    final adesso = DateTime(2026, 8, 26, 18);

    /// 🚨 **Su oggi si ferma all'ora che è.** Le calorie assunte sono quelle di
    /// finora: confrontarle con ventiquattro ore di basale dichiara un deficit
    /// che è soltanto la giornata non ancora finita.
    test('oggi si ferma all\'ora che è', () {
      final basale = basaleDelGiorno(
        bmr: 2400,
        giorno: DateTime(2026, 8, 26),
        adesso: adesso,
      );

      // Alle 18:00 sono passate 18 ore su 24: tre quarti.
      expect(basale, closeTo(1800, 1));
    });

    test('e su un giorno passato è intero', () {
      expect(
        basaleDelGiorno(
          bmr: 2400,
          giorno: DateTime(2026, 8, 25),
          adesso: adesso,
        ),
        2400,
      );
    });

    /// ⚠️ L'ora di oggi vale anche se l'istante porta minuti e secondi: quello
    /// che conta è **il giorno**, non l'uguaglianza fra due `DateTime`.
    test('e «oggi» è il giorno, non l\'istante', () {
      expect(
        basaleDelGiorno(
          bmr: 2400,
          giorno: DateTime(2026, 8, 26, 3, 17),
          adesso: adesso,
        ),
        closeTo(1800, 1),
      );
    });
  });

  group('📊 la media del periodo', () {
    List<DateTime> giorniFinoA(DateTime ultimo, int quanti) => [
      for (var i = quanti - 1; i >= 0; i--)
        ultimo.subtract(Duration(days: i)),
    ];

    final adesso = DateTime(2026, 8, 26, 18);
    final giorni = giorniFinoA(DateTime(2026, 8, 26), 4);

    test('è la media dei saldi dei giorni completi', () {
      final medio = saldoMedioDelPeriodo(
        // 23, 24, 25 completi · 26 è oggi
        giorni: giorni,
        assunte: const [2000, 2000, 2000, 2000],
        attive: const [0, 0, 0, 0],
        bmr: 2200,
        adesso: adesso,
      );

      expect(medio, isNotNull);
      expect(medio!.giorni, 3);
      expect(medio.kcalAlGiorno, -200);
      expect(medio.deficit, isTrue);
    });

    /// ⛔ **Oggi non entra**, perché non è finito. Un pomeriggio a metà entra in
    /// media come una giornata intera e la tira verso il deficit — e il giorno
    /// dopo lo stesso numero cambierebbe da solo.
    test('e oggi non entra, anche se ha già del diario', () {
      final conOggiEnorme = saldoMedioDelPeriodo(
        giorni: giorni,
        assunte: const [2000, 2000, 2000, 9999],
        attive: const [0, 0, 0, 0],
        bmr: 2200,
        adesso: adesso,
      );

      expect(conOggiEnorme!.giorni, 3);
      expect(conOggiEnorme.kcalAlGiorno, -200);
    });

    /// 🚨 **Un giorno senza diario si salta, non vale zero.** Con `assunte = 0`
    /// il saldo sarebbe un digiuno completo, e su tre giorni saltati fanno una
    /// media da fame che non è successa. È la stessa regola di `pesoDalSaldo`.
    test('un giorno senza diario si salta, non vale digiuno', () {
      final medio = saldoMedioDelPeriodo(
        giorni: giorni,
        assunte: const [2000, 0, 2000, 2000],
        attive: const [0, 0, 0, 0],
        bmr: 2200,
        adesso: adesso,
      );

      expect(medio!.giorni, 2);
      expect(
        medio.kcalAlGiorno,
        -200,
        reason: 'contando lo zero verrebbe −933: un digiuno che non c\'è stato',
      );
    });

    test('e il movimento entra nel conto', () {
      final medio = saldoMedioDelPeriodo(
        giorni: giorni,
        assunte: const [2500, 2500, 2500, 0],
        attive: const [300, 300, 300, 0],
        bmr: 2200,
        adesso: adesso,
      );

      expect(medio!.kcalAlGiorno, 0);
      expect(medio.deficit, isFalse);
    });

    /// ⚠️ La media di niente non è zero, è **assente**.
    test('senza nessun giorno completo non c\'è media', () {
      expect(
        saldoMedioDelPeriodo(
          giorni: [DateTime(2026, 8, 26)],
          assunte: const [1500],
          attive: const [0],
          bmr: 2200,
          adesso: adesso,
        ),
        isNull,
      );
    });

    test('e nemmeno con il diario tutto vuoto', () {
      expect(
        saldoMedioDelPeriodo(
          giorni: giorni,
          assunte: const [0, 0, 0, 0],
          attive: const [0, 0, 0, 0],
          bmr: 2200,
          adesso: adesso,
        ),
        isNull,
      );
    });

    /// ⚠️ Le liste possono essere più corte delle date: il server manda le
    /// serie, e una risposta monca non deve far esplodere la card.
    test('e una serie più corta delle date non esplode', () {
      final medio = saldoMedioDelPeriodo(
        giorni: giorni,
        assunte: const [2000, 2000],
        attive: const [],
        bmr: 2200,
        adesso: adesso,
      );

      expect(medio!.giorni, 2);
      expect(medio.kcalAlGiorno, -200);
    });
  });
}
