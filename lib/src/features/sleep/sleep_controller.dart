import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/archivio_salute.dart';
import '../health/analizzatore_sonno.dart';
import '../health/dati_salute.dart';
import '../health/health_controller.dart';

// ⚠️ `core/providers.dart` non torna: la sorgente non è più la rete, e
// `apiClientProvider` qui non serve più a niente.

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

  /// Dal giudizio calcolato in locale — S4.3.
  ///
  /// 🚨 **È un adattatore, non un modello nuovo.** `GiudizioNotte` è ciò che
  /// `AnalizzatoreSonno` produce leggendo l'archivio; `SleepNight` è ciò che la
  /// schermata sa disegnare da C14. Tenendoli separati, il giorno che si vorrà
  /// cambiare la presentazione non si toccherà il calcolo — e viceversa.
  ///
  /// ⚠️ `fromJson` resta al suo posto **anche se nessuno la chiama più**: è la
  /// prova documentale del contratto che il backend aveva, e cancellarla
  /// renderebbe impossibile capire da cosa viene questa forma.
  factory SleepNight.daGiudizio(GiudizioNotte g) => SleepNight(
    night: g.notte,
    from: g.da,
    to: g.a,
    asleepMinutes: g.minutiDormiti,
    awakeMinutes: g.minutiSvegli,
    lightMinutes: g.minutiLeggero,
    deepMinutes: g.minutiProfondo,
    remMinutes: g.minutiRem,
    deepPct: g.profondoPct,
    remPct: g.remPct,
    ratings: g.valutazioni.map((k, v) => MapEntry(k, v.nome)),
    overall: g.complessivo.nome,
    disclaimer: GiudizioNotte.avvertenza,
    hypnogram: g.ipnogramma.map((c) {
      final fase = FaseSonno.daCodice(c.fase);

      return SleepBlock(
        from: c.iniziatoIl,
        to: c.finitoIl,
        stage: fase.codice,
        label: fase.etichetta,
        minutes: c.minuti,
      );
    }).toList(),
  );

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

/// L'ipnogramma della notte, **letto dal telefono** — S4.3.
///
/// 🚨 **Non chiama il server, e non lo chiamerà più.** Fino a `v4.8.1` faceva
/// `GET /health/sleep`; quell'endpoint è stato rimosso in S1 perché sonno, HRV
/// e battito restano sul telefono di chi li produce (decisione D9).
///
/// 💡 **La firma non è mai cambiata** — `FutureProvider.autoDispose<SleepNight?>`
/// — ed è il motivo per cui `SleepNight`, `SleepBlock` e `SleepScreen` non sono
/// stati cancellati in S2: è cambiata **solo la sorgente**, e nessuna schermata
/// se n'è accorta.
final sleepProvider = FutureProvider.autoDispose<SleepNight?>((ref) async {
  final archivio = ref.watch(archivioSaluteProvider);

  // Si ricalcola quando il ponte scrive: senza, collegare Health Connect non
  // aggiornerebbe la schermata fino al riavvio dell'app.
  ref.watch(healthControllerProvider);

  // ⚠️ Nessuna notte scelta = **l'ultima con dati**, non «stanotte». Chi apre
  // l'app alle 18 senza aver sincronizzato vedrebbe altrimenti una schermata
  // vuota pur avendo dormito: il dato c'è, è solo di ieri.
  final quale = ref.watch(sleepNightProvider) ?? await archivio.ultimaNotteConDati();

  if (quale == null) return null;

  final giudizio = await AnalizzatoreSonno.notte(archivio, quale);

  return giudizio == null ? null : SleepNight.daGiudizio(giudizio);
});
