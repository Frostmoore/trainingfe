import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/api_exception.dart';
import '../../core/providers.dart';
import '../health/recupero_controller.dart';
import '../health/settimana_per_il_consiglio.dart';
import '../profile/corpo_controller.dart';
import '../profile/target_locale_controller.dart';
import '../training/bruciate_locali.dart';
import '../training/storico_unificato_controller.dart';
import 'data/dashboard_models.dart';
import 'giorno_scelto.dart';
import 'riassunto_settimana.dart';

/// Il riepilogo di oggi — D5.
///
/// 🚨 **Una chiamata sola.** Calorie, allenamenti, peso, sonno e parametri
/// arrivano insieme: con cinque richieste separate basta che una sia lenta
/// perché la schermata compaia a pezzi, e su rete mobile succede sempre.
final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((
  ref,
) async {
  /*
   * 🆕 **Segue il giorno scelto** — 3b-O.1b.2, 21/08/2026.
   *
   * 🚨 Era il pezzo che rendeva le frecce impossibili: questo provider
   * chiedeva **sempre oggi**, e una schermata che mostra i numeri di oggi sotto
   * la data di tre giorni fa è **peggio** di una senza frecce — perché non si
   * distingue da una che funziona.
   *
   * 💡 `date` si manda **solo quando non è oggi**: così la chiamata normale
   * resta identica a prima, e la cache del server non si spacca in una voce per
   * giorno per chi non sfoglia mai.
   */
  final giorno = ref.watch(giornoSceltoProvider);
  final adesso = DateTime.now();
  final eOggi = giorno == DateTime(adesso.year, adesso.month, adesso.day);

  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>(
        '/dashboard',
        query: eOggi
            ? null
            : {
                'date':
                    '${giorno.year.toString().padLeft(4, '0')}-'
                    '${giorno.month.toString().padLeft(2, '0')}-'
                    '${giorno.day.toString().padLeft(2, '0')}',
              },
      );

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
    this.protein = const [],
    this.period,
    this.avgConsumed = 0,
    this.avgBurned = 0,
    this.daysWithData = 0,
    this.canGoBack = true,
  });

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
  /// ⚠️ **Vuota se il server non li manda ancora**, e va bene: il campo è stato
  /// *aggiunto* a `/series`, e un'app nuova contro un server vecchio deve
  /// funzionare lo stesso. 💡 Chi la usa nasconde la voce invece di scrivere
  /// zero — uno zero direbbe «non hai mangiato proteine», che è un'altra cosa.
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
  ///
  /// ⚠️ Vuota sulle serie vecchie, e va bene: senza date non si fonde niente e
  /// resta quello che manda il server.
  final List<String> dates;

  final String granularity;
  final String? period;
  final int avgConsumed;

  /// ⛔ **Non usarlo: dopo la FASE 11 vale zero per tutti.**
  ///
  /// 🚨 È la media delle bruciate secondo il **server**, che gli allenamenti non
  /// li ha più. ⚠️ Resta nel modello solo perché il campo arriva ancora nella
  /// risposta: chi lo legge stampa uno zero credibile. 💡 Le bruciate vere si
  /// contano con `bruciateDi()` in `grafico_calorie.dart`.
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

/// I periodi che `/series` accetta — difetto del 21/08/2026.
///
/// ══ 🚨 NON È UN INTERVALLO LIBERO, E COSTA CARO CREDERLO ══════════════════
///
/// `SeriesController::index` valida `days` con `in:0,7,30,90,365`
/// (`trainingbe/app/Http/Controllers/Api/V1/Training/SeriesController.php`):
/// sono i **periodi dei pulsanti del grafico**, e `0` significa «tutto lo
/// storico». ⚠️ Qualunque altro numero prende `422 validation.in`.
///
/// 🚨 **È già successo, ed è passato inosservato per settimane.**
/// `_storiaCalorieProvider` chiedeva `days: 28` — la finestra dei calcoli di
/// forma — e il suo `catch` si mangiava l'errore: la **carica veniva calcolata
/// senza l'ingrediente delle calorie**, mostrando un numero plausibile e
/// sbagliato. Nessun avviso a schermo, nessun modo di accorgersene dall'app.
///
/// 💡 Sta scritto qui perché chi costruisce una finestra lo legga **prima** di
/// inventare un numero: chiedere il valore ammesso più vicino e tagliare la
/// lista in casa costa due righe, scoprirlo dal log costa settimane.
///
/// ⚠️ Se l'elenco cambia di là, cambia **anche qui**: sono due copie della
/// stessa regola, ed è il prezzo per poterla controllare senza rete.
const giorniAmmessiPerLeSerie = <int>{0, 7, 30, 90, 365};

