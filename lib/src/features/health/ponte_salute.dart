import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../../core/storage/archivio_salute.dart';
import 'dati_salute.dart';
import 'salute_in_piu.dart';
import 'sessioni_di_sonno.dart';
import 'tipo_allenamento.dart';

/// Il ponte fra il telefono e l'archivio locale — S3.3.
///
/// 🚨 **I dati entrano da qui e non escono più.** Prima di S1 esisteva
/// `POST /health/ingest`, che mandava sonno e parametri vitali al server: quel
/// canale **non esiste più** (decisione D9 di `todo-2026-08-11.md`). Questo
/// ponte scrive **solo** in `ArchivioSalute`, che vive sul telefono.
///
/// ⚠️ Chi in futuro aggiungesse qui una chiamata di rete starebbe annullando
/// l'intera fase di sicurezza. Non è una svista possibile: è il punto in cui
/// bisogna fermarsi e rileggere §C11.
///
/// **Cosa legge**: HRV, battito a riposo e le fasi del sonno. Non le calorie
/// bruciate — quelle sono attività, non un parametro del corpo, e restano un
/// problema di S5.
class PonteSalute {
  PonteSalute(this._archivio, {Health? salute}) : _salute = salute ?? Health();

  final ArchivioSalute _archivio;
  final Health _salute;

  /// I tipi che **leggiamo davvero**.
  ///
  /// 🚨 Non coincide con quelli che **chiediamo**: vedi `_tipiDaAutorizzare`.
  /// La differenza non e' una svista, e' la difesa descritta piu' sotto.
  static const _tipiDaLeggere = <HealthDataType>[
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESTING_HEART_RATE,

    /*
     * 🆕 **Il battito continuo** — 07/09/2026, per il Training Effect Index.
     *
     * ⛔ **Il ramo c'era gia' in `_metricaDi` e non veniva mai percorso**: il
     * tipo non stava qui, e il permesso non era nel manifest. 🚨 Codice morto
     * che sembrava vivo — chi leggeva quella riga credeva che il battito medio
     * arrivasse, e invece la colonna restava vuota.
     *
     * 💡 Il TEI si calcola sui **minuti** passati a una certa frequenza rispetto
     * alla propria riserva: con un campione al giorno non esiste.
     *
     * ⚠️ **E' il dato piu' granulare che raccogliamo**, ed e' dichiarato: sta
     * nel registro dei trattamenti e nell'informativa. Chi lo aggiunge da
     * qualche altra parte legga prima quelli.
     */
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_AWAKE,

    /*
     * ⚡ **La velocità** — 08/09/2026.
     *
     * ⛔ **Il 08/09 una sonda ha detto «SPEED nessun campione» e l'ho letto come
     * "l'orologio non la scrive".** 🚨 Falso: Health Connect ne mostra
     * 3,792 km/h per la camminata delle 10:49, scritti da Zepp. A mancare era
     * `READ_SPEED` nel manifest, che non c'era e non veniva chiesto.
     *
     * ⚠️ E' lo stesso errore dei 23.471 passi: uno zero misurato su una porta
     * chiusa da noi, e attribuito a chi sta dall'altra parte.
     */
    HealthDataType.SPEED,

    /*
     * 🆕 FASE 1 — le calorie bruciate con l'attivita'.
     *
     * 🚨 **`ACTIVE_ENERGY_BURNED`, mai `TOTAL_CALORIES_BURNED`**: il totale
     * comprende il metabolismo basale, e il nostro obiettivo e' gia' un TDEE che
     * il basale ce l'ha dentro. Sommarlo lo conterebbe due volte — circa
     * +1.600 kcal al giorno, con un numero che resta plausibile.
     */
    HealthDataType.ACTIVE_ENERGY_BURNED,

    /*
     * ══ ⛔ `STEPS` NON STA QUI, E CI E' STATO PER UN GIORNO ════════════════
     *
     * 🚨 Il 06/09/2026 l'ho aggiunto a questo elenco, e i passi hanno cominciato
     * ad arrivare come **record grezzi**, uno per campione, sommati per
     * sorgente da `ArchivioSalute.passiDi()`.
     *
     * ⚠️ **Il confronto con l'aggregato, misurato il 07/09**, dice che quella
     * somma sbaglia — ma non sempre e non nel verso che sembrava:
     *
     *     giorno   somma grezza   aggregato
     *     09-04       24.435        24.506
     *     09-05       23.471        22.470
     *     09-06        7.533         8.192
     *     09-07        1.413         1.195
     *
     * ⛔ **I ventiquattromila erano veri**: quei giorni aveva camminato davvero
     * cosi' tanto, e la prima diagnosi — «e' doppio conteggio» — era sbagliata.
     * 🚨 Ma nei giorni in cui **due sorgenti scrivono insieme** i conti
     * divergono in tutti e due i versi, perche' il massimo per sorgente perde i
     * pezzi che una sorgente ha e l'altra no.
     *
     * 💡 **La ragione vera per cui si usa l'aggregato non e' quindi il doppio
     * conteggio: e' che la deduplicazione non e' un problema nostro.** Health
     * Connect sa quali record si sovrappongono e quali no, sorgente per
     * sorgente; noi possiamo solo indovinare, e ogni euristica — somma, massimo,
     * media — sbaglia su un caso diverso.
     *
     * ⚠️ E il commento di [passiAlGiorno] lo diceva gia', anche se con una
     * motivazione piu' netta di quella che i dati sostengono.
     *
     * 💡 In piu': una riga al giorno invece di trecento campioni.
     *
     * ⚠️ `STEPS` resta fra i tipi da **autorizzare**: senza il permesso
     * l'aggregato non risponde. E' esattamente la distinzione che questo elenco
     * esiste per fare.
     */

    /*
     * 🆕 FASE 1.8 — gli allenamenti.
     *
     * 💡 Health Connect e' il **magazzino**, non la fonte: ci scrivono l'app
     * dell'orologio, Strava, Google Fit. Per questo prendiamo **tutti** i tipi e
     * non solo la palestra — una corsa e un giro in bici arrivano dallo stesso
     * canale, e chi si allena senza aprire la nostra app li ha solo li'.
     *
     * ⚠️ E **mai** `WORKOUT_ROUTE`, che e' la traccia GPS: dice dove abiti e che
     * giro fai la domenica. E' il dato piu' identificante che il telefono
     * possieda, e non serve a niente di quello che facciamo.
     */
    HealthDataType.WORKOUT,

    /*
     * ══ ⛔ IL BMI NON SI LEGGE. MAI. SU NESSUNA PIATTAFORMA. ══════════════
     *
     * 📌 Era stato chiesto — *«peso, massa grassa e bmi direttamente dalla
     * bilancia»* — e la risposta è no, con due ragioni diverse che portano
     * allo stesso posto.
     *
     * ── 1. Su Android **non esiste** ────────────────────────────────────
     *
     * 🚨 Health Connect non ha un record BMI. Il pacchetto `health` elenca
     * `BODY_MASS_INDEX` in `dataTypeKeysAndroid`, ma il plugin nativo
     * (`HealthConstants.kt`) non ha **nessuna riga** che lo mappi: sta in
     * quella lista perché su iOS esiste, e la lista non distingue le
     * piattaforme. ⚠️ Chiederlo non dà errore: dà **zero risultati, per
     * sempre**. Verificato sul telefono il 30/08 con `DiagnosticaSalute`.
     *
     * ── 2. Su iOS esiste, e la risposta è lo stesso no ──────────────────
     *
     * 🚨 **Il BMI non è una misura: è una divisione** — peso ÷ altezza². Di
     * quei due numeri il peso ce l'abbiamo (dalla bilancia) e l'altezza ce
     * l'ha data la persona, nel profilo.
     *
     * ⛔ Prendere la divisione di qualcun altro vuol dire prendere **la sua
     * altezza**: quella configurata sulla bilancia, o dentro Apple Health, che
     * nessuno ricontrolla mai. Risultato: due BMI diversi per la stessa
     * persona, e nessuno in grado di spiegare quale sia giusto.
     *
     * 💡 Uno solo, calcolato da noi, con l'altezza che quella persona ci ha
     * detto. `CalcolatoreCalorie.bmi(kg, cm)` esiste da sempre e basta.
     */
  ];

