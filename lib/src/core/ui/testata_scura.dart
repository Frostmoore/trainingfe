import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/branding_controller.dart';
import '../../features/onboarding/data/gym_branding.dart';
import '../theme/app_theme.dart';
import 'intestazione_app.dart';

/// 🌑 **La testata scura a strumenti** — `plan_interfaccia.md` §3.1, I1,
/// 19/11/2026.
///
/// 📌 Decisa sulle tavole del 19/11: *«Mi piace la 5 ma con l'header della
/// 4»*. In cima alle schermate che hanno strumenti — Oggi, Diario,
/// Allenamento, Forma, Sonno, la seduta — c'è un blocco scuro arrotondato in
/// basso, e dentro gli strumenti di quella pagina.
///
/// ══ 🔑 PERCHÉ UN `Theme` SCURO, E NON COLORI SCRITTI A MANO ════════════════
///
/// Gli strumenti che esistono già (`BarraCarico`, `BatteriaCarica`,
/// `OndaMetrica`…) prendono i colori da `Theme.of(context).colorScheme`. 💡 Messi
/// sotto [temaPer] si ridisegnano **da soli** in versione scura, e l'accento
/// della palestra diventa il tono chiaro che `ColorScheme.fromSeed` calcola per
/// il buio — cioè leggibile su questo fondo, senza che nessuno scelga a mano.
///
/// ⛔ La strada a mano voleva dire due tavolozze da tenere allineate per sempre,
/// e la prima palestra con un colore strano le avrebbe fatte divergere.
///
/// ⚠️ `TachimetroProntezza` ha colori **fissi** (rosso, giallo, verde, decisi
/// il 28/08): non dipendono dal tema e restano quelli. È giusto così — lì il
/// colore **è** l'informazione.
///
/// ══ 🚨 PERCHÉ CONTIENE UN `IntestazioneApp` VERO ═══════════════════════════
///
/// La riga col logo, il nome, i gettoni e il profilo va **su tutte le pagine**
/// (regola del 21/08), e la difende `test/intestazione_ovunque_test.dart`.
/// Copiarla qui vorrebbe dire due righe d'identità che divergono; contenerla
/// vuol dire che il guardiano la riconosce anche dentro la testata.
///
/// ══ ⚠️ NON È UN `PreferredSizeWidget` ═════════════════════════════════════
///
/// È alta quanto i suoi strumenti, e lo sa solo dopo averli disegnati. Quindi
/// sta **nel corpo**, come primo figlio della lista, e scorre via con la pagina
/// — come faceva già l'intestazione di «Oggi».
class TestataScura extends ConsumerWidget {
  const TestataScura({
    this.titolo,
    this.sottotitolo,
    this.azioni = const <Widget>[],
    this.indietro = true,
    this.navigatore,
    this.avvertenza,
    this.strumenti,
    super.key,
  });

  /// `null` su «Oggi»: lì la pagina la nomina già la riga d'identità.
  final String? titolo;

  final String? sottotitolo;

  final List<Widget> azioni;

  final bool indietro;

  /// La data con le frecce, il navigatore della settimana, le linguette.
  final Widget? navigatore;

  /// 🚨 **Sempre prima degli strumenti** — decisione D-2s/B: un'avvertenza
  /// letta dopo i numeri arriva troppo tardi. Per questo ha un posto suo, e
  /// non è un figlio qualunque di [strumenti].
  final Widget? avvertenza;

  final Widget? strumenti;

  /// Il raggio degli angoli in basso, uno solo per tutta l'app.
  static const double raggio = 28;

  /// Il fondo col telefono in chiaro: quasi nero, con una punta di blu.
  static const Color sfondoInChiaro = Color(0xFF10161B);

  /// Lo sfondo della testata, che dipende da com'è il **telefono**.
  ///
  /// ⚠️ Va chiamato con un `context` **fuori** dal tema scuro della testata:
  /// dentro, la luminosità è sempre scura e non direbbe più niente.
  ///
  /// 💡 Col telefono in scuro il corpo è già scuro, e una testata dello
  /// stesso colore sparirebbe: si scende di un gradino, a
  /// `surfaceContainerLowest`, il tono più basso dello schema.
  static Color sfondoPer(BuildContext context) {
    final theme = Theme.of(context);

    if (theme.brightness == Brightness.light) return sfondoInChiaro;

    return theme.colorScheme.surfaceContainerLowest;
  }

  static GymBranding? _ultimaPalestra;
  static ThemeData? _ultimoTema;

  /// Il tema degli strumenti dentro la testata: quello scuro della palestra.
  ///
  /// 💡 **Si ricorda l'ultimo**: `ColorScheme.fromSeed` calcola due tavolozze
  /// tonali, e la testata si ridisegna a ogni cambio di stato della pagina.
  /// La palestra cambia quasi mai, e quando cambia è un oggetto nuovo.
  static ThemeData temaPer(GymBranding palestra) {
    if (identical(palestra, _ultimaPalestra) && _ultimoTema != null) {
      return _ultimoTema!;
    }

    _ultimaPalestra = palestra;
    _ultimoTema = AppTheme.dark(palestra);

    return _ultimoTema!;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palestra = ref.watch(brandingControllerProvider).branding;
    final sfondo = sfondoPer(context);
    final haContenuto =
        navigatore != null || avvertenza != null || strumenti != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: sfondo,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(raggio),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚠️ `arrotondata: false`: gli angoli li fa il blocco intero, non la
          // sua prima riga — altrimenti si vedrebbe una curva a metà testata.
          IntestazioneApp(
            titolo: titolo,
            sottotitolo: sottotitolo,
            azioni: azioni,
            indietro: indietro,
            arrotondata: false,
          ),

          if (haContenuto)
            Theme(
              data: temaPer(palestra),
              /*
               * 🚨 **`Material` trasparente, e non è decorazione.** Il colore
               * dei testi senza stile proprio non viene dal `Theme`: viene dal
               * `DefaultTextStyle`, che lo mette lo `Scaffold` di **fuori** —
               * cioè scuro. Senza questo, ogni `Text` degli strumenti sarebbe
               * nero su quasi-nero. `Material` rimette il `DefaultTextStyle`
               * del tema che ha sopra.
               */
              child: Material(
                type: MaterialType.transparency,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.md,
                    0,
                    Gap.md,
                    Gap.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ?navigatore,
                      if (avvertenza != null) ...[
                        const SizedBox(height: Gap.sm),
                        avvertenza!,
                      ],
                      if (strumenti != null) ...[
                        const SizedBox(height: Gap.md),
                        strumenti!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
