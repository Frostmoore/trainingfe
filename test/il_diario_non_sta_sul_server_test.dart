import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/privacy/consensi_controller.dart';
import 'package:training_companion/src/features/privacy/ui/widgets/dove_vanno_i_dati.dart';

/// 🚨 **La privacy dice il vero su dove sta il diario** — 23/09/2026.
///
/// ══ ⛔ IL DIFETTO ══════════════════════════════════════════════════════════
///
/// La card *«Stanno sui nostri server»* elencava **«Il diario alimentare, con
/// quello che scrivi negli alimenti»**. Era vero fino al 22/09; quel giorno A1
/// ha tolto il diario dal server — migrazione `il_diario_lascia_il_server`, con
/// un guardiano nel backend
/// (`tests/Feature/Nutrition/IlDiarioNonStaSulServerTest.php`) che impedisce di
/// rimettercelo.
///
/// ⚠️ Nessuno ha riletto **questa** schermata quando il codice è cambiato, e
/// per un giorno l'app ha dichiarato di mandare sui nostri server un dato che
/// non manda più — nel punto esatto in cui si promette trasparenza.
///
/// 🚨 Ed era sbagliata **due volte**: dichiarata dove non sta, e assente da
/// dove sta. Chi apriva questa card per sapere cosa perde disinstallando l'app
/// non ci trovava il diario, che è il dato che ci mette più tempo a ricostruire.
///
/// 💡 Questo file è il gemello di quel guardiano, da questa parte: il backend
/// difende il **fatto**, questo difende quello che ne **diciamo**. Un dato che
/// si sposta e una frase che resta indietro sono due bug diversi, e il secondo
/// non lo trova nessuna suite del server.
void main() {
  const diario = 'Il diario alimentare, con quello che scrivi negli alimenti';

  Future<void> disegna(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // ⚠️ Senza, la card dell'AI resta in caricamento e il resto non si
          // costruisce: qui non interessa nessun consenso, solo l'elenco.
          consensiProvider.overrideWith((ref) async => const Consensi()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DoveVannoIDati()),
          ),
        ),
      ),
    );

    await tester.pump();
  }

  testWidgets('il diario è elencato fra i dati che restano sul telefono', (
    tester,
  ) async {
    await disegna(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('dati-sul-telefono')),
        matching: find.text(diario),
      ),
      findsOneWidget,
    );
  });

  testWidgets('e NON fra quelli che stanno sui nostri server', (tester) async {
    await disegna(tester);

    expect(
      find.descendant(
        of: find.byKey(const Key('dati-sul-server')),
        matching: find.text(diario),
      ),
      findsNothing,
      reason: 'il diario ha lasciato il server il 22/09 (A1)',
    );
  });
}