  /// I tipi del corpo — 3b-W.
  ///
  /// ══ 🚨 UN GRUPPO A PARTE, E NON DENTRO [_tipiDaLeggere] ═════════════════
  ///
  /// ⛔ **Metterceli dentro spegneva tutta la sincronizzazione**, e senza
  /// nessun errore. `aggiornaInSilenzio()` comincia con
  /// `if (!await permessiGiaConcessi()) return;`, e quel controllo chiedeva
  /// **tutti** i tipi in blocco: chi aveva già concesso i vecchi si ritrovava
  /// `false` per via dei tre nuovi, e l'app smetteva di aggiornare **anche
  /// sonno, HRV e allenamenti** finché non fosse tornato a mano sulla
  /// schermata.
  ///
  /// ⚠️ Trovato il 30/08 guardando `dumpsys` dopo l'installazione: i tre
  /// permessi risultavano **dichiarati e non concessi**, che è esattamente lo
  /// stato in cui il difetto scatta.
  ///
  /// 💡 È la stessa regola di tutta 3b-W, applicata ai permessi invece che ai
  /// valori: **una decisione per gruppo**. Se manca il permesso del corpo,
  /// manca solo il corpo.
  ///
  /// ⛔ Il BMI non c'è, e il perché è scritto sopra.
  static const tipiDelCorpo = <HealthDataType>[
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.LEAN_BODY_MASS,
  ];

  static final _permessiDelCorpo = List<HealthDataAccess>.filled(
    tipiDelCorpo.length,
    HealthDataAccess.READ,
  );

  /// I permessi del corpo ci sono già?
  ///
  /// 💡 Separato da [permessiGiaConcessi] apposta: chi ha collegato l'orologio
  /// mesi fa e non ha mai avuto una bilancia deve continuare a sincronizzare
  /// tutto il resto.
  Future<bool> permessiDelCorpoConcessi() async {
    try {
      await _salute.configure();

      return await _salute.hasPermissions(
            tipiDelCorpo,
            permissions: _permessiDelCorpo,
          ) ??
          false;
    } on Object {
      return false;
    }
  }

  /// I tre tipi che **chiediamo senza leggerli**, perche' li pretende il
  /// pacchetto per consegnare un allenamento completo.
  ///
  /// ── 🚨 Perche' esistono ───────────────────────────────────────────────────
  ///
  /// `handleWorkoutData` non si limita a `ExerciseSessionRecord`: per ogni
  /// sessione legge anche `DistanceRecord`, `StepsRecord` e
  /// `TotalCaloriesBurnedRecord` dentro l'intervallo dell'allenamento. Se **uno
  /// solo** dei permessi manca, cattura l'eccezione e restituisce lista
  /// **vuota**.
  ///
  /// ⚠️ Il sintomo e' «zero allenamenti», che somiglia a «l'orologio non ne
  /// manda» ed e' invece un permesso negato. E' precisamente l'errore del
  /// 19/08: `SecurityException: Caller requires READ_DISTANCE`.
  ///
  /// 💡 Dichiararli nel manifest **non basta**: `preparePermissionsListInternal`
  /// costruisce l'elenco da chiedere **dai tipi**, uno a uno, e `WORKOUT`
  /// traduce nel solo `READ_EXERCISE`. Senza queste tre righe restano
  /// `granted=false` per sempre, senza che a nessuno venga chiesto niente.
  ///
  /// ══ 🚨 REGOLA NON NEGOZIABILE ════════════════════════════════════════════
  ///
  /// **`TOTAL_CALORIES_BURNED` non entra in `_tipiDaLeggere`. Mai.**
  ///
  /// Quel record contiene il metabolismo basale. Qui serve solo perche' il
  /// pacchetto lo legge **da solo**, dentro l'intervallo di una sessione, per
  /// riempirne le calorie. Il totale della **giornata** resta
  /// `ACTIVE_ENERGY_BURNED`.
  ///
  /// 💡 Ed e' per questo che le due liste sono separate invece di essere una
  /// sola: cosi' la regola non e' un commento che qualcuno puo' non leggere, e'
  /// il fatto che il tipo **non c'e'** nella lista che legge. Per sbagliare
  /// bisogna spostarlo a mano, e a quel punto si passa di qui.
  static const _tipiInPiuPerGliAllenamenti = <HealthDataType>[
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.STEPS,
    HealthDataType.TOTAL_CALORIES_BURNED,

    /*
     * 🗺️ **Il percorso** — 08/09/2026.
     *
     * ⚠️ **Sta qui e non in `_tipiDaLeggere`**, e non è la solita difesa: i
     * percorsi non passano dal ciclo dei record grezzi — quello costruisce
     * `LetturaSalute`, e un tracciato non è un numero. Li legge
     * [_percorsiDegliAllenamenti], a parte.
     *
     * 🚨 **Chiederlo qui serve lo stesso**, perché `requestAuthorization`
     * costruisce l'elenco dai tipi: senza, non comparirebbe mai nel foglio del
     * consenso. ⛔ E non basta: il permesso «tutti i percorsi»
     * (`READ_EXERCISE_ROUTES`) Google **non lo concede su richiesta** — *«attempts
     * to request the permission by applications will be ignored»*. Lo dà la
     * persona a mano.
     */
    HealthDataType.WORKOUT_ROUTE,
  ];

