/// Il riepilogo della schermata principale — D5.
///
/// 🚨 **Ogni sezione può essere assente, e l'assenza è un'informazione.**
/// Sonno e parametri arrivano dall'orologio, che può non aver mai mandato
/// niente. Trasformare un `null` in uno zero farebbe disegnare un HRV di 0 ms,
/// che si legge come un valore pessimo invece che come un dato mancante — ed è
/// la differenza fra «stai male» e «non lo so».
library;

class DashboardSummary {
  const DashboardSummary({
    required this.date,
    required this.hour,
    required this.dayProgressPct,
    required this.nutrition,
    required this.training,
    required this.body,
    this.sleep,
    this.vitals = const [],
    this.hasVitals = false,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    final parametri = (j['vitals'] as Map?)?.cast<String, dynamic>() ?? const {};

    return DashboardSummary(
      date: DateTime.parse(j['date'].toString()),
      hour: (j['hour'] as num?)?.toInt() ?? 0,
      dayProgressPct: (j['day_progress_pct'] as num?)?.toInt() ?? 0,
      nutrition: NutritionToday.fromJson(
        (j['nutrition'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      training: TrainingToday.fromJson(
        (j['training'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      body: BodyToday.fromJson((j['body'] as Map?)?.cast<String, dynamic>() ?? const {}),
      sleep: j['sleep'] == null
          ? null
          : SleepToday.fromJson((j['sleep'] as Map).cast<String, dynamic>()),
      hasVitals: parametri['has_any'] == true,
      vitals: parametri.entries
          .where((e) => e.key != 'has_any' && e.value != null)
          .map((e) => Vital.fromJson(e.key, (e.value as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  final DateTime date;
  final int hour;

  /// Quanto è passato della **giornata sveglia** (6→23), non delle 24 ore.
  ///
  /// 🚨 È il riferimento con cui leggere le calorie: 1.200 su 2.400 a metà
  /// mattina sono tantissime, le stesse alle nove di sera sono poche. Senza,
  /// la stessa barra racconta due cose opposte.
  final int dayProgressPct;

  final NutritionToday nutrition;
  final TrainingToday training;
  final BodyToday body;
  final SleepToday? sleep;
  final List<Vital> vitals;
  final bool hasVitals;

  /// Il ritmo di oggi rispetto all'ora: `null` quando non c'è un target.
  ///
  /// Positivo = si sta mangiando più in fretta di come scorre la giornata.
  double? get scostamentoRitmo {
    final target = nutrition.targetKcal;

    if (target == null || target <= 0) return null;

    final atteso = target * dayProgressPct / 100;

    return nutrition.kcal - atteso;
  }
}

class NutritionToday {
  const NutritionToday({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.burnedKcal,
    required this.entriesCount,
    this.targetKcal,
    this.targetProtein,
    this.targetCarbs,
    this.targetFat,
    this.targetDaPiano = false,
  });

  factory NutritionToday.fromJson(Map<String, dynamic> j) {
    final totali = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final target = (j['targets'] as Map?)?.cast<String, dynamic>();
    final bruciate = (j['burned'] as Map?)?.cast<String, dynamic>() ?? const {};

    double n(Map<String, dynamic> m, String k) => (m[k] as num?)?.toDouble() ?? 0;

    return NutritionToday(
      kcal: n(totali, 'kcal'),
      protein: n(totali, 'protein'),
      carbs: n(totali, 'carbs'),
      fat: n(totali, 'fat'),
      burnedKcal: (bruciate['kcal'] as num?)?.toInt() ?? 0,
      entriesCount: (j['entries_count'] as num?)?.toInt() ?? 0,
      targetKcal: (target?['kcal'] as num?)?.toDouble(),
      targetProtein: (target?['protein_g'] as num?)?.toDouble(),
      targetCarbs: (target?['carbs_g'] as num?)?.toDouble(),
      targetFat: (target?['fat_g'] as num?)?.toDouble(),
      targetDaPiano: target?['source'] == 'plan',
    );
  }

  final double kcal, protein, carbs, fat;
  final int burnedKcal;
  final int entriesCount;
  final double? targetKcal, targetProtein, targetCarbs, targetFat;

  /// Se l'obiettivo viene dal piano del trainer e non dalla formula — S7.5.
  ///
  /// 🚨 Il backend ne restituisce **uno solo**, e va lasciato così: due numeri
  /// diversi nella stessa schermata sono un invito a non fidarsi di nessuno dei
  /// due, e chi paga un trainer vuole seguire il trainer.
  final bool targetDaPiano;

  bool get haTarget => targetKcal != null && targetKcal! > 0;

  double? get residuo => haTarget ? targetKcal! - kcal : null;
}

class TrainingToday {
  const TrainingToday({
    required this.last30Days,
    required this.recent,
    this.daysSinceLast,
    this.openSessionId,
  });

  factory TrainingToday.fromJson(Map<String, dynamic> j) => TrainingToday(
    last30Days: (j['last_30_days'] as num?)?.toInt() ?? 0,
    daysSinceLast: (j['days_since_last'] as num?)?.toInt(),
    openSessionId: (j['open_session_id'] as num?)?.toInt(),
    recent: ((j['recent'] as List?) ?? const [])
        .map((e) => RecentWorkout.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  final int last30Days;

  /// `null` quando non si è mai allenato: diverso da «oggi».
  final int? daysSinceLast;

  final int? openSessionId;
  final List<RecentWorkout> recent;
}

class RecentWorkout {
  const RecentWorkout({
    required this.id,
    required this.name,
    required this.startedAt,
    required this.setsCount,
    required this.isOpen,
    this.durationMinutes,
    this.kcal,
  });

  factory RecentWorkout.fromJson(Map<String, dynamic> j) => RecentWorkout(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? 'Sessione libera',
    // A3: istante con offset → `DateTime` in UTC. Va riportato in locale prima
    // che qualcuno lo formatti, o l'orario mostrato e' quello di Greenwich.
    startedAt: DateTime.parse(j['started_at'].toString()).toLocal(),
    durationMinutes: (j['duration_minutes'] as num?)?.toInt(),
    setsCount: (j['sets_count'] as num?)?.toInt() ?? 0,
    kcal: (j['kcal'] as num?)?.toInt(),
    isOpen: j['is_open'] == true,
  );

  final int id;
  final String name;
  final DateTime startedAt;
  final int? durationMinutes;
  final int setsCount;
  final int? kcal;
  final bool isOpen;
}

class BodyToday {
  const BodyToday({this.weightKg, this.weightAt, this.weightDelta, this.targetWeightKg});

  factory BodyToday.fromJson(Map<String, dynamic> j) => BodyToday(
    weightKg: (j['weight_kg'] as num?)?.toDouble(),
    weightAt: j['weight_at'] == null ? null : DateTime.tryParse(j['weight_at'].toString()),
    weightDelta: (j['weight_delta'] as num?)?.toDouble(),
    targetWeightKg: (j['target_weight_kg'] as num?)?.toDouble(),
  );

  final double? weightKg;
  final DateTime? weightAt;

  /// La differenza dalla pesata precedente: il numero da solo non dice se si
  /// sta andando nella direzione giusta.
  final double? weightDelta;

  final double? targetWeightKg;
}

class SleepToday {
  const SleepToday({
    required this.asleepMinutes,
    required this.deepPct,
    required this.remPct,
    required this.awakeMinutes,
    required this.overall,
  });

  factory SleepToday.fromJson(Map<String, dynamic> j) => SleepToday(
    asleepMinutes: (j['asleep_minutes'] as num?)?.toInt() ?? 0,
    deepPct: (j['deep_pct'] as num?)?.toDouble() ?? 0,
    remPct: (j['rem_pct'] as num?)?.toDouble() ?? 0,
    awakeMinutes: (j['awake_minutes'] as num?)?.toInt() ?? 0,
    overall: j['overall']?.toString() ?? 'ok',
  );

  final int asleepMinutes;
  final double deepPct;
  final double remPct;
  final int awakeMinutes;

  /// `ok` · `warn` · `bad` — il giudizio lo dà il server, non l'app: le soglie
  /// di ciò che è un sonno sano sono una scelta di prodotto e stanno in un
  /// posto solo.
  final String overall;

  String get durata =>
      '${asleepMinutes ~/ 60}h ${(asleepMinutes % 60).toString().padLeft(2, '0')}';
}

/// HRV o battito, **con la media della persona**.
class Vital {
  const Vital({
    required this.metric,
    required this.label,
    required this.unit,
    required this.value,
    required this.day,
    this.average,
    this.deltaPct,
  });

  factory Vital.fromJson(String metric, Map<String, dynamic> j) => Vital(
    metric: metric,
    label: j['label']?.toString() ?? metric,
    unit: j['unit']?.toString() ?? '',
    value: (j['value'] as num).toDouble(),
    day: DateTime.parse(j['day'].toString()),
    average: (j['average'] as num?)?.toDouble(),
    deltaPct: (j['delta_pct'] as num?)?.toDouble(),
  );

  final String metric;
  final String label;
  final String unit;
  final double value;
  final DateTime day;

  /// La media dei giorni precedenti. `null` finché non ci sono abbastanza dati.
  final double? average;

  /// 🚨 **È questo il numero da guardare, non il valore assoluto.** Un HRV di
  /// 42 ms è ottimo per qualcuno e allarmante per qualcun altro: conta lo
  /// scostamento dalla media di quella persona.
  final double? deltaPct;

  /// Vero quando lo scostamento è abbastanza grande da meritare attenzione.
  ///
  /// ⚠️ Solo **verso il basso** per HRV (recupero peggiore) e solo **verso
  /// l'alto** per il battito: un HRV più alto della media è una buona notizia,
  /// e segnalarla come anomalia insegnerebbe a ignorare i segnali.
  bool get anomalo {
    final d = deltaPct;

    if (d == null) return false;

    return metric == 'hrv' ? d <= -15 : d >= 10;
  }
}
