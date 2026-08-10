import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/api_exception.dart';
import '../../core/providers.dart';
import '../../core/storage/token_store.dart';
import 'data/app_user.dart';
import 'data/social_sign_in.dart';

/// In quale dei quattro stati si trova la sessione — A2.4.
enum AuthStatus {
  /// Si sta ancora leggendo il token dal Keychain.
  unknown,

  /// Nessuna sessione: si va al login.
  loggedOut,

  /// Sessione valida.
  loggedIn,

  /// 🚨 Autenticato **ma la palestra è sospesa**.
  ///
  /// Non è «disconnesso»: le credenziali sono giuste e l'utente non può farci
  /// niente. Mandarlo al login lo farebbe riprovare all'infinito con la
  /// password corretta, convinto di sbagliarla. Serve una schermata che dica
  /// cosa è successo.
  gymInactive,
}

/// Lo stato della sessione.
class AuthState {
  const AuthState({required this.status, this.user, this.message});

  const AuthState.unknown() : status = AuthStatus.unknown, user = null, message = null;

  final AuthStatus status;
  final AppUser? user;
  final String? message;

  bool get isAuthenticated => status == AuthStatus.loggedIn;
}

/// Chi è l'utente, e cosa succede quando smette di esserlo — A2.3 / A2.4.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._api, this._tokens) : super(const AuthState.unknown()) {
    // 🚨 Il 401 arriva da **qualunque** richiesta, non solo da quelle di
    // autenticazione: una schermata qualsiasi può essere la prima ad accorgersi
    // che la sessione è morta. Ascoltare lo stream centrale è ciò che evita di
    // gestire quel caso in ogni chiamata.
    _sessionSub = _api.onSessionExpired.listen((_) => _forgetSession());
  }

  final ApiClient _api;
  final TokenStore _tokens;

  StreamSubscription<void>? _sessionSub;

  /// Legge il token salvato e chiede al server chi siamo.
  ///
  /// Si chiama all'avvio. Se il token c'è ma non vale più, `_forgetSession()`
  /// scatta dallo stream e lo stato finisce a `loggedOut` senza che qui serva
  /// un `catch` dedicato.
  Future<void> restore() async {
    final token = await _tokens.read();

    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.loggedOut);

      return;
    }

    await _loadMe();
  }

  /// Accesso con **email o nome utente**.
  ///
  /// Il campo si chiama `login` perché accetta entrambi: chiamarlo `email`
  /// sarebbe un nome che mente, ed è il motivo per cui prima o poi qualcuno gli
  /// rimetterebbe una validazione sull'email credendo di correggere una svista.
  Future<void> login({
    required String login,
    required String password,
    String? joinCode,
  }) async {
    final payload = <String, dynamic>{
      'login': login.trim(),
      'password': password,
      // Il nome del dispositivo finisce nell'elenco dei token: serve
      // all'utente per riconoscere e revocare una sessione che non ricorda.
      'device_name': 'app',
      if (joinCode != null && joinCode.isNotEmpty) 'join_code': joinCode,
    };

    // 🚨 `unwrap: false`: la risposta è `{token, data, branding}`, non un
    // inviluppo. Vedi la nota in `ApiClient._unwrap()`.
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: payload,
      unwrap: false,
    );

    await _acceptToken(data);
  }

  /// 🚨 `passwordConfirmation` è un parametro vero, non `password` ripetuta.
  ///
  /// Il backend valida con `confirmed`, ma se il client manda due volte lo
  /// stesso valore quella regola non può fallire mai: il controllo esiste per
  /// intercettare un **errore di battitura**, e ricopiando il primo campo lo si
  /// disattiva senza toglierlo. È il tipo di finta protezione che si scopre
  /// quando qualcuno resta chiuso fuori dal proprio account il giorno dopo
  /// l'iscrizione.
  Future<void> register({
    required String joinCode,
    required String name,
    required String email,
    required String username,
    required String password,
    required String passwordConfirmation,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      body: {
        'join_code': joinCode,
        'name': name.trim(),
        'email': email.trim(),
        'username': username.trim().toLowerCase(),
        'password': password,
        'password_confirmation': passwordConfirmation,
        'device_name': 'app',
      },
      unwrap: false,
    );

    await _acceptToken(data);
  }

  /// Accesso con Google o Apple — C17.
  ///
  /// 🚨 `joinCode` serve **solo la prima volta**, e il server lo dice: se
  /// risponde `join_code_required`, l'app deve chiedere il codice palestra e
  /// riprovare. Mandarlo sempre non servirebbe — dal secondo accesso il server
  /// lo ignora, perché la palestra di una persona è quella scritta sul suo
  /// utente e non quella che presenta al momento dell'accesso.
  ///
  /// Restituisce `false` se la persona ha annullato: **non è un errore** e non
  /// va mostrato come tale.
  Future<bool> loginWithSocial(String provider, {String? joinCode}) async {
    final credenziale = await SocialSignIn.instance.accedi(provider);

    if (credenziale == null) return false;

    final data = await _api.post<Map<String, dynamic>>(
      '/auth/social',
      body: {
        'provider': credenziale.provider,
        'id_token': credenziale.idToken,
        'join_code': ?joinCode,
        'device_name': 'app',
      },
      unwrap: false,
    );

    await _acceptToken(data);

    return true;
  }

  /// Esce, e **non lascia il token addosso se il server non risponde**.
  ///
  /// 🚨 L'ordine conta: si prova a revocare lato server, ma la sessione locale
  /// si cancella comunque. Un logout che fallisce perché il telefono è offline
  /// e lascia l'utente dentro è peggio di un token che resta valido sul server
  /// finché non scade: quello lo si revoca dall'elenco dispositivi, l'altro è
  /// un telefono prestato a qualcuno con la sessione aperta.
  Future<void> logout() async {
    try {
      await _api.post<dynamic>('/auth/logout');
    } on Object {
      // Silenzio voluto: la sessione locale se ne va comunque.
    }

    await _forgetSession();
  }

  /// Ricarica l'utente: dopo un cambio di profilo, o al ritorno in primo piano.
  Future<void> refresh() => _loadMe();

  /// Dimentica la sessione **senza chiamare il server** — C6.
  ///
  /// Serve dopo l'eliminazione dell'account: il token è già stato revocato, e
  /// una `logout()` farebbe una chiamata destinata a un 401. Il router reagisce
  /// al cambio di stato e riporta all'accesso.
  Future<void> forgetSession() => _forgetSession();

  // ───────────────────────── interni ─────────────────────────

  Future<void> _acceptToken(Map<String, dynamic> data) async {
    final token = data['token']?.toString();

    if (token == null || token.isEmpty) {
      throw StateError('Il server non ha restituito un token.');
    }

    await _tokens.write(token);

    // 🚨 **L'utente sta sotto `data`, non sotto `user`.**
    //
    // La risposta è `{token, data, branding}` — la stessa forma su cui
    // `unwrap: false` insiste tre righe più su. Leggendo `user` si otteneva
    // sempre `null`, e la sessione partiva **senza utente**: si riempiva solo
    // al riavvio successivo, quando `restore()` chiama `/auth/me`.
    //
    // Nel frattempo, nella sessione appena aperta, il filo della chat mostrava
    // **ogni messaggio come se fosse dell'altra persona** (`user?.id ?? -1`
    // non corrisponde a nessun mittente) e l'intestazione di «Oggi» non
    // salutava nessuno. Difetto invisibile a chi riapriva l'app, cioè a chi
    // provava — che è esattamente il motivo per cui è sopravvissuto.
    final utente = data['data'];

    state = AuthState(
      status: AuthStatus.loggedIn,
      user: utente is Map<String, dynamic> ? AppUser.fromJson(utente) : null,
    );
  }

  Future<void> _loadMe() async {
    try {
      // Anche qui l'inviluppo non c'è: `/auth/me` risponde `{data, branding}`.
      final risposta = await _api.get<Map<String, dynamic>>('/auth/me', unwrap: false);

      final utente = risposta['data'];

      state = AuthState(
        status: AuthStatus.loggedIn,
        user: utente is Map<String, dynamic> ? AppUser.fromJson(utente) : null,
      );
    } on Object catch (error) {
      // 🚨 Sul **tipo**, non sul messaggio. Riconoscere un errore dal testo
      // significa che il giorno in cui qualcuno riformula una frase l'app
      // smette di distinguere «palestra sospesa» da «errore generico» — e
      // manda al login una persona che ha le credenziali giuste.
      final tradotto = ApiClient.unwrapError(error);

      if (tradotto is GymInactiveException) {
        state = AuthState(status: AuthStatus.gymInactive, message: tradotto.message);

        return;
      }

      // Il 401 ha già fatto scattare `_forgetSession()` dallo stream.
      if (state.status == AuthStatus.unknown) {
        state = const AuthState(status: AuthStatus.loggedOut);
      }
    }
  }

  Future<void> _forgetSession() async {
    await _tokens.clear();

    state = const AuthState(status: AuthStatus.loggedOut);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(apiClientProvider), ref.watch(tokenStoreProvider)),
);
