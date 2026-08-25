import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/data/serie_prevista.dart';
import 'package:training_companion/src/features/training/data/stima_della_scheda.dart';
import 'package:training_companion/src/features/training/training_controller.dart';

/// La stima di una scheda — 3b-D.16, 25/08/2026.
///
/// 📌 *«una stima del tempo di esecuzione e delle calorie bruciate»*.
///
/// ══ 🚨 COSA DIFENDONO QUESTI TEST ═════════════════════════════════════════
///
/// ⛔ Non che i numeri siano **giusti** — non lo sono, è una stima. Difendono
/// che siano **coerenti**: che una scheda più lunga duri di più, che i recuperi
/// contino, e che i casi limite non producano numeri assurdi.
///
/// ⚠️ Il difetto peggiore qui non è sbagliare di cinque minuti: è dare **zero**
/// a una scheda piena, o due ore a una da tre esercizi. Quelli si vedono, e
/// tolgono fiducia a tutto il resto della schermata.
void main() {
  PlanExercise esercizio({
    required String nome,
    required List<SeriePrevista> serie,
    int? id,
  }) => PlanExercise(id: id ?? 1, name: nome, prescription: '', serie: serie);

  WorkoutPlan scheda(List<PlanExercise> esercizi) => WorkoutPlan(
    id: 1,
    name: 'Prova',
    exercisesCount: esercizi.length,
    exercises: esercizi,
  );

  group('⏱️ il tempo', () {
    /// Una serie da 10 ripetizioni: 30 secondi di lavoro. Con 60 di recupero
    /// fra una e l'altra, tre serie sono 30+60+30+60+30 = 210 secondi.
    ///
    /// ⛔ **Il recupero dopo l'ultima non si conta**: finita l'ultima
    /// ripetizione l'allenamento è finito.
    test('conta il lavoro e i recuperi, ma non l\'ultimo', () {
      final s = stimaDellaScheda(
        scheda: scheda([
          esercizio(
            nome: 'Squat',
            serie: const [
              SeriePrevista(ripetizioni: 10, recuperoSec: 60),
              SeriePrevista(ripetizioni: 10, recuperoSec: 60),
              SeriePrevista(ripetizioni: 10, recuperoSec: 60),
            ],
          ),
        ]),
        catalogo: CatalogoEsercizi.vuoto,
        kg: 80,
      );

      expect(s.durata.inSeconds, 210);
      expect(s.serie, 3);
      expect(s.esercizi, 1);
    });

    /// ⚠️ **Il cambio postazione si conta fra gli esercizi, non prima del
    /// primo**: chi comincia è già dov'è. Due esercizi = un cambio solo.
    test(
      'e un minuto per cambiare postazione, fra un esercizio e l\'altro',
      () {
        final uno = stimaDellaScheda(
          scheda: scheda([
            esercizio(
              nome: 'Squat',
              serie: const [SeriePrevista(ripetizioni: 10)],
            ),
          ]),
          catalogo: CatalogoEsercizi.vuoto,
          kg: 80,
        );

        final due = stimaDellaScheda(
          scheda: scheda([
            esercizio(
              nome: 'Squat',
              serie: const [SeriePrevista(ripetizioni: 10)],
            ),
            esercizio(
              id: 2,
              nome: 'Panca',
              serie: const [SeriePrevista(ripetizioni: 10)],
            ),
          ]),
          catalogo: CatalogoEsercizi.vuoto,
          kg: 80,
        );

        // 30 di lavoro; poi 30 + 60 (recupero di ripiego) + 60 (cambio) + 30.
        expect(uno.durata.inSeconds, 30);
        expect(due.durata.inSeconds, 180);
      },
    );

    /// 💡 L'isometria dice i secondi da sola: un plank da 45s vale 45s, non 45
    /// ripetizioni.
    test('e un plank vale i suoi secondi, non le sue ripetizioni', () {
      final s = stimaDellaScheda(
        scheda: scheda([
          esercizio(nome: 'Plank', serie: const [SeriePrevista(isoSec: 45)]),
        ]),
        catalogo: CatalogoEsercizi.vuoto,
        kg: 80,
      );

      expect(s.durata.inSeconds, 45);
    });

    /// ⛔ Una serie «a cedimento» non ha ripetizioni dichiarate, ma **esiste**:
    /// contarla zero direbbe che quella serie non c'è.
    test('e una serie senza ripetizioni vale comunque qualcosa', () {
      final s = stimaDellaScheda(
        scheda: scheda([
          esercizio(nome: 'Trazioni', serie: const [SeriePrevista()]),
        ]),
        catalogo: CatalogoEsercizi.vuoto,
        kg: 80,
      );

      expect(s.durata.inSeconds, greaterThan(0));
    });

    /// 🚨 «Circa 45 minuti» è una stima; «47 minuti» è una bugia con l'aria di
    /// una misura.
    test('🔢 e i minuti si arrotondano ai cinque', () {
      const StimaDellaScheda(
        durata: Duration(minutes: 47),
        kcal: 300,
        serie: 12,
        esercizi: 4,
      ).minutiTondi.let((v) => expect(v, 45));

      const StimaDellaScheda(
        durata: Duration(minutes: 48),
        kcal: 300,
        serie: 12,
        esercizi: 4,
      ).minutiTondi.let((v) => expect(v, 50));

      /// ⚠️ Mai zero se qualcosa c'è: «circa 0 minuti» su una scheda vera
      /// sembra un difetto.
      const StimaDellaScheda(
        durata: Duration(seconds: 90),
        kcal: 10,
        serie: 1,
        esercizi: 1,
      ).minutiTondi.let((v) => expect(v, 5));
    });
  });

  group('🔥 le calorie', () {
    /// 💡 `MET × kg × ore`, con il MET medio degli esercizi che ce l'hanno.
    test('crescono col peso di chi si allena', () {
      StimaDellaScheda con(double kg) => stimaDellaScheda(
        scheda: scheda([
          esercizio(
            nome: 'Squat',
            serie: List.filled(
              4,
              const SeriePrevista(ripetizioni: 12, recuperoSec: 90),
            ),
          ),
        ]),
        catalogo: CatalogoEsercizi.vuoto,
        kg: kg,
      );

      expect(con(100).kcal!, greaterThan(con(60).kcal!));
    });

    /// ⛔ **`null` e non zero** quando non c'è niente da stimare: uno zero
    /// direbbe «questa scheda non brucia niente», che è un'altra cosa.
    test('e una scheda vuota non dice zero: non dice niente', () {
      final s = stimaDellaScheda(
        scheda: scheda([]),
        catalogo: CatalogoEsercizi.vuoto,
        kg: 80,
      );

      expect(s.kcal, isNull);
      expect(s.serie, 0);
      expect(s.durata, Duration.zero);
    });
  });
}

extension<T> on T {
  void let(void Function(T) f) => f(this);
}
