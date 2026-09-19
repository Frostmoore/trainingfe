import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/core/storage/local_cache.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/profile/data/profile_models.dart';
import 'package:training_companion/src/features/profile/data/profilo_sul_telefono.dart';
import 'package:training_companion/src/features/profile/trasloco_del_profilo.dart';

/// 📱 **Il profilo sta sul telefono** — 19/09/2026.
///
/// 📌 Il committente: *«assicurati che non ci scriva niente di personale
/// (esattamente come peso altezza e data di nascita)»*. ⛔ Fino al 19/09 sesso,
/// data di nascita, altezza e il resto andavano al server con `PATCH /profile`.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  group('la forma di prima, calcolata qui', () {
    test('dice cosa manca, e il peso manca sempre', () {
      final p = UserProfile.fromJson(profiloComeLoMandavaIlServer({}));

      expect(p.missing, ['weight_kg', 'sex', 'birthdate', 'height_cm']);
      expect(p.goals, isNotEmpty);
      expect(p.activityLevels, isNotEmpty);
    });

    test('con i dati c\'è l\'età, e mancano solo il peso', () {
      final p = UserProfile.fromJson(
        profiloComeLoMandavaIlServer({
          'sex': 'm',
          'birthdate': '1988-04-12',
          'height_cm': 178,
        }, oggi: DateTime(2026, 9, 19)),
      );

      expect(p.age, 38);
      expect(p.heightCm, 178);
      expect(p.missing, ['weight_kg']);
    });

    test('sempre i sei pasti, con quelli scelti sopra quelli di serie', () {
      final p = UserProfile.fromJson(
        profiloComeLoMandavaIlServer({
          'meal_hours': {'dinner': '19:00', 'cena': '21:00'},
        }),
      );

      expect(p.mealHours, hasLength(6));
      expect(p.mealHours['dinner'], '19:00');
      expect(p.mealHours['breakfast'], '07:00');
    });
  });

  group('l\'archivio del profilo', () {
    test('scrive solo i campi passati, e un campo null si svuota', () async {
      await archivio.scriviNelProfilo(1, {
        'height_cm': 180,
        'goal': 'maintain',
      });
      await archivio.scriviNelProfilo(1, {'sex': 'f', 'goal': null});

      final dati = await archivio.leggiProfilo(1);

      expect(dati['height_cm'], 180);
      expect(dati['sex'], 'f');
      expect(dati.containsKey('goal'), isTrue);
      expect(dati['goal'], isNull);
    });

    /// ⚠️ Due persone sullo stesso telefono non si incontrano (DA-FARE §0).
    test('è per persona', () async {
      await archivio.scriviNelProfilo(1, {'height_cm': 180});

      expect(await archivio.leggiProfilo(2), isEmpty);
    });
  });

  group('il trasloco dal server', () {
    late DioAdapter rete;
    late ApiClient api;
    late LocalCache cache;
    late List<String> chiamate;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      cache = LocalCache(await SharedPreferences.getInstance());

      final dio = Dio(
        BaseOptions(
          baseUrl: 'https://esempio.test/api/v1',
          validateStatus: (s) => s != null && s < 500,
        ),
      );
      rete = DioAdapter(dio: dio);
      dio.httpClientAdapter = rete;
      chiamate = [];

      /*
       * ⚠️ **Le richieste vere si contano qui, non dentro i mock**: in
       * `http_mock_adapter` la funzione del mock gira quando lo si REGISTRA,
       * non quando arriva la richiesta. Contare là dentro dà sempre lo stesso
       * elenco, qualunque cosa faccia il codice.
       */
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (o, h) {
            chiamate.add(o.method);
            h.next(o);
          },
        ),
      );

      api = ApiClient(
        config: const AppConfig(
          environment: AppEnvironment.local,
          apiBaseUrl: 'https://esempio.test/api/v1',
          enableDebugTools: true,
        ),
        tokenStore: _TokenFinto(),
        dio: dio,
      );
    });

    void ilServerHa(Map<String, dynamic> profilo) {
      rete.onGet('/profile', (r) => r.reply(200, {'data': profilo}));
      rete.onDelete('/profile', (r) => r.reply(200, {'message': 'ok'}));
    }

    test('porta a casa i dati, POI li cancella dal server', () async {
      ilServerHa({
        'sex': 'm',
        'birthdate': '1988-04-12',
        'height_cm': 178,
        'goal': 'lose_slow',
        'meal_hours': {...orariDiSerie, 'dinner': '19:30'},
      });

      final esito = await TraslocoDelProfilo(api, archivio, cache).porta(7);
      final dati = await archivio.leggiProfilo(7);

      expect(esito, EsitoTraslocoProfilo.fatto);
      expect(chiamate, [
        'GET',
        'DELETE',
      ], reason: 'Prima si legge, poi si cancella.');
      expect(dati['height_cm'], 178);
      expect(dati['birthdate'], '1988-04-12');

      // ⚠️ Solo l'orario scelto: quelli di serie non si scrivono come «scelti».
      expect(dati['meal_hours'], {'dinner': '19:30'});
    });

    test('quello già scritto sul telefono vince', () async {
      await archivio.scriviNelProfilo(7, {'height_cm': 181});
      ilServerHa({'height_cm': 178, 'sex': 'm'});

      await TraslocoDelProfilo(api, archivio, cache).porta(7);

      expect((await archivio.leggiProfilo(7))['height_cm'], 181);
    });

    test('una volta sola', () async {
      ilServerHa({'height_cm': 178});

      final trasloco = TraslocoDelProfilo(api, archivio, cache);
      await trasloco.porta(7);
      chiamate.clear();

      expect(await trasloco.porta(7), EsitoTraslocoProfilo.giaFatto);
      expect(chiamate, isEmpty);
    });

    /// 🚨 Senza rete non si cancella niente, e si riprova.
    test('se il server non risponde non si cancella niente', () async {
      rete.onGet(
        '/profile',
        (r) => r.throws(500, DioException(requestOptions: RequestOptions())),
      );
      rete.onDelete('/profile', (r) => r.reply(200, {}));

      final esito = await TraslocoDelProfilo(api, archivio, cache).porta(7);

      expect(esito, EsitoTraslocoProfilo.rete);
      expect(chiamate, ['GET'], reason: 'Nessun DELETE dopo un GET fallito.');
      expect(cache.getString(TraslocoDelProfilo.chiave(7)), isNull);
    });
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
