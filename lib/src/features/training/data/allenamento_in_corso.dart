/// La scheda **mentre la si esegue** — 3b-E.1, 25/08/2026.
///
/// ══ 📌 LA RICHIESTA, ED È PIÙ GROSSA DI COME SUONA ════════════════════════
///
/// *«La pagina dell'allenamento deve mostrare gli esercizi come quella
/// dell'editor delle schede»* · *«Tutte le serie devono essere rappresentate
/// anche qui come righe separate, con campi precompilati secondo quanto
/// registrato nella scheda»* · *«tutti i campi devono poter essere modificati
/// dall'utente, e ogni modifica deve aggiornare la scheda»* · *«ricordati che
/// TUTTE LE MODIFICHE fatte durante l'allenamento devono modificare la
/// scheda»*.
///
/// ══ 🚨 COSA CAMBIA DAVVERO: LA RIGA È UNA SOLA ════════════════════════════
///
/// ⛔ Fino a ieri il player teneva **due** modelli affiancati: `PlayerExercise`
/// con dentro `previste` (quello che dice la scheda) e `rows` (quello che si sta
/// facendo). Erano due liste con due numerazioni, tenute in fila a mano da
/// `_righeDa()`, e il loro disallineamento è la sorgente di metà dei difetti di
/// B.15 — comprese le due serie che si sono sovrascritte a vicenda.
///
/// 💡 Da qui in poi **la riga della scheda e la riga che si compila sono la
/// stessa riga**. Cambiare «12» in «10» durante l'allenamento cambia la scheda,
/// perché non c'è nessun altro posto in cui quel numero viva.
///
/// ══ ⚠️ E QUESTO HA UNA CONSEGUENZA CHE VA DETTA ═══════════════════════════
///
/// 🚨 Una giornata storta **abbassa la scheda**: se si scarica di 5 kg perché
/// si è dormito male, la scheda da domani dice 5 kg in meno, e nessuno lo
/// ricorda. ⛔ È esattamente quello che il committente ha chiesto, in
/// maiuscolo, e la ragione è buona — *«doverli correggere dopo, dall'editor
/// delle schede, vuol dire non correggerli mai»* — ma è una scelta, non un
/// effetto collaterale, e sta scritta qui perché fra sei mesi si sappia.
///
/// 💡 Quello che **non** cambia mai è lo **storico**: `logSet` scrive quello che
/// è stato fatto, e resta fatto anche se la scheda poi cambia. Prescrizione e
/// storia restano due cose diverse, come da B.15 — solo che adesso la
/// prescrizione la si corregge dove ci si accorge che è sbagliata.
library;

import 'scheda_in_scrittura.dart';
import 'serie_prevista.dart';
import 'session_models.dart';

/// Una riga di serie che, oltre a dire cosa fare, sa **se è stata fatta**.
class SerieInAllenamento extends SerieInScrittura {
  SerieInAllenamento({super.ripetizioni, super.carico, super.recupero});

  /// Da una serie già prescritta dalla scheda.
  ///
  /// 🚨 Nasce `toccataAMano`, per la stessa ragione di
  /// [SerieInScrittura.da]: le righe di una scheda che esiste le ha scritte
  /// **una persona**, e l'autocompilazione non deve riscriverle correggendo la
  /// prima.
  factory SerieInAllenamento.da(SeriePrevista s) => SerieInAllenamento(
    ripetizioni: s.ripetizioni?.toString(),
    carico: _numero(s.peso) ?? s.isoSec?.toString(),
    recupero: s.recuperoSec?.toString(),
  )..toccataAMano = true;

  static String? _numero(double? v) => v == null ? null : numeroPulito(v);

  /// Spuntata: questa serie è stata registrata nello storico.
  bool fatta = false;

  /// Con che numero è stata registrata — 3b-E.5.
  ///
  /// ══ 🚨 PERCHE' NON BASTA LA POSIZIONE NELLA LISTA ════════════════════════
  ///
  /// ⛔ Il numero della serie si ricavava dall'indice della riga, e finché le
  /// righe non si toglievano andava bene. 💡 Adesso una riga si può togliere
  /// **anche dopo averla spuntata**: la quarta scivola terza, e ri-spuntarla
  /// scriverebbe sopra la terza serie già in archivio — la scrittura è un
  /// upsert su (seduta, esercizio, numero), quindi non darebbe **nessun
  /// errore**, solo un peso sbagliato al posto di un altro.
  ///
  /// ⚠️ `null` finché non è mai stata registrata: allora vale la posizione.
  int? numeroRegistrato;
}

