import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
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
/// ══ 🚨 PERCHE' C'E' UN PULSANTE, E NON ARRIVA E BASTA ═════════════════════
///
/// ⛔ Health Connect non ci dà i percorsi scritti da un'altra app — cioè
/// sempre, visto che a scriverli è l'app dell'orologio. Torna
/// `ConsentRequired`, e il consenso si concede **una uscita alla volta**, in una
/// finestra di sistema che mostra la mappa e chiede se condividerla.
///
/// ⚠️ **L'interruttore «consenti sempre» esiste ma qui non c'è.** Misurato
/// l'08/09 con un dump della schermata: la sezione «Accesso aggiuntivo» di
/// Health Connect, per la nostra app, è vuota. 💡 Questa strada invece funziona.
///
/// 🚨 **Quindi il pulsante non è una comodità: è l'unico modo.** E parte da un
/// dito perché una finestra di sistema che si apre da sola, mentre scorri lo
/// storico, sarebbe insopportabile — e comunque Health Connect il percorso lo
/// dà **solo con l'app in primo piano**.
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.route_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Gap.sm),
                Text('Il percorso', style: theme.textTheme.titleMedium),
              ],
            ),

            const SizedBox(height: Gap.md),

            if (punti != null && punti.length >= 2) ...[
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
              Text(
                rifiutato
                    ? 'Non hai condiviso questo percorso. Puoi ancora farlo.'
                    : 'Il percorso ce l\'ha l\'orologio. Per vederlo qui serve '
                          'il tuo permesso, una volta per uscita.',
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

              if (_idSalute == null)
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
                )
              else
                FilledButton.tonalIcon(
                  onPressed: _inCorso ? null : _chiedi,
                  icon: _inCorso
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.map_outlined),
                  label: Text(
                    rifiutato ? 'Chiedi di nuovo' : 'Mostra il percorso',
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
