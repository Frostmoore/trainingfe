import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/backup/backup_controller.dart';
import '../../../../core/providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../health/health_controller.dart';
import '../../../privacy/consensi_controller.dart';
import '../../auth_controller.dart';

/// La sequenza subito dopo l'accesso — FASE 2-bis, 19/08/2026.
///
/// ── 🚨 L'ordine non è estetico: il primo passo evita una perdita di dati ──
///
/// | # | Passo | Perché lì |
/// |---|---|---|
/// | 1 | **Il ripristino dal backup** | Va **prima che l'app scriva qualunque cosa** |
/// | 2 | I consensi | Solo se **nessuno** è stato dato, e solo la prima volta |
/// | 3 | Health Connect | Dopo aver spiegato a cosa serve |
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

  Future<void> _avvia() async {
    if (_inCorso) return;

    final utente = ref.read(authControllerProvider).user;

    if (ref.read(authControllerProvider).status != AuthStatus.loggedIn) return;
    if (utente == null) return;

    final cache = ref.read(localCacheProvider);

    // 💡 Una volta sola per persona su questo telefono: vedi
    // `LocalCache.accoglienzaFatta`.
    if (cache.accoglienzaFatta(utente.id)) return;

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

    await _forseRipristina();
    if (!mounted) return;

    await _forseConsensi();
    if (!mounted) return;

    await _forseHealth();
  }

  /// 1. C'è un backup su Drive? Allora si chiede **prima di scrivere**.
  Future<void> _forseRipristina() async {
    final DateTime? quando;

    try {
      quando = await ref.read(backupAutomaticoProvider.notifier).cercaNelCloud();
    } on Object {
      // ⚠️ Nessun cloud, nessun permesso, nessuna rete: non è un errore da
      // mostrare. Chi vuole ripristinare ha la strada nel profilo.
      return;
    }

    if (quando == null || !mounted) return;

    final vuole = await showDialog<bool>(
      context: context,
      // 🚨 Non si chiude toccando fuori: è la domanda che protegge i dati, e
      // sfiorare lo schermo non è una risposta.
      barrierDismissible: false,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.cloud_download_outlined, size: 32),
        title: const Text('Hai già usato questa app'),
        content: Text(
          'Su Google Drive c\'è una copia dei tuoi dati del '
          '${DateFormat('d MMMM y', 'it').format(quando!.toLocal())}.\n\n'
          'Conviene riprenderla adesso: se cominci a usare l\'app e la '
          'ripristini dopo, quello che avrai scritto nel frattempo verrà '
          'sostituito.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Ricomincio da zero'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Riprendi i miei dati'),
          ),
        ],
      ),
    );

    if (vuole != true || !mounted) return;

    /*
     * 💡 Si manda alla **schermata della copia di sicurezza** invece di
     * ripristinare qui.
     *
     * ⚠️ Quella schermata ha già tutto: cerca nel cloud, mostra la data, chiede
     * conferma prima di sovrascrivere e riporta quante righe sono tornate.
     * 🚨 Rifare qui lo stesso percorso dentro un dialogo vorrebbe dire una
     * seconda copia della stessa logica — e la copia diverge sempre.
     */
    context.push(AppRoutes.backup);
  }

  /// 2. I consensi, **solo se nessuno è stato dato**.
  Future<void> _forseConsensi() async {
    final Consensi consensi;

    try {
      consensi = await ref.read(consensiProvider.future);
    } on Object {
      return;
    }

    /*
     * 🚨 **Solo se NESSUNO è approvato**, alla lettera — richiesta del
     * committente.
     *
     * ⚠️ Chi ne ha già dato uno ha **già visto** quella schermata e ha deciso:
     * riproporgliela perché ne manca un altro vuol dire chiedergli di nuovo una
     * cosa a cui aveva già risposto — e la seconda volta si tocca «no» per
     * levarsela di torno, perdendo anche quello che avrebbe dato.
     */
    if (consensi.saluteDato || consensi.aiDato || consensi.recuperoDato) return;
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

    if (vuole != true || !mounted) return;

    context.push(AppRoutes.consensi);
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