  /// Quello che compare nella schermata del consenso.
  ///
  /// ⚠️ Ogni voce in piu' e' un motivo per dire di no, e queste tre sono il
  /// prezzo degli allenamenti. Si pagano una volta sola, all'inizio.
  static const _tipiDaAutorizzare = <HealthDataType>[
    ..._tipiDaLeggere,
    ..._tipiInPiuPerGliAllenamenti,

    /*
     * ⚖️ 3b-W — il corpo si **chiede** insieme al resto, ma si **controlla** a
     * parte (vedi [permessiDelCorpoConcessi]).
     *
     * 💡 Chiederlo insieme costa tre voci in più nel foglio del consenso, una
     * volta sola. ⛔ Chiederlo dopo, in un secondo momento, vorrebbe dire un
     * secondo foglio di sistema che compare a sorpresa mesi dopo — e a quel
     * punto la gente dice di no.
     */
    ...tipiDelCorpo,
  ];

  /// Le due liste, aperte al test.
  ///
  /// 💡 Non e' una comodita': la regola qui sopra vive in una **differenza fra
  /// due elenchi**, e una differenza si controlla solo se la si puo' guardare.
  /// Senza questi due getter la regola resterebbe un commento, cioe' niente.
  @visibleForTesting
  static List<HealthDataType> get tipiDaLeggere => _tipiDaLeggere;

  @visibleForTesting
  static List<HealthDataType> get tipiDaAutorizzare => _tipiDaAutorizzare;

  /// 🚨 **Solo lettura.** Non scriviamo niente in Health Connect: l'app non ha
  /// nessun motivo per farlo, e chiedere il permesso di scrittura raddoppierebbe
  /// la superficie del consenso in cambio di niente.
  static final _permessi = List<HealthDataAccess>.filled(
    _tipiDaAutorizzare.length,
    HealthDataAccess.READ,
  );

  /// Chiede i permessi. `false` se la persona ha detto di no, o se il telefono
  /// non ha Health Connect.
  ///
  /// ⚠️ **Non si chiama all'avvio.** Chiedere un permesso prima che l'utente
  /// abbia capito a cosa serve è il modo più rapido per farselo negare **per
  /// sempre**: su Android un rifiuto ripetuto rende il dialogo non più
  /// riproponibile. Si chiama dalla schermata che lo spiega (S3.4).
  /// Il permesso c'è **già**? — A5.
  ///
  /// 🚨 **Non apre nessun dialogo, ed è tutto il punto.** Serve alla
  /// risincronizzazione silenziosa all'avvio, che deve poter chiedersi «posso
  /// leggere?» senza disturbare nessuno. Usare `chiediPermessi()` lì
  /// aprirebbe la finestra di sistema a ogni apertura dell'app — e su Android
  /// un rifiuto ripetuto la rende **non più riproponibile**, cioè si
  /// brucerebbe la funzione a forza di offrirla.
  Future<bool> permessiGiaConcessi() async {
    try {
      await _salute.configure();

      return await _salute.hasPermissions(
            _tipiDaAutorizzare,
            permissions: _permessi,
          ) ??
          false;
    } on Object {
      // Un telefono senza Health Connect: non è un errore, è una funzione che
      // quel telefono non ha.
      return false;
    }
  }

  Future<bool> chiediPermessi() async {
    try {
      // ⚠️ `_salute.configure()`, non `Health().configure()`: quella creava
      // un'istanza NUOVA e configurava quella, lasciando non configurata
      // l'unica che poi legge davvero. Con il doppio iniettato dai test era
      // anche peggio — si toccava il pacchetto vero.
      await _salute.configure();

      final gia = await _salute.hasPermissions(
        _tipiDaAutorizzare,
        permissions: _permessi,
      );

      /*
       * ⛰️ **Il dislivello si chiede SEMPRE, anche a chi ha già concesso** —
       * 08/09/2026.
       *
       * ⛔ **Stava dopo il `return` qui sotto, ed era inutile per quasi tutti**:
       * chi aveva già i permessi usciva prima, e il dislivello non lo avrebbe
       * ricevuto mai — cioè proprio chi usa l'app da settimane.
       *
       * 💡 Chiamarla è innocuo: il lato nativo controlla prima se il permesso
       * c'è già, e in quel caso risponde e basta senza aprire niente.
       */
      await const SaluteInPiu().chiediIlDislivello();

      if (gia ?? false) return true;

      return await _salute.requestAuthorization(
        _tipiDaAutorizzare,
        permissions: _permessi,
      );


    } on Object catch (errore, stack) {
      // Un telefono senza Health Connect non è un errore da mostrare: è una
      // funzione che quel telefono non ha.
      debugPrintStack(
        label: 'PonteSalute.chiediPermessi: $errore',
        stackTrace: stack,
      );
      return false;
    }
  }

