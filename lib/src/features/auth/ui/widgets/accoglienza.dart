import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/crypto/providers_crypto.dart';
import '../../../../core/crypto/servizio_chiavi.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../chiavi/ui/schermata_ripresa_dati.dart';
import '../../../health/health_controller.dart';
import '../../../privacy/consensi_controller.dart';
import '../../auth_controller.dart';

/// La sequenza subito dopo l'accesso — FASE 2-bis, 19/08/2026.
///
/// ── 🚨 L'ordine non è estetico: il primo passo evita una perdita di dati ──
///
/// | # | Passo | Perché lì |
/// |---|---|---|
/// | 1 | **L'impronta** | È l'unico che riguarda l'accesso stesso, e non tocca dati |
/// | 2 | **Il ripristino dal backup** | Va **prima che l'app scriva qualunque cosa** |
/// | 3 | Health Connect | Dopo aver spiegato a cosa serve |
/// | 4 | I consensi | Ultimi: sono la decisione più lunga, e non bloccano niente |
///
/// 🚨 **L'ordine è quello chiesto dal committente il 19/08**, dopo aver provato
/// la versione precedente: *«quando accedo mi fa un botto di richieste tutte
/// insieme, non va bene così, devono partire una dopo l'altra con una logica»*.
///
/// ⚠️ **Prima erano due widget separati** — questo e `PropostaSblocco` — e
/// partivano **insieme**, ognuno col proprio `postFrameCallback`. Due dialoghi
/// nello stesso frame: quello che arrivava secondo si apriva **sopra** il primo,
/// o veniva scartato. 💡 Adesso l'impronta è **dentro** la sequenza, ed è il
/// primo passo.
///
/// 🚨 **Il primo è quello che conta.** *«altrimenti mi si aggiungono cose nuove e
/// si crea una race condition che non avrebbe senso avere»* — il committente,
/// 19/08/2026. Se l'app comincia a scrivere nell'archivio locale e **poi** si
/// ripristina, il ripristino sovrascrive ciò che è appena stato creato. Non è un
/// fastidio di interfaccia: è **perdita di dati**.
///
/// ⚠️ **N7 non copre questo caso.** Il ripristino all'ingresso esiste per il
/// telefono nuovo alla prima apertura; qui si tratta di **accedere con un utente
/// che ha già usato l'app** su un telefono ripulito — che è quello che succede a
/// ogni reinstallazione.
///
/// ── 💡 Perché una sequenza sola e non tre widget ──────────────────────────
///
/// Perché tre widget indipendenti aprirebbero tre dialoghi **insieme**, o in
/// ordine casuale a seconda di quale future risponde prima. Qui i passi sono
/// `await` uno dietro l'altro, e l'ordine è quello scritto.
///
/// 🚨 **Non disegna niente** ed è invisibile, come `PropostaSblocco`: vive nella
/// shell perché è l'unico punto che esiste subito dopo l'accesso e sopravvive al
/// cambio di scheda.
class Accoglienza extends ConsumerStatefulWidget {
  const Accoglienza({super.key});

  @override
  ConsumerState<Accoglienza> createState() => _AccoglienzaState();
}

class _AccoglienzaState extends ConsumerState<Accoglienza> {
  /// ⚠️ Guardia di istanza: `build` gira più volte, e senza questa la sequenza
  /// partirebbe due volte sovrapposta.
  bool _inCorso = false;

  /// 🚨 **Chi ha già fatto l'accoglienza in QUESTA sessione dell'app.**
  ///
  /// Statica, e non basta il flag su disco. ⚠️ Il ripristino riapre l'archivio,
  /// e `authControllerProvider` lo **osserva**: quando l'archivio cambia il
  /// controller viene ricreato, la shell con lui, e nasce un
  /// `_AccoglienzaState` nuovo con `_inCorso` a `false`. La sequenza ripartiva
  /// da capo — impronta compresa — subito dopo aver ripristinato.
  ///
  /// 💡 È il difetto riferito il 19/08 sera, ed è la stessa famiglia della
  /// «race condition» che il ripristino esiste per evitare: uno stato scritto
  /// prima del ripristino e riletto dopo.
  static final Set<int> _fattaInQuestaSessione = <int>{};

