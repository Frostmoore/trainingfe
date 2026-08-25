import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/health/health_controller.dart';
import 'package:training_companion/src/features/training/data/catalogo_esercizi.dart';
import 'package:training_companion/src/features/training/data/gruppo_muscolare.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';
import 'package:training_companion/src/features/training/session_controller.dart';
import 'package:training_companion/src/features/training/ui/player_screen.dart';
import 'package:training_companion/src/features/training/ui/widgets/spunta_della_serie.dart';

import 'aiuto/intestazione.dart';

/// La spunta e quello che registra — 3b-E.2/E.4/E.5, 25/08/2026.
///
/// ══ 📌 LE RICHIESTE ═══════════════════════════════════════════════════════
///
/// *«Il segno di spunta per marcare la serie come completata dovrebbe essere più
/// piccolo e più carino»* · *«il tempo di riposo deve seguire quello indicato
/// nella scheda»* · *«Tutte le serie devono essere rappresentate anche qui come
/// righe separate, con campi precompilati secondo quanto registrato nella
/// scheda»*.
///
/// ══ 🚨 PERCHE' SI PROVA QUI E NON A MANO ══════════════════════════════════
///
/// ⛔ Tutto quello che può andare storto in questa schermata è **silenzioso**:
/// una serie che si registra col numero di un'altra, un recupero che ricade sul
/// valore di fabbrica, un peso preso dalla riga sbagliata. Nessuno di questi dà
/// un errore, e ci si accorge solo giorni dopo guardando lo storico — quando
/// rifarli è impossibile.
void main() {
  late List<Override> base;
  late ArchivioSalute archivio;
  late int schedaId;
  late List<Map<String, Object?>> registrate;

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
    registrate = [];

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
            'serie': [
              // 💡 Una piramide vera, con il recupero che cresce: è così che
              // sono scritte le schede, ed è il caso che il modello vecchio —
              // un peso e un recupero per tutto l'esercizio — non sapeva dire.
              {'reps': 12, 'weight': 40, 'rest_sec': 60},
              {'reps': 10, 'weight': 45, 'rest_sec': 90},
              {'reps': 8, 'weight': 50, 'rest_sec': 120},
            ],
          },
        ],
      }),
    );
  });

  tearDown(() => archivio.close());

  WorkoutSession sessione({List<LoggedSet> serie = const []}) => WorkoutSession(
    id: 1,
    planId: schedaId,
    planName: 'Giorno 1',
    startedAt: DateTime(2026, 8, 25, 18),
    isOpen: true,
    sets: serie,
    photos: const [],
  );

  Widget attorno({List<LoggedSet> fatte = const []}) => ProviderScope(
    overrides: [
      ...base,
      archivioSaluteProvider.overrideWithValue(archivio),
      sessionProvider.overrideWith((ref, id) async => sessione(serie: fatte)),
      catalogoEserciziProvider.overrideWith(
        (ref) async => CatalogoEsercizi.vuoto,
      ),
      sessionActionsProvider.overrideWith(
        (ref) => _AzioniFinte(ref, registrate),
      ),
    ],
    child: const MaterialApp(home: PlayerScreen(sessionId: 1)),
  );

  testWidgets('c\'è una spunta per ogni serie, e nessuna in più', (
    tester,
  ) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    expect(find.byType(SpuntaDellaSerie), findsNWidgets(3));
  });

  /// 📌 *«con campi precompilati secondo quanto registrato nella scheda»*.
  ///
  /// 🚨 È la differenza che si vede a schermo: prima l'esercizio aveva **un**
  /// peso e **un** recupero per tutte le serie, e una piramide non si poteva
  /// raccontare.
  testWidgets('i campi arrivano già scritti, riga per riga', (tester) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    for (final valore in ['12', '40', '60', '10', '45', '90', '8', '50']) {
      expect(
        find.text(valore),
        findsWidgets,
        reason: '$valore doveva essere già scritto in una riga',
      );
    }
  });

  /// ⚠️ **Si registra quello che c'è nella riga**, non quello che c'era nella
  /// prescrizione: sono lo stesso campo, ed è tutto il punto di 3b-E.
  testWidgets('la spunta registra i numeri della SUA riga', (tester) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SpuntaDellaSerie).at(1));
    await tester.pumpAndSettle();

    expect(registrate, hasLength(1));
    expect(registrate.single['setNumber'], 2);
    expect(registrate.single['reps'], 10);
    expect(registrate.single['weight'], 45.0);
  });

  /// 📌 *«il tempo di riposo deve seguire quello indicato nella scheda»*.
  ///
  /// ⛔ Prima era **uno per esercizio**: 90 secondi anche prima dell'ultima
  /// serie, dove la scheda ne diceva 120.
  testWidgets('e il recupero è quello della sua riga', (tester) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SpuntaDellaSerie).at(2));
    await tester.pumpAndSettle();

    expect(registrate.single['restSec'], 120);
  });

  /// 🚨 Correggere il peso **prima** di spuntare è il gesto normale: si arriva
  /// al bilanciere, si vede che 45 sono troppi, si mettono 42.5 e si spinge.
  testWidgets('correggere un numero e poi spuntare registra il numero nuovo', (
    tester,
  ) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '45'), '42.5');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SpuntaDellaSerie).at(1));
    await tester.pumpAndSettle();

    expect(registrate.single['weight'], 42.5);
  });

  /// ⛔ **E finisce anche nella scheda**, che è la richiesta in maiuscolo:
  /// *«TUTTE LE MODIFICHE fatte durante l'allenamento devono modificare la
  /// scheda»*.
  testWidgets('e il numero nuovo resta scritto nella scheda', (tester) async {
    await tester.pumpWidget(attorno());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, '45'), '42.5');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SpuntaDellaSerie).at(1));
    await tester.pumpAndSettle();

    final r = await archivio.laScheda(schedaId);
    final scheda = (jsonDecode(r!.scheda) as Map).cast<String, dynamic>();
    final serie =
        ((scheda['exercises'] as List).single as Map)['serie'] as List;

    expect((serie[1] as Map)['weight'], 42.5);
    expect(
      (serie[0] as Map)['weight'],
      40,
      reason: 'le altre righe non si toccano',
    );
  });

  /// ══ 🚨 IL DIFETTO CHE `numeroRegistrato` ESISTE PER NON FARE ═══════════
  ///
  /// ⛔ Togliendo una riga già spuntata, quelle sotto scivolano su: ri-spuntando
  /// la terza — che adesso è la seconda — si scriverebbe **sopra** la serie 2
  /// già in archivio. ⚠️ La scrittura è un upsert su (seduta, esercizio,
  /// numero): non darebbe nessun errore, solo un peso al posto di un altro.
  testWidgets('una serie già registrata tiene il suo numero', (tester) async {
    await tester.pumpWidget(
      attorno(
        fatte: [
          const LoggedSet(
            id: 1,
            exerciseId: 101,
            exerciseName: 'Panca piana',
            setNumber: 3,
            reps: 8,
            weight: 50,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    // La prima riga se ne va: la terza diventa la seconda.
    await tester.drag(
      find.widgetWithText(TextField, '12').first,
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SpuntaDellaSerie).last);
    await tester.pumpAndSettle();

    expect(
      registrate.single['setNumber'],
      3,
      reason: 'era la serie 3 quando è stata fatta, e resta la 3',
    );
  });

  /// 💡 Riaprendo una seduta interrotta le spunte devono esserci: senza, si
  /// rifanno delle serie già fatte — o si crede di averle fatte e si salta.
  testWidgets('riaprendo una seduta le spunte sono già al loro posto', (
    tester,
  ) async {
    await tester.pumpWidget(
      attorno(
        fatte: [
          const LoggedSet(
            id: 1,
            exerciseId: 101,
            exerciseName: 'Panca piana',
            setNumber: 1,
            reps: 12,
            weight: 40,
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Esercizio 1 · 1 di 3'), findsOneWidget);
  });
}

/// Le azioni della seduta, senza archivio e senza rete.
///
/// ⚠️ Si **estende** la classe vera invece di inventarne un'interfaccia: così
/// il giorno in cui `logSet` cambia firma, questo file non compila — che è
/// esattamente quello che deve succedere.
class _AzioniFinte extends SessionActions {
  _AzioniFinte(super.ref, this.registrate);

  final List<Map<String, Object?>> registrate;

  @override
  Future<int> logSet({
    required int sessionId,
    required int setNumber,
    int? exerciseId,
    String? exerciseName,
    MuscoliScelti? muscoli,
    int? reps,
    double? weight,
    int? restSec,
  }) async {
    registrate.add({
      'setNumber': setNumber,
      'exerciseName': exerciseName,
      'reps': reps,
      'weight': weight,
      'restSec': restSec,
    });

    return exerciseId ?? 1;
  }
}