  /// Legge dal telefono e scrive nell'archivio. Torna quanti campioni sono
  /// entrati davvero (i duplicati e gli implausibili non contano).
  ///
  /// ⚠️ **Rilegge sempre una finestra intera, non solo il nuovo.** È il motivo
  /// per cui l'archivio ha gli indici univoci: un sensore può consegnare in
  /// ritardo un campione di ieri, e chiedere «solo da adesso in poi»
  /// significherebbe perderlo per sempre.
  ///
  /// 🚨 **`giorniIndietro` di serie è 7, ma Health Connect ne concede ~30** e
  /// oltre serve un permesso a parte che Google dà con parsimonia. Quindi:
  /// la prima sincronizzazione prende quel che può, e **da lì in poi la memoria
  /// lunga è l'archivio locale**, che accumula. La media di riferimento a sette
  /// giorni esiste solo dopo sette giorni di app installata — non è un difetto,
  /// ma va detto a chi la usa o sembrerà che la funzione non parta.
  /// I passi **al giorno** degli ultimi [giorni] — 3b-G.1.4, 26/08/2026.
  ///
  /// ══ 💡 A COSA SERVE ═══════════════════════════════════════════════════
  ///
  /// «Quanto ti muovi?» è la domanda peggiore della registrazione: nessuno sa
  /// rispondere, e chi prova indovina. 🚨 Ma il numero che risponde davvero
  /// **ce l'abbiamo già**, e allora non si chiede: si misura e si fa
  /// confermare.
  ///
  /// ══ ⛔ PERCHE' L'AGGREGATO E NON LA SOMMA DEI RECORD ══════════════════
  ///
  /// 🚨 **Le sorgenti possono essere due**, e scrivere gli stessi passi. Sul
  /// telefono del committente, ad agosto 2026, scrivono sia il POCO X7 Pro sia
  /// lo Zepp: sommare i record grezzi **raddoppierebbe**, e il gradino
  /// suggerito salirebbe di due scalini senza che niente lo dica.
  ///
  /// 💡 `getTotalStepsInInterval` passa dall'aggregazione di Health Connect,
  /// che i doppioni li toglie per priorità di sorgente. È l'unico modo di
  /// avere un numero che voglia dire quello che sembra.
  ///
  /// ⚠️ `null` quando non c'è niente da leggere — nessun permesso, nessun
  /// dato, o un telefono senza Health Connect. ⛔ **Non zero**: zero passi
  /// sarebbe un'affermazione, e su un suggerimento di dieta un'affermazione
  /// inventata è la cosa che non deve succedere.
  /// Una lettura di passi per ciascuno degli ultimi [giorni].
  ///
  /// ⚠️ **`fonte: 'aggregato'` e non il nome dell'app.** Il totale non viene da
  /// una sorgente sola: e' Health Connect che ha scelto fra le sue. 🚨 Scriverci
  /// «huami» o «phone» direbbe una cosa falsa, e `ArchivioSalute.passiDi()` —
  /// che tiene la sorgente **piu' alta** — tornerebbe a poter sommare due
  /// versioni dello stesso giorno.
  ///
  /// ══ 🚨 PERCHE' RISCRIVE INVECE DI INSERIRE — 08/09/2026 ═══════════
  ///
  /// ⛔ **Fino al 08/09 questo metodo tornava delle `LetturaSalute` che
  /// finivano in `scriviLetture`, cioe' in una INSERT.** L'indice unico
  /// `(fonte, metrica, misurataIl)` faceva fallire l'inserimento di un giorno
  /// gia' presente — in silenzio, com'e' giusto per un indice — e il risultato
  /// era che **ogni giorno restava congelato al primo valore mai scritto**.
  ///
  /// 🚨 **Misurato sul telefono del committente il 08/09**: l'archivio dava
  /// 1.195 passi per il 07/09, l'aggregato di Health Connect ne dava **4.500**.
  /// Il 07/09 era stato letto per la prima volta alle 00:38 di quel giorno,
  /// quando di passi ce n'erano 1.195 — e li' e' rimasto. Due
  /// risincronizzazioni complete e un riavvio dell'app non l'hanno spostato.
  ///
  /// ⚠️ **E non era il difetto che il commento vecchio descriveva.** Quello
  /// diceva «il totale di stamattina resta quello di stamattina» e rimandava a
  /// un metodo `aggiornaIPassiDiOggi` che nessuno chiamava: raccontava un
  /// ritardo di qualche ora, mentre il dato era **definitivo**. Un giorno
  /// letto mentre e' a meta' resta a meta' per sempre, e quel numero e'
  /// perfettamente plausibile — nessuno lo va a controllare l'indomani.
  ///
  /// 💡 Adesso ogni giorno della finestra passa da
  /// `ArchivioSalute.riscriviIPassi()`, che **cancella e riscrive**. Costa una
  /// DELETE per giorno a sincronizzazione, ed e' il prezzo per avere un numero
  /// che vuol dire quello che sembra.
  ///
  /// Torna **quanti giorni** ha scritto.
  Future<int> _riscriviIPassiAggregati(int giorni) async {
    final oggi = DateTime.now();
    var scritti = 0;

    for (var i = 0; i <= giorni; i++) {
      final g = DateTime(
        oggi.year,
        oggi.month,
        oggi.day,
      ).subtract(Duration(days: i));

      final totale = await passiDelGiorno(g);

      /*
       * ⛔ **`null` non cancella niente.** Un giorno che Health Connect non sa
       * piu' raccontare — permesso revocato, sorgente disinstallata — deve
       * lasciare in piedi quello che avevamo: sostituire un dato vero con
       * l'assenza e' peggio che tenerlo vecchio.
       */
      if (totale == null) continue;

      await _archivio.riscriviIPassi(giorno: g, passi: totale);
      scritti++;
    }

    return scritti;
  }

  /// I passi di **un giorno**, dall'aggregato — 07/09/2026.
  ///
  /// 🚨 **Un numero al giorno, non un campione ogni cinque minuti.** Health
  /// Connect tiene record sovrapposti — minuto per minuto **e** aggregati per
  /// finestra — e da due sorgenti diverse. Sommare i grezzi conta lo stesso
  /// passo piu' volte: il 05/09/2026 dava **23.471** passi.
  ///
  /// 💡 `getTotalStepsInInterval` fa la deduplicazione dentro Health Connect,
  /// per priorita' di sorgente. E' l'unico modo di avere un numero che voglia
  /// dire quello che sembra.
  ///
  /// ⚠️ `null` quando non c'e' niente: nessun permesso, nessun dato, o un
  /// telefono senza Health Connect. ⛔ **Non zero** — zero passi sarebbe
  /// un'affermazione.
  Future<int?> passiDelGiorno(DateTime giorno) async {
    try {
      await _salute.configure();

      final da = DateTime(giorno.year, giorno.month, giorno.day);
      final a = da.add(const Duration(days: 1));

      /*
       * ⚠️ **Mai oltre adesso.** Chiedere fino a mezzanotte di stanotte per il
       * giorno in corso funziona, ma su alcune versioni l'aggregato con una fine
       * nel futuro torna `null` invece del parziale — e il sintomo sarebbe
       * «oggi zero passi, ieri ottomila».
       */
      final adesso = DateTime.now();
      final fine = a.isAfter(adesso) ? adesso : a;

      if (!fine.isAfter(da)) return null;

      final totale = await _salute.getTotalStepsInInterval(da, fine);

      return totale == null || totale <= 0 ? null : totale;
    } on Object catch (errore) {
      debugPrint('passi del giorno: non leggibili — $errore');

      return null;
    }
  }

