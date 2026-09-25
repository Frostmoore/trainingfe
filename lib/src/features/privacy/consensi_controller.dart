import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../auth/auth_controller.dart';

/// Lo stato dei consensi — S9.1.
///
/// 🚨 **Sono date, non booleani, e arrivano così anche all'app.** L'art. 7(1)
/// chiede di poter dimostrare che il consenso è stato dato; qui servono anche a
/// dire *«concesso il 12 agosto»* invece di una spunta muta — chi riapre questa
/// schermata sta cercando di ricordarsi cosa ha deciso e quando.
class Consensi {
  const Consensi({
    this.salute,
    this.ai,
    this.aiPresaDAtto,
    this.recupero,
    this.consiglioAutomatico = true,
    this.nienteOfferte = false,
    this.nienteOfferteDal,
    this.chiestiIl,
  });

  factory Consensi.fromJson(Map<String, dynamic> j) => Consensi(
    salute: DateTime.tryParse(j['health']?.toString() ?? ''),
    ai: DateTime.tryParse(j['ai']?.toString() ?? ''),
    aiPresaDAtto: DateTime.tryParse(j['ai_disclaimer']?.toString() ?? ''),
    recupero: DateTime.tryParse(j['sleep_ai']?.toString() ?? ''),
    consiglioAutomatico: j['consiglio_automatico'] as bool? ?? true,

    /*
     * 🆕 🔕 **«Non mandarmi offerte»** — voce 43, 25/09/2026.
     *
     * ⚠️ **`false` di ripiego, ed è il verso giusto**: un server vecchio non
     * manda questo campo, e leggerlo come «si è opposto» spegnerebbe le
     * promozioni a chi non ha chiesto niente. 💡 È un opt-out: l'assenza di
     * risposta vuol dire «non l'ha detto», non «l'ha detto».
     */
    nienteOfferte: j['niente_offerte'] as bool? ?? false,
    nienteOfferteDal: DateTime.tryParse(
      j['niente_offerte_dal']?.toString() ?? '',
    ),
    chiestiIl: DateTime.tryParse(j['chiesti_il']?.toString() ?? ''),
  );

  /// Quando è stato concesso, oppure `null` se non lo è.
  final DateTime? salute;
  final DateTime? ai;

  /// ⚖️ Quando si è preso atto che l'AI **non è un parere medico** — 3b-J.3.
  ///
  /// ⛔ **Non è un permesso, è una dichiarazione.** [ai] è la base giuridica per
  /// mandare dati al fornitore; questa dice «ho capito cosa esce di là».
  ///
  /// 🚨 Il server **rifiuta** di accendere [ai] senza — e la revoca insieme,
  /// perché chi riaccende deve rileggere: è tutto il senso della richiesta.
  final DateTime? aiPresaDAtto;

  /// 🚨 Il consenso a mandare **sonno, battito e variabilità** ad Anthropic,
  /// dentro il consiglio del giorno — 16/08/2026.
  ///
  /// ⚠️ È **separato** da [ai], e non per pignoleria: chi accetta che una frase
  /// sul pranzo vada a un modello non ha con ciò accettato che ci vada quanto e
  /// come dorme. Sono due decisioni di intimità diversa, e l'art. 7 vieta il
  /// consenso a pacchetto.
  ///
  /// 💡 È **subordinato** ad [ai]: revocare l'AI lo revoca a cascata, lato
  /// server. L'interfaccia lo mostra spento e non toccabile finché l'AI è
  /// spenta — altrimenti si accenderebbe un consenso che non può valere.
  final DateTime? recupero;

  /// 💡 **Preferenza, non consenso**: un booleano, non una data. Di una
  /// preferenza non serve sapere *quando* è stata cambiata, di un consenso sì.
  final bool consiglioAutomatico;

  /// 🆕 🔕 Si è opposto alle comunicazioni commerciali — voce 43.
  ///
  /// ⚠️ **Opt-out, non consenso**: di serie è `false` e le offerte arrivano.
  final bool nienteOfferte;

  /// Da quando vale l'opposizione. `null` quando le offerte sono accese.
  final DateTime? nienteOfferteDal;

  /// Quando la schermata dei consensi e' stata **mostrata** — FASE 2-bis.
  ///
  /// 🚨 **«Chiesti» non e' «dati».** Senza questa data, «non gliel'ho mai
  /// chiesto» e «ha detto no a tutto» sono lo stesso stato — tre `null` — e chi
  /// rifiuta si vede riproporre la domanda a ogni reinstallazione.
  ///
  /// 💡 Sta sul **server** e non nelle preferenze locali proprio per questo:
  /// un flag nell'app muore con l'app.
  final DateTime? chiestiIl;

