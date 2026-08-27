/// La progressione degli esercizi: storia, analisi, e chi può vederle — 3b-I.A.
///
/// ══ 🚨 DUE COSE DIVERSE, E SOLO UNA COSTA ═════════════════════════════════
///
/// | | Da dove viene | Costa | Chi la vede |
/// |---|---|---|---|
/// | **La sparkline** | dal telefono, sempre | niente | solo gli abbonati |
/// | **La riga dell'AI** | dal server, su richiesta | 1 gettone | solo gli abbonati |
///
/// 💡 La sparkline si disegna **senza chiedere niente a nessuno**: i dati sono
/// già sul telefono. ⛔ Chiamare il server per disegnarla sarebbe far pagare una
/// cosa che abbiamo già.
///
/// ══ ⚠️ E L'ANALISI NON SI RIGENERA DA SOLA ════════════════════════════════
///
/// 🚨 Non c'è **nessun** percorso in questo file che chiami il modello senza che
/// qualcuno abbia toccato un pulsante. Un'analisi che si rigenera aprendo la
/// pagina sarebbe un gettone speso ogni volta che si guarda una scheda — e la
/// persona lo scoprirebbe dal saldo, non dall'app.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/api_exception.dart';
import '../../core/providers.dart';
import '../../core/storage/archivio_salute.dart';
import '../auth/auth_controller.dart';
import '../health/health_controller.dart';
import 'data/limiti_delle_schede.dart';
import 'data/progressione.dart';
import 'data/storia_della_scheda.dart';

/// L'ora della sera in cui l'analisi si fa da sola, se oggi non ti sei allenato.
///
/// ══ 📌 LA REGOLA, IN UNA RIGA ═════════════════════════════════════════════
///
/// 📌 *«in automatico lo fa una volta sola al giorno dopo l'allenamento (se c'è
/// un allenamento oggi, altrimenti intorno alle 20)»*.
///
/// 💡 **Dopo l'allenamento** perché è il momento in cui c'è qualcosa di nuovo da
/// dire: farla prima vorrebbe dire raccontare la giornata di ieri.
///
/// ⚠️ **Non c'è nessun lavoro in sottofondo**: l'app non ha un job che gira alle
/// 20. Vuol dire «dalle 20 in poi, la prima volta che apri quella scheda» — che
/// è l'unico momento in cui possiamo fare qualcosa, e anche l'unico in cui
/// serve, perché è quando la stai guardando.
const oraDellaSera = 20;

/// Se questa persona può vedere progressione e analisi.
///
/// ⛔ **`soloSeAbbonato` e NON `senzaLimiti`** — corretto il 27/08/2026.
///
/// 📌 *«io ho AI illimitata ma non l'abbonamento, quindi quella cosa non la
/// dovrei vedere»*. 🚨 Avevo riusato la regola delle schede, che apre anche a
/// chi ha l'AI illimitata: è la regola giusta **per quel limite**, e quella
/// sbagliata per **questo gate**.
///
/// ⚠️ **E l'app diceva una cosa che il server negava**: `AiController` guarda
/// `PianoAttivo::eAbbonato()`. Il pulsante c'era e la chiamata sarebbe stata
/// rifiutata — che a schermo si legge come un guasto, non come un limite.
final puoVedereIProgressiProvider = Provider.autoDispose<bool>(
  (ref) => soloSeAbbonato(ref.watch(authControllerProvider).user?.abbonato),
);

/// I primati di ogni esercizio, su **tutto** lo storico — 3b-I.F.
///
/// 🚨 Una lettura a parte da [storiaDellaSchedaProvider], che è tagliata a otto
/// sedute: qui serve il contrario, cioè tutto. ⛔ Allargare la finestra avrebbe
/// fatto crescere anche quello che si manda al modello — dieci volte i token per
/// fargli fare un `max` che il telefono fa in un millisecondo, e che sbaglierebbe.
final primatiDellaSchedaProvider = FutureProvider.autoDispose
    .family<Map<int, PrimatiDellEsercizio>, int>((ref, schedaLocale) async {
      final tutto = await ref
          .watch(archivioSaluteProvider)
          .storiaDegliEsercizi(schedaLocale, quanteSedute: 500);

      return {
        for (final voce in tutto.entries) voce.key: primatiDaiPunti(voce.value),
      };
    });

/// La storia degli esercizi di una scheda, dal telefono.
///
/// ⚠️ **L'id è quello locale** (`SchedeSulTelefono.id`), che è quello che
/// `WorkoutPlan.id` porta davvero — vedi la nota su `storiaDegliEsercizi`.
final storiaDellaSchedaProvider = FutureProvider.autoDispose
    .family<Map<int, List<PuntoDiProgressione>>, int>(
      (ref, schedaLocale) =>
          ref.watch(archivioSaluteProvider).storiaDegliEsercizi(schedaLocale),
    );

