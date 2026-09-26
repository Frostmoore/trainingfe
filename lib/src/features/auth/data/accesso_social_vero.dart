import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'social_sign_in.dart';

/// 🔑 **Chi ottiene il token dal sistema operativo** — voce 25, 26/09/2026.
///
/// Prende il posto di `_NonInstallato` in [SocialSignIn.instance]. ⚠️ La firma
/// non è cambiata: tutto il resto — i pulsanti, il controller, il server —
/// esisteva già ed è rimasto dov'era.
///
/// ══ 🧭 COSA FA, IN DUE RIGHE ════════════════════════════════════════════════
///
/// Chiede al fornitore un **token d'identità** (un JWT firmato) e lo passa al
/// server, che lo verifica contro le chiavi pubbliche di Google/Apple. ⛔ L'app
/// **non** decide chi sei: trasporta soltanto una dichiarazione firmata.
///
/// ══ ⚖️ APPLE SOLO SU iOS — decisione del committente, 26/09 ═════════════════
///
/// 📌 *«Apple solo su iOS»*. ⚠️ L'accesso con Apple **nativo** esiste solo sui
/// sistemi Apple: su Android passerebbe da un flusso web con un Services ID e
/// un indirizzo di ritorno sul server, cioè molto più lavoro.
/// ⚖️ Apple obbliga a offrirlo **dove offri altri accessi social su iOS**; su
/// Android non obbliga nessuno.
///
/// 🔑 Il pulsante su Android non compare (ci pensa `SocialButtons`), ma qui c'è
/// comunque un controllo: ⛔ un errore chiaro è meglio di una finestra di
/// sistema che non si apre e non dice perché.
class AccessoSocialVero implements SocialSignIn {
  AccessoSocialVero({required this.serverClientId});

  /// 🚨 **L'ID client *web* del progetto Google**, non quello Android.
  ///
  /// ⚠️ È lui a finire nel campo `aud` del token, ed è quello che il server
  /// confronta con `SOCIAL_GOOGLE_CLIENT_IDS`. ⛔ Passare l'ID Android farebbe
  /// arrivare al server un token che rifiuta, con un messaggio che parla di
  /// destinatario sbagliato e non fa capire da dove venga.
  final String serverClientId;

  bool _googleAvviato = false;

  @override
  Future<SocialCredential?> accedi(String provider) => switch (provider) {
    SocialProviderId.google => _conGoogle(),
    SocialProviderId.apple => _conApple(),
    _ => throw AccessoSocialFallito('Fornitore sconosciuto: $provider'),
  };

  // ───────────────────────────── Google ─────────────────────────────

  Future<SocialCredential?> _conGoogle() async {
    /*
     * ⚠️ `initialize()` una volta sola, e **non** nel costruttore: è una
     * chiamata al canale nativo, e farla all'avvio dell'app la rallenterebbe
     * per una funzione che magari nessuno usa.
     */
    if (!_googleAvviato) {
      await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
      _googleAvviato = true;
    }

    try {
      final conto = await GoogleSignIn.instance.authenticate();
      final token = conto.authentication.idToken;

      /*
       * 🚨 Un conto senza `idToken` **è** un difetto di configurazione, non un
       * caso limite: succede quando `serverClientId` non è un ID di tipo *web*.
       * ⛔ Restituire `null` qui sembrerebbe un annullamento dell'utente.
       */
      if (token == null || token.isEmpty) {
        throw const AccessoSocialFallito(
          'Google non ha restituito un token d\'identità. '
          'Di solito vuol dire che l\'ID client configurato non è di tipo web.',
        );
      }

      return SocialCredential(
        provider: SocialProviderId.google,
        idToken: token,
      );
    } on GoogleSignInException catch (errore) {
      // 🚨 «Ho cambiato idea» non è un errore, e non va mostrato come tale.
      if (errore.code == GoogleSignInExceptionCode.canceled) return null;

      throw AccessoSocialFallito(spiegaIlRifiutoDiGoogle(errore.code));
    }
  }

