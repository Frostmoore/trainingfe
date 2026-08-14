import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../compositore_scheda_controller.dart';
import '../data/scheda_allenamento.dart';

/// L'elenco delle schede che questo trainer ha scritto — G7.2.
///
/// 🚨 **Sono anonime** (D4): non c'è nessun «assegnata a». Il legame con una
/// persona nasce solo quando la scheda parte via chat, e quel legame il server
/// non lo vede mai.
///
/// 💡 Per ritrovarle c'è il **Rif. Allievo**, che è un promemoria del trainer e
/// lo vede solo lui (R4).
class MieSchedeScreen extends ConsumerWidget {
  const MieSchedeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stato = ref.watch(mieSchedeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Le mie schede')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.compositoreScheda),
        icon: const Icon(Icons.add),
        label: const Text('Nuova scheda'),
      ),
      body: stato.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(mieSchedeProvider),
        ),
        data: (schede) => schede.isEmpty
            ? const EmptyState(
                icon: Icons.fitness_center_outlined,
                title: 'Nessuna scheda',
                message: 'Scrivine una: potrai mandarla a un allievo dalla chat.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(mieSchedeProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(Gap.md),
                  itemCount: schede.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                  itemBuilder: (_, i) => _Riga(scheda: schede[i]),
                ),
              ),
      ),
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({required this.scheda});

  final SchedaAllenamento scheda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(scheda.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*
             * 💡 Il «Rif. Allievo» è la sola cosa che distingue due schede che
             * si chiamano uguale. ⚠️ Se manca la chiave non vuol dire che sia
             * vuoto: vuol dire che quella scheda l'ha scritta un altro (R4).
             */
            if (scheda.rifAllievo != null && scheda.rifAllievo!.trim().isNotEmpty)
              Text(scheda.rifAllievo!, style: theme.textTheme.bodySmall),
            Text(
              '${scheda.giorni.length} ${scheda.giorni.length == 1 ? "giorno" : "giorni"}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('${AppRoutes.mieSchede}/${scheda.id}'),
      ),
    );
  }
}