  Future<int?> passiAlGiorno({int giorni = 30}) async {
    if (giorni <= 0) return null;

    try {
      await _salute.configure();

      final a = DateTime.now();
      final da = a.subtract(Duration(days: giorni));
      final totale = await _salute.getTotalStepsInInterval(da, a);

      if (totale == null || totale <= 0) return null;

      return (totale / giorni).round();
    } on Object catch (errore) {
      // ⚠️ Detto e non ingoiato: un `catch` muto qui vorrebbe dire un
      // suggerimento che non compare mai, senza niente da cui partire. È la
      // lezione del suono del recupero (3b-E.8).
      debugPrint('passi: non leggibili — $errore');

      return null;
    }
  }

  /// ⚖️ Il corpo: peso, massa grassa e massa magra — 3b-W.1.
  ///
  /// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
  ///
  /// *«prendere tutti i dati su peso, massa grassa e bmi direttamente dalla
  /// bilancia […] e se non ci sono li stimiamo come facciamo ora»*, e poi:
  /// *«bisogna prendere solo i dati che vengono davvero passati»*.
  ///
  /// ══ 🚨 UNA DECISIONE PER VALORE, NON UN `if` SOLO ════════════════════════
  ///
  /// I tre valori sono **tre record separati**, e una bilancia può mandarne uno
  /// solo: quella del committente manda peso e massa grassa, la massa magra no.
  ///
  /// ⛔ Il modo sbagliato, che sembra il più ordinato: *«se la bilancia c'è
  /// prendo tutto da lei, altrimenti stimo tutto»*. 🚨 A chi ha una bilancia che
  /// manda **solo il peso** darebbe una massa grassa mancante anche quando la
  /// conosciamo da un'altra parte — o, peggio, uno zero.
  ///
  /// 💡 Qui ogni tipo si legge e si scrive per conto suo, e i giorni in cui
  /// arriva possono essere diversi.
  ///
  /// ══ ⚠️ PERCHE' NON DENTRO [sincronizza] ══════════════════════════════════
  ///
  /// Perché ha una **finestra diversa**: il sonno vale sette giorni, il peso di
  /// due anni fa è la cosa che si guarda indietro. ⛔ Allargare la finestra di
  /// `sincronizza` a due anni vorrebbe dire rileggere ogni volta 56.000 record
  /// di battito — sei secondi misurati il 30/08 — per un dato che cambia una
  /// volta al giorno.
  ///
  /// @return quanti giorni sono stati scritti
  Future<int> sincronizzaIlCorpo({int? giorniIndietro}) async {
    final a = DateTime.now();

    /*
     * ── ⏳ La prima volta prende TUTTO, poi solo il nuovo ──────────────────
     *
     * 💡 Chi arriva da un'altra app ha anni di pesate, ed è esattamente quello
     * che gli serve rivedere. ⚠️ Ma rileggerli **a ogni avvio** costa: si parte
     * dall'ultimo giorno già importato.
     *
     * 🚨 **Con una settimana di sovrapposizione**, e non dal giorno esatto: una
     * bilancia può scrivere in ritardo — l'app della bilancia sincronizza
     * quando le pare — e ripartire dall'ultimo giorno noto salterebbe le
     * pesate arrivate dopo. ⛔ Un buco nel grafico che nessuno saprebbe
     * spiegare.
     */
    final ultimo = await _archivio.ultimoGiornoImportato();

    final da = giorniIndietro != null
        ? a.subtract(Duration(days: giorniIndietro))
        : ultimo == null
        ? a.subtract(const Duration(days: 365 * 5))
        : ultimo.subtract(const Duration(days: 7));

    /*
     * ⛔ **Senza il permesso non si prova nemmeno.** `getHealthDataFromTypes`
     * su un tipo non concesso non lancia: torna vuoto. 🚨 Il che vuol dire che
     * senza questo controllo la differenza fra «non ho il permesso» e «la
     * bilancia non ha scritto niente» sparisce — e la prima è risolvibile,
     * la seconda no.
     */
    if (!await permessiDelCorpoConcessi()) return 0;

    final List<HealthDataPoint> punti;

    try {
      await _salute.configure();

      punti = await _salute.getHealthDataFromTypes(
        types: tipiDelCorpo,
        startTime: da,
        endTime: a,
      );
    } on Object catch (errore) {
      /*
       * ⚠️ **Detto e non ingoiato**, ma senza rilanciare: chi non ha una
       * bilancia collegata passa di qui a ogni avvio, e un'eccezione che sale
       * spegnerebbe l'app per una funzione che quella persona non sa di avere.
       */
      debugPrint('PonteSalute.sincronizzaIlCorpo: $errore');

      return 0;
    }

    if (punti.isEmpty) return 0;

    /*
     * ── 🚨 Una misura al giorno, e si prende LA PIU' RECENTE ───────────────
     *
     * ⛔ La regola scritta all'inizio era «la prima del giorno, che è quella a
     * stomaco vuoto». **I dati veri l'hanno smentita**: le pesate del
     * committente sono alle 23:40, alle 17:48, alle 18:08 e alle 12:45.
     * Nessuna al mattino. 🚨 Presupponeva un'abitudine che quella persona non
     * ha.
     *
     * 💡 «La più recente» è semplice e prevedibile, e non finge di sapere quale
     * pesata sia quella buona. ⚠️ Il rumore lo toglie il livellamento, non la
     * scelta dell'orario: 96,15 kg alle 17:48 e 95,85 alle 18:08 — trecento
     * grammi in venti minuti, che non sono grasso.
     */
    final perGiorno = <DateTime, _CorpoDelGiorno>{};

    for (final punto in punti) {
      final valore = _numero(punto.value);

      if (valore == null) continue;

      final giorno = DateTime(
        punto.dateFrom.year,
        punto.dateFrom.month,
        punto.dateFrom.day,
      );

      final riga = perGiorno.putIfAbsent(giorno, _CorpoDelGiorno.new);

      switch (punto.type) {
        case HealthDataType.WEIGHT:
          riga.peso.considera(punto.dateFrom, valore);
        case HealthDataType.BODY_FAT_PERCENTAGE:
          /*
           * 🚨 **Uno zero non è «zero grasso»: è una misura fallita.** Una
           * bilancia che non riesce a leggere l'impedenza — piedi asciutti,
           * calzini — scrive `0`, non `null`. ⛔ Prenderlo per buono darebbe
           * una massa magra pari al peso intero, e un BMR alto, plausibile e
           * sbagliato.
           */
          if (valore > 0) riga.grasso.considera(punto.dateFrom, valore);
        case HealthDataType.LEAN_BODY_MASS:
          if (valore > 0) riga.magra.considera(punto.dateFrom, valore);
        default:
          break;
      }
    }

    var scritti = 0;

    for (final voce in perGiorno.entries) {
      final fatto = await _archivio.registraDaSalute(
        giorno: voce.key,
        pesoKg: voce.value.peso.valore,
        massaGrassaPct: voce.value.grasso.valore,
        massaMagraKg: voce.value.magra.valore,
      );

      if (fatto) scritti++;
    }

    return scritti;
  }

