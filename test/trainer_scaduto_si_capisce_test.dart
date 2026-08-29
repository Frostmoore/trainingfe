import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/trainer/ui/abbonamento_scaduto.dart';

/// 🎯 Un trainer scaduto deve **capire perché**, non vedere un errore — U.3.1.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«è una merda se esce solo un errore, si deve capire che è perché non ha
/// pagato»* — il committente, 29/08/2026.
///
/// 💡 La **traduzione** del 403 si prova in `api_client_test.dart`, accanto a
/// `tenant_inactive`: là c'è l'adattatore che fa passare la risposta per tutta
/// la catena. ⚠️ Costruire a mano una `DioException` non proverebbe niente —
/// `unwrapError` si limita a srotolare quello che l'interceptor ha già messo
/// dentro, e senza interceptor torna `ServerException`.
///
/// Qui si prova l'altra metà: **cosa legge la persona**.
void main() {
  testWidgets('il cartello dice perché è chiuso, e cosa NON si è perso', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AbbonamentoTrainerScaduto())),
      ),
    );

    // 1. Perché.
    expect(find.text('Abbonamento da trainer scaduto'), findsOneWidget);

    /*
     * 2. 🚨 **Cosa resta**, ed è la metà che si dimentica: un trainer che vede
     * sparire «i miei utenti» pensa di aver perso il lavoro di mesi.
     */
    expect(
      find.textContaining('Le tue schede restano tue'),
      findsOneWidget,
      reason:
          'Il cartello non dice cosa NON si è perso: è la cosa che quella '
          'persona sta cercando di capire in quel momento.',
    );

    // ⚠️ E non è un guasto: un lucchetto, non un triangolo d'errore.
    expect(find.byIcon(Icons.lock_clock_outlined), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('col messaggio del server usa quello', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: AbbonamentoTrainerScaduto(
              messaggio: 'Frase precisa arrivata dal server.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Frase precisa arrivata dal server.'), findsOneWidget);
  });
}
