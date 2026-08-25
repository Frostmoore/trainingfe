import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/ui/widgets/barra_del_consumo.dart';

/// La barra delle calorie bruciate — 3b-B.19, corretta in 3b-F.
///
/// 📌 *«vorrei sotto un'altra barra dove mi dice le calorie bruciate … le
/// calorie che ho bruciato perché sono vivo del colore d'accento, e le calorie
/// "attive" diciamo rosse … ma nella stessa barra»*.
///
/// ══ 🚨 IL 26/08 IL PRIMO SEGMENTO E' CAMBIATO ═════════════════════════════
///
/// ⛔ Era il **basale**, cioè quello che si brucia stando fermi. 📌 Il
/// committente: *«la seconda barra della prima card non mi deve indicare
/// l'obbiettivo ma il vero e proprio dispendio energetico della giornata»* —
/// e sul suo gradino (1.2, «poco o nessun esercizio») il TDEE **è** la vita
/// quotidiana, senza allenamenti.
///
/// 💡 Quindi adesso è **vita quotidiana + allenamento**, e la barra dice quanto
/// si è speso davvero invece di un numero più basso del vero.
void main() {
  // ⚠️ Il TDEE della giornata intera: è quello che si mappa sull'ora.
  const tdee = 1800.0;

  DateTime alle(int ora, [int minuti = 0]) =>
      DateTime(2026, 8, 25, ora, minuti);

  group('🕒 il basale si mappa sull\'ora', () {
    test('a mezzanotte non hai ancora bruciato niente', () {
      expect(consumoFinora(kcalDelGiorno: tdee, adesso: alle(0)), 0);
    });

    test('a mezzogiorno ne hai bruciato metà', () {
      expect(consumoFinora(kcalDelGiorno: tdee, adesso: alle(12)), 900);
    });

    test('e a fine giornata quasi tutto', () {
      expect(
        consumoFinora(kcalDelGiorno: tdee, adesso: alle(23, 59)),
        closeTo(tdee, 2),
      );
    });

    /// ⛔ **È il difetto che si sarebbe preso usando `dayProgressPct`**, che è
    /// lì nella stessa card e conta dalle 6 alle 23: alle 6 vale **0**, ma di
    /// calorie ne hai già bruciate sei ore. La barra avrebbe detto «zero» a chi
    /// si sveglia presto.
    test('alle 6 del mattino NON è zero: un quarto è già andato', () {
      expect(consumoFinora(kcalDelGiorno: tdee, adesso: alle(6)), tdee / 4);
    });
  });

  group('🔥 una barra sola, due colori', () {
    /// Le larghezze dei due segmenti, in pixel, su una barra larga [larghezza].
    Future<({double riposo, double movimento})> segmenti(
      WidgetTester tester, {
      required double quotidiano,
      required double allenamento,
      required double tdee,
      double larghezza = 300,
    }) async {
      const accento = Color(0xFF0E7C66);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: const ColorScheme.light(primary: accento),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: larghezza,
                child: BarraDelConsumo(
                  quotidiano: quotidiano,
                  allenamento: allenamento,
                  tdee: tdee,
                ),
              ),
            ),
          ),
        ),
      );

      double largo(Color colore) {
        final trovati = find.byWidgetPredicate(
          (w) => w is ColoredBox && w.color == colore,
        );

        return trovati.evaluate().isEmpty ? 0 : tester.getSize(trovati).width;
      }

      return (riposo: largo(accento), movimento: largo(BarraDelConsumo.fuoco));
    }

    testWidgets('il riposo è lungo quanto la sua quota di TDEE', (
      tester,
    ) async {
      final s = await segmenti(
        tester,
        quotidiano: 900,
        allenamento: 0,
        tdee: 1800,
      );

      expect(s.riposo, 150, reason: 'metà di una barra da 300');
      expect(s.movimento, 0);
    });

    /// 📌 *«ma nella stessa barra»*: il movimento **si aggiunge** al riposo, non
    /// gli si sovrappone e non sta in una barra sua.
    testWidgets('e il movimento parte dove finisce il riposo', (tester) async {
      final s = await segmenti(
        tester,
        quotidiano: 900,
        allenamento: 300,
        tdee: 1800,
      );

      expect(s.riposo, 150);
      expect(s.movimento, 50, reason: '300 kcal su 1800 di un\'asta da 300px');
    });

    /// ⚠️ Superare il TDEE è **normale** — un giorno in cui ci si è mossi più
    /// del previsto. La barra si riempie e basta: non straborda, e non diventa
    /// rossa d'errore, che sarebbe la lettura opposta di quella giusta.
    testWidgets('chi supera il TDEE riempie la barra, non la sfonda', (
      tester,
    ) async {
      final s = await segmenti(
        tester,
        quotidiano: 900,
        allenamento: 3000,
        tdee: 1800,
      );

      expect(s.riposo + s.movimento, 300);
    });

    /// 🚨 E il riposo non si mangia lo spazio del movimento: se da solo copre
    /// già tutto, il movimento resta a zero invece di uscire dalla barra.
    testWidgets('e nemmeno il solo riposo la sfonda', (tester) async {
      final s = await segmenti(
        tester,
        quotidiano: 5000,
        allenamento: 500,
        tdee: 1800,
      );

      expect(s.riposo, 300);
      expect(s.movimento, 0);
    });

    /// ⚠️ Un TDEE a zero vuol dire profilo incompleto: si disegna una barra
    /// vuota, **non** una divisione per zero.
    testWidgets('senza TDEE non esplode', (tester) async {
      final s = await segmenti(
        tester,
        quotidiano: 900,
        allenamento: 100,
        tdee: 0,
      );

      expect(s.riposo, 0);
      expect(s.movimento, 0);
    });
  });

  group('🏷️ la legenda dice quale pezzo è quale', () {
    testWidgets('due voci, due numeri', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LegendaDelConsumo(quotidiano: 1320.4, allenamento: 160.7),
          ),
        ),
      );

      expect(find.text('vita quotidiana 1320'), findsOneWidget);
      expect(find.text('allenamento 161'), findsOneWidget);
    });
  });
}
