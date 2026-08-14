import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth_controller.dart';

/// 🔒 Propone lo sblocco rapido **al primo accesso su un dispositivo** — A1.
///
/// ── Perché una proposta e non solo un interruttore nel profilo ────────────
///
/// Un'opzione che sta nelle impostazioni la trova chi la cerca. Ma nessuno
/// **cerca** una funzione di cui non sa l'esistenza: la si scopre il giorno che
/// si scorre il profilo per un altro motivo. Proporla una volta, subito dopo
/// aver digitato la password, è il momento in cui il vantaggio si capisce senza
/// spiegarlo — *«la prossima volta ti basta il dito»*.
///
/// ── ⚠️ Le tre regole che la rendono sopportabile ──────────────────────────
///
/// 1. **Una volta sola per dispositivo.** `segnaProposto()` si chiama **anche
///    quando la risposta è no**: ripresentarla a ogni avvio è il modo più
///    rapido per far disinstallare un'app.
/// 2. **Non compare se il telefono non sa farlo**, né se non c'è nessuna
///    impronta registrata — offrire una cosa che poi fallisce è peggio che non
///    offrirla.
/// 3. **«Più tardi» è una risposta legittima**, e resta l'interruttore nel
///    profilo. Non c'è nessuna insistenza da nessuna parte.
///
/// 💡 **Non disegna niente**: è un widget invisibile che si limita a far
/// comparire un dialogo. Sta nella shell perché è l'unico posto che esiste
/// subito dopo l'accesso e sopravvive al cambio di scheda.
///
/// ── 🚨 4ª regola: SOLO a sessione aperta — 14/08/2026 ─────────────────────
///
/// Difetto riferito provando l'app: *«mi chiede l'impronta prima ancora di aver
/// fatto la scelta di palestra o autonomo»*.
///
/// ⚠️ **La proposta partiva al primo fotogramma dell'app, sempre.** Il router
/// nasce con `initialLocation: AppRoutes.home`, e finché lo stato è
/// `AuthStatus.unknown` la regola 1 di `destinazione()` risponde «resta dove
/// sei» — quindi `HomeShell` **viene costruita davvero**, per la frazione di
/// secondo che serve a leggere il Keychain. Con lei nasceva questo widget, e il
/// suo `postFrameCallback` faceva il resto: nessuno era ancora entrato, e l'app
/// chiedeva l'impronta.
///
/// 🚨 **E la parte peggiore non è il fastidio.** `segnaProposto()` si scrive
/// **anche quando la risposta è no** (regola 1): la proposta «una volta sola per
/// dispositivo» veniva **bruciata prima del primo accesso**, cioè nel momento in
/// cui non voleva dire niente. Chi rispondeva «più tardi» non se la sarebbe più
/// vista offrire nel momento giusto — e la funzione sarebbe rimasta un
/// interruttore nascosto nel profilo, che è esattamente quello che la proposta
/// esiste per evitare.
///
/// 💡 Perciò non basta un `initState`: quando la sessione si apre, questa shell
/// **è già montata**. La proposta deve reagire al **passaggio** a `loggedIn`,
/// non al momento in cui nasce.
class PropostaSblocco extends ConsumerStatefulWidget {
  const PropostaSblocco({super.key});

  @override
  ConsumerState<PropostaSblocco> createState() => _PropostaSbloccoState();
}

class _PropostaSbloccoState extends ConsumerState<PropostaSblocco> {
  /// ⚠️ Guardia di istanza: `build` può girare più volte, e senza questa il
  /// dialogo si aprirebbe due volte sovrapposto.
  bool _giaFatto = false;

  Future<void> _forse() async {
    if (_giaFatto) return;

    // 🚨 La quarta regola, applicata qui: **si chiede solo a chi è dentro.**
    // Il controllo sta dentro `_forse()` e non solo nel `build` perché fra la
    // pianificazione del callback e la sua esecuzione può passare un frame, e
    // in quel frame la sessione può essere caduta.
    if (ref.read(authControllerProvider).status != AuthStatus.loggedIn) return;

    _giaFatto = true;

    final blocco = ref.read(bloccoBiometricoProvider);

    if (!await blocco.daProporre()) return;
    if (!mounted) return;

    final vuole = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        icon: const Icon(Icons.fingerprint_rounded, size: 32),
        title: const Text('Sblocco rapido'),
        content: const Text(
          'La prossima volta puoi riaprire l\'app con l\'impronta, invece di '
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
     * risposte.
     *
     * Se si segnasse solo dopo un'attivazione riuscita, chi sfiora l'impronta
     * male si ritroverebbe la proposta al riavvio successivo — e di nuovo, e di
     * nuovo. La domanda a cui questo flag risponde è «gliel'ho già chiesto?»,
     * non «ha funzionato?».
     */
    await blocco.segnaProposto();

    if (vuole != true) return;

    final fatto = await blocco.imposta(acceso: true);

    if (!mounted || fatto) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Non è andata. Puoi riprovare dal profilo, in «Sblocco rapido».',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    /*
     * 🚨 `watch` e non `initState`: quando la sessione si apre questa shell **è
     * già montata**, quindi un callback piazzato alla nascita del widget è già
     * passato da un pezzo. Guardando lo stato, la proposta scatta al
     * **passaggio** a `loggedIn` — che è il momento in cui ha un senso.
     *
     * ⚠️ Il `postFrameCallback` resta: aprire un dialogo **durante** un `build`
     * è un errore di framework, non una scortesia.
     */
    final stato = ref.watch(authControllerProvider).status;

    if (stato == AuthStatus.loggedIn && !_giaFatto) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _forse());
    }

    return const SizedBox.shrink();
  }
}
