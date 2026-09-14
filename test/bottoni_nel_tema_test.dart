import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/theme/app_theme.dart';
import 'package:training_companion/src/features/onboarding/data/gym_branding.dart';

/// I pulsanti del tema, dentro una riga.
///
/// 🚨 **Il test che avrebbe evitato due schermate bianche.**
///
/// Il tema imponeva a ogni pulsante `minimumSize: Size.fromHeight(48)`, che vale
/// `Size(double.infinity, 48)`: una **larghezza minima infinita**. Dentro una
/// `Column` o una lista non si nota — riempie e basta, che era l'intenzione — ma
/// dentro una `Row` con un figlio flessibile `RenderFlex` misura prima i figli
/// non flessibili con larghezza **illimitata**: il pulsante chiede infinito e il
/// layout lancia.
///
/// E un'eccezione durante il layout non lascia un pulsante storto: fa **sparire
/// l'intera schermata**. Il riepilogo di fine allenamento era completamente
/// bianco, e la riga «Riprendi» portava giù con sé la scheda Allenamento.
void main() {
  Widget conTema(Widget figlio) => MaterialApp(
    theme: AppTheme.light(GymBranding.neutral),
    home: Scaffold(body: figlio),
  );

  /// La disposizione che rompeva: un campo che si allarga e un pulsante
  /// accanto. È quella del riepilogo (calorie + «Salva») e della riga
  /// dell'allenamento in corso (testo + «Riprendi»).
  testWidgets(
    'un FilledButton accanto a un Expanded non fa esplodere il layout',
    (tester) async {
      await tester.pumpWidget(
        conTema(
          Row(
            children: [
              const Expanded(child: TextField()),
              FilledButton(onPressed: () {}, child: const Text('Salva')),
            ],
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Salva'), findsOneWidget);
    },
  );

  testWidgets('e nemmeno un OutlinedButton', (tester) async {
    await tester.pumpWidget(
      conTema(
        Row(
          children: [
            const Expanded(child: Text('Allenamento in corso')),
            OutlinedButton(onPressed: () {}, child: const Text('Riprendi')),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  /// ⚠️ Il vincolo che conta resta: 48 px è la soglia sotto la quale un
  /// bersaglio diventa difficile da centrare col pollice.
  testWidgets('il bersaglio resta alto almeno 48', (tester) async {
    await tester.pumpWidget(
      conTema(
        Align(
          alignment: Alignment.topLeft,
          child: FilledButton(onPressed: () {}, child: const Text('X')),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      greaterThanOrEqualTo(48),
    );
  });

  /// Chi vuole tutta la larghezza la chiede: continua a funzionare.
  testWidgets('a tutta larghezza si ottiene ancora, dicendolo', (tester) async {
    await tester.pumpWidget(
      conTema(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Concludi')),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    final larghezza = tester.getSize(find.byType(FilledButton)).width;

    expect(larghezza, tester.getSize(find.byType(Scaffold)).width);
  });

  // ─────────────────── i colori che nessuno ha scelto ───────────────────

  /// ⛔ **`tertiary: accento` non basta**, ed è costato un riquadro rosa.
  ///
  /// `ColorScheme.fromSeed` ricava `tertiaryContainer` dalla tavolozza del
  /// **seme**, non dal parametro `tertiary`: con un primario verde acqua e un
  /// accento ambra, il contenitore usciva rosa. 🚨 Nessun errore, e un colore
  /// che nell'app non esiste — per una palestra, un colore diverso da quello
  /// scritto nel suo pannello.
  ///
  /// 💡 Si misura la **distanza di tinta** dall'accento, non il valore esatto:
  /// Material schiarisce e desatura per farne un contenitore, ed è giusto che
  /// lo faccia. Quello che non deve fare è cambiare famiglia.
  test('il contenitore terziario resta della famiglia dell accento', () {
    const accento = Color(0xFFF59E0B); // l'ambra del branding neutro

    final tema = AppTheme.light(GymBranding.neutral);
    final contenitore = tema.colorScheme.tertiaryContainer;

    double tinta(Color c) => HSLColor.fromColor(c).hue;

    // ⚠️ In gradi, e sul cerchio: 350° e 10° distano 20, non 340.
    final diff = (tinta(contenitore) - tinta(accento)).abs();
    final distanza = diff > 180 ? 360 - diff : diff;

    expect(
      distanza,
      lessThan(40),
      reason:
          'tertiaryContainer è ${tinta(contenitore).round()}°, '
          'l\'accento ${tinta(accento).round()}°: non è più un ambra.',
    );
  });

  /// 🚨 **Le finestre non si tingono da sole.** In Material 3 l'elevazione
  /// **tinge la superficie** con il primario: un `AlertDialog` sta a 6, quindi
  /// ne prendeva parecchia, e il colore cambiava da palestra a palestra senza
  /// che nessuno l'avesse deciso. ⛔ È lo stesso difetto già chiuso per le
  /// `Card`, che era stato chiuso **solo** per le card.
  test('le finestre non prendono la sfumatura del primario', () {
    final tema = AppTheme.light(GymBranding.neutral);

    expect(tema.dialogTheme.surfaceTintColor, Colors.transparent);
    expect(tema.datePickerTheme.surfaceTintColor, Colors.transparent);
    expect(tema.bottomSheetTheme.surfaceTintColor, Colors.transparent);

    // 💡 E la superficie è quella dell'app, non quella che M3 sceglierebbe.
    expect(tema.dialogTheme.backgroundColor, tema.colorScheme.surface);
  });
}
