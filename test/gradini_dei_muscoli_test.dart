import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/ui/widgets/figura_del_corpo.dart';

/// I quattro gradini della figura — 3b-C.9, 25/08/2026.
///
/// 📌 *«non facciamo più o meno rosso per l'uso dei muscoli, facciamo 4 colori:
/// nessuno, verde, giallo, rosso. Secondo me è più chiaro»*.
///
/// ⛔ Prima era una scala continua di rosso. ⚠️ Il difetto non era estetico: due
/// muscoli allo 0,55 e allo 0,70 avevano due rossi indistinguibili, e chi
/// guardava non poteva dire quale dei due avesse allenato di più. **Sembrava
/// informazione e non lo era.**
void main() {
  group('🪜 le soglie', () {
    /// 🚨 Zero è **assenza**, non un quarto colore: il muscolo resta spento.
    test('zero non è allenato', () {
      expect(GradinoDelMuscolo.da(0), GradinoDelMuscolo.nessuno);
      expect(GradinoDelMuscolo.nessuno.colore, isNull);
    });

    /// ⚠️ Anche un'intensità piccolissima è **qualcosa**: chi ha fatto una
    /// serie di bicipiti deve vederli accesi, non spenti come se non li avesse
    /// toccati.
    test('e un filo di lavoro è già «poco»', () {
      expect(GradinoDelMuscolo.da(0.01), GradinoDelMuscolo.poco);
      expect(GradinoDelMuscolo.da(1 / 3), GradinoDelMuscolo.poco);
    });

    test('il secondo terzo è «abbastanza»', () {
      expect(GradinoDelMuscolo.da(0.34), GradinoDelMuscolo.abbastanza);
      expect(GradinoDelMuscolo.da(2 / 3), GradinoDelMuscolo.abbastanza);
    });

    /// 💡 `intensitaDeiMuscoli` normalizza a 1 il gruppo più allenato del
    /// periodo: il rosso quindi c'è **sempre**, ed è il tuo massimo.
    test('e l\'ultimo è «tanto»', () {
      expect(GradinoDelMuscolo.da(0.67), GradinoDelMuscolo.tanto);
      expect(GradinoDelMuscolo.da(1), GradinoDelMuscolo.tanto);
    });
  });

  group('🎨 i colori', () {
    /// ⛔ Tre colori diversi, o due gradini sarebbero indistinguibili — che è
    /// il difetto da cui si scappa.
    test('i tre accesi sono diversi fra loro', () {
      final colori = [
        for (final g in GradinoDelMuscolo.values)
          if (g.colore != null) g.colore!,
      ];

      expect(colori.length, 3);
      expect(colori.toSet().length, 3);
    });

    /// ⚠️ Verde, giallo, rosso — nell'ordine chiesto. Si controlla la
    /// **componente**, non il valore esatto: il tono si può ritoccare, l'ordine
    /// no.
    test('e vanno dal verde al rosso', () {
      final poco = GradinoDelMuscolo.poco.colore!;
      final tanto = GradinoDelMuscolo.tanto.colore!;

      expect(poco.g, greaterThan(poco.r), reason: 'il «poco» è verde');
      expect(tanto.r, greaterThan(tanto.g), reason: 'il «tanto» è rosso');
    });
  });

  /// 🚨 **Senza legenda quattro colori restano da indovinare.** Una scala
  /// continua si capisce da sola — più scuro, più allenato; verde e giallo non
  /// hanno un ordine ovvio finché qualcuno non lo dice.
  testWidgets('🏷️ e la legenda li nomina, tranne l\'assenza', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: LegendaDeiMuscoli())),
    );

    expect(find.text('Poco'), findsOneWidget);
    expect(find.text('Abbastanza'), findsOneWidget);
    expect(find.text('Tanto'), findsOneWidget);

    expect(
      find.text('Non allenato'),
      findsNothing,
      reason: 'spiegare che il grigio significa grigio non serve a nessuno',
    );
  });
}
