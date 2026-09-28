/// 🔔 **Il catalogo delle notifiche, lato app** — voce 62, 27/09/2026.
///
/// ══ 📌 PERCHE' ESISTE, E PERCHE' NON E' UNA SECONDA LISTA ══════════════════
///
/// 📌 Il committente: *«il sistema delle notifiche fallo autoconsistente. Voglio
/// un solo punto dove posso aggiungere notifiche»*.
///
/// 🔑 **Il punto dove si aggiungono è il server**: `App\Enums\Notifica` nel
/// backend. ⛔ Questo file è il suo **riflesso**, e non una seconda lista da
/// tenere a mente: `test/catalogo_delle_notifiche_test.dart` legge l'enum PHP e
/// pretende che i due elenchi coincidano, valore per valore e canale per canale.
///
/// ⚠️ Quindi aggiungendo una notifica di là, **questo test diventa rosso** e dice
/// cosa manca qui. 💡 È il contrario di due copie che divergono in silenzio: qui
/// divergere è **impossibile senza accorgersene**.
///
/// ══ 🚨 PERCHE' ALL'APP SERVONO ANCHE LE PUSH ══════════════════════════════
///
/// Perché è l'app a decidere **dove portare** quando le tocchi, e lo fa leggendo
/// il campo `tipo` — che è esattamente il valore di questi casi. ⛔ Prima era una
/// stringa scritta a mano di qua e di là: due posti che dovevano restare uguali
/// per abitudine.
library;

/// Da dove parte una notifica.
enum CanaleDellaNotifica {
  /// 📡 Dal **server**, via Firebase. ⚖️ Nella DPIA è un trattamento con Google
  /// come sub-responsabile.
  push,

  /// 📱 La programma l'**app**. ✅ Non esce dal telefono, funziona senza rete, e
  /// ⚖️ **non** è un trattamento con un sub-responsabile.
  locale,
}

/// 🔔 Tutte le notifiche del prodotto.
///
/// ⚠️ **L'ordine e i nomi seguono l'enum PHP**: il `valore` è la stringa che
/// viaggia nel campo `tipo` delle push, e quella deve combaciare.
enum Notifica {
  // ─────────────── 📡 push: l'evento è già sul server ───────────────
  messaggio('messaggio', CanaleDellaNotifica.push, 'messaggi'),
  avviso('avviso', CanaleDellaNotifica.push, 'casa'),
  promozione('promozione', CanaleDellaNotifica.push, 'offerte'),
  incassoFallito('incasso_fallito', CanaleDellaNotifica.push, 'abbonamento'),
  abbonamentoInScadenza(
    'abbonamento_in_scadenza',
    CanaleDellaNotifica.push,
    'abbonamento',
  ),
  servizioRiattivato(
    'servizio_riattivato',
    CanaleDellaNotifica.push,
    'abbonamento',
  ),
  invito('invito', CanaleDellaNotifica.push, 'casa'),
  slotDeciso('slot_deciso', CanaleDellaNotifica.push, 'messaggi'),
  rispostaARichiesta('risposta_a_richiesta', CanaleDellaNotifica.push, 'casa'),
  importPronto('import_pronto', CanaleDellaNotifica.push, 'casa'),
  stimaPronta('stima_pronta', CanaleDellaNotifica.push, 'diario'),

  // ─────────────── 📱 locali: il server non sa, e non deve ───────────────

  /// ⏱️ ✅ L'unica locale già fatta (`RestTimer`).
  fineRecupero('fine_recupero', CanaleDellaNotifica.locale, null),

  /// 🏋️ ⛔ Il server non sa quando ti alleni: la scheda sta qui.
  promemoriaAllenamento(
    'promemoria_allenamento',
    CanaleDellaNotifica.locale,
    null,
  ),

  /// 🍎 ⛔ Il diario ha lasciato il server il 22/09.
  promemoriaDiario('promemoria_diario', CanaleDellaNotifica.locale, null),

  /// ⚖️ I progressi stanno sul telefono.
  promemoriaMisure('promemoria_misure', CanaleDellaNotifica.locale, null);

  const Notifica(this.valore, this.canale, this.destinazione);

  /// La stringa che viaggia nel campo `tipo`. ⚠️ Deve combaciare col backend.
  final String valore;

  final CanaleDellaNotifica canale;

  /// 🧭 **Dove porta, toccandola: un NOME, non un percorso** — 27/09/2026.
  ///
  /// 📌 Il committente: *«ci deve essere un altro parametro nelle notifiche: dove
  /// rimanda. Cioè a che pagina dell'app o a che url»*.
  ///
  /// 🔑 È un nome — `abbonamento`, `messaggi`, `casa` — e la traduzione in
  /// schermata la fa **l'app**, con l'elenco chiuso `_leDestinazioni` in
  /// `notifiche_push.dart`. ⛔ Se il server mandasse il percorso, chi lo
  /// controlla potrebbe far aprire all'app qualunque pagina cambiando una
  /// stringa in una notifica.
  ///
  /// ⚠️ **Lo stesso nome sta anche nell'enum PHP** (`Notifica::destinazione()`),
  /// e `test/catalogo_delle_notifiche_test.dart` pretende che coincidano: il
  /// server lo manda nel campo `dove`, e se i due divergessero una notifica
  /// porterebbe in un posto diverso da quello dichiarato.
  ///
  /// 💡 `null` per le locali: le programma l'app, che sa già dove sta.
  final String? destinazione;

  /// Quelle che la app programma da sé.
  static List<Notifica> get locali =>
      values.where((n) => n.canale == CanaleDellaNotifica.locale).toList();

  /// Quelle che arrivano dal server.
  static List<Notifica> get push =>
      values.where((n) => n.canale == CanaleDellaNotifica.push).toList();

  /// 🔎 La notifica con questo `tipo`, se è nel catalogo.
  ///
  /// ⛔ `null` per un tipo sconosciuto, ed è deliberato: una push con un tipo che
  /// non conosciamo **non deve portare da nessuna parte**. 🚨 Il server manda un
  /// nome, non un indirizzo.
  static Notifica? dalTipo(String? tipo) {
    if (tipo == null || tipo.isEmpty) return null;

    for (final n in values) {
      if (n.valore == tipo) return n;
    }

    return null;
  }
}
