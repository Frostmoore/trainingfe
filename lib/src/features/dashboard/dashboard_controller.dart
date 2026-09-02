import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/api_exception.dart';
import '../../core/providers.dart';
import '../../core/storage/archivio_salute.dart';
import '../diary/data/diario_locale.dart';
import '../diary/data/serie_del_cibo.dart';
import '../health/recupero_controller.dart';
import '../health/settimana_per_il_consiglio.dart';
import '../profile/corpo_controller.dart';
import '../profile/target_locale_controller.dart';
import '../training/bruciate_locali.dart';
import '../training/storico_unificato_controller.dart';
import 'data/dashboard_models.dart';
import 'data/serie.dart';
import 'giorno_scelto.dart';
import 'riassunto_settimana.dart';
import 'ultima_notizia.dart';

/// 🚨 **`Series` vive in `data/serie.dart` e si riesporta da qui** — I2.5.
///
/// ⛔ Ci sono venti file che scrivono `import '.../dashboard_controller.dart'`
/// per averla. 💡 Riesportarla li lascia tutti intatti: spostare una classe *e*
/// riscrivere venti import nello stesso giro vorrebbe dire non sapere quale
/// delle due cose ha rotto cosa.
export 'data/serie.dart';

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

  final riepilogo = DashboardSummary.fromJson(data);

  /*
   * ══ 🚨 IL CIBO VIENE DAL TELEFONO — Parte I, I2.5 ═══════════════════════
   *
   * ⛔ `nutrition.totals` nasceva da `food_entries`, che dal 03/09/2026 non è
   * più il posto in cui il diario vive. ⚠️ Lasciando la lettura, «Oggi» avrebbe
   * mostrato **zero calorie assunte senza un errore** — e uno zero credibile
   * non si distingue da una giornata a digiuno.
   *
   * 💡 È lo stesso innesto della FASE 11.5 per gli allenamenti: il resto della
   * risposta — ora, percentuale di giornata, sonno, parametri — resta del
   * server, che quelle cose le sa ancora.
   */
  ref.watch(revisioneDiarioProvider);

  final diario = ref.watch(diarioLocaleProvider);
  final totali = await diario.totaliDel(giorno);
  final quante = await diario.quanteVociDel(giorno);

  return riepilogo.conNutrizione(
    riepilogo.nutrition.conIlCiboDelTelefono(
      kcal: totali.kcal,
      protein: totali.proteine,
      carbs: totali.carboidrati,
      fat: totali.grassi,
      entriesCount: quante,
    ),
  );
});

/*
| ══ ⛔ `giorniAmmessiPerLeSerie` NON ESISTE PIU' — I2.5, 03/09/2026 ═════════
|
| Era l'elenco `{0, 7, 30, 90, 365}` che `SeriesController` accettava, copiato
| qui per poterlo controllare senza rete. 🚨 Ha reso un servizio e ha fatto un
| danno:
|
| - **il servizio**: il 21/08 ha spiegato perche' la carica fosse calcolata
|   senza le calorie — `_storiaCalorieProvider` chiedeva 28, prendeva un
|   `422 validation.in`, e un `catch` se lo mangiava;
| - **il danno**: il test che lo sorvegliava cercava i **letterali** `'days': N`
|   e `tdeeMisuratoProvider` scriveva `days: _finestraGiorni`. 🚨 Restava verde
|   mentre il TDEE misurato **non funzionava per nessuno**. 📌 *«Un test che
|   passa per il motivo sbagliato e' peggio di uno rosso»*.
|
| 💡 Da I2.5 la serie delle calorie si costruisce sul telefono
| (`serie_del_cibo.dart`): non c'e' piu' nessun elenco di periodi ammessi, e i
| giorni che servono si chiedono e basta. ⚠️ Il suo posto lo ha preso
| `test/il_diario_resta_sul_telefono_test.dart`, che sorveglia una cosa piu'
| utile: che nessuno rimetta il diario sul server.
*/

