import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/health/dati_salute.dart';
import 'package:training_companion/src/features/health/timeline_sonno.dart';

/// La notte non può durare più di sé stessa — 23/08/2026.
///
/// ══ 🚨 IL DIFETTO CHE QUESTI TEST CHIUDONO ════════════════════════════════
///
/// 📌 Il committente, guardando la schermata: *«dimmi che porcoddio di calcolo
/// ha fatto?»*.
///
/// ⚠️ L'app diceva **11h 29 di sonno dentro una finestra di 8h 49**, perché
/// sommava i campioni uno per uno — e `SLEEP_ASLEEP`, la fase generica, si
/// sovrappone a quelle dettagliate.
///
/// 🚨 **Il numero era plausibile**, e nessun errore lo segnalava. L'unico modo
/// di accorgersene era fare la sottrazione a mano.
void main() {
  DateTime t(int ora, int minuto) => DateTime(2026, 8, 23, ora, minuto);

  ({DateTime da, DateTime a, FaseSonno fase}) c(
    int daOra,
    int daMin,
    int aOra,
    int aMin,
    FaseSonno fase,
  ) => (da: t(daOra, daMin), a: t(aOra, aMin), fase: fase);

  int minutiDi(List<SegmentoSonno> s, FaseSonno fase) =>
      s.where((x) => x.fase == fase).fold(0, (tot, x) => tot + x.minuti);

  group('l invariante', () {
    test('la somma non supera mai la durata della notte', () {
      /*
       * 🚨 **Questa è LA proprietà**, e prima non valeva. Tutto il resto è
       * dettaglio: se la somma dei segmenti sta dentro la finestra, il difetto
       * del 23/08 non può ripresentarsi, da qualunque sovrapposizione arrivi.
       */
      final segmenti = TimelineSonno.appiattisci([
        c(3, 0, 11, 0, FaseSonno.leggero),
        c(3, 30, 5, 0, FaseSonno.profondo),
        c(6, 0, 7, 0, FaseSonno.rem),
        c(8, 0, 8, 20, FaseSonno.sveglio),
        // Un secondo campione generico che copre di nuovo mezza notte.
        c(3, 0, 7, 30, FaseSonno.leggero),
      ]);

      final totale = segmenti.fold(0, (tot, s) => tot + s.minuti);
      final finestra = segmenti.last.a.difference(segmenti.first.da).inMinutes;

      expect(totale, lessThanOrEqualTo(finestra));
      expect(totale, 480, reason: 'dalle 3 alle 11 sono otto ore piene');
    });

    test('due segmenti non si accavallano mai', () {
      final segmenti = TimelineSonno.appiattisci([
        c(0, 0, 8, 0, FaseSonno.leggero),
        c(1, 0, 2, 0, FaseSonno.profondo),
        c(1, 30, 3, 0, FaseSonno.rem),
      ]);

      for (var i = 0; i < segmenti.length - 1; i++) {
        expect(
          segmenti[i].a.isAfter(segmenti[i + 1].da),
          isFalse,
          reason: 'il segmento $i finisce dopo l inizio del successivo',
        );
      }
    });
  });

  group('la notte del 23/08/2026, con i numeri veri', () {
    /*
     * ══ 💡 I NUMERI SONO QUELLI DELLO SCHERMO, NON INVENTATI ══════════════
     *
     * Health Connect aveva **una sola** sessione, da Zepp: `03:02 → 11:51`,
     * cioè **529 minuti**. L'app mostrava `3h11 + 2h07 + 6h11 = 689` di sonno,
     * più `0h39` di sveglio: **728 minuti in 529**.
     *
     * 🚨 La scomposizione che torna al minuto è una sola: togliendo 199 minuti
     * di generico dal leggero, `191 + 127 + 172 + 39 = 529`. Questo test la
     * ricostruisce e pretende quel risultato.
     */
    test('la fase generica non si somma a quelle dettagliate', () {
      final segmenti = TimelineSonno.appiattisci([
        // La notte, descritta a grana grossa: 199 minuti di «dorme».
        c(3, 2, 6, 21, FaseSonno.leggero),

        // E la stessa notte, con le fasi vere.
        c(3, 2, 6, 13, FaseSonno.profondo),
        c(6, 13, 8, 20, FaseSonno.rem),
        c(8, 20, 11, 12, FaseSonno.leggero),
        c(11, 12, 11, 51, FaseSonno.sveglio),
      ]);

      expect(minutiDi(segmenti, FaseSonno.profondo), 191);
      expect(minutiDi(segmenti, FaseSonno.rem), 127);
      expect(
        minutiDi(segmenti, FaseSonno.leggero),
        172,
        reason: 'il generico è sparito dentro le fasi che lo coprivano',
      );
      expect(minutiDi(segmenti, FaseSonno.sveglio), 39);

      final totale = segmenti.fold(0, (tot, s) => tot + s.minuti);

      expect(totale, 529, reason: '03:02 → 11:51: la notte dura quanto dura');
    });
  });

  group('le regole di precedenza', () {
    test('una fase specifica batte il generico', () {
      final segmenti = TimelineSonno.appiattisci([
        c(1, 0, 2, 0, FaseSonno.leggero),
        c(1, 0, 2, 0, FaseSonno.profondo),
      ]);

      expect(segmenti, hasLength(1));
      expect(segmenti.first.fase, FaseSonno.profondo);
      expect(segmenti.first.minuti, 60);
    });

    test('sveglio batte il generico ma cede al profondo', () {
      /*
       * ⚠️ Uno «sveglio» sovrapposto a un «profondo» è una contraddizione del
       * sensore: vince la lettura più specifica. Sovrapposto al generico è lui
       * la lettura più precisa, e vince.
       */
      final conGenerico = TimelineSonno.appiattisci([
        c(1, 0, 2, 0, FaseSonno.leggero),
        c(1, 0, 2, 0, FaseSonno.sveglio),
      ]);

      expect(conGenerico.first.fase, FaseSonno.sveglio);

      final conProfondo = TimelineSonno.appiattisci([
        c(1, 0, 2, 0, FaseSonno.sveglio),
        c(1, 0, 2, 0, FaseSonno.profondo),
      ]);

      expect(conProfondo.first.fase, FaseSonno.profondo);
    });
  });

  group('quello che NON deve fare', () {
    test('una notte senza sovrapposizioni resta identica', () {
      /*
       * 🚨 **La correzione non deve toccare chi stava già bene.** Un orologio
       * che manda solo fasi dettagliate, senza generico, deve vedere gli
       * stessi numeri di prima.
       */
      // ⚠️ Tutto dentro la stessa giornata: l'helper `t()` costruisce le ore
      // sul 23 agosto, e un campione «23:45 → 01:30» finirebbe **prima** di
      // cominciare. Al primo giro questo test era rosso per questo, non per
      // un difetto del codice.
      final segmenti = TimelineSonno.appiattisci([
        c(0, 0, 0, 45, FaseSonno.leggero),
        c(0, 45, 2, 30, FaseSonno.profondo),
      ]);

      expect(segmenti, hasLength(2));
      expect(minutiDi(segmenti, FaseSonno.leggero), 45);
      expect(minutiDi(segmenti, FaseSonno.profondo), 105);
    });

    test('un buco fra due campioni non si riempie', () {
      /*
       * ⛔ Fra le 2 e le 3 il sensore non ha detto niente. Riempire quel vuoto
       * sarebbe l'errore opposto a quello corretto: inventare sonno invece di
       * contarlo due volte.
       */
      final segmenti = TimelineSonno.appiattisci([
        c(1, 0, 2, 0, FaseSonno.leggero),
        c(3, 0, 4, 0, FaseSonno.leggero),
      ]);

      final totale = segmenti.fold(0, (tot, s) => tot + s.minuti);

      expect(totale, 120, reason: 'due ore di dati, non tre di finestra');
    });

    test('due blocchi uguali e attaccati diventano uno', () {
      // 💡 Senza, un profondo attraversato dal confine di un campione generico
      // si spezzerebbe in due e l ipnogramma mostrerebbe una discontinuità che
      // nel sonno non c e stata.
      final segmenti = TimelineSonno.appiattisci([
        c(1, 0, 2, 0, FaseSonno.profondo),
        c(2, 0, 3, 0, FaseSonno.profondo),
      ]);

      expect(segmenti, hasLength(1));
      expect(segmenti.first.minuti, 120);
    });

    test('niente campioni, niente segmenti', () {
      expect(TimelineSonno.appiattisci(const []), isEmpty);
    });

    test('un campione a durata zero si scarta', () {
      expect(
        TimelineSonno.appiattisci([c(1, 0, 1, 0, FaseSonno.leggero)]),
        isEmpty,
      );
    });
  });
}
