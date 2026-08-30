import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/storage/archivio_salute.dart';
import '../privacy/consensi_controller.dart';
import '../profile/corpo_controller.dart';
import '../profile/data/modello_calorie.dart';
import '../profile/livello_attivita.dart';
import '../profile/target_locale_controller.dart';
import 'bruciate_dalle_sedute.dart';
import 'dati_salute.dart';
import 'ponte_salute.dart';

/// L'archivio locale, uno solo per tutta l'app.
///
/// ⚠️ **Non `autoDispose`**: un database che si chiude e riapre a ogni
/// schermata paga l'apertura del file ogni volta, e su un telefono lento si
/// vede. Vive quanto l'app.
final archivioSaluteProvider = Provider<ArchivioSalute>((ref) {
  final archivio = ArchivioSalute();

  ref.onDispose(archivio.close);

  return archivio;
});

final ponteSaluteProvider = Provider<PonteSalute>(
  (ref) => PonteSalute(ref.watch(archivioSaluteProvider)),
);

/// Quante volte l'archivio degli allenamenti è cambiato — FASE 1.10.
///
/// ── 🚨 Il difetto che chiude, trovato guardando l'app il 20/08 ────────────
///
/// La sincronizzazione scriveva l'allenamento nell'archivio e **non lo diceva a
/// nessuno**. Sul telefono del committente il ponte ha scritto la seduta di
/// pesi alle `00:18:29`, con lo storico già aperto davanti: la schermata è
/// rimasta su «Nessun allenamento» mentre nel database la riga c'era.
///
/// ⚠️ **È un difetto invisibile a chi lo prova male**: chi cambia scheda e
/// torna indietro vede il dato comparire — il provider è `autoDispose`, quindi
/// si ricrea — e conclude che funziona. Non funziona **al primo avvio**, che è
/// esattamente il momento in cui uno guarda.
///
/// 💡 Sta qui e non nella cartella `training` perché a scrivere è la
/// sincronizzazione, che è un fatto di salute. Il verso giusto è che chi mostra
/// dipenda da chi scrive, non il contrario.
final revisioneAllenamentiProvider = StateProvider<int>((ref) => 0);

/// Le calorie bruciate con l'attività in un giorno, lette da Google Health —
/// FASE 1.
///
/// 🚨 **Non escono mai da questo telefono.** Vivono in `ArchivioSalute` (che
/// finisce nel backup) e la somma con l'obiettivo calorico si fa **a runtime**,
/// qui nell'app: il server non le vede e non deve vederle.
///
/// 💡 `family` sul giorno perché la scheda cibo si può sfogliare indietro, e
/// il numero è quello **di quel giorno** — non quello di oggi mostrato accanto a
/// una data di tre giorni fa.
/// Le bruciate dell'orologio di un giorno — **dalle sedute**, 3b-G.3.
///
/// ⚠️ **Il nome è rimasto** perché lo leggono cinque schermate e cambiarlo
/// avrebbe voluto dire toccarle tutte per una cosa che non cambia il loro
/// significato: restano «le calorie che l'orologio dice che hai bruciato
/// allenandoti». ⛔ Cambia da dove le prende — vedi `bruciate_dalle_sedute.dart`
/// per il perché, che è lungo e vale la pena.
final kcalAttiveDelGiornoProvider = FutureProvider.autoDispose
    .family<int, DateTime>((ref, giorno) async {
      ref.watch(revisioneAllenamentiProvider);

      /*
       * ⚠️ **`valueOrNull` e non `await`, ed è deliberato** — 3b-G.4.
       *
       * 🚨 Il basale serve solo alla correzione netto/lordo, che oggi non
       * scatta per nessuna sorgente conosciuta. ⛔ Aspettarlo vorrebbe dire far
       * dipendere le calorie bruciate — che stanno nell'archivio locale — da
       * una chiamata al server per il profilo: la card di «Oggi» si
       * fermerebbe a metà per una correzione che quasi sempre vale zero.
       *
       * 💡 Se il basale non c'è ancora non si corregge (che è comunque il
       * ripiego giusto), e quando arriva questo provider si rifà da solo.
       */
      final bmr = ref.watch(metabolismoBasaleProvider).valueOrNull;

      final sedute = await ref
          .watch(archivioSaluteProvider)
          .seduteDellOrologioDi(giorno);

      return kcalDelleSedute(sedute, bmr: bmr);
    });

