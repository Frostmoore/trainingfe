import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../training_controller.dart';

/// Le schede assegnate — A5.1.
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schede = ref.watch(plansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Allenamento')),
      body: schede.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(plansProvider)),
        data: (elenco) => elenco.isEmpty
            // 🚨 Il vuoto dice **di chi è la palla**: l'iscritto non può darsi
            // una scheda da solo, e un «nessuna scheda» senza spiegazione lo
            // lascerebbe a chiedersi se l'app è rotta.
            ? const EmptyState(
                icon: Icons.assignment_outlined,
                title: 'Nessuna scheda',
                message: 'Il tuo trainer non te ne ha ancora assegnata una. '
                    'Appena lo fa, la trovi qui.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(plansProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(Gap.md),
                  itemCount: elenco.length,
                  separatorBuilder: (context, index) => const SizedBox(height: Gap.md),
                  itemBuilder: (context, index) => _SchedaCard(scheda: elenco[index]),
                ),
              ),
      ),
    );
  }
}

class _SchedaCard extends StatelessWidget {
  const _SchedaCard({required this.scheda});

  final WorkoutPlan scheda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Gap.radius),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => _DettaglioScheda(id: scheda.id, nome: scheda.name)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.fitness_center_rounded, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheda.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${scheda.exercisesCount} esercizi',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _DettaglioScheda extends ConsumerWidget {
  const _DettaglioScheda({required this.id, required this.nome});

  final int id;
  final String nome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheda = ref.watch(planDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: Text(nome)),
      body: scheda.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(planDetailProvider(id))),
        data: (p) => ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            if (p.notes != null && p.notes!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Text(p.notes!),
                ),
              ),
              const SizedBox(height: Gap.md),
            ],
            for (final e in p.exercises)
              Card(
                margin: const EdgeInsets.only(bottom: Gap.sm),
                child: ListTile(
                  title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text([
                    e.prescription,
                    if (e.restSec != null) 'rec. ${e.restSec}s',
                    if (e.targetWeight != null) '${e.targetWeight} kg',
                  ].where((s) => s.isNotEmpty).join(' · '),),
                  isThreeLine: e.notes != null && e.notes!.isNotEmpty,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
