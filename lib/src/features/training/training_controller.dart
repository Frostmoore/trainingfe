import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/archivio_salute.dart';
import '../auth/auth_controller.dart';
import '../dashboard/gettoni_controller.dart';
import '../health/health_controller.dart';
import 'data/limiti_delle_schede.dart';
import 'data/serie_prevista.dart';
import 'porta_giu_le_schede.dart';

/// Una scheda assegnata — A5.1.
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.exercisesCount,
    this.notes,
    this.exercises = const [],
    this.editable = false,
    this.imageUrl,
    this.authorName,
    this.authorIsMe = false,
    this.giorni = 1,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) => WorkoutPlan(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? '',
    notes: j['notes']?.toString(),
    exercisesCount: (j['exercises_count'] as num?)?.toInt() ?? 0,
    exercises: (j['exercises'] as List? ?? const [])
        .map((e) => PlanExercise.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    // 🚨 Chi può modificare cosa lo dice il SERVER (campo `editable`).
    // Dedurlo qui confrontando l'autore con l'utente vorrebbe dire riscrivere
    // in Dart una regola che vive in `WorkoutPlanPolicy`: due copie divergono
    // sempre, e quella sbagliata mostra un pulsante «Modifica» che il server
    // rifiuta con un 403.
    editable: j['editable'] == true,
    imageUrl: j['image_url']?.toString(),
    authorName: (j['author'] as Map?)?['name']?.toString(),
    authorIsMe: (j['author'] as Map?)?['is_me'] == true,

    /*
     * 🆕 3b-C.6 — quanti giorni ha questa scheda.
     *
     * 📌 Serve al limite di chi non è abbonato: *«possono essere solo schede a
     * un giorno singolo»*.
     *
     * ⚠️ **`1` e non `0` quando `days` non c'è.** Una scheda senza giorni
     * dichiarati è una scheda a giorno unico — è la forma più vecchia, quella
     * di prima di D2 — e contarla come zero la farebbe passare per «senza
     * giorni», cioè per una cosa che non esiste.
     */
    giorni: (j['days'] as List?)?.length ?? 1,
  );

  final int id;
  final String name;
  final String? notes;
  final int exercisesCount;
  final List<PlanExercise> exercises;

  /// Vero solo per le schede che l'iscritto si è scritto da solo.
  final bool editable;

  /// La copertina — C23. `null` quando nessuno l'ha caricata.
  final String? imageUrl;

  final String? authorName;
  final bool authorIsMe;

  /// Quanti giorni ha la scheda — 3b-C.6. `1` per quelle a giorno unico.
  final int giorni;

  /// Da mostrare sotto il nome: «scritta dal tuo trainer» dà contesto a un
  /// elenco che altrimenti è solo una lista di nomi.
  String get attribuzione => authorIsMe
      ? 'Scheda tua'
      : (authorName == null ? '' : 'Scritta da $authorName');
}

/// Una riga della scheda.
class PlanExercise {
  const PlanExercise({
    required this.id,
    required this.name,
    required this.prescription,
    required this.serie,
    this.exerciseId,
    this.restSec,
    this.targetWeight,
    this.notes,
    this.imageUrl,
  });