  /// 🚨 **Traduce l'errore più frequente e più muto di questa funzione.**
  ///
  /// ⛔ Su Android, se l'impronta della chiave di firma non è registrata nella
  /// console di Google, l'accesso fallisce con `ApiException: 10`
  /// (`DEVELOPER_ERROR`) — un numero che non dice niente e manda a cercare il
  /// difetto nel codice, dove non c'è. 💡 Qui diventa una frase che dice cosa
  /// è successo.
  ///
  /// 💡 Pubblica e statica **apposta**: è l'unica parte di questa classe che si
  /// può provare senza un dispositivo e senza le console di Google.
  @visibleForTesting
  static String spiegaIlRifiutoDiGoogle(GoogleSignInExceptionCode codice) =>
      switch (codice) {
        GoogleSignInExceptionCode.clientConfigurationError =>
          'L\'app non è registrata correttamente presso Google. Di solito '
              'manca l\'impronta SHA-1 della chiave di firma fra le credenziali '
              'del progetto.',
        GoogleSignInExceptionCode.providerConfigurationError =>
          'Il progetto Google non è configurato per l\'accesso.',
        GoogleSignInExceptionCode.uiUnavailable =>
          'Google non è riuscito ad aprire la finestra di accesso su questo '
              'dispositivo.',
        GoogleSignInExceptionCode.canceled =>
          'Accesso annullato.', // ⚠️ non dovrebbe arrivare qui: vedi _conGoogle
        _ => 'Google ha rifiutato l\'accesso (${codice.name}).',
      };

  // ───────────────────────────── Apple ─────────────────────────────

  Future<SocialCredential?> _conApple() async {
    if (!supportaApple) {
      throw const AccessoSocialFallito(
        'L\'accesso con Apple è disponibile solo su iPhone e iPad.',
      );
    }

    try {
      /*
       * ⚠️ Si chiedono **email e nome**, e arrivano **una volta sola**: al
       * primo accesso. 🚨 Dalla seconda volta in poi Apple manda solo il
       * token, senza nome né email.
       *
       * 💡 Non è un problema per noi — il server tiene l'identità su
       * `(fornitore, sub)` e l'email la conserva dal primo accesso — ma è la
       * ragione per cui ⛔ non si può «riprovare» un primo accesso andato
       * storto senza prima togliere l'app dalle autorizzazioni dell'ID Apple.
       */
      final credenziale = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final token = credenziale.identityToken;

      if (token == null || token.isEmpty) {
        throw const AccessoSocialFallito(
          'Apple non ha restituito un token d\'identità.',
        );
      }

      return SocialCredential(provider: SocialProviderId.apple, idToken: token);
    } on SignInWithAppleAuthorizationException catch (errore) {
      // 🚨 Come sopra: annullare è una risposta legittima, non un guasto.
      if (errore.code == AuthorizationErrorCode.canceled) return null;

      throw AccessoSocialFallito(
        'Apple ha rifiutato l\'accesso (${errore.code.name}).',
      );
    }
  }

  /// 🍎 Dove l'accesso con Apple esiste davvero.
  ///
  /// 💡 `kIsWeb` **prima** di `Platform`: su web `dart:io` non c'è, e leggerlo
  /// farebbe saltare tutto prima di arrivare alla risposta.
  static bool get supportaApple =>
      !kIsWeb && (Platform.isIOS || Platform.isMacOS);
}

/// Un accesso social non riuscito, con un messaggio da mostrare.
///
/// ⚠️ Il testo è **per la persona**, non per chi sviluppa: `SocialButtons` lo
/// mette a schermo così com'è.
@immutable
class AccessoSocialFallito implements Exception {
  const AccessoSocialFallito(this.message);

  final String message;

  @override
  String toString() => message;
}
