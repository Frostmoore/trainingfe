import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../api/api_client.dart';
import '../providers.dart';
import '../router/app_router.dart';

/// 🔔 **Le notifiche push, dall'arrivo al tocco** — 24/09/2026.
///
/// 📌 Il committente: *«il tocco su una notifica deve aprire l'offerta»*, e poi
/// *«mettimi nei da fare che bisogna impostare firebase sia per android che per
/// apple dopo che abbiamo il dominio. Per adesso predisponi tutto il codice
/// necessario»*.
///
/// ══ ⚠️ PREDISPOSTO, E SPENTO ══════════════════════════════════════════════
///
/// Senza `android/app/google-services.json` (Android) o `GoogleService-Info.plist`
/// + APNs (iOS) `Firebase.initializeApp()` fallisce: qui lo si **prende**, e
/// l'app funziona come prima — nessun token registrato, nessuna notifica. Il
/// giorno che i file ci sono, parte tutto da solo.
///
/// ══ 🧭 IL GIRO ═════════════════════════════════════════════════════════════
///
/// | Momento | Cosa succede |
/// |---|---|
/// | accesso fatto | il token del telefono va al server (`POST /device-tokens`) |
/// | token rinnovato da Firebase | lo stesso, col token nuovo |
/// | uscita | il token si toglie **prima** (`DELETE /device-tokens`): ⛔ altrimenti le notifiche di chi è uscito arriverebbero a chi entra dopo sullo stesso telefono |
/// | notifica con l'app chiusa o in background | la mostra il sistema; al tocco si apre la pagina giusta |
/// | notifica con l'app aperta | il sistema non la mostra: la mostriamo noi (notifica locale), col suo tocco |
///
/// Dove porta il tocco lo decide [destinazioneDellaNotifica], che si prova da
/// sola.
class NotifichePush {
  NotifichePush._();

  static bool _acceso = false;
  static String? _ultimoToken;

  /// Firebase è partito? Falso finché mancano i file di configurazione.
  static bool get acceso => _acceso;

  /// Da chiamare una volta, dopo aver creato il `container` e prima di `runApp`.
  static Future<void> avvia(ProviderContainer container) async {
    try {
      await Firebase.initializeApp();
    } on Object catch (errore) {
      // ⚠️ Il caso normale oggi: Firebase non è ancora configurato (DA-FARE).
      if (kDebugMode) debugPrint('Notifiche push spente: $errore');

      return;
    }

    _acceso = true;
    final messaggi = FirebaseMessaging.instance;

    // 👆 Il tocco su una notifica di sistema (app in background, o chiusa).
    FirebaseMessaging.onMessageOpenedApp.listen(
      (m) => _apri(container, m.data),
    );

    /*
     * ⚠️ L'app **aperta dal tocco** (era chiusa): si aspetta il primo frame, o
     * il router non è ancora montato e la destinazione andrebbe persa.
     */
    final iniziale = await messaggi.getInitialMessage();

    if (iniziale != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _apri(container, iniziale.data),
      );
    }

    // 📲 Con l'app aperta il sistema non mostra niente: la mostriamo noi.
    FirebaseMessaging.onMessage.listen(_mostraInPrimoPiano);
    await _preparaLeNotificheLocali(container);

    // 🔑 Il token al server, a ogni accesso e a ogni rinnovo.
    messaggi.onTokenRefresh.listen((token) => _registra(container, token));

