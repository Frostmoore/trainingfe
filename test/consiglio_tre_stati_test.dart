import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/errors/api_exception.dart';
import 'package:training_companion/src/core/storage/token_store.dart';

/// I tre rifiuti del consiglio del giorno si distinguono — 21/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// 📌 Il committente: *«se non ho attiva l'ai perché ho 0 crediti o perché non
/// ho l'abbonamento, mi mostra il consiglio del giorno in perpetuo
/// caricamento»*.
///
/// ⚠️ **La causa era peggiore del sintomo.** `adviceProvider` catturava con
/// `on ForbiddenException`, ma quello che `dio` lancia è una `DioException` che
/// la **contiene**: quel ramo non scattava mai, e **tutto** finiva nel `catch`
/// generico — cioè in un consiglio vuoto, che a valle diventa la rotellina.
///
/// 🚨 Quindi non era rotto solo «niente AI»: era rotto anche **«serve il
/// consenso»**, scritto apposta il 12/08 e mai funzionante. Questo file prova
/// che adesso i tre casi si distinguono davvero.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiClient api;

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://esempio.test/api/v1',
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    api = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: _TokenStoreFinto(),
      dio: dio,
    );
  });

  tearDown(() => api.dispose());

  /// Quello che `adviceProvider` vede quando chiama.
  Future<ApiException> rifiuto() async {
    try {
      await api.get<Map<String, dynamic>>('/ai/advice');
    } on Object catch (e) {
      return ApiClient.unwrapError(e);
    }

    fail('La chiamata doveva fallire.');
  }

  test('🚨 il 403 NON arriva come ForbiddenException nuda', () async {
    /*
     * ══ LA TRAPPOLA, PROVATA ═══════════════════════════════════════════════
     *
     * ⚠️ È il motivo per cui il `catch` tipizzato non scattava. Questo test non
     * prova una funzione nostra: prova **come si comporta `dio`**, che è
     * l'assunto sbagliato su cui era costruito il codice vecchio.
     *
     * 🚨 Se un domani `ApiClient` cambiasse e cominciasse a lanciare
     * l'eccezione nuda, questo test diventerebbe rosso — ed è giusto: vorrebbe
     * dire che tutti i `catch` scritti con `unwrapError` vanno riguardati.
     */
    adapter.onGet(
      '/ai/advice',
      (s) => s.reply(403, {
        'code': 'ai_consent_required',
        'message': 'Serve il consenso.',
      }),
    );

    Object? grezzo;

    try {
      await api.get<Map<String, dynamic>>('/ai/advice');
    } on Object catch (e) {
      grezzo = e;
    }

    expect(
      grezzo,
      isNot(isA<ForbiddenException>()),
      reason: 'Se arrivasse nuda, il catch tipizzato avrebbe funzionato.',
    );
    expect(grezzo, isA<DioException>());
  });

  test('serve il consenso → ForbiddenException, dopo unwrapError', () async {
    adapter.onGet(
      '/ai/advice',
      (s) => s.reply(403, {
        'code': 'ai_consent_required',
        'message': 'Serve il consenso per usare l\'assistente.',
      }),
    );

    expect(await rifiuto(), isA<ForbiddenException>());
  });

  test('gettoni finiti → AiQuotaExceededException', () async {
    /*
     * 💡 È il caso che il committente vedeva: quota esaurita. ⚠️ Prima finiva
     * nel `catch` generico insieme a tutto il resto, e la card restava a
     * girare.
     */
    adapter.onGet(
      '/ai/advice',
      (s) => s.reply(429, {
        'error': 'ai_quota_exceeded',
        'message': 'Hai esaurito le chiamate di questo mese.',
      }),
    );

    expect(await rifiuto(), isA<AiQuotaExceededException>());
  });

  test('un guasto vero resta un guasto, e non diventa «niente AI»', () async {
    /*
     * ⚠️ La distinzione che rende utile tutto il resto: se il server non
     * risponde, la risposta giusta **non** è «non hai l'abbonamento». 🚨
     * Dirlo a chi l'abbonamento ce l'ha sarebbe peggio della rotellina.
     */
    adapter.onGet(
      '/ai/advice',
      (s) => s.throws(
        500,
        DioException(
          requestOptions: RequestOptions(path: '/ai/advice'),
          type: DioExceptionType.connectionError,
        ),
      ),
    );

    final tradotto = await rifiuto();

    expect(tradotto, isNot(isA<ForbiddenException>()));
    expect(tradotto, isNot(isA<AiQuotaExceededException>()));
    expect(tradotto, isA<NetworkException>());
  });
}

class _TokenStoreFinto implements TokenStore {
  String? _token;

  @override
  Future<void> clear() async => _token = null;

  @override
  void forgetCache() => _token = null;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;
}
