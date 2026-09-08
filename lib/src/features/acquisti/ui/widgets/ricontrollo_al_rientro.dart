import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_controller.dart';
import '../../data/spia_dell_abbonamento.dart';
import 'abbonamento_scaduto.dart';
import 'hai_sbloccato_lai.dart';

/// 🔄 Al rientro nell'app si ricontrolla chi sei — 08/09/2026.
///
/// ══ 📌 LE DUE RICHIESTE ═══════════════════════════════════════════════════
///
/// *«quando si finalizza il pagamento di un abbonamento, deve aggiornare
/// automaticamente lo stato di abbonamento»* e *«dopo la scadenza
/// dell'abbonamento deve apparire una modale "Il tuo abbonamento è scaduto"»*.
///
/// ══ 🚨 PERCHÉ IL RICONTROLLO NON BASTA A FAR COMPARIRE UNA MODALE ═════════
///
/// ⛔ **Il pagamento non finisce dentro l'app.** `apriIlPagamento()` apre il
/// browser e torna **subito** — non quando la persona ha pagato, ma quando il
/// browser si è aperto. 💡 Il momento vero è il **rientro**, ed è quello che
/// questo osservatore intercetta.
///
/// 🚨 **Ma il rientro non è l'unico caso, e il primo tentativo lo dimenticava.**
/// 📌 *«mi sono tolto l'abbonamento, ho chiuso l'app e l'ho riaperta, poi ho di
/// nuovo chiuso l'app, mi sono dato l'abbonamento e ho riaperto l'app, e non mi
/// è apparsa nessuna modale»*.
///
/// ⛔ Chiudendo e riaprendo, il valore precedente **muore con il processo**: un
/// confronto in memoria non può vedere un cambiamento avvenuto fra due
/// esecuzioni. 💡 Per questo il confronto lo fa `SpiaDellAbbonamento`, che
/// l'ultimo stato lo **scrive sul telefono**.
///
/// ⚠️ **Costa una `/auth/me` per ogni rientro**, e va bene: è la stessa chiamata
/// che l'app fa a ogni avvio, e porta anche il branding e il piano. ⛔ Non ci si
/// può girare intorno con un timer: un'attesa fissa o è troppo corta per il
/// webhook o è troppo lunga per chi guarda lo schermo.
///
/// 🚨 **Se la rete non c'è non succede niente di male**: `_loadMe()` fallisce in
/// silenzio e lascia lo stato com'era — non butta fuori nessuno, e la spia non
/// vede nessun cambiamento perché il valore noto resta quello di prima.
class RicontrolloAlRientro extends ConsumerStatefulWidget {
  const RicontrolloAlRientro({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RicontrolloAlRientro> createState() =>
      _RicontrolloAlRientroState();
}

class _RicontrolloAlRientroState extends ConsumerState<RicontrolloAlRientro>
    with WidgetsBindingObserver {
  /// Una modale alla volta, e non due sovrapposte.
  ///
  /// ⚠️ La spia si aggiorna **al primo confronto**, quindi un secondo giro non
  /// vedrebbe più niente. 💡 Questo flag serve al caso in cui il valore noto
  /// oscilli mentre la modale è già aperta — una `/auth/me` che risponde due
  /// volte, un rientro durante l'animazione.
  bool _apertaUnaModale = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    /*
     * 🚨 **Il primo confronto, quello che il `listen` non può fare.**
     *
     * ⛔ `WidgetRef.listen` non ha un `fireImmediately`, e il caso che conta di
     * più — l'app riaperta dopo aver pagato — è proprio quello in cui il valore
     * **arriva prima** che questo widget si metta in ascolto: senza questa
     * riga, si perderebbe esattamente il caso riferito dal committente.
     *
     * 💡 Dopo il fotogramma, per non leggere provider durante la costruzione.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _valuta(ref.read(abbonatoNotoProvider));
    });
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
     * ha niente da ricontrollare, e una `/auth/me` senza token è un 401 che fa
     * scattare `_forgetSession()` — cioè un difetto al posto di un
     * aggiornamento.
     */
    if (ref.read(authControllerProvider).status != AuthStatus.loggedIn) return;

    ref.read(authControllerProvider.notifier).refresh();
  }

  Future<void> _valuta(bool? noto) async {
    if (_apertaUnaModale) return;

    final cambio = await ref.read(spiaDellAbbonamentoProvider).confronta(noto);

    if (cambio == CambioDellAbbonamento.nessuno || !mounted) return;

    _apertaUnaModale = true;

    /*
     * 💡 **Dopo il fotogramma**: aprire un foglio modale dentro un `build` — o
     * dentro il `listen` che ci sta attaccato — è la strada breve per un
     * `setState() called during build`.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _apertaUnaModale = false;

        return;
      }

      /*
       * == SENZA `context`, E NON E' UNA SVISTA ==
       *
       * Questo widget sta nel `builder` di `MaterialApp`, cioe' SOPRA il
       * `Navigator`: passando il proprio `context` le due modali non trovavano
       * nessun navigatore su cui aprirsi, e morivano dentro questo
       * `addPostFrameCallback` senza che si vedesse niente.
       *
       * E' il difetto riferito due volte dal committente. Le due `mostra()`
       * senza argomento usano `chiaveDelNavigatore`, che il navigatore vero lo
       * conosce.
       */
      await switch (cambio) {
        CambioDellAbbonamento.appenaAbbonato => HaiSbloccatoLAi.mostra(),
        CambioDellAbbonamento.appenaScaduto => AbbonamentoScaduto.mostra(),
        CambioDellAbbonamento.nessuno => Future<void>.value(),
      };

      _apertaUnaModale = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    /*
     * ══ 🚨 SI GUARDA IL VALORE **NOTO**, NON QUELLO CON IL RIPIEGO ════════
     *
     * ⛔ Il primo tentativo ascoltava `abbonatoProvider`, che vale `true` anche
     * quando il profilo non è ancora arrivato. 🚨 Così ogni avvio partiva da
     * `true`, e il passaggio da «non abbonato» ad «abbonato» non poteva
     * verificarsi mai: la modale non compariva, e il codice si leggeva giusto.
     *
     * 💡 `abbonatoNotoProvider` resta `null` finché non si sa, e la spia sul
     * `null` non decide niente.
     */
    ref.listen<bool?>(abbonatoNotoProvider, (_, adesso) => _valuta(adesso));

    return widget.child;
  }
}
