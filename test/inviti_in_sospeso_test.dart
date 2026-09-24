import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/trainer/data/invito_in_sospeso.dart';
import 'package:training_companion/src/features/trainer/trainer_controller.dart';
import 'package:training_companion/src/features/trainer/ui/invita_qualcuno.dart';
import 'package:training_companion/src/features/trainer/ui/inviti_screen.dart';

import 'aiuto/intestazione.dart';

/// 📨 **Gli inviti si gestiscono dall'app** — blocco B1, 24/09/2026.
///
/// 📌 Il committente, il 23/09: *«devono poter creare il link di invito e
/// inviarlo per mail o copiarlo»*.
///
/// ══ ⛔ IL DIFETTO CHE QUESTI TEST TENGONO CHIUSO ════════════════════════════
///
/// 🚨 **Un invito creato dall'app spariva.** Il link finiva negli appunti e da
/// quel momento non stava più da nessuna parte: non si rivedeva, non si
/// ricopiava, non si revocava.
///
/// ⚠️ E ogni invito in piedi **tiene un posto del piano** finché non scade: un
/// tocco distratto costava **sette giorni** di un posto pagato.
void main() {
  late ApiClient client;

  /*
   * 🚨 **Gli appunti vanno finti, o l'app crede di essere rotta.**
   *
   * ⛔ `Clipboard.setData()` passa da un canale di piattaforma che in un test
   * non esiste: lancia, il `catch` della scheda lo prende per un errore
   * dell'invito e mostra **il messaggio sbagliato**. ⚠️ Il test che controllava
   * solo «ha chiamato il server?» passava lo stesso: l'errore stava dopo.
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

  InvitoInSospeso invito({
    int id = 1,
    String? email,
    DateTime? mandata,
    int giorni = 7,
  }) => InvitoInSospeso(
    id: id,
    url: 'https://esempio.test/invito/abc$id',
    email: email,
    emailInviataIl: mandata,
    scadeIl: DateTime.now().add(Duration(days: giorni)),
  );

  Future<_AzioniFinte> apri(
    WidgetTester tester,
    List<InvitoInSospeso> lista, {
    PostiDegliInviti posti = const PostiDegliInviti(
      occupati: 1,
      totali: 10,
      rimasti: 9,
    ),
  }) async {
    final azioni = _AzioniFinte(client);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // ⚠️ `IntestazioneApp` sta su tutte le pagine e poggia su cache e
          //    configurazione, che senza `bootstrap()` lanciano apposta.
          ...await intestazioneFinta(),
          invitiProvider.overrideWith(
            (ref) async => InvitiEPosti(inviti: lista, posti: posti),
          ),
          trainerActionsProvider.overrideWith((ref) => azioni),
        ],
        child: const MaterialApp(home: InvitiScreen()),
      ),
    );

    await tester.pumpAndSettle();

    return azioni;
  }

  group('la pagina degli inviti in sospeso', () {
    testWidgets('mostra a chi è stato mandato e quando scade', (tester) async {
      await apri(tester, [
        invito(email: 'tizio@esempio.test', mandata: DateTime.now(), giorni: 3),
      ]);

      expect(find.text('tizio@esempio.test'), findsOneWidget);
      expect(find.textContaining('scade fra 3 giorni'), findsOneWidget);
    });

    /// 🚨 **«Mandata» solo quando è vero.**
    ///
    /// ⚠️ `email` dice **a chi** si voleva mandarlo; `emailInviataIl` dice se è
    /// **partita**. ⛔ Confonderle farebbe aspettare una mail che non arriverà
    /// mai — e l'invio può fallire davvero, perché quando fallisce l'invito
    /// resta valido di proposito.
    testWidgets('un invito con email ma mai partita non dice «mandata»', (
      tester,
    ) async {
      await apri(tester, [invito(email: 'tizio@esempio.test')]);

      expect(find.textContaining('Non mandata'), findsOneWidget);
      expect(find.textContaining('Mandata per email'), findsNothing);
    });

    /// 💡 I posti stanno **sopra l'elenco**: è la ragione per cui si apre questa
    /// pagina — non «quanti inviti ho mandato», ma «quanti posti mi restano».
    testWidgets('dice quanti posti restano, e che gli inviti li occupano', (
      tester,
    ) async {
      await apri(tester, [invito()]);

      expect(
        find.textContaining('Posti liberi: 9 su 10'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Contano anche gli inviti in sospeso'),
        findsOneWidget,
      );
    });

    testWidgets('senza inviti lo dice, e resta scorrevole', (tester) async {
      await apri(tester, const []);

      expect(find.text('Nessun invito in sospeso'), findsOneWidget);

      // ⚠️ `ListView` e non `Center`: o strisciare in giù non afferrerebbe
      //    niente, e la pagina sembrerebbe bloccata proprio quando è vuota.
      expect(find.byType(ListView), findsOneWidget);
    });

    /// 🚨 **La revoca si conferma, e la conferma dice cosa succede davvero:**
    /// il link muore **e il posto torna libero**. ⛔ Senza la seconda metà, chi
    /// legge non sa perché dovrebbe revocare.
    testWidgets('revocare chiede conferma e spiega che il posto torna', (
      tester,
    ) async {
      final azioni = await apri(tester, [invito(id: 5)]);

      await tester.tap(find.text('Revoca'));
      await tester.pumpAndSettle();

      expect(find.textContaining('il posto che occupava torna'), findsOneWidget);
      expect(azioni.revocati, isEmpty, reason: 'Ha revocato senza conferma.');

      await tester.tap(find.widgetWithText(FilledButton, 'Revoca'));
      await tester.pumpAndSettle();

      expect(azioni.revocati, [5]);
    });

    testWidgets('annullare non revoca niente', (tester) async {
      final azioni = await apri(tester, [invito(id: 5)]);

      await tester.tap(find.text('Revoca'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'No'));
      await tester.pumpAndSettle();

      expect(azioni.revocati, isEmpty);
    });

    /// 📧 **Rimandare, invece di rifare**: rifare consuma un altro posto finché
    /// il primo non scade.
    testWidgets('rimanda alla stessa email senza chiedere niente', (
      tester,
    ) async {
      final azioni = await apri(tester, [
        invito(id: 9, email: 'tizio@esempio.test'),
      ]);

      await tester.tap(find.text('Rimanda'));
      await tester.pumpAndSettle();

      expect(azioni.rimandati, [(9, 'tizio@esempio.test')]);
    });

    /// ⛔ **Un destinatario non si inventa**: se l'invito è nato senza email,
    /// prima la si chiede.
    testWidgets('senza email chiede a chi mandarlo', (tester) async {
      final azioni = await apri(tester, [invito(id: 9)]);

      await tester.tap(find.text('Rimanda'));
      await tester.pumpAndSettle();

      expect(find.text('A quale indirizzo?'), findsOneWidget);
      expect(azioni.rimandati, isEmpty);

      await tester.enterText(find.byType(TextField), 'nuovo@esempio.test');
      await tester.tap(find.widgetWithText(FilledButton, 'Manda'));
      await tester.pumpAndSettle();

      expect(azioni.rimandati, [(9, 'nuovo@esempio.test')]);
    });
  });

  group('la scheda «Invita una persona»', () {
    Future<_AzioniFinte> apriLaScheda(WidgetTester tester) async {
      final azioni = _AzioniFinte(client);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [trainerActionsProvider.overrideWith((ref) => azioni)],
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

      return azioni;
    }

    /// 🚨 **Due strade, non una.** ⛔ Prima il pulsante faceva una cosa sola —
    /// copiava il link — e l'email, che l'API accettava dal 22/09, non si
    /// poteva usare.
    testWidgets('offre sia il link sia l\'email', (tester) async {
      await apriLaScheda(tester);

      expect(find.text('Crea e copia il link'), findsOneWidget);
      expect(find.text('Crea e manda per email'), findsOneWidget);
    });

    /// 💡 **Si dice prima che costa un posto**, non dopo averlo consumato.
    testWidgets('avvisa che l\'invito tiene occupato un posto', (tester) async {
      await apriLaScheda(tester);

      expect(find.textContaining('tiene occupato un posto'), findsOneWidget);
    });

    /// ⛔ **Non si crea l'invito per poi dire «però scrivi l'email»**: quello
    /// consumerebbe un posto per un gesto che la persona non ha finito.
    testWidgets('chiedere di mandare senza email non crea niente', (
      tester,
    ) async {
      final azioni = await apriLaScheda(tester);

      await tester.tap(find.text('Crea e manda per email'));
      await tester.pumpAndSettle();

      expect(azioni.creati, isEmpty);
      expect(find.textContaining('Scrivi l\'email'), findsOneWidget);
    });

    testWidgets('con l\'email crea e la passa al server', (tester) async {
      final azioni = await apriLaScheda(tester);

      await tester.enterText(find.byType(TextField), 'tizio@esempio.test');
      await tester.tap(find.text('Crea e manda per email'));
      await tester.pumpAndSettle();

      expect(azioni.creati, ['tizio@esempio.test']);
    });

    testWidgets('senza email crea lo stesso e copia il link', (tester) async {
      final azioni = await apriLaScheda(tester);

      await tester.tap(find.text('Crea e copia il link'));
      await tester.pumpAndSettle();

      expect(azioni.creati, [null]);
    });

    /// 🚨 **Non si dice «mandata» se non è partita.**
    ///
    /// ⚠️ L'invito resta valido di proposito — il link c'è — ma far aspettare
    /// una mail che non arriverà è peggio che dire subito di passarlo a mano.
    testWidgets('se la mail non parte, lo dice e rimanda agli appunti', (
      tester,
    ) async {
      final azioni = await apriLaScheda(tester);
      azioni.mailParte = false;

      await tester.enterText(find.byType(TextField), 'tizio@esempio.test');
      await tester.tap(find.text('Crea e manda per email'));
      await tester.pumpAndSettle();

      expect(find.textContaining('la mail non è partita'), findsOneWidget);
    });
  });
}

/// Le azioni del trainer, finte: registrano invece di chiamare il server.
class _AzioniFinte extends TrainerActions {
  _AzioniFinte(ApiClient client) : super(client, _RefFinto());

  final creati = <String?>[];
  final revocati = <int>[];
  final rimandati = <(int, String?)>[];

  bool mailParte = true;

  @override
  Future<InvitoCreato> invita({String? email}) async {
    creati.add(email);

    return InvitoCreato(
      id: 1,
      url: 'https://esempio.test/invito/abc',
      email: email,
      emailInviata: email != null && mailParte,
    );
  }

  @override
  Future<void> revocaInvito(int id) async => revocati.add(id);

  @override
  Future<bool> rimandaInvito(int id, {String? email}) async {
    rimandati.add((id, email));

    return mailParte;
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
