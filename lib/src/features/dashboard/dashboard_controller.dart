import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/errors/api_exception.dart';
import '../../core/providers.dart';
import '../health/recupero_controller.dart';
import '../health/settimana_per_il_consiglio.dart';
import '../profile/corpo_controller.dart';
import '../profile/target_locale_controller.dart';
import '../training/storico_unificato_controller.dart';
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
    this.dates = const [],
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
      dates: ((j['dates'] as List?) ?? const []).map((e) => e.toString()).toList(),
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

  /// Le date vere delle colonne (`yyyy-mm-dd`) — 19/08/2026.
  ///
  /// 🚨 `labels` e' testo da mostrare (`d/m`): non ci si ricostruisce sopra un
  /// giorno. Queste servono a unire alla serie le calorie **misurate
  /// dall'orologio**, che stanno solo sul telefono e vanno accostate **per
  /// giorno**.
  ///
  /// ⚠️ Vuota sulle serie vecchie, e va bene: senza date non si fonde niente e
  /// resta quello che manda il server.
  final List<String> dates;

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
final adviceProvider = FutureProvider.autoDispose<Consiglio>((ref) async {
  /*
   * 🚨 **Il fabbisogno lo manda l'app, perché il server non può più
   * calcolarlo** — S8.2.
   *
   * Da S5 il peso non sta sul server: senza, il consiglio del giorno arrivava
   * al modello con le calorie assunte e **nessun numero con cui
   * confrontarle**, cioè muto o generico.
   *
   * ⚠️ **Si manda solo il risultato, non il peso.** Il target è un numero
   * derivato; il peso da cui nasce resta su questo telefono, che è il punto di
   * tutta la fase S5. E il server lo **inoltra al modello senza conservarlo**.
   *
   * 💡 Se non c'è — profilo incompleto, nessuna pesata — non si manda niente e
   * il consiglio esce come può. Meglio un consiglio generico che uno costruito
   * su un numero inventato.
   */
  final locale = (await ref.watch(targetLocaleProvider.future)).target;

  /*
   * 🚨 **Il recupero lo manda l'app, per la stessa ragione del target** —
   * 16/08/2026.
   *
   * Sonno, variabilità e battito vivono nell'archivio locale (D9): il server
   * non li ha e non li conserva. Se li vuole il consiglio, glieli deve passare
   * chi ce li ha.
   *
   * 💡 E risolve un conflitto che sembrava grosso: il consiglio **non può**
   * essere generato da un job del server, perché il server questi dati non li
   * vede. Lo chiede l'app — al massimo una volta per fascia — e il tetto di tre
   * al giorno resta senza nessuno schedulatore.
   *
   * ⚠️ **Si manda anche se il consenso manca**, e non è una svista: la
   * decisione sta sul server (`AiController::recuperoDallApp()`), che è l'unico
   * posto dove non si aggira. Un client che decide da solo cosa può mandare è
   * un client di cui bisogna fidarsi, e non ci si fida mai.
   */
  final recupero = await ref.watch(recuperoPerIlConsiglioProvider.future);

  /*
   * 🆕 20/08 — il **tipo** degli allenamenti della settimana.
   *
   * 🚨 Lo sa solo il telefono: sul server il tipo non esiste, e l'unico posto
   * dove esiste «Pesi» e' l'orologio. Vedi `tipiDegliAllenamentiProvider`.
   *
   * ⚠️ **Un guasto qui non deve far sparire il consiglio.** Il tipo e' un di
   * piu': se l'archivio locale non si legge, il consiglio parte con quello che
   * c'e' — e' la stessa regola per cui il recupero e' facoltativo.
   */
  /*
   * 🆕 20/08 — la settimana: sonno, HRV, battito e allenamenti.
   *
   * 🚨 Chiude due difetti con la stessa radice: il consiglio riceveva **una
   * notte sola** e **zero allenamenti dell'orologio**, e da li' inventava il
   * resto. *«non vede il mio allenamento di ieri»* e *«non e' vero che di
   * solito dormo bene»* erano lo stesso problema visto da due lati.
   *
   * ⚠️ Anche questa e' facoltativa: se l'archivio non si legge, il consiglio
   * parte con quello che c'e'.
   */
  final settimana = await ref
      .watch(settimanaPerIlConsiglioProvider.future)
      .then((s) => s.payload)
      .catchError((Object e) {
    debugPrint('adviceProvider: la settimana non si legge — $e');

    return const <String, Object>{};
  });

  final tipi = await ref
      .watch(tipiDegliAllenamentiProvider.future)
      .catchError((Object e) {
    debugPrint('adviceProvider: i tipi degli allenamenti non si leggono — $e');

    return const <int, String>{};
  });

  try {
    final data = await ref
        .watch(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/ai/advice',
          query: {
            if (locale != null) ...{
              'target_kcal': locale.kcal,
              'target_protein_g': locale.macro.proteineG,
              'target_carbs_g': locale.macro.carboidratiG,
              'target_fat_g': locale.macro.grassiG,
            },
            ...recupero,
            ...settimana,

            /*
             * 🚨 Il **codice**, non l'etichetta: `STRENGTH_TRAINING`, non
             * «Pesi». Il server rifiuta tutto cio' che non e' `[A-Z_]{2,48}`,
             * ed e' quella regex a garantire che da qui non esca testo libero.
             */
            for (final voce in tipi.entries)
              'training_types[${voce.key}]': voce.value,
          },
        );

    return Consiglio(
      testo: data['body']?.toString(),
      generatoIl: DateTime.tryParse(data['generated_at']?.toString() ?? '')?.toLocal(),
    );
  } on ForbiddenException {
    /*
     * 🚨 **Il 403 del consenso NON è «l'AI non risponde»** — S9.
     *
     * Da S9 le rotte AI pretendono il consenso esplicito, e senza rispondono
     * `403` con `code: ai_consent_required`. ⚠️ Prima questo `catch` inghiottiva
     * **tutto** allo stesso modo, quindi il consiglio del giorno spariva in
     * silenzio e sembrava un guasto — è così che l'ha segnalato il committente:
     * *«non mi mostra il consiglio del giorno»*.
     *
     * 💡 La differenza fra «non ha funzionato» e «devi dare il permesso» è
     * tutto: la prima è una cosa che si aspetta, la seconda è una cosa che si
     * fa. E l'unico posto in cui si può fare è la schermata dei consensi.
     *
     * ⚠️ **Si riconosce dal 403 e non da un codice**, perché
     * `ForbiddenException` il codice non lo porta. Oggi è esatto: su
     * `/ai/advice` l'unico 403 è quello del consenso — la quota esaurita
     * risponde **429**. Se un domani quell'endpoint imparasse a rifiutare per
     * un altro motivo, il posto giusto per distinguerli sarà l'eccezione, non
     * questo ramo.
     */
    return const Consiglio(serveConsenso: true);
  } on Object {
    // Il consiglio è un di più: se l'AI non risponde, la dashboard resta
    // utilizzabile. Far fallire tutta la schermata per questo sarebbe
    // sproporzionato.
    return const Consiglio();
  }
});

