import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../health/salute_in_piu.dart';
import '../../../health/tipo_allenamento.dart';
import '../../data/storico_unificato.dart';
import '../../percorso_controller.dart';
import 'forma_del_percorso.dart';

/// 🗺️ Il percorso di un allenamento, con la sua richiesta di consenso.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// Il committente: *«ci deve essere la forma del percorso che ho fatto»*.
///
/// ══ ✅ IL PERCORSO ARRIVA DA SOLO, E QUESTA CARD LO DISEGNA E BASTA ══════
///
/// 📌 Il committente, l'08/09: *«non glielo devo chiedere ogni volta, sarebbe
/// ridicolo»*. **Ed è giusto.**
///
/// ⛔ **La prima versione aveva un pulsante «Mostra il percorso» sempre**, e
/// apriva una finestra di sistema **per ogni singola uscita**. Funzionava, ed
/// era insopportabile.
///
/// 💡 Con il permesso «tutti i percorsi» i tracciati entrano dalla
/// **sincronizzazione**, come il sonno e il battito: vedi
/// `PonteSalute._percorsiDegliAllenamenti`. ✅ Misurato: **1.604 punti** sulla
/// camminata delle 10:49, senza che nessuno premesse niente.
///
/// ══ ⚠️ IL PULSANTE RESTA, MA E' L'ECCEZIONE ══════════════════════════════
///
/// ⛔ Quel permesso **non si può chiedere da codice** — Google: *«attempts to
/// request the permission by applications will be ignored»* — e su Android 16
/// la voce non compare nemmeno nella schermata di Health Connect (verificato
/// l'08/09 con un dump della UI).
///
/// 🚨 Quindi c'è un caso in cui il tracciato non arriverà mai da solo, e per
/// quello resta la strada per singola uscita. ⚠️ Ma compare **solo quando il
/// percorso manca**: chi ce l'ha non vede nessun pulsante.
class PercorsoDellAllenamento extends ConsumerStatefulWidget {
  const PercorsoDellAllenamento({required this.voce, super.key});

  final VoceStorico voce;

  @override
  ConsumerState<PercorsoDellAllenamento> createState() =>
      _PercorsoDellAllenamentoState();
}

