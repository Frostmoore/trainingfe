import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../calendar_controller.dart';

/// Il calendario — C13.
///
/// Sette colonne che cominciano da **lunedì**, come il calendario italiano. Le
/// celle arrivano già allineate dal server: se cominciassero dal primo del mese
/// un mese che parte di mercoledì avrebbe tutte le date sotto l'intestazione
/// sbagliata, e non se ne accorgerebbe nessuno finché non si confronta un
/// giorno con la realtà.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  static const _intestazioni = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagina = ref.watch(calendarProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: pagina.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(calendarProvider),
        ),
        data: (p) => Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => ref.read(calendarMonthProvider.notifier).state = p.prev,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    p.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () => ref.read(calendarMonthProvider.notifier).state = p.next,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              child: Row(
                children: [
                  for (final g in _intestazioni)
                    Expanded(
                      child: Text(
                        g,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Gap.xs),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.72,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: p.days.length,
                itemBuilder: (context, i) => _Cella(giorno: p.days[i], target: p.targetKcal),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(Gap.sm),
              child: Text(
                'La barra è la percentuale sul tuo fabbisogno. '
                'Tocca un giorno per il dettaglio.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cella extends StatelessWidget {
  const _Cella({required this.giorno, this.target});

  final CalendarDay giorno;
  final int? target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sfora = target != null && giorno.kcal != null && giorno.kcal! > target!;

    return Opacity(
      // I giorni dell'altro mese ci sono ma sfumati: toglierli spezzerebbe la
      // griglia di sette colonne.
      opacity: giorno.inMonth ? 1 : 0.35,
      child: InkWell(
        borderRadius: BorderRadius.circular(Gap.radiusSm),
        // go_router, non `Navigator.pushNamed`: vedi la nota in
        // `history_screen.dart`.
        onTap: () => context.push(
          AppRoutes.day(DateFormat('yyyy-MM-dd').format(giorno.date)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Gap.radiusSm),
            border: Border.all(
              color: giorno.today ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
              width: giorno.today ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${giorno.day}', style: theme.textTheme.labelMedium),

              if (giorno.kcal != null) ...[
                Text(
                  '${giorno.kcal}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: sfora ? theme.colorScheme.error : theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (target != null)
                  LinearProgressIndicator(
                    value: (giorno.kcal! / target!).clamp(0, 1),
                    minHeight: 3,
                    color: sfora ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
              ],

              const Spacer(),

              if (giorno.workouts > 0)
                Row(
                  children: [
                    Icon(Icons.fitness_center_rounded, size: 10, color: theme.colorScheme.tertiary),
                    if (giorno.workouts > 1)
                      Text('${giorno.workouts}', style: theme.textTheme.labelSmall),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