/// La finestra scelta per il grafico delle calorie.
class CaloriesWindow {
  /// 🚨 L'`assert` è la rete: un periodo non ammesso **spacca subito in
  /// sviluppo**, invece di diventare un `422` che qualcuno intercetta e
  /// nasconde. ⚠️ In release non gira — lì la difesa è il test sul sorgente.
  const CaloriesWindow({this.days = 7, this.offset = 0})
    : assert(
        days == 0 || days == 7 || days == 30 || days == 90 || days == 365,
        'Il server accetta solo $giorniAmmessiPerLeSerie giorni per /series.',
      );

  final int days;
  final int offset;

  CaloriesWindow copyWith({int? days, int? offset}) =>
      CaloriesWindow(days: days ?? this.days, offset: offset ?? this.offset);
}

final caloriesWindowProvider = StateProvider<CaloriesWindow>(
  (ref) => const CaloriesWindow(),
);

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
        query: {
          'metric': 'calories',
          'days': finestra.days,
          'offset': finestra.offset,
        },
      );

  return Series.fromJson(data);
});

/// Il consiglio del giorno.
///
/// ⚠️ `null` quando il profilo non basta a calcolare un fabbisogno: senza
/// target l'AI non ha niente su cui costruire un consiglio, e inventarne uno
/// generico sarebbe rumore.
/// Il contesto del consiglio, **in un posto solo** — FASE 2-septies, 21/08.
///
/// ══ 🚨 PERCHÉ È UN PROVIDER E NON DUE LISTE DI PARAMETRI ══════════════════
///
/// Perché le richieste che chiedono un consiglio sono **due** — la lettura
/// normale e «Rigenera» — e prima costruivano il contesto **ognuna per conto
/// suo**. ⚠️ Non erano uguali: `rigeneraConsiglioProvider` mandava target e
/// recupero e **non** mandava la settimana né i tipi degli allenamenti.
///
/// 🚨 **E il server mette il contesto nella chiave della cache.** Due contesti
/// diversi sono due `context_hash` diversi, quindi:
///
/// 1. si tocca «Rigenera» → il server cancella il consiglio di oggi, ne genera
///    uno con il contesto **povero** e lo scrive con l'hash A. **Pagato.**
/// 2. l'app invalida `adviceProvider`, che rilegge con il contesto **pieno** →
///    hash B ≠ A → cache mancata → **si genera di nuovo. Pagato una seconda
///    volta.**
///
/// 💡 Cioè un tocco costava **due** chiamate al modello, e quella che l'utente
/// leggeva non era quella che aveva chiesto. ⚠️ Il difetto non si vedeva da
/// nessuna parte: il consiglio arrivava, era pure quello giusto, e il conto lo
/// pagavamo noi.
///
/// 🚨 Da qui la regola: **chi chiede un consiglio passa da questo provider.**
/// Un terzo chiamante che si ricostruisse la mappa a mano rimetterebbe in piedi
/// esattamente lo stesso difetto, e nessun test lo vedrebbe.
final contestoConsiglioProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
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
   */
      final locale = (await ref.watch(targetLocaleProvider.future)).target;

      /*
   * 🚨 **Il recupero lo manda l'app, per la stessa ragione del target** —
   * 16/08/2026. Sonno, variabilità e battito vivono nell'archivio locale (D9):
   * il server non li ha e non li conserva.
   *
   * ⚠️ **Si manda anche se il consenso manca**, e non è una svista: la
   * decisione sta sul server (`AiController::recuperoDallApp()`), che è l'unico
   * posto dove non si aggira. Un client che decide da solo cosa può mandare è
   * un client di cui bisogna fidarsi, e non ci si fida mai.
   */
      final recupero = await ref.watch(recuperoPerIlConsiglioProvider.future);

      /*
   * 🆕 20/08 — la settimana: sonno, HRV, battito e allenamenti.
   *
   * 🚨 Chiude due difetti con la stessa radice: il consiglio riceveva **una
   * notte sola** e **zero allenamenti dell'orologio**, e da lì inventava il
   * resto. *«non vede il mio allenamento di ieri»* e *«non è vero che di
   * solito dormo bene»* erano lo stesso problema visto da due lati.
   *
   * ⚠️ È facoltativa: se l'archivio non si legge, il consiglio parte con quello
   * che c'è.
   */
      final settimana = await ref
          .watch(settimanaPerIlConsiglioProvider.future)
          .then((s) => s.payload)
          .catchError((Object e) {
            debugPrint('contestoConsiglio: la settimana non si legge — $e');

            return const <String, Object>{};
          });

      /*
   * 🆕 20/08 — il **tipo** degli allenamenti della settimana.
   *
   * 🚨 Lo sa solo il telefono: sul server il tipo non esiste, e l'unico posto
   * dove esiste «Pesi» è l'orologio. ⚠️ Un guasto qui non deve far sparire il
   * consiglio: è un di più.
   */
      final tipi = await ref
          .watch(tipiDegliAllenamentiProvider.future)
          .catchError((Object e) {
            debugPrint(
              'contestoConsiglio: i tipi degli allenamenti non si leggono — $e',
            );

            return const <int, String>{};
          });

      /*
       * 🚨 **Le bruciate le manda l'app** — FASE 11.6, 21/08/2026.
       *
       * ⚠️ Prima le calcolava il server da `workout_sessions` e `daily_burns`.
       * Dopo il trasloco non ce le ha più: senza questa riga il consiglio del
       * giorno direbbe a chi si è allenato due ore che **non si è mosso** — e
       * lo direbbe con la stessa sicurezza di un consiglio giusto.
       *
       * 💡 Stessa strada del target e del recupero: quello che vive sul
       * telefono viaggia **dentro la richiesta**, e il server lo valida senza
       * conservarlo.
       */
      final oggi = DateTime.now();

      final bruciate = await ref
          .watch(
            bruciateLocaliDelGiornoProvider(
              DateTime(oggi.year, oggi.month, oggi.day),
            ).future,
          )
          .catchError((Object e) {
            debugPrint('contestoConsiglio: le bruciate non si leggono — $e');

            return 0;
          });

      /*
       * 🚨 **I due conteggi dell'allenamento** — FASE 11.6.
       *
       * ⚠️ Li mandava il server da `workout_sessions`. Senza, il consiglio
       * direbbe *«non ti alleni da sempre»* a chi si è allenato ieri — ed è la
       * frase che dovrebbe far tornare in palestra.
       */
      final settimanaAllenamento = await ref
          .watch(riassuntoSettimanaProvider.future)
          .catchError((Object e) {
            debugPrint('contestoConsiglio: il riassunto non si legge — $e');

            return const RiassuntoSettimana();
          });

      return {
        if (bruciate > 0) 'burned_kcal': bruciate,
        'training_last_30_days': settimanaAllenamento.ultimi30,
        if (settimanaAllenamento.giorniDallUltimo != null)
          'training_days_since_last': settimanaAllenamento.giorniDallUltimo,
        if (locale != null) ...{
          'target_kcal': locale.kcal,
          'target_protein_g': locale.macro.proteineG,
          'target_carbs_g': locale.macro.carboidratiG,
          'target_fat_g': locale.macro.grassiG,
        },
        ...recupero,
        ...settimana,

        /*
     * 🚨 Il **codice**, non l'etichetta: `STRENGTH_TRAINING`, non «Pesi». Il
     * server rifiuta tutto ciò che non è `[A-Z_]{2,48}`, ed è quella regex a
     * garantire che da qui non esca testo libero.
     */
        for (final voce in tipi.entries)
          'training_types[${voce.key}]': voce.value,
      };
    });

