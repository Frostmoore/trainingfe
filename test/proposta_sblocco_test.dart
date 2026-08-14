import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/sicurezza/blocco_biometrico.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';
import 'package:training_companion/src/features/auth/ui/widgets/proposta_sblocco.dart';

/// La proposta dello sblocco rapido non anticipa l'accesso — 14/08/2026.
///
/// ── 🚨 Il difetto riferito provando l'app ─────────────────────────────────
///
/// *«Mi chiede l'impronta prima ancora di aver fatto la scelta di palestra o
/// autonomo.»*
///
/// Il router nasce con `initialLocation: AppRoutes.home`, e finché lo stato è
/// `AuthStatus.unknown` la regola 1 di `destinazione()` risponde «resta dove
/// sei». ⚠️ Quindi `HomeShell` **viene costruita davvero**, per la frazione di
/// secondo che serve a leggere il Keychain — e con lei `PropostaSblocco`, che al
/// primo fotogramma chiedeva l'impronta a nessuno.
///
/// 🚨 **E bruciava la proposta.** `segnaProposto()` si scrive anche quando la
/// risposta è no: la domanda «una volta sola per dispositivo» veniva spesa prima
/// del primo accesso, cioè quando non voleva dire niente.
///
/// 💡 Questi test guardano `BloccoBiometrico`: se la proposta non lo interroga,
/// non può nemmeno cominciare. È l'unico punto osservabile — il dialogo di
/// sistema lo disegna il telefono, e in un test non compare mai.
void main() {
  late ApiClient client;
  late _TokenStoreFinto token;

  setUp(() {
    token = _TokenStoreFinto();

    client = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: token,
      dio: Dio(BaseOptions(baseUrl: 'https://esempio.test/api/v1')),
    );
  });

  /// Monta il widget con uno stato di sessione deciso a mano.
  Future<(_BloccoSpia, AuthController)> monta(
    WidgetTester tester,
    AuthStatus iniziale,
  ) async {
    final spia = _BloccoSpia();
    late AuthController controller;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bloccoBiometricoProvider.overrideWithValue(spia),
          authControllerProvider.overrideWith((ref) {
            controller = AuthController(client, token, null, spia)
              ..state = AuthState(status: iniziale);

            return controller;
          }),
        ],
        child: const MaterialApp(home: Scaffold(body: PropostaSblocco())),
      ),
    );

    await tester.pump();

    return (spia, controller);
  }

  testWidgets('mentre si legge il Keychain non chiede niente', (tester) async {
    final (spia, _) = await monta(tester, AuthStatus.unknown);

    // 🚨 È il fotogramma in cui `HomeShell` esiste ma nessuno è entrato.
    expect(spia.interrogato, 0);
  });

  testWidgets('a sessione chiusa non chiede niente', (tester) async {
    final (spia, _) = await monta(tester, AuthStatus.loggedOut);

    // ⚠️ È lo stato di chi sta scegliendo palestra o «da solo»: proporgli lo
    // sblocco rapido vuol dire proporre di aprire in fretta **il nulla**.
    expect(spia.interrogato, 0);
  });

  testWidgets('a sessione bloccata non chiede niente', (tester) async {
    final (spia, _) = await monta(tester, AuthStatus.locked);

    // 💡 Chi è a schermo bloccato ha già il blocco acceso: la proposta sarebbe
    // una domanda a cui ha già risposto.
    expect(spia.interrogato, 0);
  });

  testWidgets('a sessione aperta la proposta parte', (tester) async {
    final (spia, _) = await monta(tester, AuthStatus.loggedIn);

    // 🎯 La correzione non deve **spegnere** la funzione: senza questo test,
    // «non chiede mai niente» passerebbe per una correzione riuscita.
    expect(spia.interrogato, 1);
  });

  testWidgets('parte anche se la sessione si apre DOPO', (tester) async {
    final (spia, controller) = await monta(tester, AuthStatus.unknown);

    expect(spia.interrogato, 0);

    /*
     * 🚨 **È il caso che un `initState` non prenderebbe.** Quando la sessione si
     * apre, questa shell è **già montata**: un callback piazzato alla nascita
     * del widget è passato da un pezzo, e la proposta non arriverebbe mai.
     *
     * ⚠️ Correggere il difetto guardando solo il primo fotogramma avrebbe
     * quindi **spento la funzione** invece di spostarla — e sarebbe passato per
     * una correzione riuscita, perché il sintomo sparisce in entrambi i casi.
     */
    controller.state = const AuthState(status: AuthStatus.loggedIn);
    await tester.pump();

    expect(spia.interrogato, 1);
  });

  testWidgets('e non la chiede due volte', (tester) async {
    final (spia, controller) = await monta(tester, AuthStatus.loggedIn);

    controller.state = const AuthState(status: AuthStatus.loggedIn);
    await tester.pump();
    await tester.pump();

    // ⚠️ `build` gira più volte: senza la guardia il dialogo si aprirebbe
    // sovrapposto a se stesso.
    expect(spia.interrogato, 1);
  });
}

/// 💡 Risponde sempre «non c'è niente da proporre»: serve solo a **contare**
/// se qualcuno l'ha chiesto, non a far comparire un dialogo.
class _BloccoSpia extends BloccoBiometrico {
  int interrogato = 0;

  @override
  Future<bool> daProporre() async {
    interrogato++;

    return false;
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
