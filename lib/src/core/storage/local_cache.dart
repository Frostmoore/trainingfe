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
  static Future<LocalCache> open() async => LocalCache(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  // ───────────────────────── chiavi ─────────────────────────

  static const _joinCode = 'gym.join_code';
  static const _branding = 'gym.branding';

  // ───────────────────────── palestra ─────────────────────────

  String? get joinCode => _prefs.getString(_joinCode);

  Future<void> setJoinCode(String code) => _prefs.setString(_joinCode, code);

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
  }

  // ───────────────────────── generico ─────────────────────────

  String? getString(String key) => _prefs.getString(key);

  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  Future<void> remove(String key) => _prefs.remove(key);
}
