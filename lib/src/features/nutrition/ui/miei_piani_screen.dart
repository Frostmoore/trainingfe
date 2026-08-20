import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/states.dart';
import '../compositore_piano_controller.dart';
import '../data/piano_alimentare.dart';

/// L'elenco dei piani alimentari che questo trainer ha scritto — G7.4.
///
/// 🚨 **Sono anonimi** (D4): non c'è nessun «assegnato a». Il legame con una
/// persona nasce solo quando il piano parte via chat, e quel legame il server
/// non lo vede mai.
///
/// 💡 Per ritrovarli c'è il **Rif. Allievo**, che è un promemoria del trainer e
/// lo vede solo lui.
class MieiPianiScreen extends ConsumerWidget {
  const MieiPianiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stato = ref.watch(mieiPianiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('I miei consigli alimentari')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.compositorePiano),
        icon: const Icon(Icons.add),
        label: const Text('Nuovi consigli'),
      ),
      body: stato.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(mieiPianiProvider),
        ),
        data: (piani) => piani.isEmpty
            ? const EmptyState(
                icon: Icons.restaurant_menu_outlined,
                title: 'Nessun consiglio',
                message: 'Scrivine uno: potrai mandarlo a un allievo dalla chat.',
              )
            : RefreshIndicator(
                onRefresh: () => aggiornaTutto(context, ref, () => ref.invalidate(mieiPianiProvider)),
                child: ListView.separated(
                  padding: const EdgeInsets.all(Gap.md),
                  itemCount: piani.length,
                  separatorBuilder: (_, _) => const SizedBox(height: Gap.sm),
                  itemBuilder: (_, i) => _Riga(piano: piani[i]),
                ),
              ),
      ),
    );
  }
}

class _Riga extends StatelessWidget {
  const _Riga({required this.piano});

  final PianoAlimentare piano;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(piano.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /*
             * 💡 Il «Rif. Allievo» è la sola cosa che distingue due piani che
             * si chiamano uguale. ⚠️ Se manca la chiave non vuol dire che sia
             * vuoto: vuol dire che quel piano l'ha scritto un altro (R4).
             */
            if (piano.rifAllievo != null && piano.rifAllievo!.trim().isNotEmpty)
              Text(piano.rifAllievo!, style: theme.textTheme.bodySmall),
            Text(
              '${piano.giorni.length} ${piano.giorni.length == 1 ? "giorno" : "giorni"}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('${AppRoutes.mieiPiani}/${piano.id}'),
      ),
    );
  }
}