/// Le versioni della scheda, dalla più vecchia — 3b-I.E.
final versioniDellaSchedaProvider = FutureProvider.autoDispose
    .family<List<VersioneDellaScheda>, int>(
      (ref, schedaLocale) => ref
          .watch(archivioSaluteProvider)
          .versioniDellaScheda(schedaLocale),
    );

/// L'analisi già scritta, se c'è.
final analisiDellaSchedaProvider = FutureProvider.autoDispose
    .family<AnalisiInCorso?, int>((ref, schedaLocale) async {
      ref.watch(revisioneDellAnalisiProvider);

      final riga = await ref
          .watch(archivioSaluteProvider)
          .analisiDellaScheda(schedaLocale);

      if (riga == null) return null;

      final storia = await ref.watch(
        storiaDellaSchedaProvider(schedaLocale).future,
      );

      return AnalisiInCorso(
        righe: _daJson(riga.righe),
        riassunto: riga.riassunto ?? '',
        fattaIl: riga.fattaIl,

        /*
         * 🚨 **Il confronto si fa QUI, non in un widget.** «È ancora attuale?»
         * è una domanda sui dati, e un widget che la ricalcola per conto suo è
         * un secondo posto dove la regola può divergere — cioè un'app che dice
         * «aggiornata» in una schermata e «superata» in un'altra.
         */
        superata: riga.impronta != improntaDelloStorico(storia),
      );
    });

/// 💡 Il contatore che fa ridisegnare dopo un'analisi nuova: drift non notifica
/// da solo su queste tabelle, e invalidare l'archivio intero ricaricherebbe
/// mezza app.
final revisioneDellAnalisiProvider = StateProvider<int>((ref) => 0);

/// L'analisi come la legge la schermata.
class AnalisiInCorso {
  const AnalisiInCorso({
    required this.righe,
    required this.fattaIl,
    required this.superata,
    this.riassunto = '',
  });

  /// La frase che guarda gli esercizi **insieme** — 3b-I.F.
  ///
  /// 💡 È la sola cosa che una riga per esercizio non può dire, e per questo è
  /// la più utile delle due. ⚠️ Può essere vuota: il setaccio la svuota se
  /// prescriveva, e il modello la lascia vuota quando non c'è niente da dire su
  /// tutta la scheda.
  final String riassunto;

  final List<ProgressoEsercizio> righe;
  final DateTime fattaIl;

  /// Da quando è stata scritta sono state fatte altre sedute.
  final bool superata;

  /// Se è già stata fatta **oggi**.
  ///
  /// ⚠️ **Il giorno di calendario, non ventiquattr'ore**: «una volta al giorno»
  /// vuol dire questo. ⛔ Con una finestra mobile, un'analisi fatta alle 23 di
  /// ieri bloccherebbe quella di stasera alle 20 — e chi guarda direbbe che non
  /// funziona, perché per lui è un altro giorno.
  ///
  /// 🚨 **Vale solo per l'automatico.** Chi tocca il pulsante paga, e chi paga
  /// rifà quante volte vuole.
  bool get fattaOggi {
    final adesso = DateTime.now();

    return fattaIl.year == adesso.year &&
        fattaIl.month == adesso.month &&
        fattaIl.day == adesso.day;
  }

  ProgressoEsercizio? per(int esercizioId) {
    for (final r in righe) {
      if (r.esercizioId == esercizioId) return r;
    }

    return null;
  }
}

/// Perché l'analisi non si è potuta fare.
enum EsitoAnalisi {
  fatta,

  /// ⛔ Non è abbonato. Porta alla modale.
  serveAbbonamento,

  /// ⚠️ Non ci sono abbastanza sedute: non è un guasto, è che non c'è niente
  /// da raccontare.
  troppoPocoStorico,

  /// ⛔ **C'è già, e da allora non è successo niente.** ⚠️ Non è un errore e non
  /// è un limite: è la risposta giusta a una domanda che non andava fatta. 💡 Su
  /// questo esito non si dice niente a nessuno — l'analisi che si sta guardando
  /// è quella buona.
  giaAggiornata,

  /// Gettoni finiti, o quota del mese esaurita.
  senzaGettoni,

  /// La rete, il server, il modello: una cosa sola perché la persona non può
  /// farci niente di diverso in nessuno dei tre casi.
  nonRiuscita,
}