/// Un esercizio mentre lo si esegue: **è quello dell'editor**, con le spunte.
///
/// 💡 Estende [EsercizioInScrittura] invece di somigliargli, ed è il punto:
/// così `CardEsercizioScrittura`, `RigheDelleSerie`, l'autocompilazione, la
/// scelta del carico e il salvataggio in JSON sono **gli stessi**, non delle
/// copie. ⛔ Il committente su questo è stato esplicito: *«a che cazzo serve
/// fare delle modifiche se poi non sono ovunque»*.
class EsercizioInAllenamento extends EsercizioInScrittura {
  EsercizioInAllenamento({
    super.nome,
    super.note,
    super.exerciseId,
    super.muscoli,
    super.immagine,
    super.carico,
    List<SerieInAllenamento>? serie,
  }) : super(
         /*
          * ⚠️ **Una lista nuova, dichiarata `List<SerieInScrittura>`.**
          *
          * ⛔ Passando direttamente una `List<SerieInAllenamento>`, il giorno in
          * cui qualcuno ci infilasse una riga base Dart lancerebbe un
          * `TypeError` — **a metà allenamento**, che è il posto peggiore in cui
          * scoprire una scorrettezza di tipi. 💡 Meglio una lista larga e un
          * `cast` esplicito in [serieFatte], dove il difetto si vede subito.
          */
         serie: <SerieInScrittura>[
           ...(serie ??
               List.generate(
                 EsercizioInScrittura.seriePredefinite,
                 (_) => SerieInAllenamento(),
               )),
         ],
       );

  /// Da un esercizio scritto in una scheda — **in qualunque formato**.
  factory EsercizioInAllenamento.da(Map<String, dynamic> j) {
    final campi = campiDellEsercizio(j);

    return EsercizioInAllenamento(
      nome: campi.nome,
      note: campi.note,
      exerciseId: campi.exerciseId,
      muscoli: campi.muscoli,
      immagine: campi.immagine,
      carico: campi.carico,
      serie: [for (final s in campi.serie) SerieInAllenamento.da(s)],
    );
  }

  /// 🚨 Vedi [ConLeSerie.rigaNuova]: «Aggiungi serie» deve dare una riga che si
  /// possa spuntare, o l'unica serie non spuntabile sarebbe la quarta.
  @override
  SerieInScrittura rigaNuova() => SerieInAllenamento();

  /// Le righe, già del tipo giusto.
  ///
  /// ⚠️ Il `cast` è sicuro perché [rigaNuova] è l'unico modo in cui una riga
  /// entra in questa lista dopo la costruzione — ed è per questo che esiste.
  List<SerieInAllenamento> get serieFatte => [
    for (final r in righe) r as SerieInAllenamento,
  ];

  /// Quante ne sono state spuntate.
  int get quanteFatte => serieFatte.where((r) => r.fatta).length;

  bool get tuttoFatto => righe.isNotEmpty && quanteFatte == righe.length;
}

/// Gli esercizi da mostrare nel player: la scheda, più ciò che è già stato
/// registrato in questa seduta.
///
/// ══ 🚨 RIAPRIRE UNA SEDUTA INTERROTTA DEVE RITROVARE TUTTO ════════════════
///
/// ⛔ Non è un caso di scuola: il telefono si blocca, l'app viene chiusa dal
/// sistema mentre è in tasca, si esce per rispondere al telefono. Se al ritorno
/// le spunte non ci sono più, si rifanno delle serie già fatte — o, peggio, si
/// crede di averle fatte e si salta.
///
/// ⚠️ **Le serie registrate fuori scheda restano visibili**: un esercizio fatto
/// al volo esiste in archivio, e non mostrarlo vorrebbe dire un allenamento che
/// a schermo non corrisponde a quello che è stato scritto.
List<EsercizioInAllenamento> eserciziDellAllenamento({
  required Map<String, dynamic> scheda,
  required List<LoggedSet> fatte,
}) {
  final esercizi = <EsercizioInAllenamento>[
    for (final e in (scheda['exercises'] as List?) ?? const [])
      EsercizioInAllenamento.da((e as Map).cast<String, dynamic>()),
  ];

  final perNome = <String, List<LoggedSet>>{};

  for (final s in fatte) {
    perNome.putIfAbsent(s.exerciseName, () => []).add(s);
  }

  for (final e in esercizi) {
    _applica(e, perNome.remove(e.nome.text.trim()) ?? const []);
  }

  // Gli esercizi registrati **fuori scheda**.
  for (final voce in perNome.entries) {
    // ⚠️ Nasce **senza righe**: le fa `_applica` da quello che è stato
    // registrato. Inventarne tre vuote direbbe che la scheda le prevedeva.
    final e = EsercizioInAllenamento(
      nome: voce.key,

      /*
       * ⚠️ **Solo un id vero.** Gli id delle serie salvate senza rete sono
       * **negativi** di proposito (B.16.10), e lo zero è il ripiego di
       * `LoggedSet.fromJson`. 🚨 Prendendoli per buoni, l'esercizio
       * risulterebbe «già in catalogo» e la prima serie si prenderebbe un 422
       * per i muscoli mancanti — a metà allenamento.
       */
      exerciseId: voce.value.first.exerciseId > 0
          ? voce.value.first.exerciseId
          : null,
      serie: const [],
    );

    _applica(e, voce.value);

    esercizi.add(e);
  }

  return esercizi;
}

