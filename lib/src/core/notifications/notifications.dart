import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../tempo/fuso_del_dispositivo.dart';

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

  /*
   * 🚨 **Qui c'era `tz.getLocation(DateTime.now().timeZoneName)`, e non ha mai
   * funzionato.**
   *
   * `timeZoneName` restituisce l'**abbreviazione** (`CEST`), non un
   * identificativo IANA: `getLocation('CEST')` lancia sempre, il `catch`
   * inghiottiva, e l'app restava su UTC — non «se non si riesce a
   * determinarlo», come diceva il commento, ma **a ogni avvio**.
   *
   * ⚠️ Il danno era davvero contenuto — un recupero di 90 secondi dura 90
   * secondi in qualunque fuso — ed è proprio per questo che era sopravvissuto:
   * un difetto che non fa male non si cerca. Ma il ripiego silenzioso era
   * diventato **la strada normale**, e il commento diceva il contrario.
   */
  final fuso = await FusoDelDispositivo.leggi();

  if (fuso != null) {
    try {
      tz.setLocalLocation(tz.getLocation(fuso));
    } on Object catch (_) {
      // Resta UTC: un fuso che il pacchetto conosce e il database delle zone
      // no è possibile dopo un aggiornamento di sistema, e non vale un avvio
      // fallito.
    }
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
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final concesso = await android.requestNotificationsPermission();

      /*
       * 🚨 **NON si chiede il permesso per le sveglie esatte.**
       *
       * `requestExactAlarmsPermission()` non mostra un dialogo: apre la
       * schermata di sistema «Consenti impostazione di sveglie e promemoria»,
       * e da Android 14 quell'interruttore e' **grigio e non attivabile** per
       * le app che non sono sveglie o calendari. Il risultato e' che l'utente
       * viene buttato fuori dall'allenamento su una schermata dove non puo'
       * fare niente, e deve tornare indietro a mano — nel mezzo di una serie.
       *
       * Il recupero non ne ha bisogno: `RestTimer` prova a programmare una
       * notifica esatta **solo se il permesso c'e' gia'**, altrimenti ne
       * programma una inesatta. Su un recupero da 90 secondi con lo schermo
       * acceso la differenza non si nota; su uno a schermo spento la notifica
       * arriva con qualche secondo di ritardo, che e' incomparabilmente meglio
       * di un vicolo cieco.
       */

      return concesso ?? false;
    }

    final ios = plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  } on Object {
    return false;
  }
}
