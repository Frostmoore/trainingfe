import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/auth/data/fornitori_social.dart';
import 'package:training_companion/src/features/auth/data/social_sign_in.dart';

/// 🔑 **«Con cosa posso entrare?»** — voce 25, 26/09/2026.
///
/// ══ ⛔ IL DIFETTO CHE QUESTI TEST CHIUDONO ═════════════════════════════════
///
/// 🚨 L'elenco dei fornitori viaggiava **solo** dentro `GymBranding.social`, e
/// il branding arriva con l'accesso — cioè **dopo**. ⛔ Chi apriva l'app per la
/// prima volta aveva `neutral`, con l'elenco vuoto, e i pulsanti «Continua con
/// Google» non comparivano **mai**: proprio a chi servivano.
///
/// ⚠️ La rotta pubblica che serviva a questo è stata tolta con F11 il
/// 24/09/2026. 🚨 Nessuno se n'è accorto per due giorni perché l'accesso social
/// era comunque spento: il sintomo era identico al comportamento atteso.
void main() {
  group('la lettura della risposta del server', () {
    test('tiene i fornitori conosciuti', () {
      expect(leggiIFornitori(['google', 'apple']), [
        SocialProviderId.google,
        SocialProviderId.apple,
      ]);
    });

    /// 🚨 **Il caso che conta.** ⛔ Il server potrebbe un giorno dichiarare un
    /// fornitore nuovo: una versione vecchia dell'app non saprebbe né
    /// disegnarne il pulsante né gestirne l'accesso.
    ///
    /// 💡 Mostrarlo sarebbe peggio che ignorarlo: un pulsante che non porta da
    /// nessuna parte fa sembrare rotta tutta l'applicazione.
    test('⛔ butta via quelli che non conosce', () {
      expect(leggiIFornitori(['google', 'facebook', 'linkedin']), [
        SocialProviderId.google,
      ]);
    });

    /// ⚠️ La risposta arriva dalla rete: può essere qualunque cosa. ⛔ Un
    /// `as List` ottimista qui farebbe morire la schermata d'accesso — cioè la
    /// prima cosa che si vede.
    test('⚠️ una risposta malformata non fa saltare niente', () {
      for (final storta in <Object?>[null, 'google', 42, {}, ['', null]]) {
        expect(
          leggiIFornitori(storta),
          isEmpty,
          reason: 'su ${storta.runtimeType} deve restituire una lista vuota',
        );
      }
    });

    test('una lista vuota resta vuota', () {
      expect(leggiIFornitori(const []), isEmpty);
    });
  });


  /// 🎯 **Il test che avrebbe preso il difetto del 26/09.**
  ///
  /// ══ ⛔ COSA ERA SUCCESSO ═══════════════════════════════════════════════
  ///
  /// 🚨 Il provider chiedeva una `Map<String, dynamic>` e leggeva `['data']`.
  /// ⛔ Ma `ApiClient.get` **srotola già** l'involucro: arriva la **lista**.
  /// Il cast falliva, l'errore finiva nel `catch`, e l'app si comportava
  /// **esattamente come se il server non avesse risposto** — nessun pulsante,
  /// nessun messaggio.
  ///
  /// ⚠️ Il server rispondeva **200**: si è scoperto solo andando a leggere il
  /// suo log di accesso. 💡 Nessuno dei test di prima poteva vederlo, perché
  /// provavano `leggiIFornitori()` **da sola** — cioè il pezzo che era giusto.
  ///
  /// 🔑 Per questo qui si passa dal **client vero**, con la risposta vera:
  /// l'involucro fa parte del contratto, e un test che lo salta prova metà
  /// del giro.
  group('il provider legge la risposta vera del server', () {
    late Dio dio;
    late DioAdapter adapter;
    late ProviderContainer container;

    setUp(() {
      dio = Dio(
        BaseOptions(
          baseUrl: 'https://esempio.test/api/v1',
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      adapter = DioAdapter(dio: dio);
      dio.httpClientAdapter = adapter;

      container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(
            ApiClient(
              config: const AppConfig(
                environment: AppEnvironment.local,
                apiBaseUrl: 'https://esempio.test/api/v1',
                enableDebugTools: true,
              ),
              tokenStore: _SenzaToken(),
              dio: dio,
            ),
          ),
        ],
      );
    });

    tearDown(() => container.dispose());

    test('🎯 srotola l\'involucro `data` come fa ApiClient', () async {
      adapter.onGet(
        '/auth/fornitori',
        (s) => s.reply(200, {
          'data': ['google', 'apple'],
        }),
      );

      expect(await container.read(fornitoriSocialProvider.future), [
        'google',
        'apple',
      ]);
    });

    /// ⚠️ E se il server non risponde **non si disegna niente**, senza far
    /// saltare la schermata d'accesso — che è la prima cosa che si vede.
    test('⚠️ se il server non risponde, nessun pulsante e nessun errore', () async {
      adapter.onGet(
        '/auth/fornitori',
        (s) => s.throws(
          0,
          DioException.connectionError(
            requestOptions: RequestOptions(path: '/auth/fornitori'),
            reason: 'offline',
          ),
        ),
      );

      expect(await container.read(fornitoriSocialProvider.future), isEmpty);
    });
  });
}

class _SenzaToken implements TokenStore {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}

  @override
  Future<void> forgetCache() async {}
}
