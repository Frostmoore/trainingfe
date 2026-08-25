import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/ui/widgets/carosello_del_mese.dart';

/// Il fondo del riquadro della figura — 3b-D.13, 25/08/2026.
///
/// ══ 🚨 PERCHE' QUESTA DECISIONE HA UN TEST ════════════════════════════════
///
/// ⛔ E' stata ribaltata **due volte in un giorno**, e ogni volta con una buona
/// ragione:
///
/// 1. era `Colors.white` sempre, perché il committente aveva chiesto «un
///    quadrato con fondo bianco»;
/// 2. è diventata «segue il tema» perché *«i quadrati bianchi ti carbonizzano
///    la retina»* — con la figura come eccezione, che restava bianca;
/// 3. e la figura è diventata **chiara ma non bianca**, perché anche quella
///    eccezione abbagliava: *«facciamola semplicemente più chiara dello sfondo,
///    così è troppo bianco»*.
///
/// 🚨 Le tre richieste **non si contraddicono**: chiedono tutte e tre lo
/// **stacco** dal fondo della card, e cambia solo quanto forte. ⚠️ Ma una
/// decisione che si muove tre volte è esattamente quella che qualcuno
/// «semplifica» tornando al bianco — e questo test è ciò che lo impedisce.
void main() {
  /// Il colore del riquadro, montato nel tema chiesto.
  Future<Color?> fondo(WidgetTester tester, {required Brightness tema}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: tema),
        home: const Scaffold(
          body: RiquadroBianco(sempreChiaro: true, child: SizedBox(height: 40)),
        ),
      ),
    );

    final scatola = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(RiquadroBianco),
        matching: find.byType(DecoratedBox),
      ),
    );

    return (scatola.decoration as BoxDecoration).color;
  }

  testWidgets('☀️ in tema chiaro è bianco', (tester) async {
    expect(await fondo(tester, tema: Brightness.light), Colors.white);
  });

  testWidgets('🌙 in tema scuro è chiaro, ma NON bianco', (tester) async {
    final colore = await fondo(tester, tema: Brightness.dark);

    expect(
      colore,
      isNot(Colors.white),
      reason: 'il bianco pieno dentro una schermata scura è una lampada',
    );

    /*
     * ⛔ **E nemmeno scuro**: il PNG della figura ha i solchi fra i muscoli
     * trasparenti, quindi lascia vedere il fondo. Su un fondo scuro il disegno
     * si perde — che è il difetto da cui si era partiti.
     *
     * 💡 Si controlla la **luminosità**, non il valore esatto: il tono si può
     * ritoccare, il fatto che sia chiaro no. È la stessa forma del test sui
     * quattro colori dei muscoli.
     */
    expect(
      colore!.computeLuminance(),
      greaterThan(0.5),
      reason: 'deve restare chiaro: i solchi del PNG mostrano il fondo',
    );

    expect(
      colore.computeLuminance(),
      lessThan(0.95),
      reason: 'ma non quanto il bianco, o siamo al punto di prima',
    );
  });

  /// ⚠️ **Gli altri riquadri restano quelli di 3b-C.1**: seguono il tema, ed è
  /// la richiesta opposta fatta nella stessa frase. 🚨 Chi un giorno decidesse
  /// di uniformarli troverebbe questo test.
  testWidgets('🌗 e gli altri riquadri seguono il tema', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const Scaffold(body: RiquadroBianco(child: SizedBox(height: 40))),
      ),
    );

    final scatola = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(RiquadroBianco),
        matching: find.byType(DecoratedBox),
      ),
    );

    final colore = (scatola.decoration as BoxDecoration).color!;

    expect(colore.computeLuminance(), lessThan(0.5));
  });
}
