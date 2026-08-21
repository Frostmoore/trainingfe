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

        Wrap(
          spacing: Gap.sm,
          children: [
            /*
             * 🚨 Il peso **prima** e con il pulsante pieno quando è l'unica cosa
             * che manca: è il caso di gran lunga più comune — il profilo si
             * compila una volta all'iscrizione, la pesata no — ed è quello in cui
             * mandare al profilo sarebbe un giro a vuoto.
             */
            if (esito.mancano.contains(PezzoMancante.peso))
              esito.soloIlPeso
                  ? FilledButton.icon(
                      onPressed: () => WeightSheet.mostra(context),
                      icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                      label: const Text('Registra il peso'),
                    )
                  : TextButton.icon(
                      onPressed: () => WeightSheet.mostra(context),
                      icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                      label: const Text('Registra il peso'),
                    ),

            if (esito.mancano.any((p) => p.staNelProfilo))
              TextButton(
                onPressed: () => context.push(AppRoutes.profileEdit),
                child: const Text('Compila i tuoi dati'),
              ),
          ],
        ),
      ],
    );
  }
}
