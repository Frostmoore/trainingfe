import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/api_exception.dart';
import '../../core/providers.dart';
import '../../core/storage/token_store.dart';
import 'data/app_user.dart';

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

  Future<void> login({required String email, required String password, String? joinCode}) async {
    final payload = <String, dynamic>{
      'email': email.trim(),
      'password': password,
      // Il nome del dispositivo finisce nell'elenco dei token: serve
      // all'utente per riconoscere e revocare una sessione che non ricorda.
      'device_name': 'app',
      if (joinCode != null && joinCode.isNotEmpty) 'join_code': joinCode,
    };

    final data = await _api.post<Map<String, dynamic>>('/auth/login', body: payload);

    await _acceptToken(data);
  }

  Future<void> register({
    required String joinCode,
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      body: {
        'join_code': joinCode,
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirmation': password,
        'device_name': 'app',
      },
    );

    await _acceptToken(data);
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

  // ───────────────────────── interni ─────────────────────────

  Future<void> _acceptToken(Map<String, dynamic> data) async {
    final token = data['token']?.toString();

    if (token == null || token.isEmpty) {
      throw StateError('Il server non ha restituito un token.');
    }

    await _tokens.write(token);

    final user = data['user'];

    state = AuthState(
      status: AuthStatus.loggedIn,
      user: user is Map<String, dynamic> ? AppUser.fromJson(user) : null,
    );
  }

  Future<void> _loadMe() async {
    try {
      final data = await _api.get<Map<String, dynamic>>('/auth/me');

      state = AuthState(status: AuthStatus.loggedIn, user: AppUser.fromJson(data));
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
