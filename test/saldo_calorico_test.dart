import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/saldo_calorico.dart';

/// Il saldo calorico della card di «Oggi» — 3b-F, 26/08/2026.
///
/// ══ 📌 LA SEGNALAZIONE, E I TRE GIRI CHE SONO SERVITI ═════════════════════
///
/// *«se passo il dito sull'ultimo giorno mi dice che sono sotto di 570 kcal»* →
/// *«il tdee è il consumo ad attività praticamente 0 (1.2) … non ha nulla a che
/// vedere con gli allenamenti»* → *«si dovrebbe capire che è deficit e surplus
/// rispetto AL TARGET, non rispetto alla giornata vera»*.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Tre numeri nella stessa pagina, e ognuno con un **riferimento diverso**:
///
/// | Dove | Riferimento |
/// |---|---|
/// | il riquadro del dito | l'**obiettivo** del giorno |
/// | la media in fondo | l'**obiettivo**, mediato sul periodo |
/// | la barra della prima card | il **consumo** (vita quotidiana + allenamento) |
///
/// ⛔ Il difetto originale era che un numero solo cercava di rispondere a due
/// domande, e non diceva a quale. ⚠️ **Nessun test poteva prenderlo**: il numero
/// restava plausibile, e la formula viveva dentro il costruttore di un tooltip
/// di `fl_chart`. 💡 Adesso sta qui, e si prova.
void main() {
  group('🔢 il saldo di un giorno', () {
    /// ⚠️ **Sul target, non sul consumo.** Chi ha un obiettivo di dimagrimento
    /// e lo centra è a **zero** qui, e ci deve essere: la domanda è «sto
    /// seguendo quello che mi ero ripromesso», non «sto dimagrendo».
    test('è mangiate meno obiettivo, e basta', () {
      expect(saldoDelGiorno(assunte: 2259, obiettivo: 2132), closeTo(127, 1));
    });

    test('sotto il target dà un numero negativo', () {
      expect(saldoDelGiorno(assunte: 1650, obiettivo: 1990), -340);
    });

    test('e centrarlo dà zero', () {
      expect(saldoDelGiorno(assunte: 1990, obiettivo: 1990), 0);
    });
  });

  group('🕐 il consumo del giorno', () {
    final adesso = DateTime(2026, 8, 26, 18);

    /// 🚨 **Su oggi si ferma all'ora che è.** Le calorie assunte sono quelle di
    /// finora: confrontarle con ventiquattro ore di consumo dichiarerebbe un
    /// deficit che è soltanto la giornata non ancora finita.
    test('oggi si ferma all\'ora che è', () {
      final consumo = consumoDelGiorno(
        tdee: 2400,
        giorno: DateTime(2026, 8, 26),
        adesso: adesso,
      );

      // Alle 18:00 sono passate 18 ore su 24: tre quarti.
      expect(consumo, closeTo(1800, 1));
    });

    /// ⛔ È il difetto trovato il 26/08 dietro a *«le calorie di ieri sono
    /// sbagliate»*: la card mostrava il consumo maturato **stanotte** sopra una
    /// giornata finita da ore.
    test('e su un giorno passato è intero', () {
      expect(
        consumoDelGiorno(
          tdee: 2400,
          giorno: DateTime(2026, 8, 25),
          adesso: adesso,
        ),
        2400,
      );
    });

    /// ⚠️ Quello che conta è **il giorno**, non l'uguaglianza fra due istanti.
    test('e «oggi» è il giorno, non l\'istante', () {
      expect(
        consumoDelGiorno(
          tdee: 2400,
          giorno: DateTime(2026, 8, 26, 3, 17),
          adesso: adesso,
        ),
        closeTo(1800, 1),
      );
    });
  });

  group('📊 la media del periodo', () {
    List<DateTime> giorniFinoA(DateTime ultimo, int quanti) => [
      for (var i = quanti - 1; i >= 0; i--) ultimo.subtract(Duration(days: i)),
    ];

    final adesso = DateTime(2026, 8, 26, 18);
    final giorni = giorniFinoA(DateTime(2026, 8, 26), 4);

    /// ⚠️ **È la distanza dal target**, non dal consumo: risponde a «sto
    /// seguendo quello che mi ero ripromesso?».
    test('è la media dei saldi dei giorni completi', () {
      final medio = saldoMedioDelPeriodo(
        // 23, 24, 25 completi · 26 è oggi
        giorni: giorni,
        assunte: const [1800, 1800, 1800, 1800],
        obiettivi: const [2000, 2000, 2000, 2000],
        adesso: adesso,
      );

      expect(medio, isNotNull);
      expect(medio!.giorni, 3);
      expect(medio.kcalAlGiorno, -200);
      expect(medio.sotto, isTrue);
    });

    test('e sopra il target il segno si gira', () {
      final medio = saldoMedioDelPeriodo(
        giorni: giorni,
        assunte: const [2300, 2300, 2300, 0],
        obiettivi: const [2000, 2000, 2000, 2000],
        adesso: adesso,
      );

      expect(medio!.kcalAlGiorno, 300);
      expect(medio.sotto, isFalse);
    });

    /// ⛔ **Oggi non entra**, perché non è finito. Un pomeriggio a metà entra in
    /// media come una giornata intera e la tira verso il basso — e il giorno
    /// dopo lo stesso numero cambierebbe da solo.
    test('e oggi non entra, anche se ha già del diario', () {
      final medio = saldoMedioDelPeriodo(
        giorni: giorni,
        assunte: const [1800, 1800, 1800, 300],
        obiettivi: const [2000, 2000, 2000, 2000],
        adesso: adesso,
      );

      expect(medio!.giorni, 3);
      expect(medio.kcalAlGiorno, -200);
    });

    /// 🚨 **Un giorno senza diario si salta, non vale zero.** Con `assunte = 0`
    /// il saldo sarebbe l'obiettivo intero in negativo, cioè un digiuno
    /// completo. È la stessa regola di `pesoDalSaldo`.
    test('un giorno senza diario si salta, non vale digiuno', () {
      final medio = saldoMedioDelPeriodo(
        giorni: giorni,
        assunte: const [1800, 0, 1800, 1800],
        obiettivi: const [2000, 2000, 2000, 2000],
        adesso: adesso,
      );

      expect(medio!.giorni, 2);
      expect(
        medio.kcalAlGiorno,
        -200,
        reason: 'contando lo zero verrebbe −800: un digiuno che non c\'è stato',
      );
    });

    /// ⚠️ Senza obiettivo non c'è distanza da misurare: quel giorno esce.
    test('e un giorno senza obiettivo pure', () {
      final medio = saldoMedioDelPeriodo(
        giorni: giorni,
        assunte: const [1800, 1800, 1800, 1800],
        obiettivi: const [2000, 0, 2000, 2000],
        adesso: adesso,
      );

      expect(medio!.giorni, 2);
    });

    /// ⚠️ La media di niente non è zero, è **assente**.
    test('senza nessun giorno completo non c\'è media', () {
      expect(
        saldoMedioDelPeriodo(
          giorni: [DateTime(2026, 8, 26)],
          assunte: const [1500],
          obiettivi: const [2000],
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
          obiettivi: const [2000, 2000, 2000, 2000],
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
        assunte: const [1800, 1800],
        obiettivi: const [2000, 2000],
        adesso: adesso,
      );

      expect(medio!.giorni, 2);
      expect(medio.kcalAlGiorno, -200);
    });
  });
}
