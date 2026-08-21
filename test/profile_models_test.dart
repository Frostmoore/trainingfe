import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/dashboard_controller.dart';
import 'package:training_companion/src/features/profile/data/profile_models.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';

/// C8/C10/C12 — la lettura delle risposte del server.
///
/// 🚨 Quello che si prova qui è **la distinzione fra assente e zero**, che è la
/// famiglia di difetti che ha già morso questo progetto tre volte: un valore
/// mancante trattato come zero non dà errore, dà un numero sbagliato.
void main() {
  group('profilo', () {
    test('un profilo completo porta i valori derivati', () {
      final p = UserProfile.fromJson({
        'sex': 'm',
        'birthdate': '1988-04-12',
        'age': 38,
        'height_cm': 178,
        'activity_level': 'moderate',
        'goal': 'lose_slow',
        'weight_kg': 84.0,
        'meal_hours': {'breakfast': '07:00', 'dinner': '20:00'},
        'missing': <String>[],
        'derived': {
          'bmi': 26.5,
          'bmr': 1786.5,
          'tdee': 2769.1,
          'target_kcal': 2354,
          'macros': {'protein_g': 188, 'carbs_g': 224, 'fat_g': 78},
        },
        'options': {
          'activity_levels': {'moderate': 'Moderato'},
          'goals': {'lose_slow': 'Dimagrimento graduale'},
        },
      });

      expect(p.isComplete, isTrue);
      expect(p.derived!.targetKcal, 2354);
      expect(p.derived!.proteinG, 188);
      expect(p.activityLevels['moderate'], 'Moderato');
    });

    /// 🚨 `derived` **null** e non zero: un target a zero verrebbe mostrato
    /// come «0 kcal al giorno», che è un consiglio nutrizionale sbagliato, non
    /// un dato mancante.
    test('senza gli ingredienti non c\'è nessun target', () {
      final p = UserProfile.fromJson({
        'missing': ['weight_kg', 'birthdate'],
        'derived': null,
        'meal_hours': <String, String>{},
        'options': <String, dynamic>{},
      });

      expect(p.isComplete, isFalse);
      expect(p.derived, isNull);
      expect(p.missing, ['weight_kg', 'birthdate']);
    });

    test(
      'i campi mancanti hanno un nome leggibile, non quello della colonna',
      () {
        // «manca weight_kg» non si può mostrare a una persona.
        expect(UserProfile.labelFor('weight_kg'), 'il tuo peso');
        expect(UserProfile.labelFor('birthdate'), 'la data di nascita');
      },
    );
  });

  group('serie', () {
    test('le medie portano con sé su quanti giorni sono calcolate', () {
      final s = Series.fromJson({
        'labels': ['01/08', '02/08'],
        'consumed': [2000, 2400],
        'burned': [0, 300],
        'granularity': 'day',
        'averages': {'consumed': 2200, 'burned': 300, 'days_with_data': 2},
      });

      // 🚨 Senza `days_with_data` la media si legge come se fosse su tutto il
      // periodo: «2.200 di media» su due giorni su sette non è lo stesso
      // numero che su sette.
      expect(s.avgConsumed, 2200);
      expect(s.daysWithData, 2);
    });

    test('«tutto lo storico» non ha un periodo precedente', () {
      final s = Series.fromJson({
        'labels': ['08/26'],
        'consumed': [2000],
        'burned': [0],
        'granularity': 'month',
        'can_go_back': false,
      });

      expect(s.canGoBack, isFalse);
      expect(s.granularity, 'month');
    });

    test('una serie di soli zeri è vuota', () {
      final s = Series.fromJson({
        'labels': ['01/08', '02/08'],
        'consumed': [0, 0],
        'burned': [0, 0],
        'granularity': 'day',
      });

      expect(s.vuota, isTrue);
    });
  });

  group('sessione di allenamento', () {
    test('l\'etichetta dice da dove vengono le calorie', () {
      WorkoutSession con(String? fonte) => WorkoutSession.fromJson({
        'id': 1,
        'started_at': '2026-08-10T18:00:00+02:00',
        'is_open': false,
        'kcal': 320,
        'kcal_source': fonte,
      });

      // Senza, chi legge il numero non sa se può sovrascriverlo.
      expect(con('manual').etichettaKcal, 'inserite a mano');
      expect(con('ai').etichettaKcal, 'stima AI');
      expect(con('formula').etichettaKcal, 'stima');
      expect(con(null).etichettaKcal, 'stima');
    });

    test('una sessione senza scheda si chiama «Sessione libera»', () {
      final s = WorkoutSession.fromJson({
        'id': 1,
        'started_at': '2026-08-10T18:00:00+02:00',
        'is_open': true,
      });

      expect(s.titolo, 'Sessione libera');
      expect(s.planId, isNull);
      expect(s.photos, isEmpty);
    });

    test('le foto della sessione arrivano già nell\'elenco', () {
      // È ciò che permette allo storico di mostrare la miniatura senza una
      // chiamata per ogni scheda.
      final s = WorkoutSession.fromJson({
        'id': 1,
        'started_at': '2026-08-10T18:00:00+02:00',
        'is_open': false,
        'photos': [
          {'id': 7, 'url': 'https://esempio.test/api/v1/photos/7/file'},
        ],
      });

      expect(s.photos, hasLength(1));
      expect(s.photos.first.id, 7);
    });
  });
}
