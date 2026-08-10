import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';

/// A2.3 — la sessione.
///
/// 🚨 **Il test che mancava.** `api_client_test.dart` provava già che la
/// risposta di login ha la forma `{token, data, branding}`, ma nessuno provava
/// che `AuthController` la **leggesse** giusta: cercava l'utente sotto `user`,
/// che non esiste, e otteneva sempre `null`.
///
/// Il difetto era invisibile a chi riapriva l'app — `restore()` chiama
/// `/auth/me`, che l'utente lo legge dal posto giusto — e quindi sopravviveva a
/// ogni prova manuale fatta il giorno dopo. Si vedeva solo nella sessione
/// appena aperta: la chat metteva **tutti** i messaggi dal lato dell'altra
/// persona, perché `user?.id ?? -1` non corrisponde a nessun mittente.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiClient client;
  late _TokenStoreFinto token;

  /// La risposta comune a `/auth/login` e `/auth/register`: l'utente sta sotto
  /// `data`, **accanto** al token, non dentro un inviluppo.
  const rispostaConToken = {
    'token': '1|abcdef',
    'data': {
      'id': 7,
      'name': 'Mario Rossi',
      'email': 'mario@esempio.test',
      'username': 'mario.rossi',
    },
    'branding': {'name': 'Palestra Demo'},
  };

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://esempio.test/api/v1',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    token = _TokenStoreFinto();

    client = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: token,
      dio: dio,
    );
  });

  test('dopo il login la sessione sa chi è l\'utente', () async {
    adapter.onPost(
      '/auth/login',
      (s) => s.reply(200, rispostaConToken),
      data: Matchers.any,
    );

    final auth = AuthController(client, token);

    await auth.login(login: 'mario.rossi', password: 'x');

    expect(auth.state.status, AuthStatus.loggedIn);
    expect(
      auth.state.user,
      isNotNull,
      reason: 'Senza utente la chat attribuisce ogni messaggio all\'altra '
          'persona e «Oggi» non saluta nessuno.',
    );
    expect(auth.state.user!.id, 7);
    expect(auth.state.user!.name, 'Mario Rossi');
    expect(auth.state.user!.username, 'mario.rossi');
  });

  test('il token arriva nel portachiavi, non solo nello stato', () async {
    adapter.onPost(
      '/auth/login',
      (s) => s.reply(200, rispostaConToken),
      data: Matchers.any,
    );

    final auth = AuthController(client, token);

    await auth.login(login: 'mario.rossi', password: 'x');

    expect(token.salvato, '1|abcdef');
  });

  test('anche la registrazione porta con sé l\'utente', () async {
    adapter.onPost(
      '/auth/register',
      (s) => s.reply(201, rispostaConToken),
      data: Matchers.any,
    );

    final auth = AuthController(client, token);

    await auth.register(
      joinCode: 'DEMO2345',
      name: 'Mario Rossi',
      email: 'mario@esempio.test',
      username: 'mario.rossi',
      password: 'x',
      passwordConfirmation: 'x',
    );

    expect(auth.state.user?.id, 7);
  });

  /// 🚨 La conferma viaggia come campo **suo**, non come copia della password.
  ///
  /// Se il client ricopiasse il primo valore, la regola `confirmed` del backend
  /// non potrebbe fallire mai: il controllo esisterebbe senza proteggere dal
  /// caso per cui è lì — l'errore di battitura che chiude fuori dal proprio
  /// account il giorno dopo l'iscrizione.
  test('la conferma della password si manda separata, non ricopiata', () async {
    Map<String, dynamic>? inviato;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('register')) {
            inviato = (options.data as Map).cast<String, dynamic>();
          }
          handler.next(options);
        },
      ),
    );

    adapter.onPost(
      '/auth/register',
      (s) => s.reply(201, rispostaConToken),
      data: Matchers.any,
    );

    final auth = AuthController(client, token);

    await auth.register(
      joinCode: 'DEMO2345',
      name: 'Mario Rossi',
      email: 'mario@esempio.test',
      username: 'mario.rossi',
      password: 'primo-valore',
      passwordConfirmation: 'secondo-valore',
    );

    expect(inviato?['password'], 'primo-valore');
    expect(inviato?['password_confirmation'], 'secondo-valore');
  });

  /// La via che funzionava già, e che nascondeva l'altra: qui l'utente sta
  /// sotto `data` di una risposta **senza** token.
  test('al riavvio la sessione si ricostruisce da /auth/me', () async {
    token.salvato = '1|abcdef';

    adapter.onGet(
      '/auth/me',
      (s) => s.reply(200, {
        'data': {'id': 7, 'name': 'Mario Rossi', 'email': 'mario@esempio.test'},
        'branding': {'name': 'Palestra Demo'},
      }),
    );

    final auth = AuthController(client, token);

    await auth.restore();

    expect(auth.state.status, AuthStatus.loggedIn);
    expect(auth.state.user?.id, 7);
  });

  test('senza token salvato si parte disconnessi, senza chiamare il server', () async {
    final auth = AuthController(client, token);

    await auth.restore();

    expect(auth.state.status, AuthStatus.loggedOut);
    expect(auth.state.user, isNull);
  });

  /// 🚨 Dopo l'eliminazione dell'account il token è **già** revocato: una
  /// `logout()` farebbe una chiamata destinata a un 401.
  test('forgetSession svuota la sessione senza chiamare il server', () async {
    adapter.onPost(
      '/auth/login',
      (s) => s.reply(200, rispostaConToken),
      data: Matchers.any,
    );

    final auth = AuthController(client, token);

    await auth.login(login: 'mario.rossi', password: 'x');
    await auth.forgetSession();

    expect(auth.state.status, AuthStatus.loggedOut);
    expect(auth.state.user, isNull);
    expect(token.salvato, isNull);
  });
}

class _TokenStoreFinto implements TokenStore {
  String? salvato;

  @override
  Future<String?> read() async => salvato;

  @override
  Future<void> write(String token) async => salvato = token;

  @override
  Future<void> clear() async => salvato = null;

  @override
  void forgetCache() {}
}
