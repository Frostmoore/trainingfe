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
class PropostaSblocco extends ConsumerStatefulWidget {
  const PropostaSblocco({super.key});

  @override
  ConsumerState<PropostaSblocco> createState() => _PropostaSbloccoState();
}

class _PropostaSbloccoState extends ConsumerState<PropostaSblocco> {
  /// ⚠️ Guardia di istanza: `build` può girare più volte, e senza questa il
  /// dialogo si aprirebbe due volte sovrapposto.
  bool _giaFatto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _forse());
  }

  Future<void> _forse() async {
    if (_giaFatto) return;
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
  Widget build(BuildContext context) => const SizedBox.shrink();
}
