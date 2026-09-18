import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../trainer_controller.dart';

/// 🎟️ **Tieni il posto o lo liberi?** — AH.1-ter.6, 18/09/2026.
///
/// ══ 📌 LA REGOLA DEL COMMITTENTE ═══════════════════════════════════════════
///
/// > *«se un allievo di un free trainer si iscrive in una palestra in cui
/// > lavora quel free trainer, allora il free trainer deve ricevere la modale
/// > che gli chiede se vuole mantenere lo slot occupato o liberarlo»*
///
/// > *«se il trainer decide di mantenere lo slot occupato, l'allievo passa alla
/// > palestra, poi se si dissocia dalla palestra torna al trainer. Se il trainer
/// > decide di liberare lo slot, […] non torna al trainer.»*
///
/// ══ ⛔ COSA NON DICE, ED E' IMPORTANTE ═════════════════════════════════════
///
/// **Non dice che il rapporto è sospeso**, perché non lo è: il trainer continua
/// a vedere il suo allievo e l'allievo il suo trainer. 🚨 Una frase come
/// «il rapporto è in pausa» sarebbe falsa, e farebbe decidere il trainer su
/// una cosa che non sta succedendo. La domanda è solo sui **soldi**.
///
/// ══ ⚖️ PERCHE' «TENGO IL POSTO» E' IL TASTO PIENO ══════════════════════════
///
/// Perché **liberarlo non si torna indietro**: chi lo libera non si riprende
/// quell'allievo quando esce dalla palestra. 💡 È lo stesso principio della
/// modale del secondo trainer (AH.1-ter.4): la scelta che cambia qualcosa, e
/// che non si annulla, si fa apposta — e non deve stare sotto il dito di chi
/// tocca il primo tasto che vede.
///
/// ⚠️ **Possono essere più d'uno**, e il committente l'ha detto: *«gli allievi
/// che ha che sono anche iscritti in quella palestra (potrebbero essere più di
/// uno)»*. Ogni riga si risponde da sola, e la finestra si chiude quando non
/// ne resta nessuna.
class SceltaDelloSlot extends ConsumerStatefulWidget {
  const SceltaDelloSlot({required this.daDecidere, super.key});

  final List<SlotDaDecidere> daDecidere;

  /// ⚠️ **Senza `context` di serie**, come le due modali dell'abbonamento:
  /// chi la apre sta **sopra** il `Navigator`, e il proprio `context` non ne
  /// trova nessuno su cui aprirla. 💡 `chiaveDelNavigatore` conosce quello vero.
  static Future<void> mostra(
    List<SlotDaDecidere> daDecidere, [
    BuildContext? context,
  ]) => showModalBottomSheet<void>(
    context: context ?? chiaveDelNavigatore.currentContext!,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,

    /*
     * 🚨 **Non si chiude toccando fuori.** Una domanda sui soldi chiusa per
     * sbaglio con un tocco sul bordo tornerebbe al prossimo rientro, e nel
     * frattempo il trainer penserebbe di aver risposto.
     */
    isDismissible: false,
    enableDrag: false,
    builder: (_) => SceltaDelloSlot(daDecidere: daDecidere),
  );

  @override
  ConsumerState<SceltaDelloSlot> createState() => _SceltaDelloSlotState();
}

class _SceltaDelloSlotState extends ConsumerState<SceltaDelloSlot> {
  late final List<SlotDaDecidere> _restano = [...widget.daDecidere];

  /// Chi ha una risposta in viaggio verso il server: i suoi tasti si spengono.
  final Set<int> _inCorso = {};

  Future<void> _rispondi(SlotDaDecidere voce, {required bool tengo}) async {
    setState(() => _inCorso.add(voce.allievoId));

    try {
      await ref
          .read(trainerActionsProvider)
          .decidiLoSlot(voce.allievoId, tengo: tengo);

      if (!mounted) return;

      setState(() {
        _inCorso.remove(voce.allievoId);
        _restano.removeWhere((v) => v.allievoId == voce.allievoId);
      });

      if (_restano.isEmpty) Navigator.of(context).pop();
    } on Object catch (e) {
      if (!mounted) return;

      setState(() => _inCorso.remove(voce.allievoId));

      /*
       * 🚨 **`unwrapError` prima, e poi si guarda** — la trappola pagata sulla
       * modale del secondo trainer: il client rilancia l'errore grezzo del
       * trasporto, e un `on <Tipo> catch` non prende niente.
       */
      final errore = ApiClient.unwrapError(e);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Non sono riuscito a salvare. ${errore.message}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final uno = _restano.length == 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            uno
                ? 'Un tuo allievo è entrato nella tua palestra'
                : 'Alcuni tuoi allievi sono entrati nella tua palestra',
            style: tema.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.sm),

          /*
           * 💡 **Cosa comporta, detto prima della domanda.** Senza, «tieni il
           * posto?» è una domanda a cui non si può rispondere — che è la stessa
           * lezione della modale del secondo trainer.
           *
           * ⛔ E nessuna parola su un rapporto «in pausa»: non lo è.
           */
          Text(
            'Continui a seguirlo come prima. Ora però è anche iscritto '
            'alla palestra, che copre il suo posto.\n\n'
            'Se tieni il posto, continui a pagarlo: quando uscirà dalla '
            'palestra resterà tuo.\n'
            'Se lo liberi, non lo paghi più: quando uscirà dalla palestra '
            'non tornerà da te.',
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.lg),

          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _restano.length,
              separatorBuilder: (_, _) => const Divider(height: Gap.lg),
              itemBuilder: (_, i) => _Voce(
                voce: _restano[i],
                occupato: _inCorso.contains(_restano[i].allievoId),
                onTengo: () => _rispondi(_restano[i], tengo: true),
                onLibero: () => _rispondi(_restano[i], tengo: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Voce extends StatelessWidget {
  const _Voce({
    required this.voce,
    required this.occupato,
    required this.onTengo,
    required this.onLibero,
  });

  final SlotDaDecidere voce;
  final bool occupato;
  final VoidCallback onTengo;
  final VoidCallback onLibero;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          voce.nome,
          style: tema.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (voce.palestra != null && voce.palestra!.isNotEmpty)
          Text(
            'Iscritto a ${voce.palestra}',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: Gap.sm),
        Row(
          children: [
            /*
             * ⚖️ **«Lo libero» è il tasto leggero**: non si torna indietro, e
             * la scelta che non si annulla si fa apposta.
             */
            Expanded(
              child: OutlinedButton(
                onPressed: occupato ? null : onLibero,
                child: const Text('Lo libero'),
              ),
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: FilledButton(
                onPressed: occupato ? null : onTengo,
                child: occupato
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tengo il posto'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
