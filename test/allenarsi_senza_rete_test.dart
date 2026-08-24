import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/health/health_controller.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/session_controller.dart';
import 'package:training_companion/src/features/training/training_controller.dart';

/// Allenarsi **senza rete** — 3b-B.16.12, 24/08/2026.
///
/// ══ 📌 IL CASO PER CUI TUTTO B.16 ESISTE ══════════════════════════════════
///
/// *«L'allenamento e le schede devono essere solide come il marmo … tutto deve
/// stare sul telefono … perché potrei non avere rete quando mi alleno»*.
///
/// ⛔ Prima di oggi, in una palestra senza campo:
///
/// | Cosa | Cosa succedeva |
/// |---|---|
/// | aprire la scheda | `planDetailProvider` andava al server: **l'allenamento non partiva** |
/// | registrare una serie | `logSet` chiedeva l'id al server: **la serie non si salvava** |
///
/// 🚨 Due modi diversi di dire la stessa cosa: l'app rifiutava di registrare
/// l'allenamento **che stavi facendo**. Questo file gira con la rete staccata e
/// pretende che tutto funzioni lo stesso.
void main() {
  late Dio dio;
  late DioAdapter rete;
  late ArchivioSalute archivio;
  late ProviderContainer contenitore;

  /// Una rete che non risponde a niente: è il punto del file.
  void staccaLaRete() {
    for (final rotta in ['/workout-plans', '/workout-plans/8', '/exercises']) {
      rete.onGet(
        rotta,
        (r) => r.throws(500, DioException(requestOptions: RequestOptions())),
      );
      rete.onPost(
        rotta,
        (r) => r.throws(500, DioException(requestOptions: RequestOptions())),
        data: Matchers.any,
      );
    }
  }

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
        archivioSaluteProvider.overrideWithValue(archivio),
      ],
    );
  });

  tearDown(() {
    contenitore.dispose();
    archivio.close();
  });

  /// Lo stesso ambiente, con dentro il catalogo che il telefono ha già.
  ProviderContainer conIlCatalogo(CatalogoEsercizi catalogo) {
    final c = ProviderContainer(
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
        archivioSaluteProvider.overrideWithValue(archivio),
        catalogoEserciziProvider.overrideWith((ref) async => catalogo),
      ],
    );

    addTearDown(c.dispose);

    return c;
  }

  /// La scheda com'è arrivata l'ultima volta che c'era campo.
  Future<void> laSchedaEGiaSulTelefono() => archivio.scriviSchedaDalServer(
    idServer: 8,
    nome: 'Giorno 1',
    aggiornataIlServer: DateTime.utc(2026, 8, 24, 10),
    modificabile: true,
    scheda: jsonEncode({
      'id': 8,
      'name': 'Giorno 1',
      'editable': true,
      'updated_at': '2026-08-24T10:00:00Z',
      'exercises': [
        {
          'id': 1,
          'exercise': {'id': 126, 'name': 'Calf Raise Gamba Singola in Piedi'},
          'prescription': '4 × 35',
          'rest_sec': 60,
        },
        {
          'id': 2,
          'exercise': {'id': 127, 'name': 'Calf Press (Macchina)'},
          'prescription': '4 × 35',
          'rest_sec': 30,
        },
      ],
    }),
  );

  /// ⛔ **La scheda si apre lo stesso.** Era il primo muro: senza campo il
  /// player non riusciva nemmeno a sapere che esercizi doveva mostrare.
  test('senza rete la scheda si apre lo stesso', () async {
    await laSchedaEGiaSulTelefono();
    staccaLaRete();

    final piano = await contenitore.read(planDetailProvider(8).future);

    expect(piano.name, 'Giorno 1');
    expect(piano.exercises.length, 2);
    expect(piano.exercises.first.name, 'Calf Raise Gamba Singola in Piedi');
  });

  /// ══ 🚨 E LE SERIE SI REGISTRANO ═══════════════════════════════════════
  ///
  /// ⛔ Qui c'era un `throw`: senza id la serie **non si salvava**, e il player
  /// gli id non ce li ha. Cioè la prima serie di **ogni** esercizio andava
  /// perduta. 💡 Adesso l'id si cerca nel catalogo che sta già sul telefono.
  test('senza rete le serie si registrano lo stesso', () async {
    await laSchedaEGiaSulTelefono();
    staccaLaRete();

    final conCatalogo = conIlCatalogo(
      CatalogoEsercizi(const [
        EsercizioDelCatalogo(
          id: 126,
          nome: 'Calf Raise Gamba Singola in Piedi',
          primario: null,
          secondari: [],
          met: 5,
        ),
      ]),
    );

    final seduta = await conCatalogo
        .read(sessionActionsProvider)
        .start(planId: 8, planName: 'Giorno 1');

    final id = await conCatalogo
        .read(sessionActionsProvider)
        .logSet(
          sessionId: seduta.id,
          setNumber: 1,
          exerciseName: 'Calf Raise Gamba Singola in Piedi',
          reps: 35,
        );

    expect(id, 126, reason: 'L\'id doveva uscire dal catalogo sul telefono.');

    final serie = await archivio.serieDi(seduta.id);

    expect(serie.length, 1);
    expect(serie.first.nomeEsercizio, 'Calf Raise Gamba Singola in Piedi');
    expect(serie.first.met, 5);
  });

  /// ══ ⛔ E ANCHE UN ESERCIZIO CHE IL CATALOGO NON CONOSCE ════════════════
  ///
  /// 🚨 **Una serie fatta non si perde mai.** In sala si aggiunge un esercizio
  /// al volo di continuo — macchina occupata, sostituzione — e senza campo il
  /// nome non si può riconciliare con la libreria. ⛔ Prima quella serie
  /// spariva: chi ha appena spinto un bilanciere non la rifà perché l'app non
  /// aveva rete.
  ///
  /// 💡 Si salva con un id **provvisorio e negativo**: gli id veri sono
  /// positivi, quindi non può collidere e si riconosce a colpo d'occhio.
  test(
    'e anche un esercizio che il catalogo non conosce non si perde',
    () async {
      staccaLaRete();

      final conCatalogo = conIlCatalogo(CatalogoEsercizi.vuoto);

      final seduta = await conCatalogo.read(sessionActionsProvider).start();

      final id = await conCatalogo
          .read(sessionActionsProvider)
          .logSet(
            sessionId: seduta.id,
            setNumber: 1,
            exerciseName: 'Macchina strana della palestra nuova',
            reps: 12,
            weight: 40,
          );

      expect(
        id,
        lessThan(0),
        reason: 'L\'id provvisorio dev\'essere negativo.',
      );

      final serie = await archivio.serieDi(seduta.id);

      expect(serie.length, 1, reason: 'La serie è stata persa.');
      expect(serie.first.nomeEsercizio, 'Macchina strana della palestra nuova');
      expect(serie.first.pesoKg, 40);
    },
  );

  /// ⚠️ **E la sincronizzazione non cancella niente**: quando la rete manca,
  /// quello che c'è sul telefono resta dov'è.
  test(
    'e la scheda resta sul telefono anche se il server non risponde',
    () async {
      await laSchedaEGiaSulTelefono();
      staccaLaRete();

      await contenitore.read(planDetailProvider(8).future);

      expect(await archivio.schedaSulTelefono(8), isNotNull);
    },
  );
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
