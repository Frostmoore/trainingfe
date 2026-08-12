import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/profile/data/calcolatore_calorie.dart';
import 'package:training_companion/src/features/profile/data/profile_models.dart';

/// 🚨 La traduzione fra il vocabolario del profilo e quello delle formule.
///
/// ── Il difetto, trovato il 12/08/2026 ────────────────────────────────────
///
/// Il committente ha chiesto: *«fatti i conti con i dati che ho inserito e
/// dimmi se secondo te il target calorico è adeguato per il dimagrimento»*.
/// Non lo era, e la ragione era che il profilo salva `lose_weight` mentre
/// `CalcolatoreCalorie` conosce `lose`.
///
/// ⚠️ Lato server la traduzione esiste da sempre (`Profile::goalForFormula()`
/// e compagni), **con scritto sopra che va aggiornata insieme agli elenchi**.
/// Portando il calcolatore in Dart erano stati portati i numeri e non lei.
///
/// 🚨 **Nessuno dei tre errori dava un'eccezione.** Producevano tutti un numero
/// plausibile: un deficit del 15% diventava 0%, un uomo veniva calcolato come
/// donna, un atleta come sedentario. È il tipo di numero che nessuno controlla
/// più — e che intanto diventa la dieta di qualcuno.
void main() {
  UserProfile profilo({String? sesso, String? attivita, String? obiettivo}) =>
      UserProfile(
        sex: sesso,
        activityLevel: attivita,
        goal: obiettivo,
        mealHours: const {},
        missing: const [],
        activityLevels: const {},
        goals: const {},
      );

  group('il vocabolario del profilo non è quello delle formule', () {
    /// 🚨 `'m'` non è `'male'`: il calcolatore confronta con `'male'`, quindi
    /// senza traduzione ogni uomo veniva calcolato con la costante femminile —
    /// **166 kcal di metabolismo basale in meno**.
    test('il sesso si traduce', () {
      expect(profilo(sesso: 'm').sessoPerFormula, 'male');
      expect(profilo(sesso: 'f').sessoPerFormula, 'female');
    });

    /// ⚠️ In dubbio si usa `female`, che è la stima **più prudente**: un
    /// fabbisogno sottostimato porta a un deficit più piccolo del previsto,
    /// uno soprastimato porta a mangiare più del necessario credendo di essere
    /// a target. Fra i due errori si sceglie sempre il primo.
    test('un sesso mancante vale come femminile, che è la stima prudente', () {
      expect(profilo().sessoPerFormula, 'female');
    });

    /// 🚨 Il difetto che ha fatto partire tutto: `lose_weight` non è una chiave
    /// di `deltaObiettivo`, quindi il deficit era **0%**.
    test('l\'obiettivo si traduce', () {
      expect(profilo(obiettivo: 'lose_weight').obiettivoPerFormula, 'lose');
      expect(profilo(obiettivo: 'gain_muscle').obiettivoPerFormula, 'bulk');
      expect(profilo(obiettivo: 'maintain').obiettivoPerFormula, 'maintain');
    });

    test('«molto attivo» è «atleta» nel calcolatore', () {
      expect(profilo(attivita: 'very_active').attivitaPerFormula, 'athlete');
      expect(profilo(attivita: 'moderate').attivitaPerFormula, 'moderate');
      expect(profilo(attivita: null).attivitaPerFormula, 'sedentary');
    });
  });

  /// 🚨 **Il test che chiude il cerchio.** Ogni valore che il profilo può
  /// salvare deve tradursi in una chiave che il calcolatore **conosce
  /// davvero** — altrimenti si ricade sul valore di serie senza che niente lo
  /// segnali.
  ///
  /// ⚠️ È quello che fallisce da solo il giorno che qualcuno aggiunge un
  /// obiettivo al profilo e si dimentica della traduzione.
  group('ogni valore salvabile finisce su una chiave che esiste', () {
    test('gli obiettivi', () {
      for (final salvato in ['lose_weight', 'maintain', 'gain_muscle']) {
        final tradotto = profilo(obiettivo: salvato).obiettivoPerFormula;

        expect(
          CalcolatoreCalorie.deltaObiettivo.containsKey(tradotto),
          isTrue,
          reason: '«$salvato» si traduce in «$tradotto», che il calcolatore '
              'non conosce: userebbe 0% di scostamento senza dirlo',
        );
        expect(
          CalcolatoreCalorie.ripartizioneMacro.containsKey(tradotto),
          isTrue,
          reason: '«$salvato» non ha una ripartizione dei macro',
        );
      }
    });

    test('i livelli di attività', () {
      for (final salvato in [
        'sedentary',
        'light',
        'moderate',
        'active',
        'very_active',
      ]) {
        final tradotto = profilo(attivita: salvato).attivitaPerFormula;

        expect(
          CalcolatoreCalorie.attivita.containsKey(tradotto),
          isTrue,
          reason: '«$salvato» si traduce in «$tradotto», che non è un '
              'moltiplicatore noto: userebbe 1.2 senza dirlo',
        );
      }
    });
  });

  /// Il conto vero, sui dati del committente: uomo, 175 cm, 37 anni,
  /// sedentario, «dimagrire», 96,7 kg.
  ///
  /// 💡 Fissa **entrambi** i numeri — quello giusto e quello che usciva prima —
  /// così se qualcuno rimuove la traduzione il test dice anche di quanto si
  /// sbaglia.
  test('il caso reale che ha fatto trovare il difetto', () {
    const c = CalcolatoreCalorie();

    final p = profilo(sesso: 'm', attivita: 'sedentary', obiettivo: 'lose_weight');

    final bmr = c.bmr(sesso: p.sessoPerFormula, kg: 96.7, cm: 175, eta: 37);
    final tdee = c.tdee(bmr, p.attivitaPerFormula);
    final kcal = c.targetCalorico(tdee, p.obiettivoPerFormula);

    // Mifflin-St Jeor per un uomo: 10×96,7 + 6,25×175 − 5×37 + 5.
    expect(bmr, closeTo(1880.8, 0.1));
    expect(tdee, closeTo(2256.9, 0.1));

    // −15% per «dimagrire». Prima usciva 2058: mantenimento, con il basale
    // calcolato come se fosse una donna.
    expect(kcal, 1918);

    final macro = c.macro(kcal, p.obiettivoPerFormula);

    // La ripartizione di `lose` alza le proteine: in deficit servono a
    // limitare la perdita di massa magra.
    expect(macro.proteineG, 153);
  });
}
