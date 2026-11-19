import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/router/app_router.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/core/ui/testata_scura.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';
import 'package:training_companion/src/features/auth/data/app_user.dart';
import 'package:training_companion/src/features/chat/chat_controller.dart';
import 'package:training_companion/src/features/chat/ui/conversations_screen.dart';

import 'aiuto/intestazione.dart';

/// 💬 **Messaggi con la ricerca in testata** — `plan_interfaccia.md` I6,
/// 19/11/2026.
///
/// 🚨 **M7.4: il catalogo si raggiunge da Messaggi.** Fino al 19/11 era
/// un'icona fra le azioni; ora è la ricerca grande nel seguito scuro. Questo
/// test tiene ferma la regola dopo lo spostamento: la porta c'è, sta nel
/// seguito scuro, e porta davvero al catalogo — e l'icona vecchia non è
/// rimasta come seconda strada.
void main() {
  Future<void> disegna(
    WidgetTester tester, {
    List<Conversation> conversazioni = const [],
  }) async {
    final client = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: _TokenFinto(),
      dio: Dio(BaseOptions(baseUrl: 'https://esempio.test/api/v1')),
    );

    const utente = AppUser(
      id: 1,
      name: 'Rita',
      email: 'rita@esempio.test',
      isTrainer: false,
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ConversationsScreen()),
        GoRoute(
          path: AppRoutes.catalogo,
          builder: (_, _) => const Scaffold(body: Text('IL CATALOGO')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await intestazioneFinta(),
          authControllerProvider.overrideWith(
            (ref) => _AuthFinto(client, _TokenFinto(), utente),
          ),
          conversationsProvider.overrideWith((ref) async => conversazioni),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('la ricerca sta nel seguito scuro e porta al catalogo', (
    tester,
  ) async {
    await disegna(tester);

    final porta = find.text('Trova un trainer o una palestra');
    expect(
      find.descendant(of: find.byType(CodaDellaTestata), matching: porta),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(CodaDellaTestata),
        matching: find.textContaining('cifrati'),
      ),
      findsOneWidget,
    );

    await tester.tap(porta);
    await tester.pumpAndSettle();

    expect(find.text('IL CATALOGO'), findsOneWidget);
  });

  testWidgets("l'icona vecchia del catalogo non è rimasta fra le azioni", (
    tester,
  ) async {
    await disegna(tester);

    expect(find.byIcon(Icons.travel_explore_rounded), findsNothing);
  });

  testWidgets('ogni conversazione è una carta', (tester) async {
    await disegna(
      tester,
      conversazioni: const [
        Conversation(id: 1, withName: 'Coach Marco', unread: 0),
        Conversation(id: 2, withName: 'Palestra Uno', unread: 2),
      ],
    );

    for (final nome in ['Coach Marco', 'Palestra Uno']) {
      expect(
        find.ancestor(of: find.text(nome), matching: find.byType(Card)),
        findsOneWidget,
        reason: nome,
      );
    }
  });
}

class _AuthFinto extends AuthController {
  _AuthFinto(super.api, super.tokens, AppUser utente) {
    state = AuthState(status: AuthStatus.loggedIn, user: utente);
  }
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
