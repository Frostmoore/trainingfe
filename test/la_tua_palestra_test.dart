import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/profile/palestra_controller.dart';

/// 🏠 **«La tua palestra»** — trovato nel giro dei rapporti, 18/09/2026.
///
/// ⛔ Dal 23/08 la schermata diceva *«Non sei iscritto a nessuna palestra»* a
/// chi ci era iscritto, con l'intestazione della palestra sopra: `get()`
/// toglieva già l'involucro `data`, e il provider lo cercava una seconda
/// volta. 🚨 Nessuno poteva dissociarsi dall'app.
void main() {
  late DioAdapter rete;
  late ProviderContainer contenitore;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'https://esempio.test/api/v1'));
    rete = DioAdapter(dio: dio);
    dio.httpClientAdapter = rete;

    contenitore = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(
            config: const AppConfig(
              environment: AppEnvironment.local,
              apiBaseUrl: 'https://esempio.test/api/v1',
              enableDebugTools: true,
            ),
            tokenStore: _TokenFinto(),
            dio: dio,
          ),
        ),
      ],
    );
  });

  tearDown(() => contenitore.dispose());

  test('chi è in palestra la vede', () async {
    rete.onGet(
      '/account/gym',
      (r) => r.reply(200, {
        'data': {
          'name': 'Palestra Giro A',
          'contact_email': 'a@esempio.test',
          'iscritto_dal': '2026-09-18',
        },
      }),
    );

    final p = await contenitore.read(dettagliPalestraProvider.future);

    expect(p, isNotNull, reason: 'Diceva «nessuna palestra» a chi c’era.');
    expect(p!.nome, 'Palestra Giro A');
    expect(p.iscrittoDal, DateTime(2026, 9, 18));
  });

  /// ⚠️ **E chi non ce l'ha non va in errore**: `data: null` è una risposta,
  /// non un guasto.
  test('chi non è in palestra riceve null, non un errore', () async {
    rete.onGet('/account/gym', (r) => r.reply(200, {'data': null}));

    expect(await contenitore.read(dettagliPalestraProvider.future), isNull);
  });
}

class _TokenFinto implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  void forgetCache() {}

  @override
  Future<String?> read() async => 'finto';

  @override
  Future<void> write(String token) async {}
}
