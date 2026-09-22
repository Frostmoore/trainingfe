import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';
import 'package:training_companion/src/features/privacy/consensi_controller.dart';

/// 🔒 **I consensi si rileggono dopo l'accesso** — 22/09/2026.
///
/// ⛔ `FutureProvider` tiene in cache **anche gli errori**. All'avvio l'app
/// chiede i consensi prima che ci sia un token: quella chiamata prende un 401,
/// l'errore resta lì, e la schermata della privacy continua a dire *«Non riesco
/// a leggere i tuoi consensi — Sessione scaduta»* anche dopo un accesso
/// riuscito, mentre tutto il resto dell'app funziona.
///
/// ⚠️ È successo al committente subito dopo un ripristino da file: il server
/// aveva risposto `201` a `PUT /chat-key` e `200` a `/dashboard`, ma la privacy
/// dichiarava morta la sessione. *«Quando faccio il ripristino non deve
/// succedere che mi dica che c'è un problema con i consensi. Follia pura.»*
///
/// 💡 Questo test guarda **quante volte** l'endpoint viene chiamato: è l'unico
/// modo per distinguere «si è ricalcolato» da «ha ridato quello che aveva in
/// tasca». Contare le chiamate prova il meccanismo, non l'effetto.
void main() {
  // L'avvio legge la versione dell'app da un canale di piattaforma.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('un 401 preso da sloggati non sopravvive all\'accesso', () async {
    final rete = _ReteACapriccio();
    final dio = Dio(BaseOptions(baseUrl: 'https://esempio.test/api/v1'))
      ..httpClientAdapter = rete;

    final client = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: _TokenFinto(),
      dio: dio,
    );

    // 🚨 Niente `addTearDown(auth.dispose)`: il notifier lo possiede il
    // contenitore, che lo chiude da solo. Chiuderlo due volte e' un errore.
    final auth = AuthController(client, _TokenFinto());

    final contenitore = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authControllerProvider.overrideWith((ref) => auth),
      ],
    );
    addTearDown(contenitore.dispose);

    // ── 1. Da sloggati: 401, e l'errore finisce in cache.
    await expectLater(
      contenitore.read(consensiProvider.future),
      throwsA(anything),
    );
    expect(rete.consensiChiesti, 1);

    // ── 2. L'accesso.
    await auth.restore();
    expect(auth.state.status, AuthStatus.loggedIn);

    // ── 3. 🚨 I consensi si rileggono **da soli**: nessuno li ha invalidati a
    //       mano, è il provider che guarda chi è entrato.
    final consensi = await contenitore.read(consensiProvider.future);

    expect(rete.consensiChiesti, 2, reason: 'ha riusato l\'errore vecchio');
    expect(consensi.saluteDato, isTrue);
  });
}

/// La rete che risponde 401 la prima volta e 200 dalla seconda.
class _ReteACapriccio implements HttpClientAdapter {
  int consensiChiesti = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.path.endsWith('/account/consents')) {
      consensiChiesti++;

      return consensiChiesti == 1
          ? _risposta(401, {'message': 'Unauthenticated.'})
          : _risposta(200, {
              'data': {'health': '2026-09-01T10:00:00Z'},
            });
    }

    if (options.path.endsWith('/auth/me')) {
      return _risposta(200, {
        'data': {'id': 13, 'name': 'Riccardo', 'email': 'r@esempio.test'},
      });
    }

    // Il fuso orario e qualunque altra cortesia dell'avvio.
    return _risposta(200, {'data': <String, dynamic>{}});
  }

  ResponseBody _risposta(int codice, Map<String, dynamic> corpo) =>
      ResponseBody.fromString(
        jsonEncode(corpo),
        codice,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
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
