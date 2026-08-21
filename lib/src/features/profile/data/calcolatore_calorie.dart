import 'dart:math' as math;

/// I grammi dei tre macronutrienti.
class Macro {
  const Macro({
    required this.proteineG,
    required this.carboidratiG,
    required this.grassiG,
  });

  final int proteineG;
  final int carboidratiG;
  final int grassiG;
}

/// Il ritratto in Dart di `CalorieCalculator` — S5.1.
///
/// 🚨 **È una traduzione fedele.** I coefficienti sono stati **copiati dal file
/// PHP**, non ricordati: la regola §2.3 del piano — *spostare non è migliorare*
/// — esiste perché altrimenti un difetto del trasloco e uno introdotto per
/// strada diventano indistinguibili.
///
/// ⚠️ **Questa classe contraddice §8.3 dell'atlante dell'app** — *«le decisioni
/// del server non si riscrivono in Dart»* — ed è **un'eccezione dichiarata, non
/// un precedente**. La ragione è precisa: dopo S5 il server **non ha più peso,
/// altezza ed età di nessuno** (decisione D9-bis), quindi non può calcolare
/// niente su di essi. Non è che abbiamo preferito farlo qui: è che là non si
/// può più.
///
/// 🚨 Chi in futuro volesse spostare in Dart un'altra regola del server deve
/// chiedersi se il server **ha ancora i dati per applicarla**. Se sì, la
/// risposta è no.
///
/// ⚠️ **`CalorieCalculator` resta vivo sul backend**: serve al pannello del
/// trainer, che compone i **modelli** di piano — e i modelli non sono dati
/// personali. Le due copie non divergono perché nessuna delle due calcola sulla
/// stessa cosa: quella lì lavora su valori d'esempio, questa sulla persona.
class CalcolatoreCalorie {
  const CalcolatoreCalorie();

  /// Moltiplicatori del metabolismo basale per livello di attività.
  ///
  /// Valori classici di Harris-Benedict aggiornati; l'ultimo, `athlete`, copre
  /// chi si allena due volte al giorno e nella tabella standard non c'è.
  static const attivita = <String, double>{
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
    'athlete': 1.9,
  };

  /// Scostamento dal fabbisogno, per obiettivo.
  ///
  /// ⚠️ **Percentuali e non valori fissi**: −500 kcal su chi ne consuma 3.000 è
  /// un taglio del 17%, sulla stessa persona a 1.600 è il 31% ed è
  /// insostenibile.
  ///
  /// 🚨 **Cinque gradini, simmetrici** — 12/08/2026.
  ///
  /// Il committente: *«non è una stima accurata se sono solo 3 scelte»*. Con
  /// tre gradini l'unica alternativa a «mantenere» era un taglio del 15%:
  /// troppo per chi vuole andare piano, troppo poco per chi ha fretta — e chi
  /// non si ritrova nel numero smette di fidarsi dell'app, non dell'obiettivo.
  ///
  /// Su un TDEE di 2.500 kcal: 2.000 → 2.250 → 2.500 → 2.750 → 3.000.
  ///
  /// ⚠️ **Ritratto fedele di `CalorieCalculator::GOAL_DELTA`.** Chi cambia un
  /// numero di là deve cambiarlo qui, o l'app e il server mostrerebbero due
  /// target diversi per la stessa persona.
  static const deltaObiettivo = <String, double>{
    'lose_fast': -0.20,
    'lose_slow': -0.10,
    'maintain': 0.0,
    'gain_lean': 0.10,
    'gain_fast': 0.20,
  };

  /// ⚠️ Il vocabolario precedente, per i profili non ancora migrati.
  ///
  /// 🚨 `cut` valeva −25% e **nessuno lo impostava mai**: il commento diceva
  /// che arrivava dal piano alimentare, e nel piano alimentare non c'era una
  /// riga che lo facesse. Il suo posto lo prende `lose_fast`.
  static const obiettiviStorici = <String, String>{
    'lose': 'lose_slow',
    'cut': 'lose_fast',
    'bulk': 'gain_lean',
    'lose_weight': 'lose_slow',
    'gain_muscle': 'gain_lean',
  };

  /// Un obiettivo qualunque, portato al vocabolario di oggi.
  static String normalizzaObiettivo(String obiettivo) {
    final o = obiettivo.toLowerCase().trim();

    return obiettiviStorici[o] ?? o;
  }