  factory PlanExercise.fromJson(Map<String, dynamic> j) => PlanExercise(
    /*
     * ══ 🚨 SENZA ID SI LEGGE LO STESSO — 3b-D.17, 25/08/2026 ═══════════════
     *
     * 📌 *«Se modifico una scheda, quando clicco salva mi dà errore … Adesso la
     * pagina schede mi dice sempre "Qualcosa è andato storto"»*.
     *
     * ⛔ Qui c'era `(j['id'] as num).toInt()`, un **cast duro**. Gli id delle
     * righe li dava il server, e **da B.17 il server non c'è più**: un
     * esercizio scritto dall'editor non ha nessun id, e questa riga esplodeva
     * con *«type 'Null' is not a subtype of type 'num'»*.
     *
     * 🚨 **E non si rompeva solo il salvataggio.** La scheda restava scritta
     * nell'archivio, e `schedeUniteProvider` la rilegge per costruire
     * **l'elenco**: da quel momento la pagina Schede intera non si apriva più.
     * ⚠️ Un dato scritto male avvelena tutte le letture, non solo quella che lo
     * ha prodotto — ed è il motivo per cui un cast duro su un dato **locale** è
     * sempre una bomba a tempo.
     *
     * 💡 **Zero, e non fa niente**: nessuno usa questo campo. L'identità di un
     * esercizio dentro una scheda è **il suo posto**, e per le righe scese dal
     * server prima di B.17 l'id continua a leggersi.
     */
    id: (j['id'] as num?)?.toInt() ?? 0,
    /*
     * ══ 🚨 IL NOME STA IN CIMA, E `exercise.name` E' IL RIPIEGO — 3b-D.17 ══
     *
     * ⛔ Qui si leggeva **solo** `exercise.name`, cioe' il nome che manda il
     * server. Un esercizio scritto dall'editor lo mette in cima (`name`), e
     * quindi si chiamava **«Esercizio»** — in elenco, nel player, ovunque.
     *
     * 🚨 **E' lo stesso difetto di B.17**, quando ogni scheda ricevuta si
     * chiamava «Scheda» da mesi: si legge il nome da dove lo scrive **una**
     * delle sorgenti, e l'altra resta muta. ⚠️ Non da' errore: da' un'etichetta
     * generica, che sembra una scelta.
     *
     * 💡 Stesso ordine di `EsercizioDellaScheda.fromJson`: prima quello che
     * scrive chi ha compilato, poi quello del catalogo.
     */
    name:
        j['name']?.toString() ??
        (j['exercise'] as Map?)?['name']?.toString() ??
        'Esercizio',

    /// ⚠️ **`id` è la riga della scheda, `exerciseId` è l'esercizio.** Due
    /// numeri diversi che si somigliano: usare il primo per cercare nel
    /// catalogo trova l'esercizio sbagliato — e non dà nessun errore, perché un
    /// id qualunque nel catalogo di solito esiste.
    /*
     * ⚠️ **E anche l'aggancio al catalogo sta in due posti.** L'editor scrive
     * `exercise_id` (3b-D.4.2), il server annida `exercise.id`.
     *
     * 🚨 Perderlo non da' nessun errore: fa **sparire i muscoli** dalla figura
     * e il MET dalla stima, cioe' due schermate che diventano mute senza dire
     * perche'.
     */
    exerciseId:
        (j['exercise_id'] as num?)?.toInt() ??
        ((j['exercise'] as Map?)?['id'] as num?)?.toInt(),
    // 🚨 Arriva già formattata dal backend («3 × 8-12»): comporla qui
    // significherebbe avere due formati diversi fra app e pannello per la
    // stessa scheda.
    prescription: j['prescription']?.toString() ?? '',
    imageUrl: (j['exercise'] as Map?)?['image_url']?.toString(),
    restSec: (j['rest_sec'] as num?)?.toInt(),
    targetWeight: (j['target_weight'] as num?)?.toDouble(),
    notes: j['notes']?.toString(),

    /*
     * ══ 🆕 LE SERIE, RIGA PER RIGA — 3b-D.1 ════════════════════════════════
     *
     * 🚨 **Qui passa TUTTO**: le schede scritte con l'editor nuovo, quelle
     * scritte prima, e quelle che arrivano dal server — che dal server
     * continuano ad arrivare nel formato vecchio, perche' `plan_exercises` le
     * serie riga per riga non le ha.
     *
     * 💡 `serieDellEsercizio` le espande, quindi da qui in giu' **nessuno deve
     * sapere che sono esistiti due formati**: il player, la card dei numeri e
     * l'editor leggono tutti delle righe.
     */
    serie: serieDellEsercizio(j),
  );

  final int id;
  final String name;

  /// L'id dell'esercizio **nel catalogo**, quando il server lo manda.
  ///
  /// 💡 Serve a `pesiDellaScheda` per sapere che muscoli allena senza
  /// riscrivere i muscoli dentro la scheda: stanno nel catalogo, e ci stanno una
  /// volta sola.
  final int? exerciseId;
  final String prescription;

