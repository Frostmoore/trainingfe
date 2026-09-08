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
     * ══ ⛔ LE DUE ANCORE DI PRIMA ERANO SBAGLIATE — 08/09/2026 ═══════════════
     *
     * Erano *«40 min all'85% della **riserva** = 100»* e *«150 min al 50%»*, e
     * la prima l'avevo attribuita al PAI.
     *
     * 🚨 **Il PAI non dice quello.** NTNU/CERG, che il PAI l'ha inventato:
     * *«two sessions totalling one hour of exercise to reach 100 PAI if the
     * intensity is at least 80% of your MAXIMUM heart rate»*.
     *
     * ⚠️ Percentuale della **massima**, non della riserva: due grandezze
     * diverse, e scambiarle sposta l'ancora di venti punti percentuali. 💡 Per
     * una persona tipo (riposo 60, massima 180) l'80% della massima è 144 bpm,
     * cioè il **70% della riserva**.
     */
    test('🚨 60 minuti al 70% della riserva fanno ~100', () {
      final punti = ModelloDiEffetto.puntiAlMinuto(0.70) * 60;

      expect(punti, closeTo(100, 5));
    });

    /*
     * 📌 La stessa fonte: 100 PAI si ottengono con *«60 min di camminata svelta
     * + 40 di bici + 50 di nuoto + 30 di aerobica + 20 di corsa»* — cioè
     * **200 minuti** di attività fra leggera e moderata.
     */
    test('🚨 200 minuti al 50% fanno ~100', () {
      final punti = ModelloDiEffetto.puntiAlMinuto(0.50) * 200;

      expect(punti, closeTo(100, 5));
    });

    test('⛔ sotto la soglia non si accumula niente', () {
      /*
       * ══ 🚨 LA SOGLIA ERA 0.30, E QUEL NUMERO HA PRODOTTO UN 175 ═══════════
       *
       * 📌 Il committente: *«è impossibile che io stia a 175/100, mi sono
       * allenato relativamente poco»*.
       *
       * ⛔ Con riposo 75 e massima 181, il 30% della riserva cade a **107 bpm**:
       * salire le scale, portare la spesa, avere fretta. Il conto ci ha trovato
       * dentro **1.092 minuti in una settimana**.
       *
       * 💡 Il 40% cade a 117 bpm. Lì sotto non si allena nessuno.
       */
      expect(ModelloDiEffetto.puntiAlMinuto(0.40), 0);
      expect(ModelloDiEffetto.puntiAlMinuto(0.35), 0);
      expect(ModelloDiEffetto.puntiAlMinuto(0.10), 0);

      // 🚨 Il valore che prima contava, e che era il difetto.
      expect(
        ModelloDiEffetto.puntiAlMinuto(0.30),
        0,
        reason: 'il 30% della riserva è vita normale, non allenamento',
      );
    });

    test('📉 e i rendimenti decrescenti fanno di 100 il traguardo vero', () {
      /*
       * 📌 *«deve essere una rotazione settimanale in cui 100 è la perfezione»*.
       *
       * 🚨 **Cento grezzi devono fare cento esatti**, o la saturazione starebbe
       * riscalando il traguardo invece di comprimere l'eccesso.
       */
      expect(ModelloDiEffetto.conRendimentiDecrescenti(100), closeTo(100, 0.5));

      // 💡 «È più facile arrivare ai primi 50 che ai secondi 50» — NTNU/CERG.
      expect(ModelloDiEffetto.conRendimentiDecrescenti(50), greaterThan(60));

      // ⛔ E un 175 da una settimana di vita normale non esce più.
      expect(ModelloDiEffetto.conRendimentiDecrescenti(200), lessThan(140));
      expect(ModelloDiEffetto.conRendimentiDecrescenti(10000), lessThan(151));
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

      /*
       * ⚠️ **Il tetto si controlla sul GREZZO, non sul punteggio mostrato** —
       * 08/09/2026. 🚨 Da quando c'è la saturazione i due numeri non coincidono
       * più: 75 grezzi diventano 84 a schermo, ed è giusto così.
       *
       * ⛔ Cercare 75 in `punti` sarebbe provare la saturazione credendo di
       * provare il tetto — un test verde per la ragione sbagliata.
       */
      expect(
        gara.perGiorno.last,
        closeTo(ModelloDiEffetto.tettoAlGiorno, 0.01),
      );

      expect(
        gara.punti,
        closeTo(
          ModelloDiEffetto.conRendimentiDecrescenti(
            ModelloDiEffetto.tettoAlGiorno,
          ),
          0.01,
        ),
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
