import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/limiti_delle_schede.dart';
import 'package:training_companion/src/features/training/training_controller.dart';

/// Il limite delle schede per chi non è abbonato — 3b-C.6, 25/08/2026.
///
/// 📌 *«un utente che non sia abbonato o non abbia l'ai illimitata possa avere
/// solamente 3 schede (le ultime 3 per data di creazione, le altre le deve
/// vedere disabilitate)»* e *«possono essere solo schede a un giorno singolo»*.
void main() {
  WorkoutPlan scheda(int id, {int giorni = 1}) => WorkoutPlan(
    id: id,
    name: 'Scheda $id',
    exercisesCount: 4,
    giorni: giorni,
  );

  /// ⚠️ **Già in ordine di creazione, dalla più recente**: è così che le passa
  /// `schedeUniteProvider`, e il criterio «le ultime tre» dipende da quello.
  final tre = [scheda(1), scheda(2), scheda(3)];
  final cinque = [scheda(1), scheda(2), scheda(3), scheda(4), scheda(5)];

  group('💳 chi è abbonato non ha limiti', () {
    test('con l\'AI illimitata non si blocca niente', () {
      expect(
        schedeBloccate(schede: cinque, illimitata: true, abbonato: true),
        isEmpty,
      );
    });

    /// 🚨 **Se non si sa, non si blocca.** Il flag arriva dalla rete: un errore
    /// lì non deve nascondere le schede a chi le ha pagate. ⛔ Meglio un limite
    /// che non scatta che un abbonato chiuso fuori dai propri allenamenti.
    test('e se il flag non è arrivato, nemmeno', () {
      expect(
        schedeBloccate(schede: cinque, illimitata: null, abbonato: null),
        isEmpty,
      );
    });
  });

  /// ══ 🚨 DUE CONDIZIONI, NON UNA ═══════════════════════════════════════
  ///
  /// 📌 *«ovviamente AI illimitata e abbonato sono due cose diverse, non va bene
  /// che siano trattati come una cosa singola»*.
  ///
  /// ⛔ Le avevo trattate come una sola, appoggiandomi al fatto che **oggi**
  /// l'abbonamento concede la quota illimitata. Era un'osservazione sul
  /// presente, non una definizione: il giorno in cui si vendesse un pacchetto AI
  /// senza abbonamento, quella riga avrebbe sbagliato **in silenzio**.
  group('🔀 e sono due cose diverse', () {
    /// 💡 La regola detta dal committente: *«non sia abbonato **o** non abbia
    /// l'ai illimitata»* → servono **tutte e due** per non avere il limite.
    test('la sola AI illimitata non basta', () {
      expect(
        schedeBloccate(schede: cinque, illimitata: true, abbonato: false),
        isNotEmpty,
      );
    });

    test('e nemmeno il solo abbonamento', () {
      expect(
        schedeBloccate(schede: cinque, illimitata: false, abbonato: true),
        isNotEmpty,
      );
    });

    test('servono tutte e due', () {
      expect(
        schedeBloccate(schede: cinque, illimitata: true, abbonato: true),
        isEmpty,
      );
    });

    /// ⚠️ **Ciascuna, se non si sa, non blocca.** Oggi `abbonato` arriva sempre
    /// `null` perché il server non lo manda: il limite deve continuare a
    /// funzionare sull'altra condizione invece di spegnersi.
    test('e quella che non si sa lascia decidere alla sorella', () {
      expect(
        schedeBloccate(schede: cinque, illimitata: false, abbonato: null),
        isNotEmpty,
        reason: 'oggi e questo il caso vero',
      );

      expect(
        schedeBloccate(schede: cinque, illimitata: null, abbonato: null),
        isEmpty,
        reason: 'senza sapere niente non si blocca niente',
      );
    });
  });

  group('🔒 chi non è abbonato ne usa tre', () {
    test('con tre schede non si blocca niente', () {
      expect(
        schedeBloccate(schede: tre, illimitata: false, abbonato: true),
        isEmpty,
      );
    });

    /// 💡 Le **ultime tre**: le prime della lista, che arriva ordinata dalla più
    /// recente.
    test('con cinque, le due più vecchie si bloccano', () {
      final bloccate = schedeBloccate(
        schede: cinque,
        illimitata: false,
        abbonato: true,
      );

      expect(bloccate.keys.toSet(), {4, 5});
      expect(bloccate[4], MotivoBlocco.troppeSchede);
    });
  });

  group('📅 e solo a giorno singolo', () {
    test('una scheda a più giorni è bloccata comunque', () {
      final bloccate = schedeBloccate(
        schede: [scheda(1, giorni: 3)],
        illimitata: false,
        abbonato: true,
      );

      expect(bloccate[1], MotivoBlocco.piuGiorni);
    });

    /// 🚨 **E il posto lo occupa comunque** — correzione del committente:
    /// *«Una scheda a più giorni certo che occupa uno slot scheda»*.
    ///
    /// ⛔ Saltare il conteggio vorrebbe dire che una scheda in più non costa
    /// niente finché è multi-giorno: chi ne accumula dieci avrebbe ancora tutti
    /// e tre i posti liberi.
    test('e il posto lo occupa lo stesso', () {
      final bloccate = schedeBloccate(
        schede: [scheda(1, giorni: 4), scheda(2), scheda(3), scheda(4)],
        illimitata: false,
        abbonato: true,
      );

      expect(bloccate[1], MotivoBlocco.piuGiorni);
      expect(
        bloccate[4],
        MotivoBlocco.troppeSchede,
        reason: 'la quarta e fuori dai tre posti, multi-giorno o no',
      );
      expect(bloccate.keys.toSet(), {1, 4});
    });

    /// 📌 *«un deficit piccolo»*, dichiarato e accettato: tre schede a più
    /// giorni lasciano senza schede usabili finché non se ne cancella una.
    test('e tre multi-giorno lasciano senza niente da usare', () {
      final bloccate = schedeBloccate(
        schede: [
          scheda(1, giorni: 2),
          scheda(2, giorni: 3),
          scheda(3, giorni: 2),
        ],
        illimitata: false,
        abbonato: true,
      );

      expect(bloccate.length, 3);
      expect(bloccate.values.every((m) => m == MotivoBlocco.piuGiorni), isTrue);
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