/// Le bruciate che si sommano **anche nel modello a stima** — 3b-G.7.
///
/// ══ 🚨 PERCHE' NON E' SEMPRE IL TOTALE DELLE SEDUTE MARCATE ═══════════════
///
/// | Modello | Cosa torna | Perché |
/// |---|---|---|
/// | `stima` | le sedute marcate | gli allenamenti normali sono già nel fattore, questi no |
/// | `misurata` | **zero** | lì entrano già tutte: sommarle di nuovo le conterebbe due volte |
/// | non ha scelto | **zero** | niente cambia da solo prima che risponda |
///
/// ⛔ **Lo zero del secondo caso è la cosa importante.** Una seduta marcata
/// «fuori dal solito» resta marcata anche cambiando modello — è un dato della
/// seduta, non dell'impostazione — e senza questo zero riapparirebbe come
/// margine doppio il giorno che qualcuno passa a «misurata».
final bruciateExtraDelGiornoProvider = FutureProvider.autoDispose
    .family<int, DateTime>((ref, giorno) async {
      ref.watch(revisioneAllenamentiProvider);

      if (ref.watch(modelloCalorieProvider) != ModelloCalorie.stima) return 0;

      return ref.watch(archivioSaluteProvider).kcalExtraDi(giorno);
    });

/// L'andamento di una metrica negli ultimi giorni — 3b-O.5.3.
///
/// 🚨 Serve alla scheda «Recupero» per disegnare **una linea invece di un
/// numero**: per HRV e battito a riposo il valore singolo non dice quasi niente,
/// conta il verso — e il verso si legge solo se i punti sono uniti.
///
/// 💡 Una media **per giorno**: Health Connect scrive decine di campioni al
/// giorno, e disegnarli tutti darebbe un pettine invece di un andamento.
final andamentoMetricaProvider = FutureProvider.autoDispose
    .family<List<double>, MetricaSalute>((ref, metrica) async {
      ref.watch(healthControllerProvider);

      final righe = await ref
          .watch(archivioSaluteProvider)
          .mediePerGiorno(metrica, giorni: 7);

      // ⚠️ Dal più vecchio al più recente: `mediePerGiorno` ordina già così, e
      // invertirlo darebbe un disegno plausibile e sbagliato.
      return righe.map((r) => r.media).toList();
    });

