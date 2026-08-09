import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../data/diary_models.dart';
import '../diary_controller.dart';
import 'widgets/add_food_sheet.dart';
import 'widgets/macro_summary.dart';

/// Il diario del giorno — A4.1.
class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giorno = ref.watch(selectedDateProvider);
    final diario = ref.watch(diaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diario'),
        actions: [
          IconButton(
            onPressed: () => _scegliData(context, ref, giorno),
            icon: const Icon(Icons.calendar_today_rounded),
            tooltip: 'Cambia giorno',
          ),
        ],
        bottom: _BarraGiorno(giorno: giorno, ref: ref),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddFoodSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      body: diario.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(diaryProvider)),
        data: (day) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(diaryProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 96),
            children: [
              MacroSummary(day: day),
              const SizedBox(height: Gap.md),
              for (final pasto in day.meals) _Pasto(pasto: pasto),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scegliData(BuildContext context, WidgetRef ref, DateTime attuale) async {
    final scelta = await showDatePicker(
      context: context,
      initialDate: attuale,
      // Il diario non si compila in anticipo: non si sa cosa si mangerà.
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('it'),
    );

    if (scelta != null) {
      ref.read(selectedDateProvider.notifier).state = scelta;
    }
  }
}

/// La riga con «ieri / oggi / domani»: cambiare giorno è il gesto più frequente
/// del diario, e farlo passare da un calendario a ogni volta è troppo attrito.
class _BarraGiorno extends StatelessWidget implements PreferredSizeWidget {
  const _BarraGiorno({required this.giorno, required this.ref});

  final DateTime giorno;
  final WidgetRef ref;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final oggi = DateTime.now();
    final isOggi = DateUtils.isSameDay(giorno, oggi);

    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => ref.read(selectedDateProvider.notifier).state =
                giorno.subtract(const Duration(days: 1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          SizedBox(
            width: 180,
            child: Text(
              isOggi ? 'Oggi' : DateFormat('EEEE d MMMM', 'it').format(giorno),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            // Disabilitato su oggi: in avanti non c'è niente da vedere.
            onPressed: isOggi
                ? null
                : () => ref.read(selectedDateProvider.notifier).state =
                      giorno.add(const Duration(days: 1)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _Pasto extends ConsumerWidget {
  const _Pasto({required this.pasto});

  final DiaryMeal pasto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      pasto.label,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${pasto.kcal.round()} kcal',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            if (pasto.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
                child: Text(
                  'Niente ancora.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final voce in pasto.entries) _Voce(voce: voce),

            TextButton.icon(
              onPressed: () => AddFoodSheet.show(context, meal: pasto.meal),
              icon: const Icon(Icons.add, size: 18),
              label: Text('Aggiungi a ${pasto.label.toLowerCase()}'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Voce extends ConsumerWidget {
  const _Voce({required this.voce});

  final FoodEntry voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(voce.id),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: theme.colorScheme.errorContainer,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: Gap.lg),
            child: Icon(Icons.delete_outline_rounded),
          ),
        ),
      ),
      onDismissed: (_) => ref.read(diaryActionsProvider).delete(voce.id),
      child: ListTile(
        dense: true,
        title: Text(voce.description),
        subtitle: Text(voce.quantita),
        trailing: Text(
          voce.kcal != null ? '${voce.kcal!.round()} kcal' : '—',
          style: theme.textTheme.labelMedium,
        ),
        // L'icona dice da dove viene la voce: serve a capire, guardando lo
        // storico, quali stime sono dell'AI quando un totale non torna.
        leading: Icon(
          switch (voce.source) {
            'ai_text' => Icons.auto_awesome_outlined,
            'ai_photo' => Icons.photo_camera_outlined,
            'favorite' => Icons.star_outline_rounded,
            'plan' => Icons.assignment_outlined,
            _ => Icons.edit_outlined,
          },
          size: 18,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }
}
