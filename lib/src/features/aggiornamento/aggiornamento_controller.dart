import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/api_exception.dart';
import '../../core/providers.dart';

/// L'app è troppo vecchia — FASE 10.
///
/// ══ 🚨 LA REGOLA CHE DECIDE SE QUESTA FASE È UTILE O DANNOSA ══════════════
///
/// | Cosa risponde il server | L'app |
/// |---|---|
/// | `426` esplicito | 🔒 **si blocca** |
/// | `200`, versione buona | ✅ va avanti |
/// | **nessuna risposta** — rete assente, server giù, DNS morto | ✅ **va avanti** |
///
/// ⚠️ **Si blocca solo su un verdetto esplicito, mai sul silenzio.** Il
/// contrario renderebbe l'app inutilizzabile in aereo, in cantina, e ogni volta
/// che il *nostro* server ha un problema: cioè un guasto nostro diventerebbe
/// un'app rotta per tutti.
///
/// 🚨 **Ed è per questo che il cancello da solo non basta a spegnere un server
/// vecchio.** Il silenzio non blocca, quindi spegnerlo **non** fa scattare
/// niente: serve la procedura in cinque passi del piano, dove il server vecchio
/// resta acceso a dire «aggiornati» finché le copie vecchie non si sono fermate.
///
/// 💡 Qui non c'è nessuna chiamata di rete che va a cercare il verdetto: il
/// `426` arriva da solo, sulla prima richiesta che l'app fa comunque. Un
/// controllo dedicato all'avvio sarebbe una richiesta in più per dire una cosa
/// che la richiesta successiva direbbe da sé.
class StatoAggiornamento {
  const StatoAggiornamento({this.serve = false, this.store});

  final bool serve;
  final String? store;
}

class AggiornamentoController extends StateNotifier<StatoAggiornamento> {
  /*
   * 🚨 **Si iscrive allo stream, non aspetta che qualcuno lo chiami.**
   *
   * ⚠️ È la stessa scelta già fatta per il 401 in `AuthController`: se ogni
   * schermata dovesse accorgersi del 426 per conto suo, **la prima che se ne
   * dimentica** lascerebbe la persona davanti a un errore generico su un'app
   * che non può funzionare — e le farebbe premere «riprova» all'infinito.
   */
  AggiornamentoController(ApiClient api) : super(const StatoAggiornamento()) {
    _sub = api.onDaAggiornare.listen(bloccati);
  }

  StreamSubscription<AppDaAggiornareException>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  /// 🚨 Non si torna indietro da soli.
  ///
  /// ⚠️ Una volta che il server ha detto «sei vecchia», l'unica cosa che può
  /// smentirlo è **un'altra risposta del server**, cioè il pulsante «Riprova»
  /// della schermata. Sbloccarsi da soli dopo un timeout vorrebbe dire mostrare
  /// dati a una versione che il server ha appena dichiarato incompatibile.
  void bloccati(AppDaAggiornareException e) {
    state = StatoAggiornamento(serve: true, store: e.store);
  }

  /// 💡 Serve al «Riprova»: quando il blocco è stato **un errore nostro**, senza
  /// questo per toglierlo servirebbe un'altra pubblicazione sullo store.
  void sblocca() => state = const StatoAggiornamento();
}

final aggiornamentoProvider =
    StateNotifierProvider<AggiornamentoController, StatoAggiornamento>(
      (ref) => AggiornamentoController(ref.watch(apiClientProvider)),
    );
