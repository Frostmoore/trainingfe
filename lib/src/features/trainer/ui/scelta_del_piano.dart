import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../acquisti/data/listino.dart';
import '../trainer_controller.dart';

/// 💳 **Il tuo piano da trainer** — §9.6, 18/09/2026.
///
/// ══ 📌 PERCHE' ESISTE ═════════════════════════════════════════════════════
///
/// ⛔ Fino al 18/09 un trainer **non aveva nessun posto dove pagare il suo
/// piano**. Questa schermata diceva già *«Per averne di più serve un piano
/// superiore»* — e non c'era un pulsante per prenderlo. 📌 Il committente: *«va
/// sistemato tutto, in tutti gli scenari»*.
///
/// ══ ⚠️ LA STRADA LA DECIDE IL SERVER ══════════════════════════════════════
///
/// Chi ha già un canone pagato **cambia** piano — Stripe calcola la differenza —
/// gli altri **aprono il pagamento**. 🚨 Qui si legge `puoCambiare` dal server e
/// basta: decidere nell'app vorrebbe dire che un tasto sbagliato apre un secondo
/// abbonamento, cioè due addebiti al mese.
class SceltaDelPiano extends ConsumerStatefulWidget {
  const SceltaDelPiano({super.key});

  static Future<void> mostra(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const SceltaDelPiano(),
  );

  @override
  ConsumerState<SceltaDelPiano> createState() => _SceltaDelPianoState();
}

class _SceltaDelPianoState extends ConsumerState<SceltaDelPiano> {
  String? _inCorso;

  Future<void> _scegli(PianoInVendita piano, {required bool cambia}) async {
    setState(() => _inCorso = piano.codice);

    final errore = await scegliIlPiano(
      ref,
      codice: piano.codice,
      cambia: cambia,
    );

    if (!mounted) return;

    setState(() => _inCorso = null);

    if (errore != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errore)));

      return;
    }

    if (cambia) {
      /*
       * 💡 Cambiato: i posti sono già quelli nuovi — il server aggiorna la riga
       * subito, non al webhook — quindi l'elenco si ricarica e si chiude.
       */
      ref.invalidate(mieiUtentiProvider);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Adesso hai il piano «${piano.nome}».')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final listino = ref.watch(listinoProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.lg),
      child: listino.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => const Padding(
          padding: EdgeInsets.all(Gap.xl),
          child: Text('Non riesco a caricare i piani. Riprova fra poco.'),
        ),
        data: (l) {
          /*
           * ⚠️ Solo i piani a canone: il consumo è delle palestre, e un
           * trainer non lo vede nemmeno dal server — questo filtro è solo la
           * seconda serratura.
           */
          final piani = l.piani.where((p) => !p.aConsumo).toList();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Il tuo piano',
                style: tema.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Gap.sm),

              /*
               * 🚨 **Il pagamento non riuscito per primo.** Stripe riprova per
               * qualche giorno: è il momento di cambiare carta, non di scoprirlo
               * a servizio spento.
               */
              if (l.pagamentoFallitoIl != null) ...[
                Container(
                  padding: const EdgeInsets.all(Gap.md),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "L'ultimo pagamento non è andato a buon fine. Stripe "
                    'riproverà nei prossimi giorni: se la carta è scaduta, '
                    'aggiornala dalla gestione del pagamento.',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.md),
              ],

              if (piani.isEmpty)
                const Text('Non ci sono piani da scegliere.')
              else
                for (final p in piani)
                  _Piano(
                    piano: p,
                    suo: p.codice == l.pianoAttuale,
                    occupato: _inCorso == p.codice,
                    spento: _inCorso != null,
                    cambia: l.puoCambiare,
                    onScegli: () => _scegli(p, cambia: l.puoCambiare),
                  ),

              const SizedBox(height: Gap.sm),
              Text(
                'Salendo paghi subito la differenza per i giorni che restano. '
                'Non puoi scendere sotto i posti che stai già usando.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Piano extends StatelessWidget {
  const _Piano({
    required this.piano,
    required this.suo,
    required this.occupato,
    required this.spento,
    required this.cambia,
    required this.onScegli,
  });

  final PianoInVendita piano;
  final bool suo;
  final bool occupato;
  final bool spento;
  final bool cambia;
  final VoidCallback onScegli;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    piano.nome,
                    style: tema.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${euro(piano.prezzoCent)} al mese · '
                    '${piano.posti == null ? 'posti senza limite' : '${piano.posti} posti'}',
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Gap.sm),
            if (suo)
              Chip(
                label: const Text('Il tuo'),
                backgroundColor: tema.colorScheme.primaryContainer,
              )
            else
              FilledButton(
                onPressed: spento ? null : onScegli,
                child: occupato
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    /*
                     * ⚠️ Il tasto dice cosa succede: chi ha già un piano ci
                     * **passa**, gli altri lo **scelgono**.
                     */
                    : Text(cambia ? 'Passa' : 'Scegli'),
              ),
          ],
        ),
      ),
    );
  }
}
