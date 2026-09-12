/// 💳 **Chi paga l'abbonamento di questa persona** — 3b-AH.4, 12/09/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// Il committente: *«un utente iscritto alla palestra o a un trainer non può
/// vedere il toggle di rinnovo automatico perché non dipende da lui, e la modale
/// per lui deve dire che non è più abbonato **perché non è più abbonato il suo
/// trainer o la sua palestra**»*.
///
/// ══ ⛔ COSA DICEVA PRIMA, E PERCHE' ERA FALSO ═════════════════════════════
///
/// La modale «il tuo abbonamento è scaduto» diceva a tutti la stessa frase:
/// *«il rinnovo automatico era spento, quindi non abbiamo addebitato niente»*.
///
/// 🚨 A un iscritto di palestra è **falso due volte**: non ha spento niente, e
/// non ha mai pagato niente. ⛔ Gli fa cercare un'impostazione che non ha, e gli
/// nasconde l'unica cosa utile — parlarne con la palestra.
///
/// ══ 🚨 NON SI DEDUCE, SI LEGGE ════════════════════════════════════════════
///
/// ⚠️ L'app il tipo di spazio ce l'ha, e potrebbe dedurlo. ⛔ Sarebbe la stessa
/// informazione dedotta due volte, e le due deduzioni divergono al primo caso
/// nuovo: da `AH.1` lo spazio di un trainer è «personale» come quello di un
/// utente singolo, e dedurlo dal tipo direbbe «trainer» a chi paga per sé.
///
/// 💡 Lo dice il server, in un campo solo, calcolato in un posto solo
/// (`PianoAttivo::chiPaga()`).
enum ChiPaga {
  /// Lo spazio è suo: utente singolo, trainer indipendente, o l'amministratore
  /// di una palestra.
  io,

  /// Sta dentro una palestra che non è sua.
  palestra,

  /// Sta dentro lo spazio di un'altra **persona**: l'allievo di un trainer.
  trainer;

  /// ⚠️ **Il ripiego è [io], e la direzione è voluta.**
  ///
  /// A chi paga davvero si mostra un pulsante in più; il contrario direbbe a
  /// qualcuno di parlare con una palestra che non ha. 💡 Fra due difetti si
  /// prende quello che confonde meno.
  static ChiPaga daStringa(String? valore) => switch (valore) {
    'palestra' => ChiPaga.palestra,
    'trainer' => ChiPaga.trainer,
    _ => ChiPaga.io,
  };

  /// Se l'abbonamento **non** dipende da questa persona.
  bool get lopagaQualcunAltro => this != ChiPaga.io;

  /// Come si chiama chi paga, per scriverlo in una frase.
  String get nome => switch (this) {
    ChiPaga.palestra => 'la tua palestra',
    ChiPaga.trainer => 'il tuo trainer',
    ChiPaga.io => 'tu',
  };
}
