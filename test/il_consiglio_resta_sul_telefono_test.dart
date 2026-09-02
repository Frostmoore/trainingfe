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

/// Il consiglio del giorno vive qui — Parte I, I5.3.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Da I5.3 il server **non conserva più il testo**: `ai_advices.body` non
/// esiste, e quella tabella è rimasta il registro delle fasce. ⛔ Il testo esce
/// una volta sola — nella risposta della generazione — e se l'app non lo scrive,
/// **è perso**: la lettura successiva trova `cached: true` e niente da mostrare.
///
/// 🚨 È un difetto che non darebbe nessun errore: il consiglio semplicemente
/// smetterebbe di comparire dopo il primo caricamento della giornata.
void main() {
  late Dio dio;
  late DioAdapter rete;
  late ArchivioSalute archivio;

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
  });

  tearDown(() => archivio.close());

  ApiClient client() => ApiClient(
    config: const AppConfig(
      environment: AppEnvironment.local,
      apiBaseUrl: 'https://esempio.test/api/v1',
      enableDebugTools: true,
    ),
    tokenStore: _TokenFinto(),
    dio: dio,
  );

  /// 💡 Un provider usa-e-getta: `chiediIlConsiglio` vuole un `Ref`, e un
  /// `ProviderContainer` non lo è.
  final prova = FutureProvider<Consiglio>(
    (ref) => chiediIlConsiglio(ref, const {}),
  );

  Future<Consiglio> chiedi() {
    final contenitore = ProviderContainer(
      overrides: [
        archivioSaluteProvider.overrideWithValue(archivio),
        apiClientProvider.overrideWithValue(client()),
      ],
    );

    addTearDown(contenitore.dispose);

    return contenitore.read(prova.future);
  }

  void rispondiCon(Map<String, dynamic>? data) {
    rete.onGet(
      '/ai/advice',
      (s) => s.reply(200, {'data': data}),
      queryParameters: {},
    );
  }

  group('🎉 quando il consiglio è appena nato', () {
    test('si mostra e si scrive, perché il server non lo terrà', () async {
      rispondiCon({
        'body': 'Ti mancano 30 g di proteine.',
        'cached': false,
        'fascia': '2026-09-03T09',
        'generated_at': '2026-09-03T07:15:00Z',
      });

      final consiglio = await chiedi();

      expect(consiglio.testo, 'Ti mancano 30 g di proteine.');

      // 🚨 E soprattutto: è finito nell'archivio.
      final salvato = await archivio.consiglioDellaFascia('2026-09-03T09');

      expect(salvato, isNotNull);
      expect(salvato!.testo, 'Ti mancano 30 g di proteine.');
    });
  });

  group('🔁 quando il server dice «ce l\'hai già»', () {
    test('si rilegge dall\'archivio, con la sua data', () async {
      await archivio.scriviConsiglio(
        fascia: '2026-09-03T09',
        testo: 'Il consiglio di stamattina.',
        generatoIl: DateTime(2026, 9, 3, 9, 15),
      );

      rispondiCon({
        'body': null,
        'cached': true,
        'fascia': '2026-09-03T09',
        'generated_at': '2026-09-03T07:15:00Z',
      });

      final consiglio = await chiedi();

      expect(consiglio.testo, 'Il consiglio di stamattina.');
      expect(consiglio.generatoIl, DateTime(2026, 9, 3, 9, 15));
    });

    test('⚠️ e se di QUELLA fascia non c\'è, si mostra l\'ultimo che c\'è', () async {
      /*
       * 💡 È la stessa scelta che il server faceva restituendo l'ultimo invece
       * di `null`: 📌 *«l'app lo mostra con la sua data, e chi legge vede che è
       * di prima»*.
       */
      await archivio.scriviConsiglio(
        fascia: '2026-09-02T22',
        testo: 'Quello di ieri sera.',
        generatoIl: DateTime(2026, 9, 2, 22, 30),
      );

      rispondiCon({
        'body': null,
        'cached': true,
        'fascia': '2026-09-03T09',
        'generated_at': '2026-09-03T07:15:00Z',
      });

      expect((await chiedi()).testo, 'Quello di ieri sera.');
    });

    test('⛔ e se questo telefono non ha niente, non si inventa', () async {
      /*
       * 🚨 Reinstallazione, dati cancellati, un secondo telefono: il testo sul
       * server non c'è più, e nessuno può rimediare. ⚠️ Meglio niente che un
       * consiglio di un altro giorno spacciato per quello di oggi.
       */
      rispondiCon({
        'body': null,
        'cached': true,
        'fascia': '2026-09-03T09',
        'generated_at': '2026-09-03T07:15:00Z',
      });

      expect((await chiedi()).testo, isNull);
    });
  });

  group('🚨 `data: null` non è un guasto', () {
    test('con l\'aggiornamento spento si mostra comunque quello che c\'è', () async {
      /*
       * ⛔ Il server risponde `data: null` quando l'interruttore automatico è
       * spento e non c'è niente in cache. ⚠️ Prima quel caso diventava un
       * `TypeError` raccolto dal `catch` generico — cioè un consiglio vuoto
       * invece del ricordo locale. 📌 *«Spegnere l'aggiornamento non vuol dire
       * cancellare quello che c'è»*.
       */
      await archivio.scriviConsiglio(
        fascia: '2026-09-03T09',
        testo: 'Quello di stamattina.',
        generatoIl: DateTime(2026, 9, 3, 9, 15),
      );

      rispondiCon(null);

      expect((await chiedi()).testo, 'Quello di stamattina.');
    });
  });

  group('✂️ tre righe al massimo', () {
    test('la quarta fa cadere la più vecchia', () async {
      /*
       * 📌 *«perché dovremmo salvare il consiglio del giorno? L'utente lo vede
       * quel giorno e via»*. 🚨 Tre sono le fasce di una giornata: serve poter
       * mostrare quello di stamattina quando quello delle 14 non è ancora nato.
       */
      for (final (i, fascia) in [
        '2026-09-02T14',
        '2026-09-02T22',
        '2026-09-03T09',
        '2026-09-03T14',
      ].indexed) {
        await archivio.scriviConsiglio(
          fascia: fascia,
          testo: 'Consiglio $i',
          generatoIl: DateTime(2026, 9, 2).add(Duration(hours: i * 6)),
        );
      }

      expect(await archivio.consiglioDellaFascia('2026-09-02T14'), isNull);
      expect(await archivio.consiglioDellaFascia('2026-09-03T14'), isNotNull);
      expect((await archivio.ultimoConsiglio())!.testo, 'Consiglio 3');
    });

    test('💡 e riscrivere la stessa fascia non aggiunge una riga', () async {
      // ⚠️ Senza l'indice unico su `fascia`, `insertOnConflictUpdate` non
      // avrebbe niente su cui riconoscere il conflitto.
      await archivio.scriviConsiglio(
        fascia: '2026-09-03T09',
        testo: 'Primo',
        generatoIl: DateTime(2026, 9, 3, 9),
      );
      await archivio.scriviConsiglio(
        fascia: '2026-09-03T09',
        testo: 'Rigenerato',
        generatoIl: DateTime(2026, 9, 3, 9, 30),
      );

      expect(
        (await archivio.consiglioDellaFascia('2026-09-03T09'))!.testo,
        'Rigenerato',
      );
      expect((await archivio.esportaPerBackup())['consigli_del_giorno'], hasLength(1));
    });
  });

  group('💾 e finisce nel backup da solo', () {
    /*
     * 🚨 **Regola R4**: *«ogni dato o file nuovo deve finire nel backup, e la
     * domanda si fa quando lo si crea»*. 💡 Qui la risposta è sì per
     * costruzione — `esportaPerBackup()` enumera `allTables` — e questo test lo
     * verifica invece di darlo per scontato.
     */
    test('l\'esportazione lo comprende senza che nessuno lo elenchi', () async {
      await archivio.scriviConsiglio(
        fascia: '2026-09-03T09',
        testo: 'Il consiglio.',
        generatoIl: DateTime(2026, 9, 3, 9),
      );

      final backup = await archivio.esportaPerBackup();

      expect(backup['consigli_del_giorno'], hasLength(1));
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
