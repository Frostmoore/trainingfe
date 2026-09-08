import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/gate_dell_abbonamento.dart';
import '../modale_acquisti.dart';

/// 🔒 Una card che chi non è abbonato **vede sfumata** — 08/09/2026.
///
/// ══ 📌 LA RICHIESTA, E IL CAMBIO DI REGOLA ════════════════════════════════
///
/// Il committente: *«Le cards devono rimanere visibili ma offuscate (per far
/// capire che manca qualcosa)»*.
///
/// ⚠️ **Ribalta la regola del 26/08**, che diceva *«verbi, non viste: chiudere
/// un grafico che c'era ieri si legge come un furto»*. 🚨 È una decisione presa
/// sapendolo — *«è vero questa era la mia regola, ma ho cambiato idea»* — e sta
/// scritta qui perché chi legge questo file non concluda che la regola vecchia
/// sia stata dimenticata.
///
/// ⛔ **La conseguenza va guardata in faccia**: chi usava queste card se le
/// ritrova sfumate. La sfumatura e il banner devono spiegare **cosa** manca e
/// **come** si riprende, o quello che arriva non è un abbonamento, è una
/// segnalazione.
///
/// ── 🚨 Perché `ImageFiltered` e non `Opacity` ─────────────────────────────
///
/// 💡 È la stessa scelta già fatta in `ProgressoDellEsercizio`: un testo
/// trasparente **resta leggibile** — si seleziona, lo legge lo screen reader,
/// si legge inclinando lo schermo. Non sarebbe un limite, sarebbe un limite
/// finto. ⛔ E un limite finto è peggio di nessun limite: chi lo scopre non
/// pensa «ho trovato un trucco», pensa «mi stavano prendendo in giro».
///
/// ⚠️ `ExcludeSemantics` per la stessa ragione, e `AbsorbPointer` perché sotto
/// ci sono card che si aprono: un tocco deve portare al listino, non dentro una
/// schermata che poi si vedrebbe per intero.
class SottoAbbonamento extends ConsumerWidget {
  const SottoAbbonamento({required this.child, this.motivo, super.key});

  final Widget child;

  /// Cosa si sblocca, in due parole: «il tuo recupero», «i tuoi allenamenti».
  ///
  /// 💡 Serve a non ripetere la stessa frase su cinque card di fila: il banner
  /// in cima dice il **perché**, il lucchetto dice il **cosa**.
  final String? motivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(abbonatoProvider)) return child;

    final tema = Theme.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: AbsorbPointer(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(
                sigmaX: 5,
                sigmaY: 5,
                // 🚨 `decal` e non il valore di serie: senza, il bordo della
                // card si scioglie e la sfumatura sembra un difetto di disegno
                // invece di una cosa voluta.
                tileMode: TileMode.decal,
              ),
              child: child,
            ),
          ),
        ),

        /*
         * 🔒 **Il lucchetto è un pulsante, non una decorazione.**
         *
         * ⛔ Una card sfumata senza niente da toccare lascia una sola strada:
         * cercare da qualche altra parte cosa è successo. 💡 Qui il tocco porta
         * dove si risolve.
         */
        Semantics(
          button: true,
          label: motivo == null
              ? 'Bloccato: serve l\'abbonamento'
              : 'Bloccato: $motivo si sblocca con l\'abbonamento',
          child: Material(
            color: tema.colorScheme.surface.withValues(alpha: 0.92),
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => ModaleAcquisti.mostra(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 18,
                      color: tema.colorScheme.primary,
                    ),
                    const SizedBox(width: Gap.sm),
                    Flexible(
                      child: Text(
                        motivo ?? 'Con l\'abbonamento',
                        style: tema.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tema.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 💳 Il banner che spiega perché cinque card sono sfumate — 08/09/2026.
///
/// 📌 *«in alto, sotto alla card delle calorie iniziale, ci va un banner che
/// propone di abbonarsi per sbloccare le analisi avanzate dei propri dati»*.
///
/// ══ 🚨 STA SOTTO LE CALORIE, E IL POSTO È IL MESSAGGIO ════════════════════
///
/// 💡 La card delle calorie è l'unica cosa **completa** che un non abbonato
/// vede: sopra di lei il banner sembrerebbe un annuncio prima del prodotto,
/// sotto di lei arriva **dopo** che l'app ha già dato qualcosa. ⚠️ Ed è anche
/// dove comincia la fila delle card sfumate: la spiegazione precede di un dito
/// la cosa che spiega.
///
/// ⛔ **Sparisce per gli abbonati**, e non «si spegne»: chi ha pagato non deve
/// vedere nemmeno lo spazio dove stava.
class BannerAbbonamento extends ConsumerWidget {
  const BannerAbbonamento({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(abbonatoProvider)) return const SizedBox.shrink();

    final tema = Theme.of(context);

    return Card(
      // 💡 `primaryContainer`: si distingue dalle card dei dati senza gridare.
      // ⛔ Un colore d'errore direbbe che qualcosa si è rotto.
      color: tema.colorScheme.primaryContainer,
      child: InkWell(
        borderRadius: BorderRadius.circular(Gap.radius),
        onTap: () => ModaleAcquisti.mostra(context),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: tema.colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sblocca le analisi dei tuoi dati',
                      style: tema.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tema.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 2),

                    /*
                     * ⚠️ **Elenca le cinque card per nome**, e non dice «e
                     * altro». 🚨 Un banner che promette genericamente «più
                     * funzioni» costringe a scorrere per capire cosa manca —
                     * cioè fa fare alla persona il lavoro di chi vende.
                     */
                    Text(
                      'Spunto di oggi, carico e carica, recupero, com\'è fatto '
                      'e i tuoi allenamenti. I dati restano tuoi: '
                      'l\'abbonamento apre le letture, non i numeri.',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: tema.colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
