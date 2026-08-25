import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/health/health_controller.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';
import 'package:training_companion/src/features/training/session_controller.dart';
import 'package:training_companion/src/features/training/ui/player_screen.dart';

import 'aiuto/intestazione.dart';

/// Togliere un esercizio dal player — 3b-B.15 (24/08), rifatto in 3b-E.
///
/// ══ 🚨 IL DIFETTO CHE QUESTO FILE ESISTE PER NON RIFARE ═══════════════════
///
/// 📌 Il committente, dopo un allenamento vero: *«durante l'allenamento ho
/// cercato di rimuovere curl invertito, ma non mi è sparito dalla scheda quindi
/// semplicemente l'ho fatto»*. E sul server, a fine seduta, di esercizi ne erano
/// spariti **due**: Curl Invertito **e** quello subito dopo.
///
/// ⛔ **La causa: le card degli esercizi sono `StatefulWidget` senza `Key`,
/// dentro una lista.** Flutter allora abbina i figli **per posizione**: tolto
/// l'elemento 8, la card che stava al 9 riceve i dati dell'8 ma **si tiene il
/// suo `State`** — e i `TextEditingController` restano quelli di prima. A
/// schermo non cambia niente.
///
/// 🚨 Il danno non è cosmetico: chi tocca «rimuovi» e non vede succedere niente
/// **tocca di nuovo**. Il secondo tocco cancella il vicino, che nel frattempo è
/// scivolato in quella posizione. Un gesto, due esercizi persi — e nessun errore
/// da nessuna parte.
///
/// ══ ⚠️ COSA È CAMBIATO IN 3b-E ════════════════════════════════════════════
///
/// La scheda non arriva più da `planDetailProvider`: si legge il **JSON grezzo**
/// dall'archivio, e ci si riscrive sopra man mano. 💡 Quindi questo file adesso
/// prova due cose insieme: che togliere funziona **e** che quello che si toglie
/// finisce davvero sul telefono.
void main() {
  late List<Override> base;
  late ArchivioSalute archivio;
  late int schedaId;

  /// ⚠️ Uno schermo alto: la lista costruisce **solo quello che si vede**, e su
  /// una finestra da 600 punti il terzo esercizio non esisterebbe affatto — il
  /// test fallirebbe per il motivo sbagliato.
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

  Map<String, dynamic> riga(String nome, int id) => {
    'name': nome,
    'exercise_id': id,
    'serie': [
      {'reps': 15, 'weight': 10, 'rest_sec': 60},
      {'reps': 15, 'weight': 10, 'rest_sec': 60},
    ],
  };

  setUp(() async {
    base = await intestazioneFinta();
    archivio = ArchivioSalute.inMemoria();

    /// Tre esercizi, come nella scheda vera: quello di mezzo è il bersaglio.
    schedaId = await archivio.aggiungiScheda(
      nome: 'Giorno 1',
      mia: true,
      origine: 'mia',
      scheda: jsonEncode({
        'name': 'Giorno 1',
        'notes': 'la scheda di agosto',
        'exercises': [
          riga('Concentration Curl', 101),
          riga('Curl Invertito (Manubrio)', 102),
          riga('Bicipiti Martello (Manubrio)', 103),
        ],
      }),
    );
  });

  tearDown(() => archivio.close());

  WorkoutSession sessione({List<LoggedSet> serie = const []}) => WorkoutSession(
    id: 1,
    planId: schedaId,
    planName: 'Giorno 1',
    startedAt: DateTime(2026, 8, 24, 16),
    isOpen: true,
    sets: serie,
    photos: const [],
  );

  Widget attorno() => ProviderScope(
    overrides: [
      ...base,
      archivioSaluteProvider.overrideWithValue(archivio),
      sessionProvider.overrideWith((ref, id) async => sessione()),
      catalogoEserciziProvider.overrideWith(
        (ref) async => CatalogoEsercizi.vuoto,
      ),
    ],
    child: const MaterialApp(home: PlayerScreen(sessionId: 1)),
  );

  /// Gli esercizi **come stanno scritti sul telefono** adesso.
  Future<List<String>> nomiSulTelefono() async {
    final r = await archivio.laScheda(schedaId);
    final scheda = (jsonDecode(r!.scheda) as Map).cast<String, dynamic>();

    return [
      for (final e in scheda['exercises'] as List) (e as Map)['name'] as String,
    ];
  }

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
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).at(1));
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
  /// sono legati alla card: senza chiavi restano attaccati alla posizione
  /// invece che all'esercizio, e dopo una rimozione il recupero di uno finisce
  /// nella card di un altro.
  testWidgets('e i parametri restano attaccati al loro esercizio', (
    tester,
  ) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('Curl Invertito (Manubrio)'), findsOneWidget);
    expect(find.text('Bicipiti Martello (Manubrio)'), findsOneWidget);
    expect(find.text('Concentration Curl'), findsNothing);
  });

  /// ══ 🆕 3b-E: E ADESSO FINISCE ANCHE SUL TELEFONO ══════════════════════
  ///
  /// 📌 *«TUTTE LE MODIFICHE fatte durante l'allenamento devono modificare la
  /// scheda»*. ⛔ Prima si chiedeva a fine seduta, con una finestra che non
  /// diceva **quali**: è così che ne sono spariti due senza che nessuno li
  /// avesse nominati.
  testWidgets('e la scheda sul telefono lo perde davvero', (tester) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    expect(await nomiSulTelefono(), hasLength(3));

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).at(1));
    await tester.pumpAndSettle();

    expect(await nomiSulTelefono(), [
      'Concentration Curl',
      'Bicipiti Martello (Manubrio)',
    ]);
  });

  /// 💡 **La rete sotto il gesto.** Adesso che togliere è definitivo e non
  /// passa più da una domanda, chi tocca il cestino per sbaglio deve potersene
  /// accorgere **nel momento in cui succede** — l'unico in cui può rimediare.
  testWidgets('ma «Annulla» lo rimette dov\'era', (tester) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).at(1));
    await tester.pumpAndSettle();

    expect(find.text('Annulla'), findsOneWidget);

    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(find.text('Curl Invertito (Manubrio)'), findsOneWidget);
    expect(await nomiSulTelefono(), [
      'Concentration Curl',
      'Curl Invertito (Manubrio)',
      'Bicipiti Martello (Manubrio)',
    ]);
  });

  /// ⚠️ La scheda si **rattoppa**, non si ricostruisce: ricostruirla è ciò che
  /// il 24/08 ha fatto sparire quello che il player non conosce.
  testWidgets('e le note della scheda non se ne vanno con lui', (tester) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded).first);
    await tester.pumpAndSettle();

    final r = await archivio.laScheda(schedaId);
    final scheda = (jsonDecode(r!.scheda) as Map).cast<String, dynamic>();

    expect(scheda['notes'], 'la scheda di agosto');
  });
}