  Future<int> sincronizza({int giorniIndietro = 7}) async {
    final a = DateTime.now();
    final da = a.subtract(Duration(days: giorniIndietro));

    final List<HealthDataPoint> punti;

    try {
      punti = await _salute.getHealthDataFromTypes(
        types: _tipiDaLeggere,
        startTime: da,
        endTime: a,
      );
    } on Object catch (errore, stack) {
      debugPrintStack(
        label: 'PonteSalute.sincronizza: $errore',
        stackTrace: stack,
      );
      return 0;
    }

    final letture = <LetturaSalute>[];
    final campioni = <CampioneSonno>[];

    final allenamenti = _allenamentiDa(punti);

    for (final punto in punti) {
      final metrica = _metricaDi(punto.type);

      if (metrica != null) {
        final valore = _numero(punto.value);
        if (valore == null) continue;

        letture.add(
          LetturaSalute(
            id: 0,
            fonte: _fonte(punto),
            metrica: metrica.codice,
            misurataIl: punto.dateFrom,
            giorno: DateTime(
              punto.dateFrom.year,
              punto.dateFrom.month,
              punto.dateFrom.day,
            ),
            valore: valore,
          ),
        );

        continue;
      }

      final fase = _faseDi(punto.type);

      if (fase != null) {
        /*
         * \U0001F6A8 La giornata si mette **dopo**, non qui.
         *
         * Quello che arriva sono **segmenti di fase** — venti minuti di REM,
         * quaranta di profondo — e da un segmento solo non si puo' sapere se
         * fa parte di una notte o di un pisolino. ⚠️ La regola precedente ci
         * provava guardando l'ora d'inizio, e una pennichella cominciata alle
         * 18:09 finiva accreditata all'indomani.
         *
         * \U0001F4A1 Si mette un segnaposto e si decide sotto, quando ci sono tutti.
         */
        campioni.add(
          CampioneSonno(
            id: 0,
            fonte: _fonte(punto),
            notte: punto.dateFrom,
            iniziatoIl: punto.dateFrom,
            finitoIl: punto.dateTo,
            fase: fase.codice,
          ),
        );
      }
    }

    /*
     * ══ 🚶 I PASSI, UN GIORNO ALLA VOLTA — 07/09/2026 ═════════════════════
     *
     * 🚨 **Non passano dal ciclo qui sopra**, e non e' una svista: quello
     * raccoglie i record grezzi, e i passi grezzi si sovrappongono fra loro e
     * fra le sorgenti. Sommandoli, il 05/09 ne uscivano **23.471**.
     *
     * 💡 Qui si chiede a Health Connect il **totale aggregato** di ogni giorno,
     * che la deduplicazione la fa lei. Una riga al giorno, non trecento.
     *
     * ⚠️ **E non entrano in `letture`**: quelle si inseriscono, e un giorno
     * gia' presente non si aggiornerebbe mai piu'. Vedi
     * [_riscriviIPassiAggregati].
     */
    final conLaGiornataGiusta = _assegnaLeGiornate(campioni);

    final a1 = await _archivio.scriviLetture(letture);
    final a2 = await _archivio.scriviCampioniSonno(conLaGiornataGiusta);
    final a3 = await _archivio.scriviAllenamenti(allenamenti);
    final a4 = await _riscriviIPassiAggregati(giorniIndietro);

    /*
     * 🗺️ **I percorsi, DOPO gli allenamenti** — 08/09/2026.
     *
     * 🚨 L'ordine non è estetico: un percorso si aggancia alla riga
     * dell'allenamento tramite `idSalute`, e quella riga deve esistere. ⛔
     * Leggerli prima vorrebbe dire buttarli tutti, senza nemmeno un errore.
     */
    final a5 = await _percorsiDegliAllenamenti(da, a);

    return a1 + a2 + a3 + a4 + a5;
  }

