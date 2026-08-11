import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../profile/corpo_controller.dart';
import 'data/dashboard_models.dart';

/// Il riepilogo di oggi — D5.
///
/// 🚨 **Una chiamata sola.** Calorie, allenamenti, peso, sonno e parametri
/// arrivano insieme: con cinque richieste separate basta che una sia lenta
/// perché la schermata compaia a pezzi, e su rete mobile succede sempre.
final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final data = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/dashboard');

  return DashboardSummary.fromJson(data);
});

/// Una serie per i grafici — C12.
///
/// 🚨 **Una sola forma per entrambe le metriche.** Il backend risponde con lo
/// stesso involucro per peso e calorie proprio perché qui ci sia un parser
/// solo: due parser divergono, e il secondo si scopre rotto molto più tardi.
class Series {
  const Series({
    required this.labels,
    required this.granularity,
    this.values = const [],
    this.consumed = const [],
    this.burned = const [],
    this.period,
    this.avgConsumed = 0,
    this.avgBurned = 0,
    this.daysWithData = 0,
    this.canGoBack = true,
  });

  factory Series.fromJson(Map<String, dynamic> j) {
    final medie = (j['averages'] as Map?)?.cast<String, dynamic>() ?? const {};

    List<double> numeri(String chiave) =>
        ((j[chiave] as List?) ?? const []).map((e) => (e as num).toDouble()).toList();

    return Series(
      labels: ((j['labels'] as List?) ?? const []).map((e) => e.toString()).toList(),
      values: numeri('values'),
      consumed: numeri('consumed'),
      burned: numeri('burned'),
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

  final String granularity;
  final String? period;
  final int avgConsumed;
  final int avgBurned;

  /// 🚨 Su quanti giorni sono calcolate le medie. Va **mostrato**: «2.200 kcal
  /// di media» su due giorni registrati su sette è un numero diverso da
  /// «2.200 di media» su sette, e senza il contesto si legge come se lo fosse.
  final int daysWithData;

  final bool canGoBack;

  bool get vuota =>
      values.isEmpty && consumed.every((v) => v == 0) && burned.every((v) => v == 0);
}

/// La finestra scelta per il grafico delle calorie.
class CaloriesWindow {
  const CaloriesWindow({this.days = 7, this.offset = 0});

  final int days;
  final int offset;

  CaloriesWindow copyWith({int? days, int? offset}) =>
      CaloriesWindow(days: days ?? this.days, offset: offset ?? this.offset);
}

final caloriesWindowProvider = StateProvider<CaloriesWindow>((ref) => const CaloriesWindow());

final weightWindowProvider = StateProvider<int>((ref) => 0);

/// La serie del peso, **costruita sul telefono** — S5.2.
///
/// 🚨 **Era `GET /series?metric=weight`.** Da S5 quell'endpoint non serve più il
/// peso: i dati del corpo non stanno sul server (decisione **D9-bis**).
///
/// ⚠️ `caloriesSeriesProvider` invece **continua a chiamare il server**: le
/// calorie del diario non sono un dato del corpo, e restano dove sono. Le due
/// serie hanno la stessa forma e due sorgenti diverse, ed è voluto.
final weightSeriesProvider = FutureProvider.autoDispose<Series>((ref) async {
  final giorni = ref.watch(weightWindowProvider);
  final misure = await ref.watch(storicoCorpoProvider.future);

  // `0` = tutto lo storico, come faceva il backend.
  final da = giorni == 0
      ? null
      : DateTime.now().subtract(Duration(days: giorni));

  final punti = misure
      .where((m) => m.pesoKg != null && (da == null || !m.giorno.isBefore(da)))
      .toList()
      // 🚨 In ordine **crescente**: `storicoMisure()` torna dal più recente,
      // e un grafico disegnato al contrario mostrerebbe un dimagrimento come
      // un ingrassamento.
      .reversed
      .toList();

  return Series(
    labels: punti.map((m) => DateFormat('d/MM').format(m.giorno)).toList(),
    values: punti.map((m) => m.pesoKg!).toList(),
    granularity: 'day',
    daysWithData: punti.length,
    // ⚠️ Con i dati in locale non c'è nessuna pagina precedente da chiedere:
    // c'è già tutto quello che esiste.
    canGoBack: false,
  );
});

final caloriesSeriesProvider = FutureProvider.autoDispose<Series>((ref) async {
  final finestra = ref.watch(caloriesWindowProvider);

  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>(
        '/series',
        query: {'metric': 'calories', 'days': finestra.days, 'offset': finestra.offset},
      );

  return Series.fromJson(data);
});

/// Il consiglio del giorno.
///
/// ⚠️ `null` quando il profilo non basta a calcolare un fabbisogno: senza
/// target l'AI non ha niente su cui costruire un consiglio, e inventarne uno
/// generico sarebbe rumore.
final adviceProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    final data = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/ai/advice');

    return data['body']?.toString();
  } on Object {
    // Il consiglio è un di più: se l'AI non risponde, la dashboard resta
    // utilizzabile. Far fallire tutta la schermata per questo sarebbe
    // sproporzionato.
    return null;
  }
});
