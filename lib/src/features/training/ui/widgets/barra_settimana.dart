/// Il navigatore per settimana, nell'intestazione — 3b-A.4.1, 24/08/2026.
///
/// 📌 Il committente: *«Va aggiunto, nell'header, un navigatore per settimana e
/// lo storico deve essere ordinato per settimana»*.
///
/// ══ 💡 È IL FRATELLO DELLA BARRA DEI GIORNI ═══════════════════════════════
///
/// Stessa forma di `_BarraData` su «Oggi» — frecce ai lati, etichetta in mezzo,
/// il tocco sull'etichetta che riporta al presente — e non è pigrizia: due
/// navigatori temporali che si comportano in modo diverso nella stessa app
/// costringono a impararne due.
///
/// ⚠️ **Vive nell'intestazione di due schermate**: la sezione Allenamento
/// (`PlansScreen`, sotto le pasticche) e la rotta a sé `HistoryScreen`. Sono
/// due strade per lo stesso storico, e una che avesse il navigatore e l'altra
/// no sembrerebbe una funzione che va e viene.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../settimana_scelta.dart';
import '../../storico_unificato_controller.dart';

/// L'altezza che [BarraSettimana] occupa in `IntestazioneApp.altezzaSotto`.
///
/// 🚨 **Va sommata a mano** da chi la mette nell'intestazione: `Scaffold` non
/// sa quanto spazio serve a `sotto` e lo taglierebbe. Tenerla qui evita che i
/// due chiamanti usino due numeri diversi.
const double altezzaBarraSettimana = 40;

class BarraSettimana extends ConsumerWidget {
  const BarraSettimana({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final inizio = ref.watch(settimanaSceltaProvider);
    final controllo = ref.read(settimanaSceltaProvider.notifier);

    final eQuesta = inizio == lunediDi(DateTime.now());
    final fine = inizio.add(const Duration(days: 6));
    final sopra = theme.colorScheme.onPrimaryContainer;

    /*
     * 💡 **Il conteggio sta qui, non sopra l'elenco.**
     *
     * Prima ogni settimana aveva la sua riga «18 – 24 ago · 3 sedute» sopra le
     * card. Con il navigatore quella riga direbbe la stessa cosa due volte, a
     * dieci pixel di distanza. ⚠️ Il **numero** però serviva — è la risposta
     * alla domanda che ci si fa guardando lo storico, «quante volte mi sono
     * allenato questa settimana» — quindi si sposta, non si butta.
     *
     * 🚨 `valueOrNull`: mentre lo storico carica non si scrive «0 sedute», che
     * sarebbe un numero falso. Si scrive solo l'intervallo.
     */
    final quante = ref
        .watch(storicoUnificatoProvider)
        .valueOrNull
        ?.where((v) => lunediDi(v.quando) == inizio)
        .length;

    final etichetta = StringBuffer()
      ..write(
        eQuesta
            ? 'Questa settimana'
            : '${DateFormat('d MMM', 'it').format(inizio)} – '
                  '${DateFormat('d MMM', 'it').format(fine)}',
      );

    if (quante != null) {
      etichetta.write(' · $quante ${quante == 1 ? 'seduta' : 'sedute'}');
    }

    return SizedBox(
      height: altezzaBarraSettimana,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: controllo.indietro,
            icon: Icon(Icons.chevron_left_rounded, color: sopra),
            tooltip: 'Settimana prima',
            visualDensity: VisualDensity.compact,
          ),

          Flexible(
            child: GestureDetector(
              // 💡 Toccando si torna a questa settimana: con le frecce, da
              // marzo, ci vorrebbero venti tocchi.
              onTap: eQuesta ? null : controllo.questa,
              child: Text(
                etichetta.toString(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: sopra,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          IconButton(
            // ⛔ Spenta sulla settimana in corso: `null` disabilita il
            // pulsante, e si **vede**. Un allenamento della settimana prossima
            // non esiste, e portarci darebbe una schermata vuota che sembra un
            // guasto.
            onPressed: eQuesta ? null : controllo.avanti,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: eQuesta ? sopra.withValues(alpha: 0.3) : sopra,
            ),
            tooltip: 'Settimana dopo',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
