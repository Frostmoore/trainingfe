import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/auth_controller.dart';
import '../avvisi_controller.dart';
import '../data/avviso.dart';
import 'avviso_modale.dart';

/// 📣 **L'avviso compare all'apertura dell'app** — blocco B4, 24/09/2026.
///
/// ══ 🚨 ALL'APERTURA, E NON SOPRA QUELLO CHE STAI FACENDO ════════════════════
///
/// ⛔ Mai sopra il player di un allenamento, mai dentro la chat, mai durante una
/// registrazione. 💡 Per questo l'osservatore sta **sopra il router** e guarda
/// l'**avvio** e i **rientri** — gli unici due momenti in cui nessuno è a metà
/// di qualcosa.
///
/// ⚠️ È lo stesso posto e la stessa forma di `SceltaDelloSlotAlRientro` e del
/// ricontrollo dell'abbonamento, con le tre lezioni già pagate:
///
/// | Lezione | Qui |
/// |---|---|
/// | sta sopra il `Navigator`: col proprio `context` non ne troverebbe nessuno | `AvvisoModale.mostra()` usa `chiaveDelNavigatore` |
/// | il primo controllo va fatto a mano (`listen` non ha `fireImmediately`) | `addPostFrameCallback` in `initState` |
/// | una finestra alla volta | `_aperta` |
///
/// 🚨 **Se la rete non c'è non succede niente**: l'avviso torna al rientro
/// successivo. ⛔ Un errore a schermo qui sarebbe una finestra rossa comparsa
/// dal nulla, per una cosa che la persona non ha chiesto.
class AvvisoAllApertura extends ConsumerStatefulWidget {
  const AvvisoAllApertura({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AvvisoAllApertura> createState() => _AvvisoAllAperturaState();
}

class _AvvisoAllAperturaState extends ConsumerState<AvvisoAllApertura>
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

  /// ⚠️ **Solo con la sessione aperta**: chiederlo sulla schermata d'accesso
  /// vorrebbe dire un 401 a ogni avvio, per niente.
  bool get _dentro =>
      ref.read(authControllerProvider).status == AuthStatus.loggedIn;

  Future<void> _controlla() async {
    if (_aperta || !_dentro) return;

    final Avviso? avviso;

    try {
      // 💡 Si richiede al server a ogni rientro: un avviso può essere nato
      //    mentre l'app era chiusa.
      ref.invalidate(prossimoAvvisoProvider);
      avviso = await ref.read(prossimoAvvisoProvider.future);
    } on Object {
      return;
    }

    if (avviso == null || !mounted || _aperta) return;

    _aperta = true;

    // 💡 Dopo il fotogramma: aprire un foglio dentro un `build` è la strada
    //    breve per un `setState() called during build`.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _aperta = false;

        return;
      }

      await AvvisoModale.mostra(avviso!);

      _aperta = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    /*
     * ⚠️ **Anche quando si entra**, non solo al rientro: chi fa l'accesso deve
     * trovare l'avviso subito, non al primo cambio d'app.
     */
    ref.listen(authControllerProvider, (prima, dopo) {
      if (prima?.status != AuthStatus.loggedIn &&
          dopo.status == AuthStatus.loggedIn) {
        _controlla();
      }
    });

    return widget.child;
  }
}
