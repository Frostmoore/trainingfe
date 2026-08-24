import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/calorie_allenamento.dart';
import 'package:training_companion/src/features/training/data/tipo_scelto.dart';

/// Le calorie stimate entrano nel bilancio — 3b-B.20.7, 25/08/2026.
///
/// ══ 📌 LA CORREZIONE DEL COMMITTENTE ══════════════════════════════════════
///
/// *«se ci sono quelle che arrivano dall'orologio ok, se le inserisco a mano ok,
/// ma se non faccio nessuna delle due cose non vedo proprio perché quelle
/// stimate non dovrebbero entrare nel calcolo»*.
///
/// ⛔ **Aveva ragione, e c'era un buco**: le stime venivano **solo** dalle sedute
/// registrate nell'app. Una corsa vista solo dall'orologio, su cui avevi
/// dichiarato «corsa», non produceva nessuna seduta — quindi non entrava da
/// nessuna parte, e la giornata la contava zero.
void main() {
  group('🔥 la formula', () {
    /// `MET × kg × ore`, la stessa delle sedute.
    test('un\'ora di corsa a 87 kg fa quello che deve', () {
      final corsa = TipoScelto.per('RUNNING')!;

      expect(
        CalorieAllenamento.formula(
          durata: const Duration(hours: 1),
          kg: 87,
          metMedio: corsa.met,
        ),
        (9.8 * 87).round(),
      );
    });

    /// ⛔ Durata nulla → zero, e zero non entra nel bilancio: è l'allenamento
    /// aperto e chiuso per sbaglio nello stesso minuto.
    test('e una durata nulla non produce niente', () {
      expect(
        CalorieAllenamento.formula(
          durata: Duration.zero,
          kg: 87,
          metMedio: 9.8,
        ),
        0,
      );
    });
  });

  group('⚠️ e la precedenza resta quella di sempre', () {
    /// 🚨 **La dichiarazione a mano vince su tutto.** Le stime dal tipo entrano
    /// fra le sedute, cioè **dentro** il ramo che `aMano` scavalca: chi ha
    /// scritto un numero l'ha scritto apposta, e una formula non lo sconfessa.
    test('un numero scritto a mano scavalca le stime', () {
      expect(
        CalorieAllenamento.bruciateDelGiorno(
          aMano: 300,
          kcalDelleSedute: const [500, 200],
        ),
        300,
      );
    });

    /// 💡 E senza dichiarazione le stime si sommano fra loro: due allenamenti
    /// nello stesso giorno sono due allenamenti.
    test('e senza, le stime del giorno si sommano', () {
      expect(
        CalorieAllenamento.bruciateDelGiorno(
          aMano: null,
          kcalDelleSedute: const [500, 200],
        ),
        700,
      );
    });

    /// ⚠️ **Zero dichiarato non è «non lo so»**: è «oggi fermo», e vince.
    test('e uno zero dichiarato è una dichiarazione', () {
      expect(
        CalorieAllenamento.bruciateDelGiorno(
          aMano: 0,
          kcalDelleSedute: const [500],
        ),
        0,
      );
    });
  });
}
