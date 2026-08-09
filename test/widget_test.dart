import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/diary/data/diary_models.dart';

/// A4.1 — la lettura della giornata alimentare.
///
/// 🚨 **Il test che vale di più è quello sui numeri tondi.**
/// Il backend garantisce che i `double` restino `double` anche quando valgono
/// 80,0 — c'è una classe apposta lato server per questo. Ma se quella garanzia
/// venisse meno, `as double` andrebbe in crash **solo su certi valori**: un peso
/// di 80,5 kg funzionerebbe e uno di 80 kg no. Qui si verifica che l'app regga
/// entrambi.
void main() {
  group('DiaryDay', () {
    test('legge una giornata completa', () {
      final day = DiaryDay.fromJson(const {
        'date': '2026-08-10',
        'totals': {'kcal': 1850.5, 'protein': 120.0, 'carbs': 180.0, 'fat': 60.0},
        'targets': {'kcal': 2200.0, 'protein_g': 150, 'carbs_g': 220, 'fat_g': 70},
        'burned': {'kcal': 300, 'source': 'formula'},
        'meals': [
          {
            'meal': 'lunch',
            'label': 'Pranzo',
            'totals': {'kcal': 800.0},
            'entries': [
              {
                'id': 1,
                'description': 'Pasta',
                'meal': 'lunch',
                'grams': 80.0,
                'kcal': 280.0,
                'source': 'ai_text',
              },
            ],
          },
        ],
      });

      expect(day.kcal, 1850.5);
      expect(day.hasTarget, isTrue);
      expect(day.residuoKcal, closeTo(349.5, 0.01));
      expect(day.burnedKcal, 300);
      expect(day.meals.single.entries.single.description, 'Pasta');
    });

    /// 🚨 Numeri interi e decimali devono funzionare entrambi.
    test('regge sia gli interi sia i decimali', () {
      final day = DiaryDay.fromJson(const {
        'date': '2026-08-10',
        // `kcal` intero, `protein` decimale: nella stessa risposta.
        'totals': {'kcal': 1800, 'protein': 120.5, 'carbs': 200, 'fat': 55.0},
        'burned': {'kcal': 0},
        'meals': [],
      });

      expect(day.kcal, 1800.0);
      expect(day.protein, 120.5);
    });

    /// Senza target non si inventa niente: il backend risponde `null` quando
    /// mancano gli ingredienti, e l'app deve saperlo dire invece di mostrare
    /// uno zero che sembra un obiettivo.
    test('senza target non finge di averne uno', () {
      final day = DiaryDay.fromJson(const {
        'date': '2026-08-10',
        'totals': {'kcal': 500},
        'targets': null,
        'burned': {'kcal': 0},
        'meals': [],
      });

      expect(day.hasTarget, isFalse);
      expect(day.targetKcal, isNull);
      expect(day.progresso, 0);
    });

    test('lo sforamento si riconosce', () {
      final day = DiaryDay.fromJson(const {
        'date': '2026-08-10',
        'totals': {'kcal': 2600},
        'targets': {'kcal': 2000},
        'burned': {'kcal': 0},
        'meals': [],
      });

      expect(day.residuoKcal, -600);
      expect(day.progresso, greaterThan(1));
    });
  });

  group('FoodEntry', () {
    test('mostra la quantità come l\'ha scritta l\'utente', () {
      final voce = FoodEntry.fromJson(const {
        'id': 1,
        'description': 'Olio',
        'meal': 'lunch',
        'qty': 2.0,
        'unit': 'cucchiaio',
        'grams': 28.0,
      });

      // «2 cucchiaio», non «28 g»: i grammi sono la verità del calcolo, non
      // quello che la persona ricorda di aver messo nel piatto.
      expect(voce.quantita, '2 cucchiaio');
    });

    test('senza unità ricade sui grammi', () {
      final voce = FoodEntry.fromJson(const {
        'id': 1,
        'description': 'Pollo',
        'meal': 'dinner',
        'grams': 150.0,
      });

      expect(voce.quantita, '150 g');
    });
  });
}
