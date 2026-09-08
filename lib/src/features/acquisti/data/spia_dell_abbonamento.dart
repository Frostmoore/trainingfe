import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../auth/auth_controller.dart';

/// Cosa è cambiato nell'abbonamento da quando l'app è stata chiusa.
enum CambioDellAbbonamento {
  /// Niente da dire: era così anche l'ultima volta.
  nessuno,

  /// 🎉 Non era abbonato, adesso lo è.
  appenaAbbonato,

  /// 🛑 Era abbonato, adesso non più.
  appenaScaduto,
}

/// 👁️ Lo stato dell'abbonamento **visto l'ultima volta** — 08/09/2026.
///
/// ══ 🚨 IL DIFETTO CHE QUESTA CLASSE ESISTE PER RIPARARE ═══════════════════
///
/// 📌 Il committente: *«mi sono tolto l'abbonamento, ho chiuso l'app e l'ho
/// riaperta, poi ho di nuovo chiuso l'app, mi sono dato l'abbonamento e ho
/// riaperto l'app, e non mi è apparsa nessuna modale»*.
///
/// ⛔ **E non poteva apparire.** La modale era agganciata a un `ref.listen` su
/// `abbonatoProvider`, che confronta il valore *precedente* con quello nuovo
/// **dentro la stessa esecuzione dell'app**. Chiudendo e riaprendo, il valore
/// precedente non esiste più: è morto con il processo.
///
/// 🚨 **E c'era un secondo difetto sotto il primo, peggiore.**
/// `abbonatoProvider` vale `soloSeAbbonato(user?.abbonato)`, cioè **`true`
/// quando il profilo non è ancora arrivato** — è la scelta giusta per il gate
/// (un flag che manca non deve chiudere fuori chi ha pagato), ma qui vuol dire
/// che ogni avvio parte da `true`. ⛔ Il passaggio `false → true` non poteva
/// verificarsi **mai**, nemmeno a app aperta: il primo valore era già `true`.
///
/// 💡 Due difetti che si sommavano, e nessuno dei due dava un errore: la modale
/// semplicemente non compariva, e il codice si leggeva giusto.
///
/// ── ✅ Come si ripara ─────────────────────────────────────────────────────
///
/// 1. si guarda il valore **noto** (`bool?`), non quello con il ripiego: `null`
///    vuol dire «non lo so ancora» e non fa scattare niente;
/// 2. l'ultimo valore noto si **scrive sul telefono**, così sopravvive alla
///    chiusura dell'app — che è esattamente il caso riferito.
class SpiaDellAbbonamento {
  const SpiaDellAbbonamento(this._ref);

  final Ref _ref;

  /// ⚠️ Resta su **questo** telefono: sta in `PreferenzeNelBackup.restanoQui`.
  /// 🚨 Ripristinandola da un backup di un altro telefono si porterebbe dietro
  /// «quello che aveva visto quell'altro telefono», e la modale comparirebbe o
  /// sparirebbe per un motivo che non ha niente a che fare con chi guarda.
  static const chiave = 'abbonamento.ultimo_stato';

  /// Confronta con l'ultima volta, e **si aggiorna**.
  ///
  /// ⛔ **`null` non decide niente e non scrive niente.** Un profilo che non è
  /// ancora arrivato non è «non abbonato»: scrivere `false` in quel momento
  /// farebbe comparire «il tuo abbonamento è scaduto» a ogni avvio con la rete
  /// lenta. 🚨 È il difetto che questa classe deve evitare, non commettere.
  ///
  /// 💡 La prima volta in assoluto — chiave mai scritta — non è un cambiamento:
  /// si registra e basta. Chi installa l'app già abbonato non deve trovarsi una
  /// festa per qualcosa che ha comprato tre mesi fa.
  Future<CambioDellAbbonamento> confronta(bool? adesso) async {
    if (adesso == null) return CambioDellAbbonamento.nessuno;

    final cache = _ref.read(localCacheProvider);
    final prima = cache.getBool(chiave);

    if (prima != adesso) {
      await cache.setBool(chiave, value: adesso);
    }

    if (prima == null || prima == adesso) return CambioDellAbbonamento.nessuno;

    return adesso
        ? CambioDellAbbonamento.appenaAbbonato
        : CambioDellAbbonamento.appenaScaduto;
  }
}

final spiaDellAbbonamentoProvider = Provider(SpiaDellAbbonamento.new);

/// L'abbonamento **come lo sa il server**, senza ripieghi.
///
/// ══ 🚨 NON È `abbonatoProvider`, ED È TUTTO IL PUNTO ══════════════════════
///
/// | | `null` | A cosa serve |
/// |---|---|---|
/// | `abbonatoProvider` | diventa `true` | Decidere **cosa mostrare**: chi ha pagato non deve trovare le card sfumate mentre il profilo arriva |
/// | `abbonatoNotoProvider` | resta `null` | Accorgersi di un **cambiamento**: «non lo so ancora» non è «è cambiato» |
///
/// ⛔ Usare il primo per il secondo è il difetto dell'08/09: ogni avvio partiva
/// da `true`, e il passaggio da «non abbonato» ad «abbonato» non si vedeva mai.
final abbonatoNotoProvider = Provider<bool?>(
  (ref) => ref.watch(authControllerProvider).user?.abbonato,
);
