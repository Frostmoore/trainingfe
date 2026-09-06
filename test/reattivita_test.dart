import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/forma/reattivita.dart';

/// Il modello a tre processi — 06/09/2026.
///
/// ══ 🚨 COSA DIFENDONO QUESTI TEST ════════════════════════════════════════
///
/// Non «che il numero esca»: che esca **nella forma giusta**. Un modello di
/// allerta sbagliato non dà nessun errore — dà un numero fra 0 e 100 che sembra
/// sensato e descrive un essere umano che non esiste.
///
/// 📌 Quindi i test sono scritti sugli **esempi del committente**, uno per uno:
/// se il modello non li riproduce, non serve a niente per quanto sia validato in
/// letteratura.
void main() {
  /// Le tre frasi da cui nasce tutto, il 06/09/2026:
  ///
  /// *«subito dopo aver mangiato sono meno reattivo che dopo un paio d'ore che
  /// sto in piedi»* · *«dopo un bel pisolino di due ore sono molto più reattivo
  /// di quanto io lo sia a fine serata in un giorno che non ho riposato»*.
  group('gli esempi del committente', () {
    test('🚨 subito dopo mangiato si è meno reattivi che due ore dopo', () {
      double alle(double ore, {double? dalPasto}) => ModelloDellaReattivita
          .calcola(
            oraDecimale: ore,
            oreSveglio: ore - 7,
            oreDormite: 8,
            oreDalPasto: dalPasto,
            kcalDelPasto: 700,
          )
          .valore;

      // 🍽️ Pranzo alle 13. Un'ora dopo si è nel pieno della digestione…
      final durante = alle(14, dalPasto: 1);

      // …e due ore più tardi è passata.
      final dopo = alle(16, dalPasto: 3);

      expect(
        durante,
        lessThan(dopo),
        reason: 'Il pasto deve abbassare la reattività, non alzarla',
      );
    });

    test('🚨 il pisolino batte la fine serata senza riposo', () {
      /*
       * 📌 *«dopo che ho fatto un bel pisolino di due ore sono molto più
       * reattivo di quanto io lo sia a fine serata in un giorno che non ho
       * riposato»*.
       */

      // 😴 Pisolino finito da un'ora e mezza: l'inerzia è passata, S è risalito.
      final dopoIlPisolino = ModelloDellaReattivita.calcola(
        oraDecimale: 17,
        oreSveglio: 1.5,
        oreDormite: 2,
      ).valore;

      // 🌙 Le 23, in piedi da sedici ore, dopo una notte da cinque.
      final fineSerata = ModelloDellaReattivita.calcola(
        oraDecimale: 23,
        oreSveglio: 16,
        oreDormite: 5,
      ).valore;

      expect(dopoIlPisolino, greaterThan(fineSerata));
    });

    test('⚠️ ma NELL\'istante del risveglio si è peggio di prima', () {
      /*
       * 🚨 **È l'inerzia del risveglio, il terzo processo.** Senza, un pisolino
       * risulterebbe un guadagno immediato — e chi si alza intontito penserebbe
       * che il numero è rotto.
       */
      final appenaSveglio = ModelloDellaReattivita.calcola(
        oraDecimale: 15.5,
        oreSveglio: 0.05,
        oreDormite: 2,
      );

      final unOraDopo = ModelloDellaReattivita.calcola(
        oraDecimale: 16.5,
        oreSveglio: 1,
        oreDormite: 2,
      );

      expect(appenaSveglio.valore, lessThan(unOraDopo.valore));
      expect(appenaSveglio.motivo, MotivoDellaReattivita.appenaSvegliato);
    });
  });

  group('i processi, uno per uno', () {
    test('il circadiano ha il picco alle 16:48 e il minimo dodici ore prima', () {
      final picco = ModelloDellaReattivita.circadiano(
        ModelloDellaReattivita.acrofase,
      );

      final minimo = ModelloDellaReattivita.circadiano(
        ModelloDellaReattivita.acrofase - 12,
      );

      expect(picco, closeTo(ModelloDellaReattivita.ampiezzaCircadiana, 0.001));
      expect(minimo, closeTo(-ModelloDellaReattivita.ampiezzaCircadiana, 0.001));
    });

    test('🚨 l\'omeostatico scende stando svegli, e non risale mai da solo', () {
      double dopo(double ore) =>
          ModelloDellaReattivita.omeostatico(oreSveglio: ore);

      expect(dopo(2), greaterThan(dopo(8)));
      expect(dopo(8), greaterThan(dopo(16)));

      // ⚠️ E non scende mai sotto l'asintoto: restare svegli tre giorni non
      // porta l'allerta sotto zero, porta a un minimo che resta lì.
      expect(dopo(72), greaterThan(ModelloDellaReattivita.asintotoBasso));
    });

    test('💡 dormire di più riporta più in alto', () {
      expect(
        ModelloDellaReattivita.alRisveglio(oreDormite: 8),
        greaterThan(ModelloDellaReattivita.alRisveglio(oreDormite: 4)),
      );

      /*
       * 🚨 **E il recupero è dieci volte più rapido del consumo**: si perde
       * allerta piano stando svegli e la si riprende in fretta dormendo. È il
       * motivo per cui due ore di pisolino contano tanto.
       */
      expect(
        ModelloDellaReattivita.recuperoSonno,
        greaterThan(ModelloDellaReattivita.decadimentoVeglia * 5),
      );
    });

    test('l\'inerzia svanisce in un paio d\'ore', () {
      final subito = ModelloDellaReattivita.inerzia(0);
      final dopoUnOra = ModelloDellaReattivita.inerzia(1);
      final dopoDue = ModelloDellaReattivita.inerzia(2);

      expect(subito, closeTo(ModelloDellaReattivita.inerziaAlRisveglio, 0.001));
      expect(dopoUnOra.abs(), lessThan(subito.abs() * 0.3));
      expect(dopoDue.abs(), lessThan(0.35));
    });

    test('⚠️ il pasto è una campana, non un gradino', () {
      double a(double ore) => ModelloDellaReattivita.dopoIlPasto(
        oreDalPasto: ore,
        kcalDelPasto: 800,
      );

      // 💡 All'istante del pasto non è ancora successo niente…
      expect(a(0), closeTo(0, 0.001));

      // …il minimo è a metà strada…
      expect(a(1.5), lessThan(a(0.5)));
      expect(a(1.5), lessThan(a(2.5)));

      // …e a tre ore è passata.
      expect(a(3), closeTo(0, 0.001));

      // ⛔ E fuori finestra non pesa: non si inventa una digestione infinita.
      expect(a(5), 0);
    });

    test('🚨 un pasto grosso pesa più di uno piccolo', () {
      final abbondante = ModelloDellaReattivita.dopoIlPasto(
        oreDalPasto: 1.5,
        kcalDelPasto: 1200,
      );

      final leggero = ModelloDellaReattivita.dopoIlPasto(
        oreDalPasto: 1.5,
        kcalDelPasto: 200,
      );

      expect(abbondante, lessThan(leggero));
    });

    test('⛔ senza sapere quando si è mangiato non si inventa niente', () {
      expect(
        ModelloDellaReattivita.dopoIlPasto(oreDalPasto: null, kcalDelPasto: 800),
        0,
      );
    });
  });

  group('la fisiologia modifica, non decide', () {
    test('🚨 il battito va INVERTITO', () {
      /*
       * ⚠️ È l'errore di segno più facile da fare qui dentro, ed è lo stesso
       * che `IndiciDiForma` documenta: darebbe una reattività che sale proprio
       * quando dovrebbe scendere.
       */
      final battitoAlto = ModelloDellaReattivita.calcola(
        oraDecimale: 12,
        oreSveglio: 5,
        oreDormite: 8,
        zBattito: 1.5,
      ).valore;

      final battitoBasso = ModelloDellaReattivita.calcola(
        oraDecimale: 12,
        oreSveglio: 5,
        oreDormite: 8,
        zBattito: -1.5,
      ).valore;

      expect(battitoAlto, lessThan(battitoBasso));
    });

    test('l\'HRV alto è una buona notizia', () {
      final alto = ModelloDellaReattivita.calcola(
        oraDecimale: 12,
        oreSveglio: 5,
        oreDormite: 8,
        zHrv: 1.5,
      ).valore;

      final basso = ModelloDellaReattivita.calcola(
        oraDecimale: 12,
        oreSveglio: 5,
        oreDormite: 8,
        zHrv: -1.5,
      ).valore;

      expect(alto, greaterThan(basso));
    });

    test('⚠️ il carico conta SOLO in negativo', () {
      final base = ModelloDellaReattivita.calcola(
        oraDecimale: 12,
        oreSveglio: 5,
        oreDormite: 8,
      ).valore;

      final tanto = ModelloDellaReattivita.calcola(
        oraDecimale: 12,
        oreSveglio: 5,
        oreDormite: 8,
        zCarico: 2,
      ).valore;

      final poco = ModelloDellaReattivita.calcola(
        oraDecimale: 12,
        oreSveglio: 5,
        oreDormite: 8,
        zCarico: -2,
      ).valore;

      expect(tanto, lessThan(base));

      /*
       * 💡 **Non allenarsi non rende più reattivi**: rende meno allenati, che è
       * un'altra cosa e la dice la Stanchezza.
       */
      expect(poco, closeTo(base, 0.001));
    });

    test('🚨 la fisiologia non può ribaltare il modello', () {
      /*
       * ⛔ Un HRV strepitoso non deve rendere reattivo qualcuno che è sveglio da
       * venti ore alle quattro di notte: il modello descrive la fisiologia
       * umana, i sensori descrivono la giornata di oggi.
       */
      final notteFonda = ModelloDellaReattivita.calcola(
        oraDecimale: 4,
        oreSveglio: 20,
        oreDormite: 4,
        zHrv: 2,
        zBattito: -2,
      ).valore;

      final pomeriggio = ModelloDellaReattivita.calcola(
        oraDecimale: 16,
        oreSveglio: 8,
        oreDormite: 8,
        zHrv: -2,
        zBattito: 2,
      ).valore;

      expect(notteFonda, lessThan(pomeriggio));
    });
  });

  group('la scala', () {
    test('sta sempre fra 0 e 100', () {
      for (final ora in [0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 23.5]) {
        for (final sveglio in [0.0, 1.0, 8.0, 16.0, 30.0]) {
          final v = ModelloDellaReattivita.calcola(
            oraDecimale: ora,
            oreSveglio: sveglio,
            oreDormite: 3,
            zHrv: -2,
            zBattito: 2,
            zCarico: 2,
          ).valore;

          expect(v, inInclusiveRange(0, 100));
        }
      }
    });

    test('💡 una giornata normale sta nella metà alta', () {
      /*
       * ⚠️ Non è pignoleria: se una persona che ha dormito otto ore e sta in
       * piedi da cinque risultasse a 30, la scala direbbe che va male a
       * chiunque — e un indice che dice sempre «male» smette di essere letto.
       */
      final normale = ModelloDellaReattivita.calcola(
        oraDecimale: 12,
        oreSveglio: 5,
        oreDormite: 8,
      ).valore;

      expect(normale, greaterThan(50));
    });
  });
}
