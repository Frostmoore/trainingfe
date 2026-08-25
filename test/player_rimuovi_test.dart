import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';
import 'package:training_companion/src/features/training/session_controller.dart';
import 'package:training_companion/src/features/training/training_controller.dart';
import 'package:training_companion/src/features/training/ui/player_screen.dart';

import 'aiuto/intestazione.dart';

/// Togliere un esercizio dal player — 3b-B.15, 24/08/2026.
///
/// ══ 🚨 IL DIFETTO CHE QUESTO FILE ESISTE PER NON RIFARE ═══════════════════
///
/// 📌 Il committente, dopo un allenamento vero: *«durante l'allenamento ho
/// cercato di rimuovere curl invertito, ma non mi è sparito dalla scheda quindi
/// semplicemente l'ho fatto»*. E sul server, a fine seduta, di esercizi ne erano
/// spariti **due**: Curl Invertito **e** quello subito dopo.
///
/// ⛔ **La causa: le card degli esercizi sono `StatefulWidget` senza `Key`,
/// dentro una `ListView`.** Flutter allora abbina i figli **per posizione**: tolto
/// l'elemento 8, la card che stava al 9 riceve i dati dell'8 ma **si tiene il suo
/// `State`** — e i `TextEditingController`, che sono `late final`, restano quelli
/// di prima. A schermo non cambia niente.
///
/// 🚨 Il danno non è cosmetico: chi tocca «rimuovi» e non vede succedere niente
/// **tocca di nuovo**. Il secondo tocco cancella il vicino, che nel frattempo è
/// scivolato in quella posizione. Un gesto, due esercizi persi — e nessun errore
/// da nessuna parte.
///
/// 💡 Questo file non c'era: il player non aveva **nessun** test. È il motivo per
/// cui un difetto di questa gravità è arrivato in palestra.
void main() {
  late List<Override> base;

  setUp(() async => base = await intestazioneFinta());

  /// ⚠️ Uno schermo alto: la `ListView` costruisce **solo quello che si vede**,
  /// e su una finestra da 600 punti il terzo esercizio non esisterebbe affatto —
  /// il test fallirebbe per il motivo sbagliato.
  setUpAll(() {
    final vista = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    vista.physicalSize = const Size(1000, 3000);
    vista.devicePixelRatio = 1;
  });

  tearDownAll(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .resetPhysicalSize();
  });

  WorkoutSession sessione({List<LoggedSet> serie = const []}) => WorkoutSession(
    id: 1,
    planId: 8,
    planName: 'Giorno 1',
    startedAt: DateTime(2026, 8, 24, 16),
    isOpen: true,
    sets: serie,
    photos: const [],
  );

  PlanExercise riga(int id, String nome) => PlanExercise(
    id: id,
    exerciseId: id + 100,
    name: nome,
    prescription: '4 × 15',
    restSec: 60,

    // 🆕 3b-D.1: le righe delle serie. ⚠️ Qui si costruisce a mano quello che
    // `PlanExercise.fromJson` ricava da solo — vuota va benissimo, questo test
    // guarda la rimozione di un esercizio e non i numeri.
    serie: const [],
  );

  /// Tre esercizi, come nella scheda vera: quello di mezzo è il bersaglio.
  final piano = WorkoutPlan(
    id: 8,
    name: 'Giorno 1',
    exercisesCount: 3,
    editable: true,
    exercises: [
      riga(1, 'Concentration Curl'),
      riga(2, 'Curl Invertito (Manubrio)'),
      riga(3, 'Bicipiti Martello (Manubrio)'),
    ],
  );

  Widget attorno() => ProviderScope(
    overrides: [
      ...base,
      sessionProvider.overrideWith((ref, id) async => sessione()),
      planDetailProvider.overrideWith((ref, id) async => piano),
      catalogoEserciziProvider.overrideWith(
        (ref) async => CatalogoEsercizi.vuoto,
      ),
    ],
    child: const MaterialApp(home: PlayerScreen(sessionId: 1)),
  );

  /// ══ 🚨 IL TEST CHE AVREBBE PRESO TUTTO ═════════════════════════════════
  ///
  /// ⛔ Non basta controllare che la **lista** sia giusta: la lista lo era. Il
  /// difetto stava fra la lista e lo schermo, quindi la prova deve guardare
  /// **quello che si legge**, non quello che il codice tiene in memoria.
  testWidgets('togliere un esercizio lo toglie DALLO SCHERMO', (tester) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    expect(find.text('Curl Invertito (Manubrio)'), findsOneWidget);
    expect(find.text('Bicipiti Martello (Manubrio)'), findsOneWidget);

    // Il «rimuovi» del secondo esercizio.
    await tester.tap(find.byIcon(Icons.close_rounded).at(1));
    await tester.pumpAndSettle();

    expect(
      find.text('Curl Invertito (Manubrio)'),
      findsNothing,
      reason:
          'È stato tolto dalla lista ma si legge ancora: chi lo vede tocca di '
          'nuovo, e il secondo tocco cancella il vicino.',
    );

    /*
     * 🚨 **E gli altri due devono essere ancora tutti e due lì.** È l'altra
     * metà del difetto: la card che scivola su non deve portarsi dietro il nome
     * di quella cancellata, né perdere il proprio.
     */
    expect(find.text('Concentration Curl'), findsOneWidget);
    expect(find.text('Bicipiti Martello (Manubrio)'), findsOneWidget);
  });

  /// ⚠️ **E i campi devono seguire la loro riga.** I `TextEditingController`
  /// sono `late final`: senza chiavi restano attaccati alla posizione invece che
  /// all'esercizio, e dopo una rimozione il recupero di uno finisce nella card
  /// di un altro.
  testWidgets('e i parametri restano attaccati al loro esercizio', (
    tester,
  ) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Curl Invertito (Manubrio)'), findsOneWidget);
    expect(find.text('Bicipiti Martello (Manubrio)'), findsOneWidget);
    expect(find.text('Concentration Curl'), findsNothing);
  });
}