  /// I tracciati delle uscite all'aperto, salvati **senza chiedere niente**.
  ///
  /// ══ 📌 PERCHE' QUI E NON DIETRO UN PULSANTE ═══════════════════════════════
  ///
  /// Il committente, l'08/09: *«se non c'è una foto deve mostrarmi il percorso
  /// nella card dell'allenamento al posto della foto, **non glielo devo chiedere
  /// ogni volta, sarebbe ridicolo**»*.
  ///
  /// ✅ **E con il permesso «tutti i percorsi» arrivano davvero**: misurato lo
  /// stesso giorno sulla camminata delle 10:49 — **1.604 punti, tutti con la
  /// quota**. Nessuna finestra, nessun gesto.
  ///
  /// ══ 🚨 IL PERMESSO NON SI PUO' CHIEDERE, E VA SAPUTO ══════════════════════
  ///
  /// ⛔ `READ_EXERCISE_ROUTES` Google **non lo concede su richiesta**: *«attempts
  /// to request the permission by applications will be ignored»*. Lo dà la
  /// persona a mano in Health Connect.
  ///
  /// ⚠️ **E su questo telefono quella voce non compare** — verificato con un
  /// dump della schermata. 💡 Per questo resta la strada per singola uscita
  /// (`SaluteInPiu.percorso`): è il ripiego, non la regola.
  ///
  /// ══ ⚠️ E SOLO IN PRIMO PIANO ══════════════════════════════════════════════
  ///
  /// Google: *«when your app runs in the background … Health Connect returns
  /// `ConsentRequired`, **even if** your app has Always allow»*. 🚨 Quindi una
  /// sincronizzazione in sottofondo qui non porta niente — e non è un guasto:
  /// semplicemente i percorsi arrivano alla prima apertura dell'app.
  Future<int> _percorsiDegliAllenamenti(DateTime da, DateTime a) async {
    try {
      final punti = await _salute.getHealthDataFromTypes(
        types: const [HealthDataType.WORKOUT_ROUTE],
        startTime: da,
        endTime: a,
      );

      var salvati = 0;

      for (final p in punti) {
        final valore = p.value;

        if (valore is! WorkoutRouteHealthValue) continue;

        /*
         * ⛔ **Le liste vuote si saltano in silenzio.** Sono i
         * `ConsentRequired`: Health Connect risponde così per ogni sessione
         * quando il permesso manca, comprese quelle che un percorso non ce
         * l'hanno mai avuto. 🚨 Scriverle vorrebbe dire segnare come «rifiutato»
         * qualcosa che la persona non ha mai visto.
         */
        if (valore.locations.isEmpty) continue;

        final salvato = await _archivio.scriviIlPercorsoDiSalute(
          idSalute: p.uuid,
          punti: [
            for (final l in valore.locations)
              PuntoDelPercorso(
                latitudine: l.latitude,
                longitudine: l.longitude,
                quotaMetri: l.altitude,
                istante: l.timestamp,
              ),
          ],
        );

        if (salvato) salvati++;
      }

      return salvati;
    } on Object catch (errore) {
      /*
       * ⚠️ **Un percorso mancante non deve far fallire la sincronizzazione.**
       * Senza il permesso questa chiamata può lanciare, e sonno, battito e passi
       * non c'entrano niente.
       */
      debugPrint('percorsi: non leggibili — $errore');

      return 0;
    }
  }

  /// Gli allenamenti, ripuliti — FASE 1.8.
  ///
  /// ── 🚨 Cosa si scarta, e perché ───────────────────────────────────────────
  ///
  /// | Scartato | Perché |
  /// |---|---|
  /// | Valore che non è un `WorkoutHealthValue` | non è un allenamento |
  /// | Tipo in `_nonSonoAllenamenti` | è un esito di **elettrocardiogramma** |
  /// | Durata nulla o negativa | un allenamento di zero minuti non è successo |
  ///
  /// 💡 Il terzo caso sembra teorico e non lo è: un'app che scrive male, o una
  /// sessione interrotta sul nascere, producono record con inizio e fine
  /// identici. ⚠️ Nello storico diventerebbero righe «0 min · 0 kcal» che
  /// nessuno sa da dove vengano e che non si possono cancellare.
  @visibleForTesting
  static List<AllenamentoDaOrologio> allenamentiDa(
    List<HealthDataPoint> punti,
  ) => _allenamentiDa(punti);

  static List<AllenamentoDaOrologio> _allenamentiDa(
    List<HealthDataPoint> punti,
  ) {
    final fuori = <AllenamentoDaOrologio>[];

    for (final punto in punti) {
      if (punto.type != HealthDataType.WORKOUT) continue;

      final valore = punto.value;
      if (valore is! WorkoutHealthValue) continue;

      final codice = valore.workoutActivityType.name;
      if (!TipoAllenamento.eUnAllenamento(codice)) continue;

      if (!punto.dateTo.isAfter(punto.dateFrom)) continue;

      fuori.add(
        AllenamentoDaOrologio(
          /*
         * ⚠️ L'`id` a zero e' costretto dalla classe generata, e va bene
         * **solo** perche' `_companionAllenamento` non lo passa: vedi la nota
         * lunga in `ArchivioSalute`, dove lo stesso zero aveva prodotto un
         * archivio con una riga sola per sincronizzazione.
         */
          id: 0,
          fonte: _fonte(punto),
          tipo: codice,
          iniziatoIl: punto.dateFrom,
          finitoIl: punto.dateTo,

          /*
         * ══ 🚨 NON `valore.totalEnergyBurned` ═══════════════════════════════
         *
         * Quello viene da `TotalCaloriesBurnedRecord` e comprende il
         * **metabolismo basale**. Il 20/08 il committente l'ha visto subito:
         * l'app dell'orologio diceva **680 kcal** per quella seduta, e noi ne
         * mostravamo **835**.
         *
         * ⚠️ È lo **stesso errore** che la regola sul totale giornaliero vieta,
         * solo in scala più piccola — e infatti mi era sfuggito proprio perché
         * la regola parlava della giornata.
         *
         * 💡 E le calorie giuste ce le **abbiamo già**: sono
         * `ACTIVE_ENERGY_BURNED`, lo stesso record che alimenta il totale del
         * giorno. Prenderle da lì non è solo più corretto: è l'unico modo
         * perché due schermate dell'app non dicano numeri diversi sulla stessa
         * ora.
         */
          kcal: _attiveDentro(punti, punto.dateFrom, punto.dateTo),
          distanzaMetri: valore.totalDistance,
          passi: valore.totalSteps,
          nascosto: false,

          /*
         * ⚠️ Sempre `false` da qui: `staccato` e' una **scelta di chi usa
         * l'app**, non un dato dell'orologio. Non viene nemmeno passato a
         * `_companionAllenamento`, quindi una rilettura non puo' cancellarlo.
         */
          staccato: false,
          contaComeExtra: false,

          /*
           * 🗺️ **L'identificativo di Health Connect** — 08/09/2026.
           *
           * 🚨 Senza, il percorso non si puo' nemmeno CHIEDERE: la finestra di
           * consenso vuole l'id della sessione e non accetta nient'altro — non
           * l'ora, non la durata, non la sorgente.
           */
          idSalute: punto.uuid,
        ),
      );
    }

    return fuori;
  }