/// Riporta nelle righe quello che è già stato registrato.
void _applica(EsercizioInAllenamento esercizio, List<LoggedSet> fatte) {
  for (final s in fatte) {
    // ⛔ Il numero di serie è 1-based: la seconda serie è la riga di indice 1.
    while (esercizio.righe.length < s.setNumber) {
      esercizio.righe.add(SerieInAllenamento()..toccataAMano = true);
    }

    final riga = esercizio.serieFatte[s.setNumber - 1];

    riga
      ..fatta = true
      ..numeroRegistrato = s.setNumber
      ..toccataAMano = true;

    /*
     * 💡 **Quello che è stato fatto vince su quello che era prescritto**: la
     * riga mostra il peso vero, non quello che c'era scritto prima di alzarlo.
     * ⚠️ Solo se c'è: una serie registrata senza ripetizioni non deve
     * cancellare il numero che la scheda prescriveva.
     */
    if (s.reps != null) riga.ripetizioni.text = '${s.reps}';

    if (s.weight != null && esercizio.carico == CaricoDellEsercizio.peso) {
      riga.carico.text = numeroPulito(s.weight!);
    }

    if (s.restSec != null) riga.recupero.text = '${s.restSec}';
  }

  if (esercizio.righe.isEmpty) esercizio.righe.add(SerieInAllenamento());
}

/// La scheda con gli esercizi di **un giorno** riscritti — 3b-E.6.
///
/// ══ 🚨 SI RATTOPPA, NON SI RICOSTRUISCE ═══════════════════════════════════
///
/// ⛔ È la lezione del 24/08, che è costata due esercizi al committente:
/// ricostruire la scheda da quello che il player conosce **butta via tutto il
/// resto** — le note, la copertina, i giorni, i campi che una versione futura
/// aggiungerà. Qui si sostituisce una chiave sola e non si tocca nient'altro.
///
/// ══ ⚠️ E `days` VA TENUTO D'ACCORDO CON `exercises` ═══════════════════════
///
/// 🚨 Su una scheda a più giorni gli esercizi stanno **in due posti**:
/// `exercises` (che è il giorno 1, scritto anche per le versioni dell'app che i
/// giorni non li conoscono) e `days[0]['exercises']`. ⛔ Scriverne uno solo
/// vuol dire una scheda che dice due cose diverse a seconda di chi la legge — e
/// il difetto comparirebbe **solo aprendo l'editor**, giorni dopo.
///
/// ⏳ **Debito dichiarato**: il player esegue sempre il **giorno 1**. Scegliere
/// il giorno non c'è ancora, e finché non c'è [giorno] vale 0 sempre.
Map<String, dynamic> schedaConGliEsercizi(
  Map<String, dynamic> scheda,
  List<Map<String, dynamic>> esercizi, {
  int giorno = 0,
}) {
  final fuori = {...scheda};
  final giorni = fuori['days'] as List?;

  if (giorni == null || giorni.length <= giorno) {
    fuori['exercises'] = esercizi;

    return fuori;
  }

  final rifatti = [
    for (var i = 0; i < giorni.length; i++)
      if (i == giorno)
        {...(giorni[i] as Map).cast<String, dynamic>(), 'exercises': esercizi}
      else
        (giorni[i] as Map).cast<String, dynamic>(),
  ];

  fuori['days'] = rifatti;

  // ⚠️ `exercises` resta il giorno 1, come lo scrive `PlanActions.create`.
  if (giorno == 0) fuori['exercises'] = esercizi;

  return fuori;
}
