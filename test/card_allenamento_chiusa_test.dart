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
import 'package:training_companion/src/features/training/ui/widgets/spunta_della_serie.dart';

import 'aiuto/intestazione.dart';

/// La card dell'allenamento a riposo — 3b-E.10, 26/08/2026.
///
/// ══ 📌 LA CORREZIONE, DOPO AVERLA VISTA ═══════════════════════════════════
///
/// *«non c'è bisogno che tutta l'interfaccia sia uguale all'editor, in questo
/// caso: io direi che cliccando sulla matita diventa possibile modificare nome,
/// pesi, note, foto e il selettore tra peso nessuno e iso. Altrimenti deve
/// essere solo la lista degli esercizi, con il nome scritto senza campo di
/// input»*.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// ⛔ In palestra un campo di testo è un bersaglio che si apre da solo: la
/// tastiera sale, copre metà lista, e chi voleva premere la spunta si ritrova a
/// scrivere dentro il nome dell'esercizio.
///
/// ══ ⚠️ MA NON TUTTI I CAMPI — LA SECONDA CORREZIONE ═══════════════════════
///
/// *«ripetizioni e peso devono poter essere modificate anche senza la matita»*.
///
/// 🚨 **È il gesto più frequente dell'allenamento**: si arriva al bilanciere, si
/// vede che oggi 45 sono troppi, si mettono 42,5 e si spinge. Metterlo dietro la
/// matita vorrebbe dire due tocchi in più per la cosa che si fa a ogni serie.
///
/// 💡 Quindi il confine è preciso, e questo file lo difende riga per riga:
/// **due** campi per serie (ripetizioni e carico) e **nessun altro** — il nome è
/// testo, il recupero è testo, le note sono testo.
void main() {
  late List<Override> base;
  late ArchivioSalute archivio;
  late int schedaId;

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

  setUp(() async {
    base = await intestazioneFinta();
    archivio = ArchivioSalute.inMemoria();

    schedaId = await archivio.aggiungiScheda(
      nome: 'Giorno 1',
      mia: true,
      origine: 'mia',
      scheda: jsonEncode({
        'name': 'Giorno 1',
        'exercises': [
          {
            'name': 'Panca piana',
            'exercise_id': 101,
            'notes': 'gomiti stretti',
            'serie': [
              {'reps': 12, 'weight': 40, 'rest_sec': 60},
              {'reps': 10, 'weight': 45, 'rest_sec': 90},
            ],
          },
          {
            'name': 'Plank',
            'carico': 'iso',
            'serie': [
              {'iso_sec': 30, 'rest_sec': 60},
            ],
          },
        ],
      }),
    );
  });

  tearDown(() => archivio.close());

  Widget attorno() => ProviderScope(
    overrides: [
      ...base,
      archivioSaluteProvider.overrideWithValue(archivio),
      sessionProvider.overrideWith(
        (ref, id) async => WorkoutSession(
          id: 1,
          planId: schedaId,
          planName: 'Giorno 1',
          startedAt: DateTime(2026, 8, 26, 9),
          isOpen: true,
          sets: const [],
          photos: const [],
        ),
      ),
      catalogoEserciziProvider.overrideWith(
        (ref) async => CatalogoEsercizi.vuoto,
      ),
    ],
    child: const MaterialApp(home: PlayerScreen(sessionId: 1)),
  );

  group('📖 a riposo si legge, e si correggono due numeri', () {
    /// 🚨 **Il caso che difende il confine.** Tre serie in tutto: due campi
    /// ciascuna per quelle a peso, **uno solo** per l'isometria… no: anche
    /// l'isometria ha la sua colonna (i secondi). Cinque campi in tutto, e
    /// nessuno di più.
    ///
    /// ⛔ Se ne ricompare un sesto — il nome, le note, il recupero — questo test
    /// diventa rosso prima che la schermata torni quella da scrivania.
    testWidgets('ci sono due campi per serie, e nessun altro', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      expect(
        find.byType(TextField),
        findsNWidgets(6),
        reason: 'due serie a peso + una iso, due campi ciascuna',
      );
    });

    /// 📌 *«ripetizioni e peso devono poter essere modificate anche senza la
    /// matita»*.
    testWidgets('e sono ripetizioni e peso, già compilati', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '12'), findsOneWidget);
      expect(find.widgetWithText(TextField, '40'), findsOneWidget);
      expect(find.widgetWithText(TextField, '10'), findsOneWidget);
      expect(find.widgetWithText(TextField, '45'), findsOneWidget);
    });

    /// ⏱️ Il recupero **si legge e non si tocca**: è una prescrizione che si
    /// corregge una volta ogni tanto, e sta bene sotto la matita. ⚠️ Ed è anche
    /// quello che tiene la riga larga abbastanza per due campi a 328 px.
    testWidgets('ma il recupero è testo, non un campo', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      expect(find.text('60s'), findsWidgets);
      expect(find.widgetWithText(TextField, '60s'), findsNothing);
    });

    /// 📌 *«con il nome scritto senza campo di input»*.
    testWidgets('il nome è testo, non un campo', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      expect(find.text('Panca piana'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Panca piana'), findsNothing);
    });

    /// ⚠️ **La spunta c'è in tutti e due gli stati**: è l'unica cosa che si fa
    /// sempre, e nasconderla dietro un tocco vorrebbe dire un tocco in più per
    /// ogni serie di ogni allenamento.
    testWidgets('ma le spunte ci sono, una per serie', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      expect(find.byType(SpuntaDellaSerie), findsNWidgets(3));
    });

    testWidgets('le note si leggono e non si scrivono', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      expect(find.text('gomiti stretti'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'gomiti stretti'), findsNothing);
    });

    /// ⚠️ Con `Iso.` la colonna dei chili diventa **secondi**, come nell'editor:
    /// stessa etichetta, stesso campo, nessuna sorpresa passando da una
    /// schermata all'altra.
    testWidgets('e l\'isometria mostra i secondi, non i chili', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, '30'), findsOneWidget);
      expect(find.text('Sec.'), findsOneWidget);
      expect(find.text('Kg'), findsNWidgets(2));
    });

    /// ⛔ **Il cestino non c'è**: è l'unico gesto distruttivo della schermata, e
    /// a card chiusa starebbe a due centimetri dalle spunte.
    testWidgets('e non si può cancellare niente per sbaglio', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    /// ↕️ La maniglia invece resta: in sala si sposta un esercizio perché la
    /// macchina è occupata, non perché lo si sta modificando.
    testWidgets('ma si può ancora spostare', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle_rounded), findsNWidgets(2));
    });
  });

  group('✏️ la matita apre l\'editor', () {
    /// 📌 *«cliccando sulla matita diventa possibile modificare nome, pesi,
    /// note, foto e il selettore tra peso nessuno e iso»*.
    testWidgets('e allora ci sono i campi, il carico e il cestino', (
      tester,
    ) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Panca piana'), findsOneWidget);
      expect(find.widgetWithText(TextField, '40'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'gomiti stretti'), findsOneWidget);
      expect(find.text('Iso.'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    /// ⚠️ **Si apre solo quella toccata.** Aprirle tutte rifarebbe la schermata
    /// da scrivania al primo tocco.
    testWidgets('e solo quella toccata', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.text('Plank'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Plank'), findsNothing);
    });

    testWidgets('e il «fatto» la richiude', (tester) async {
      await tester.pumpWidget(attorno());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Panca piana'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_rounded).first);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'Panca piana'), findsNothing);
      expect(find.text('Panca piana'), findsOneWidget);
    });
  });

  /// 🚨 **Il giro completo del gesto più frequente**, senza mai aprire la card:
  /// si corregge il peso e si spunta. ⛔ Se questo si rompe, l'allenamento
  /// registra il numero che c'era sulla scheda invece di quello fatto davvero —
  /// e nessuno se ne accorge fino a mesi dopo, guardando lo storico.
  testWidgets('✏️ correggere un peso senza la matita finisce nella scheda', (
    tester,
  ) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '45'), '42.5');
    await tester.pumpAndSettle();

    /*
     * ⚠️ **Quello che si batte a mano si scrive dopo 700 ms**, non subito: una
     * transazione per tasto mentre si compila un peso sarebbe uno spreco (3b-E.6).
     * 🚨 I gesti — spuntare, togliere, spostare — scrivono invece all'istante, ed
     * e' la differenza che questo test rende esplicita.
     */
    await tester.pump(attesaPrimaDiScrivere + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final r = await archivio.laScheda(schedaId);
    final scheda = (jsonDecode(r!.scheda) as Map).cast<String, dynamic>();
    final serie = ((scheda['exercises'] as List).first as Map)['serie'] as List;

    expect((serie[1] as Map)['weight'], 42.5);
  });

  /// ⚠️ **Un esercizio appena aggiunto nasce aperto.** A card chiusa mostrerebbe
  /// una riga vuota e nessun modo evidente di riempirla, e chi l'ha appena
  /// creato dovrebbe cercare la matita per fare la cosa che stava già facendo.
  testWidgets('➕ un esercizio nuovo nasce già aperto', (tester) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aggiungi esercizio'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Esercizio'), findsOneWidget);
    expect(
      find.text('Muscoli: da indicare'),
      findsOneWidget,
      reason: 'nasce aperto, quindi si vede subito cosa manca',
    );
  });
}
