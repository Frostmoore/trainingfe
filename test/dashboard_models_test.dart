import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/data/dashboard_models.dart';

/// D5 — la lettura del riepilogo.
///
/// 🚨 Quello che si prova qui è **la lettura delle calorie rispetto all'ora**,
/// che è la regola per cui la stessa cifra racconta due cose opposte, e la
/// distinzione fra dato assente e valore zero.
void main() {
  DashboardSummary con({
    required int oraPercentuale,
    double kcal = 0,
    double? target,
    Map<String, dynamic>? vitals,
    Map<String, dynamic>? sleep,
  }) => DashboardSummary.fromJson({
    'date': '2026-08-10',
    'hour': 12,
    'day_progress_pct': oraPercentuale,
    'nutrition': {
      'totals': {'kcal': kcal, 'protein': 0, 'carbs': 0, 'fat': 0},
      'targets': target == null ? null : {'kcal': target},
      'burned': {'kcal': 0},
      'entries_count': 0,
    },
    'training': {'last_30_days': 0, 'recent': <dynamic>[]},
    'body': <String, dynamic>{},
    'sleep': sleep,
    'vitals': vitals ?? {'has_any': false},
  });

  group('le calorie si leggono rispetto all\'ora', () {
    /// 🚨 **Il cuore di D4/D5.**
    ///
    /// 1.200 kcal su 2.400 a metà mattina sono tantissime; le stesse a fine
    /// giornata sono poche. Senza il confronto con la quota di giornata
    /// passata, la stessa barra racconta due situazioni opposte allo stesso
    /// modo.
    test('le stesse calorie sono «avanti» al mattino e «indietro» la sera', () {
      final mattina = con(oraPercentuale: 15, kcal: 1200, target: 2400);
      final sera = con(oraPercentuale: 90, kcal: 1200, target: 2400);

      // Atteso a quel punto della giornata: 15% di 2400 = 360. Mangiate 1200:
      // 840 kcal avanti.
      expect(mattina.scostamentoRitmo, closeTo(840, 0.1));

      // A sera l'atteso è 2160: 1200 sono 960 kcal indietro.
      expect(sera.scostamentoRitmo, closeTo(-960, 0.1));
    });

    test('senza target non c\'è nessun ritmo da confrontare', () {
      // Un ritmo calcolato su un target inventato sarebbe peggio di nessun
      // ritmo: sembrerebbe un giudizio.
      expect(con(oraPercentuale: 50, kcal: 1200).scostamentoRitmo, isNull);
    });

    test('il residuo esiste solo quando esiste un target', () {
      expect(con(oraPercentuale: 50, kcal: 1000, target: 2400).nutrition.residuo, 1400);
      expect(con(oraPercentuale: 50, kcal: 1000).nutrition.residuo, isNull);
    });
  });

  group('parametri dall\'orologio', () {
    /// 🚨 Un HRV di 42 ms è ottimo per qualcuno e allarmante per un altro.
    /// Conta **solo** lo scostamento dalla media di quella persona.
    test('un HRV molto sotto la propria media è un\'anomalia', () {
      final r = con(
        oraPercentuale: 50,
        vitals: {
          'has_any': true,
          'hrv': {
            'label': 'Variabilità cardiaca',
            'unit': 'ms',
            'value': 40,
            'day': '2026-08-10',
            'average': 50,
            'delta_pct': -20,
          },
        },
      );

      expect(r.hasVitals, isTrue);
      expect(r.vitals.single.anomalo, isTrue);
    });

    /// ⚠️ Verso l'alto no: un HRV migliore della media è una buona notizia, e
    /// segnalarla come anomalia insegnerebbe a ignorare i segnali.
    test('un HRV sopra la media non è un\'anomalia', () {
      final r = con(
        oraPercentuale: 50,
        vitals: {
          'has_any': true,
          'hrv': {
            'label': 'HRV',
            'unit': 'ms',
            'value': 65,
            'day': '2026-08-10',
            'average': 50,
            'delta_pct': 30,
          },
        },
      );

      expect(r.vitals.single.anomalo, isFalse);
    });

    test('un battito molto sopra la media è un\'anomalia', () {
      final r = con(
        oraPercentuale: 50,
        vitals: {
          'has_any': true,
          'resting_hr': {
            'label': 'Battito a riposo',
            'unit': 'bpm',
            'value': 66,
            'day': '2026-08-10',
            'average': 58,
            'delta_pct': 14,
          },
        },
      );

      expect(r.vitals.single.anomalo, isTrue);
    });

    test('senza media non si giudica niente', () {
      // La prima misura in assoluto non ha un riferimento: dichiararla
      // anomala sarebbe un giudizio senza base.
      final r = con(
        oraPercentuale: 50,
        vitals: {
          'has_any': true,
          'hrv': {
            'label': 'HRV',
            'unit': 'ms',
            'value': 30,
            'day': '2026-08-10',
            'average': null,
            'delta_pct': null,
          },
        },
      );

      expect(r.vitals.single.anomalo, isFalse);
    });

    /// 🚨 Assente non è zero: uno zero verrebbe disegnato come un valore
    /// pessimo invece che come un dato mai arrivato.
    test('senza orologio non ci sono parametri, e non ci sono zeri', () {
      final r = con(oraPercentuale: 50);

      expect(r.hasVitals, isFalse);
      expect(r.vitals, isEmpty);
      expect(r.sleep, isNull);
    });
  });

  test('il sonno porta con sé il giudizio del server, non lo ricalcola l\'app', () {
    final r = con(
      oraPercentuale: 50,
      sleep: {
        'asleep_minutes': 401,
        'deep_pct': 12.0,
        'rem_pct': 18.0,
        'awake_minutes': 25,
        'overall': 'warn',
      },
    );

    expect(r.sleep!.durata, '6h 41');
    // Le soglie di ciò che è un sonno sano sono una scelta di prodotto e
    // stanno in un posto solo: `SleepAnalyzer`.
    expect(r.sleep!.overall, 'warn');
  });
}
