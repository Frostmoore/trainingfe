import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/acquisti/data/listino.dart';
import 'package:training_companion/src/features/trainer/ui/scelta_del_piano.dart';

/// 💳 **Il tuo piano da trainer** — §9.6, 18/09/2026.
///
/// ⛔ Fino al 18/09 un trainer non aveva nessun posto dove pagare il suo piano:
/// «I miei utenti» diceva *«serve un piano superiore»* e non c'era un pulsante.
void main() {
  Map<String, dynamic> risposta({
    String? attuale,
    bool puoCambiare = false,
    String? fallito,
  }) => {
    'abbonato': false,
    'livello': 'free',
    'pacchetti': const [],
    'gettoni_disponibili': 0,
    'piani': [
      {
        'codice': 'trainer_5',
        'nome': 'Trainer — 5 allievi',
        'prezzo_cent': 1990,
        'posti': 5,
        'a_consumo': false,
      },
      {
        'codice': 'trainer_15',
        'nome': 'Trainer — 15 allievi',
        'prezzo_cent': 4990,
        'posti': 15,
        'a_consumo': false,
      },
      {
        'codice': 'gym_consumo',
        'nome': 'Consumo',
        'prezzo_cent': 0,
        'a_consumo': true,
      },
    ],
    'piano_attuale': attuale,
    'puo_cambiare': puoCambiare,
    'pagamento_fallito_il': fallito,
  };

  group('la lettura del listino', () {
    test('legge i piani, quello attuale e il pagamento fallito', () {
      final l = Listino.fromJson(
        risposta(
          attuale: 'trainer_5',
          puoCambiare: true,
          fallito: '2026-09-16',
        ),
      );

      expect(l.piani.map((p) => p.codice), contains('trainer_15'));
      expect(l.pianoAttuale, 'trainer_5');
      expect(l.puoCambiare, isTrue);
      expect(l.pagamentoFallitoIl, DateTime(2026, 9, 16));
    });

    /// ⚠️ **Un server vecchio non li manda**: niente da comprare, e nessun crash.
    test('una risposta senza piani regge', () {
      final l = Listino.fromJson(const {'abbonato': false});

      expect(l.piani, isEmpty);
      expect(l.pianoAttuale, isNull);
      expect(l.puoCambiare, isFalse);
      expect(l.pagamentoFallitoIl, isNull);
    });
  });

  group('il foglio dei piani', () {
    Future<void> apri(WidgetTester tester, Map<String, dynamic> dati) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            listinoProvider.overrideWith((ref) async => Listino.fromJson(dati)),
          ],
          child: const MaterialApp(home: Scaffold(body: SceltaDelPiano())),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('elenca i piani da trainer, e non il consumo', (tester) async {
      await apri(tester, risposta());

      expect(find.text('Trainer — 5 allievi'), findsOneWidget);
      expect(find.text('Trainer — 15 allievi'), findsOneWidget);
      expect(find.text('Consumo'), findsNothing);
    });

    testWidgets('il piano che ha già è segnato, e non si ricompra', (
      tester,
    ) async {
      await apri(tester, risposta(attuale: 'trainer_5', puoCambiare: true));

      expect(find.text('Il tuo'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Passa'), findsOneWidget);
    });

    /// 🚨 **Il tasto dice cosa succede**: senza un piano si **sceglie** (e si
    /// paga), con un piano si **passa** (e Stripe fa il conguaglio).
    testWidgets('senza un piano si sceglie', (tester) async {
      await apri(tester, risposta());

      expect(find.widgetWithText(FilledButton, 'Scegli'), findsNWidgets(2));
      expect(find.widgetWithText(FilledButton, 'Passa'), findsNothing);
    });

    /// 🚨 **Il pagamento non riuscito si vede**, e per primo.
    testWidgets('il pagamento non riuscito si vede', (tester) async {
      await apri(
        tester,
        risposta(
          attuale: 'trainer_5',
          puoCambiare: true,
          fallito: '2026-09-16',
        ),
      );

      expect(find.textContaining('non è andato a buon fine'), findsOneWidget);
    });

    testWidgets('senza pagamenti falliti non allarma nessuno', (tester) async {
      await apri(tester, risposta(attuale: 'trainer_5', puoCambiare: true));

      expect(find.textContaining('non è andato a buon fine'), findsNothing);
    });
  });
}
