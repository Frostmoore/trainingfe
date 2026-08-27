import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/gruppo_muscolare.dart';
import 'package:training_companion/src/features/training/data/settimana_programmata.dart';

/// La distribuzione della settimana — 3b-I.B, 27/08/2026.
///
/// ══ 🚨 COSA DIFENDE ═══════════════════════════════════════════════════════
///
/// ⛔ **Il determinismo prima di tutto.** Toccare «Distribuisci» due volte con
/// gli stessi ingressi deve dare la stessa settimana: una proposta che cambia da
/// sola è una proposta di cui non ci si fida, e nessuno la userebbe due volte.
///
/// ⚠️ E il fatto che i giorni non si ammucchino: 3 su 7 vuol dire 2-2-3, non
/// 1-1-5. Ammucchiarli sarebbe esattamente il difetto che si vuole evitare.
void main() {
  // Due schede opposte e una che le somiglia entrambe a metà.
  const petto = {GruppoMuscolare.petto: 10.0, GruppoMuscolare.tricipiti: 4.0};
  const gambe = {
    GruppoMuscolare.quadricipiti: 10.0,
    GruppoMuscolare.glutei: 6.0,
  };
  const pettoBis = {GruppoMuscolare.petto: 8.0, GruppoMuscolare.tricipiti: 3.0};

  const pesi = <int, Map<GruppoMuscolare, double>>{
    1: petto,
    2: gambe,
    3: pettoBis,
  };

  group('📐 quanto si somigliano', () {
    test('una scheda somiglia a sé stessa', () {
      expect(somiglianza(petto, petto), closeTo(1, 0.0001));
    });

    /// 💡 Guarda le **proporzioni**, non le quantità: sei esercizi o dodici
    /// sugli stessi muscoli sono la stessa cosa.
    test('e le proporzioni contano più delle quantità', () {
      expect(somiglianza(petto, pettoBis), greaterThan(0.99));
    });

    test('due schede senza muscoli in comune non si somigliano', () {
      expect(somiglianza(petto, gambe), 0);
    });

    /// ⚠️ Una scheda di cui non conosciamo i muscoli non attira né respinge:
    /// verso prudente, perché il dato manca.
    test('e senza muscoli noti la somiglianza è zero', () {
      expect(somiglianza(petto, const {}), 0);
      expect(somiglianza(const {}, const {}), 0);
    });
  });

  group('📅 i giorni scelti', () {
    /// 🚨 **Non ammucchiati.** Con 3 su 7: lunedì, mercoledì, sabato.
    test('si distribuiscono nella settimana', () {
      expect(giorniScelti(3), [0, 2, 5]);
      expect(giorniScelti(2), [0, 4]);
      expect(giorniScelti(4), [0, 2, 4, 5]);
    });

    test('e con sette sono tutti', () {
      expect(giorniScelti(7), [0, 1, 2, 3, 4, 5, 6]);
    });

    /// ⛔ Più di sette giorni non esistono: si taglia, non si gira.
    test('più di sette non esistono', () {
      expect(giorniScelti(10), hasLength(7));
    });

    test('e zero giorni non è un errore', () {
      expect(giorniScelti(0), isEmpty);
      expect(giorniScelti(-3), isEmpty);
    });
  });

  group('🗓️ la distribuzione', () {
    test('mette una scheda per ogni giorno scelto', () {
      final s = distribuisci(schede: [1, 2], quantiGiorni: 2, pesi: pesi);

      expect(s, hasLength(7));
      expect(s.where((x) => x != null), hasLength(2));
    });

    /// 🚨 **Il cuore dell'algoritmo**: due schede che pesano sugli stessi
    /// muscoli non vanno una dopo l'altra.
    test('allontana le schede che si somigliano', () {
      final s = distribuisci(schede: [1, 3, 2], quantiGiorni: 3, pesi: pesi);
      final ordine = s.where((x) => x != null).toList();

      // 1 e 3 sono quasi identiche: fra loro ci deve stare la 2.
      expect(ordine, [1, 2, 3]);
    });

    /// ⛔ Chi ha due schede e si allena quattro volte vuole ABAB, non AB e poi
    /// due giorni di riposo che non ha chiesto.
    test('e le ripete quando sono meno dei giorni', () {
      final s = distribuisci(schede: [1, 2], quantiGiorni: 4, pesi: pesi);
      final ordine = s.where((x) => x != null).toList();

      expect(ordine, [1, 2, 1, 2]);
    });

    /// ⛔ **Mai due giorni di fila la stessa**, se ce n'è un'altra.
    test('non mette mai la stessa scheda due giorni di fila', () {
      final s = distribuisci(schede: [1, 3], quantiGiorni: 4, pesi: pesi);
      final ordine = s.where((x) => x != null).toList();

      for (var i = 1; i < ordine.length; i++) {
        expect(ordine[i], isNot(ordine[i - 1]));
      }
    });

    /// ══ 🚨 IL TEST PIU' IMPORTANTE ══════════════════════════════════════
    ///
    /// Una proposta che cambia da sola non la usa nessuno due volte.
    test('è deterministica: due giri danno la stessa settimana', () {
      final primo = distribuisci(
        schede: [1, 2, 3],
        quantiGiorni: 5,
        pesi: pesi,
      );
      final secondo = distribuisci(
        schede: [1, 2, 3],
        quantiGiorni: 5,
        pesi: pesi,
      );

      expect(primo, secondo);
    });

    /// 💡 A pari merito vince l'ordine dell'utente: è l'unico modo di essere
    /// deterministici senza sembrare arbitrari.
    test('e a pari merito rispetta l\'ordine dell\'elenco', () {
      // 2 e 3 sono entrambe lontanissime da... nessuna: senza pesi tutto vale 0.
      final s = distribuisci(
        schede: [7, 8, 9],
        quantiGiorni: 3,
        pesi: const {},
      );

      expect(s.where((x) => x != null).toList(), [7, 8, 9]);
    });

    test('senza schede la settimana resta vuota', () {
      final s = distribuisci(schede: const [], quantiGiorni: 3, pesi: pesi);

      expect(s.every((x) => x == null), isTrue);
    });

    test('e con zero giorni pure', () {
      final s = distribuisci(schede: [1, 2], quantiGiorni: 0, pesi: pesi);

      expect(s.every((x) => x == null), isTrue);
    });
  });
}
