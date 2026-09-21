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

/// 🧭 **Dove porta il tocco su una notifica** — 24/09/2026.
///
/// I `data` li scrive il server (`PushSender::toUser`), e sono stringhe:
///
/// | `data` | Destinazione |
/// |---|---|
/// | `tipo: promozione`, `codice` | l'offerta, in cima a «Offerte per te» |
/// | `conversation_id` | la chat |
/// | altro | niente: si resta dove si apre l'app |
///
/// 💡 Una funzione pura, e non un pezzo di `NotifichePush`, perché si possa
/// provare senza Firebase.
String? destinazioneDellaNotifica(Map<String, dynamic> dati) {
  final codice = dati['codice']?.toString() ?? '';

  if (dati['tipo'] == 'promozione' && codice.isNotEmpty) {
    return AppRoutes.offertaDaMostrare(codice);
  }

  if ((dati['conversation_id']?.toString() ?? '').isNotEmpty) {
    return AppRoutes.chat;
  }

  return null;
}
