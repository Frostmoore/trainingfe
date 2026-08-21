import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/calorie_allenamento.dart';

/// Le calorie di un allenamento, in Dart — FASE 11.2, 21/08/2026.
///
/// ══ 🚨 QUESTO FILE PROVA UN **TRASPORTO** ═════════════════════════════════
///
/// 📌 Regola del piano: *«trasportare, non reinventare»*. Il calcolo veniva da
/// `trainingbe/app/Services/Training/WorkoutCalorieService.php`, e i numeri qui
/// sotto sono **gli stessi** dei test PHP che lo coprivano
/// (`tests/Feature/Api/WorkoutApiTest.php`):
///
/// | Caso | Atteso | Da dove viene |
/// |---|---|---|
/// | MET 5.0 × 80 kg × 1 h | **400** | `an_estimate_is_produced_on_finish` |
/// | MET 5.0 × 75 kg × 0 h | **0** | `a_session_without_sets_still_has_a_number` |
///
/// ⚠️ **Se uno di questi cambia è un difetto, non un arrotondamento diverso.**
/// È l'unico modo di accorgersi di aver tradotto male una formula che continua
/// a dare numeri credibili.
void main() {
  group('la formula', () {
    test('MET 5.0 × 80 kg × 1 h = 400 — lo stesso numero del server', () {
      expect(
        CalorieAllenamento.formula(
          durata: const Duration(hours: 1),
          kg: 80,
          metMedio: 5,
        ),
        400,
      );
    });

    test('durata zero vale zero, non un numero a caso', () {
      // ⛔ Non è un caso limite teorico: è la seduta aperta e chiusa per
      // sbaglio nello stesso minuto.
      expect(
        CalorieAllenamento.formula(durata: Duration.zero, kg: 75, metMedio: 5),
        0,
      );
    });

    test('una durata negativa non produce calorie negative', () {
      expect(
        CalorieAllenamento.formula(
          durata: const Duration(minutes: -30),
          kg: 75,
          metMedio: 5,
        ),
        0,
      );
    });

    test('i minuti contano, non solo le ore', () {
      // 5.0 × 80 × 0.5 = 200. 🚨 Il PHP usava `durationMinutes() / 60`: qui si
      // parte dai secondi, e mezz'ora deve dare esattamente la metà.
      expect(
        CalorieAllenamento.formula(
          durata: const Duration(minutes: 30),
          kg: 80,
          metMedio: 5,
        ),
        200,
      );
    });
  });

  group('il MET medio', () {
    test('senza esercizi con MET vince il ripiego', () {
      // ⚠️ È il caso di una seduta di soli esercizi scritti a mano dalla
      // palestra, che un MET non ce l'hanno.
      expect(CalorieAllenamento.metMedio(const []), CalorieAllenamento.met);
      expect(
        CalorieAllenamento.metMedio(const [null, null]),
        CalorieAllenamento.met,
      );
    });

    test('è la media dei MET veri, non di tutti', () {
      /*
       * 🚨 I `null` **non entrano nella media**: contarli come zero
       * abbasserebbe il risultato di una seduta mista — quattro esercizi con
       * MET 6.0 e uno senza darebbero 4.8 invece di 6.0, cioè un deficit
       * inventato del 20%.
       */
      expect(CalorieAllenamento.metMedio(const [6, null, 6]), 6.0);
      expect(CalorieAllenamento.metMedio(const [3, 9]), 6.0);
    });

    test('uno zero o un negativo si scartano come un null', () {
      // ⚠️ Un MET di zero non esiste: è un dato sbagliato, non un esercizio
      // che non fa bruciare niente.
      expect(CalorieAllenamento.metMedio(const [0, 8]), 8.0);
      expect(CalorieAllenamento.metMedio(const [-3, 8]), 8.0);
      expect(CalorieAllenamento.metMedio(const [0]), CalorieAllenamento.met);
    });
  });

  group('il numero da mostrare', () {
    test('quello salvato vince sulla formula', () {
      // 🚨 Qualunque ne sia la fonte: se c'è un numero salvato, quello è il
      // numero. La formula è il ripiego, non l'arbitro.
      expect(
        CalorieAllenamento.kcalDi(
          kcalSalvate: 450,
          durata: const Duration(hours: 1),
          kg: 80,
          metDelleSerie: const [5],
        ),
        450,
      );
    });

    test('senza numero salvato si applica la formula', () {
      expect(
        CalorieAllenamento.kcalDi(
          kcalSalvate: null,
          durata: const Duration(hours: 1),
          kg: 80,
          metDelleSerie: const [5],
        ),
        400,
      );
    });

    test('una seduta senza serie vale comunque la durata', () {
      // 💡 Chi si è allenato senza segnare niente ha comunque bruciato
      // qualcosa: MET di ripiego 5.0 × 75 kg × 1 h = 375.
      expect(
        CalorieAllenamento.kcalDi(
          kcalSalvate: null,
          durata: const Duration(hours: 1),
          kg: CalorieAllenamento.pesoDiRipiego,
          metDelleSerie: const [],
        ),
        375,
      );
    });
  });

  group('le bruciate del giorno', () {
    test('🚨 il valore a mano VINCE e NON si somma', () {
      /*
       * ⚠️ È una dichiarazione complessiva («oggi ho bruciato 800»), non un
       * contributo. Sommarlo alle sedute raddoppierebbe la giornata di chi
       * corregge il numero **dopo** essersi allenato — e 1.200 al posto di 800
       * resta un numero credibile, quindi nessuno se ne accorge.
       */
      expect(
        CalorieAllenamento.bruciateDelGiorno(
          aMano: 800,
          kcalDelleSedute: const [400],
        ),
        800,
      );
    });

    test('senza valore a mano si sommano le sedute', () {
      expect(
        CalorieAllenamento.bruciateDelGiorno(
          aMano: null,
          kcalDelleSedute: const [400, 250],
        ),
        650,
      );
    });

    test('uno zero DICHIARATO è una dichiarazione, non un\'assenza', () {
      /*
       * 🚨 La distinzione che questo progetto sbaglia di continuo (vedi il
       * difetto O.D.4 delle calorie attive). ⚠️ Qui `0` significa «oggi fermo»
       * e vince come qualunque altro numero: non è «non lo so».
       */
      expect(
        CalorieAllenamento.bruciateDelGiorno(
          aMano: 0,
          kcalDelleSedute: const [400],
        ),
        0,
      );
    });

    test('nessuna seduta e nessuna dichiarazione fa zero', () {
      expect(
        CalorieAllenamento.bruciateDelGiorno(
          aMano: null,
          kcalDelleSedute: const [],
        ),
        0,
      );
    });
  });
}
