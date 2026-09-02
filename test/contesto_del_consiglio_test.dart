import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/dashboard/dashboard_controller.dart';
import 'package:training_companion/src/features/health/health_controller.dart';

/// Le due richieste del consiglio mandano **la stessa cosa** — 21/08/2026.
///
/// ── 🚨 Il difetto che questo file impedisce di rifare ──────────────────────
///
/// `adviceProvider` e `rigeneraConsiglioProvider` costruivano il contesto
/// **ognuno per conto suo**, e non erano uguali: «Rigenera» mandava target e
/// recupero, senza la settimana e senza i tipi degli allenamenti.
///
/// 🚨 **Il server mette il contesto nella chiave della cache.** Due contesti
/// diversi sono due `context_hash` diversi, quindi un tocco su «Rigenera»
/// costava **due** chiamate al modello: una con il contesto povero (scritta con
/// l'hash A, e pagata), e subito dopo un'altra con quello pieno, perché la
/// lettura non trovava niente in cache.
///
/// ⚠️ **Non si vedeva da nessuna parte.** Il consiglio arrivava, ed era pure
/// quello giusto: a pagare due volte era solo il conto.
///
/// 💡 Per questo il test non guarda *cosa* c'è nel contesto — quello cambia a
/// ogni fase — ma che i due chiamanti mandino **lo stesso**. È l'invariante che
/// deve sopravvivere alle modifiche future.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late List<Map<String, dynamic>> mandate;

  /// 💡 Da I5.3 `chiediIlConsiglio` scrive il testo nell'archivio: senza, i due
  /// chiamanti non arrivano nemmeno alla richiesta.
  late ArchivioSalute archivio;

  /// Il contesto finto: qui non interessa come nasce, interessa **chi lo usa**.
  const contesto = <String, dynamic>{
    'target_kcal': 2200,
    'sleep_minutes': 430,
    'week_workouts[0][type]': 'STRENGTH_TRAINING',
  };

  setUp(() {
    mandate = [];
    archivio = ArchivioSalute.inMemoria();

    dio = Dio(
      BaseOptions(
        baseUrl: 'https://esempio.test/api/v1',
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    // 💡 In coda agli interceptor veri: legge la richiesta **come parte**, dopo
    // che il client ci ha messo le sue cose.
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (opzioni, avanti) {
          if (opzioni.path.contains('/ai/advice')) {
            mandate.add(Map<String, dynamic>.from(opzioni.queryParameters));
          }

          avanti.next(opzioni);
        },
      ),
    );
  });

  ProviderContainer conta() {
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(
            config: const AppConfig(
              environment: AppEnvironment.local,
              apiBaseUrl: 'https://esempio.test/api/v1',
              enableDebugTools: true,
            ),
            tokenStore: _TokenStoreFinto(),
            dio: dio,
          ),
        ),

        /*
         * 🚨 Si finge **il contesto**, non i quattro provider da cui nasce.
         * Il difetto non era in cosa il contesto contiene: era che ce n'erano
         * **due**. Fingere la sorgente unica e guardare i due chiamanti prova
         * esattamente quello.
         */
        contestoConsiglioProvider.overrideWith((ref) async => contesto),
        archivioSaluteProvider.overrideWithValue(archivio),
      ],
    );

    addTearDown(c.dispose);
    addTearDown(archivio.close);

    return c;
  }

  test('la lettura manda il contesto, tutto intero', () async {
    adapter.onGet(
      '/ai/advice',
      (s) => s.reply(200, {
        'data': {'body': 'Vai di proteine.', 'cached': false},
      }),
      queryParameters: contesto,
    );

    final c = conta();
    final consiglio = await c.read(adviceProvider.future);

    expect(consiglio.testo, 'Vai di proteine.');
    expect(mandate, hasLength(1));
    expect(mandate.first, contesto);
  });

  test('«Rigenera» manda lo STESSO contesto, più `manuale`', () async {
    adapter.onGet(
      '/ai/advice',
      (s) => s.reply(200, {
        'data': {'body': 'Rifatto.', 'cached': false},
      }),
      queryParameters: {'manuale': 1, ...contesto},
    );

    final c = conta();
    await c.read(rigeneraConsiglioProvider)();

    expect(mandate, hasLength(1));

    /*
     * ══ 🚨 L'ASSERZIONE CHE CONTA ═══════════════════════════════════════════
     *
     * Tolto `manuale`, quello che parte deve essere **identico** alla lettura.
     * ⚠️ Se un domani qualcuno aggiunge un campo a una sola delle due strade,
     * qui diventa rosso — invece di diventare una seconda chiamata al modello
     * che nessuno vede.
     */
    final senzaManuale = Map<String, dynamic>.from(mandate.first)
      ..remove('manuale');

    expect(senzaManuale, contesto);
    expect(mandate.first['manuale'], 1);
  });

  test('i due chiamanti mandano la stessa identica mappa', () async {
    adapter
      ..onGet(
        '/ai/advice',
        (s) => s.reply(200, {
          'data': {'body': 'A', 'cached': false},
        }),
        queryParameters: contesto,
      )
      ..onGet(
        '/ai/advice',
        (s) => s.reply(200, {
          'data': {'body': 'B', 'cached': false},
        }),
        queryParameters: {'manuale': 1, ...contesto},
      );

    final c = conta();

    await c.read(adviceProvider.future);
    await c.read(rigeneraConsiglioProvider)();

    expect(mandate, hasLength(2));

    // 💡 Il confronto diretto fra le due: è la frase «lo stesso hash», detta in
    // modo che una macchina la possa controllare.
    final lettura = mandate[0];
    final rigenera = Map<String, dynamic>.from(mandate[1])..remove('manuale');

    expect(rigenera, lettura);
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
