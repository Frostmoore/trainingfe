import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../trainer_controller.dart';
import 'scelta_dello_slot.dart';

/// 🎟️ **La domanda sullo slot arriva da sola** — AH.1-ter.6, 18/09/2026.
///
/// ══ 📌 PERCHE' SERVE UN OSSERVATORE, E NON UNA PAGINA ═════════════════════
///
/// 📌 Il committente: *«il free trainer deve ricevere la modale»*. Dal piano:
/// serve *«un modo di chiedere al trainer, che al momento del passaggio non è
/// presente»*.
///
/// ⛔ **Il momento in cui nasce la domanda non è del trainer.** È l'allievo che
/// entra in palestra, magari mentre il trainer dorme. 🚨 Agganciarla alla pagina
/// «I miei utenti» vorrebbe dire che un trainer che non la apre per una
/// settimana non viene mai interpellato — e intanto continua a pagare un posto
/// su cui nessuno gli ha chiesto niente.
///
/// 💡 Per questo sta **sopra il router**, accanto al ricontrollo
/// dell'abbonamento, e guarda **all'apertura e a ogni rientro**.
///
/// ══ ⚠️ LE TRE LEZIONI GIA' PAGATE DAL RICONTROLLO DELL'ABBONAMENTO ════════
///
/// | Lezione | Qui |
/// |---|---|
/// | Sta sopra il `Navigator`, quindi il proprio `context` non ne trova nessuno | `SceltaDelloSlot.mostra()` usa `chiaveDelNavigatore` |
/// | Il primo controllo va fatto a mano: `listen` non ha un `fireImmediately` | `addPostFrameCallback` in `initState` |
/// | Una finestra alla volta | `_aperta` |
///
/// 🚨 **Se la rete non c'è non succede niente**: la domanda torna al rientro
/// successivo. ⛔ Un errore a schermo qui sarebbe una finestra rossa comparsa
/// dal nulla, su una cosa che il trainer non ha nemmeno chiesto.
class SceltaDelloSlotAlRientro extends ConsumerStatefulWidget {
  const SceltaDelloSlotAlRientro({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SceltaDelloSlotAlRientro> createState() =>
      _SceltaDelloSlotAlRientroState();
}

class _SceltaDelloSlotAlRientroState
    extends ConsumerState<SceltaDelloSlotAlRientro>
    with WidgetsBindingObserver {
  bool _aperta = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controlla();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    if (stato == AppLifecycleState.resumed) _controlla();
  }

  /// ⚠️ **Solo un trainer con la sessione aperta.** Per chiunque altro la rotta
  /// risponde 403, e chiederla a ogni rientro sarebbe rumore — o peggio, un 401
  /// su chi è sulla schermata d'accesso.
  bool get _eUnTrainerDentro {
    final stato = ref.read(authControllerProvider);

    return stato.status == AuthStatus.loggedIn &&
        (stato.user?.isTrainer ?? false);
  }

  Future<void> _controlla() async {
    if (_aperta || !_eUnTrainerDentro) return;

    final List<SlotDaDecidere> lista;

    try {
      /*
       * 💡 **Si rifà la domanda al server a ogni rientro**, non si legge una
       * risposta vecchia: la scelta nasce fuori da questo telefono, e fra un
       * rientro e l'altro qualcuno può essere entrato in palestra.
       */
      ref.invalidate(slotDaDecidereProvider);
      lista = await ref.read(slotDaDecidereProvider.future);
    } on Object {
      return;
    }

    if (lista.isEmpty || !mounted || _aperta) return;

    _aperta = true;

    /*
     * 💡 **Dopo il fotogramma**: aprire un foglio dentro un `build`, o dentro un
     * `listen`, è la strada breve per un `setState() called during build`.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _aperta = false;

        return;
      }

      await SceltaDelloSlot.mostra(lista);

      _aperta = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    /*
     * ⚠️ **Anche quando si entra**, non solo al rientro: un trainer che fa
     * l'accesso deve trovare la domanda subito, non al primo cambio d'app.
     * 💡 Si ascolta il **passaggio** a «trainer dentro», non il valore: così la
     * domanda non si ripete a ogni ricostruzione.
     */
    ref.listen<bool>(
      authControllerProvider.select(
        (s) => s.status == AuthStatus.loggedIn && (s.user?.isTrainer ?? false),
      ),
      (prima, adesso) {
        if (adesso && prima != true) _controlla();
      },
    );

    return widget.child;
  }
}
