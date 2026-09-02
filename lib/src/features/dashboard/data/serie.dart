/// Le serie per i grafici — C3.
///
/// ══ 📌 PERCHE' STA IN UN FILE SUO — I2.5 ══════════════════════════════════
///
/// Viveva in `dashboard_controller.dart`. ⛔ Da quando la serie delle calorie
/// **si costruisce sul telefono** (`serie_del_cibo.dart`, nel diario), quel file
/// e il costruttore della serie si sarebbero importati a vicenda.
///
/// 💡 `dashboard_controller.dart` la **riesporta**, così i venti file che
/// scrivono `import '.../dashboard_controller.dart'` per avere `Series`
/// continuano a compilare senza toccarli. ⚠️ Spostare una classe *e* riscrivere
/// venti import nello stesso giro vorrebbe dire non sapere quale delle due cose
/// ha rotto cosa.
library;

/// Una serie per i grafici — C12.
///
/// 🚨 **Una sola forma per entrambe le metriche.** Peso e calorie hanno lo
/// stesso involucro proprio perché qui ci sia un parser solo: due parser
/// divergono, e il secondo si scopre rotto molto più tardi.
class Series {
  const Series({
    required this.labels,
    required this.granularity,
    this.dates = const [],
    this.values = const [],
    this.consumed = const [],
    this.burned = const [],
    this.protein = const [],
    this.period,
    this.avgConsumed = 0,
    this.avgBurned = 0,
    this.daysWithData = 0,
    this.canGoBack = true,
  });

  /// ⚠️ **Resta anche se nessuno la chiama più** — I2.5.
  ///
  /// 🚨 `GET /series` non serve più né il peso (da S5) né le calorie (da I2.5):
  /// tutte e due le serie nascono sul telefono. 💡 Il costruttore però non è
  /// morto — è il **contratto documentato** di quella risposta, e cancellarlo
  /// costringerebbe a riscriverlo il giorno che una serie tornasse dal server
  /// (per esempio una media di palestra, che dati personali non ne ha).
  factory Series.fromJson(Map<String, dynamic> j) {
    final medie = (j['averages'] as Map?)?.cast<String, dynamic>() ?? const {};

    List<double> numeri(String chiave) => ((j[chiave] as List?) ?? const [])
        .map((e) => (e as num).toDouble())
        .toList();

    return Series(
      labels: ((j['labels'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      dates: ((j['dates'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      values: numeri('values'),
      consumed: numeri('consumed'),
      burned: numeri('burned'),
      protein: numeri('protein'),
      granularity: j['granularity']?.toString() ?? 'day',
      period: j['period']?.toString(),
      avgConsumed: (medie['consumed'] as num?)?.toInt() ?? 0,
      avgBurned: (medie['burned'] as num?)?.toInt() ?? 0,
      daysWithData: (medie['days_with_data'] as num?)?.toInt() ?? 0,
      canGoBack: j['can_go_back'] != false,
    );
  }

  final List<String> labels;

  /// Solo per il peso.
  final List<double> values;

  /// Solo per le calorie.
  final List<double> consumed;
  final List<double> burned;

  /// I grammi di proteine per giorno — 3b-O.7.3, 21/08/2026.
  ///
  /// ⛔ Arriva **solo** sulla vista per giorno: una media mensile di grammi non
  /// risponde a nessuna domanda.
  final List<double> protein;

  /// Le date vere delle colonne (`yyyy-mm-dd`) — 19/08/2026.
  ///
  /// 🚨 `labels` e' testo da mostrare (`d/m`): non ci si ricostruisce sopra un
  /// giorno. Queste servono a unire alla serie le calorie **misurate
  /// dall'orologio**, che stanno solo sul telefono e vanno accostate **per
  /// giorno**.
  final List<String> dates;

  final String granularity;
  final String? period;
  final int avgConsumed;

  /// ⛔ **Non usarlo: vale zero per tutti.**
  ///
  /// 🚨 Era la media delle bruciate secondo il **server**, che gli allenamenti
  /// non li ha più dalla FASE 11. 💡 Le bruciate vere si contano con
  /// `bruciateDi()` in `grafico_calorie.dart`.
  final int avgBurned;

  /// 🚨 Su quanti giorni sono calcolate le medie. Va **mostrato**: «2.200 kcal
  /// di media» su due giorni registrati su sette è un numero diverso da
  /// «2.200 di media» su sette, e senza il contesto si legge come se lo fosse.
  final int daysWithData;

  final bool canGoBack;

  bool get vuota =>
      values.isEmpty &&
      consumed.every((v) => v == 0) &&
      burned.every((v) => v == 0);
}