    container.listen<AuthState>(authControllerProvider, (prima, adesso) {
      if (adesso.status == AuthStatus.loggedIn &&
          prima?.status != AuthStatus.loggedIn) {
        _registraIlTokenAttuale(container);
      }
    }, fireImmediately: true);
  }

  /// ⛔ **Prima di uscire**: toglie il token dal server. Chiamata da
  /// `AuthController.logout()` finché la sessione vale ancora.
  static Future<void> dimenticaIlDispositivo(ApiClient api) async {
    final token = _ultimoToken;

    if (!_acceso || token == null) return;

    try {
      await api.delete('/device-tokens', body: {'token': token});
    } on Object {
      // Silenzio voluto: l'uscita non si ferma per questo.
    }

    _ultimoToken = null;
  }

  static Future<void> _registraIlTokenAttuale(
    ProviderContainer container,
  ) async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();

      if (token != null) await _registra(container, token);
    } on Object catch (errore) {
      if (kDebugMode) debugPrint('Token push non registrato: $errore');
    }
  }

  static Future<void> _registra(
    ProviderContainer container,
    String token,
  ) async {
    if (container.read(authControllerProvider).status != AuthStatus.loggedIn) {
      return;
    }

    try {
      await container
          .read(apiClientProvider)
          .post<dynamic>(
            '/device-tokens',
            body: {
              'token': token,
              'platform': Platform.isIOS ? 'ios' : 'android',
            },
          );
      _ultimoToken = token;
    } on Object catch (errore) {
      if (kDebugMode) debugPrint('Token push rifiutato: $errore');
    }
  }

  static const _canale = AndroidNotificationDetails(
    'avvisi',
    'Avvisi',
    channelDescription: 'Offerte, regali e messaggi',
    importance: Importance.high,
    priority: Priority.high,

    /*
     * 🆕 🔔 **La stessa icona delle notifiche di sistema** — 26/09/2026.
     *
     * ⚠️ Questa è la notifica che mostriamo **noi**, quando l'app è aperta.
     * ⛔ Senza questa riga userebbe l'icona dell'app, che Android riduce a
     * sagoma piena — il cerchio bianco. 🚨 E si sarebbe visto **solo con
     * l'app in primo piano**: il caso che si prova per ultimo, quando si
     * crede di aver già finito.
     */
    icon: 'ic_notifica',
    /*
     * 🎨 **Lo stesso `colore_notifica` di `res/values/colors.xml`** — il verde
     * petrolio del marchio.
     *
     * ⚠️ Vanno tenuti uguali a mano: questo vale per le notifiche che mostra
     * l'app con sé stessa aperta, quello per le notifiche che disegna Android
     * quando l'app è chiusa. ⛔ Se divergono, la **stessa** notifica cambia
     * colore a seconda di dove ti trova — e sembra un difetto a caso.
     *
     * 📌 Era l'oro `0xFFC9A227`, cambiato il 26/09: *«il cerchio intorno è
     * tipo marroncino»*.
     */
    color: Color(0xFF0F766E),
  );

  static Future<void> _mostraInPrimoPiano(RemoteMessage messaggio) async {
    final notifica = messaggio.notification;

    if (notifica == null) return;

    await FlutterLocalNotificationsPlugin().show(
      messaggio.hashCode,
      notifica.title,
      notifica.body,
      const NotificationDetails(
        android: _canale,
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(messaggio.data),
    );
  }

  /// 👆 Il tocco sulle notifiche **locali** — quelle che mostriamo noi con
  /// l'app aperta. ⚠️ Si reinizializza il plugin con la richiamata: il resto
  /// delle impostazioni è lo stesso di `initNotifications()`.
  static Future<void> _preparaLeNotificheLocali(
    ProviderContainer container,
  ) async {
    const impostazioni = InitializationSettings(
      /*
       * ⚠️ Qui resta l'icona dell'app, ed è giusto: questa è solo l'icona di
       * **ripiego** del plugin. 💡 Quella che conta la sceglie `_canale`
       * (`ic_notifica`), e la usa per ogni notifica che mostriamo noi.
       */
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await FlutterLocalNotificationsPlugin().initialize(
      impostazioni,
      onDidReceiveNotificationResponse: (risposta) {
        final dati = _leggi(risposta.payload);

        if (dati != null) _apri(container, dati);
      },
    );
  }

  static Map<String, dynamic>? _leggi(String? payload) {
    if (payload == null || payload.isEmpty) return null;

    try {
      final dati = jsonDecode(payload);

      return dati is Map<String, dynamic> ? dati : null;
    } on Object {
      return null;
    }
  }

  static void _apri(ProviderContainer container, Map<String, dynamic> dati) {
    final dove = destinazioneDellaNotifica(dati);

    if (dove != null) container.read(routerProvider).go(dove);
  }
}

/// 🧭 **Dove porta il tocco su una notifica** — 24/09/2026, allargata il
/// 26/09.
///
/// I `data` li scrive il server (`PushSender::toUser`), e sono stringhe:
///
/// | `data` | Destinazione |
/// |---|---|
/// | `tipo: promozione`, `codice` | l'offerta, in cima a «Offerte per te» |
/// | `conversation_id` | la chat |
/// | 🆕 `tipo: avviso` | la **casa**: l'avviso è una modale, e compare da sé |
/// | 🆕 `tipo` fra le **sezioni note** | quella sezione (vedi `_leSezioni`) |
/// | altro | niente: si resta dove si apre l'app |
///
/// ══ 🚨 IL DIFETTO CHE C'ERA, E NON SI POTEVA VEDERE ════════════════
///
/// ⛔ `MandaLAvvisoInPush` (B4) manda `tipo: avviso` dal 24/09, e il suo
/// commento dice *«toccando la notifica l'app sa quale modale aprire»*. 🚨 Non
/// era vero: qui `avviso` non era gestito, e il tocco non faceva **niente**.
///
/// ⚠️ Non si vedeva perché le push non partivano (Firebase non c'era): il
/// sintomo del difetto — «non succede niente» — era **identico** al sintomo
/// atteso. 💡 È venuto fuori il 26/09, il giorno che le push si sono accese.
///
/// ══ ⛔ PERCHE' NON SI ACCETTA UN PERCORSO QUALUNQUE ══════════════════
///
/// 🚨 Sarebbe comodo un campo `rotta` che l'app apre e basta. ⛔ Ma quello
/// che arriva in una notifica è **testo che viene da fuori**, e aprire un
/// percorso arbitrario vuol dire far navigare l'app dove dice il messaggio.
/// 💡 Qui le destinazioni sono **dichiarate**: quello che non è in elenco non
/// porta da nessuna parte.
///
/// 💡 Una funzione pura, e non un pezzo di `NotifichePush`, perché si possa
/// provare senza Firebase.
String? destinazioneDellaNotifica(Map<String, dynamic> dati) {
  final codice = dati['codice']?.toString() ?? '';
  final tipo = dati['tipo']?.toString() ?? '';

  if (tipo == 'promozione' && codice.isNotEmpty) {
    return AppRoutes.offertaDaMostrare(codice);
  }

  if ((dati['conversation_id']?.toString() ?? '').isNotEmpty) {
    return AppRoutes.chat;
  }

  /*
   * 🆕 📣 **Un avviso porta a casa** — 26/09/2026.
   *
   * ⚠️ Non c'è una pagina «avviso» da aprire: l'avviso è una **modale**, e la
   * mostra `AvvisoAllApertura` non appena l'app torna in primo piano — che è
   * esattamente quello che succede toccando la notifica.
   *
   * 💡 Quindi si porta alla casa e si lascia fare a lei: ⛔ aprire la modale
   * da qui vorrebbe dire due strade per la stessa cosa, e due strade che si
   * accavallano fanno comparire la finestra due volte.
   */
  if (tipo == 'avviso') return AppRoutes.home;

  return _leSezioni[tipo];
}

/// 🗺️ **Le sezioni dove una notifica può portare** — 26/09/2026.
///
/// 🔑 **Un elenco chiuso, e non un percorso libero**: il server manda un
/// nome, non un indirizzo. ⛔ Così una notifica non può far aprire all'app una
/// pagina qualunque, e chi aggiunge una destinazione deve passare **da qui** —
/// cioè da un posto dove qualcuno la legge.
///
/// ⚠️ Sono le sezioni della barra, quelle che esistono sempre: una notifica
/// che porta a una schermata di dettaglio dovrebbe portarsi dietro anche il
/// **suo** identificativo, e allora non basta un nome.
const Map<String, String> _leSezioni = {
  'allenamenti': AppRoutes.training,
  'diario': AppRoutes.diary,
  'progressi': AppRoutes.progress,
  'messaggi': AppRoutes.chat,
  'profilo': AppRoutes.profile,
};