/// Le calorie attive **di oggi**.
///
/// ── 🚨 Perché un provider a parte e non `…DelGiorno(DateTime.now())` ──
///
/// **Perché quella riga non funziona, e non lo dice.** La chiave di una `family`
/// è il valore passato: `DateTime.now()` cambia a **ogni millisecondo**, quindi
/// ogni `build` creava un provider **nuovo** — appena nato, quindi in
/// caricamento, quindi `valueOrNull == null`, quindi `?? 0`.
///
/// ⚠️ **Il numero non compariva mai**, e non c'era nessun errore da nessuna
/// parte: la schermata mostrava zero come se zero fosse la risposta. È il
/// difetto riferito dal committente la sera del 19/08 — *«nell'header della
/// pagina oggi non le somma e non le mostra»* — e la prima correzione non lo
/// aveva chiuso proprio per questo.
///
/// 💡 Qui la data si calcola **dentro**, e l'identità del provider è una sola.
/// La scheda cibo invece usa `…DelGiorno(day.date)`, che è stabile perché è la
/// giornata che si sta sfogliando — e infatti lì funzionava.
/// Le calorie attive per un elenco di giornate (`yyyy-mm-dd`) — 19/08/2026.
///
/// 🚨 Serve al **grafico**, che mostrava zero bruciate mentre l'intestazione
/// ne mostrava 680. Non erano due numeri diversi: erano **due fonti diverse** —
/// il grafico legge la serie del server, che le calorie dell'orologio non le ha
/// e non le puo' avere, perche' restano sul telefono.
///
/// 💡 La chiave e' la lista delle date **gia' formattate**, cosi' l'identita'
/// del provider e' stabile: e' l'errore che avevo fatto con `DateTime.now()`,
/// che cambiava a ogni millisecondo e teneva il provider per sempre in
/// caricamento.
final kcalAttivePerGiorniProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, giorniUnitiDaVirgole) async {
      final archivio = ref.watch(archivioSaluteProvider);
      final esito = <String, int>{};

      // 3b-G.3: dalle sedute, non dal flusso. Vedi `kcalAttiveDelGiornoProvider`.
      ref.watch(revisioneAllenamentiProvider);

      final bmr = ref.watch(metabolismoBasaleProvider).valueOrNull;

      for (final etichetta in giorniUnitiDaVirgole.split(',')) {
        final giorno = DateTime.tryParse(etichetta);

        if (giorno == null) continue;

        esito[etichetta] = kcalDelleSedute(
          await archivio.seduteDellOrologioDi(giorno),
          bmr: bmr,
        );
      }

      return esito;
    });

final kcalAttiveOggiProvider = FutureProvider.autoDispose<int>((ref) async {
  final adesso = DateTime.now();

  return ref.watch(
    kcalAttiveDelGiornoProvider(
      DateTime(adesso.year, adesso.month, adesso.day),
    ).future,
  );
});

/// Lo stato del collegamento con Health Connect.
class StatoSalute {
  const StatoSalute({
    this.collegato = false,
    this.inCorso = false,
    this.errore,
    this.ultimaSincronizzazione,
  });

  final bool collegato;
  final bool inCorso;
  final String? errore;
  final String? ultimaSincronizzazione;

  StatoSalute copyWith({
    bool? collegato,
    bool? inCorso,
    String? errore,
    String? ultimaSincronizzazione,
    bool azzeraErrore = false,
  }) => StatoSalute(
    collegato: collegato ?? this.collegato,
    inCorso: inCorso ?? this.inCorso,
    errore: azzeraErrore ? null : (errore ?? this.errore),
    ultimaSincronizzazione:
        ultimaSincronizzazione ?? this.ultimaSincronizzazione,
  );
}

/// Chi governa il collegamento e la sincronizzazione — S3.4 / A5.
class HealthController extends StateNotifier<StatoSalute> {
  HealthController(
    this._ponte,
    this._archivio,
    this._consensoSanitario,
    this._segnalaAllenamenti,
    this._segnalaMisure,
  ) : super(const StatoSalute());

  final PonteSalute _ponte;
  final ArchivioSalute _archivio;

  /// Come si avvisa che l'archivio degli allenamenti è cambiato — FASE 1.10.
  ///
  /// 🚨 **Una chiusura e non un `Ref`**, come `AuthController._svuotaLArchivio`
  /// e per la stessa ragione pagata il 19/08: un controller che tiene un `Ref`
  /// finisce per dipendere dal grafo dei provider, e allora qualunque cosa lo
  /// tocchi può ricrearlo. Qui serve **un solo gesto**, e si passa quello.
  ///
  /// 💡 Effetto collaterale utile: nei test si passa una funzione che conta le
  /// chiamate, e si può verificare che dopo una sincronizzazione l'avviso parta
  /// davvero — senza montare mezzo Riverpod.
  final void Function() _segnalaAllenamenti;

