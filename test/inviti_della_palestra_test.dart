import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/auth/data/app_user.dart';
import 'package:training_companion/src/features/trainer/data/invito_in_sospeso.dart';
import 'package:training_companion/src/features/trainer/trainer_controller.dart';
import 'package:training_companion/src/features/trainer/ui/invita_qualcuno.dart';
import 'package:training_companion/src/features/trainer/ui/inviti_screen.dart';

import 'aiuto/intestazione.dart';

/// 🏋️ **Gli inviti di una palestra, dall'app** — blocco B2, 24/09/2026.
///
/// 📌 Il committente, il 23/09: *«trainer e palestre possono proprio fare gli
/// inviti direttamente dall'app»*. B1 ha fatto la metà del trainer; questa è la
/// metà della palestra, e chiude la voce 11.
///
/// ══ 🚨 COSA GUARDANO QUESTI TEST ════════════════════════════════════════════
///
/// ⛔ **La pagina è una sola**, condivisa con quella del trainer: quindi il
/// rischio non è che non funzioni, è che **funzioni per uno dei due**. I test
/// qui sotto guardano esattamente le tre cose che cambiano — le due specie di
/// invitato, i **due** contatori, e le rotte da cui si legge — perché sono le
/// tre in cui un ramo dimenticato non dà nessun errore.
void main() {
  late ApiClient client;

  /*
   * 🚨 **Gli appunti vanno finti, o l'app crede di essere rotta**: è la stessa
   * trappola già pagata in B1. `Clipboard.setData()` passa da un canale di
   * piattaforma che in un test non esiste, lancia, e il `catch` della scheda lo
   * prende per un errore dell'invito mostrando il messaggio sbagliato.
   */
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (chiamata) async {
          return null;
        });
  });

  setUp(() {
    client = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: _TokenStoreFinto(),
      dio: Dio(BaseOptions(baseUrl: 'https://esempio.test/api/v1')),
    );
  });

  InvitoInSospeso invito({int id = 1, String? email, RuoloInvitato? ruolo}) =>
      InvitoInSospeso(
        id: id,
        url: 'https://esempio.test/invito-palestra/abc$id',
        email: email,
        ruolo: ruolo,
        scadeIl: DateTime.now().add(const Duration(days: 7)),
      );

  Future<_AzioniFinte> apri(
    WidgetTester tester,
    List<InvitoInSospeso> lista, {
    PostiDegliInviti iscritti = const PostiDegliInviti(
      occupati: 1,
      totali: 50,
      rimasti: 49,
    ),
    PostiDegliInviti trainer = const PostiDegliInviti(
      occupati: 2,
      totali: 3,
      rimasti: 1,
    ),
  }) async {
    final azioni = _AzioniFinte(client);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await intestazioneFinta(),
          invitiProvider.overrideWith(
            (ref, chi) async => InvitiEPosti(
              inviti: lista,
              posti: iscritti,
              postiTrainer: trainer,
            ),
          ),
          trainerActionsProvider.overrideWith((ref) => azioni),
        ],
        child: const MaterialApp(home: InvitiScreen(chi: ChiInvita.palestra)),
      ),
    );

    await tester.pumpAndSettle();

    return azioni;
  }

  group('la pagina degli inviti di una palestra', () {
    /// 🚨 **Due contatori, e si leggono tutti e due.**
    ///
    /// ⛔ Il difetto che questo test rende impossibile è sommarli: con un
    /// totale unico, una palestra con un solo posto trainer libero e
    /// quarantanove posti iscritti leggerebbe «restano 50» e non capirebbe
    /// perché al secondo trainer il server dice di no.
    testWidgets('mostra i posti iscritti e quelli trainer, separati', (
      tester,
    ) async {
      await apri(tester, [invito(ruolo: RuoloInvitato.iscritto)]);

      expect(
        find.textContaining('Iscritti · Posti liberi: 49 su 50'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Trainer · Posti liberi: 1 su 3'),
        findsOneWidget,
      );
    });

    /// 🏷️ **Il ruolo si vede su ogni riga.**
    ///
    /// 🚨 Nello stesso elenco ci sono inviti che consumano posti **diversi**:
    /// chi revoca per liberare un posto iscritto deve accorgersene **prima** di
    /// toccarlo, non dopo, guardando muoversi il contatore sbagliato.
    testWidgets('ogni riga dice se è un iscritto o un trainer', (tester) async {
      await apri(tester, [
        invito(
          id: 1,
          email: 'tizio@esempio.test',
          ruolo: RuoloInvitato.iscritto,
        ),
        invito(
          id: 2,
          email: 'coach@esempio.test',
          ruolo: RuoloInvitato.trainer,
        ),
      ]);

      /*
       * ⚠️ **La riga intera, non «Trainer ·»**: quel pezzo compare anche nel
       * contatore dei posti trainer, e un `textContaining` passerebbe pure se
       * il ruolo sulle righe sparisse del tutto.
       */
      expect(
        find.text('Iscritto · Non mandata · scade fra 7 giorni'),
        findsOneWidget,
      );
      expect(
        find.text('Trainer · Non mandata · scade fra 7 giorni'),
        findsOneWidget,
      );
    });

    /// ⚠️ **Le azioni vanno sulle rotte della palestra**, non su quelle del
    /// trainer: la pagina è la stessa, e questo è il punto in cui un ramo
    /// dimenticato revocherebbe l'invito sbagliato — o nessuno.
    testWidgets('revocare passa da «chi invita», non dal trainer', (
      tester,
    ) async {
      final azioni = await apri(tester, [invito(id: 7)]);

      await tester.tap(find.text('Revoca'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Revoca'));
      await tester.pumpAndSettle();

      expect(azioni.revocati, [(7, ChiInvita.palestra)]);
    });

    testWidgets('rimandare passa dalle rotte della palestra', (tester) async {
      final azioni = await apri(tester, [
        invito(id: 3, email: 'tizio@esempio.test'),
      ]);

      await tester.tap(find.text('Rimanda'));
      await tester.pumpAndSettle();

      expect(azioni.rimandati, [(3, ChiInvita.palestra)]);
    });
  });

  group('la scheda «Invita» di una palestra', () {
    Future<_AzioniFinte> scheda(WidgetTester tester) async {
      final azioni = _AzioniFinte(client);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await intestazioneFinta(),
            trainerActionsProvider.overrideWith((ref) => azioni),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      InvitaQualcuno.mostra(context, chi: ChiInvita.palestra),
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();

      return azioni;
    }

    /// 🚨 **La scelta c'è, e sta prima dell'email**: decide **quale posto** si
    /// sta per consumare. ⛔ Sceglierlo dopo vorrebbe dire tornare indietro
    /// quando il limite che salta non è quello che si stava guardando.
    testWidgets('si sceglie fra iscritto e trainer', (tester) async {
      await scheda(tester);

      expect(
        find.widgetWithText(SegmentedButton<RuoloInvitato>, 'Iscritto'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SegmentedButton<RuoloInvitato>, 'Trainer'),
        findsOneWidget,
      );
    });

    /// 💡 **Di serie «iscritto»**: una palestra invita trainer una volta ogni
    /// tanto e iscritti tutti i giorni.
    testWidgets('senza toccare niente invita un iscritto', (tester) async {
      final azioni = await scheda(tester);

      await tester.tap(find.text('Crea e copia il link'));
      await tester.pumpAndSettle();

      expect(azioni.creati, [(ChiInvita.palestra, RuoloInvitato.iscritto)]);
    });

    testWidgets('scegliendo «Trainer» invita un trainer', (tester) async {
      final azioni = await scheda(tester);

      await tester.tap(find.text('Trainer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Crea e copia il link'));
      await tester.pumpAndSettle();

      expect(azioni.creati, [(ChiInvita.palestra, RuoloInvitato.trainer)]);
    });

    /// ⛔ **Un trainer indipendente non sceglie niente**: ha una specie sola di
    /// allievo, e un interruttore che non decide nulla è una domanda a cui non
    /// si può rispondere sbagliato — quindi è solo rumore.
    testWidgets('un trainer non vede nessuna scelta di ruolo', (tester) async {
      final azioni = _AzioniFinte(client);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await intestazioneFinta(),
            trainerActionsProvider.overrideWith((ref) => azioni),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => InvitaQualcuno.mostra(context),
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();

      expect(find.byType(SegmentedButton<RuoloInvitato>), findsNothing);
    });
  });

  group('chi vede la voce nel profilo', () {
    /// 🚨 **`gym_admin` non è `trainer`**, e i due cappelli sono indipendenti.
    ///
    /// ⛔ Il difetto che questo test chiude: legare la voce a «chi allena»
    /// la farebbe sparire proprio al gestore che non segue allievi — cioè al
    /// caso più comune di tutti.
    test('un gestore di palestra risulta tale anche se non allena nessuno', () {
      final utente = AppUser.fromJson(const {
        'id': 1,
        'name': 'Gestore',
        'email': 'gestore@olimpo.it',
        'roles': ['gym_admin'],
      });

      expect(utente.gestisceUnaPalestra, isTrue);
      expect(utente.isTrainer, isFalse);
    });

    test('un trainer non gestisce nessuna palestra', () {
      final utente = AppUser.fromJson(const {
        'id': 2,
        'name': 'Coach',
        'email': 'coach@olimpo.it',
        'roles': ['trainer'],
      });

      expect(utente.gestisceUnaPalestra, isFalse);
      expect(utente.isTrainer, isTrue);
    });

    /// 💡 E chi ha **tutti e due** i cappelli li tiene tutti e due: sono due
    /// elenchi di inviti diversi, su due piani diversi.
    test('si possono avere tutti e due i cappelli', () {
      final utente = AppUser.fromJson(const {
        'id': 3,
        'name': 'Doppio',
        'email': 'doppio@olimpo.it',
        'roles': ['gym_admin', 'free_trainer'],
      });

      expect(utente.gestisceUnaPalestra, isTrue);
      expect(utente.isTrainer, isTrue);
    });
  });
}

/// Le azioni, finte: registrano **anche da quali rotte** sono passate.
///
/// 🚨 È il punto di questi test: con una pagina sola, sbagliare `chi` non dà
/// nessun errore a schermo — chiama semplicemente il server sbagliato.
class _AzioniFinte extends TrainerActions {
  _AzioniFinte(ApiClient client) : super(client, _RefFinto());

  final creati = <(ChiInvita, RuoloInvitato?)>[];
  final revocati = <(int, ChiInvita)>[];
  final rimandati = <(int, ChiInvita)>[];

  @override
  Future<InvitoCreato> invita({
    String? email,
    ChiInvita chi = ChiInvita.trainer,
    RuoloInvitato? ruolo,
  }) async {
    creati.add((chi, ruolo));

    return InvitoCreato(
      id: 1,
      url: 'https://esempio.test/invito-palestra/abc',
      email: email,
      emailInviata: email != null,
      ruolo: ruolo,
    );
  }

  @override
  Future<void> revocaInvito(
    int id, {
    ChiInvita chi = ChiInvita.trainer,
  }) async => revocati.add((id, chi));

  @override
  Future<bool> rimandaInvito(
    int id, {
    String? email,
    ChiInvita chi = ChiInvita.trainer,
  }) async {
    rimandati.add((id, chi));

    return true;
  }
}

/// ⚠️ `TrainerActions` vuole una `Ref` per invalidare i provider: qui non c'è
/// niente da invalidare, perché le azioni non chiamano il server.
class _RefFinto implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TokenStoreFinto implements TokenStore {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