/// Il consiglio del giorno.
///
/// ⚠️ `null` quando il profilo non basta a calcolare un fabbisogno: senza
/// target l'AI non ha niente su cui costruire un consiglio, e inventarne uno
/// generico sarebbe rumore.
final adviceProvider = FutureProvider.autoDispose<Consiglio>((ref) async {
  /*
   * ⛔ **Sui giorni passati non si genera niente** — decisione del committente,
   * 21/08: *«semplicemente sui giorni passati niente consiglio del giorno»*.
   *
   * 💡 Ed è la scelta che costa meno: il consiglio si costruisce su «come sta
   * andando **oggi**» — quanto hai mangiato finora, che ore sono. ⚠️ Rigenerarlo
   * per il 18 agosto vorrebbe dire pagare una chiamata per un consiglio che non
   * serve piu' a nessuno.
   */
  final giorno = ref.watch(giornoSceltoProvider);
  final adesso = DateTime.now();

  if (giorno != DateTime(adesso.year, adesso.month, adesso.day)) {
    return const Consiglio();
  }

  final contesto = await ref.watch(contestoConsiglioProvider.future);

  try {
    final data = await ref
        .watch(apiClientProvider)
        .get<Map<String, dynamic>>('/ai/advice', query: contesto);

    return Consiglio(
      testo: data['body']?.toString(),
      generatoIl: DateTime.tryParse(
        data['generated_at']?.toString() ?? '',
      )?.toLocal(),
    );
  } on Object catch (e) {
    /*
     * ══ 🚨 SI SBUCCIA CON `unwrapError`, NON CON `on ...Exception` ═══════════
     *
     * ⚠️ **Il `catch` tipizzato che c'era qui non scattava mai.** Quello che
     * `dio` lancia è una `DioException` che **contiene** la nostra eccezione:
     * `on ForbiddenException` non la prendeva, e **tutto** finiva nel ramo
     * generico — cioè in un `Consiglio()` vuoto, che a valle diventa la
     * rotellina che gira per sempre.
     *
     * 🚨 Quindi non era rotto solo il caso «niente AI»: era rotto anche il caso
     * **«serve il consenso»**, che era stato scritto apposta il 12/08 e non ha
     * mai funzionato. 💡 Lo stesso errore trovato lo stesso giorno in
     * `SchermataAggiorna`: è una trappola del client, non di questo file.
     */
    final tradotto = ApiClient.unwrapError(e);

    /*
     * 🚨 **Il 403 del consenso NON è «l'AI non risponde»** — S9.
     *
     * La differenza fra «non ha funzionato» e «devi dare il permesso» è tutto:
     * la prima è una cosa che si aspetta, la seconda una cosa che si fa.
     */
    if (tradotto is ForbiddenException) {
      // ⚠️ Su `/ai/advice` il 403 è del consenso; il piano senza AI risponde
      // con `plan_without_ai`, che `ApiClient` traduce nello stesso tipo.
      return tradotto.message.contains('piano') ||
              tradotto.message.contains('abbonamento')
          ? const Consiglio(senzaAi: true)
          : const Consiglio(serveConsenso: true);
    }

    /*
     * 🆕 **Quota o gettoni finiti**: l'assistente c'è ma non si può usare.
     * ⚠️ Non è un guasto e non è un'attesa: è una porta chiusa, e va detto.
     */
    if (tradotto is AiQuotaExceededException) {
      return const Consiglio(senzaAi: true);
    }

    // Il consiglio è un di più: se l'AI non risponde, la dashboard resta
    // utilizzabile. Far fallire tutta la schermata per questo sarebbe
    // sproporzionato.
    return const Consiglio();
  }
});

