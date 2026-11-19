/// 📅 **La settimana programmata in testata** — `plan_interfaccia.md` I4,
/// 19/11/2026.
///
/// | Caso | Cosa difende |
/// |---|---|
/// | sette caselle, piene dove c'è una scheda | la settimana si legge com'è, non solo «quanti giorni» |
/// | dice quanti giorni | la frase del vecchio riquadro non si è persa |
/// | senza abbonamento si capisce che è bloccata | 3b-I.A: *«si deve capire che sono bloccati»* |
/// | toccarla apre la settimana | l'ingresso del 27/08 non sparisce |
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:training_companion/src/core/router/app_router.dart';
import 'package:training_companion/src/features/training/settimana_controller.dart';
import 'package:training_companion/src/features/training/ui/widgets/settimana_in_testata.dart';

void main() {
  Future<void> monta(
    WidgetTester tester, {
    List<int?> giorni = const [7, null, 8, null, 7, null, null],
    bool puo = true,
  }) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: Center(child: SettimanaInTestata())),
        ),
        GoRoute(
          path: AppRoutes.settimana,
          builder: (_, _) => const Scaffold(body: Text('LA SETTIMANA')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settimanaProvider.overrideWith((ref) async => giorni),
          puoProgrammareProvider.overrideWith((ref) => puo),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Le caselle piene: quelle col colore primario.
  int piene(WidgetTester tester) {
    final primario = Theme.of(
      tester.element(find.byType(SettimanaInTestata)),
    ).colorScheme.primary;

    return tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(AspectRatio),
            matching: find.byType(DecoratedBox),
          ),
        )
        .where((d) => (d.decoration as BoxDecoration).color == primario)
        .length;
  }

  testWidgets('sette caselle, piene dove c’è una scheda', (tester) async {
    await monta(tester);

    expect(find.byType(AspectRatio), findsNWidgets(7));
    expect(piene(tester), 3);
  });

  testWidgets('dice quanti giorni sono programmati', (tester) async {
    await monta(tester);

    expect(find.text('3 giorni · cambia'), findsOneWidget);
  });

  testWidgets('senza abbonamento si capisce che è bloccata', (tester) async {
    await monta(tester, puo: false);

    expect(find.text('Serve l\'abbonamento'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
  });

  testWidgets('toccarla apre la settimana', (tester) async {
    await monta(tester);

    await tester.tap(find.byType(SettimanaInTestata));
    await tester.pumpAndSettle();

    expect(find.text('LA SETTIMANA'), findsOneWidget);
  });
}
