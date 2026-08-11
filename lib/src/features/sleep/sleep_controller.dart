import 'package:flutter_riverpod/flutter_riverpod.dart';

// ⚠️ `intl` e `core/providers.dart` sono stati tolti in S2.2 insieme alla
// chiamata di rete: servivano a formattare la data per la query e a prendere
// `apiClientProvider`. **Torneranno in S4.3** — `intl` per la data della notte
// nell'archivio locale, `providers` no: la sorgente non sarà più la rete.

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

/// L'ipnogramma della notte.
///
/// 🚨 **Non chiama più il server, e per ora non ha nessuna sorgente.**
///
/// Fino a `v4.8.1` questo provider faceva `GET /health/sleep`. Quell'endpoint
/// **non esiste più**: la fase S1 di `plan_security_and_retention.md` l'ha
/// rimosso perché sonno, HRV e battito restano sul telefono di chi li produce
/// (decisione D9).
///
/// ⚠️ **Restituisce `null` di proposito, e non è un ripiego provvisorio mal
/// fatto**: è la finestra prevista dal piano fra «il backend smette di servire
/// il dato» (S1) e «l'app impara a produrselo» (S3 e S4). Lasciare la chiamata
/// avrebbe dato un **404** a ogni apertura della schermata, cioè un errore che
/// sembra un guasto invece di un'assenza.
///
/// **Dove torna la sorgente**: `ArchivioSalute` in S3, e `AnalizzatoreSonno`
/// in S4.2. Da lì questo provider legge dal database locale e la firma —
/// `FutureProvider.autoDispose<SleepNight?>` — **non cambia**: è il motivo per
/// cui `SleepNight`, `SleepBlock` e `SleepScreen` non sono stati cancellati.
final sleepProvider = FutureProvider.autoDispose<SleepNight?>((ref) async {
  // Si continua a osservare la notte scelta: quando in S4 arriverà l'archivio
  // locale, cambiare notte dovrà gia' rileggere senza toccare le schermate.
  ref.watch(sleepNightProvider);

  return null;
});