  /// Le calorie **attive** bruciate fra `da` e `a`, dai campioni letti.
  ///
  /// ── ⚠️ Si contano in proporzione, non tutte o niente ──────────────────────
  ///
  /// Un campione di calorie attive copre un intervallo, e quell'intervallo può
  /// cominciare prima dell'allenamento o finire dopo. Contarlo intero
  /// gonfierebbe una corsa di venti minuti con l'ora di camminata che la
  /// precede; scartarlo perché «non ci sta dentro» butterebbe via il grosso.
  ///
  /// 💡 Nel caso vero misurato il 20/08 la proporzione non serve — Zepp scrive
  /// **un** campione che coincide con la sessione — ma non tutte le app fanno
  /// così, e la regola giusta costa tre righe.
  ///
  /// 🚨 Torna `null`, non `0`, quando non c'è niente da sommare: «non lo so» e
  /// «non hai bruciato niente» sono due cose diverse, e mostrare uno zero
  /// inventato è peggio che non mostrare niente. ⚠️ E in nessun caso si ripiega
  /// su `totalEnergyBurned`: sarebbe rimettere dentro il basale di nascosto.
  static int? _attiveDentro(
    List<HealthDataPoint> punti,
    DateTime da,
    DateTime a,
  ) {
    var somma = 0.0;
    var trovato = false;

    for (final punto in punti) {
      if (punto.type != HealthDataType.ACTIVE_ENERGY_BURNED) continue;

      final valore = punto.value;
      if (valore is! NumericHealthValue) continue;

      final inizio = punto.dateFrom.isAfter(da) ? punto.dateFrom : da;
      final fine = punto.dateTo.isBefore(a) ? punto.dateTo : a;

      if (fine.isBefore(inizio)) continue;

      final kcal = valore.numericValue.toDouble();
      final durata = punto.dateTo.difference(punto.dateFrom).inSeconds;

      /*
       * 💡 Un campione istantaneo (`dateFrom == dateTo`) non si può ripartire:
       * o sta dentro o no. La riga sopra ha già scartato quelli fuori.
       */
      if (durata <= 0) {
        somma += kcal;
        trovato = true;

        continue;
      }

      somma += kcal * (fine.difference(inizio).inSeconds / durata);
      trovato = true;
    }

    return trovato ? somma.round() : null;
  }

  /// Ricompone i segmenti in dormite e da' a ognuno la giornata della sua.
  ///
  /// \U0001F6A8 È il passaggio che la versione precedente non aveva: decideva
  /// segmento per segmento, e un segmento da solo non sa dove appartiene.
  static List<CampioneSonno> _assegnaLeGiornate(List<CampioneSonno> campioni) {
    if (campioni.isEmpty) return campioni;

    final giornate = SessioniDiSonno.giornatePerSegmento(
      campioni.map((c) => (inizio: c.iniziatoIl, fine: c.finitoIl)),
    );

    return [
      for (final c in campioni)
        CampioneSonno(
          id: c.id,
          fonte: c.fonte,
          notte: giornate[c.iniziatoIl] ?? c.iniziatoIl,
          iniziatoIl: c.iniziatoIl,
          finitoIl: c.finitoIl,
          fase: c.fase,
        ),
    ];
  }

  static String _fonte(HealthDataPoint punto) {
    final nome = punto.sourceName.trim();

    return nome.isEmpty
        ? 'health'
        : nome.substring(0, nome.length.clamp(0, 32));
  }

  static double? _numero(HealthValue valore) =>
      valore is NumericHealthValue ? valore.numericValue.toDouble() : null;

  static MetricaSalute? _metricaDi(HealthDataType tipo) => switch (tipo) {
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD => MetricaSalute.hrv,
    HealthDataType.RESTING_HEART_RATE => MetricaSalute.battitoARiposo,
    HealthDataType.HEART_RATE => MetricaSalute.battitoMedio,
    HealthDataType.ACTIVE_ENERGY_BURNED => MetricaSalute.calorieAttive,
    HealthDataType.SPEED => MetricaSalute.velocita,
    /*
     * ⛔ **`STEPS` non passa piu' di qui** — 07/09/2026. I passi si scrivono un
     * giorno alla volta con l'aggregato, non campione per campione: vedi
     * [passiDelGiorno] e il commento in `_tipiDaLeggere`.
     */
    _ => null,
  };

  /// ⚠️ `SLEEP_ASLEEP` è la fase «dorme ma non sappiamo come»: la si conta come
  /// **leggero**, che è il comportamento del vecchio `SleepStage`. Non come
  /// profondo: sarebbe la lettura più generosa proprio dove serve prudenza.
  static FaseSonno? _faseDi(HealthDataType tipo) => switch (tipo) {
    HealthDataType.SLEEP_DEEP => FaseSonno.profondo,
    HealthDataType.SLEEP_REM => FaseSonno.rem,
    HealthDataType.SLEEP_LIGHT ||
    HealthDataType.SLEEP_ASLEEP => FaseSonno.leggero,
    HealthDataType.SLEEP_AWAKE => FaseSonno.sveglio,
    _ => null,
  };
}

/// Il valore **più recente** di un giorno, e l'ora a cui è arrivato — 3b-W.
///
/// 💡 Una classe di tre righe invece di un `Map<DateTime, (double, DateTime)>`:
/// il confronto sull'ora sta in un posto solo, e non si ripete tre volte con la
/// possibilità di sbagliarne una.
class _PiuRecente {
  DateTime? _quando;
  double? valore;

  void considera(DateTime quando, double v) {
    if (_quando != null && !quando.isAfter(_quando!)) return;

    _quando = quando;
    valore = v;
  }
}

/// I tre valori di una giornata, ciascuno con la sua ora.
///
/// ⚠️ **Tre `_PiuRecente` e non uno**: peso e massa grassa possono arrivare da
/// record diversi con orari diversi, e prendere «l'ultimo punto della giornata»
/// per tutti e tre vorrebbe dire far decidere a uno l'ora degli altri.
class _CorpoDelGiorno {
  final peso = _PiuRecente();
  final grasso = _PiuRecente();
  final magra = _PiuRecente();
}