  /// Non e' mai stata mostrata la schermata dei consensi a questa persona.
  bool get maiChiesti => chiestiIl == null;

  /// Non ha dato **nessun** consenso.
  bool get nessunoDato => !saluteDato && !aiDato && !recuperoDato;

  bool get saluteDato => salute != null;

  bool get aiDato => ai != null;

  bool get presaDAttoData => aiPresaDAtto != null;

  bool get recuperoDato => recupero != null;
}

/// I consensi di **questa** sessione.
///
/// ══ 🚨 Perche' guarda chi e' entrato ═══════════════════════════════════
///
/// ⛔ `FutureProvider` **tiene anche gli errori**, non solo i risultati. All'avvio
/// l'app chiede i consensi prima ancora che ci sia un token: quella chiamata
/// prende un 401, l'errore resta in cache, e da quel momento la schermata della
/// privacy mostra *«Non riesco a leggere i tuoi consensi — Sessione scaduta»*
/// **per sempre**, anche dopo un accesso riuscito e anche mentre tutto il resto
/// dell'app funziona.
///
/// ⚠️ E' successo davvero il 22/09/2026, subito dopo un ripristino da file: il
/// server aveva risposto 201 a `PUT /chat-key` e 200 a `/dashboard`, ma la
/// privacy continuava a dire che la sessione era scaduta. Il committente:
/// *«Quando faccio il ripristino non deve succedere che mi dica che c'e' un
/// problema con i consensi. Follia pura»*. Aveva ragione: l'app dichiarava
/// rotto qualcosa che era a posto.
///
/// 💡 Guardando **chi e' entrato** il provider si ricalcola da solo a ogni
/// cambio di sessione — accesso, uscita, cambio di persona — e un errore preso
/// da sloggati non sopravvive all'accesso. ⚠️ Si guarda `(stato, id)` e non
/// l'intero `AuthState`: quello cambia anche per un `refresh()` del profilo, e
/// rileggere i consensi a ogni giro sarebbe una chiamata in piu' per niente.
final consensiProvider = FutureProvider<Consensi>((ref) async {
  ref.watch(authControllerProvider.select((s) => (s.status, s.user?.id)));

  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/account/consents');

  return Consensi.fromJson(data);
});

/// Il consenso sanitario, ridotto a una domanda secca — S9 / A5.
///
/// 🚨 **Esiste perché la stessa domanda si fa da due posti**: il cancello che
/// impedisce di collegare Health Connect, e il recupero che smette di mostrarsi
/// quando il consenso viene revocato. Scriverla due volte significa che un
/// giorno una delle due dirà `true` e l'altra `false`.
///
/// 💡 **Ed è ciò che rende la revoca istantanea**: `cambiaConsensoProvider`
/// invalida `consensiProvider`, questo si ricalcola, e tutto quello che lo
/// guarda si spegne da solo. Senza, la sezione recupero resterebbe visibile
/// fino al riavvio dell'app — che è esattamente il difetto trovato provandola.
///
/// ⚠️ **In dubbio risponde `false`**, errore di rete compreso: non poter
/// verificare un consenso vale quanto non averlo.
final consensoSaluteProvider = FutureProvider<bool>((ref) async {
  try {
    return (await ref.watch(consensiProvider.future)).saluteDato;
  } on Object {
    return false;
  }
});

/// Concede o revoca.
///
/// 🚨 **Revocare costa esattamente quanto concedere** (art. 7(3)): la stessa
/// chiamata, lo stesso campo, `false` invece di `true`. Un consenso che si dà
/// con un tocco e si toglie scrivendo un'email non è liberamente revocabile —
/// e quindi, a rigore, non è mai stato valido.
final cambiaConsensoProvider =
    Provider<Future<void> Function(String, bool, {bool presaDAtto})>((ref) {
      return (String quale, bool dato, {bool presaDAtto = false}) async {
        await ref
            .read(apiClientProvider)
            .patch<Map<String, dynamic>>(
              '/account/consents',
              body: {
                quale: dato,

                /*
                 * ⚖️ **La presa d'atto viaggia INSIEME all'accensione** —
                 * 3b-J.3.
                 *
                 * 🚨 Due chiamate separate vorrebbero dire che fra la prima e
                 * la seconda esiste un istante in cui l'AI è accesa senza. ⛔ E
                 * se la seconda fallisce — rete che cade, app chiusa — quello
                 * stato resta.
                 *
                 * 💡 Il server la pretende nella stessa richiesta proprio per
                 * questo: `ai: true` senza `ai_disclaimer: true` risponde 422.
                 */
                if (presaDAtto) 'ai_disclaimer': true,
              },
            );

        ref.invalidate(consensiProvider);
      };
    });
