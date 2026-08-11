/// I modelli del diario alimentare — A4.
///
/// 🚨 **Ogni numero si legge con `_num()`.**
/// Il backend manda `double` anche per i valori tondi (lo garantisce apposta
/// con `JSON_PRESERVE_ZERO_FRACTION`), ma un `as double` diretto resterebbe un
/// crash in attesa: basta un endpoint nuovo che dimentichi la regola, o una
/// risposta letta da una cache scritta da una versione precedente. `num` accetta
/// entrambi e costa niente.
library;

double? _num(Object? v) => v == null ? null : (v as num).toDouble();

/// Una voce mangiata.
class FoodEntry {
  const FoodEntry({
    required this.id,
    required this.description,
    required this.meal,
    this.grams,
    this.qty,
    this.unit,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.kcal100,
    this.source = 'manual',
  });

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
    id: (j['id'] as num).toInt(),
    description: j['description']?.toString() ?? '',
    meal: j['meal']?.toString() ?? 'lunch',
    grams: _num(j['grams']),
    qty: _num(j['qty']),
    unit: j['unit']?.toString(),
    kcal: _num(j['kcal']),
    protein: _num(j['protein']),
    carbs: _num(j['carbs']),
    fat: _num(j['fat']),
    kcal100: _num(j['kcal_100']),
    source: j['source']?.toString() ?? 'manual',
  );

  final int id;
  final String description;
  final String meal;
  final double? grams, qty, kcal, protein, carbs, fat;
  final String? unit;

  /// Le calorie per 100 g.
  ///
  /// 🚨 **Non serve all'app per contare** — il ricalcolo lo fa il server, che
  /// possiede la tabella delle unità. Serve solo a **sapere** se cambiando la
  /// quantità i macro si aggiorneranno: quando manca, il modulo deve dirlo
  /// invece di lasciar credere a un ricalcolo che non avverrà.
  final double? kcal100;

  bool get siRicalcola => kcal100 != null;

  final String source;

  /// «120 g» oppure «2 cucchiai»: come lo ha scritto l'utente, non come lo
  /// conserva il database.
  String get quantita {
    if (qty != null && unit != null) return '${_pulito(qty!)} $unit';
    if (grams != null) return '${_pulito(grams!)} g';

    return '';
  }

  static String _pulito(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Un pasto della giornata, con le sue voci e i suoi totali.
class DiaryMeal {
  const DiaryMeal({
    required this.meal,
    required this.label,
    required this.entries,
    required this.kcal,
  });

  factory DiaryMeal.fromJson(Map<String, dynamic> j) => DiaryMeal(
    meal: j['meal']?.toString() ?? '',
    label: j['label']?.toString() ?? '',
    entries: (j['entries'] as List? ?? const [])
        .map((e) => FoodEntry.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    kcal: _num((j['totals'] as Map?)?['kcal']) ?? 0,
  );

  final String meal;
  final String label;
  final List<FoodEntry> entries;
  final double kcal;
}

/// La giornata intera, come la restituisce `GET /api/v1/diary`.
class DiaryDay {
  const DiaryDay({
    required this.date,
    required this.meals,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.burnedKcal,
    this.targetKcal,
    this.targetProtein,
    this.targetCarbs,
    this.targetFat,
    this.targetDaPiano = false,
  });

  factory DiaryDay.fromJson(Map<String, dynamic> j) {
    final totals = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final targets = (j['targets'] as Map?)?.cast<String, dynamic>();
    final burned = (j['burned'] as Map?)?.cast<String, dynamic>() ?? const {};

    return DiaryDay(
      date: DateTime.tryParse(j['date']?.toString() ?? '') ?? DateTime.now(),
      meals: (j['meals'] as List? ?? const [])
          .map((m) => DiaryMeal.fromJson((m as Map).cast<String, dynamic>()))
          .toList(),
      kcal: _num(totals['kcal']) ?? 0,
      protein: _num(totals['protein']) ?? 0,
      carbs: _num(totals['carbs']) ?? 0,
      fat: _num(totals['fat']) ?? 0,
      burnedKcal: (burned['kcal'] as num?)?.toInt() ?? 0,
      targetKcal: _num(targets?['kcal']),
      targetProtein: _num(targets?['protein_g']),
      targetCarbs: _num(targets?['carbs_g']),
      targetFat: _num(targets?['fat_g']),
      targetDaPiano: targets?['source'] == 'plan',
    );
  }

  final DateTime date;
  final List<DiaryMeal> meals;
  final double kcal, protein, carbs, fat;
  final int burnedKcal;

  /// `null` quando il backend non ha abbastanza dati per calcolarlo: manca il
  /// profilo o il piano. **Non si inventa**, perché l'utente ci costruirebbe
  /// sopra una dieta.
  final double? targetKcal, targetProtein, targetCarbs, targetFat;

  /// Se l'obiettivo viene dal **piano del trainer** e non dalla formula — S7.5.
  ///
  /// 🚨 **Quando c'è un piano, il numero calcolato non si mostra affatto.** Il
  /// backend ne restituisce già uno solo (`targetsFor()` sceglie il piano), e
  /// va lasciato così: due numeri diversi nella stessa schermata sono un invito
  /// a non fidarsi di nessuno dei due, e chi paga un trainer vuole seguire il
  /// trainer.
  ///
  /// ⚠️ **La formula resta e continua a girare**: serve quando il piano scade,
  /// e per chi un trainer non ce l'ha. È la *visualizzazione* che cede il posto,
  /// non il calcolo che si spegne.
  final bool targetDaPiano;

  bool get hasTarget => targetKcal != null && targetKcal! > 0;

  /// Quanto resta. Negativo quando si è sforato — e va mostrato in rosso.
  double get residuoKcal => (targetKcal ?? 0) - kcal;

  /// Da 0 a oltre 1: oltre 1 significa sforato.
  double get progresso => hasTarget ? (kcal / targetKcal!).clamp(0.0, 2.0) : 0;
}
