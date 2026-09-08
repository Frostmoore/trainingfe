import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';

/// 🔄 Al rientro nell'app, si ricontrolla chi sei — 08/09/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// Il committente: *«quando si finalizza il pagamento di un abbonamento, deve
/// aggiornare automaticamente lo stato di abbonamento o no»*.
///
/// ══ 🚨 PERCHÉ NON BASTAVA AGGIORNARE DOPO IL PAGAMENTO ════════════════════
///
/// ⛔ **Il pagamento non finisce dentro l'app.** `apriIlPagamento()` apre il
/// browser e torna **subito** — non quando la persona ha pagato, ma quando il
/// browser si è aperto. 🚨 Invalidare lì dentro vuol dire aggiornare lo stato
/// *prima* che qualcuno abbia inserito la carta: si aggiorna, e si aggiorna
/// **sbagliato**.
///
/// 💡 Il momento vero è **il rientro**: la persona paga su Stripe, il webhook
/// arriva al nostro server, e lei torna all'app. Quello è l'unico istante in
/// cui la domanda «è abbonato?» ha una risposta nuova.
///
/// ⚠️ **Costa una `/auth/me` per ogni rientro**, e va bene: è la stessa chiamata
/// che l'app fa a ogni avvio, e porta anche il branding della palestra e il
/// piano. ⛔ Non ci si può girare intorno con un timer: un'attesa fissa o è
/// troppo corta per il webhook o è troppo lunga per chi guarda lo schermo.
///
/// 🚨 **Se la rete non c'è non succede niente di male**: `_loadMe()` fallisce
/// in silenzio e lascia lo stato com'era — non butta fuori nessuno.
class RicontrolloAlRientro extends ConsumerStatefulWidget {
  const RicontrolloAlRientro({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RicontrolloAlRientro> createState() =>
      _RicontrolloAlRientroState();
}

class _RicontrolloAlRientroState extends ConsumerState<RicontrolloAlRientro>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    if (stato != AppLifecycleState.resumed) return;

    /*
     * ⚠️ **Solo se c'è già una sessione.** Chi è sulla schermata di accesso non
     * ha niente da ricontrollare, e una `/auth/me` senza token è un 401 che
     * fa scattare `_forgetSession()` — cioè un difetto al posto di un
     * aggiornamento.
     */
    if (ref.read(authControllerProvider).status != AuthStatus.loggedIn) return;

    ref.read(authControllerProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
