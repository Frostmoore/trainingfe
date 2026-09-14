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
    /*
     * ══ 🆕 L'ACCENTO ARRIVA ANCHE AI CONTENITORI — 14/09/2026 ════════════════
     *
     * ⛔ **`tertiary: branding.accent` sostituisce UNA tinta, non la famiglia.**
     * `ColorScheme.fromSeed` genera `tertiaryContainer` e
     * `onTertiaryContainer` dalla **tavolozza del seme**, e i parametri
     * espliciti rimpiazzano solo lo slot che nominano.
     *
     * 🚨 Il risultato si vedeva su `/diario/importa-piano`: l'accento neutro è
     * ambra (`#F59E0B`), e il riquadro del suggerimento era **rosa**. Nessuno
     * aveva scelto quel rosa: è la terziaria che Material genera da sola
     * partendo dal verde acqua del primario. ⚠️ Nessun errore, nessun avviso,
     * un colore che nell'app non esiste — e che per una palestra sarebbe stato
     * diverso dal colore scritto nel suo pannello.
     *
     * 💡 Si semina una **seconda** tavolozza dall'accento e se ne prendono i
     * tre slot che servono: così «accento» vuol dire accento anche dentro un
     * contenitore, che è quello che il pannello promette.
     */
    final dallAccento = ColorScheme.fromSeed(
      seedColor: branding.accent,
      brightness: brightness,
    );

    final scheme = ColorScheme.fromSeed(
      seedColor: branding.primary,
      brightness: brightness,
      // L'accento della palestra entra come `tertiary`: è decorativo. Non tocca
      // `error`, perché il rosso di un avviso non deve dipendere dal gusto di
      // chi ha compilato il pannello — un avviso che non sembra un avviso non
      // è un avviso.
      tertiary: branding.accent,
      onTertiary: dallAccento.onPrimary,
      tertiaryContainer: dallAccento.primaryContainer,
      onTertiaryContainer: dallAccento.onPrimaryContainer,
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

      /*
       * ══ 🆕 UNA LIEVE OMBREGGIATURA, PER TUTTA L'APP — 3b-O, 21/08/2026 ═════
       *
       * 📌 Il committente: *«rendiamo l'estetica della card più moderna, con un
       * po' più di contrasto e una lieve ombreggiatura […] non lo ripeterò più,
       * tutta l'interfaccia deve essere modernizzata»*.
       *
       * 🚨 **Si cambia QUI e non scheda per scheda**, ed è tutto il punto: le
       * schede sono nove solo su «Oggi», e altrettante altrove. Toccarle una a
       * una vorrebbe dire venti posti da tenere allineati, e il primo che
       * qualcuno dimentica diventa la scheda che sembra di un'altra app.
       *
       * ⚠️ **`surfaceTintColor` a trasparente insieme all'elevazione.** In
       * Material 3 l'elevazione **tinge la superficie** con il colore primario,
       * e sommandosi al colore della palestra darebbe una tonalità diversa per
       * ogni cliente. 💡 Qui l'elevazione deve produrre **un'ombra**, non una
       * sfumatura: sono due cose che M3 confonde di proposito.
       *
       * 💡 `surfaceContainer` invece di `surfaceContainerLow`: un gradino di
       * contrasto in più rispetto allo sfondo, che è la metà «più contrasto»
       * della richiesta.
       */
      cardTheme: CardThemeData(
        elevation: 2,
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: scheme.shadow.withValues(alpha: 0.28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: EdgeInsets.zero,
      ),

      /*
       * ══ 🆕 LE FINESTRE PRENDONO I COLORI DELL'APP — 14/09/2026 ════════════
       *
       * 📌 Dal giro sull'emulatore: *«Quattro colori d'accento in un minuto»*.
       * Le due finestre del primo avvio, e il calendario che sceglie la
       * settimana, erano **lavanda**: un colore che nell'app non esiste.
       *
       * 🚨 **È lo stesso difetto già chiuso per le `Card`, un piano più su.**
       * In Material 3 l'elevazione non fa un'ombra: **tinge la superficie** con
       * il primario. Una finestra sta a 6 di elevazione, quindi prende una
       * bella dose di tinta — e siccome il primario cambia con la palestra, il
       * colore delle finestre cambierebbe da cliente a cliente senza che
       * nessuno l'abbia scelto.
       *
       * ⛔ Il commento di `cardTheme` diceva già *«si cambia QUI e non scheda
       * per scheda»*: valeva anche per le finestre, e le finestre erano state
       * dimenticate.
       *
       * 💡 Superficie dichiarata e tinta spenta: `AlertDialog`, i fogli, il
       * calendario e l'orologio escono tutti dello stesso colore del resto.
       */
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        // ⚠️ L'intestazione ha una superficie sua: senza questa riga resta
        // lavanda mentre il resto della finestra è già a posto.
        headerBackgroundColor: scheme.surface,
        headerForegroundColor: scheme.onSurface,
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surface,
        // 💡 `TimePickerThemeData` non ha `surfaceTintColor`: la sfumatura
        // gliela toglie lo sfondo dichiarato qui sopra.
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
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

/// 🥇 L'oro degli allenamenti intensi — 3b-B.20.6.
///
/// ⚠️ **Scritto a mano, e non c'era alternativa.** `ColorScheme` non ha uno slot
/// per l'oro, e riusarne uno vicino — `tertiary` — vorrebbe dire dare due
/// significati allo stesso colore: `tertiary` in questa app dice già «calorie
/// bruciate».
///
/// 💡 Non è giallo pieno ma un ambra scuro: un giallo acceso sopra una foto in
/// una griglia fitta grida, e questo deve **premiare**, non allarmare.
///
/// 🚨 Sta **nel tema** e non nello schermo dello storico: lo usano il bordo
/// della card e la riga «Allenamento intenso» dentro l'allenamento, e un colore
/// scritto due volte è un colore che prima o poi è due colori.
const oroDellIntenso = Color(0xFFC9A227);

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