/// La finestra scelta per il grafico delle calorie.
class CaloriesWindow {
  /// ⚠️ **Qui c'era un `assert` sui periodi ammessi, e non serve più.**
  ///
  /// Sorvegliava l'elenco di `SeriesController` (`0, 7, 30, 90, 365`), perché un
  /// numero fuori elenco diventava un `422` che qualcuno intercettava in
  /// silenzio. 🆕 Da I2.5 la serie la costruisce il telefono: **qualunque numero
  /// di giorni è lecito**, e i pulsanti offrono quelli che offrono per scelta
  /// d'interfaccia, non per un limite del server.
  ///
  /// 💡 `0` continua a significare «tutto lo storico», ed è il valore che manda
  /// il pulsante «Tutto».
  const CaloriesWindow({this.days = 7, this.offset = 0});

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
/// 🆕 **E da I2.5 anche `caloriesSeriesProvider` nasce qui.** Fino al
/// 03/09/2026 le due serie avevano la stessa forma e due sorgenti diverse — il
/// peso dal telefono, le calorie dal server — ed era voluto. ⛔ Dopo il trasloco
/// del diario quella distinzione non esiste più: le sorgenti sono una sola.
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

/// La serie delle calorie, **costruita sul telefono** — Parte I, I2.5.
///
/// 🚨 **Era `GET /series?metric=calories`.** Dopo il trasloco il server il
/// diario non ce l'ha più: la stessa chiamata avrebbe risposto un grafico di
/// zeri, credibile e falso.
///
/// 💡 Adesso `caloriesSeriesProvider` e `weightSeriesProvider` sono finalmente
/// la stessa cosa — due serie dallo stesso archivio locale — e la nota che
/// spiegava perché fossero diverse non serve più.
final caloriesSeriesProvider = FutureProvider.autoDispose<Series>((ref) async {
  ref.watch(revisioneDiarioProvider);

  final finestra = ref.watch(caloriesWindowProvider);

  return ref
      .watch(serieDelCiboProvider)
      .calorie(giorni: finestra.days, offset: finestra.offset);
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
/// Quanti giorni indietro viaggiano con il consiglio.
///
/// 📌 *«diciamo tutta la settimana»*.
///
/// 🚨 **Deve valere quanto `AiController::GIORNI_DI_STORIA`** (7): il server
/// costruisce `week_food` sulla sua finestra e noi mandiamo `week_burned` sulla
/// nostra. ⛔ Due finestre diverse darebbero al modello una settimana di cibo e
/// dieci giorni di bruciate, e i confronti che ne uscirebbero sarebbero
/// plausibili e sbagliati.
const giorniDelContesto = 7;

/// `2026-08-30` — la forma che le serie della settimana usano da sempre.
String _etichettaDelGiorno(DateTime g) =>
    '${g.year.toString().padLeft(4, '0')}-'
    '${g.month.toString().padLeft(2, '0')}-'
    '${g.day.toString().padLeft(2, '0')}';

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
      final oggiPerLaSettimana = DateTime(oggi.year, oggi.month, oggi.day);

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

      /*
       * ══ 🕘 QUANDO È SUCCESSA L'ULTIMA COSA — 3b-AB, 30/08/2026 ═══════════
       *
       * 📌 *«questo può succedere solo dopo che apri l'app e solo dopo che si è
       * registrato un pasto, un allenamento o il sonno»*.
       *
       * 🚨 **Il server non può ricavarselo da solo**: dopo D9 e la FASE 11.6
       * non ha più né le sedute né i dati del sensore. I pasti li conta lui,
       * allenamenti e sonno glieli diciamo noi — e prende il più recente dei
       * due. Vedi `AiController::qualcosaDiNuovo()`.
       *
       * ⛔ **Il campo si manda SEMPRE, anche vuoto**, e non è una svista: sul
       * server «assente» vuol dire *app vecchia che non lo sa* — e in quel caso
       * si genera come prima. «Vuoto» vuol dire *non ho mai registrato niente*,
       * e allora non si genera.
       *
       * 🚨 Se questa riga diventasse condizionale, un'app nuova senza dati
       * verrebbe scambiata per un'app vecchia, e pagherebbe una chiamata per
       * fascia raccontando una giornata in cui non è successo niente.
       *
       * ⚠️ **Non entra nel prompt**: `contestoConsiglio()` sul server è una
       * lista bianca, e questo campo non ne fa parte. Serve a decidere *se*
       * chiamare il modello, non a dirgli qualcosa.
       */
      /*
       * ══ 📅 LA SETTIMANA DI BRUCIATE E PESO — 31/08/2026 ═══════════════════
       *
       * 📌 *«anche i giorni passati (diciamo tutta la settimana) di tutti i
       * dati che passo (anche in forma compressa, per non aumentare troppo il
       * costo della chiamata)»*.
       *
       * 🚨 **Le manda l'app perché il server non le ha**: le bruciate dopo la
       * FASE 11.6 e il peso dopo S5 vivono nell'archivio locale. ⛔ Il cibo
       * invece **non** si manda da qui: `food_entries` è del server, e una
       * seconda sede della stessa risposta è una sede che diverge.
       *
       * 💡 Compressa: un giorno per riga, un numero. Sette giorni costano una
       * manciata di token.
       */
      final giorniIndietro = [
        for (var i = 1; i <= giorniDelContesto; i++)
          oggiPerLaSettimana.subtract(Duration(days: i)),
      ];

      final bruciateSettimana = await ref
          .watch(
            bruciateLocaliProvider(
              giorniIndietro.map(_etichettaDelGiorno).join(','),
            ).future,
          )
          .catchError((Object e) {
            debugPrint('contestoConsiglio: la settimana bruciata non si legge — $e');

            return const <String, int>{};
          });

      final pesateSettimana = await ref
          .watch(storicoCorpoProvider.future)
          .catchError((Object e) {
            debugPrint('contestoConsiglio: le pesate non si leggono — $e');

            return const <MisuraCorpo>[];
          });

      final notizia = await ref
          .watch(ultimaNotiziaProvider.future)
          .catchError((Object e) {
            debugPrint('contestoConsiglio: l\'ultima notizia non si legge — $e');

            return null;
          });

      /*
       * ⛔ **Solo le pesate della finestra, e solo quelle vere.** Una riga senza
       * peso è una misura del corpo senza bilancia (per esempio la sola massa
       * grassa): mandarla con un peso nullo darebbe al modello un giorno che
       * sembra pesato e non lo è.
       */
      final pesateDaMandare = [
        for (final m in pesateSettimana)
          if (m.pesoKg != null &&
              m.giorno.isAfter(
                oggiPerLaSettimana.subtract(
                  const Duration(days: giorniDelContesto),
                ),
              ))
            m,
      ];

      final pesoDiOggi = pesateSettimana
          .where((m) => m.pesoKg != null)
          .map((m) => m.pesoKg)
          .firstOrNull;

      return {
        'last_event_at': notizia?.toUtc().toIso8601String() ?? '',
        if (bruciate > 0) 'burned_kcal': bruciate,
        'training_last_30_days': settimanaAllenamento.ultimi30,
        if (settimanaAllenamento.giorniDallUltimo != null)
          'training_days_since_last': settimanaAllenamento.giorniDallUltimo,
        if (locale != null) ...{
          'target_kcal': locale.kcal,
          'target_protein_g': locale.macro.proteineG,
          'target_carbs_g': locale.macro.carboidratiG,
          'target_fat_g': locale.macro.grassiG,

          /*
           * 🚨 **Il TDEE dà senso al target, e senza è un numero nudo.**
           *
           * 📌 *«Deve capire il target calorico mio, il mio tdee»*.
           *
           * 💡 1.900 kcal su un TDEE di 2.000 sono un deficit piccolo; 1.900 su
           * 3.000 sono un deficit grosso, e i due meritano consigli opposti —
           * nel secondo il rischio non è mangiare troppo, è non arrivare a
           * fine giornata. ⛔ Con il solo target il modello non può distinguerli.
           */
          'tdee_kcal': locale.tdee.round(),
        },

        /*
         * ⚠️ **IL PESO ESCE DAL TELEFONO, ED È UN CAMBIO DI S5.**
         *
         * 🚨 Poche righe sopra c'è scritto *«Si manda solo il risultato, non il
         * peso»*. Da oggi il peso parte, su richiesta esplicita del committente
         * — ed è scritto qui perché nessuno lo scopra leggendo quel commento e
         * lo creda un difetto.
         *
         * 💡 **Il perimetro non cambia**: il server lo inoltra al modello e non
         * lo conserva, come fa da 16/08 con sonno, HRV e battito — che sono
         * dati dell'art. 9, cioè molto più delicati. Vedi
         * `AiController::corpoDallApp()`.
         *
         * ⛔ E il prompt gli vieta di parlarne: serve per le proteine, non è un
         * argomento.
         */
        'weight_kg': ?pesoDiOggi,
        ...recupero,
        ...settimana,

        /*
     * 🚨 Il **codice**, non l'etichetta: `STRENGTH_TRAINING`, non «Pesi». Il
     * server rifiuta tutto ciò che non è `[A-Z_]{2,48}`, ed è quella regex a
     * garantire che da qui non esca testo libero.
     */
        for (final voce in tipi.entries)
          'training_types[${voce.key}]': voce.value,

        /*
         * 💡 La stessa forma delle altre serie della settimana (`day` + `v`),
         * perché il server le passa tutte dallo stesso setaccio
         * (`AiController::serieDallApp`). ⚠️ Una forma diversa vorrebbe dire un
         * secondo sanificatore, e il secondo è quello che diverge.
         */
        for (final (i, giorno) in giorniIndietro.indexed) ...{
          if (bruciateSettimana[_etichettaDelGiorno(giorno)] case final k?) ...{
            'week_burned[$i][day]': _etichettaDelGiorno(giorno),
            'week_burned[$i][v]': k,
          },
        },

        for (final (i, m) in pesateDaMandare.indexed) ...{
          'week_weight[$i][day]': _etichettaDelGiorno(m.giorno),
          'week_weight[$i][v]': m.pesoKg,
        },
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
