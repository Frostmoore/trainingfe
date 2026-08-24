import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';
import 'package:training_companion/src/features/training/ui/widgets/esercizi_fatti.dart';

/// Le card degli esercizi — 3b-B.20.3, 25/08/2026.
///
/// 📌 *«gli esercizi che ho fatto devono essere più dettagliati. va bene una
/// card per uno come hai fatto tu, ma con tutti i dettagli (rep, pesi, serie)»*.
void main() {
  LoggedSet serie({
    required int numero,
    String nome = 'Panca piana',
    int? reps = 8,
    double? peso = 40,
  }) => LoggedSet(
    id: numero,
    exerciseId: 1,
    exerciseName: nome,
    setNumber: numero,
    reps: reps,
    weight: peso,
  );

  Future<void> mostra(WidgetTester tester, EsercizioFatto e) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(children: [CardEsercizioFatto(esercizio: e)]),
          ),
        ),
      );

  group('📋 il raggruppamento', () {
    /// ⚠️ L'ordine è quello in cui le serie sono state fatte, non alfabetico:
    /// è ciò che rende l'elenco il racconto della seduta.
    test('tiene l\'ordine in cui gli esercizi sono comparsi', () {
      final gruppi = raggruppaPerEsercizio([
        serie(numero: 1, nome: 'Squat'),
        serie(numero: 1, nome: 'Panca'),
        serie(numero: 2, nome: 'Squat'),
      ]);

      expect(gruppi.map((g) => g.nome), ['Squat', 'Panca']);
      expect(gruppi.first.serie.length, 2);
    });
  });

  group('🧮 i conti dell\'esercizio', () {
    test('il volume è ripetizioni per peso, sommato', () {
      final e = EsercizioFatto.dalleSerie(
        nome: 'Panca',
        serie: [serie(numero: 1), serie(numero: 2, reps: 6, peso: 45)],
      );

      expect(e.volume, 8 * 40 + 6 * 45);
      expect(e.ripetizioni, 14);
    });

    /// 🚨 **`null`, non `0`.** A corpo libero non c'è un volume da mostrare, e
    /// «0 kg» sarebbe una risposta sbagliata a una domanda che non si può fare.
    test('a corpo libero non c\'è nessun volume', () {
      final e = EsercizioFatto.dalleSerie(
        nome: 'Trazioni',
        serie: [serie(numero: 1, peso: null)],
      );

      expect(e.volume, isNull);
      expect(e.ripetizioni, 8);
    });
  });

  group('🃏 la card', () {
    /// ⛔ Prima erano tutte su **una riga**: `8 × 40 kg · 8 × 40 kg · …`. Il
    /// numero della serie — quello che si cerca per sapere dove si è calati —
    /// non c'era.
    testWidgets('una riga per serie, numerata', (tester) async {
      await mostra(
        tester,
        EsercizioFatto.dalleSerie(
          nome: 'Panca',
          serie: [
            serie(numero: 1),
            serie(numero: 2, reps: 7),
            serie(numero: 3, reps: 6),
          ],
        ),
      );

      expect(find.text('3 serie'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('8 rip'), findsOneWidget);
      expect(find.text('7 rip'), findsOneWidget);
      expect(find.text('6 rip'), findsOneWidget);
    });

    testWidgets('e in fondo il volume', (tester) async {
      await mostra(
        tester,
        EsercizioFatto.dalleSerie(nome: 'Panca', serie: [serie(numero: 1)]),
      );

      expect(find.text('Volume'), findsOneWidget);
      expect(find.text('320 kg'), findsWidgets);
    });

    /// 🚨 **È il caso di un allenamento del polso con una scheda attaccata**:
    /// serie registrate non ce ne sono, e non ci si inventa dei carichi «per
    /// coerenza». Si dice cosa c'era scritto sulla scheda, e si dice che è
    /// quello.
    testWidgets('senza serie mostra la prescrizione, e lo dichiara', (
      tester,
    ) async {
      await mostra(
        tester,
        const EsercizioFatto(nome: 'Panca', prescrizione: '4 × 12'),
      );

      expect(find.text('4 × 12 da scheda'), findsOneWidget);
      expect(find.text('Volume'), findsNothing);
    });

    testWidgets('e senza nemmeno quella lo dice e basta', (tester) async {
      await mostra(tester, const EsercizioFatto(nome: 'Panca'));

      expect(find.text('Nessuna serie registrata.'), findsOneWidget);
    });

    /// 💡 «40 kg», non «40.0 kg».
    testWidgets('i chili non hanno decimali quando non servono', (
      tester,
    ) async {
      await mostra(
        tester,
        EsercizioFatto.dalleSerie(
          nome: 'Panca',
          serie: [serie(numero: 1, peso: 42.5)],
        ),
      );

      expect(find.text('42.5 kg'), findsOneWidget);
      expect(find.text('40.0 kg'), findsNothing);
    });
  });
}
