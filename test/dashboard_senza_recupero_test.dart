import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/dashboard/data/dashboard_models.dart';
import 'package:training_companion/src/features/dashboard/ui/widgets/today_cards.dart';
import 'package:training_companion/src/features/health/health_controller.dart';

/// 🚨 **Il contratto nuovo di `/dashboard` — S2.4.**
///
/// Dopo la fase S1 il backend **non manda più** `sleep` né `vitals`: sonno, HRV
/// e battito restano sul telefono di chi li produce (decisione D9).
///
/// Questi test esistono per la regola *«quando un test verifica la forma di una
/// risposta, ne serve un altro che verifichi chi la consuma»*. Il backend ha già
/// il suo (`the_dashboard_no_longer_carries_any_body_signal`); questo è il lato
/// dell'app, ed è quello che dice se la schermata **si disegna** o sparisce.
///
/// ⚠️ Non è un test di cortesia: un'eccezione durante il layout **non lascia un
/// widget storto, fa sparire la schermata intera** (§8.9 dell'atlante). Se
/// `DashboardSummary` avesse preteso quelle chiavi, il sintomo non sarebbe stato
/// «manca il recupero»: sarebbe stata la pagina principale bianca.
void main() {
  /// La risposta come la manda il backend **dopo S1**: senza `sleep`, senza
  /// `vitals`. Copiata dalla struttura reale, non inventata.
  Map<String, dynamic> rispostaDopoS1() => {
    'date': '2026-08-11',
    'now': '2026-08-11T10:00:00+00:00',
    'hour': 10,
    'day_progress_pct': 23,
    'nutrition': {
      'totals': {'kcal': 800.0, 'protein': 40.0, 'carbs': 90.0, 'fat': 25.0},
      'targets': {'kcal': 2400.0, 'protein': 150.0, 'carbs': 250.0, 'fat': 80.0},
      'burned': {'kcal': 300},
      'entries_count': 2,
    },
    'training': {
      'last_30_days': 5,
      'days_since_last': 2,
      'open_session_id': null,
      'recent': <dynamic>[],
    },
    'body': {'weight_kg': 84.2, 'weight_delta': -0.8, 'target_weight_kg': 78.0},
  };

  group('la risposta senza recupero', () {
    test('si legge senza lanciare, e sonno e parametri restano vuoti', () {
      final riepilogo = DashboardSummary.fromJson(rispostaDopoS1());

      // 🚨 `null`, non un oggetto vuoto: «non lo so» e «zero» sono due cose
      // diverse, e la seconda si disegnerebbe come un valore pessimo.
      expect(riepilogo.sleep, isNull);
      expect(riepilogo.vitals, isEmpty);
      expect(riepilogo.hasVitals, isFalse);
    });

    test('il resto del riepilogo arriva intero', () {
      final riepilogo = DashboardSummary.fromJson(rispostaDopoS1());

      // Se togliendo due chiavi si fosse rotto qualcos'altro, si vedrebbe qui.
      expect(riepilogo.nutrition.kcal, 800.0);
      expect(riepilogo.training.last30Days, 5);
      expect(riepilogo.body.weightKg, 84.2);
      expect(riepilogo.dayProgressPct, 23);
    });
  });

  group('la card del recupero', () {
    /// Un archivio vuoto: nessun dato del sensore su questo telefono.
    ///
    /// ⚠️ Da S4.3 la card **non legge più da `DashboardSummary`**: legge da
    /// `recuperoProvider`, cioè dall'archivio locale. Per questo il test
    /// costruisce un `ProviderScope` invece di passare un modello.
    Widget conArchivioVuoto(Widget figlio) {
      final archivio = ArchivioSalute.inMemoria();

      addTearDown(archivio.close);

      return ProviderScope(
        overrides: [archivioSaluteProvider.overrideWithValue(archivio)],
        child: MaterialApp(home: Scaffold(body: figlio)),
      );
    }

    testWidgets('senza dati invita a collegare, invece di promettere', (tester) async {
      await tester.pumpWidget(conArchivioVuoto(const RecoveryCard()));
      await tester.pumpAndSettle();

      // 🚨 Prima di S2 qui c'era «compaiono appena il tuo orologio comincia a
      // inviarli»: una promessa che dopo S1 nessuno poteva mantenere, perché il
      // canale di ingest non esisteva più. Adesso c'è qualcosa che si **può
      // fare**, ed è a un tocco.
      expect(find.textContaining('orologio'), findsNothing);
      expect(find.textContaining('Collega Health Connect'), findsOneWidget);
      expect(find.textContaining('restano sul tuo telefono'), findsOneWidget);
    });

    testWidgets('e non fa esplodere il layout dentro una colonna stretta', (tester) async {
      // 320 px: la larghezza sotto cui la barra del recupero era già esplosa
      // una volta (F1). Il layout si prova dove rompe, non dove sta comodo.
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        conArchivioVuoto(
          const Column(
            children: [RecoveryCard(), Expanded(child: SizedBox())],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
