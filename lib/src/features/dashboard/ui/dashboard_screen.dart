import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/states.dart';
import '../../forma/ui/scheda_forma.dart';
import '../../profile/corpo_controller.dart';
import '../consiglio_da_mostrare.dart';
import '../dashboard_controller.dart';
import '../gettoni_controller.dart';
import 'widgets/grafico_calorie.dart';
import 'widgets/scheda_peso.dart';
import 'widgets/today_cards.dart';
import 'widgets/today_header.dart';

/// La dashboard — C12.
///
/// Due grafici e un consiglio, come nell'app storica: il peso nel tempo e le
/// calorie assunte contro quelle bruciate. Sono le due domande su cui una
/// persona prende decisioni.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riepilogo = ref.watch(dashboardProvider);
    final consiglio = ref.watch(consiglioDaMostrareProvider);

    return Scaffold(
      // 🚨 Niente AppBar: l'intestazione **è** la scheda della palestra, e una
      // barra sopra di essa aggiungerebbe una seconda riga di titolo che dice
      // la stessa cosa due volte, rubando un quinto dello schermo.
      body: RefreshIndicator(
        /*
         * 🆕 FASE 1-ter — strisciare in giù risincronizza anche Health.
         *
         * 🚨 **Qui più che altrove**: è la schermata dove si guarda l'obiettivo
         * calorico del giorno, cioè l'unico numero che le calorie bruciate
         * cambiano. Chi torna dall'allenamento e striscia qui si aspetta di
         * vederlo aggiornato — ed è precisamente quello che non succedeva.
         *
         * ⚠️ La rotellina **non aspetta** Health: si chiude con la rete, e il
         * numero arriva quando arriva. Vedi `aggiornaTutto`.
         */
        onRefresh: () => aggiornaTutto(context, ref, () {
          ref
            ..invalidate(dashboardProvider)
            ..invalidate(weightSeriesProvider)
            ..invalidate(storicoCorpoProvider)
            ..invalidate(caloriesSeriesProvider)
            ..invalidate(adviceProvider);
        }),
        child: riepilogo.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            error: ApiClient.unwrapError(e),
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (r) => ListView(
            // ⚠️ Nessun `padding` orizzontale sulla lista: l'intestazione deve
            // arrivare ai bordi. Lo spazio lo mette `_Blocchi`, che è anche il
            // punto unico in cui vive la distanza fra una scheda e l'altra —
            // affidarla al margine di serie di `Card` le lasciava appiccicate.
            padding: EdgeInsets.zero,
            children: [
              TodayHeader(riepilogo: r),

              _Blocchi(
                children: [
                  CaloriesCard(riepilogo: r),

                  /*
                   * 🚨 **La card non sparisce mai** — 20/08/2026.
                   *
                   * 📌 *«la card del consiglio del giorno si deve sempre vedere
                   * (a meno che io non l'abbia disabilitato), al limite si
                   * mostra il consiglio del giorno precedente, se ancora non è
                   * pronto quello nuovo»*.
                   *
                   * ⚠️ Prima spariva in **quattro** modi e tre erano difetti:
                   * mentre caricava, se l'AI non rispondeva, e — il più
                   * frequente — mentre il server la rigenerava perché il
                   * contesto era cambiato. Cioè spariva proprio a chi aveva
                   * appena segnato un pasto: puniva l'uso dell'app.
                   *
                   * 💡 Se manca il consenso all'AI si **porta a darlo** invece
                   * di tacere: quello non è qualcosa da aspettare, è qualcosa
                   * da fare.
                   */
                  switch (consiglio.valueOrNull?.stato) {
                    StatoConsiglio.serveConsenso => const _ConsensoAiMancante(),
                    StatoConsiglio.senzaAi => const _SenzaAi(),
                    StatoConsiglio.spento => null,
                    StatoConsiglio.inArrivo => const _ConsiglioInArrivo(),
                    _ => _Consiglio(
                      testo: consiglio.valueOrNull?.testo ?? '',
                      generatoIl: consiglio.valueOrNull?.generatoIl,
                      vecchio:
                          consiglio.valueOrNull?.stato ==
                          StatoConsiglio.vecchio,
                    ),
                  },

                  /*
                   * 🆕 FASE 2-sexies — carico e carica.
                   *
                   * 💡 Accanto al recupero e non altrove: sono la stessa
                   * domanda vista da due distanze — come sto stanotte, e come
                   * sto questa settimana.
                   */
                  const SchedaForma(),

                  const RecoveryCard(),

                  /*
                   * ⚖️ **Peso e grafico: una scheda sola** — 3b-O.6+8.
                   *
                   * ⛔ `WeightCard` e `_GraficoPeso` **non esistono più**: erano
                   * due schede lontane fra loro che rispondevano alla stessa
                   * domanda, e chi le leggeva doveva tenersi il numero a mente
                   * mentre scorreva fino al grafico.
                   */
                  SchedaPeso(pesoObiettivo: r.body.targetWeightKg),

                  const TrainingCard(),
                  /*
                   * 🔥 **Il grafico delle calorie, rifatto** — 3b-O.9.
                   *
                   * ⛔ `_GraficoCalorie` **non esiste più**: affiancava due
                   * grandezze che non erano la stessa cosa — un totale e uno
                   * scostamento — e il confronto che invitava a fare non
                   * significava niente.
                   */
                  const GraficoCalorie(),
                ],
              ),

              const SizedBox(height: Gap.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Impila le schede con **una** distanza, decisa in un posto solo.
///
/// 🚨 Lasciare la spaziatura al margine di serie di `Card` (4 px verticali) le
/// fa sembrare incollate, e aggiungerne una a mano dentro ogni scheda
/// significherebbe sette punti da tenere allineati. I `null` si scartano qui: chi
/// costruisce l'elenco non deve preoccuparsi di lasciare buchi.
class _Blocchi extends StatelessWidget {
  const _Blocchi({required this.children});

  final List<Widget?> children;

  @override
  Widget build(BuildContext context) {
    final visibili = children.whereType<Widget>().toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visibili.length; i++) ...[
            if (i > 0) const SizedBox(height: Gap.md),
            visibili[i],
          ],
        ],
      ),
    );
  }
}

/// La card del consiglio del giorno.
///
/// ── 🚨 L'avvertenza NON è una postilla: è metà della card ─────────────────
///
/// Richiesta del committente, 16/08/2026: *«deve essere specificamente indicato
/// che è generato da AI e che non ha NESSUN VALORE MEDICO, che l'utente non
/// dovrebbe fidarsi e che lo dovrebbe far vedere a un medico sportivo»*.
///
/// ⚠️ Perciò sta **sempre a schermo**, sotto il testo, e non dietro un tocco né
/// in fondo a una schermata di impostazioni. Un'avvertenza che bisogna cercare
/// è un'avvertenza che non c'è.
///
/// 💡 E il prompt lavora nella stessa direzione (regola 5): al modello è vietato
/// il tono della prescrizione — niente «devi», «ti serve». Un testo che dice
/// «devi» sotto una riga che dice «non fidarti» si contraddice da solo, e a
/// vincere è sempre il testo più grande.
class _Consiglio extends ConsumerStatefulWidget {
  const _Consiglio({
    required this.testo,
    this.generatoIl,
    this.vecchio = false,
  });

  final String testo;

  final DateTime? generatoIl;

  /// Se quello che si sta mostrando **non è di oggi**.
  ///
  /// 🚨 **Va detto, non nascosto.** Mostrare il consiglio di ieri come se fosse
  /// di oggi vorrebbe dire far leggere una frase sul riposo a chi si è appena
  /// allenato, senza che nulla lo avverta. ⚠️ È il tipo di bugia che non fa
  /// danno subito e distrugge la fiducia in tutto il resto.
  final bool vecchio;

  @override
  ConsumerState<_Consiglio> createState() => _ConsiglioState();
}

class _ConsiglioState extends ConsumerState<_Consiglio> {
  bool _inCorso = false;

  /// Rigenera **pagando**: è una chiamata vera al modello.
  ///
  /// 🚨 `manuale: true` fa saltare la cache al server. Senza, il tocco
  /// restituirebbe lo stesso testo di prima senza spendere niente — e
  /// sembrerebbe rotto.
  Future<void> _rigenera() async {
    setState(() => _inCorso = true);

    try {
      await ref.read(rigeneraConsiglioProvider)();
      ref
        ..invalidate(adviceProvider)
        // 💡 Il saldo è appena cambiato: senza questa riga l'intestazione
        // continuerebbe a mostrare il numero di prima fino al prossimo avvio.
        ..invalidate(gettoniProvider);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.unwrapError(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sopra = theme.colorScheme.onPrimaryContainer;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: sopra),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Spunto di oggi',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: sopra,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                /*
                 * 🚨 **Il costo è scritto sul pulsante, non in un avviso dopo.**
                 * Stessa regola delle linguette del cibo: chi sta per spendere
                 * lo deve sapere **mentre decide**, non mentre scopre il saldo
                 * calato.
                 */
                if (_inCorso)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Gap.sm),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _rigenera,
                    icon: Icon(Icons.refresh_rounded, size: 18, color: sopra),
                    label: Text(
                      '1 gettone',
                      style: theme.textTheme.labelSmall?.copyWith(color: sopra),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                /*
                 * 🆕 **Nascondere la card** — 3b-O.3.2, 21/08/2026.
                 *
                 * 📌 *«deve esserci sempre un toggle per nascondere la card
                 * (se la nascondo la devo poter riattivare dalle impostazioni,
                 * ovviamente)»*.
                 *
                 * ⚠️ **Non spegne il consiglio, nasconde la card**: sono due cose
                 * diverse, e l'interruttore che ferma la spesa sta nel profilo.
                 * 💡 Chi tocca qui vuole spazio sulla schermata, non
                 * risparmiare.
                 *
                 * 🚨 E lo dice, con un messaggio che porta dove si riaccende:
                 * un elemento che sparisce senza dire come tornare è un
                 * elemento perso.
                 */
                IconButton(
                  onPressed: () async {
                    final messaggero = ScaffoldMessenger.of(context);

                    await ref
                        .read(consiglioNascostoProvider.notifier)
                        .imposta(nascosto: true);

                    messaggero.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Nascosta. La riattivi da Profilo → Consiglio del giorno.',
                        ),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.visibility_off_outlined,
                    size: 18,
                    color: sopra,
                  ),
                  tooltip: 'Nascondi',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),

            const SizedBox(height: Gap.sm),

            /*
             * 🚨 **Si dice che non è di oggi, e si dice PRIMA del testo.**
             *
             * ⚠️ Sotto lo leggerebbe chi ha già finito di leggere il consiglio,
             * cioè troppo tardi: chi si è appena allenato deve sapere che sta
             * per leggere una frase scritta ieri **mentre** la legge.
             */
            if (widget.vecchio) ...[
              Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 14,
                    color: sopra.withValues(alpha: 0.75),
                  ),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(
                      widget.generatoIl == null
                          ? 'Questo è l\'ultimo che avevi: sto preparando quello di oggi.'
                          : 'Consiglio del ${DateFormat('d MMMM', 'it').format(widget.generatoIl!)}: '
                                'sto preparando quello di oggi.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: sopra.withValues(alpha: 0.75),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xs),
            ],

            Text(
              widget.testo,
              style: theme.textTheme.bodyMedium?.copyWith(color: sopra),
            ),

            const SizedBox(height: Gap.md),
            Divider(height: 1, color: sopra.withValues(alpha: 0.20)),
            const SizedBox(height: Gap.sm),

            // 🚨 L'avvertenza. Sempre visibile, mai dietro un tocco.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: sopra.withValues(alpha: 0.75),
                ),
                const SizedBox(width: Gap.xs),
                Expanded(
                  child: Text(
                    'Scritto da un\'intelligenza artificiale sui pochi dati che ha, '
                    'e può sbagliare. Non è un parere medico e non va preso per '
                    'buono: se riguarda la tua salute, parlane con un medico dello '
                    'sport.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: sopra.withValues(alpha: 0.75),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsiglioInArrivo extends StatelessWidget {
  const _ConsiglioInArrivo();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sopra = theme.colorScheme.onPrimaryContainer;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: sopra),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                'Sto preparando il consiglio di oggi…',
                style: theme.textTheme.bodyMedium?.copyWith(color: sopra),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'assistente non e' attivo — 3b-O.3.1, 21/08/2026.
///
/// ══ 🚨 IL DIFETTO CHE QUESTA SCHEDA CHIUDE ══════════════════════════════
///
/// 📌 Il committente: *«se non ho attiva l'ai perché ho 0 crediti o perché non
/// ho l'abbonamento, mi mostra il consiglio del giorno in perpetuo
/// caricamento»*.
///
/// ⚠️ È l'altra faccia della regola del 20/08 *«la card non sparisce mai»*: si
/// è impedito che sparisse, e non si è previsto il caso in cui un consiglio
/// **non può proprio esserci**. 🚨 Una rotellina che gira per sempre è peggio di
/// una card assente: dice «sto arrivando» e non arriva.
///
/// ── ⛔ Cosa manca ancora, e va detto ─────────────────────────────────────
///
/// 📌 La richiesta diceva anche *«mi deve invogliare a sottoscrivere un
/// abbonamento o ad acquistare dei gettoni»*. ⚠️ **Nell'app non esiste nessuna
/// schermata per farlo**: il saldo dei gettoni si vede, ma non c'è nessun posto
/// dove comprarli. 💡 Il pulsante non c'è perché non avrebbe dove andare — un
/// bottone che non porta da nessuna parte è peggio di nessun bottone.
class _SenzaAi extends StatelessWidget {
  const _SenzaAi();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              color: tema.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consiglio del giorno',
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "L'assistente non è attivo sul tuo profilo. Con un piano che "
                    'lo comprende — o con dei gettoni — ogni mattina trovi qui un '
                    'consiglio costruito su quello che hai mangiato, come hai '
                    'dormito e come ti sei allenato.',
                    style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: Gap.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: () => context.push(AppRoutes.acquisti),
                      child: const Text('Scopri come attivarlo'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsensoAiMancante extends StatelessWidget {
  const _ConsensoAiMancante();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  'Il consiglio del giorno',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Per prepararlo dobbiamo mandare quello che hai scritto nel '
              'diario a un servizio esterno. Non lo facciamo senza il tuo '
              'permesso.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: () => context.push(AppRoutes.consensi),
                child: const Text('Decidi tu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le bruciate della colonna `i`: quelle dell'orologio se ci sono, altrimenti
/// quelle della serie del server.
///
/// 🚨 **Si sostituiscono, non si sommano.** L'orologio ha gia' misurato
/// l'allenamento che la formula del server sta stimando: sommarli darebbe il
/// doppio, con un numero che resta plausibile. E' la stessa regola di
/// `BruciateDelGiorno`, applicata al grafico.
