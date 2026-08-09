import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/diary_models.dart';

/// Il riepilogo in cima al diario — A4.1.
///
/// 🚨 **Rosso quando si sfora, e la barra non si ferma a fine corsa.**
/// Una barra che si riempie e si blocca al 100% dice «sei arrivato», non «hai
/// superato»: sono due cose diverse e l'utente deve poter distinguere 2.000 su
/// 2.000 da 2.600 su 2.000 con un'occhiata, senza leggere i numeri.
class MacroSummary extends StatelessWidget {
  const MacroSummary({required this.day, super.key});

  final DiaryDay day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sforato = day.hasTarget && day.kcal > day.targetKcal!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  day.kcal.round().toString(),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: sforato ? theme.colorScheme.error : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: Gap.xs),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    day.hasTarget ? '/ ${day.targetKcal!.round()} kcal' : 'kcal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                if (day.burnedKcal > 0)
                  // Le bruciate si mostrano perché il target del giorno le
                  // comprende già: senza, l'utente vedrebbe un target più alto
                  // del solito e non capirebbe perché.
                  Chip(
                    avatar: const Icon(Icons.local_fire_department_rounded, size: 16),
                    label: Text('${day.burnedKcal}'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),

            if (day.hasTarget) ...[
              const SizedBox(height: Gap.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  // `clamp` a 1 solo per il disegno: il colore dice il resto.
                  value: day.progresso.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: sforato ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: Gap.xs),
              Text(
                sforato
                    ? 'Hai superato di ${(-day.residuoKcal).round()} kcal'
                    : 'Ti restano ${day.residuoKcal.round()} kcal',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: sforato ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              const SizedBox(height: Gap.sm),
              Text(
                // 🚨 Si dice **perché** manca il target invece di mostrarne uno
                // inventato: un numero inventato diventerebbe la dieta di
                // qualcuno.
                'Nessun obiettivo impostato. Chiedi al tuo trainer un piano, '
                'oppure completa il profilo con altezza, età e peso.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: Gap.md),
            Row(
              children: [
                _Macro(nome: 'Proteine', valore: day.protein, target: day.targetProtein),
                _Macro(nome: 'Carboidrati', valore: day.carbs, target: day.targetCarbs),
                _Macro(nome: 'Grassi', valore: day.fat, target: day.targetFat),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.nome, required this.valore, this.target});

  final String nome;
  final double valore;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            target != null
                ? '${valore.round()} / ${target!.round()} g'
                : '${valore.round()} g',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            nome,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