  /// Le serie previste, **una per riga** — 3b-D.1.
  ///
  /// 💡 Su una scheda scritta prima di oggi sono l'espansione di
  /// `sets × prescription`: la scheda diceva gia' questo, in un modo piu'
  /// povero. ⚠️ Non e' mai vuota — vedi `serieDellEsercizio`.
  final List<SeriePrevista> serie;
  final int? restSec;
  final double? targetWeight;
  final String? notes;

  /// L'illustrazione dell'esercizio — C23.
  final String? imageUrl;
}

/// Le schede dell'iscritto, **dal telefono** — 3b-B.17, 24/08/2026.
///
/// ══ 📌 IL SERVER NON C'ENTRA PIÙ ══════════════════════════════════════════
///
/// *«la scheda risiede sul telefono (e finisce nel backup). Basta, niente
/// server, sticazzi crea solo problemi»*.
///
/// ⛔ Qui c'erano **tre** sorgenti da tenere d'accordo: le schede sul server,
/// quelle arrivate in chat, e la copia locale con la sincronizzazione fra le
/// prime due. 💡 Adesso ce n'è una: quello che sta sul telefono.
///
/// ⚠️ Resta `schedePortateGiuProvider`, che è **un'importazione una tantum**:
/// le schede che stavano già sul server scendono una volta e poi il server non
/// si guarda più. Vedi `porta_giu_le_schede.dart`.
final schedeUniteProvider = FutureProvider.autoDispose<List<WorkoutPlan>>((
  ref,
) async {
  // ⚠️ Prima si porta giù quello che c'era; poi si legge il telefono.
  await ref.watch(schedePortateGiuProvider.future);

  final archivio = ref.watch(archivioSaluteProvider);

  /*
   * 🚨 Si ridisegna quando le schede cambiano: drift non notifica da solo chi
   * legge con `Future`, e senza questo chi ne salva una resterebbe a guardare
   * l'elenco di prima.
   */
  ref.watch(revisioneSchedeProvider);

  final locali = await archivio.tutteLeSchede();

  /*
   * ══ 📅 IN ORDINE DI NASCITA, NON DI ULTIMA MODIFICA — 3b-C.6 ═════════════
   *
   * ⛔ `tutteLeSchede()` ordina per `aggiornataIl`, e per un elenco andava
   * benissimo. 🚨 Da quando esiste il limite delle tre schede non basta più:
   * rinominare una scheda di marzo la porterebbe in cima e sbloccherebbe
   * quella, bloccando una arrivata ieri. **Un limite che si aggira rinominando
   * non è un limite.**
   *
   * ⚠️ `creataIl` è nullable — le righe che c'erano prima una data di nascita
   * non ce l'hanno — e lì si cade su `aggiornataIl`, che per quelle è la stima
   * migliore disponibile.
   */
  final ordinate = [...locali]
    ..sort(
      (a, b) => (b.creataIl ?? b.aggiornataIl).compareTo(
        a.creataIl ?? a.aggiornataIl,
      ),
    );

  return [
    for (final r in ordinate)
      WorkoutPlan.fromJson({
        ...(json.decode(r.scheda) as Map).cast<String, dynamic>(),
        'id': r.id,
        'name': r.nome,
        'editable': r.mia,
      }),
  ];
});

/// Quali schede sono bloccate per chi non è abbonato — 3b-C.6.
///
/// 🚨 **Se il flag non si sa, non si blocca niente.** `gettoniProvider` va in
/// rete: un errore lì non deve nascondere le schede a chi le ha pagate. ⛔ Meglio
/// un limite che non scatta che un abbonato chiuso fuori dai propri allenamenti.
///
/// 💡 `valueOrNull` fa esattamente questo: mentre carica, e se fallisce, vale
/// `null` — e `schedeBloccate` con `null` non blocca.
final schedeBloccateProvider =
    FutureProvider.autoDispose<Map<int, MotivoBlocco>>((ref) async {
      final schede = await ref.watch(schedeUniteProvider.future);

      return schedeBloccate(
        schede: schede,
        illimitata: ref.watch(gettoniProvider).valueOrNull?.illimitata,

        /*
         * ✅ **E adesso il server lo manda** — 3b-C.8, 25/08/2026.
         *
         * 📌 *«aggiusta anche il server in modo che gli utenti (free users o
         * iscritti in una palestra o con un trainer) abbiano il flag abbonato e
         * il flag tier»*.
         *
         * 💡 `PianoAttivo::eAbbonato()` lato server, dentro il profilo. ⚠️ In
         * questo impianto **paga il tenant**: chi è iscritto a una palestra
         * abbonata è coperto da quella, ed è il modello di vendita.
         *
         * 🚨 `null` mentre il profilo carica, e `null` non blocca: chi apre
         * l'app non deve vedere le proprie schede spegnersi per un istante.
         */
        abbonato: ref.watch(authControllerProvider).user?.abbonato,
      );
    });