  /// Ripartizione dei macro in percentuale delle calorie, per obiettivo.
  ///
  /// 🚨 **Percentuali del target e non grammi per chilo, ed è una scelta.** La
  /// formula g/kg è più comune, ma su una persona di 120 kg in forte deficit
  /// produce più proteine di quante ne stiano nel target: il conto non torna e
  /// bisogna correggerlo a mano. In percentuale il conto torna sempre.
  ///
  /// I due gradini di dimagrimento alzano le proteine perché in deficit servono
  /// a limitare la perdita di massa magra — che è esattamente ciò che l'utente
  /// non vuole perdere. Più il deficit è grande, più servono.
  static const ripartizioneMacro = <String, Map<String, double>>{
    'lose_fast': {'protein': 0.38, 'carbs': 0.32, 'fat': 0.30},
    'lose_slow': {'protein': 0.32, 'carbs': 0.38, 'fat': 0.30},
    'maintain': {'protein': 0.25, 'carbs': 0.48, 'fat': 0.27},
    'gain_lean': {'protein': 0.28, 'carbs': 0.50, 'fat': 0.22},
    'gain_fast': {'protein': 0.25, 'carbs': 0.52, 'fat': 0.23},
  };

  /// Calorie per grammo: le costanti di Atwater.
  static const _kcalPerGrammo = <String, double>{
    'protein': 4.0,
    'carbs': 4.0,
    'fat': 9.0,
  };

  /// 🚨 **Il pavimento a 1.200 kcal non è negoziabile.**
  ///
  /// Sotto quella soglia un piano alimentare non è più una dieta, e questo
  /// sistema **non è un dispositivo medico**. È la prima cosa che si perde
  /// riscrivendo «uguale ma in un'altra lingua», e la sola il cui smarrimento
  /// farebbe male a qualcuno.
  static const pavimentoKcal = 1200;

  // ───────────────────────── indici ─────────────────────────

  double bmi(double kg, double cm) {
    if (cm <= 0) throw ArgumentError('Altezza non valida.');

    final m = cm / 100;

    return _arrotonda(kg / (m * m), 1);
  }

  /// Metabolismo basale con **Mifflin-St Jeor**.
  ///
  /// Preferita a Harris-Benedict perché è più accurata sulla popolazione
  /// generale di oggi, che è mediamente più pesante di quella su cui la seconda
  /// era stata tarata nel 1919.
  ///
  /// ⚠️ **Un sesso sconosciuto usa la costante femminile**, che è la più
  /// prudente: un fabbisogno **sotto**stimato porta a un deficit più piccolo del
  /// previsto, uno **sopra**stimato porta a mangiare più del necessario credendo
  /// di essere a target. Fra i due errori si sceglie sempre il primo.
  double bmr({
    required String sesso,
    required double kg,
    required double cm,
    required int eta,
  }) {
    final base = (10 * kg) + (6.25 * cm) - (5 * eta);

    return _arrotonda(base + (sesso.toLowerCase() == 'male' ? 5 : -161), 1);
  }

  double tdee(double bmr, String attivitaScelta) {
    final fattore =
        attivita[attivitaScelta.toLowerCase()] ?? attivita['sedentary']!;

    return _arrotonda(bmr * fattore, 1);
  }

  // ───────────────────────── obiettivo ─────────────────────────

  /// Il target calorico giornaliero.
  ///
  /// ⚠️ **Un obiettivo sconosciuto vale `maintain`, non un errore**: un piano
  /// salvato con un valore vecchio deve continuare a funzionare.
  int targetCalorico(double tdeeValore, String obiettivo) {
    final delta = deltaObiettivo[normalizzaObiettivo(obiettivo)] ?? 0.0;

    return math.max(pavimentoKcal, (tdeeValore * (1 + delta)).round());
  }

  /// I grammi di ciascun macro per un dato target.
  Macro macro(int kcal, String obiettivo) {
    final split =
        ripartizioneMacro[normalizzaObiettivo(obiettivo)] ??
        ripartizioneMacro['maintain']!;

    return Macro(
      proteineG: (kcal * split['protein']! / _kcalPerGrammo['protein']!)
          .round(),
      carboidratiG: (kcal * split['carbs']! / _kcalPerGrammo['carbs']!).round(),
      grassiG: (kcal * split['fat']! / _kcalPerGrammo['fat']!).round(),
    );
  }

  int kcalDaMacro(double proteineG, double carboidratiG, double grassiG) =>
      (proteineG * 4 + carboidratiG * 4 + grassiG * 9).round();

  /// L'età compiuta a partire dalla data di nascita.
  ///
  /// ⚠️ **Compiuta, non «anni trascorsi»**: chi compie gli anni domani ne ha
  /// ancora uno in meno oggi, e sul BMR un anno vale 5 kcal — poco, ma sbagliare
  /// per pigrizia un conto che si fa in tre righe non ha scuse.
  int etaDa(DateTime nascita, {DateTime? adesso}) {
    final oggi = adesso ?? DateTime.now();
    var anni = oggi.year - nascita.year;

    final compiuti =
        (oggi.month > nascita.month) ||
        (oggi.month == nascita.month && oggi.day >= nascita.day);

    if (!compiuti) anni--;

    return anni;
  }

  static double _arrotonda(double v, int decimali) {
    final f = <int, double>{0: 1, 1: 10, 2: 100}[decimali] ?? 10;

    return (v * f).roundToDouble() / f;
  }
}
