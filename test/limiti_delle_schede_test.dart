import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/limiti_delle_schede.dart';
import 'package:training_companion/src/features/training/training_controller.dart';

/// Il limite delle schede per chi non è abbonato — 3b-C.6, 25/08/2026.
///
/// 📌 *«un utente che non sia abbonato o non abbia l'ai illimitata possa avere
/// solamente 3 schede (le ultime 3 per data di creazione, le altre le deve
/// vedere disabilitate)»* e *«possono essere solo schede a un giorno singolo»*.
void main() {
  WorkoutPlan scheda(int id, {int giorni = 1}) =>
      WorkoutPlan(id: id, name: 'Scheda $id', exercisesCount: 4, giorni: giorni);

  /// ⚠️ **Già in ordine di creazione, dalla più recente**: è così che le passa
  /// `schedeUniteProvider`, e il criterio «le ultime tre» dipende da quello.
  final tre = [scheda(1), scheda(2), scheda(3)];
  final cinque = [scheda(1), scheda(2), scheda(3), scheda(4), scheda(5)];

  group('💳 chi è abbonato non ha limiti', () {
    test('con l\'AI illimitata non si blocca niente', () {
      expect(schedeBloccate(schede: cinque, illimitata: true), isEmpty);
    });

    /// 🚨 **Se non si sa, non si blocca.** Il flag arriva dalla rete: un errore
    /// lì non deve nascondere le schede a chi le ha pagate. ⛔ Meglio un limite
    /// che non scatta che un abbonato chiuso fuori dai propri allenamenti.
    test('e se il flag non è arrivato, nemmeno', () {
      expect(schedeBloccate(schede: cinque, illimitata: null), isEmpty);
    });
  });

  group('🔒 chi non è abbonato ne usa tre', () {
    test('con tre schede non si blocca niente', () {
      expect(schedeBloccate(schede: tre, illimitata: false), isEmpty);
    });

    /// 💡 Le **ultime tre**: le prime della lista, che arriva ordinata dalla più
    /// recente.
    test('con cinque, le due più vecchie si bloccano', () {
      final bloccate = schedeBloccate(schede: cinque, illimitata: false);

      expect(bloccate.keys.toSet(), {4, 5});
      expect(bloccate[4], MotivoBlocco.troppeSchede);
    });
  });

  group('📅 e solo a giorno singolo', () {
    test('una scheda a più giorni è bloccata comunque', () {
      final bloccate = schedeBloccate(
        schede: [scheda(1, giorni: 3)],
        illimitata: false,
      );

      expect(bloccate[1], MotivoBlocco.piuGiorni);
    });

    /// 🚨 **Non occupa uno dei tre posti.** Farla contare vorrebbe dire togliere
    /// un posto usabile per una scheda che comunque non si può usare: chi ha una
    /// scheda a più giorni si ritroverebbe con due schede invece di tre.
    test('e non ruba il posto a una usabile', () {
      final bloccate = schedeBloccate(
        schede: [scheda(1, giorni: 4), scheda(2), scheda(3), scheda(4)],
        illimitata: false,
      );

      expect(bloccate[1], MotivoBlocco.piuGiorni);
      expect(
        bloccate.keys.toSet(),
        {1},
        reason: 'le tre a giorno singolo restano tutte usabili',
      );
    });
  });

  /// ⚠️ La frase la scrive l'enum, non il widget: le schermate che la mostrano
  /// sono due, e due copie divergono alla prima correzione.
  test('ogni motivo sa dire perché', () {
    for (final m in MotivoBlocco.values) {
      expect(m.spiegazione, isNotEmpty);
      expect(m.spiegazione, contains('abbonamento'));
    }
  });
}
