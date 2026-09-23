import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/intestazione_app.dart';
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
      /*
       * ══ 🆕 UN NOME SOLO PER UNA COSA SOLA — 15/09/2026 ══════════════
       *
       * ⛔ **La stessa cosa si chiamava in tre modi in due schermate**: dal
       * profilo «**I miei piani alimentari**», qui «**I miei consigli
       * alimentari**», e il vuoto diceva «**Nessun consiglio**». ⚠️ Chi tocca
       * una voce e ne trova un'altra si chiede se ha sbagliato strada.
       *
       * ⛔ **Vinceva «piano alimentare», e il 23/09/2026 ha perso.**
       *
       * 📌 Il committente: *«cambia tutte le occorrenze di piano alimentare
       * in consigli alimentari: ancora non esiste il nutrizionista, quindi non
       * possiamo fornire piani alimentari»*.
       *
       * 🚨 E non è una preferenza di stile: un piano alimentare lo redige un
       * biologo nutrizionista, un dietista o un medico. ⚠️ **Questa schermata lo
       * diceva già** — il riquadro nel compositore recita *«un piano alimentare
       * vero lo può fare solo un biologo nutrizionista…»* — e intanto si
       * intitolava «I miei piani alimentari»: l'avvertenza e l'insegna dicevano
       * il contrario.
       *
       * ⚠️ **Resta «piano» dove il piano c'è davvero**: il PDF che l'allievo
       * importa è stato scritto da un professionista, e la schermata
       * dell'import fa dichiarare chi l'ha firmato. Chiamarlo «consigli»
       * sarebbe falso al contrario, e indebolirebbe una frase che serve.
       */
      appBar: const IntestazioneApp(titolo: 'I miei consigli alimentari'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.compositorePiano),
        icon: const Icon(Icons.add),
        // ⚠️ Plurale: «consigli» non ha un singolare che regga da solo qui.
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
                message:
                    'Scrivine: potrai mandarli a un allievo dalla chat.',
              )
            : RefreshIndicator(
                onRefresh: () => aggiornaTutto(
                  context,
                  ref,
                  () => ref.invalidate(mieiPianiProvider),
                ),
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
        title: Text(
          piano.nome,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('${AppRoutes.mieiPiani}/${piano.id}'),
      ),
    );
  }
}