/// Chiede al server l'analisi della scheda, e la scrive sul telefono.
///
/// ══ ⚠️ L'ORDINE DEI CONTROLLI NON È CASUALE ═══════════════════════════════
///
/// Prima *hai diritto*, poi *c'è qualcosa da dire*, poi *non l'hai appena
/// fatta*. 🚨 Girato, chi non è abbonato si sentirebbe dire «troppo poco
/// storico» — cioè una spiegazione vera che nasconde quella che conta.
///
/// ⚠️ **`WidgetRef` e non `Ref`**: la chiama un pulsante, e in Riverpod i due
/// tipi non sono intercambiabili — `Ref` è quello di dentro un provider. 💡 È
/// la stessa firma di `salvaLaSettimana`, per la stessa ragione.
Future<EsitoAnalisi> chiediLAnalisi(
  WidgetRef ref, {
  required int schedaLocale,
  required Map<int, String> nomiDegliEsercizi,
  bool automatica = false,
}) async {
  if (!ref.read(puoVedereIProgressiProvider)) {
    return EsitoAnalisi.serveAbbonamento;
  }

  final storia = await ref.read(
    storiaDellaSchedaProvider(schedaLocale).future,
  );

  if (!valeLaPenaAnalizzare(storia)) return EsitoAnalisi.troppoPocoStorico;

  final gia = await ref.read(
    analisiDellaSchedaProvider(schedaLocale).future,
  );

  /*
   * ══ 🚨 IL LIMITE VALE SOLO PER L'AUTOMATICO ═══════════════════════════
   *
   * 📌 *«se pago 1 gettone lo devo poter rifare eh»*.
   *
   * ⛔ **Prima il tetto valeva anche per il pulsante**, ed era sbagliato:
   * mettere un limite a chi sta pagando vuol dire prendergli i soldi e
   * decidere al posto suo quando può spenderli. 🚨 Chi tocca ha deciso lui —
   * e ha anche letto «1 gettone» sul pulsante.
   *
   * 💡 Sull'automatico invece un limite ci vuole, perché nessuno l'ha chiesto:
   * lo decide [_quandoDaSola].
   */
  if (automatica && !await _quandoDaSola(ref, gia, schedaLocale)) {
    return EsitoAnalisi.giaAggiornata;
  }

  /*
   * ══ 📐 I CAMBI DELLA SCHEDA VANNO INSIEME ALLE SEDUTE — 3b-I.E ═════════
   *
   * 📌 *«deve vedere com'era prima e com'era dopo»*.
   *
   * 🚨 **È la differenza fra una lettura e un'osservazione.** Senza, il modello
   * vede solo dei numeri che salgono o scendono e può soltanto ripeterli — è
   * esattamente il *«15 ripetizioni in entrambe le sedute»* che non serviva a
   * niente. ⛔ Con i cambi può dire perché: una serie in più, un recupero
   * accorciato, un peso alzato la settimana scorsa.
   *
   * ⚠️ **E previene una frase falsa detta con sicurezza**: ripetizioni scese
   * dopo aver aggiunto una quarta serie non sono un peggioramento, e senza
   * questo pezzo il modello non ha modo di saperlo.
   */
  final versioni = await ref.read(
    versioniDellaSchedaProvider(schedaLocale).future,
  );

  final primati = await ref.read(
    primatiDellaSchedaProvider(schedaLocale).future,
  );

  /*
   * ⚠️ **Si mandano solo gli esercizi che hanno una storia.** Mandare anche
   * quelli mai fatti vorrebbe dire pagare del contesto per farsi rispondere
   * «poco storico» — una cosa che sappiamo già senza chiedere a nessuno.
   */
  final corpo = <Map<String, Object?>>[];

  for (final voce in storia.entries) {
    if (voce.value.length < 2) continue;

    final cambi = cambiDellEsercizio(versioni, voce.key);

    corpo.add({
      'id': voce.key,
      'nome': nomiDegliEsercizi[voce.key] ?? 'Esercizio',
      'sedute': [for (final p in voce.value) p.versoIlServer()],

      // 💡 Assente quando non è cambiato niente, invece di una lista vuota: un
      // campo che c'è sempre invita il modello a parlarne comunque.
      if (cambi.isNotEmpty)
        'cambi_alla_scheda': [for (final c in cambi) c.versoIlServer()],

      /*
       * 🏆 **I primati, calcolati qui e non dal modello** — 3b-I.F.
       *
       * 📌 *«Mi deve dire qualcosa di utile, sennò che cazzo lo pago a fare?»*.
       *
       * 🚨 I modelli linguistici sbagliano i confronti fra numeri, e un «è il
       * tuo record» falso è **una bugia detta con entusiasmo** — peggio di una
       * frase banale. ⛔ Quindi il massimo di sempre e da quante sedute il
       * carico è fermo li conta il telefono, e il modello li racconta.
       */
      if (primati[voce.key] case final p?) 'primati': p.versoIlServer(),
    });
  }

  if (corpo.isEmpty) return EsitoAnalisi.troppoPocoStorico;

  try {
    final risposta = await ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/ai/scheda/progresso',
          body: {'esercizi': corpo},
        );

    final righe = [
      for (final r in (risposta['esercizi'] as List? ?? const []))
        if (r is Map) ProgressoEsercizio.daJson(Map<String, Object?>.from(r)),
    ];

    final riassunto = (risposta['riassunto'] as String?) ?? '';

    await ref
        .read(archivioSaluteProvider)
        .scriviLAnalisi(
          AnalisiDelleSchedeCompanion.insert(
            schedaLocale: Value(schedaLocale),
            righe: jsonEncode([for (final r in righe) r.aJson()]),

            /*
             * 🚨 **L'impronta è quella dello storico INTERO**, non solo degli
             * esercizi mandati. ⚠️ Con l'impronta dei soli mandati, una seduta
             * su un esercizio nuovo non farebbe scattare «superata» — e
             * l'analisi resterebbe a dire che quell'esercizio non c'è.
             */
            impronta: improntaDelloStorico(storia),
            riassunto: Value(riassunto),
            fattaIl: DateTime.now(),
          ),
        );

    ref.read(revisioneDellAnalisiProvider.notifier).state++;

    return EsitoAnalisi.fatta;
  } on Object catch (e) {
    /*
     * 🚨 **`unwrapError` e non un `catch` tipizzato.** Quello che `dio` lancia
     * è una `DioException` che *contiene* la nostra eccezione: `on
     * ForbiddenException` non scatta mai, ed è la trappola già pagata in
     * `dashboard_controller.dart` il 12/08.
     */
    final tradotto = ApiClient.unwrapError(e);

    if (tradotto is ForbiddenException) return EsitoAnalisi.serveAbbonamento;

    if (tradotto is AiQuotaExceededException) return EsitoAnalisi.senzaGettoni;

    return EsitoAnalisi.nonRiuscita;
  }
}

