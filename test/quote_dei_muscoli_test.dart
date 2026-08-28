import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/data/gruppo_muscolare.dart';
import 'package:training_companion/src/features/training/data/serie_prevista.dart';
import 'package:training_companion/src/features/training/muscoli_allenati.dart';
import 'package:training_companion/src/features/training/training_controller.dart';

/// Quanto ho usato ciascun muscolo, in proporzione — 3b-S, 28/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«Deve essere un peso ponderato. Cioè se io alleno al 70% spalle e al 30
/// petto i numeri non possono essere calcolati in questo modo… mi devi fare un
/// calcolo proporzionale di quanto ho usato ciascuno dei muscoli»*.
///
/// ══ 🚨 I DUE DIFETTI CHE QUESTI TEST FISSANO ══════════════════════════════
///
/// 1. ⛔ **Le serie non contavano.** Ogni riga della scheda pesava 1, quindi un
///    esercizio da quattro serie valeva come uno da una. Nessun errore a
///    schermo: la figura si colorava lo stesso, solo sbagliata.
/// 2. ⛔ **Il numero non era una proporzione.** `intensitaDeiMuscoli`
///    normalizza sul massimo: la zona più allenata vale 1 **sempre**, quindi
///    non può dire «il 70% del lavoro è andato alle spalle».
void main() {
  EsercizioDelCatalogo esercizio(
    int id,
    String nome,
    GruppoMuscolare primario,
    List<GruppoMuscolare> secondari,
  ) => EsercizioDelCatalogo(
    id: id,
    nome: nome,
    primario: primario,
    secondari: secondari,
  );

  final catalogo = CatalogoEsercizi([
    esercizio(1, 'Panca piana', GruppoMuscolare.petto, []),
    esercizio(2, 'Alzate laterali', GruppoMuscolare.spalle, []),
    esercizio(3, 'Rematore', GruppoMuscolare.schiena, [GruppoMuscolare.bicipiti]),
  ]);

  /// Una riga di scheda con [quante] serie di quell'esercizio.
  PlanExercise riga(int exerciseId, String nome, int quante) => PlanExercise(
    id: exerciseId,
    name: nome,
    prescription: '',
    exerciseId: exerciseId,
    serie: List.generate(quante, (_) => const SeriePrevista()),
  );

  WorkoutPlan scheda(List<PlanExercise> righe) => WorkoutPlan(
    id: 1,
    name: 'Prova',
    exercisesCount: righe.length,
    exercises: righe,
  );

  group('le serie contano', () {
    /// 🚨 Il difetto vero: quattro serie di panca e una di alzate non possono
    /// dire «petto e spalle uguali».
    test('un esercizio da quattro serie pesa quattro volte uno da una', () {
      final pesi = pesiDellaScheda(
        scheda([riga(1, 'Panca piana', 4), riga(2, 'Alzate laterali', 1)]),
        catalogo,
      );

      expect(pesi[GruppoMuscolare.petto], 4);
      expect(pesi[GruppoMuscolare.spalle], 1);
    });

    /// ⚠️ «Non l'ho ancora compilata» non vuol dire «non allena niente»: una
    /// riga senza serie vale comunque un esercizio, o sparirebbe dalla figura.
    test('una riga senza serie vale almeno una', () {
      final pesi = pesiDellaScheda(
        scheda([riga(1, 'Panca piana', 0)]),
        catalogo,
      );

      expect(pesi[GruppoMuscolare.petto], 1);
    });
  });

  group('le quote sono proporzioni vere', () {
    test('sommano a cento', () {
      final quote = quoteDeiMuscoli(
        pesiDellaScheda(
          scheda([riga(1, 'Panca piana', 3), riga(3, 'Rematore', 2)]),
          catalogo,
        ),
      );

      expect(
        quote.values.fold<double>(0, (a, b) => a + b),
        closeTo(100, 0.001),
      );
    });

    /// 📌 *«se io alleno al 70% spalle e al 30 petto»*: ecco il caso, coi
    /// numeri che lo dicono davvero.
    test('sette serie di spalle e tre di petto fanno 70 e 30', () {
      final quote = quoteDeiMuscoli(
        pesiDellaScheda(
          scheda([riga(2, 'Alzate laterali', 7), riga(1, 'Panca piana', 3)]),
          catalogo,
        ),
      );

      expect(quote[GruppoMuscolare.spalle], closeTo(70, 0.001));
      expect(quote[GruppoMuscolare.petto], closeTo(30, 0.001));
    });

    /// 🚨 **La differenza fra le due misure, in un test.** Con l'intensità la
    /// prima voce vale sempre 1: se la percentuale la si leggesse da lì, dieci
    /// serie di spalle e una di petto direbbero «spalle 100%».
    test('un secondario vale metà di un primario, e si vede nella quota', () {
      final quote = quoteDeiMuscoli(
        pesiDellaScheda(scheda([riga(3, 'Rematore', 2)]), catalogo),
      );

      // schiena 2 × 1 = 2 · bicipiti 2 × 0,5 = 1 · totale 3
      expect(quote[GruppoMuscolare.schiena], closeTo(200 / 3, 0.001));
      expect(quote[GruppoMuscolare.bicipiti], closeTo(100 / 3, 0.001));
    });

    test('senza pesi non si inventa nessuna percentuale', () {
      expect(quoteDeiMuscoli(const {}), isEmpty);
    });
  });

  group('il coefficiente è dichiarato', () {
    /// ⚠️ Il valore ha una fonte — il *fractional set counting*, con una
    /// meta-analisi su 67 studi dietro. 🚨 Questo test non lo difende: lo
    /// **fissa**, così cambiarlo è una decisione e non un incidente.
    test('primario 1, secondario 0,5', () {
      expect(pesoDelPrimario, 1.0);
      expect(pesoDelSecondario, 0.5);
    });
  });
}