  Future<void> _avvia() async {
    if (_inCorso) return;

    final utente = ref.read(authControllerProvider).user;

    if (ref.read(authControllerProvider).status != AuthStatus.loggedIn) return;
    if (utente == null) return;

    final cache = ref.read(localCacheProvider);

    // 💡 Una volta sola per persona su questo telefono: vedi
    // `LocalCache.accoglienzaFatta`.
    if (cache.accoglienzaFatta(utente.id)) return;

    // 🚨 E una volta sola **in questa sessione**, anche se il ripristino
    // ricrea la shell: vedi `_fattaInQuestaSessione`.
    if (!_fattaInQuestaSessione.add(utente.id)) return;

    _inCorso = true;

    /*
     * 🚨 **Si segna PRIMA di cominciare, non alla fine.**
     *
     * ⚠️ Se si segnasse in fondo, chiudere l'app a metà sequenza — o un errore
     * di rete sul secondo passo — la farebbe ricominciare da capo al riavvio,
     * riproponendo il ripristino a chi aveva appena detto di no. E la domanda a
     * cui questo flag risponde è «gliel'ho già chiesto?», non «è andata bene?».
     */
    await cache.segnaAccoglienzaFatta(utente.id);

    await _forseImpronta();
    if (!mounted) return;

    await _forseRipristina();
    if (!mounted) return;

    await _forseHealth();
    if (!mounted) return;

    await _forseConsensi();
  }