/// Cambia quando una scheda viene scritta o buttata.
final revisioneSchedeProvider = StateProvider<int>((ref) => 0);

/// Il dettaglio di una scheda, con gli esercizi.
///
/// ══ 🚨 DAL TELEFONO, NON DALLA RETE — 3b-B.16.9, 24/08/2026 ══════════════
///
/// 📌 *«tutto deve stare sul telefono … perché potrei non avere rete quando mi
/// alleno»*.
///
/// ⛔ Prima questo provider andava **sempre** al server, e il player lo usa per
/// costruire la lista degli esercizi: senza campo, l'allenamento non partiva
/// affatto. In una palestra interrata è la differenza fra un'app che funziona e
/// una che no.
///
/// ⛔ **E qui c'era un secondo ramo, per gli id negativi**, che andava a pescare
/// nell'altro archivio locale — quello delle schede della chat. 💡 Dal 25/08 di
/// archivi ce n'è **uno**: un id è un id, e si cerca in un posto solo.
final planDetailProvider = FutureProvider.autoDispose.family<WorkoutPlan, int>((
  ref,
  id,
) async {
  final locale = await ref.watch(archivioSaluteProvider).laScheda(id);

  if (locale != null) {
    return WorkoutPlan.fromJson({
      ...(json.decode(locale.scheda) as Map).cast<String, dynamic>(),
      // ⚠️ **L'id e il nome li comanda la riga, non il JSON dentro.** Quello
      // di una scheda arrivata in chat è l'id che aveva sul telefono del
      // trainer, e non vuol dire niente qui.
      'id': locale.id,
      'name': locale.nome,
      'editable': locale.mia,
    });
  }

  /*
   * ⛔ **E se il telefono non ce l'ha, non c'e' nient'altro da guardare.**
   *
   * 🚨 Qui c'era il ripiego sulla rete. Da B.17 le schede vivono sul telefono e
   * basta: una scheda che qui non c'e' **non esiste**, e chiederla al server
   * vorrebbe dire far ricomparire dal nulla una che l'iscritto ha cancellato.
   */
  throw StateError('Scheda $id non trovata sul telefono');
});

/// Le scritture sulle schede — C11, riscritte in 3b-B.17.
///
/// ══ 📌 TUTTO SUL TELEFONO ═════════════════════════════════════════════════
///
/// *«la scheda risiede sul telefono (e finisce nel backup). Basta, niente
/// server»*.
///
/// ⛔ Queste tre chiamate andavano al server. Adesso scrivono nell'archivio
/// locale, e basta: 💡 niente rete vuol dire niente errore di rete, niente
/// salvataggio che fallisce in palestra, niente due copie da tenere d'accordo.
///
/// ⚠️ L'iscritto si scrive le proprie (decisione D1); quelle del trainer le
/// legge e le esegue — `mia = false`, e l'app non mostra il pulsante.
class PlanActions {
  PlanActions(this._ref);

  final Ref _ref;

  ArchivioSalute get _archivio => _ref.read(archivioSaluteProvider);

  void _rileggi() => _ref.read(revisioneSchedeProvider.notifier).state++;

