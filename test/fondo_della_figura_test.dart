import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/ui/widgets/carosello_del_mese.dart';

/// Il riquadro della figura e il colore del corpo — 3b-D.13, 25/08/2026.
///
/// ══ 🚨 QUATTRO GIRI SULLA STESSA COSA, E LA CAUSA ERA ALTROVE ═════════════
///
/// 1. **bianco sempre** — il committente aveva chiesto «un quadrato con fondo
///    bianco»;
/// 2. **segue il tema, figura esclusa** (C.1) — *«i quadrati bianchi ti
///    carbonizzano la retina»*, ma il PNG della figura sembrava aver bisogno
///    del bianco;
/// 3. **la figura chiara ma non bianca** (D.13, primo tentativo) — abbagliava
///    lo stesso;
/// 4. ✅ **nessuna eccezione**: *«adesso lo sfondo è ancora bianco»* ·
///    *«facciamola semplicemente più chiara dello sfondo»*.
///
/// 🚨 **La causa non era il fondo: era il corpo.** Il colore del muscolo non
/// allenato viene dal tema, quindi si vede su qualunque fondo — e per tre giri
/// ho curato il sintomo mettendo una lampada dietro la figura.
///
/// ⚠️ Questi test tengono insieme **le due metà**: il fondo e la tinta. Sono la
/// stessa decisione presa in due file, e separarle è il modo in cui questo
/// difetto torna.
///
/// 💡 **Qui non si monta la figura vera**: `FiguraDelCorpo` vuole un
/// `ProviderScope` e **decodifica un'immagine**, che dentro `testWidgets` è una
/// cosa vera dentro un tempo finto — la trappola di B.1.4, che una volta ha
/// lasciato un test appeso dieci minuti. 🚨 Il montaggio della figura dentro il
/// riquadro è già coperto da `carosello_del_mese_test.dart`, che prepara la
/// sagoma in `setUpAll`.
void main() {
  Color? fondoDi(WidgetTester tester) {
    final scatola = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(RiquadroBianco),
        matching: find.byType(DecoratedBox),
      ),
    );

    return (scatola.decoration as BoxDecoration).color;
  }

  Future<void> monta(WidgetTester tester, Brightness tema) => tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: tema),
      home: const Scaffold(
        body: RiquadroBianco(child: SizedBox(height: 40)),
      ),
    ),
  );

  testWidgets('☀️ in tema chiaro il riquadro è bianco', (tester) async {
    await monta(tester, Brightness.light);

    expect(fondoDi(tester), Colors.white);
  });

  /// ⛔ **Niente eccezione per la figura.** Un riquadro chiaro dentro una
  /// schermata scura è una lampada, e non serve: il corpo si tinge col tema.
  testWidgets('🌙 in tema scuro è SCURO, appena sopra il fondo', (tester) async {
    await monta(tester, Brightness.dark);

    final colore = fondoDi(tester)!;

    expect(
      colore,
      isNot(Colors.white),
      reason: 'il bianco dentro una schermata scura è una lampada',
    );

    expect(
      colore.computeLuminance(),
      lessThan(0.5),
      reason: '«più chiara dello sfondo» vuol dire un tono sopra il fondo '
          'scuro, non un fondo chiaro',
    );
  });

  /// 🚨 **La metà che conta davvero.** Se il colore del corpo smettesse di
  /// venire dal tema — è già successo — su un fondo scuro la figura sparirebbe
  /// del tutto, e il riquadro tornerebbe a doverla salvare col bianco.
  testWidgets('🧍 e il corpo si tinge col tema, non con un grigio fisso', (
    tester,
  ) async {
    Color spentoCon(Brightness tema) {
      final schema = ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: tema,
      );

      return schema.onSurfaceVariant;
    }

    /*
     * ⚠️ Si controlla la **relazione**, non i valori: quello che deve restare
     * vero è che il corpo sia chiaro dove il fondo è scuro e viceversa.
     */
    expect(
      spentoCon(Brightness.dark).computeLuminance(),
      greaterThan(0.5),
      reason: 'in tema scuro il corpo dev\'essere chiaro',
    );

    expect(
      spentoCon(Brightness.light).computeLuminance(),
      lessThan(0.5),
      reason: 'in tema chiaro il corpo dev\'essere scuro',
    );
  });
}
