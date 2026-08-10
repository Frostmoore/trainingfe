import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';

/// Una notte — C14.
///
/// ⚠️ Il backend restituisce già ipnogramma, minuti per fase, percentuali e
/// **giudizi** (`ok` / `warn` / `bad`): qui non si ricalcola niente. Le soglie
/// di ciò che è un sonno sano sono una scelta di prodotto, e devono stare in un
/// posto solo.
class SleepNight {
  const SleepNight({
    required this.night,
    required this.from,
    required this.to,
    required this.asleepMinutes,
    required this.awakeMinutes,
    required this.lightMinutes,
    required this.deepMinutes,
    required this.remMinutes,
    required this.deepPct,
    required this.remPct,
    required this.ratings,
    required this.overall,
    required this.hypnogram,
    this.disclaimer,
  });

  factory SleepNight.fromJson(Map<String, dynamic> j) => SleepNight(
    night: DateTime.parse(j['night'].toString()),
    from: DateTime.parse(j['from'].toString()),
    to: DateTime.parse(j['to'].toString()),
    asleepMinutes: (j['asleep_minutes'] as num?)?.toInt() ?? 0,
    awakeMinutes: (j['awake_minutes'] as num?)?.toInt() ?? 0,
    lightMinutes: (j['light_minutes'] as num?)?.toInt() ?? 0,
    deepMinutes: (j['deep_minutes'] as num?)?.toInt() ?? 0,
    remMinutes: (j['rem_minutes'] as num?)?.toInt() ?? 0,
    deepPct: (j['deep_pct'] as num?)?.toDouble() ?? 0,
    remPct: (j['rem_pct'] as num?)?.toDouble() ?? 0,
    ratings: ((j['ratings'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k.toString(), v.toString()),
    ),
    overall: j['overall']?.toString() ?? 'ok',
    disclaimer: j['disclaimer']?.toString(),
    hypnogram: ((j['hypnogram'] as List?) ?? const [])
        .map((e) => SleepBlock.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  final DateTime night;
  final DateTime from;
  final DateTime to;
  final int asleepMinutes;
  final int awakeMinutes;
  final int lightMinutes;
  final int deepMinutes;
  final int remMinutes;
  final double deepPct;
  final double remPct;

  /// `asleep_minutes` · `deep_pct` · `rem_pct` · `awake_minutes` → `ok|warn|bad`.
  final Map<String, String> ratings;

  final String overall;
  final String? disclaimer;
  final List<SleepBlock> hypnogram;

  String get durata {
    final h = asleepMinutes ~/ 60;
    final m = asleepMinutes % 60;

    return '${h}h ${m.toString().padLeft(2, '0')}';
  }
}

class SleepBlock {
  const SleepBlock({
    required this.from,
    required this.to,
    required this.stage,
    required this.label,
    required this.minutes,
  });

  factory SleepBlock.fromJson(Map<String, dynamic> j) => SleepBlock(
    from: DateTime.parse(j['from'].toString()),
    to: DateTime.parse(j['to'].toString()),
    stage: (j['stage'] as num).toInt(),
    label: j['label'].toString(),
    minutes: (j['minutes'] as num?)?.toInt() ?? 0,
  );

  final DateTime from;
  final DateTime to;
  final int stage;
  final String label;
  final int minutes;
}

/// La notte che si sta guardando.
final sleepNightProvider = StateProvider<DateTime?>((ref) => null);

final sleepProvider = FutureProvider.autoDispose<SleepNight?>((ref) async {
  final notte = ref.watch(sleepNightProvider);

  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>?>(
        '/health/sleep',
        query: {if (notte != null) 'night': DateFormat('yyyy-MM-dd').format(notte)},
      );

  // `null` quando per quella notte non è mai arrivato niente dall'orologio:
  // non è un errore, è l'assenza di dati.
  return data == null ? null : SleepNight.fromJson(data);
});
