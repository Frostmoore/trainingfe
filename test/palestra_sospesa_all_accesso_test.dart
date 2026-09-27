import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';
import 'package:training_companion/src/features/auth/ui/login_screen.dart';

import 'aiuto/intestazione.dart';

/// ⏸️ **Chi prova a entrare in una palestra sospesa sente che i dati sono al
/// sicuro** — 23/09/2026, dal giro UX.
///
/// ══ ⛔ IL DIFETTO ══════════════════════════════════════════════════════════
///
/// Sospesa la palestra nel database locale e rifatto l'accesso, l'app mostrava
/// la sola riga del server: *«La tua palestra è sospesa. Contattala per
/// riattivare l'accesso.»*
///
/// ⚠️ La frase che conta — **«il tuo account e i tuoi dati sono al sicuro»** —
/// viveva in una schermata dedicata che si vedeva solo **da dentro**. 🚨 Chi stava
/// provando a entrare, cioè chi se lo sta chiedendo davvero, non la riceveva.
///
/// 🆕 **27/09/2026**: quella schermata è stata **cancellata** — era irraggiungibile
/// dal 26/09 e diceva l'opposto di quello che è stato deciso (si entra, e si vede
/// l'interfaccia dei non abbonati). 💡 La costante è rimasta, e vive nella
/// schermata d'accesso: è l'unico posto che la usa.
///
/// 🔑 Questo test resta valido parola per parola, e continua a proteggere la cosa
/// giusta: che chi **non riesce a entrare** senta dire che i suoi dati sono al sicuro.
void main() {
  testWidgets('l\'errore dice anche che i dati sono al sicuro', (tester) async {
    final rete = _PalestraSospesa();
    final dio = Dio(BaseOptions(baseUrl: 'https://esempio.test/api/v1'))
      ..httpClientAdapter = rete;

    final client = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: _TokenFinto(),
      dio: dio,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // ⚠️ Il login poggia su `localCacheProvider` e sul branding: senza
          // queste sovrascritture non si costruisce, e fallirebbe per un motivo
          // che non c'entra niente con quello che si sta provando.
          ...await intestazioneFinta(),
          apiClientProvider.overrideWithValue(client),
          authControllerProvider.overrideWith(
            (ref) => AuthController(client, _TokenFinto()),
          ),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.pump();

    await tester.enterText(find.byType(TextFormField).first, 'rita@esempio.it');
    await tester.enterText(find.byType(TextFormField).last, 'Password-9');

    /*
     * ⚠️ **`runAsync` e non `pumpAndSettle`**, e serve per due motivi:
     *
     * · la chiamata finta si risolve sull'orologio **vero**, e sotto quello
     *   finto del test resterebbe in sospeso per sempre — il pulsante resta a
     *   girare e non compare nessun errore;
     * · la schermata ha un'animazione che non si ferma mai, quindi aspettare la
     *   quiete vuol dire aspettare per sempre.
     */
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Accedi'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });

    await tester.pump();

    // 🚨 Le due metà insieme: quella del server e quella nostra.
    expect(
      find.textContaining('La tua palestra è sospesa'),
      findsOneWidget,
      reason: 'manca il motivo',
    );
    expect(
      find.textContaining(rassicurazionePalestraSospesa),
      findsOneWidget,
      reason: 'manca la frase che dice che i dati non si perdono',
    );
  });
}

/// Il server di una palestra sospesa: 403 con `tenant_inactive`.
class _PalestraSospesa implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode({
      'message': 'La tua palestra è sospesa. Contattala per riattivare '
          'l\'accesso.',
      'code': 'tenant_inactive',
    }),
    403,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

class _TokenFinto implements TokenStore {
  @override
  Future<void> clear() async {}

  @override
  void forgetCache() {}

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String token) async {}
}