/// Il consiglio, o il motivo per cui non c'è.
class Consiglio {
  const Consiglio({this.testo, this.serveConsenso = false, this.generatoIl});

  final String? testo;

  /// Quando l'ha generato il server (`generated_at`).
  ///
  /// 🆕 20/08 — serve a `consiglioDaMostrareProvider` per scrivere «di ieri»
  /// invece di un generico «vecchio». 💡 Una data dice a chi legge **quanto**
  /// fidarsi di quel testo; «vecchio» non dice niente.
  final DateTime? generatoIl;

  /// L'app deve **portare al consenso**, non limitarsi a tacere.
  final bool serveConsenso;

  bool get haTesto => testo != null && testo!.isNotEmpty;
}

/// Rigenera il consiglio **pagando** — 16/08/2026.
///
/// 🚨 `manuale: 1` fa saltare la cache al server: senza, la chiamata
/// restituirebbe lo stesso testo di prima **senza spendere niente**, e il
/// pulsante sembrerebbe rotto.
///
/// ⚠️ Manda anche target e recupero, come la lettura normale: un consiglio
/// rigenerato senza quel contesto sarebbe **peggiore** di quello che sostituisce
/// — e l'utente avrebbe pagato per peggiorarlo.
final rigeneraConsiglioProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final locale = (await ref.read(targetLocaleProvider.future)).target;
    final recupero = await ref.read(recuperoPerIlConsiglioProvider.future);

    await ref.read(apiClientProvider).get<Map<String, dynamic>>(
      '/ai/advice',
      query: {
        'manuale': 1,
        if (locale != null) ...{
          'target_kcal': locale.kcal,
          'target_protein_g': locale.macro.proteineG,
          'target_carbs_g': locale.macro.carboidratiG,
          'target_fat_g': locale.macro.grassiG,
        },
        ...recupero,
      },
    );
  };
});
