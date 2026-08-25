/// «Single-day o multi-day?», prima di entrare — 3b-D.2, 25/08/2026.
///
/// 📌 *«Prima di entrare nella vera interfaccia di creazione scheda mi deve
/// chiedere se voglio una scheda single-day o multi-day. Nel caso di utente non
/// abbonato o non ai illimitata, ovviamente l'opzione multi-day deve essere
/// disabilitata con la ragione»*.
///
/// ══ 🚨 LA DOMANDA SI FA PRIMA, E NON E' UN DETTAGLIO DI FLUSSO ════════════
///
/// ⚠️ Chiederlo dopo — un interruttore dentro l'editor — vorrebbe dire che chi
/// non è abbonato scrive tre esercizi e **poi** scopre che quella forma non può
/// averla. 💡 Un limite che si incontra prima di lavorare è una regola; lo
/// stesso limite incontrato dopo è una perdita di tempo.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_controller.dart';
import '../../../dashboard/gettoni_controller.dart';
import '../../data/limiti_delle_schede.dart';

/// Quanti giorni avrà la scheda che si sta per scrivere.
enum TipoDiScheda { unGiorno, piuGiorni }

/// Chiede il tipo. `null` = ha cambiato idea.
Future<TipoDiScheda?> chiediIlTipoDiScheda(BuildContext context) =>
    showModalBottomSheet<TipoDiScheda>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _FoglioDelTipo(),
    );

class _FoglioDelTipo extends ConsumerWidget {
  const _FoglioDelTipo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    /*
     * 🚨 **La stessa condizione di `schedeBloccate`, dalla stessa funzione.**
     * ⛔ Riscriverla qui sarebbe stata la terza stesura della stessa regola — e
     * le prime due le ho sbagliate tutte e due (una volta unendo i due flag,
     * una volta leggendo l'«o» come un «e»).
     */
    final puo = senzaLimiti(
      abbonato: ref.watch(authControllerProvider).user?.abbonato,
      illimitata: ref.watch(gettoniProvider).valueOrNull?.illimitata,
    );

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
            child: Text(
              'Che scheda vuoi scrivere?',
              style: tema.textTheme.titleMedium,
            ),
          ),

          ListTile(
            leading: const Icon(Icons.looks_one_rounded),
            title: const Text('Un giorno solo'),
            subtitle: const Text(
              'Una lista di esercizi. La più comune, e la più veloce da usare.',
            ),
            onTap: () => Navigator.of(context).pop(TipoDiScheda.unGiorno),
          ),

          ListTile(
            enabled: puo,
            leading: Icon(
              puo ? Icons.calendar_month_rounded : Icons.lock_outline_rounded,
            ),
            title: const Text('Più giorni'),
            subtitle: Text(
              puo
                  ? 'Fino a 7 giorni, ognuno con i suoi esercizi.'
                  // ⚠️ **La ragione non si riscrive qui**: è la stessa frase
                  // che compare sulle schede bloccate, e due copie divergono
                  // alla prima correzione.
                  : MotivoBlocco.piuGiorni.spiegazione,
            ),
            onTap: puo
                ? () => Navigator.of(context).pop(TipoDiScheda.piuGiorni)
                : null,
          ),

          const SizedBox(height: Gap.md),
        ],
      ),
    );
  }
}