class _PercorsoDellAllenamentoState
    extends ConsumerState<PercorsoDellAllenamento> {
  bool _inCorso = false;

  /// 🚨 Il **primo** tratto, come per la foto: se l'orologio ha spezzato
  /// l'uscita in tre, il percorso è dell'uscita.
  int? get _allenamentoId => widget.voce.dalPolso.firstOrNull?.id;

  String? get _idSalute => widget.voce.dalPolso.firstOrNull?.idSalute;

  Future<void> _chiedi() async {
    final id = _allenamentoId;

    if (id == null) return;

    setState(() => _inCorso = true);

    try {
      await ref
          .read(chiediIlPercorsoProvider)
          .per(allenamentoId: id, idSalute: _idSalute);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = _allenamentoId;

    if (id == null) return const SizedBox.shrink();

    /*
     * ⛔ **Sui pesi non si chiede niente**, e non è una scorciatoia: una seduta
     * in palestra un percorso non ce l'ha, e un pulsante «mostra il percorso»
     * che apre una finestra per poi non trovare niente insegna a non premerlo
     * più — nemmeno dove funzionerebbe.
     */
    final tipo = widget.voce.dalPolso.first.tipo;

    if (!TipoAllenamento.conPercorso(tipo)) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final punti = ref.watch(percorsoDellAllenamentoProvider(id)).valueOrNull;
    final rifiutato =
        ref.watch(percorsoRifiutatoProvider(id)).valueOrNull ?? false;

    /*
     * ══ 📌 DENTRO LA CARD DEI NUMERI, NON SOTTO ═════════════════════
     *
     * Il committente, l'08/09: *«la forma del percorso non la voglio sotto, la
     * voglio nella stessa card con i numeri dell'allenamento»*.
     *
     * 💡 **Ed è la lettura giusta**: velocità, passo e tracciato rispondono
     * tutti alla stessa domanda — *com'è andata questa uscita*. ⛔ Due riquadri
     * separati suggerivano due argomenti diversi, e facevano scorrere per
     * mettere insieme cose che si guardano insieme.
     *
     * ⚠️ **Quindi qui non c'è più una `Card`**: la disegna chi ospita, cioè
     * [NumeriDellAllenamento]. Rimetterla vorrebbe dire una cornice dentro una
     * cornice.
     */
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.route_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: Gap.xs),
            Text('Il percorso', style: theme.textTheme.labelLarge),
          ],
        ),

        const SizedBox(height: Gap.sm),

        if (punti != null && punti.length >= 2) ...[
          /*
               * ✅ **Il caso normale, ed è muto**: nessun pulsante, nessuna
               * spiegazione, nessun permesso da chiedere. Il tracciato è
               * arrivato con la sincronizzazione e si guarda.
               */
          SizedBox(
            height: 200,
            width: double.infinity,
            child: FormaDelPercorso(punti: punti, spessore: 3),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            /*
                 * 💡 Dire quanti punti non è vanità tecnica: un tracciato con
                 * dodici punti e uno con milleduecento si disegnano uguali e non
                 * sono la stessa cosa. ⚠️ Chi vede una forma squadrata deve poter
                 * capire che è il GPS, non la strada.
                 */
            '${punti.length} punti · resta sul telefono',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else ...[
          /*
               * ⚠️ **Si arriva qui solo se il tracciato non è arrivato da solo**,
               * cioè quasi sempre perché manca il permesso «tutti i percorsi».
               * 🚨 E quel permesso non possiamo chiederlo: possiamo solo
               * accompagnarci la persona.
               */
          Text(
            rifiutato
                ? 'Non hai condiviso questo percorso.'
                : 'Il tuo orologio il percorso ce l\'ha, ma Android non ce '
                      'lo passa finché non attivi «Percorsi di allenamento» '
                      'in Health Connect.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: Gap.sm),

          /*
               * ⚠️ **La promessa va detta prima del pulsante, non dopo.** Il
               * percorso è la cosa più sensibile che l'app legge: dice dove sei
               * stato e a che ora. 🚨 Chi preme deve sapere che resta qui — e se
               * un domani non fosse più vero, questa riga va cambiata **insieme**
               * al codice che la rende falsa.
               */
          Text(
            'Resta sul telefono e nel tuo backup. Non lo mandiamo a '
            'nessuno, e non lo vede né la palestra né l\'AI.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.md),

          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              /*
                   * 💡 **Questo è il pulsante che risolve per sempre**: apre
                   * Health Connect, dove si concede una volta sola e poi i
                   * percorsi arrivano da soli con la sincronizzazione.
                   */
              FilledButton.tonalIcon(
                onPressed: () => const SaluteInPiu().apriIPermessi(),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Attiva i percorsi'),
              ),

              /*
                   * ⚠️ **E questo è il ripiego, per una uscita sola.** Sta in
                   * secondo piano di proposito: apre una finestra di sistema, e
                   * chi lo usa dovrà rifarlo per ogni allenamento. ⛔ Sarebbe
                   * ridicolo come strada principale — 📌 lo ha detto il
                   * committente, e aveva ragione.
                   */
              if (_idSalute != null)
                TextButton(
                  onPressed: _inCorso ? null : _chiedi,
                  child: Text(_inCorso ? 'Attendi…' : 'Solo questo, una volta'),
                ),
            ],
          ),

          if (_idSalute == null) ...[
            const SizedBox(height: Gap.sm),
            /*
                 * ⛔ **Senza l'id di Health Connect non si può nemmeno chiedere**,
                 * e va detto invece di offrire un pulsante che non fa niente:
                 * succede sugli allenamenti letti prima dell'08/09.
                 */
            Text(
              'Questo allenamento è arrivato prima che l\'app sapesse '
              'chiedere i percorsi. Si sistema da sé alla prossima '
              'sincronizzazione, se l\'orologio ce l\'ha ancora.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ],
    );
  }
}
