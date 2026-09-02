import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/core/storage/local_cache.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/diary/data/trasloco_del_diario.dart';

/// Il diario viene a casa — Parte I, I3.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Un trasloco che porta **metà** del diario non dà nessun errore: il telefono
/// scrive quello che riceve, i totali si ricalcolano, e i numeri sembrano veri.
/// ⛔ Mezzo diario è **peggio** di nessun diario.
///
/// 💡 Per questo il conteggio non è un di più: è l'unica cosa che permette di
/// accorgersene. E per questo si riconta **l'archivio**, non la lista appena
/// spedita — fra le due c'è tutto ciò che può andare storto in silenzio.
void main() {
  late Dio dio;
  late DioAdapter rete;
  late ArchivioSalute archivio;
  late _CacheFinta cache;
  late Trasloco trasloco;

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://esempio.test/api/v1',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    rete = DioAdapter(dio: dio);
    dio.httpClientAdapter = rete;

    archivio = ArchivioSalute.inMemoria();
    cache = _CacheFinta();

    trasloco = Trasloco(
      ApiClient(
        config: const AppConfig(
          environment: AppEnvironment.local,
          apiBaseUrl: 'https://esempio.test/api/v1',
          enableDebugTools: true,
        ),
        tokenStore: _TokenFinto(),
        dio: dio,
      ),
      archivio,
      cache,
    );
  });

  tearDown(() => archivio.close());

  Map<String, dynamic> voce(int id, {String giorno = '2026-09-01'}) => {
    'id': id,
    'eaten_at': '${giorno}T00:00:00+00:00',
    'created_at': '${giorno}T10:14:00+00:00',
    'meal': 'lunch',
    'description': 'Pollo',
    // ⚠️ **Stringhe**, come le manda MySQL: è il caso che conta.
    'kcal': '412.50',
    'protein': '38.00',
    'kcal_100': '165.00',
    'source': 'ai_text',
  };

  void rispondiCon({
    required List<Map<String, dynamic>> voci,
    int? quanteDice,
    List<Map<String, dynamic>> preferiti = const [],
  }) {
    rete.onGet(
      '/trasloco/diario',
      (s) => s.reply(200, {
        'data': {
          'quante_voci': quanteDice ?? voci.length,
          'quanti_preferiti': preferiti.length,
          'voci': voci,
          'preferiti': preferiti,
        },
      }),
    );
  }

  group('il trasloco', () {
    test('porta il diario a casa', () async {
      rispondiCon(voci: [voce(1), voce(2, giorno: '2026-09-02')]);

      expect(await trasloco.porta(), EsitoTrasloco.fatto);
      expect(await archivio.quanteVociDelDiario(), 2);
      /*
       * 💡 **La versione, non un «sì»**: il pacchetto cresce, e un numero
       * permette di rifare il trasloco quando guadagna un campo — come è
       * successo col contatore d'uso dei preferiti.
       */
      expect(cache.getString(chiaveTraslocoFatto), '$versioneDelTrasloco');
    });

    test('🚨 i decimali arrivano come stringhe, e non si perdono', () async {
      /*
       * ⛔ `as double?` su una stringa la butterebbe via **in silenzio**, e il
       * diario arriverebbe senza calorie: le voci ci sarebbero tutte, i
       * conteggi tornerebbero, e i totali direbbero zero.
       *
       * 🚨 È il difetto peggiore di questa classe — quello che passa tutti i
       * controlli e si vede solo guardando un giorno vecchio.
       */
      rispondiCon(voci: [voce(1)]);

      await trasloco.porta();

      final righe = await archivio.vociDelGiorno(DateTime(2026, 9, 1));

      expect(righe.single.kcal, 412.5);
      expect(righe.single.proteine, 38);
      expect(righe.single.kcal100, 165);
    });

    test('💡 `created_at` diventa `scrittaIl`', () async {
      /*
       * È il campo che distingue una cena **programmata** alle 10 del mattino da
       * una mangiata alle 21. ⛔ Perderlo nel trasloco vorrebbe dire che il
       * consiglio del giorno torna a sbagliare come prima di 3b-AC — su dati
       * che non si possono più recuperare, perché il server nel frattempo si è
       * svuotato.
       */
      rispondiCon(voci: [voce(1)]);

      await trasloco.porta();

      final riga = (await archivio.vociDelGiorno(DateTime(2026, 9, 1))).single;

      expect(riga.scrittaIl.toUtc().hour, 10);
      expect(riga.mangiatoIl.day, 1);
    });

    test('⛔ se i conteggi non tornano NON si conferma', () async {
      /*
       * 🚨 Il server dice cinque, ne arrivano due. Una risposta troncata, un
       * campo che non si converte, una riga scartata dall'indice: nessuna di
       * queste dà errore.
       *
       * 💡 Non confermare vuol dire **riprovare al prossimo avvio**, ed è la
       * cosa giusta: le righe già scritte non si duplicano.
       */
      rispondiCon(voci: [voce(1), voce(2)], quanteDice: 5);

      expect(await trasloco.porta(), EsitoTrasloco.nonTorna);
      expect(cache.getString(chiaveTraslocoFatto), isNull);
    });

    test('e riprovando dopo un mezzo trasloco non si duplica niente', () async {
      rispondiCon(voci: [voce(1), voce(2)], quanteDice: 5);
      await trasloco.porta();

      rispondiCon(voci: [voce(1), voce(2), voce(3), voce(4), voce(5)]);

      expect(await trasloco.porta(), EsitoTrasloco.fatto);
      expect(
        await archivio.quanteVociDelDiario(),
        5,
        reason:
            'Le due righe del primo giro non devono ricomparire una seconda '
            'volta: ci pensa insertOrIgnore su idSulServer.',
      );
    });

    test('💡 una volta fatto non si rifà', () async {
      rispondiCon(voci: [voce(1)]);
      await trasloco.porta();

      expect(await trasloco.porta(), EsitoTrasloco.giaFatto);
      expect(await archivio.quanteVociDelDiario(), 1);
    });

    test('⛔ senza rete non si conferma, e non si perde niente', () async {
      rete.onGet(
        '/trasloco/diario',
        (s) => s.throws(
          500,
          DioException(requestOptions: RequestOptions(path: '/trasloco/diario')),
        ),
      );

      expect(await trasloco.porta(), EsitoTrasloco.nonRiuscito);
      expect(cache.getString(chiaveTraslocoFatto), isNull);
    });
  });
}

/// 💡 Una cache in memoria: qui interessa **cosa** ci si scrive, non dove.
class _CacheFinta implements LocalCache {
  final _dati = <String, String>{};

  @override
  String? getString(String chiave) => _dati[chiave];

  @override
  Future<void> setString(String chiave, String valore) async =>
      _dati[chiave] = valore;

  @override
  Future<void> remove(String chiave) async => _dati.remove(chiave);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
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
