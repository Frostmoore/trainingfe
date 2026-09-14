import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../target_locale_controller.dart';
import 'weight_sheet.dart';

/// Cosa manca per avere un obiettivo calorico, **detto per nome**.
///
/// ── 🚨 Il difetto che questo widget chiude ────────────────────────────────
///
/// Prima, ovunque mancasse il target, si leggeva *«Nessun obiettivo impostato.
/// Compila i tuoi dati»* — e il pulsante portava al profilo.
///
/// ⚠️ Ma il **peso non sta nel profilo**: dopo S5 vive nell'archivio locale del
/// telefono e si registra da un'altra schermata. Chi aveva il profilo completo e
/// nessuna pesata veniva quindi mandato a **rifare una cosa già fatta**, per
/// una che non gli era mai stata offerta. È esattamente come è stato riferito
/// provando l'app: *«Non mi calcola più i valori che inserisco di peso, altezza
/// eccetera»*.
///
/// 💡 Adesso si dice **quale** pezzo manca e si porta **dove serve** — al
/// foglio della pesata se manca solo quella, al profilo altrimenti.
class MancaPerIlTarget extends ConsumerWidget {
  const MancaPerIlTarget({
    required this.esito,
    this.compatto = false,
    super.key,
  });

  final EsitoTarget esito;

  /// Nel diario lo spazio è meno: si mostra la frase e un pulsante solo.
  final bool compatto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    /*
     * ══ 🆕 UN SOLO PULSANTE PIENO, E È QUELLO CHE SBLOCCA — 14/09/2026 ═══════
     *
     * 📌 Trovato girando l'app sull'emulatore: *«il tasto più evidente è quello
     * meno utile»*.
     *
     * ⛔ **Prima erano pieni tutti e due i pulsanti che potevano comparire**
     * (peso e attività) e grigio l'unico che porta al modulo con più campi
     * mancanti. Con tre cose da fare, tre pesi visivi uguali non dicono da dove
     * si comincia: chi guarda tocca quello più in vista, e quello non era
     * necessariamente il passo giusto.
     *
     * 💡 **La regola adesso è una sola**: si riempie il *primo* pezzo che manca
     * nell'ordine in cui conviene farli — i dati del profilo, poi il livello di
     * attività, poi la pesata — e tutti gli altri sono link. Quando manca solo
     * il peso, il peso **è** il primo, quindi il caso comune resta com'era.
     */
    final mancaProfilo = esito.mancano.any(
      (p) => p.staNelProfilo && p != PezzoMancante.attivita,
    );
    final mancaAttivita = esito.mancano.contains(PezzoMancante.attivita);
    final mancaPeso = esito.mancano.contains(PezzoMancante.peso);

    // 🚨 Uno solo dei tre è vero: il primo che manca, nell'ordine dei passi.
    final pienoProfilo = mancaProfilo;
    final pienoAttivita = !mancaProfilo && mancaAttivita;
    final pienoPeso = !mancaProfilo && !mancaAttivita;

    /// Pieno se è il passo da fare adesso, link altrimenti.
    Widget azione({
      required bool pieno,
      required IconData icona,
      required String testo,
      required VoidCallback vai,
    }) {
      return pieno
          ? FilledButton.icon(
              onPressed: vai,
              icon: Icon(icona, size: 18),
              label: Text(testo),
            )
          : TextButton.icon(
              onPressed: vai,
              icon: Icon(icona, size: 18),
              label: Text(testo),
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(esito.spiegazione, style: theme.textTheme.bodySmall),

        if (!compatto)
          Text(
            'Senza, il fabbisogno non si può calcolare — e un numero inventato '
            'diventerebbe la tua dieta.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),

        const SizedBox(height: Gap.xs),

        /*
         * ⚠️ **L'ordine dei pulsanti è l'ordine dei passi**, non quello in cui
         * è cresciuto il codice: il pieno deve stare per primo, o «prima questo»
         * lo dice il colore e «prima quello» lo dice la posizione.
         */
        Wrap(
          spacing: Gap.sm,
          children: [
            if (mancaProfilo)
              azione(
                pieno: pienoProfilo,
                icona: Icons.badge_outlined,
                testo: 'Compila i tuoi dati',
                vai: () => context.push(AppRoutes.profileEdit),
              ),

            /*
             * ⚖️ **Il livello di attività ha la SUA pagina** — 3b-G.1.
             *
             * 🚨 Mandarlo genericamente «al profilo» sarebbe ripetere esattamente
             * il difetto per cui questo widget è nato: la persona arriva su una
             * schermata piena di campi già compilati e deve indovinare quale sia
             * quello che manca. ⚠️ Qui la cosa da fare è una sola, e si porta
             * dritti lì.
             *
             * 🆕 ⛔ **Il testo però diceva «Come contare le calorie»**, cioè
             * prometteva una spiegazione e apriva un modulo. La pagina spiega
             * *anche*, ma quello che chiede è una scelta: adesso lo dice.
             */
            if (mancaAttivita)
              azione(
                pieno: pienoAttivita,
                icona: Icons.directions_run_rounded,
                testo: 'Scegli il livello di attività',
                vai: () => context.push(AppRoutes.modelloCalorie),
              ),

            /*
             * 💡 Il peso in fondo: è il passo che si rifà più spesso — il
             * profilo si compila una volta all'iscrizione, la pesata no — ma
             * quando è l'unico che manca è anche l'unico pulsante, quindi non
             * perde niente a stare per ultimo.
             */
            if (mancaPeso)
              azione(
                pieno: pienoPeso,
                icona: Icons.monitor_weight_outlined,
                testo: 'Registra il peso',
                vai: () => WeightSheet.mostra(context),
              ),
          ],
        ),
      ],
    );
  }
}
