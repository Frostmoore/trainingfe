import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../modale_acquisti.dart';

/// 🛑 «Il tuo abbonamento è scaduto» — 08/09/2026.
///
/// 📌 Il committente: *«altrimenti — dopo la scadenza dell'abbonamento — deve
/// apparire una modale "Il tuo abbonamento è scaduto"»*.
///
/// ══ ⚠️ NON È UNA PUNIZIONE, ED È IL MOTIVO DI OGNI PAROLA QUI DENTRO ══════
///
/// ⛔ Chi arriva a questa modale **ha scelto** di non rinnovare: il rinnovo
/// automatico è spento solo se l'ha spento lui. 🚨 Trattarlo come qualcuno che
/// si è dimenticato di pagare — un rosso d'allarme, un «attenzione!» — vuol
/// dire dare dell'incapace a una persona che ha fatto una scelta.
///
/// 💡 Quindi: si dice **cosa è cambiato**, si dice **cosa resta suo**, e il
/// pulsante per riabbonarsi c'è ma non è l'unico modo di chiudere la finestra.
///
/// 🚨 **E si dice che i dati restano.** È la paura vera di chi vede scadere un
/// abbonamento in un'app che tiene peso, allenamenti e diario: non «cosa non
/// posso più fare», ma «cosa ho perso». La risposta è niente, e va detta prima
/// che la domanda si formi.
class AbbonamentoScaduto extends ConsumerWidget {
  const AbbonamentoScaduto({super.key});

  /// Il `context` e' facoltativo: senza, si usa il navigatore dell'app.
  ///
  /// == PERCHE' IL RIPIEGO E' LA CHIAVE GLOBALE ==
  ///
  /// Chi la chiama dal `builder` di `MaterialApp` -- il ricontrollo
  /// dell'abbonamento -- NON ha un `Navigator` sopra di se', e passando il
  /// proprio `context` otteneva "a context that does not include a Navigator".
  ///
  /// E l'eccezione partiva dentro un `addPostFrameCallback`: nessuna schermata
  /// rossa, nessun blocco, solo una riga in un log che nessuno guardava. La
  /// finestra semplicemente non usciva, e il codice si leggeva giusto.
  static Future<void> mostra([BuildContext? context]) => showModalBottomSheet(
    context: context ?? chiaveDelNavigatore.currentContext!,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const AbbonamentoScaduto(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Text(
                    'Il tuo abbonamento è scaduto',
                    style: tema.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.md),

            Text(
              'Il rinnovo automatico era spento, quindi non abbiamo addebitato '
              'niente.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.md),

            /*
             * 🚨 **Questa card è la parte più importante della modale.** La
             * domanda che si fa chi vede scadere un abbonamento non è «cosa non
             * posso più fare», è «cosa ho perso». ⛔ Lasciarla senza risposta
             * per due secondi basta a far pensare che i propri allenamenti
             * siano spariti.
             */
            Card(
              color: tema.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(Gap.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      color: tema.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        'I tuoi dati restano tutti dove sono: allenamenti, '
                        'peso, diario, schede e foto. Non si cancella niente, '
                        'e se ti riabboni ritrovi tutto com\'era.',
                        style: tema.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Gap.md),

            Text(
              'Senza abbonamento restano le tue calorie, i passi, il peso, lo '
              'storico e tre schede. Tornano sfumate le analisi — carico e '
              'carica, recupero, com\'è fatto, lo spunto di oggi e i tuoi '
              'allenamenti — e puoi far partire un allenamento al giorno.',
              style: tema.textTheme.bodySmall,
            ),
            const SizedBox(height: Gap.lg),

            Row(
              children: [
                /*
                 * ⚠️ **«Va bene» prima, e non solo per abitudine**: la via
                 * d'uscita deve essere almeno visibile quanto quella che
                 * costa. ⛔ Una modale con un solo pulsante che porta a pagare
                 * non è un avviso, è un imbuto.
                 */
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Va bene'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ModaleAcquisti.mostra(context);
                  },
                  child: const Text('Riattiva'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
