import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/forma/indice_di_effetto.dart';

/// Il **Training Effect Index** — 07/09/2026.
///
/// ══ 🚨 COSA DIFENDONO QUESTI TEST ════════════════════════════════════════
///
/// Le **due ancore** da cui esce la curva, prima di tutto: se un giorno qualcuno
/// ritocca `esponente` o `coefficiente` per far venire un numero più bello, qui
/// diventa rosso — ed è l'unico modo di accorgersene, perché un TEI sbagliato
/// resta un numero fra 0 e 100 che sembra sensato.
void main() {
  DateTime alle(int giorno, int ora, [int minuto = 0]) =>
      DateTime(2026, 9, giorno, ora, minuto);

  /// Un battito ogni [passo] minuti, per [minuti] minuti, a [bpm].
  List<BattitoNelTempo> serie({
    required int giorno,
    required int oraInizio,
    required int minuti,
    required double bpm,
    int passo = 5,
  }) => [
    for (var m = 0; m < minuti; m += passo)
      BattitoNelTempo(
        bpm: bpm,
        quando: alle(giorno, oraInizio).add(Duration(minutes: m)),
      ),
  ];

  group('le due ancore, che sono la ragione dei numeri', () {
    /*
     * 📌 *«only 40 minutes of high-intensity PA (~85% of the heart rate reserve)
     * is needed to obtain 100 PAI»* — l'affermazione principale pubblicata.
     */
    test('🚨 40 minuti all\'85% della riserva fanno ~100', () {
      final punti = ModelloDiEffetto.puntiAlMinuto(0.85) * 40;

      expect(punti, closeTo(100, 5));
    });

    /*
     * 📌 La raccomandazione OMS: 150 minuti a settimana di attività moderata.
     * Il PAI è dichiaratamente allineato a quella soglia.
     */
    test('🚨 150 minuti al 50% fanno ~100', () {
      final punti = ModelloDiEffetto.puntiAlMinuto(0.50) * 150;

      expect(punti, closeTo(100, 5));
    });

    test('⛔ sotto la soglia non si accumula niente', () {
      expect(ModelloDiEffetto.puntiAlMinuto(0.30), 0);
      expect(ModelloDiEffetto.puntiAlMinuto(0.10), 0);

      // 💡 Se contasse, il TEI lo farebbe anche chi cammina fino al bar.
      expect(ModelloDiEffetto.puntiAlMinuto(0.29), 0);
    });

    test('💡 la curva cresce più che proporzionalmente', () {
      /*
       * 🚨 È il senso di tutta la misura: dieci minuti forti valgono più di
       * venti blandi. ⛔ Con una curva lineare il TEI premierebbe il tempo, non
       * l'intensità — cioè direbbe una cosa diversa da quella che promette.
       */
      final forte = ModelloDiEffetto.puntiAlMinuto(0.80) * 10;
      final blando = ModelloDiEffetto.puntiAlMinuto(0.45) * 20;

      expect(forte, greaterThan(blando));
    });
  });

  group('la riserva, che è ciò che rende il numero personale', () {
    test('🚨 NON è «battito diviso massimo»', () {
      /*
       * ⛔ È l'errore che rende l'indice inutile: due persone con lo stesso
       * battito e un riposo diverso stanno facendo due sforzi diversi.
       */
      final allenato = ModelloDiEffetto.riserva(
        bpm: 130,
        aRiposo: 45,
        massima: 190,
      );

      final sedentario = ModelloDiEffetto.riserva(
        bpm: 130,
        aRiposo: 75,
        massima: 190,
      );

      /*
       * 🚨 **Il rapporto grezzo sarebbe IDENTICO**: 130/190 per tutti e due.
       * È questa la cosa che il test difende — che due persone diverse allo
       * stesso battito non ricevano lo stesso punteggio.
       */
      expect(allenato, isNot(closeTo(sedentario, 0.01)));

      /*
       * ⚠️ **E la direzione è questa, non l'opposto**, per quanto sorprenda: con
       * un riposo a 45 e un massimo a 190 la riserva è larga 145, e arrivare a
       * 130 vuol dire averne usata il 59%. Con un riposo a 75 la riserva è larga
       * 115, e 130 ne usa il 48%.
       *
       * 💡 `%HRR` non misura «quanto fatico rispetto a quanto sono allenato»:
       * misura **dove sto dentro il mio intervallo utile**. ⛔ Averlo scritto al
       * contrario, la prima volta, ha fatto diventare rosso questo test — che è
       * esattamente il suo mestiere.
       */
      expect(allenato, greaterThan(sedentario));
    });

    test('⛔ un riposo sopra il massimo non fa esplodere niente', () {
      expect(ModelloDiEffetto.riserva(bpm: 150, aRiposo: 200, massima: 190), 0);
    });

    test('la massima usa Tanaka, non 220 meno l\'età', () {
      // 💡 A 30 anni: 208 − 21 = 187, non 190.
      expect(ModelloDiEffetto.frequenzaMassima(eta: 30), closeTo(187, 0.01));

      // ⚠️ E una massima misurata batte sempre la stima.
      expect(ModelloDiEffetto.frequenzaMassima(eta: 30, misurata: 196), 196);
    });
  });

  group('la finestra di sette giorni', () {
    test('🚨 il tetto è GIORNALIERO, non sul totale', () {
      /*
       * ⛔ Applicarlo alla somma lascerebbe passare una gara da 300 punti in un
       * giorno solo — cioè esattamente il caso per cui il tetto esiste.
       */
      final gara = ModelloDiEffetto.calcola(
        campioni: serie(giorno: 7, oraInizio: 8, minuti: 240, bpm: 170),
        aRiposo: 50,
        eta: 30,
        adesso: alle(7, 23),
      );

      expect(gara.punti, closeTo(ModelloDiEffetto.tettoAlGiorno, 0.01));
      expect(
        gara.perGiorno.last,
        closeTo(ModelloDiEffetto.tettoAlGiorno, 0.01),
      );
    });

    test('💡 lo stesso sforzo spalmato su più giorni rende di più', () {
      /*
       * 🚨 È una conseguenza voluta del tetto: il TEI premia **l'abitudine**,
       * non la giornata eroica. E va detto, perché a qualcuno sembrerà un
       * difetto.
       */
      final tuttoInUnGiorno = ModelloDiEffetto.calcola(
        campioni: serie(giorno: 7, oraInizio: 8, minuti: 180, bpm: 165),
        aRiposo: 50,
        eta: 30,
        adesso: alle(7, 23),
      );

      final spalmato = ModelloDiEffetto.calcola(
        campioni: [
          for (final g in [3, 4, 5, 6, 7])
            ...serie(giorno: g, oraInizio: 8, minuti: 36, bpm: 165),
        ],
        aRiposo: 50,
        eta: 30,
        adesso: alle(7, 23),
      );

      expect(spalmato.punti, greaterThan(tuttoInUnGiorno.punti));
    });

    test('⚠️ quello che è più vecchio di sette giorni esce dalla finestra', () {
      final c = ModelloDiEffetto.calcola(
        campioni: serie(giorno: 1, oraInizio: 8, minuti: 60, bpm: 170),
        aRiposo: 50,
        eta: 30,
        // 💡 Il giorno 1 sta a nove giorni di distanza: fuori.
        adesso: alle(10, 12),
      );

      expect(c.punti, 0);
    });
  });

  group('quando NON si può dire niente', () {
    test('🚨 un battito ogni mezz\'ora non è una misura', () {
      /*
       * ⛔ Il conto esce lo stesso, e viene basso: si direbbe «sei fermo» a chi
       * magari ha corso, solo perché l'orologio non stava guardando. 💡 È la
       * stessa regola per cui `calorieAttive` a `null` non diventa zero.
       */
      final rado = ModelloDiEffetto.calcola(
        campioni: serie(
          giorno: 7,
          oraInizio: 8,
          minuti: 60 * 10,
          bpm: 150,
          passo: 30,
        ),
        aRiposo: 50,
        eta: 30,
        adesso: alle(7, 23),
      );

      expect(rado.affidabile, isFalse);
    });

    test('💡 un battito ogni cinque minuti sì', () {
      final fitto = ModelloDiEffetto.calcola(
        campioni: serie(giorno: 7, oraInizio: 8, minuti: 300, bpm: 150),
        aRiposo: 50,
        eta: 30,
        adesso: alle(7, 23),
      );

      expect(fitto.affidabile, isTrue);
    });

    test('⛔ senza campioni non si inventa niente', () {
      final niente = ModelloDiEffetto.calcola(
        campioni: const [],
        aRiposo: 50,
        eta: 30,
        adesso: alle(7, 23),
      );

      expect(niente.punti, 0);
      expect(niente.affidabile, isFalse);
      expect(niente.minutiUtili, 0);
    });

    test('🚨 un buco lungo non vale tutte le ore che dura', () {
      /*
       * ⛔ Senza il tetto sulla durata, l'ultimo battito prima di togliersi
       * l'orologio varrebbe tutte le ore in cui è rimasto sul comodino: una
       * corsa di dieci minuti diventerebbe una corsa di otto ore.
       */
      final conBuco = ModelloDiEffetto.calcola(
        campioni: [
          BattitoNelTempo(bpm: 170, quando: alle(7, 8)),
          BattitoNelTempo(bpm: 60, quando: alle(7, 20)),
        ],
        aRiposo: 50,
        eta: 30,
        adesso: alle(7, 23),
      );

      // 💡 Al massimo dieci minuti a 170, non dodici ore.
      expect(
        conBuco.minutiUtili,
        lessThanOrEqualTo(ModelloDiEffetto.minutiFraCampioni),
      );
    });
  });
}
