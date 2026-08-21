import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/crypto/portachiavi.dart';
import 'package:training_companion/src/core/crypto/servizio_chiavi.dart';
import 'package:training_companion/src/core/storage/token_store.dart';

import '../aiuto/libsodium.dart';

/// S6.7 — cosa decide l'app all'avvio, e il difetto che ha chiuso la chat.
///
/// 🚨 **Il caso del 204 capita al 100% degli utenti la prima volta**, e non era
/// coperto da nessun test. Il risultato: la chat non si apriva **mai**, e la
/// schermata diceva «Non riesco a controllare le tue chiavi» — cioè dava la
/// colpa alla rete per un errore di tipo dentro l'app.
void main() {
  late DioAdapter adapter;
  late ServizioChiavi servizio;

  setUp(() async {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://esempio.test/api/v1',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    servizio = ServizioChiavi(
      sodium: await libsodiumPerTest(),
      api: ApiClient(
        config: const AppConfig(
          environment: AppEnvironment.local,
          apiBaseUrl: 'https://esempio.test/api/v1',
          enableDebugTools: true,
        ),
        tokenStore: _TokenStoreFinto(),
        dio: dio,
      ),
      portachiavi: _PortachiaviFinto(),
    );
  });

  /// 🚨 **Il test che avrebbe evitato il guasto.**
  ///
  /// `204 No Content` significa «non hai ancora una password di recupero», che è
  /// lo stato normale di chi apre l'app per la prima volta. Deve portare a
  /// [StatoChiavi.daCreare], non a un'eccezione.
  test('un 204 vuol dire «account nuovo», non un guasto', () async {
    adapter.onGet('/account/recovery-key', (s) => s.reply(204, null));

    expect(await servizio.stato(), StatoChiavi.daCreare);
  });

  /// ⚠️ **La variante cattiva dello stesso caso.** A seconda di come il server
  /// chiude una risposta vuota, `dio` consegna `null` **oppure una stringa
  /// vuota** — ed era la seconda a far esplodere il cast.
  test('anche un 204 con corpo vuoto invece che nullo', () async {
    adapter.onGet('/account/recovery-key', (s) => s.reply(204, ''));

    expect(await servizio.stato(), StatoChiavi.daCreare);
  });

  test('un pacchetto che c e vuol dire «da ripristinare»', () async {
    adapter.onGet(
      '/account/recovery-key',
      (s) => s.reply(200, {
        'data': {
          'version': 1,
          'kdf': 'argon2id13',
          'ops_limit': 3,
          'mem_limit': 67108864,
          'salt': 'c2FsdA==',
          'nonce': 'bm9uY2U=',
          'wrapped_key': 'a2V5',
        },
      }),
    );

    expect(await servizio.stato(), StatoChiavi.daRipristinare);
  });

  /// 🚨 **Sbagliare in questa direzione chiede una password di troppo;
  /// sbagliare nell'altra distrugge un account.**
  ///
  /// Se il server non risponde non si può sapere se un pacchetto esista. Andare
  /// su `daCreare` genererebbe una chiave maestra nuova che scriverebbe sopra
  /// quella vera, chiudendo la persona fuori dai propri messaggi per sempre.
  test(
    'se il server non risponde si chiede il ripristino, non si crea',
    () async {
      adapter.onGet(
        '/account/recovery-key',
        (s) => s.throws(
          500,
          DioException(
            requestOptions: RequestOptions(path: '/account/recovery-key'),
          ),
        ),
      );

      expect(await servizio.stato(), StatoChiavi.daRipristinare);
    },
  );
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

/// Un portachiavi vuoto: nei test il Keychain non c'è.
class _PortachiaviFinto implements Portachiavi {
  Uint8List? _chiave;

  @override
  Future<Uint8List?> chiaveMaestra() async => _chiave;

  @override
  Future<void> salvaChiaveMaestra(Uint8List chiave) async => _chiave = chiave;

  @override
  Future<bool> appGiaUsataQui() async => _chiave != null;

  @override
  Future<void> dimenticaChiave() async => _chiave = null;

  @override
  void scordaCache() {}
}
