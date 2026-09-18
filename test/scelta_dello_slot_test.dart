import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/router/app_router.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';
import 'package:training_companion/src/features/auth/data/app_user.dart';
import 'package:training_companion/src/features/trainer/trainer_controller.dart';
import 'package:training_companion/src/features/trainer/ui/scelta_dello_slot.dart';
import 'package:training_companion/src/features/trainer/ui/scelta_dello_slot_al_rientro.dart';

/// 🎟️ **Tieni il posto o lo liberi?** — AH.1-ter.6, 18/09/2026.
///
/// 📌 Il committente: *«se un allievo di un free trainer si iscrive in una
/// palestra in cui lavora quel free trainer, allora il free trainer deve
/// ricevere la modale che gli chiede se vuole mantenere lo slot occupato o
/// liberarlo»*.
///
/// ══ ⛔ PERCHE' C'E' UN GRUPPO SUL GIRO VERO ════════════════════════════════
///
/// `la_modale_compare_davvero_test` l'ha insegnato: un test sul widget da solo
/// era verde, **e la modale non compariva**. Fra la lista che torna dal server
/// e la finestra aperta c'è un widget montato in un posto preciso dell'albero,
/// ed è lì che si rompe. 💡 Il secondo gruppo monta l'osservatore **sopra** un
/// `MaterialApp` con `chiaveDelNavigatore`, com'è nell'app vera.
void main() {
  const due = [
    SlotDaDecidere(allievoId: 7, nome: 'Rita', palestra: 'Olimpo'),
    SlotDaDecidere(allievoId: 8, nome: 'Ugo', palestra: 'Olimpo'),
  ];

  late ApiClient client;

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

  group('la finestra dice le cose giuste', () {
    /*
     * ⚠️ **Il registro si crea fuori**, e si passa dentro. Il primo tentativo
     * teneva l'azione finta in una `late` assegnata dentro l'override — che
     * Riverpod esegue solo quando qualcuno legge il provider, cioè al primo
     * tocco di un tasto. `apri()` la restituiva prima: `LateInitializationError`
     * su sei test, con il codice giusto.
     */
    Future<List<(int, bool)>> apri(
      WidgetTester tester,
      List<SlotDaDecidere> lista,
    ) async {
      final decisioni = <(int, bool)>[];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trainerActionsProvider.overrideWith(
              (ref) => _AzioniFinte(client, ref, decisioni),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => SceltaDelloSlot.mostra(lista, context),
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('apri'));
      await tester.pumpAndSettle();

      return decisioni;
    }

    testWidgets('elenca tutti quelli su cui decidere', (tester) async {
      await apri(tester, due);

      expect(find.text('Rita'), findsOneWidget);
      expect(find.text('Ugo'), findsOneWidget);
      expect(
        find.text('Alcuni tuoi allievi sono entrati nella tua palestra'),
        findsOneWidget,
      );
    });

    /// 🚨 **Non dice che il rapporto è sospeso, perché non lo è.**
    ///
    /// 📌 Il committente, 18/09: *«l'allievo di un free_trainer che si
    /// iscrive in una palestra non deve avere il rapporto col free_trainer
    /// sospeso»*. ⛔ Una frase del genere farebbe decidere il trainer su una
    /// cosa che non sta succedendo.
    testWidgets('non parla di un rapporto sospeso o in pausa', (tester) async {
      await apri(tester, due);

      expect(find.textContaining('sospes'), findsNothing);
      expect(find.textContaining('pausa'), findsNothing);
      expect(
        find.textContaining('Continui a seguirlo come prima'),
        findsOneWidget,
      );
    });

    /// ⚖️ **«Tengo il posto» è il tasto pieno**: liberarlo non si annulla.
    testWidgets('tengo il posto è il tasto in evidenza', (tester) async {
      await apri(tester, due.take(1).toList());

      expect(
        find.widgetWithText(FilledButton, 'Tengo il posto'),
        findsOneWidget,
      );
      expect(find.widgetWithText(OutlinedButton, 'Lo libero'), findsOneWidget);
    });

    testWidgets('ogni risposta arriva al server con la scelta giusta', (
      tester,
    ) async {
      final decisioni = await apri(tester, due);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Tengo il posto').first,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Lo libero').first);
      await tester.pumpAndSettle();

      expect(decisioni, [(7, true), (8, false)]);
    });

    /// 💡 Ogni riga sparisce appena risposta, e con l'ultima si chiude tutto.
    testWidgets('risposto a tutti, la finestra si chiude', (tester) async {
      await apri(tester, due);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Tengo il posto').first,
      );
      await tester.pumpAndSettle();

      expect(find.text('Rita'), findsNothing);
      expect(find.text('Ugo'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Tengo il posto'));
      await tester.pumpAndSettle();

      expect(find.byType(SceltaDelloSlot), findsNothing);
    });

    /// ⚠️ La palestra può mancare (`nullOnDelete`): non si scrive «null».
    testWidgets('senza palestra non scrive null', (tester) async {
      await apri(tester, const [
        SlotDaDecidere(allievoId: 9, nome: 'Eva', palestra: null),
      ]);

      expect(find.textContaining('null'), findsNothing);
      expect(find.text('Eva'), findsOneWidget);
    });
  });

  /// 🚨 **Il giro vero: la finestra compare da sola.**
  group('compare da sola a chi deve', () {
    Future<void> monta(
      WidgetTester tester, {
      required bool trainer,
      List<SlotDaDecidere> lista = due,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              (ref) =>
                  AuthController(client, _TokenStoreFinto())
                    ..state = AuthState(
                      status: AuthStatus.loggedIn,
                      user: AppUser(
                        id: 1,
                        name: 'Coach',
                        email: 'coach@esempio.test',
                        isTrainer: trainer,
                      ),
                    ),
            ),
            slotDaDecidereProvider.overrideWith((ref) async => lista),
            trainerActionsProvider.overrideWith(
              (ref) => _AzioniFinte(client, ref, []),
            ),
          ],

          /*
           * ⚠️ **Come nell'app vera**: l'osservatore sta nel `builder`, cioè
           * sopra il `Navigator`, e la finestra si apre con
           * `chiaveDelNavigatore`. Montarlo sotto farebbe passare un test che
           * nell'app vera fallisce.
           */
          child: MaterialApp(
            navigatorKey: chiaveDelNavigatore,
            builder: (context, figlio) =>
                SceltaDelloSlotAlRientro(child: figlio!),
            home: const Scaffold(body: Text('casa')),
          ),
        ),
      );

      await tester.pumpAndSettle();
    }

    testWidgets('a un trainer con scelte aperte la finestra compare', (
      tester,
    ) async {
      await monta(tester, trainer: true);

      expect(find.byType(SceltaDelloSlot), findsOneWidget);
      expect(find.text('Rita'), findsOneWidget);
    });

    /// ⛔ A chi non è trainer la rotta risponde 403: non si chiede nemmeno.
    testWidgets('a chi non è trainer non compare', (tester) async {
      await monta(tester, trainer: false);

      expect(find.byType(SceltaDelloSlot), findsNothing);
    });

    testWidgets('senza scelte aperte non compare', (tester) async {
      await monta(tester, trainer: true, lista: const []);

      expect(find.byType(SceltaDelloSlot), findsNothing);
    });
  });
}

class _AzioniFinte extends TrainerActions {
  _AzioniFinte(super.api, super.ref, this.decisioni);

  final List<(int, bool)> decisioni;

  @override
  Future<void> decidiLoSlot(int allievoId, {required bool tengo}) async {
    decisioni.add((allievoId, tengo));
  }
}

class _TokenStoreFinto implements TokenStore {
  String? salvato;

  @override
  Future<String?> read() async => salvato;

  @override
  Future<void> write(String token) async => salvato = token;

  @override
  Future<void> clear() async => salvato = null;

  @override
  void forgetCache() {}
}
