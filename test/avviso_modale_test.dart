import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/avvisi/avvisi_controller.dart';
import 'package:training_companion/src/features/avvisi/data/avviso.dart';
import 'package:training_companion/src/features/avvisi/ui/avviso_modale.dart';

/// 📣 **La modale di un avviso** — blocco B4, 24/09/2026.
///
/// 📌 Il committente, il 23/09: *«una modale in-app con un tasto per approvare
/// (testo che deciderò di volta in volta) e uno per rifiutare … Rifiuta chiude
/// sempre la modale e logga il rifiuto»*.
///
/// ══ 🚨 COSA GUARDANO QUESTI TEST ════════════════════════════════════════════
///
/// ⛔ Che **rifiutare sia un'uscita vera e registrata**, che le etichette siano
/// **quelle del server**, e che una risposta non arrivata **non chiuda** la
/// modale. 💡 Sono i tre modi in cui una modale del genere diventa un pedaggio.
void main() {
  Avviso avviso({
    String approva = 'Va bene',
    String rifiuta = 'No, grazie',
    String azione = 'dismiss',
  }) => Avviso(
    id: 7,
    titolo: 'Una cosa da dirti',
    testo: 'Il testo dell\'avviso.',
    tastoApprova: approva,
    tastoRifiuta: rifiuta,
    azione: azione,
  );

  Future<_AzioniFinte> apri(WidgetTester tester, Avviso a) async {
    final azioni = _AzioniFinte();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [avvisiActionsProvider.overrideWith((ref) => azioni)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => AvvisoModale.mostra(a, context),
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

  /// 🏷️ **Le etichette le scrive la piattaforma**: l'app non ne inventa nessuna.
  testWidgets('usa le etichette arrivate dal server', (tester) async {
    await apri(
      tester,
      avviso(approva: 'Ci sto', rifiuta: 'Lascia stare'),
    );

    expect(find.text('Ci sto'), findsOneWidget);
    expect(find.text('Lascia stare'), findsOneWidget);
    expect(find.text('Una cosa da dirti'), findsOneWidget);
  });

  /// ⛔ **Il rifiuto è un pulsante vero, non una «x» in un angolo.** Nascosto,
  /// direbbe che la risposta giusta è una sola — e allora non è una domanda.
  testWidgets('i due tasti ci sono tutti e due, e si vedono', (tester) async {
    await apri(tester, avviso());

    expect(find.widgetWithText(FilledButton, 'Va bene'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'No, grazie'), findsOneWidget);
  });

  testWidgets('approvare manda la risposta e chiude', (tester) async {
    final azioni = await apri(tester, avviso());

    await tester.tap(find.text('Va bene'));
    await tester.pumpAndSettle();

    expect(azioni.risposte, [(7, true)]);
    expect(find.text('Una cosa da dirti'), findsNothing);
  });

  /// 🗳️ **Anche il no si registra**: è metà del motivo per cui si manda un
  /// avviso.
  testWidgets('rifiutare manda comunque la risposta', (tester) async {
    final azioni = await apri(tester, avviso());

    await tester.tap(find.text('No, grazie'));
    await tester.pumpAndSettle();

    expect(azioni.risposte, [(7, false)]);
    expect(find.text('Una cosa da dirti'), findsNothing);
  });

  /// 🚨 **Se la risposta non arriva, la modale resta aperta.**
  ///
  /// ⛔ Chiuderla lo stesso farebbe credere di aver risposto: l'avviso
  /// tornerebbe alla prossima apertura e sembrerebbe un difetto.
  testWidgets('se il server non risponde la modale non si chiude', (
    tester,
  ) async {
    final azioni = await apri(tester, avviso());
    azioni.rompiti = true;

    await tester.tap(find.text('Va bene'));
    await tester.pumpAndSettle();

    expect(find.text('Una cosa da dirti'), findsOneWidget);
  });
}

class _AzioniFinte implements AvvisiActions {
  final risposte = <(int, bool)>[];

  bool rompiti = false;

  @override
  Future<void> rispondi(int avvisoId, {required bool approvato}) async {
    if (rompiti) throw Exception('niente rete');

    risposte.add((avvisoId, approvato));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