/// Il consiglio, o il motivo per cui non c'è.
class Consiglio {
  const Consiglio({
    this.testo,
    this.serveConsenso = false,
    this.senzaAi = false,
    this.generatoIl,
  });

  final String? testo;

  /// Quando l'ha generato il server (`generated_at`).
  ///
  /// 🆕 20/08 — serve a `consiglioDaMostrareProvider` per scrivere «di ieri»
  /// invece di un generico «vecchio». 💡 Una data dice a chi legge **quanto**
  /// fidarsi di quel testo; «vecchio» non dice niente.
  final DateTime? generatoIl;

  /// L'app deve **portare al consenso**, non limitarsi a tacere.
  final bool serveConsenso;

  /// 🆕 **L'assistente non è disponibile**: niente piano, o gettoni finiti.
  ///
  /// ══ 🚨 IL DIFETTO CHE QUESTO CAMPO CHIUDE — 21/08/2026 ═══════════════════
  ///
  /// 📌 Il committente: *«se non ho attiva l'ai perché ho 0 crediti o perché non
  /// ho l'abbonamento, mi mostra il consiglio del giorno in perpetuo
  /// caricamento»*.
  ///
  /// ⚠️ È l'altra faccia della regola del 20/08 *«la card non sparisce mai»*: si
  /// è impedito che sparisse, e non si è previsto il caso in cui **un consiglio
  /// non può proprio esserci**. 🚨 Una rotellina che gira per sempre è peggio di
  /// una card assente: dice «sto arrivando» e non arriva mai.
  ///
  /// 💡 «Non ce l'hai» e «sta arrivando» sono due frasi diverse, e solo la prima
  /// dice a una persona cosa può fare.
  final bool senzaAi;

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
    /*
     * 🚨 **Lo stesso contesto della lettura, e non è un dettaglio di stile** —
     * FASE 2-septies, 21/08.
     *
     * Qui prima si costruiva una mappa **più povera** (target e recupero, senza
     * la settimana e senza i tipi). ⚠️ Il server mette il contesto nella chiave
     * della cache: un contesto diverso è un `context_hash` diverso, quindi la
     * lettura che segue non trovava niente e **rigenerava una seconda volta**.
     * Due chiamate al modello per un tocco, e il testo pagato per primo
     * buttato.
     *
     * 💡 Con `contestoConsiglioProvider` i due hash coincidono: si genera una
     * volta, e la lettura subito dopo trova la cache.
     */
    final contesto = await ref.read(contestoConsiglioProvider.future);

    await ref
        .read(apiClientProvider)
        .get<Map<String, dynamic>>(
          '/ai/advice',
          query: {'manuale': 1, ...contesto},
        );
  };
});
