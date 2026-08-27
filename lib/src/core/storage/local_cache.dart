import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// La cache locale non riservata — A1.4.
///
/// 🚨 **Qui NON va niente di segreto**: è un file in chiaro. Il token sta in
/// `TokenStore`, che usa il Keychain. Qui ci va quello che serve a far partire
/// l'app **senza schermata bianca**: il branding della palestra, il codice
/// d'invito, l'ultima giornata sfogliata.
///
/// Il valore di questa classe è tutto in una riga: al secondo avvio l'app si
/// apre già vestita dei colori giusti, e la richiesta di rete aggiorna dopo. Un
/// avvio che aspetta la rete per decidere di che colore essere mostra mezzo
/// secondo di bianco a ogni apertura, ed è la prima cosa che si nota.
class LocalCache {
  LocalCache(this._prefs);

  /// Va costruita in `bootstrap()`: `getInstance()` è asincrona, e farla
  /// aspettare al primo `build()` di un widget significa esattamente la
  /// schermata bianca che questa classe esiste per evitare.
  static Future<LocalCache> open() async =>
      LocalCache(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  // ───────────────────────── chiavi ─────────────────────────

  static const _joinCode = 'gym.join_code';
  static const _branding = 'gym.branding';
  static const _senzaPalestra = 'gym.senza_palestra';

  /// 🚪 «La schermata di benvenuto è stata superata» — 3b-J.1, 27/08/2026.
  ///
  /// ══ 🚨 PERCHÉ UNA CHIAVE SUA, E NON UNA DEDUZIONE ══════════════════════
  ///
  /// ⛔ Prima si deduceva: *«ha una palestra **o** ha detto di non averne»*.
  /// Funzionava perché tutti e due gli stati nascevano dalla stessa schermata —
  /// quella del codice, che non esiste più.
  ///
  /// 🚨 **E si è rotta subito**: adottando il branding che arriva col login,
  /// `senzaPalestra` torna `false` e `joinCode` non lo scrive più nessuno —
  /// quindi «la scelta è fatta» diventava **falsa dopo aver fatto l'accesso**,
  /// e il router rimandava al benvenuto chi era appena entrato.
  ///
  /// 💡 Adesso è un fatto suo: *«questa persona ha visto la porta d'ingresso»*.
  /// Non dipende da dove sta, e non cambia quando cambia la palestra.
  static const _sceltaFatta = 'gym.scelta_fatta';
  static const _ultimaPersona = 'sessione.ultima_persona';
  static const _accoglienzaFatta = 'sessione.accoglienza_fatta';
  static const _schedePortateGiu = 'schede.portate_giu';

  // ───────────────────────── chi c'era prima ─────────────────────────

  /// L'id dell'ultima persona che ha usato questo telefono — 13/08/2026.
  ///
  /// 🚨 **Serve a proteggere il telefono condiviso senza punire chi non lo
  /// condivide.** Prima l'archivio locale si svuotava a **ogni** logout, con la
  /// motivazione del telefono di famiglia o della tavoletta in reception: la
  /// preoccupazione è giusta, ma il momento era sbagliato — chi esce e rientra
  /// sul proprio telefono perdeva mesi di storico.
  ///
  /// 💡 Con questo id la stessa protezione scatta **quando entra qualcun
  /// altro**, che è il momento in cui serve davvero.
  ///
  /// ⚠️ È un id numerico e non un'email: qui non va niente di riservato (è un
  /// file in chiaro), e un id non dice a chi legge il telefono **chi** ci sia
  /// stato dentro.
  int? get ultimaPersona => _prefs.getInt(_ultimaPersona);

  Future<void> setUltimaPersona(int id) => _prefs.setInt(_ultimaPersona, id);

  Future<void> dimenticaUltimaPersona() => _prefs.remove(_ultimaPersona);

  // ───────────────────── l'accoglienza dopo l'accesso ─────────────────────

  /// A chi è già stata fatta la sequenza d'accoglienza, su questo telefono.
  ///
  /// ── 🚨 Perché per PERSONA e non un booleano solo ────────────────────
  ///
  /// Il telefono può essere di due persone — quello di casa, la tavoletta in
  /// reception — e la seconda deve vedersi offrire il ripristino e i consensi
  /// come la prima. ⚠️ Con un booleano unico, chi entra per secondo si
  /// ritroverebbe l'app che dà per scontate risposte che non ha mai dato.
  ///
  /// 💡 Un id numerico e non un'email: questo file è in chiaro, e un id non
  /// dice a chi legge il telefono **chi** ci sia stato dentro.
  bool accoglienzaFatta(int utenteId) =>
      (_prefs.getStringList(_accoglienzaFatta) ?? const []).contains(
        utenteId.toString(),
      );

  Future<void> segnaAccoglienzaFatta(int utenteId) async {
    final fatti =
        (_prefs.getStringList(_accoglienzaFatta) ?? const <String>[]).toSet()
          ..add(utenteId.toString());

    await _prefs.setStringList(_accoglienzaFatta, fatti.toList());
  }

  /// Se le schede che stavano sul server sono già scese — 3b-B.17.
  ///
  /// ⛔ **Una volta per telefono.** Dal 24/08 le schede vivono qui e basta: il
  /// server non è più una sorgente, e questa importazione esiste solo perché
  /// quelle che c'erano già non si buttano.
  ///
  /// ⚠️ Il segno si mette **dopo** che è andata a buon fine: metterlo prima
  /// vorrebbe dire che un'importazione fallita a metà non si ripete mai più, e
  /// le schede rimaste sul server sparirebbero per sempre.
  bool get schedePortateGiu => _prefs.getBool(_schedePortateGiu) ?? false;

  Future<void> segnaSchedePortateGiu() =>
      _prefs.setBool(_schedePortateGiu, true);

  // ───────────────────────── palestra ─────────────────────────

  String? get joinCode => _prefs.getString(_joinCode);

  Future<void> setJoinCode(String code) => _prefs.setString(_joinCode, code);

  /// 🚨 **«Ho scelto di non avere una palestra»** — F3, difetto del 13/08/2026.
  ///
  /// Serve perché «non ho una palestra» e «non ho ancora scelto» sono **due
  /// cose diverse**, e prima di questo flag l'app le confondeva: `hasGym`
  /// guardava solo il codice, quindi chi toccava «continuo senza palestra»
  /// restava indistinguibile da chi non aveva ancora deciso — e la regola 5 del
  /// router lo rimandava indietro alla schermata del codice.
  ///
  /// ⚠️ **Sta qui e non in memoria**: la scelta deve sopravvivere al riavvio.
  /// Tenuta solo nello stato, chi chiudeva l'app durante la registrazione si
  /// ritrovava di nuovo davanti al codice palestra.
  bool get senzaPalestra => _prefs.getBool(_senzaPalestra) ?? false;

  /// ⚠️ **Il ripiego non è `false`**: chi aveva già l'app installata non ha
  /// questa chiave, e mandarlo alla schermata di benvenuto sarebbe farlo
  /// ripartire da capo. 💡 Per lui vale la vecchia deduzione — se aveva scelto,
  /// una delle due chiavi c'è.
  bool sceltaFatta({required bool oppure}) =>
      _prefs.getBool(_sceltaFatta) ?? oppure;

  Future<void> setSceltaFatta() => _prefs.setBool(_sceltaFatta, true);

  Future<void> setSenzaPalestra(bool valore) =>
      _prefs.setBool(_senzaPalestra, valore);

  /// Il branding così com'è arrivato dal backend.
  ///
  /// Si conserva la mappa grezza e non un oggetto già costruito: se un giorno
  /// il backend aggiunge un campo, una cache vecchia continua a funzionare
  /// invece di far fallire la deserializzazione all'avvio — cioè nel momento in
  /// cui l'utente non ha nessun modo di rimediare.
  Map<String, dynamic>? get branding {
    final raw = _prefs.getString(_branding);

    if (raw == null) return null;

    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } on FormatException {
      // Cache corrotta: si butta invece di far esplodere l'avvio.
      unawaited(_prefs.remove(_branding));

      return null;
    }
  }

