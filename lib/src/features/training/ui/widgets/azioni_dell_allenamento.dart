/// Cosa si può fare a un allenamento già fatto — 3b-B.20.2 e B.20.5.
///
/// 📌 *«possibilità di rimuovere un allenamento»* e *«voglio poterci assegnare
/// anche un tipo di allenamento diverso dalla scheda»*.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../health/tipo_allenamento.dart';
import '../../data/storico_unificato.dart';
import '../../data/tipo_scelto.dart';
import '../../storico_unificato_controller.dart';

class AzioniDellAllenamento extends ConsumerWidget {
  const AzioniDellAllenamento({required this.voce, super.key});

  final VoceStorico voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /*
         * 🏃 **Dichiarare il tipo**, e solo per gli allenamenti del polso.
         *
         * ⛔ Su una seduta nata nell'app non ha senso: lì il tipo si sa dagli
         * esercizi, uno per uno, ed è un dato migliore di qualunque etichetta.
         */
        if (voce.dalPolso.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () => _dichiaraIlTipo(context, ref),
            icon: const Icon(Icons.category_outlined),
            label: Text(
              voce.tipoDichiarato == null
                  ? 'Che allenamento era?'
                  : 'Cambia tipo · ${TipoAllenamento.da(voce.tipoDichiarato!).nome}',
            ),
          ),

        const SizedBox(height: Gap.sm),

        TextButton.icon(
          onPressed: () => _rimuovi(context, ref),
          style: TextButton.styleFrom(foregroundColor: tema.colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Rimuovi questo allenamento'),
        ),
      ],
    );
  }

  /// Il foglio con gli sport che si possono dichiarare.
  ///
  /// 💡 In cima c'è **«Lascia decidere all'orologio»**: una scelta che non si può
  /// disfare è una trappola, ed è la stessa regola dell'assegnazione della
  /// scheda.
  Future<void> _dichiaraIlTipo(BuildContext context, WidgetRef ref) async {
    final scelto = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
              child: Text(
                'Che allenamento era?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            /*
             * ⚠️ **Si dice a cosa serve.** Senza questa riga la scelta sembra
             * un'etichetta estetica, e nessuno la userebbe: il motivo per farlo
             * è che da lì escono i muscoli e le calorie.
             */
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
              child: Text(
                'Serve a colorare i muscoli e a stimare le calorie quando '
                'l\'orologio non le sa.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

            if (voce.tipoDichiarato != null) ...[
              ListTile(
                leading: const Icon(Icons.watch_outlined),
                title: const Text('Lascia decidere all\'orologio'),
                onTap: () => Navigator.of(context).pop(''),
              ),
              const Divider(),
            ],

            for (final t in TipoScelto.tutti)
              ListTile(
                leading: Icon(TipoAllenamento.da(t.codice).icona),
                title: Text(t.nome),
                selected: t.codice == voce.tipoDichiarato,
                onTap: () => Navigator.of(context).pop(t.codice),
              ),
          ],
        ),
      ),
    );

    if (scelto == null) return;

    /*
     * ⚠️ **La stringa vuota vuol dire «togli»**, e `null` vuol dire «ho chiuso
     * il foglio senza scegliere». 🚨 Schiacciarle sullo stesso valore
     * cancellerebbe la dichiarazione a chi ha solo toccato fuori dal foglio.
     */
    for (final a in voce.dalPolso) {
      await dichiaraTipoAllenamento(
        ref,
        allenamentoId: a.id,
        codice: scelto.isEmpty ? null : scelto,
      );
    }
  }

  /// La conferma, che **dice cosa si porta via**.
  ///
  /// 🚨 ⛔ Una cancellazione che non dice cosa cancella è la cosa che il 24/08
  /// ha fatto sparire due esercizi durante un allenamento vero.
  Future<void> _rimuovi(BuildContext context, WidgetRef ref) async {
    final sicuro = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rimuovere questo allenamento?'),
        content: Text(
          '${cosaSiPortaViaLaRimozione(voce)}\n\n'
          'Non si può annullare.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Lascia stare'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (sicuro != true || !context.mounted) return;

    await rimuoviAllenamento(ref, voce);

    // 💡 Si torna indietro: restare su una pagina che descrive una cosa che non
    // c'è più è il modo più veloce di far credere che non sia successo niente.
    if (context.mounted) Navigator.of(context).maybePop();
  }
}
