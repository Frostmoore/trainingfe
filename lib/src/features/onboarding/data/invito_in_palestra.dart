import 'gym_branding.dart';

/// Quello che c'è dietro un link d'invito — 3b-V.2.
///
/// 📌 *«a chi ci clicca si deve aprire l'app in una pagina con la descrizione
/// della palestra, il logo, i colori, un messaggio di congratulazioni, le cose
/// a cui avrà accesso e due tasti, uno per accettare e uno per rifiutare»*.
///
/// ── 🚨 `cosaOttieni` arriva dal SERVER, e non si scrive qui ───────────────
///
/// ⛔ Un elenco scritto nell'app sarebbe **una promessa che l'app fa a nome
/// della palestra**, e diventerebbe falsa il giorno che quella palestra cambia
/// piano — senza che nessuno se ne accorga, perché non è collegata a niente.
///
/// ⚠️ Il caso concreto: una palestra senza AI. L'app scriverebbe comunque
/// «consigli con l'intelligenza artificiale», la persona entrerebbe, cercherebbe
/// quella funzione e non la troverebbe. 🚨 **Una promessa non mantenuta al primo
/// minuto è peggio di non averla fatta.**
class InvitoInPalestra {
  const InvitoInPalestra({
    required this.palestra,
    required this.cosaOttieni,
    this.descrizione,
    this.scadeIl,
    this.daTrainer = false,
    this.immagineTestata,
    this.indirizzo,
    this.mappa,
  });

  /// 🚨 **Tollerante come [GymBranding]**: questa risposta arriva a un'app che
  /// può essere più vecchia del server. Un campo nuovo che non si sa leggere
  /// non deve impedire di mostrare l'invito — che è l'unica cosa che quella
  /// persona sta cercando di fare.
  factory InvitoInPalestra.fromJson(Map<String, dynamic> json) {
    final palestra = json['palestra'] is Map
        ? (json['palestra'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    return InvitoInPalestra(
      palestra: GymBranding.fromJson(palestra),
      descrizione: json['descrizione']?.toString(),
      cosaOttieni: ((json['cosa_ottieni'] as List?) ?? const [])
          .whereType<Map<Object?, Object?>>()
          .map((e) => VantaggioInPalestra.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      scadeIl: DateTime.tryParse(json['scade_il']?.toString() ?? ''),
      daTrainer: json['ruolo'] == 'trainer',

      /*
       * 🆕 🖼️ 📍 F6.2 — testata, indirizzo e mappa. 💡 Un server vecchio non
       * li manda: restano `null`, e la pagina si disegna come prima.
       */
      immagineTestata: _testoOppureNull(json['immagine_testata']),
      indirizzo: _testoOppureNull(json['indirizzo']),
      mappa: _testoOppureNull(json['mappa']),
    );
  }

  final GymBranding palestra;

  /// Quello che la palestra ha scritto su di sé, nel catalogo. Può mancare.
  final String? descrizione;

  final List<VantaggioInPalestra> cosaOttieni;

  final DateTime? scadeIl;

  /// 🆕 🖼️ **L'immagine di testata della palestra** — F6.2 (A2).
  ///
  /// 📌 *«mettiamoci anche un'immagine di testata (si dovrà vedere
  /// nell'app)»*. ⚠️ È qui che si vede: il catalogo non esiste ancora, e
  /// l'invito è il primo posto in cui una persona incontra la palestra.
  final String? immagineTestata;

  /// 🆕 📍 **L'indirizzo per esteso** — F6.2 (A3). «Via Roma, 12 · 01036 Nepi
  /// (VT)». Lo compone il server: città e provincia vengono dal comune.
  final String? indirizzo;

  /// 🆕 🗺️ **Dove aprire le mappe.** ⚠️ Lo manda il server già pronto, così
  /// l'app non deve sapere come si costruisce un link di Google Maps.
  final String? mappa;

  /// 🆕 **L'invito è per allenare, non per iscriversi** — giro del 18/09/2026.
  ///
  /// ⛔ Senza, la conferma diceva a un trainer *«la palestra copre il tuo
  /// abbonamento, e ti vesti dei suoi colori»*: false tutte e due. 💡 Un
  /// server vecchio non manda `ruolo`, e allora vale «iscritto», com'era.
  final bool daTrainer;
}

/// Una riga dell'elenco «cosa ottieni».
class VantaggioInPalestra {
  const VantaggioInPalestra({
    required this.icona,
    required this.titolo,
    required this.dettaglio,
  });

  factory VantaggioInPalestra.fromJson(Map<String, dynamic> json) =>
      VantaggioInPalestra(
        icona: json['icona']?.toString() ?? '',
        titolo: json['titolo']?.toString() ?? '',
        dettaglio: json['dettaglio']?.toString() ?? '',
      );

  /// 💡 **Un nome, non un `IconData`.** Il server non può mandare un'icona di
  /// Flutter, e non deve: manda una parola, e l'app la traduce in un disegno.
  /// ⚠️ Se un giorno il server ne manda una che questa versione non conosce, si
  /// disegna quella di riserva invece di lasciare un buco.
  final String icona;

  final String titolo;
  final String dettaglio;
}

/// 💡 Una stringa vuota vale quanto un campo che manca: il server la manda
/// vuota quando la palestra non ha compilato il campo, e un `Text('')` lascerebbe
/// un buco a forma di riga.
String? _testoOppureNull(Object? valore) {
  final testo = valore?.toString().trim();

  return (testo == null || testo.isEmpty) ? null : testo;
}