  /// Come si avvisa che **le misure del corpo** sono cambiate — 3b-W.
  ///
  /// 🚨 **Una chiusura e non un `Ref`**, per la stessa ragione scritta qui
  /// sopra: un controller che sa di Riverpod costringe i test a montarne uno
  /// per provare una sincronizzazione.
  ///
  /// ⚠️ Serve perché `revisioneCorpoProvider` è quello che fa ricalcolare
  /// target, grafico e card del peso: senza, una pesata arrivata dalla bilancia
  /// resterebbe nel database e **non si vedrebbe** finché non si riapre la
  /// schermata. ⛔ E il sintomo — «l'app non prende il peso» — non somiglia per
  /// niente alla causa.
  final void Function() _segnalaMisure;

  /// Se la persona ha dato il consenso al trattamento dei dati sanitari — S9.
  ///
  /// 🚨 **È una funzione e non un `bool`** perché va riletta al momento del
  /// gesto: il consenso si revoca da un'altra schermata, e una copia presa
  /// all'avvio direbbe «sì» a chi ha appena detto di no.
  final Future<bool> Function() _consensoSanitario;

  /// Chiede il permesso e, se c'è, sincronizza subito.
  ///
  /// ⚠️ **Il permesso e la prima lettura vanno insieme.** Chiedere il permesso
  /// e poi lasciare la schermata vuota fino al giorno dopo fa sembrare che non
  /// sia successo niente, e la persona lo revoca.
  Future<void> collega() async {
    state = state.copyWith(inCorso: true, azzeraErrore: true);

    /*
     * 🚨 **Il consenso sanitario viene PRIMA del permesso di sistema** — A5/S9.
     *
     * `ConsentController` lo dichiarava già («senza il consenso sanitario non
     * si collega Health Connect») ⚠️ **e nessuno lo verificava**: la
     * dichiarazione stava nel dartdoc del server e il cancello non esisteva da
     * nessuna parte.
     *
     * L'ordine conta. Chiedere prima il permesso di Android e poi accorgersi
     * che manca il consenso significherebbe aver già aperto il dialogo di
     * sistema — che su Android, se rifiutato due volte, **non si ripropone
     * più**. Si sarebbe bruciata l'unica occasione per una verifica che si
     * poteva fare senza disturbare nessuno.
     */
    if (!await _consensoSanitario()) {
      state = state.copyWith(
        inCorso: false,
        collegato: false,
        errore:
            'Prima serve il tuo consenso al trattamento dei dati sanitari: '
            'lo trovi in Profilo → Privacy e consensi.',
      );

      return;
    }

    final concesso = await _ponte.chiediPermessi();

    if (!concesso) {
      state = state.copyWith(
        inCorso: false,
        collegato: false,
        errore:
            'Non è stato possibile collegare Health Connect. '
            'Se hai già rifiutato in passato, il permesso va riattivato dalle '
            'impostazioni di sistema.',
      );

      return;
    }

    /*
     * 🚨 30 giorni, non 7.
     *
     * Health Connect di serie lascia rileggere circa un mese indietro, e oltre
     * serve un permesso a parte che Google concede con parsimonia. Alla PRIMA
     * sincronizzazione si prende tutto quello che si puo': da li' in poi la
     * memoria lunga e' l'archivio locale, che accumula.
     *
     * ⚠️ La media di riferimento a sette giorni esiste comunque solo dopo
     * sette giorni di dati. Non e' un difetto, ma va detto — o sembrera' che
     * la funzione non parta.
     */
    final quanti = await _ponte.sincronizza(giorniIndietro: 30);

    /*
     * ══ ⚖️ E il corpo, che ha una finestra sua — 3b-W.1 ═══════════════════
     *
     * 🚨 **Una chiamata a parte e non un tipo in più in `sincronizza`.** Il
     * sonno vale sette giorni; il peso di due anni fa è la cosa che si guarda
     * indietro. ⛔ Allargare la finestra del resto a due anni vorrebbe dire
     * rileggere ogni volta 56.000 record di battito — sei secondi misurati sul
     * telefono il 30/08 — per un dato che cambia una volta al giorno.
     *
     * 💡 `sincronizzaIlCorpo()` decide da sé quanto indietro andare: tutto la
     * prima volta, poi solo il nuovo.
     */
    final misure = await _ponte.sincronizzaIlCorpo();

    /*
     * ⚠️ **La revisione si alza solo se qualcosa è cambiato davvero.**
     * `revisioneCorpoProvider` fa ricalcolare target, grafico e card: farlo a
     * ogni avvio anche senza pesate nuove vorrebbe dire tre ricalcoli inutili
     * ogni volta che si apre l'app.
     */
    if (misure > 0) _segnalaMisure();

    _diCheCiSonoAllenamentiNuovi();

    state = state.copyWith(
      inCorso: false,
      collegato: true,
      ultimaSincronizzazione: DateFormat(
        'd MMM, HH:mm',
        'it',
      ).format(DateTime.now()),
      errore: quanti == 0
          ? 'Collegato, ma non è arrivato ancora nessun dato. '
                'Succede se il tuo orologio non ha ancora sincronizzato con il telefono.'
          : null,
      azzeraErrore: quanti > 0,
    );
  }

