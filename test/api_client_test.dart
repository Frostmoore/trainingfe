import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/errors/api_exception.dart';
import 'package:training_companion/src/core/storage/token_store.dart';

/// A1.3 — il client API.
///
/// 🚨 **Nessun test tocca la rete**, come sul backend. Un test che chiama un
/// server vero è lento, dipende da uno staging acceso, e fallisce quando quello
/// ha un problema — cioè proprio quando serve sapere se il *nostro* codice
/// funziona.
///
/// Quello che si prova qui è la traduzione degli errori: è la parte che, se
/// sbagliata, fa comparire all'utente «Errore 422» invece di dirgli cosa fare.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiClient client;

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://esempio.test/api/v1',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    client = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: _TokenStoreFinto(),
      dio: dio,
    );
  });

  group('inviluppo', () {
    test('srotola `data` senza che il chiamante debba saperlo', () async {
      adapter.onGet(
        '/diario',
        (s) => s.reply(200, {
          'data': {'kcal': 1200},
        }),
      );

      final risposta = await client.get<Map<String, dynamic>>('/diario');

      expect(risposta['kcal'], 1200);
    });

    test('una risposta senza inviluppo passa com\'è', () async {
      adapter.onGet('/nudo', (s) => s.reply(200, {'kcal': 900}));

      final risposta = await client.get<Map<String, dynamic>>('/nudo');

      expect(risposta['kcal'], 900);
    });

    /// 🚨 **Il test che avrebbe risparmiato un pomeriggio.**
    ///
    /// `/auth/login` risponde `{token, data, branding}`: `data` è **una delle
    /// tre cose**, non il contenitore. Srotolandola si ottiene il solo utente,
    /// il token sparisce, e il login fallisce con un errore che l'interfaccia
    /// mostrava come «email o password non corretti» — dando la colpa
    /// all'utente di un difetto del client.
    ///
    /// Il login dell'app **non ha mai funzionato**, per nessuno, e nessun test
    /// se ne era accorto perché nessuno provava questa forma di risposta.
    test('con unwrap:false la risposta di login resta intera', () async {
      adapter.onPost(
        '/auth/login',
        (s) => s.reply(200, {
          'token': '1|abc',
          'data': {'id': 1, 'email': 'mario@esempio.test'},
          'branding': {'name': 'Palestra'},
        }),
        data: Matchers.any,
      );

      final risposta = await client.post<Map<String, dynamic>>(
        '/auth/login',
        body: const {'login': 'mario@esempio.test', 'password': 'x'},
        unwrap: false,
      );

      expect(risposta['token'], '1|abc');
      expect(risposta['branding'], isNotNull);
      expect((risposta['data'] as Map)['email'], 'mario@esempio.test');
    });

    /// E la prova al contrario, che documenta perché serviva il parametro.
    test('con unwrap:true la stessa risposta perde il token', () async {
      adapter.onPost(
        '/auth/login',
        (s) => s.reply(200, {
          'token': '1|abc',
          'data': {'id': 1, 'email': 'mario@esempio.test'},
        }),
        data: Matchers.any,
      );

      final risposta = await client.post<Map<String, dynamic>>(
        '/auth/login',
        body: const {'login': 'mario@esempio.test', 'password': 'x'},
      );

      expect(
        risposta['token'],
        isNull,
        reason:
            'Srotolando `data` il token sparisce: è esattamente il difetto '
            'che rendeva impossibile il login.',
      );
    });
  });

  group('traduzione degli errori', () {
    test(
      '401 diventa UnauthenticatedException e avvisa una volta sola',
      () async {
        adapter.onGet(
          '/me',
          (s) => s.reply(401, {'message': 'Unauthenticated.'}),
        );

        final avvisi = <void>[];
        final sub = client.onSessionExpired.listen(avvisi.add);

        await expectLater(
          client.get<dynamic>('/me'),
          throwsA(
            isA<DioException>().having(
              (e) => e.error,
              'error',
              isA<UnauthenticatedException>(),
            ),
          ),
        );

        // Il tempo di far scorrere lo stream.
        await Future<void>.delayed(Duration.zero);

        expect(
          avvisi,
          hasLength(1),
          reason: 'La sessione scaduta va segnalata una volta sola.',
        );

        await sub.cancel();
      },
    );

    test('🚨 403 tenant_inactive NON è un problema di credenziali', () async {
      adapter.onGet(
        '/me',
        (s) => s.reply(403, {
          'code': 'tenant_inactive',
          'message': 'Palestra sospesa.',
        }),
      );

      try {
        await client.get<dynamic>('/me');
        fail('Doveva lanciare.');
      } on Object catch (e) {
        final tradotto = ApiClient.unwrapError(e);

        // Se diventasse un 401, l'app manderebbe al login una persona che ha la
        // password giusta e non può farci niente: riproverebbe all'infinito.
        expect(tradotto, isA<GymInactiveException>());
        expect(tradotto, isNot(isA<UnauthenticatedException>()));
      }
    });

    test('403 generico resta ForbiddenException', () async {
      adapter.onGet('/segreto', (s) => s.reply(403, {'message': 'No.'}));

      final tradotto = ApiClient.unwrapError(
        await _cattura(() => client.get<dynamic>('/segreto')),
      );

      expect(tradotto, isA<ForbiddenException>());
    });

    test('422 porta gli errori per campo', () async {
      adapter.onPost(
        '/auth/register',
        (s) => s.reply(422, {
          'message': 'Dati non validi.',
          'errors': {
            'email': ['Questa email è già registrata.'],
          },
        }),
        data: Matchers.any,
      );

      final tradotto = ApiClient.unwrapError(
        await _cattura(
          () => client.post<dynamic>('/auth/register', body: {'email': 'x'}),
        ),
      );

      expect(tradotto, isA<ValidationException>());
      expect(
        (tradotto as ValidationException).forField('email'),
        'Questa email è già registrata.',
      );
    });

    test('🚨 429 di quota AI è diverso da un 429 di frequenza', () async {
      adapter.onPost(
        '/ai/food/text',
        (s) => s.reply(429, {
          'error': 'ai_quota_exceeded',
          'message': 'Quota finita.',
          'resets_at': '2026-09-01T00:00:00+02:00',
        }),
        data: Matchers.any,
      );

      final tradotto = ApiClient.unwrapError(
        await _cattura(
          () => client.post<dynamic>('/ai/food/text', body: {'text': 'mela'}),
        ),
      );

      // La differenza conta: la quota NON si sblocca riprovando, e mostrare un
      // «riprova» farebbe martellare l'utente contro un muro fino al mese
      // prossimo.
      expect(tradotto, isA<AiQuotaExceededException>());
      expect((tradotto as AiQuotaExceededException).resetsAt?.year, 2026);
    });

    test('429 generico è ritentabile, la quota no', () async {
      adapter.onGet('/qualcosa', (s) => s.reply(429, {'message': 'Piano.'}));

      final tradotto = ApiClient.unwrapError(
        await _cattura(() => client.get<dynamic>('/qualcosa')),
      );

      // Senza `code`, un 429 è un limite di frequenza: si riprova. Con
      // `ai_quota_exceeded` no, e quello è il test qui sopra.
      expect(tradotto, isA<RateLimitedException>());
      expect(tradotto, isNot(isA<AiQuotaExceededException>()));
    });

    test('un errore di rete non diventa un errore del server', () async {
      adapter.onGet(
        '/qualcosa',
        (s) => s.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: '/qualcosa'),
            reason: 'offline',
          ),
        ),
      );

      final tradotto = ApiClient.unwrapError(
        await _cattura(() => client.get<dynamic>('/qualcosa')),
      );

      // La distinzione serve all'interfaccia: «controlla la connessione» è un
      // consiglio utile, «il servizio ha un problema» no.
      expect(tradotto, isA<NetworkException>());
    });
  });

  /// 🚨 Il token deve arrivare su **ogni** richiesta, non solo su quelle che
  /// qualcuno si è ricordato di autenticare: basta dimenticarlo una volta per
  /// avere una schermata che dà 401 senza motivo apparente.
  test('il token finisce nell\'intestazione di ogni richiesta', () async {
    String? intestazione;

    // Un interceptor di prova in coda a quello vero: legge cosa è stato
    // effettivamente messo nella richiesta.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          intestazione = options.headers['Authorization']?.toString();
          handler.next(options);
        },
      ),
    );

    adapter.onGet('/me', (s) => s.reply(200, {'data': <String, dynamic>{}}));

    await client.get<dynamic>('/me');

    expect(intestazione, 'Bearer token-finto');
  });
}

/// Esegue e restituisce l'errore, per non ripetere try/catch in ogni test.
Future<Object> _cattura(Future<void> Function() azione) async {
  try {
    await azione();

    fail('Doveva lanciare.');
  } on Object catch (e) {
    return e;
  }
}

class _TokenStoreFinto implements TokenStore {
  @override
  Future<String?> read() async => 'token-finto';

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}

  @override
  void forgetCache() {}
}