  /// 1. L'impronta — era `PropostaSblocco`, ora è il primo passo della sequenza.
  ///
  /// 🚨 **Le sue tre regole valgono ancora, e non sono cambiate**: una volta
  /// sola per dispositivo, mai se il telefono non sa farlo, e «più tardi» è una
  /// risposta legittima. `daProporre()` e `segnaProposto()` fanno tutto il
  /// lavoro; qui cambia solo **quando** viene chiamato.
  Future<void> _forseImpronta() async {
    final blocco = ref.read(bloccoBiometricoProvider);

    if (!await blocco.daProporre()) return;
    if (!mounted) return;

    final vuole = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.fingerprint_rounded, size: 32),
        title: const Text('Sblocco rapido'),
        content: const Text(
          "La prossima volta puoi riaprire l'app con l'impronta, invece di "
          'ridigitare la password.\n\n'
          'Puoi cambiare idea quando vuoi dal profilo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Più tardi'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Attiva'),
          ),
        ],
      ),
    );

    /*
     * 🚨 Si segna **prima** di provare ad attivare, e vale per entrambe le
     * risposte: la domanda a cui questo flag risponde è «gliel'ho già
     * chiesto?», non «ha funzionato?».
     */
    await blocco.segnaProposto();

    /*
     * 🚨 **«Più tardi» vuol dire NO, e lo si scrive** — 19/08/2026.
     *
     * *«se faccio "più tardi" vuol dire "NO", la devo abilitare a mano dopo»* —
     * il committente. ⚠️ Non basta non accendere: se l'interruttore era rimasto
     * acceso da prima — da un'installazione precedente, o da un passo andato
     * storto — chi risponde «più tardi» se lo ritrova **attivo**, ed è quello
     * che è successo stasera.
     *
     * 💡 Quindi un no lo **spegne**: la risposta della persona vince su
     * qualunque stato ereditato.
     */
    if (vuole != true) {
      await blocco.imposta(acceso: false);

      return;
    }

    await blocco.imposta(acceso: true);
  }

  /// 2. Questo account ha già usato l'app? Allora si va a riprendere i dati.
  ///
  /// ── 🚨 Il segnale lo dà il SERVER, non Google Drive ──────────────────
  ///
  /// Qui prima si chiamava `cercaNelCloud()`, che per rispondere **si collega a
  /// Drive** — e quindi apriva l'accesso a Google **prima** che la persona
  /// avesse deciso alcunché. ⚠️ Il committente: *«ancora cerca di fare l'accesso
  /// a google drive prima che si apra l'interfaccia di recupero. Non va bene»*.
  ///
  /// 💡 La domanda *«questo account ha già usato l'app?»* ha una risposta che
  /// **il server conosce già**: `StatoChiavi.daRipristinare` vuol dire «sul
  /// server c'è un pacchetto di chiavi, su questo telefono no» — cioè qualcuno
  /// che ha cambiato dispositivo o reinstallato. Nessun bisogno di Drive per
  /// saperlo.
  ///
  /// 🚨 **E niente dialogo che chiede «vuoi ripristinare?».** Si va dritti
  /// alla schermata, che quella domanda la fa già — con davanti il modulo della
  /// password e il «Più tardi». Chiedere due volte la stessa cosa è il motivo
  /// per cui la sequenza sembrava un interrogatorio.
  ///
  /// ⚠️ **Drive si tocca solo là dentro**, e solo dopo la password: è l'unico
  /// momento in cui serve davvero.
  Future<void> _forseRipristina() async {
    final StatoChiavi stato;

    try {
      stato = await ref.read(statoChiaviProvider.future);
    } on Object {
      // Rete assente o server muto: non è il momento di insistere.
      return;
    }

    if (stato != StatoChiavi.daRipristinare || !mounted) return;

    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SchermataRipresaDati()),
    );
  }

  /// 4. I consensi, **solo se nessuno è stato dato**.
  Future<void> _forseConsensi() async {
    final Consensi consensi;

    try {
      consensi = await ref.read(consensiProvider.future);
    } on Object {
      return;
    }

    /*
     * 🚨 **Due condizioni, e servono entrambe.**
     *
     * 1. **Nessun consenso dato**, alla lettera — richiesta del committente.
     *    ⚠️ Chi ne ha già dato uno ha **già visto** quella schermata e ha
     *    deciso: riproporgliela perché ne manca un altro vuol dire chiedergli
     *    di nuovo una cosa a cui aveva già risposto, e la seconda volta si
     *    tocca «no» per levarsela di torno — perdendo anche quello che avrebbe
     *    dato.
     * 2. **Non gliel'abbiamo mai chiesta** (`chiesti_il`, sul server).
     *    🚨 Senza la seconda, chi rifiuta **tutto** resta indistinguibile da
     *    chi non è mai stato interpellato — sono tre `null` in entrambi i casi
     *    — e si vedrebbe riproporre la domanda **a ogni reinstallazione**.
     *
     * 💡 Ed è il motivo per cui il segnale sta sul **server** e non nelle
     * preferenze locali: quelle muoiono con l'app, ed è esattamente quello che è
     * successo il 19/08, due volte in una sera.
     */
    if (!consensi.nessunoDato) return;
    if (!consensi.maiChiesti) return;
    if (!mounted) return;

    final vuole = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.privacy_tip_outlined, size: 32),
        title: const Text('Cosa ci lasci usare'),
        content: const Text(
          'Alcune funzioni hanno bisogno del tuo permesso: il diario con l\'AI, '
          'i dati di salute, il consiglio del giorno.\n\n'
          'Sono separati e li puoi cambiare quando vuoi. Senza, l\'app funziona '
          'lo stesso — con meno cose.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Più tardi'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Scegli adesso'),
          ),
        ],
      ),
    );

    /*
     * 🚨 **Si segna appena la domanda è stata MOSTRATA**, non dopo la
     * risposta, e vale anche per «Più tardi».
     *
     * ⚠️ Segnandolo solo dopo un sì, chi dice di no se la ritroverebbe la
     * prossima volta — che è esattamente il difetto che questa data esiste per
     * chiudere.
     *
     * 💡 Non si aspetta l'esito: se la chiamata fallisce, al massimo la
     * domanda ricompare una volta. Bloccare qui la sequenza per una rete lenta
     * sarebbe peggio.
     */
    unawaited(_segnaConsensiChiesti());

    if (vuole != true || !mounted) return;

    context.push(AppRoutes.consensi);
  }

  Future<void> _segnaConsensiChiesti() async {
    try {
      await ref.read(apiClientProvider).post<dynamic>('/account/consents/chiesti');
      ref.invalidate(consensiProvider);
    } on Object {
      // Vedi il dartdoc: si tace di proposito.
    }
  }

  /// 3. Health Connect, e la schermata di consenso di Google.
  Future<void> _forseHealth() async {
    final ponte = ref.read(ponteSaluteProvider);

    // 💡 Già collegato — o telefono senza Health Connect: non si chiede niente.
    if (await ponte.permessiGiaConcessi()) return;
    if (!mounted) return;

    final vuole = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.favorite_outline, size: 32),
        title: const Text('Colleghi Google Health?'),
        content: const Text(
          'Se lo colleghi, l\'app legge il sonno, il battito e le calorie che '
          'bruci con l\'attività — e le somma al tuo obiettivo calorico del '
          'giorno.\n\n'
          'Restano sul telefono: non le mandiamo a nessun server.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Non adesso'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Collega'),
          ),
        ],
      ),
    );

    if (vuole != true) return;

    /*
     * 🚨 **Si chiede DOPO aver spiegato, e mai all'avvio** — la regola di
     * `PonteSalute.chiediPermessi()`.
     *
     * ⚠️ Su Android un permesso negato ripetutamente diventa **non più
     * riproponibile**: chiederlo prima che qualcuno abbia capito a cosa serve è
     * il modo più rapido per bruciare la funzione per sempre.
     */
    await ponte.chiediPermessi();
  }

  @override
  Widget build(BuildContext context) {
    /*
     * 🚨 `watch` e non `initState`: quando la sessione si apre questa shell è
     * **già montata**, quindi un callback piazzato alla nascita del widget è già
     * passato. Guardando lo stato, la sequenza scatta al **passaggio** a
     * `loggedIn`.
     *
     * ⚠️ Il `postFrameCallback` resta: aprire un dialogo **durante** un `build`
     * è un errore di framework.
     */
    final stato = ref.watch(authControllerProvider).status;

    if (stato == AuthStatus.loggedIn && !_inCorso) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _avvia());
    }

    return const SizedBox.shrink();
  }
}
