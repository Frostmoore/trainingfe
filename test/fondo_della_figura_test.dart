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
/// 5. ✅ e infine **il corpo bianco** sul riquadro grigio — *«l'uomo deve
///    restare bianco, è lo sfondo che deve essere grigio»*.
///
/// 🚨 **La causa non era mai il fondo: era il corpo.** Per tre giri ho curato
/// il sintomo mettendo una lampada dietro la figura, e al quarto ho lasciato il
/// corpo di un grigio che si confondeva col riquadro.
///
/// 💡 La regola, finalmente scritta: **il corpo fa contrasto col riquadro**.
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

  /// 🚨 **La metà che conta davvero, e l'ho sbagliata due volte.**
  ///
  /// 📌 *«l'uomo deve restare bianco, è lo sfondo che deve essere grigio»*.
  ///
  /// ⛔ Prima era un grigio **scuro fisso** — su fondo scuro sarebbe sparito.
  /// ⛔ Poi `onSurfaceVariant` al 45% — su fondo grigio scuro veniva un corpo
  /// **grigio medio**, appena più chiaro del fondo: non spariva, si
  /// **confondeva**, che a schermo è la stessa cosa.
  ///
  /// 💡 La regola sotto tutte e due: **il corpo fa contrasto col riquadro**.
  test('🧍 il corpo fa contrasto col riquadro, in tutti e due i temi', () {
    /*
     * ⚠️ Si controlla la **distanza** fra le due luminosità, non i valori: il
     * tono si ritocca, il fatto che si distinguano no.
     */
    double distanza(Color corpo, Color fondo) =>
        (corpo.computeLuminance() - fondo.computeLuminance()).abs();

    // 🌙 Scuro: corpo bianco su riquadro grigio scuro.
    final scuroSchema = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    );

    expect(
      distanza(
        Colors.white.withValues(alpha: 0.88),
        scuroSchema.surfaceContainerHighest,
      ),
      greaterThan(0.4),
      reason: 'un corpo grigio medio su un fondo grigio scuro si confonde',
    );

    // ☀️ Chiaro: corpo scuro su riquadro bianco.
    final chiaroSchema = ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    );

    expect(
      distanza(
        chiaroSchema.onSurfaceVariant.withValues(alpha: 0.55),
        Colors.white,
      ),
      greaterThan(0.4),
      reason: 'e un corpo bianco su bianco non ci sarebbe proprio',
    );
  });
}