  /// Riprende i dati nuovi **senza chiedere niente a nessuno** — A5.
  ///
  /// ── 🚨 Il difetto che chiude ──────────────────────────────────────────
  ///
  /// Prima l'unico modo di aggiornare i dati era tornare su «Sonno e recupero»
  /// e ritoccare *Collega*. Chi lo faceva il primo giorno e non ci tornava più
  /// vedeva **per sempre** il sonno di quella notte: la scheda in cima a «Oggi»
  /// mostrava un dato vecchio senza dire che era vecchio, ed è il modo più
  /// rapido per far smettere di fidarsi di un numero.
  ///
  /// ── ⚠️ Perché non chiede il permesso ──────────────────────────────────
  ///
  /// `chiediPermessi()` apre il dialogo di sistema, e questo metodo gira
  /// all'avvio: aprirlo lì sarebbe la cosa che il dartdoc di `PonteSalute`
  /// vieta esplicitamente — un permesso chiesto prima che si capisca a cosa
  /// serve viene negato, e su Android un rifiuto ripetuto **non si ripropone
  /// più**.
  ///
  /// Perciò qui si guarda solo se il permesso **c'è già**: se manca, non
  /// succede niente e la persona lo concederà dalla schermata che glielo
  /// spiega.
  ///
  /// 💡 Sette giorni e non trenta: è la finestra della media di riferimento, e
  /// riprendere un mese a ogni avvio costerebbe tempo per dati che l'archivio
  /// ha già.
  Future<void> aggiornaInSilenzio() async {
    // Anche qui il consenso viene prima: se è stato revocato, l'app smette di
    // leggere subito, non alla prossima volta che qualcuno tocca «collega».
    if (!await _consensoSanitario()) return;
    if (!await _ponte.permessiGiaConcessi()) return;

    final quanti = await _ponte.sincronizza();

    /*
     * ══ ⚖️ E il corpo, che ha una finestra sua — 3b-W.1 ═══════════════════
     *
     * 🚨 **Una chiamata a parte e non un tipo in più in `sincronizza`.** Il
     * sonno vale sette giorni; il peso di due anni fa è la cosa che si guarda
     * indietro. ⛔ Allargare la finestra del resto a due anni vorrebbe dire
     * rileggere ogni volta 56.000 record di battito — sei secondi misurati sul
     * telefono il 30/08 — per un dato che cambia una volta al giorno.
     *
     * 💡 `sincronizzaIlCorpo()` decide da sé quanto indietro andare: tutto la
     * prima volta, poi solo il nuovo.
     */
    final misure = await _ponte.sincronizzaIlCorpo();

    /*
     * ⚠️ **La revisione si alza solo se qualcosa è cambiato davvero.**
     * `revisioneCorpoProvider` fa ricalcolare target, grafico e card: farlo a
     * ogni avvio anche senza pesate nuove vorrebbe dire tre ricalcoli inutili
     * ogni volta che si apre l'app.
     */
    if (misure > 0) _segnalaMisure();

    _diCheCiSonoAllenamentiNuovi();

    if (!mounted) return;

    state = state.copyWith(
      collegato: true,
      ultimaSincronizzazione: quanti > 0
          ? DateFormat('d MMM, HH:mm', 'it').format(DateTime.now())
          : state.ultimaSincronizzazione,
    );
  }

