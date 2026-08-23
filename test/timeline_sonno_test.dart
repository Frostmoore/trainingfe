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

  group('la notte del 23/08/2026', () {
    /*
     * ══ ⛔ ATTENZIONE: LA RICOSTRUZIONE A TAVOLINO ERA SBAGLIATA ══════════
     *
     * Prima della correzione lo schermo diceva `3h11 + 2h07 + 6h11` di sonno
     * piu' `0h39` di sveglio: **728 minuti** in una finestra di **529**
     * (`03:02 → 11:51`, una sola sessione di Zepp).
     *
     * 🚨 Avevo dedotto che i 199 di troppo stessero tutti sul leggero, perche'
     * `191 + 127 + 172 + 39 = 529` torna al minuto. ⛔ **Falso**: con la
     * correzione accesa i numeri veri sono `107 + 107 + 285 + 30 = 529`. La
     * sovrapposizione era su **tutte e quattro** le fasi, e anche fra campioni
     * della stessa fase.
     *
     * ⚠️ **Una somma che torna non e' una prova.** Le scomposizioni compatibili
     * con «728 in 529» erano molte, e ne avevo presa una scambiandola per
     * l'unica.
     *
     * 💡 Questo test resta perche' descrive **la forma** del difetto — generico
     * sovrapposto a fasi dettagliate — non i numeri di quella notte. I numeri
     * qui dentro sono inventati apposta per essere leggibili.
     */
    test('la fase generica non si somma a quelle dettagliate', () {
      final segmenti = TimelineSonno.appiattisci([
        // La notte, descritta a grana grossa: tre ore di «dorme».
        c(3, 0, 6, 0, FaseSonno.leggero),

        // E la stessa notte, con le fasi vere.
        c(3, 0, 4, 0, FaseSonno.profondo),
        c(4, 0, 5, 0, FaseSonno.rem),
        c(6, 0, 6, 30, FaseSonno.sveglio),
      ]);

      expect(minutiDi(segmenti, FaseSonno.profondo), 60);
      expect(minutiDi(segmenti, FaseSonno.rem), 60);
      expect(
        minutiDi(segmenti, FaseSonno.leggero),
        60,
        reason: 'del generico resta solo l ora che nessuno copriva',
      );
      expect(minutiDi(segmenti, FaseSonno.sveglio), 30);

      final totale = segmenti.fold(0, (tot, s) => tot + s.minuti);

      expect(totale, 210, reason: '03:00 → 06:30, la notte dura quanto dura');
    });

    test('la stessa notte scritta due volte con i confini spostati', () {
      /*
       * ══ 🚨 QUESTA E' LA CAUSA VERA, LETTA DAI CAMPIONI GREZZI ═══════════
       *
       * ⛔ Non era `SLEEP_ASLEEP`, e non erano due app. E' **l'orologio che
       * scrive la stessa notte due volte**, con i confini spostati di un
       * minuto o due. Una fonte sola, nove coppie su tutte e quattro le fasi.
       *
       * 💡 Le quattro righe qui sotto sono **copiate dal log del telefono**.
       *
       * 🚨 `insertOrIgnore` non poteva vederli: la chiave unica e'
       * `(fonte, iniziatoIl)`, e questi hanno inizi diversi.
       */
      final segmenti = TimelineSonno.appiattisci([
        c(3, 19, 4, 9, FaseSonno.profondo), // 50 min
        c(3, 25, 4, 9, FaseSonno.profondo), // 44 min, stesso sonno
        c(5, 5, 5, 17, FaseSonno.rem), //      12 min
        c(5, 7, 5, 17, FaseSonno.rem), //      10 min, stesso sonno
      ]);

      expect(
        minutiDi(segmenti, FaseSonno.profondo),
        50,
        reason: '50 e 44 sono lo stesso blocco, non 94 minuti',
      );
      expect(minutiDi(segmenti, FaseSonno.rem), 12);
    });

    test('la notte del 23/08 in piccolo: 728 grezzi diventano 529', () {
      /*
       * 💡 Il conto vero, in scala: sui 48 campioni grezzi di quella notte la
       * somma faceva **728** minuti in una finestra di **529**. Dopo
       * l'appiattimento: 285 leggero + 107 profondo + 107 REM + 30 sveglio =
       * **529**, cioe' `03:02 → 11:51` al minuto.
       */
      final segmenti = TimelineSonno.appiattisci([
        c(3, 6, 3, 25, FaseSonno.leggero), // 19
        c(3, 19, 4, 9, FaseSonno.profondo), // 50
        c(3, 25, 4, 9, FaseSonno.profondo), // 44 — doppione
        c(4, 9, 4, 31, FaseSonno.leggero), // 22
        c(4, 30, 4, 57, FaseSonno.profondo), // 27
        c(4, 31, 4, 57, FaseSonno.profondo), // 26 — doppione
      ]);

      final totale = segmenti.fold(0, (tot, s) => tot + s.minuti);

      expect(
        totale,
        111,
        reason: '03:06 → 04:57 sono 111 minuti; i grezzi ne sommavano 188',
      );
      expect(minutiDi(segmenti, FaseSonno.profondo), 77);
      expect(minutiDi(segmenti, FaseSonno.leggero), 34);
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