  Future<void> setBranding(Map<String, dynamic> value) =>
      _prefs.setString(_branding, jsonEncode(value));

  /// Dimentica la palestra: si usa al «cambia palestra», non al logout.
  ///
  /// Al logout il branding resta apposta — chi esce e rientra vuole ritrovare
  /// la propria palestra, non ridigitare il codice.
  Future<void> forgetGym() async {
    await _prefs.remove(_joinCode);
    await _prefs.remove(_branding);

    // ⚠️ **Anche la scelta «senza palestra» si dimentica.** «Cambia palestra»
    // deve riportare alla domanda, non a metà: chi era senza palestra e tocca
    // «cambia» sta dicendo che vuole ridecidere.
    await _prefs.remove(_senzaPalestra);
  }

  // ───────────────────────── generico ─────────────────────────

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  /// 🚨 **Torna `null` quando la chiave non c'e', e non `false`** — 22/08/2026.
  ///
  /// ⚠️ Un interruttore assente e un interruttore spento sono **due cose
  /// diverse**, e schiacciarle su `false` qui vorrebbe dire che nessuna
  /// preferenza puo' avere il default acceso: chi non l'ha mai toccata se la
  /// ritroverebbe spenta, con un numero piu' basso e nessun errore da nessuna
  /// parte. ⛔ Il valore di ripiego lo decide chi chiama, che sa cosa
  /// significa.
  bool? getBool(String key) => _prefs.getBool(key);

  Future<void> setBool(String key, {required bool value}) =>
      _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}