  /// Dice allo storico che l'archivio è cambiato — FASE 1.10.
  ///
  /// 🚨 **Scrivere non basta**: il ponte scrive nel database, ma chi guarda ha
  /// già in mano una lista letta prima. Senza questa riga la seduta compare
  /// solo cambiando schermata e tornando indietro — cioè **non** al primo
  /// avvio, che è il momento in cui uno guarda.
  ///
  /// 💡 Si chiama **sempre**, anche quando la sincronizzazione non ha portato
  /// niente: costa una lettura di una tabella piccola, e il ragionamento
  /// «bumpa solo se `quanti > 0`» sarebbe sbagliato — `quanti` conta anche
  /// letture e sonno, e non dice se gli **allenamenti** sono cambiati.
  void _diCheCiSonoAllenamentiNuovi() => _segnalaAllenamenti();

  /// Cancella tutto quello che c'è sul telefono.
  ///
  /// 🚨 Con i dati in locale il server non può cancellarli per conto di
  /// nessuno: **questo è l'unico modo che una persona ha di liberarsene** senza
  /// disinstallare l'app.
  Future<void> cancellaTutto() async {
    state = state.copyWith(inCorso: true, azzeraErrore: true);

    await _archivio.svuota();

    state = state.copyWith(inCorso: false, ultimaSincronizzazione: null);
  }
}

final healthControllerProvider =
    StateNotifierProvider<HealthController, StatoSalute>(
      (ref) => HealthController(
        ref.watch(ponteSaluteProvider),
        ref.watch(archivioSaluteProvider),

        /*
     * Il consenso si **rilegge** a ogni gesto, e non si cattura una volta: si
     * revoca da un'altra schermata, e una copia presa all'avvio direbbe «sì» a
     * chi ha appena detto di no.
     *
     * 💡 La regola vive tutta in `consensoSaluteProvider` — compreso il
     * «in dubbio è no» — perché la stessa domanda se la fa anche
     * `recuperoProvider`, e due implementazioni divergono sempre.
     */
        () => ref.read(consensoSaluteProvider.future),

        /*
     * 🚨 `ref.read` e non `ref.watch` — la stessa distinzione che il 19/08 è
     * costata l'utente che spariva dopo un ripristino. Con `watch` questo
     * controller si ricreerebbe **a ogni incremento del contatore**, cioè a ogni
     * sincronizzazione: si ricrea il controller che ha appena finito di
     * sincronizzare, e la cosa si morde la coda.
     */
        () => ref.read(revisioneAllenamentiProvider.notifier).state++,

        /*
     * ⚖️ 3b-W — e la stessa cosa per le misure del corpo.
     *
     * ⚠️ `ref.read` come sopra, e per lo stesso motivo: con `watch` il
     * controller si ricreerebbe a ogni pesata arrivata dalla bilancia — cioe'
     * subito dopo averla scritta lui.
     */
        () => ref.read(revisioneCorpoProvider.notifier).state++,
      ),
    );

/// La risincronizzazione d'avvio — A5.
///
/// 🚨 **Non è `autoDispose`, ed è il motivo per cui gira una volta sola** per
/// vita dell'app: se lo fosse, ogni volta che l'ultima schermata interessata
/// sparisce il provider morirebbe e la sincronizzazione ripartirebbe al
/// ritorno — cioè a ogni cambio di scheda.
final avvioSaluteProvider = FutureProvider<void>(
  (ref) => ref.read(healthControllerProvider.notifier).aggiornaInSilenzio(),
);
