import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/errors/api_exception.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/aggiornamento/aggiornamento_controller.dart';

/// Il cancello della versione, lato app — FASE 10, 21/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// 📌 Il committente: *«se non è quella giusta si blocca dicendo che l'app non è
/// aggiornata»*.
///
/// ⚠️ Ma la cosa che questi test proteggono davvero è **il contrario**: che il
/// silenzio **non** blocchi. 🚨 Un'app che si ferma quando il server non risponde
/// è inutilizzabile in aereo, in cantina, e ogni volta che il *nostro* server ha
/// un problema — cioè un guasto nostro diventerebbe un'app rotta per tutti.
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

  test(
    'un 409 con `app_da_aggiornare` diventa AppDaAggiornareException, non un errore generico',
    () async {
      adapter.onGet(
        '/diario',
        (s) => s.reply(409, {
          'message': 'Questa versione non è più supportata.',
          'code': 'app_da_aggiornare',
          'minima': 74500,
          'store': 'https://play.google.com/store/apps/details?id=x',
        }),
      );

      /*
     * 🚨 Ha una classe sua perché il `catch (Object)` che sta in mezza app la
     * trasformerebbe in «non ha funzionato, riprova» — e la persona
     * **riproverebbe per sempre**, perché riprovare non può funzionare.
     */
      /*
       * ⚠️ Si passa da `unwrapError`, come fa tutta l'app: quello che `dio`
       * lancia è una `DioException` che **contiene** la nostra eccezione. Un
       * `on AppDaAggiornareException` non la prenderebbe mai — ed è proprio
       * l'errore che questo test ha trovato in `SchermataAggiorna`.
       */
      Object? preso;

      try {
        await api.get<Map<String, dynamic>>('/diario');
      } on Object catch (e) {
        preso = ApiClient.unwrapError(e);
      }

      expect(preso, isA<AppDaAggiornareException>());
      expect(
        (preso! as AppDaAggiornareException).store,
        contains('play.google.com'),
      );
    },
  );

  test(
    'il 409 arriva sullo stream, una volta sola e da un posto solo',
    () async {
      adapter.onGet(
        '/diario',
        (s) => s.reply(409, {
          'code': 'app_da_aggiornare',
          'store': 'https://x.test',
        }),
      );

      final visti = <AppDaAggiornareException>[];
      final sub = api.onDaAggiornare.listen(visti.add);

      await api
          .get<Map<String, dynamic>>('/diario')
          .catchError((Object _) => <String, dynamic>{});
      await Future<void>.delayed(Duration.zero);

      /*
     * 💡 Uno stream e non un'eccezione da catturare in ogni schermata: la prima
     * che se ne dimenticasse lascerebbe la persona davanti a un errore generico
     * su un'app che non può funzionare.
     */
      expect(visti, hasLength(1));
      expect(visti.first.store, 'https://x.test');

      await sub.cancel();
    },
  );

  test('il controller si blocca sul verdetto, e non da solo', () async {
    adapter.onGet(
      '/diario',
      (s) => s.reply(409, {
        'code': 'app_da_aggiornare',
        'store': 'https://x.test',
      }),
    );

    final controller = AggiornamentoController(api);

    expect(controller.state.serve, isFalse, reason: 'Nasce sbloccato.');

    await api
        .get<Map<String, dynamic>>('/diario')
        .catchError((Object _) => <String, dynamic>{});
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.serve, isTrue);
    expect(controller.state.store, 'https://x.test');

    // 💡 E si sblocca solo se glielo si dice: serve al «Riprova», per quando il
    // blocco è stato un errore nostro.
    controller.sblocca();
    expect(controller.state.serve, isFalse);

    controller.dispose();
  });

  test(
    '🚨 il SILENZIO non blocca: rete assente, server giù, DNS morto',
    () async {
      /*
     * ══ IL TEST PIÙ IMPORTANTE DEL FILE ═════════════════════════════════════
     *
     * ⚠️ Si blocca solo su un **verdetto esplicito**, mai sul silenzio. Il
     * contrario renderebbe l'app inutilizzabile ogni volta che manca la rete.
     *
     * 🚨 Ed è la ragione per cui il cancello da solo NON basta a spegnere un
     * server vecchio: il silenzio non blocca, quindi spegnerlo non fa scattare
     * niente. Serve la procedura in cinque passi del piano, dove il server
     * vecchio resta acceso a dire «aggiornati».
     */
      adapter.onGet(
        '/diario',
        (s) => s.throws(
          500,
          DioException(
            requestOptions: RequestOptions(path: '/diario'),
            type: DioExceptionType.connectionError,
          ),
        ),
      );

      final controller = AggiornamentoController(api);
      final visti = <AppDaAggiornareException>[];
      final sub = api.onDaAggiornare.listen(visti.add);

      await api
          .get<Map<String, dynamic>>('/diario')
          .catchError((Object _) => <String, dynamic>{});
      await Future<void>.delayed(Duration.zero);

      expect(
        visti,
        isEmpty,
        reason: 'Il silenzio ha fatto scattare il cancello.',
      );
      expect(controller.state.serve, isFalse);

      await sub.cancel();
      controller.dispose();
    },
  );

  test('un 401 non è un blocco di versione: due schermate diverse', () async {
    // ⚠️ Confonderli manderebbe al login chi deve andare allo store, e viceversa.
    adapter.onGet(
      '/diario',
      (s) => s.reply(401, {'message': 'Non autenticato.'}),
    );

    final controller = AggiornamentoController(api);

    await api
        .get<Map<String, dynamic>>('/diario')
        .catchError((Object _) => <String, dynamic>{});
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.serve, isFalse);

    controller.dispose();
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
