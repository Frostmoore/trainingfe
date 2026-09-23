import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';
import 'package:training_companion/src/features/auth/data/app_user.dart';
import 'package:training_companion/src/features/chat/chat_controller.dart';
import 'package:training_companion/src/features/chat/ui/conversations_screen.dart';

import 'aiuto/intestazione.dart';

/// 💬 **Il vuoto della chat parla a chi lo sta guardando** — 23/09/2026.
///
/// ══ ⛔ IL DIFETTO ══════════════════════════════════════════════════════════
///
/// A **tutti** diceva *«Qui compaiono le conversazioni col tuo trainer»*, col
/// pulsante «Scrivi al tuo trainer». ⚠️ Anche a un trainer con cinque allievi —
/// che in cima alla **stessa schermata** si vedeva offrire «manda una scheda a
/// più persone».
///
/// 🚨 La schermata sapeva chi aveva davanti — la condizione per quel pulsante
/// era già lì — e nello stato vuoto se ne dimenticava.
///
/// 💡 Questo test tiene ferme **le due frasi insieme**: quella giusta per
/// l'allievo e quella giusta per chi allena. Una sola delle due passerebbe
/// anche con il difetto rimesso a metà.
void main() {
  Future<void> disegna(WidgetTester tester, {required bool allena}) async {
    final dio = Dio(BaseOptions(baseUrl: 'https://esempio.test/api/v1'));

    final client = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: _TokenFinto(),
      dio: dio,
    );

    final utente = AppUser(
      id: 1,
      name: allena ? 'Coach' : 'Rita',
      email: 'chi@esempio.test',
      isTrainer: allena,
      puoAllenare: allena,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await intestazioneFinta(),
          authControllerProvider.overrideWith(
            (ref) => _AuthFinto(client, _TokenFinto(), utente),
          ),
          // ⚠️ Vuoto: è lo stato vuoto che si sta provando.
          conversationsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: ConversationsScreen()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('a un allievo parla del suo trainer', (tester) async {
    await disegna(tester, allena: false);

    expect(
      find.text('Qui compaiono le conversazioni col tuo trainer.'),
      findsOneWidget,
    );
    expect(find.text('Scrivi al tuo trainer'), findsOneWidget);
  });

  testWidgets('a chi allena parla dei suoi allievi', (tester) async {
    await disegna(tester, allena: true);

    expect(
      find.text('Qui compaiono le conversazioni con i tuoi allievi.'),
      findsOneWidget,
    );
    expect(find.text('Scrivi a un allievo'), findsOneWidget);
    expect(find.text('Scrivi al tuo trainer'), findsNothing);
  });
}

/// 💡 Un `AuthController` che nasce già con la persona dentro: qui non
/// interessa **come** si è entrati, solo **chi** sta guardando.
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
