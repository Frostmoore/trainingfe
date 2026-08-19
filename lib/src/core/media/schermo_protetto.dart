import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// `FLAG_SECURE`: schermate e registrazione bloccate dal sistema — N16.7.
///
/// ── 🚨 Cosa fa davvero, detto senza ottimismo ─────────────────────────────
///
/// Su Android il sistema **rifiuta** schermate e registrazione dello schermo, e
/// la finestra sparisce dall'anteprima delle app recenti.
///
/// ⚠️ **Non impedisce di fotografare lo schermo con un altro telefono**, e non
/// c'è niente che possa impedirlo. Non impedisce nemmeno che un programma
/// modificato sull'altro telefono tenga tutto: la cancellazione dipende dal
/// fatto che il client **obbedisca**.
///
/// 💡 È il motivo per cui l'interfaccia dice che l'usa e getta è una **cortesia,
/// non una garanzia**: promettere una sicurezza che non c'è è peggio che non
/// offrire la funzione, perché qualcuno manderebbe qualcosa che non avrebbe
/// mandato.
///
/// ── ⚠️ Su iOS non fa niente, e il nome non lo nasconde ────────────────────
///
/// iOS non ha nessun equivalente: si può solo **rilevare** che è stata fatta una
/// schermata, e avvisare chi ha mandato (N16.8, non ancora fatto). Le chiamate
/// qui sotto non lanciano: il canale non esiste e `MissingPluginException` viene
/// ingoiata, così la schermata di lettura funziona lo stesso.
class SchermoProtetto {
  const SchermoProtetto._();

  /// 🚨 Deve combaciare con `MainActivity.CANALE` lato Kotlin.
  static const _canale = MethodChannel('mytrainingcompanion/schermo_protetto');

  /// 🚨 **Va sempre accompagnata da [spegni]**, di solito in `dispose()`.
  ///
  /// ⚠️ Il flag sta sulla **finestra**, non sulla schermata: acceso e
  /// dimenticato resterebbe attivo su tutta l'app, e il sintomo — «non riesco
  /// più a fare schermate del diario» — non somiglierebbe mai alla sua causa.
  static Future<void> accendi() => _chiama('accendi');

  static Future<void> spegni() => _chiama('spegni');

  static Future<void> _chiama(String metodo) async {
    // 💡 Solo Android: altrove il canale non esiste e non c'è niente da fare.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    try {
      await _canale.invokeMethod<bool>(metodo);
    } on Object {
      /*
       * ⚠️ **Si tace di proposito.** Un canale mancante — build vecchia,
       * piattaforma diversa — non deve impedire di leggere un messaggio: la
       * protezione è un di più, il messaggio è la funzione.
       */
    }
  }
}
