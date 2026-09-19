import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/acquisti/data/gate_dell_abbonamento.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/health/health_controller.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/data/gruppo_muscolare.dart';
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

        /*
         * 🔒 **Il cancello dell'abbonamento, dichiarato invece che ereditato**
         * — 08/09/2026.
         *
         * ⛔ Da quando `SessionActions.start()` controlla il limite di un
         * allenamento al giorno, tira dentro `authControllerProvider` e con lui
         * `localCacheProvider`, che qui non c'è: due test sono diventati rossi
         * con un `UnimplementedError` che **non parlava di allenamenti**.
         *
         * 💡 Si sovrascrive il cancello e non la catena sotto: questo file
         * verifica che **le serie si scrivano senza rete**, e mettere in piedi
         * l'autenticazione per arrivarci vorrebbe dire far dipendere quella
         * verifica da tre cose che non c'entrano.
         *
         * ⚠️ Il limite ha un test suo — `un_allenamento_al_giorno_test.dart` —
         * ed è quello il posto in cui la regola si guarda.
         */
        abbonatoProvider.overrideWithValue(true),
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

        /*
         * 🔒 **Il cancello dell'abbonamento, dichiarato invece che ereditato**
         * — 08/09/2026.
         *
         * ⛔ Da quando `SessionActions.start()` controlla il limite di un
         * allenamento al giorno, tira dentro `authControllerProvider` e con lui
         * `localCacheProvider`, che qui non c'è: due test sono diventati rossi
         * con un `UnimplementedError` che **non parlava di allenamenti**.
         *
         * 💡 Si sovrascrive il cancello e non la catena sotto: questo file
         * verifica che **le serie si scrivano senza rete**, e mettere in piedi
         * l'autenticazione per arrivarci vorrebbe dire far dipendere quella
         * verifica da tre cose che non c'entrano.
         *
         * ⚠️ Il limite ha un test suo — `un_allenamento_al_giorno_test.dart` —
         * ed è quello il posto in cui la regola si guarda.
         */
        abbonatoProvider.overrideWithValue(true),
        catalogoEserciziProvider.overrideWith((ref) async => catalogo),
      ],
    );

    addTearDown(c.dispose);

    return c;
  }

  /// La scheda com'è arrivata l'ultima volta che c'era campo.
  ///
  /// ⚠️ **Restituisce l'id invece di fissarlo a 8** — 25/08. Da quando la
  /// tabella è una sola l'id lo dà il database, e un test che se lo scrive da
  /// solo proverebbe solo che il numero che ha inventato coincide.
  Future<int> laSchedaEGiaSulTelefono() => archivio.aggiungiScheda(
    nome: 'Giorno 1',
    mia: true,
    origine: 'server',
    idOrigine: 8,
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
    final id = await laSchedaEGiaSulTelefono();
    staccaLaRete();

    final piano = await contenitore.read(planDetailProvider(id).future);

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
      final id = await laSchedaEGiaSulTelefono();
      staccaLaRete();

      await contenitore.read(planDetailProvider(id).future);

      expect(await archivio.laScheda(id), isNotNull);
    },
  );

  /// ══ 🆕 D6 — UN ESERCIZIO INVENTATO RESTA SUL TELEFONO ══════════════════
  ///
  /// 📌 Il committente, 19/09/2026: *«se io utente medio creo un esercizio …
  /// non vedo per quale motivo dovrebbe essere salvato sul server. Resta suo, e
  /// lo vede solo lui. I muscoli devono essere obbligatori»*.
  ///
  /// ⛔ Qui c'erano i test della «riconciliazione» di B.16.13, che mandava al
  /// server gli esercizi inventati senza rete: il server li rifiutava (giro del
  /// 18/09, D6), e comunque non dovevano andarci.
  group('un esercizio inventato resta sul telefono', () {
    const macchina = 'Macchina strana della palestra nuova';

    test(
      'nasce nell\'archivio con i suoi muscoli, senza chiamare il server',
      () async {
        // ⚠️ La rete risponde con un errore a tutto: se logSet la chiamasse, il
        // test lo vedrebbe dal risultato sbagliato, non da un'eccezione.
        staccaLaRete();

        final attori = conIlCatalogo(CatalogoEsercizi.vuoto);
        final seduta = await attori.read(sessionActionsProvider).start();

        final id = await attori
            .read(sessionActionsProvider)
            .logSet(
              sessionId: seduta.id,
              setNumber: 1,
              exerciseName: macchina,
              muscoli: (
                primario: GruppoMuscolare.petto,
                secondari: const [GruppoMuscolare.tricipiti],
              ),
              reps: 10,
            );

        final suoi = await archivio.leggiEserciziSulTelefono();

        expect(id, lessThan(0));
        expect(suoi.single.id, id);
        expect(suoi.single.nome, macchina);
        expect(suoi.single.primario, 'chest');
        expect(suoi.single.origine, 'mio');
        expect((await archivio.serieDi(seduta.id)).single.esercizioId, id);
      },
    );

    test('scritto due volte è lo stesso esercizio', () async {
      final uno = await archivio.salvaEsercizioMio(
        nome: macchina,
        primario: 'chest',
      );
      final due = await archivio.salvaEsercizioMio(
        nome: '  macchina strana della palestra NUOVA ',
        primario: 'back',
      );

      expect(due, uno);
    });

    /// ⚠️ Un id nuovo non deve prendere quello di una serie provvisoria di
    /// prima di D6, che vive ancora nelle serie.
    test('un id nuovo non collide con le serie di prima', () async {
      final seduta = await archivio.apriSeduta();

      await archivio.registraSerie(
        SerieDelleSeduteCompanion.insert(
          sedutaId: seduta,
          esercizioId: -500,
          nomeEsercizio: 'vecchio',
          numero: 1,
        ),
      );

      expect(
        await archivio.salvaEsercizioMio(nome: 'nuovo', primario: 'chest'),
        -501,
      );
    });

    /// 💡 **La libreria vince**: chi scrive «Panca piana» deve finire
    /// sull'esercizio della libreria, o lo storico non è confrontabile.
    test('il catalogo li unisce, e la libreria vince', () async {
      await archivio.salvaEsercizioMio(nome: macchina, primario: 'chest');
      await archivio.salvaEsercizioMio(nome: 'Panca piana', primario: 'back');

      final catalogo = conQuelliSulTelefono(const [
        EsercizioDelCatalogo(
          id: 1,
          nome: 'Panca piana',
          primario: GruppoMuscolare.petto,
          secondari: [],
        ),
      ], await archivio.leggiEserciziSulTelefono());

      expect(catalogo.perNome(macchina)?.primario, GruppoMuscolare.petto);
      expect(catalogo.perNome('Panca piana')?.id, 1);
      expect(catalogo.tutti.length, 2);
    });
  });

  /// ══ 🆕 D8 — GLI ESERCIZI DI UNA SCHEDA RICEVUTA RESTANO PER SEMPRE ══════
  ///
  /// 📌 *«gli esercizi che creano [trainer e palestre] devono essere salvati
  /// anche nei telefoni degli allievi (anche se si disiscrivono) per sempre»*.
  group('gli esercizi di una scheda ricevuta', () {
    final scheda = jsonEncode({
      'id': 99,
      'name': 'Giorno A',
      'days': [
        {
          'name': 'Spinta',
          'exercises': [
            {
              'id': 7, // ⚠️ l'id della RIGA: non va preso
              'exercise_id': 812,
              'name': 'Spinte alla macchina del coach',
              'muscle_group': 'chest',
              'secondary_muscles': ['triceps'],
              'alternatives': [
                {
                  'exercise': {'id': 813, 'name': 'Variante del coach'},
                },
              ],
            },
          ],
        },
      ],
    });

    test('si trovano tutti, alternative comprese, con l\'id giusto', () {
      final trovati = eserciziDellaScheda(scheda);

      expect(trovati.map((e) => e.id), unorderedEquals([812, 813]));
      expect(trovati.firstWhere((e) => e.id == 812).primario, 'chest');
      expect(trovati.firstWhere((e) => e.id == 812).secondari, ['triceps']);
    });

    test('salvando la scheda dalla chat restano sul telefono', () async {
      await archivio.salvaSchedaDallaChat(
        messaggioId: 1,
        nome: 'Giorno A',
        scheda: scheda,
      );

      final sulTelefono = await archivio.leggiEserciziSulTelefono();

      expect(sulTelefono.map((e) => e.id), unorderedEquals([812, 813]));
      expect(sulTelefono.every((e) => e.origine == 'ricevuto'), isTrue);
    });

    /// ⛔ Un esercizio suo non lo sovrascrive nessuno.
    test('non toccano un esercizio mio', () async {
      final mio = await archivio.salvaEsercizioMio(
        nome: 'Mio',
        primario: 'chest',
      );

      await archivio.ricordaEserciziRicevuti([
        (
          id: mio,
          nome: 'Altro',
          primario: 'back',
          secondari: const [],
          met: null,
        ),
      ]);

      final e = (await archivio.leggiEserciziSulTelefono()).single;

      expect(e.nome, 'Mio');
      expect(e.origine, 'mio');
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