  /// Crea una scheda **qui**, e ne restituisce l'id.
  Future<int> create({
    required String name,
    String? notes,
    required List<Map<String, dynamic>> exercises,
    List<List<Map<String, dynamic>>>? giorni,
  }) async {
    /*
     * 💡 **L'id lo dà il database.** Qui si calcolava a mano — il minimo già
     * usato meno uno, per stare nei negativi e non pestare gli id del server —
     * e adesso non serve più: la tabella è una sola, e `autoIncrement` non può
     * sbagliare il conto.
     *
     * ⚠️ **Nel JSON l'id non si scrive**, ed è di proposito: chi rilegge la
     * scheda prende `id`, `name` e `editable` dalla **riga**, non da dentro la
     * busta. Scriverlo qui vorrebbe dire tenerne due d'accordo per sempre —
     * e per le schede arrivate in chat quello dentro è addirittura l'id che
     * avevano sul telefono di chi le ha mandate.
     */
    final id = await _archivio.aggiungiScheda(
      nome: name,
      mia: true,
      origine: 'mia',
      scheda: json.encode({
        'name': name,
        'notes': notes,
        'editable': true,
        'exercises': exercises,
        ...giorniInJson(giorni),
      }),
    );

    _rileggi();

    return id;
  }

  /// Riscrive una scheda che c'è già.
  ///
  /// ⚠️ **`exercises` assente vuol dire «non toccare gli esercizi»**: rinominare
  /// una scheda non deve costringere a rimandare tutte le righe — ed è anche la
  /// guardia che impedisce a una rinomina di svuotarla.
  /// I giorni, nel formato che il resto dell'app già legge — 3b-D.7.
  ///
  /// ══ 🚨 `days` E' LA CHIAVE CHE DECIDE SE UNA SCHEDA E' MULTI-GIORNO ══════
  ///
  /// 💡 La leggono già `WorkoutPlan.giorni` (che alimenta il limite dei non
  /// abbonati, 3b-C.6) e `SchedaAllenamento.fromJson`. ⛔ Inventare qui una
  /// chiave nuova vorrebbe dire una scheda a cinque giorni che al limite ne
  /// risulta uno — cioè il limite aggirato senza che nessuno se ne accorga.
  ///
  /// ⚠️ **`exercises` resta scritto anche quando ci sono i giorni**, ed è il
  /// primo: una versione dell'app che i giorni non li conosce apre comunque la
  /// scheda e ci trova dentro il giorno 1, invece di una lista vuota.
  static Map<String, dynamic> giorniInJson(
    List<List<Map<String, dynamic>>>? giorni,
  ) {
    if (giorni == null || giorni.length < 2) return const {};

    return {
      'days': [
        for (final g in giorni) {'exercises': g},
      ],
    };
  }

  Future<void> update({
    required int id,
    required String name,
    String? notes,
    List<Map<String, dynamic>>? exercises,
    List<List<Map<String, dynamic>>>? giorni,
  }) async {
    final vecchia = await _archivio.laScheda(id);

    if (vecchia == null) return;

    final scheda = (json.decode(vecchia.scheda) as Map).cast<String, dynamic>();

    scheda['name'] = name;
    scheda['notes'] = notes;

    if (exercises != null) scheda['exercises'] = exercises;

    if (exercises != null) {
      final giorniScritti = giorniInJson(giorni);

      /*
       * ⚠️ **Da più giorni a uno solo, la chiave va TOLTA.** Lasciarla vuota o
       * con un giorno solo terrebbe la scheda «multi-day» per chi legge
       * `days`, e — visto che le multi-day sono quelle bloccate senza
       * abbonamento (3b-C.6) — una scheda ridotta a un giorno resterebbe
       * bloccata senza un motivo visibile.
       */
      if (giorniScritti.isEmpty) {
        scheda.remove('days');
      } else {
        scheda.addAll(giorniScritti);
      }
    }

    await _archivio.aggiornaScheda(
      id: id,
      nome: name,
      scheda: json.encode(scheda),
    );

    _rileggi();
    _ref.invalidate(planDetailProvider(id));
  }

  /// Butta una scheda.
  ///
  /// 📌 *«se serve una nuova scheda il trainer la rimanda e l'utente cancella la
  /// vecchia e usa la nuova»*: qui cancellare è normale, non un incidente.
  Future<void> delete(int id) async {
    await _archivio.cancellaScheda(id);

    _rileggi();
  }
}

final planActionsProvider = Provider<PlanActions>(PlanActions.new);
