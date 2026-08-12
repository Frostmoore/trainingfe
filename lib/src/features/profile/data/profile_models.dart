/// I modelli del profilo — C8.
///
/// 🚨 **I valori derivati NON si ricalcolano qui.** BMR, TDEE, target e macro
/// arrivano dal server. L'app storica duplica Mifflin-St Jeor in JavaScript per
/// l'anteprima live, ed è debito: il giorno che cambia una costante nel
/// `CalorieCalculator`, il client mente finché non lo si aggiorna — e nessun
/// test se ne accorge, perché entrambi i numeri sono plausibili.
library;

class UserProfile {
  const UserProfile({
    required this.mealHours,
    required this.missing,
    required this.activityLevels,
    required this.goals,
    this.sex,
    this.birthdate,
    this.age,
    this.heightCm,
    this.activityLevel,
    this.goal,
    this.targetWeightKg,
    this.weightKg,
    this.derived,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    final opzioni = (j['options'] as Map?)?.cast<String, dynamic>() ?? const {};

    return UserProfile(
      sex: j['sex']?.toString(),
      birthdate: j['birthdate'] == null ? null : DateTime.tryParse(j['birthdate'].toString()),
      age: (j['age'] as num?)?.toInt(),
      heightCm: (j['height_cm'] as num?)?.toInt(),
      activityLevel: j['activity_level']?.toString(),
      goal: j['goal']?.toString(),
      targetWeightKg: (j['target_weight_kg'] as num?)?.toDouble(),
      weightKg: (j['weight_kg'] as num?)?.toDouble(),
      mealHours: ((j['meal_hours'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
      // 🚨 L'elenco dei campi mancanti viene dal server e si usa così com'è:
      // ricostruirlo in Dart significherebbe avere due idee diverse di «cosa
      // serve per calcolare il fabbisogno».
      missing: ((j['missing'] as List?) ?? const []).map((e) => e.toString()).toList(),
      derived: j['derived'] == null
          ? null
          : DerivedTargets.fromJson((j['derived'] as Map).cast<String, dynamic>()),
      activityLevels: ((opzioni['activity_levels'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
      goals: ((opzioni['goals'] as Map?) ?? const {}).map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
    );
  }

  final String? sex;
  final DateTime? birthdate;
  final int? age;
  final int? heightCm;
  final String? activityLevel;
  final String? goal;
  final double? targetWeightKg;
  final double? weightKg;

  /// Sempre sei voci: i valori di serie arrivano già riempiti dal server.
  final Map<String, String> mealHours;

  /// I campi che mancano per avere un fabbisogno, nell'ordine in cui chiederli.
  final List<String> missing;

  /// `null` finché `missing` non è vuoto.
  final DerivedTargets? derived;

  /// Le tendine, prese dal server: aggiungere un livello non richiede una
  /// nuova versione dell'app.
  final Map<String, String> activityLevels;
  final Map<String, String> goals;

  bool get isComplete => missing.isEmpty && derived != null;

  // ───────────────────── traduzione verso le formule ─────────────────────
  //
  // 🚨 **I valori salvati nel profilo e quelli attesi da `CalcolatoreCalorie`
  // NON coincidono**, ed è un fatto storico: la tabella nasce in B1.4, il
  // calcolatore è il port di un'app precedente con il proprio vocabolario.
  //
  // ⚠️ **Lato server questa traduzione ESISTE GIÀ** — `Profile::sexForFormula()`,
  // `activityForFormula()`, `goalForFormula()` — con sopra scritto: *«chi
  // aggiunge un livello o un obiettivo deve aggiornare questi tre metodi»*.
  //
  // 🚨 **Portando il calcolatore in Dart (S5.1) sono stati portati i numeri e
  // NON la traduzione.** Il difetto che ne è uscito è il peggiore possibile,
  // perché è silenzioso e plausibile:
  //
  // | Valore salvato | Cosa succedeva |
  // |---|---|
  // | `sex = 'm'` | il confronto era con `'male'` ⇒ usava la costante **femminile**: −161 invece di +5, cioè **166 kcal in meno** |
  // | `goal = 'lose_weight'` | non è una chiave di `deltaObiettivo` ⇒ deficit **0%**: un target di MANTENIMENTO a chi vuole dimagrire |
  // | `activity = 'very_active'` | non è una chiave di `attivita` ⇒ ripiego su `sedentary`: 1.2 invece di 1.9 |
  //
  // 💡 Nessuno di questi dà errore: producono tutti un numero **plausibile e
  // sbagliato**, che è esattamente il tipo di numero che nessuno controlla più.
  // È stato trovato solo perché il committente ha chiesto «secondo te il target
  // è adeguato per il dimagrimento?».

  /// `m`/`f` → il vocabolario di Mifflin-St Jeor.
  String get sessoPerFormula => sex == 'm' ? 'male' : 'female';

  /// ⚠️ `very_active` qui è `athlete` nel calcolatore.
  String get attivitaPerFormula => switch (activityLevel) {
    'light' => 'light',
    'moderate' => 'moderate',
    'active' => 'active',
    'very_active' => 'athlete',
    _ => 'sedentary',
  };

  /// `lose_weight`/`gain_muscle` → `lose`/`bulk`.
  ///
  /// 💡 `cut` non ha corrispondente nel profilo: è un obiettivo che si imposta
  /// dal piano alimentare del trainer, non da qui.
  String get obiettivoPerFormula => switch (goal) {
    'lose_weight' => 'lose',
    'gain_muscle' => 'bulk',
    _ => 'maintain',
  };

  /// L'etichetta italiana del campo mancante, per dirlo invece di elencare
  /// nomi di colonne.
  static String labelFor(String campo) => switch (campo) {
    'weight_kg' => 'il tuo peso',
    'sex' => 'il sesso',
    'birthdate' => 'la data di nascita',
    'height_cm' => 'l\'altezza',
    _ => campo,
  };
}

class DerivedTargets {
  const DerivedTargets({
    required this.bmi,
    required this.bmr,
    required this.tdee,
    required this.targetKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  factory DerivedTargets.fromJson(Map<String, dynamic> j) {
    final macro = (j['macros'] as Map?)?.cast<String, dynamic>() ?? const {};

    return DerivedTargets(
      bmi: (j['bmi'] as num).toDouble(),
      bmr: (j['bmr'] as num).toDouble(),
      tdee: (j['tdee'] as num).toDouble(),
      targetKcal: (j['target_kcal'] as num).toInt(),
      proteinG: (macro['protein_g'] as num?)?.toInt() ?? 0,
      carbsG: (macro['carbs_g'] as num?)?.toInt() ?? 0,
      fatG: (macro['fat_g'] as num?)?.toInt() ?? 0,
    );
  }

  final double bmi;
  final double bmr;
  final double tdee;
  final int targetKcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
}

/// Una pesata: la serie storica su cui si disegna l'andamento.
class WeightEntry {
  const WeightEntry({required this.date, required this.weightKg, this.bodyFatPct});

  factory WeightEntry.fromJson(Map<String, dynamic> j) => WeightEntry(
    date: DateTime.parse(j['date'].toString()),
    weightKg: (j['weight_kg'] as num).toDouble(),
    bodyFatPct: (j['body_fat_pct'] as num?)?.toDouble(),
  );

  final DateTime date;
  final double weightKg;
  final double? bodyFatPct;
}
