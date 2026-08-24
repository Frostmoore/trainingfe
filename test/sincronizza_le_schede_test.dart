import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/training/sincronizza_le_schede.dart';

/// La sincronizzazione delle schede — 3b-B.16, 24/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// 📌 *«le schede sul server si sincronizzano sul telefono quando apro l'app e
/// per le modifiche vince sempre la più recente … perché potrei non avere rete
/// quando mi alleno»*.
///
/// ⛔ **Una sincronizzazione sbagliata non dà errori: cancella lavoro.** È
/// esattamente la famiglia di difetti che ha fatto perdere due esercizi al
/// committente il 24/08, e l'unico modo di tenerla ferma è provare **una per
/// una** le righe della tabella delle decisioni.
void main() {
  late Dio dio;
  late DioAdapter rete;
  late ApiClient api;
  late ArchivioSalute archivio;
  late SincronizzaLeSchede sincronizza;

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://esempio.test/api/v1',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    rete = DioAdapter(dio: dio);
    dio.httpClientAdapter = rete;

    api = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: _TokenFinto(),
      dio: dio,
    );

    archivio = ArchivioSalute.inMemoria();
    sincronizza = SincronizzaLeSchede(api: api, archivio: archivio);
  });

  tearDown(() => archivio.close());

  Map<String, dynamic> scheda({
    int id = 8,
    String nome = 'Giorno 1',
    required String quando,
    bool modificabile = true,
    List<String> esercizi = const ['Piegamenti'],
  }) => {
    'id': id,
    'name': nome,
    'updated_at': quando,
    'editable': modificabile,
    'exercises': [
      for (final e in esercizi)
        {
          'id': esercizi.indexOf(e) + 1,
          'exercise': {'id': 100 + esercizi.indexOf(e), 'name': e},
          'prescription': '4 × 15',
          'sets': 4,
          'reps': '15',
          'rest_sec': 60,
        },
    ],
  };

  void elenco(List<Map<String, dynamic>> schede) {
    rete.onGet('/workout-plans', (s) => s.reply(200, {'data': schede}));
  }

  void dettaglio(Map<String, dynamic> s) {
    rete.onGet('/workout-plans/${s['id']}', (r) => r.reply(200, {'data': s}));
  }

  // ═══════════════════ riga 1: non ce l'abbiamo ═══════════════════

  test('una scheda che il telefono non ha, se la prende', () async {
    final s = scheda(quando: '2026-08-24T10:00:00Z');
    elenco([s]);
    dettaglio(s);

    final esito = await sincronizza.gira();

    expect(esito.tirate, 1);

    final locale = await archivio.schedaSulTelefono(8);

    expect(locale, isNotNull);
    expect(locale!.nome, 'Giorno 1');
    expect(
      locale.modificataQuiIl,
      isNull,
      reason:
          'Appena arrivata dal server è pulita: non c\'è niente da spingere.',
    );
  });

  // ═══════════════════ riga 2: pulita → vince il server ═══════════════════

  test('se la copia locale è pulita vince il server', () async {
    final vecchia = scheda(quando: '2026-08-24T10:00:00Z');
    elenco([vecchia]);
    dettaglio(vecchia);
    await sincronizza.gira();

    final nuova = scheda(
      quando: '2026-08-24T18:00:00Z',
      esercizi: ['Piegamenti', 'Crunch'],
    );
    elenco([nuova]);
    dettaglio(nuova);

    final esito = await sincronizza.gira();

    expect(esito.tirate, 1);
    expect(esito.spinte, 0);

    final locale = await archivio.schedaSulTelefono(8);
    final dentro = jsonDecode(locale!.scheda) as Map<String, dynamic>;

    expect((dentro['exercises'] as List).length, 2);
  });

  /// 💡 E se non è cambiato niente, non si scarica niente: in palestra la rete
  /// è quella che è, e riscaricare tutto a ogni apertura è traffico per niente.
  test('e se il server non è cambiato non si tira niente', () async {
    final s = scheda(quando: '2026-08-24T10:00:00Z');
    elenco([s]);
    dettaglio(s);
    await sincronizza.gira();

    elenco([s]);
    final esito = await sincronizza.gira();

    expect(esito.tirate, 0);
    expect(esito.haFattoQualcosa, isFalse);
  });

  // ═══════════════ riga 3: sporca e il server è fermo ═══════════════

  test('se il telefono ha modifiche e il server è fermo, si spinge', () async {
    final s = scheda(quando: '2026-08-24T10:00:00Z');
    elenco([s]);
    dettaglio(s);
    await sincronizza.gira();

    await archivio.scriviSchedaModificataQui(
      idServer: 8,
      nome: 'Giorno 1',
      scheda: jsonEncode(
        scheda(
          quando: '2026-08-24T10:00:00Z',
          esercizi: ['Piegamenti', 'Curl Invertito (Manubrio)'],
        ),
      ),
    );

    elenco([s]);
    rete.onPut(
      '/workout-plans/8',
      (r) => r.reply(200, {
        'data': scheda(
          quando: '2026-08-24T19:00:00Z',
          esercizi: ['Piegamenti', 'Curl Invertito (Manubrio)'],
        ),
      }),
      data: Matchers.any,
    );

    final esito = await sincronizza.gira();

    expect(esito.spinte, 1);

    final locale = await archivio.schedaSulTelefono(8);

    expect(
      locale!.modificataQuiIl,
      isNull,
      reason: 'Spinta riuscita: da qui la copia locale è pulita.',
    );
  });

  /// ══ ⛔ IL TEST CHE VALE PIÙ DI TUTTI QUI ═══════════════════════════════
  ///
  /// 🚨 **Se la spinta fallisce, la copia locale resta sporca.** Un fallimento
  /// che azzera il segno è un fallimento che **cancella il lavoro**: alla
  /// prossima apertura la modifica non verrebbe più spinta, e sparirebbe alla
  /// prima tirata.
  test('ma se la spinta fallisce la modifica NON si perde', () async {
    final s = scheda(quando: '2026-08-24T10:00:00Z');
    elenco([s]);
    dettaglio(s);
    await sincronizza.gira();

    await archivio.scriviSchedaModificataQui(
      idServer: 8,
      nome: 'Giorno 1',
      scheda: jsonEncode(scheda(quando: '2026-08-24T10:00:00Z')),
    );

    elenco([s]);
    rete.onPut(
      '/workout-plans/8',
      (r) => r.throws(500, DioException(requestOptions: RequestOptions())),
      data: Matchers.any,
    );

    final esito = await sincronizza.gira();

    expect(esito.spinte, 0);

    final locale = await archivio.schedaSulTelefono(8);

    expect(
      locale!.modificataQuiIl,
      isNotNull,
      reason: 'La modifica è stata dimenticata: alla prossima tirata sparisce.',
    );
  });

  // ═══════════════ riga 4: conflitto vero ═══════════════

  /// ⚠️ **Qui e solo qui i due orologi si incontrano**: cambiata sul telefono
  /// *e* sul server fra due aperture. Vince la più recente, come chiesto.
  test('conflitto vero: se il telefono è più recente, vince lui', () async {
    final s = scheda(quando: '2026-08-24T10:00:00Z');
    elenco([s]);
    dettaglio(s);
    await sincronizza.gira();

    await archivio.scriviSchedaModificataQui(
      idServer: 8,
      nome: 'Dal telefono',
      scheda: jsonEncode(
        scheda(nome: 'Dal telefono', quando: '2026-08-24T10:00:00Z'),
      ),
      quando: DateTime.utc(2026, 8, 24, 20),
    );

    // Il server è cambiato, ma **prima** della modifica sul telefono.
    final suServer = scheda(
      nome: 'Dal pannello',
      quando: '2026-08-24T12:00:00Z',
    );
    elenco([suServer]);
    rete.onPut(
      '/workout-plans/8',
      (r) => r.reply(200, {
        'data': scheda(nome: 'Dal telefono', quando: '2026-08-24T21:00:00Z'),
      }),
      data: Matchers.any,
    );

    final esito = await sincronizza.gira();

    expect(esito.conflitti, 1);
    expect(esito.spinte, 1);
    expect((await archivio.schedaSulTelefono(8))!.nome, 'Dal telefono');
  });

  /// ⛔ **E la copia che perde non si butta.** Buttarla sarebbe il difetto del
  /// 24/08 con un altro nome: una modifica vera che sparisce senza che nessuno
  /// lo dica.
  test(
    'conflitto vero: se vince il server, la copia locale si tiene',
    () async {
      final s = scheda(quando: '2026-08-24T10:00:00Z');
      elenco([s]);
      dettaglio(s);
      await sincronizza.gira();

      await archivio.scriviSchedaModificataQui(
        idServer: 8,
        nome: 'Dal telefono',
        scheda: jsonEncode(
          scheda(nome: 'Dal telefono', quando: '2026-08-24T10:00:00Z'),
        ),
        quando: DateTime.utc(2026, 8, 24, 11),
      );

      // Il server è cambiato **dopo** la modifica sul telefono.
      final suServer = scheda(
        nome: 'Dal pannello',
        quando: '2026-08-24T20:00:00Z',
      );
      elenco([suServer]);
      dettaglio(suServer);

      final esito = await sincronizza.gira();

      expect(esito.conflitti, 1);

      final locale = await archivio.schedaSulTelefono(8);

      expect(locale!.nome, 'Dal pannello');
      expect(
        locale.scartata,
        isNotNull,
        reason:
            'La copia che ha perso è stata buttata invece di tenerla da parte.',
      );
      expect(
        (jsonDecode(locale.scartata!) as Map<String, dynamic>)['name'],
        'Dal telefono',
      );
    },
  );

  // ═══════════════ senza rete ═══════════════

  /// ══ 📌 IL CASO PER CUI TUTTO QUESTO ESISTE ═════════════════════════════
  ///
  /// *«perché potrei non avere rete quando mi alleno»*.
  ///
  /// ⛔ Senza rete non si tocca niente e non si urla: quello che c'è sul
  /// telefono resta buono, e si riprova alla prossima apertura.
  test('senza rete non si tocca niente', () async {
    final s = scheda(quando: '2026-08-24T10:00:00Z');
    elenco([s]);
    dettaglio(s);
    await sincronizza.gira();

    rete.onGet(
      '/workout-plans',
      (r) => r.throws(500, DioException(requestOptions: RequestOptions())),
    );

    final esito = await sincronizza.gira();

    expect(esito.senzaRete, isTrue);
    expect(esito.haFattoQualcosa, isFalse);
    expect(
      await archivio.schedaSulTelefono(8),
      isNotNull,
      reason: 'La scheda è sparita dal telefono proprio quando serviva.',
    );
  });

  // ═══════════════ le sparite ═══════════════

  test(
    'una scheda cancellata dal server sparisce anche dal telefono',
    () async {
      final s = scheda(quando: '2026-08-24T10:00:00Z');
      elenco([s]);
      dettaglio(s);
      await sincronizza.gira();

      elenco([]);
      final esito = await sincronizza.gira();

      expect(esito.tolte, 1);
      expect(await archivio.schedaSulTelefono(8), isNull);
    },
  );

  /// ⛔ **Ma non se ha modifiche non spinte.** Cancellarla butterebbe il lavoro
  /// di chi l'ha modificata mentre era senza rete.
  test('ma non se ha modifiche non ancora spinte', () async {
    final s = scheda(quando: '2026-08-24T10:00:00Z');
    elenco([s]);
    dettaglio(s);
    await sincronizza.gira();

    await archivio.scriviSchedaModificataQui(
      idServer: 8,
      nome: 'Giorno 1',
      scheda: jsonEncode(s),
    );

    elenco([]);
    final esito = await sincronizza.gira();

    expect(esito.tolte, 0);
    expect(await archivio.schedaSulTelefono(8), isNotNull);
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
