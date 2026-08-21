import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Chi è questa copia dell'app — FASE 10.2.
///
/// ══ 🚨 SI CONFRONTA UN INTERO, NON UNA STRINGA ════════════════════════════
///
/// `X-App-Build` è il `versionCode`: **74500**, non `'7.45.0'`.
///
/// ⚠️ Confrontando le stringhe, `7.10.0` risulta **minore** di `7.9.0`, perché
/// `'1' < '9'`. 🚨 È la trappola classica, e non si vede finché non si arriva
/// alla decima versione minore — cioè fra mesi, quando nessuno collegherà più
/// «gli utenti vengono bloccati a caso» a una riga scritta oggi.
///
/// 💡 `X-App-Version` si manda lo stesso, ma **solo perché finisca nei log del
/// server leggibile da un umano**: nessuno ci prende decisioni.
///
/// ── ⚠️ Si legge una volta sola ────────────────────────────────────────────
///
/// `PackageInfo.fromPlatform()` passa da un canale di piattaforma, e farlo a
/// ogni richiesta HTTP vorrebbe dire un salto verso Android per ogni chiamata.
/// Il numero non cambia mentre l'app è aperta: cambia solo aggiornandola, e per
/// aggiornarla bisogna chiuderla.
class IdentitaApp {
  const IdentitaApp._();

  static Map<String, String>? _cache;

  /// Le intestazioni da mettere su ogni richiesta.
  ///
  /// 💡 Torna una mappa vuota se qualcosa va storto: **non deve poter impedire
  /// una richiesta**. ⚠️ E il server tratta «senza intestazione» come «passa»
  /// (vedi `VersioneMinima`), quindi il ripiego è dalla parte giusta — al
  /// peggio quella copia non è riconoscibile, non è bloccata per sbaglio.
  static Future<Map<String, String>> intestazioni() async {
    if (_cache != null) return _cache!;

    try {
      final info = await PackageInfo.fromPlatform();

      return _cache = {
        'X-App-Build': info.buildNumber,
        'X-App-Version': info.version,
        'X-App-Platform': Platform.isIOS ? 'ios' : 'android',
      };
    } on Object catch (e) {
      debugPrint('IdentitaApp: non si legge la versione — $e');

      return _cache = const {};
    }
  }

  /// 💡 Solo per i test: fa dimenticare quello che ha letto.
  @visibleForTesting
  static void dimentica() => _cache = null;
}
