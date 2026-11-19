import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/backup/backup_controller.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/router/app_router.dart';
import 'package:training_companion/src/core/sicurezza/blocco_biometrico.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/core/ui/testata_scura.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';
import 'package:training_companion/src/features/auth/data/app_user.dart';
import 'package:training_companion/src/features/profile/data/profile_models.dart';
import 'package:training_companion/src/features/profile/profile_controller.dart';
import 'package:training_companion/src/features/profile/ui/profile_screen.dart';

import 'aiuto/intestazione.dart';

/// 🪪 **Il profilo con la testata scura** — `plan_interfaccia.md` I7,
/// 19/11/2026.
///
/// 🚨 Quello che difende davvero:
/// - **I7.D3** — il backup automatico spento **si vede**, in «Backup e dati».
///   Il 19/11, sul telefono del committente, era spento e nessuno lo sapeva.
/// - **I7.D4** — chi vede cosa non è cambiato: le voci di chi allena restano
///   solo a chi allena.
/// - **3b-P.1** — la persona in testata è ancora una porta verso `/profilo/tu`.
void main() {
  group('la frase di «Backup e dati»', () {
    test('senza cloud non avvisa: non c\'è niente da accendere', () {
      final f = fraseDelBackup(
        const StatoBackup(acceso: false, disponibile: false),
      );
      expect(f.avviso, isFalse);
    });

    test('mentre carica non avvisa', () {
      expect(fraseDelBackup(null).avviso, isFalse);
    });

    test('col cloud e spento, avvisa', () {
      final f = fraseDelBackup(
        const StatoBackup(acceso: false, disponibile: true),
      );
      expect(f.avviso, isTrue);
      expect(f.testo, 'Backup automatico spento');
    });

    test('da ricollegare, avvisa', () {
      final f = fraseDelBackup(
        const StatoBackup(acceso: true, disponibile: true, daRicollegare: true),
      );
      expect(f.avviso, isTrue);
    });

    test('se l\'ultimo è fallito, avvisa', () {
      final f = fraseDelBackup(
        StatoBackup(
          acceso: true,
          disponibile: true,
          ultimo: DateTime(2026, 11, 1),
          fallitoIl: DateTime(2026, 11, 2),
        ),
      );
      expect(f.avviso, isTrue);
    });

    test('acceso e andato bene, non avvisa', () {
      final f = fraseDelBackup(
        StatoBackup(
          acceso: true,
          disponibile: true,
          ultimo: DateTime(2026, 11, 2),
        ),
      );
      expect(f.avviso, isFalse);
      expect(f.testo, 'Backup automatico acceso');
    });
  });

  Future<void> disegna(
    WidgetTester tester, {
    bool allena = false,
    StatoBackup backup = const StatoBackup(acceso: false, disponibile: true),
  }) async {
    PackageInfo.setMockInitialValues(
      appName: 'x',
      packageName: 'x',
      version: '22.6.0',
      buildNumber: '220600',
      buildSignature: '',
    );

    final client = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: _TokenFinto(),
      dio: Dio(BaseOptions(baseUrl: 'https://esempio.test/api/v1')),
    );

    final utente = AppUser(
      id: 1,
      name: 'Rita Rossi',
      email: 'rita@esempio.test',
      isTrainer: allena,
      abbonato: true,
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const ProfileScreen()),
        GoRoute(
          path: AppRoutes.tu,
          builder: (_, _) => const Scaffold(body: Text('PAGINA TU')),
        ),
      ],
    );

    // 💡 Lo schermo alto: il profilo è lungo, e qui si cercano voci in fondo.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await intestazioneFinta(),
          authControllerProvider.overrideWith(
            (ref) => _AuthFinto(client, _TokenFinto(), utente),
          ),
          profileProvider.overrideWith(
            (ref) => Completer<UserProfile>().future,
          ),
          backupAutomaticoProvider.overrideWith(() => _BackupFinto(backup)),
          bloccoBiometricoProvider.overrideWithValue(_BloccoFinto()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('il backup spento si legge in «Backup e dati»', (tester) async {
    await disegna(tester);

    expect(find.text('Backup e dati'), findsOneWidget);
    expect(find.text('Backup automatico spento'), findsOneWidget);
  });

  testWidgets('la persona e le due tessere stanno nel seguito scuro', (
    tester,
  ) async {
    await disegna(tester);

    for (final testo in ['Rita Rossi', 'PALESTRA', 'ABBONAMENTO', 'Attivo']) {
      expect(
        find.descendant(
          of: find.byType(CodaDellaTestata),
          matching: find.text(testo),
        ),
        findsOneWidget,
        reason: testo,
      );
    }
  });

  testWidgets('la persona porta ancora a /profilo/tu', (tester) async {
    await disegna(tester);

    // ⚠️ Il nome c'è due volte: anche nella riga d'identità, senza palestra.
    await tester.tap(
      find.descendant(
        of: find.byType(CodaDellaTestata),
        matching: find.text('Rita Rossi'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PAGINA TU'), findsOneWidget);
  });

  testWidgets('chi non allena non vede le voci di chi allena', (tester) async {
    await disegna(tester);

    expect(find.text('I miei utenti'), findsNothing);
    expect(find.text('Le mie schede'), findsNothing);
    expect(find.text('SE ALLENI'), findsNothing);
  });

  testWidgets('chi allena le vede tutte', (tester) async {
    await disegna(tester, allena: true);

    expect(find.text('SE ALLENI'), findsOneWidget);
    expect(find.text('I miei utenti'), findsOneWidget);
    expect(find.text('I miei consigli alimentari'), findsOneWidget);
    expect(find.text('Le mie schede'), findsOneWidget);
  });
}

class _BackupFinto extends BackupAutomatico {
  _BackupFinto(this.stato);

  final StatoBackup stato;

  @override
  Future<StatoBackup> build() async => stato;
}

/// 💡 Un telefono senza impronta: la riga dello sblocco rapido non si disegna,
/// e il test non tocca il plugin vero.
class _BloccoFinto extends BloccoBiometrico {
  @override
  Future<bool> disponibile() async => false;
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
