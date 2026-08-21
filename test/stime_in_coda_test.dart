import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/storage/local_cache.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/diary/data/stime_in_coda.dart';

/// L'attesa delle stime, dal lato dell'app — FASE 9, 21/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// 📌 Il committente: *«ovvio che ci deve essere un sistema che gli dica "sto
/// pensando" finché non ha fatto»*.
///
/// ⚠️ Ma la cosa che questi test proteggono davvero è **l'id in sospeso**. Se
/// l'app viene chiusa mentre il server pensa, il lavoro continua: al rientro va
/// **ritrovato**, non rifatto. 🚨 Rifarlo vorrebbe dire una seconda chiamata al
/// modello per lo stesso piatto — pagata due volte, e senza che nessuno se ne
/// accorga, perché il piatto arriva comunque.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late LocalCache cache;
  late StimeInCoda coda;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache(await SharedPreferences.getInstance());

    dio = Dio(
      BaseOptions(
        baseUrl: 'https://esempio.test/api/v1',
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    coda = StimeInCoda(
      ApiClient(
        config: const AppConfig(
          environment: AppEnvironment.local,
          apiBaseUrl: 'https://esempio.test/api/v1',
          enableDebugTools: true,
        ),
        tokenStore: _TokenStoreFinto(),
        dio: dio,
      ),
      cache,
    );
  });

  void accodaRisponde(int id) {
    adapter.onPost(
      '/ai/food/text',
      (s) => s.reply(202, {
        'data': {'id': id, 'stato': 'in_coda'},
      }),
      data: Matchers.any,
    );
  }

  void statoRisponde(int id, Map<String, dynamic> dati) {
    adapter.onGet('/ai/food/stime/$id', (s) => s.reply(200, {'data': dati}));
  }

  test('l\'id si scrive PRIMA di aspettare', () async {
    /*
     * 🚨 È l'invariante di tutta la FASE 9.7. Fra l'accodamento e la prima
     * risposta l'app può essere chiusa — è esattamente il caso da gestire — e un
     * id scritto dopo sarebbe un id che non esiste mai.
     */
    accodaRisponde(941);

    final id = await coda.accodaTesto(
      testo: 'pasta al pomodoro',
      pasto: 'lunch',
      quando: DateTime(2026, 8, 21),
    );

    expect(id, 941);
    expect(cache.getString(StimeInCoda.chiaveInSospeso), '941');
  });

  test('aspetta finché non è pronta, e poi dimentica l\'id', () async {
    accodaRisponde(7);

    /*
     * 💡 Prima «in lavorazione», poi «pronta»: è la sequenza vera, e serve a
     * provare che il ciclo **non si ferma al primo giro**.
     *
     * ⚠️ Si pilota con un interceptor e non con `DioAdapter`: quest'ultimo
     * costruisce la risposta **una volta sola**, alla registrazione, quindi
     * avrebbe risposto «in lavorazione» per sempre — e il test sarebbe **scaduto
     * invece di fallire**, che è il modo peggiore di sbagliare un test.
     */
    var quante = 0;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opzioni, avanti) {
          if (!opzioni.path.contains('/ai/food/stime/7')) {
            avanti.next(opzioni);

            return;
          }

          quante++;

          avanti.resolve(
            Response<Map<String, dynamic>>(
              requestOptions: opzioni,
              statusCode: 200,
              data: {
                'data': quante == 1
                    ? {'id': 7, 'stato': 'in_lavorazione', 'risultato': null}
                    : {
                        'id': 7,
                        'stato': 'pronta',
                        'risultato': {
                          'estimate': {'items': <String>[], 'confidence': 0.9},
                          'warnings': <String>[],
                          'entries': <String>[],
                          'saved': false,
                        },
                      },
              },
            ),
          );
        },
      ),
    );

    final id = await coda.accodaTesto(
      testo: 'mela',
      pasto: 'snack',
      quando: DateTime(2026, 8, 21),
    );

    final risultato = await coda.aspetta(id, passo: Duration.zero);

    expect(risultato.risultato['saved'], false);

    // 💡 Il pasto e l'origine viaggiano con la stima: servono a riaprire il
    // foglio di conferma nel pasto giusto (FASE 9.7).
    expect(risultato.daFoto, false);
    expect(quante, greaterThan(1), reason: 'Si è fermata al primo giro.');

    // ⚠️ L'id se ne va: se restasse, al riavvio l'app aspetterebbe una stima
    // già consegnata — cioè una rotellina che non finisce mai.
    expect(cache.getString(StimeInCoda.chiaveInSospeso), isNull);
  });

  test('una stima fallita dice il perché, e in italiano', () async {
    accodaRisponde(3);
    statoRisponde(3, {
      'id': 3,
      'stato': 'fallita',
      'errore': 'foto_non_leggibile',
    });

    final id = await coda.accodaTesto(
      testo: 'x',
      pasto: 'lunch',
      quando: DateTime(2026, 8, 21),
    );

    /*
     * 💡 Il server manda un **codice**, non una frase: una frase italiana scritta
     * nel suo database è una frase che un domani non si traduce. Il testo per la
     * persona lo compone l'app, ed è questo che si verifica.
     */
    await expectLater(
      coda.aspetta(id, passo: Duration.zero),
      throwsA(
        isA<StimaFallita>()
            .having((e) => e.codice, 'codice', 'foto_non_leggibile')
            .having(
              (e) => e.perUnaPersona,
              'testo',
              contains('Riprova a scattarla'),
            ),
      ),
    );

    expect(cache.getString(StimeInCoda.chiaveInSospeso), isNull);
  });

  test('l\'id in sospeso si ritrova senza chiedere al server', () async {
    await cache.setString(StimeInCoda.chiaveInSospeso, '55');

    // 🚨 Nessuna rotta registrata su `/in-corso`: se il codice ci passasse, il
    // test fallirebbe. È il modo di provare che l'id locale viene **prima**.
    expect(await coda.inSospeso(), 55);
  });

  test('senza id locale lo chiede al server', () async {
    adapter.onGet(
      '/ai/food/stime/in-corso',
      (s) => s.reply(200, {
        'data': {'id': 88, 'stato': 'in_coda'},
      }),
    );

    expect(await coda.inSospeso(), 88);

    // 💡 E se lo scrive: la volta dopo non serve chiedere.
    expect(cache.getString(StimeInCoda.chiaveInSospeso), '88');
  });

  test('quando non c\'è niente in sospeso torna null', () async {
    adapter.onGet(
      '/ai/food/stime/in-corso',
      (s) => s.reply(200, {'data': null}),
    );

    expect(await coda.inSospeso(), isNull);
  });

  test('un guasto nel recupero non impedisce di scrivere un piatto', () async {
    /*
     * ⚠️ Il recupero è un di più: se la rotta non risponde, al peggio si perde
     * una stima vecchia. 🚨 Farlo lanciare bloccherebbe l'apertura del foglio
     * del cibo per un problema che non c'entra niente con quello che la persona
     * sta facendo adesso.
     */
    adapter.onGet(
      '/ai/food/stime/in-corso',
      (s) => s.throws(500, DioException(requestOptions: RequestOptions())),
    );

    expect(await coda.inSospeso(), isNull);
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
