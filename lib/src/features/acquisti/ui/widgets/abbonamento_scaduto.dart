import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/chi_paga.dart';
import '../../data/gate_dell_abbonamento.dart';
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

    /*
     * 🆕 **Chi pagava** — 3b-AH.4, 12/09/2026.
     *
     * 📌 Il committente: *«la modale per lui deve dire che non è più
     * abbonato perché non è più abbonato il suo trainer o la sua palestra»*.
     *
     * ⛔ Fino all'11/09 questa finestra diceva a tutti *«il rinnovo automatico
     * era spento, quindi non abbiamo addebitato niente»*. 🚨 A un iscritto di
     * palestra è **falso due volte**: non ha spento niente e non ha mai pagato
     * niente. Gli faceva cercare un'impostazione che non ha, e gli nascondeva
     * l'unica cosa utile — parlarne con la palestra.
     *
     * ⚠️ Si legge dal **profilo** e non dal listino: questa finestra la apre il
     * ricontrollo al rientro, e chiedere una seconda risposta in quel momento
     * vorrebbe dire una richiesta di rete prima di poter scrivere una frase.
     * Con la rete lenta, la frase sbagliata comparirebbe per prima.
     */
    final chiPagava = ref.watch(chiPagaProvider);
    final altri = chiPagava.lopagaQualcunAltro;

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
              altri
                  ? '${chiPagava.nome[0].toUpperCase()}${chiPagava.nome.substring(1)} '
                        'non ha rinnovato l\'abbonamento. Non dipendeva da te, e '
                        'non ti è stato addebitato niente.'
                  : 'Il rinnovo automatico era spento, quindi non abbiamo '
                        'addebitato niente.',
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

            if (altri) ...[
              const SizedBox(height: Gap.md),
              Text(
                'Per tornare abbonato parlane con ${chiPagava.nome}: '
                'l\'abbonamento è suo, e da qui non c\'è niente da riattivare.',
                style: tema.textTheme.bodyMedium,
              ),
            ],

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

                /*
                 * ⛔ **Nessun «Riattiva» a chi non paga** — 3b-AH.4.
                 *
                 * 🚨 Gli farebbe comprare un abbonamento **personale**,
                 * cioè pagare due volte lo stesso servizio: appena la sua
                 * palestra rinnova, quello che ha comprato da solo diventa
                 * un doppione che continua a scalare ogni mese.
                 *
                 * 💡 E al suo posto non c'è un altro pulsante: non c'è
                 * niente che possa fare da qui. La cosa utile — parlarne
                 * con chi paga — sta scritta nel testo.
                 */
                if (!altri)
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
