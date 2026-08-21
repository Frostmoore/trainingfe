import 'package:flutter/material.dart';

import '../../features/onboarding/data/gym_branding.dart';

/// Il tema costruito **a runtime** dal branding della palestra — ADR-A01, A3.1.
///
/// 🚨 **È il cuore del white-label.** Un'app per palestra significherebbe una
/// pubblicazione e una review per cliente: qui il colore arriva da una
/// richiesta HTTP e il `ThemeData` si costruisce al volo.
///
/// `ColorScheme.fromSeed` e non una tavolozza scritta a mano: da un colore solo
/// Material 3 deriva un insieme **coerente e con contrasti leggibili**. Una
/// tavolozza compilata a mano da un colore scelto da un cliente produce, prima
/// o poi, testo grigio chiaro su sfondo grigio chiaro — e non lo scopre nessuno
/// finché non lo segnala un utente.
class AppTheme {
  const AppTheme._();

  static ThemeData light(GymBranding branding) =>
      _build(branding, Brightness.light);

  static ThemeData dark(GymBranding branding) =>
      _build(branding, Brightness.dark);

  static ThemeData _build(GymBranding branding, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: branding.primary,
      brightness: brightness,
      // L'accento della palestra entra come `tertiary`: è decorativo. Non tocca
      // `error`, perché il rosso di un avviso non deve dipendere dal gusto di
      // chi ha compilato il pannello — un avviso che non sembra un avviso non
      // è un avviso.
      tertiary: branding.accent,
    );

    final base = ThemeData(colorScheme: scheme, useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),

      /*
       * 🚨 **`Size(64, 48)` e NON `Size.fromHeight(48)`.**
       *
       * `Size.fromHeight(48)` vale `Size(double.infinity, 48)`: impone a ogni
       * pulsante dell'app una larghezza **minima infinita**. Dentro una `Column`
       * o una lista non si nota — riempie e basta, che era l'intenzione — ma
       * dentro una `Row` che contiene anche un figlio flessibile è un disastro:
       * `RenderFlex` misura i figli NON flessibili con larghezza **illimitata**
       * prima di distribuire lo spazio, il pulsante chiede infinito, e il layout
       * lancia. Da lì parte la solita cascata di «RenderBox was not laid out» e
       * **non si disegna più niente** — non il pulsante: l'intera schermata.
       *
       * È costato due schermate bianche: la riga «Riprendi» e il riepilogo di
       * fine allenamento, dove il campo delle calorie sta accanto a «Salva».
       *
       * 48 px resta il vincolo che conta — è la soglia sotto la quale un
       * bersaglio diventa difficile da centrare col pollice, ed è la linea guida
       * di accessibilità di entrambe le piattaforme. 64 px di larghezza minima è
       * il default di Material.
       *
       * ⚠️ Chi vuole un pulsante a tutta larghezza lo dice dove serve, con
       * `style: FilledButton.styleFrom(minimumSize: Size.fromHeight(52))` o
       * mettendolo in una `Column(crossAxisAlignment: stretch)`. Un default che
       * può far sparire una schermata non è un default.
       */
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        elevation: 3,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
    );
  }
}

/// Spaziature e raggi, con un nome invece di un numero — A3.1.
///
/// Non è pedanteria: `padding: EdgeInsets.all(16)` sparso in cinquanta widget
/// significa che cambiare la densità dell'interfaccia è una ricerca e
/// sostituzione su cinquanta file, con il rischio di prendere anche i 16 che
/// erano un'altra cosa.
/// «Questo pulsante occupa tutta la larghezza».
///
/// 🚨 Da chiedere **dove serve**, non da imporre nel tema: `Size.fromHeight`
/// vale `Size(double.infinity, …)`, e un pulsante che pretende larghezza
/// infinita dentro una `Row` con un figlio flessibile fa lanciare il layout —
/// e con esso sparire l'intera schermata. Vedi la nota in `AppTheme._build()`.
///
/// Si usa solo dove il pulsante è figlio diretto di una `Column` o di una lista,
/// cioè dove la larghezza è comunque limitata.
ButtonStyle bottonePieno({double altezza = 48}) =>
    FilledButton.styleFrom(minimumSize: Size.fromHeight(altezza));

class Gap {
  const Gap._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;

  static const radius = 16.0;
  static const radiusSm = 12.0;
}
