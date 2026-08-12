import 'package:flutter_timezone/flutter_timezone.dart';

/// Il fuso orario del telefono, come identificativo **IANA** (`Europe/Rome`).
///
/// ── 🚨 Perché serve un pacchetto ──────────────────────────────────────────
///
/// Dart da solo non lo sa dare. `DateTime.now().timeZoneName` restituisce
/// l'**abbreviazione** — `CEST`, e su certi Android addirittura `GMT+02:00` —
/// che non è un fuso ma un offset. E da un offset non si risale a un fuso:
/// `+02:00` d'estate è Roma, d'inverno è Helsinki, e nessuno dei due segue le
/// stesse date di cambio ora.
///
/// ⚠️ È il difetto che stava già in `notifications.dart`, dove
/// `tz.getLocation(DateTime.now().timeZoneName)` lanciava a ogni avvio e il
/// `catch` lasciava l'app su UTC — in silenzio, come previsto dal commento, ma
/// **sempre**, non «se non si riesce a determinarlo».
///
/// ── ⚠️ Non lancia mai ─────────────────────────────────────────────────────
///
/// Chi la chiama sta facendo altro — avviare l'app, sincronizzare il profilo —
/// e non ha niente di sensato da fare con un errore. Su un dispositivo che non
/// risponde si resta con `null` e si va avanti: il server ha comunque la sua
/// catena di ripiego (`tenants.timezone` → `app.display_timezone`).
class FusoDelDispositivo {
  const FusoDelDispositivo._();

  /// L'ultimo valore letto, per non ripagare il salto verso la piattaforma.
  ///
  /// 💡 Il fuso di un telefono cambia raramente e non a sorpresa: chi atterra
  /// da un volo riapre l'app, e a quel punto `main()` lo rilegge.
  static String? _memoria;

  static Future<String?> leggi() async {
    if (_memoria != null) return _memoria;

    try {
      final zona = await FlutterTimezone.getLocalTimezone();
      final nome = zona.identifier;

      // ⚠️ Una stringa vuota passerebbe la validazione `required` del server
      // solo per farsi rifiutare dall'elenco IANA: meglio non mandarla.
      return _memoria = nome.isEmpty ? null : nome;
    } on Object {
      return null;
    }
  }

  /// Solo per i test: dimentica il valore memorizzato.
  static void dimentica() => _memoria = null;
}
