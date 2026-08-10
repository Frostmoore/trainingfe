import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// L'avvio delle notifiche locali — C9.3.
///
/// 🚨 **Va chiamato in `main()`, prima di disegnare.** `tz.local` senza
/// `initializeTimeZones()` lancia `LocationNotFoundException`, e lo fa alla
/// **prima serie registrata** — cioè dentro il player, in palestra, non
/// all'avvio dove si noterebbe subito.
///
/// ⚠️ Il permesso NON si chiede qui. Chiederlo all'avvio, prima che l'utente
/// abbia capito a cosa serve, è il modo più rapido per farselo negare per
/// sempre: si chiede la prima volta che parte un recupero, dove il motivo è
/// evidente.
Future<void> initNotifications() async {
  tzdata.initializeTimeZones();

  try {
    // Il fuso del telefono. Se non si riesce a determinarlo si resta su UTC:
    // un recupero di 90 secondi dura 90 secondi in qualunque fuso, quindi il
    // danno è nullo — a differenza di un'eccezione all'avvio.
    tz.setLocalLocation(tz.getLocation(DateTime.now().timeZoneName));
  } on Object catch (_) {
    // Silenzio voluto: vedi sopra.
  }

  const impostazioni = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      // Tutti e tre `false`: il permesso si chiede dopo, al momento giusto.
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  );

  try {
    await FlutterLocalNotificationsPlugin().initialize(impostazioni);
  } on Object catch (errore) {
    // Un'app che non parte perché le notifiche non si inizializzano sarebbe
    // sproporzionata: il timer funziona lo stesso in primo piano.
    if (kDebugMode) debugPrint('Notifiche non inizializzate: $errore');
  }
}

/// Chiede il permesso, la prima volta che serve davvero.
///
/// Restituisce `false` anche quando l'utente ha detto no: il chiamante deve
/// funzionare lo stesso, solo senza avviso a schermo spento.
Future<bool> requestNotificationPermission() async {
  final plugin = FlutterLocalNotificationsPlugin();

  try {
    final android = plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (android != null) {
      final concesso = await android.requestNotificationsPermission();

      // ⚠️ Su Android 13+ servono **due** permessi: notificare e programmare
      // una sveglia esatta. Senza il secondo la notifica arriva quando capita
      // al sistema, che per un recupero di 90 secondi vuol dire in ritardo.
      await android.requestExactAlarmsPermission();

      return concesso ?? false;
    }

    final ios = plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();

    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  } on Object {
    return false;
  }
}