/// ⏰ È il momento in cui l'analisi si fa da sola? — 3b-I.G, 27/08/2026.
///
/// ══ 📌 LA REGOLA ══════════════════════════════════════════════════════════
///
/// 📌 *«in automatico lo fa una volta sola al giorno dopo l'allenamento (se c'è
/// un allenamento oggi, altrimenti intorno alle 20)»*.
///
/// | | Condizione |
/// |---|---|
/// | 1 | non è già stata fatta **oggi** |
/// | 2 | ti sei allenato oggi con questa scheda **oppure** sono passate le [oraDellaSera] |
///
/// ── 💡 Perché il momento conta, e non solo il numero ─────────────────────
///
/// **Dopo l'allenamento** c'è qualcosa di nuovo da dire; prima no. ⛔ Un'analisi
/// che parte alle 8 del mattino racconta la giornata di ieri, e poi non si
/// rifà: chi si allena alle 19 la trova vecchia proprio quando gli servirebbe.
///
/// ⚠️ **La prima analisi in assoluto non aspetta niente.** Chi apre la scheda
/// per la prima volta deve vedere la funzione, non un riquadro vuoto con la
/// promessa che stasera arriva qualcosa.
Future<bool> _quandoDaSola(
  WidgetRef ref,
  AnalisiInCorso? gia,
  int schedaLocale,
) async {
  if (gia == null) return true;

  if (gia.fattaOggi) return false;

  final oggi = await ref.read(allenatoOggiProvider(schedaLocale).future);

  return oggi || DateTime.now().hour >= oraDellaSera;
}

/// Ti sei allenato **oggi** con questa scheda?
///
/// ⚠️ **Solo le sedute finite**: una ancora aperta è un allenamento in corso, e
/// analizzarlo a metà racconterebbe un calo che non è successo. 💡 È la stessa
/// regola di `storiaDegliEsercizi`, ed è il motivo per cui l'analisi arriva
/// quando chiudi la seduta e non quando la apri.
final allenatoOggiProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  schedaLocale,
) async {
  final storia = await ref.watch(storiaDellaSchedaProvider(schedaLocale).future);
  final adesso = DateTime.now();

  for (final punti in storia.values) {
    for (final p in punti) {
      if (p.data.year == adesso.year &&
          p.data.month == adesso.month &&
          p.data.day == adesso.day) {
        return true;
      }
    }
  }

  return false;
});

/// @nodoc
List<ProgressoEsercizio> _daJson(String testo) {
  final letto = jsonDecode(testo);

  if (letto is! List) return const [];

  return [
    for (final r in letto)
      if (r is Map) ProgressoEsercizio.daJson(Map<String, Object?>.from(r)),
  ];
}
