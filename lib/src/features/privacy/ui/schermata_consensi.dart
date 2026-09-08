import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../health/ui/widgets/connessione_salute.dart';
import '../consensi_controller.dart';
import 'widgets/dove_vanno_i_dati.dart';
import 'widgets/elenco_dei_consensi.dart';

/// I consensi facoltativi — S9.1.
///
/// ── 🚨 Perché sono due interruttori e non uno ─────────────────────────────
///
/// *«Accetto il trattamento dei dati»* in una casella sola **non è consenso
/// esplicito** ai sensi dell'art. 9(2)(a) GDPR. Tenere i propri dati **sul
/// proprio telefono** e mandare il diario **ad Anthropic, negli Stati Uniti**
/// sono due decisioni diverse, e chi accetta la prima non ha per questo
/// accettato la seconda.
///
/// ⚠️ **L'app funziona con entrambi spenti**, ed è la ragione per cui sono
/// facoltativi davvero: un consenso necessario per usare il servizio non è
/// «liberamente dato» (art. 7(4)), e quindi non è consenso.
class SchermataConsensi extends ConsumerWidget {
  const SchermataConsensi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consensi = ref.watch(consensiProvider);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Privacy e consensi'),
      body: consensi.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text('Non riesco a leggere i tuoi consensi.\n$e'),
          ),
        ),
        data: (dati) => ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            /*
           * ══ 🔗 IL COLLEGAMENTO A HEALTH CONNECT — 3b-P.8.3/P.10.2 ════════
           *
           * 📌 Il committente: *«la parte di connessione a Google Health
           * Connect deve andare in privacy e consensi»* · *«Deve includere
           * anche tutto quello che c'e' nella pagina di connessione»*.
           *
           * 💡 **Sta in cima**, prima degli altri consensi: e' l'unico che
           * apre una porta verso un'altra app, ed e' quello da cui dipendono
           * meta' dei dati che le card qui sotto elencano.
           */
            const ConnessioneSalute(),
            const SizedBox(height: Gap.lg),

            /*
             * ══ 📋 DOVE VANNO I DATI — 3b-P.10.1 ═══════════════════════════
             *
             * 📌 *«Deve avere una serie di cards che dettagliano esattamente
             * quali dati prendiamo, quali salviamo sul server e quali inviamo
             * all'AI (se l'AI è attiva)»*.
             *
             * 💡 **Prima degli interruttori, non dopo.** Un consenso si dà
             * sapendo a cosa: mettere la spiegazione sotto i pulsanti vorrebbe
             * dire che la legge solo chi ha già deciso.
             */
            const DoveVannoIDati(),
            const SizedBox(height: Gap.lg),

            Text(
              'Quello che decidi qui puoi cambiarlo quando vuoi, e togliere '
              'costa quanto mettere.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.lg),

            ElencoDeiConsensi(dati: dati),

            const SizedBox(height: Gap.lg),

            /*
             * 💡 **Qui sotto non è un consenso, ed è separato apposta.**
             *
             * È una preferenza: «voglio che il consiglio si aggiorni da solo».
             * Sta nella stessa schermata perché è lì che uno la cerca, ma sotto
             * una riga e con un titolo che non parla di dati.
             */
            const Divider(height: Gap.xl),
            Text(
              'Come funziona il consiglio',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Gap.sm),

            _InterruttoreConsiglio(acceso: dati.consiglioAutomatico),

            const SizedBox(height: Gap.lg),
            Text(
              // ⚠️ Art. 7(3), terzo periodo: la revoca non ha effetto
              // retroattivo, e dirlo qui evita di prometterlo per sbaglio.
              'Se togli un consenso, smettiamo subito. Quello che è già stato '
              'fatto resta fatto: per cancellare anche i dati usa '
              '«Elimina account» dal profilo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// L'interruttore del consiglio automatico — 16/08/2026.
///
/// 🚨 **Non è un consenso, e sta apposta sotto una riga separata.** Un consenso
/// è una base giuridica: si dà, si revoca, e se ne conserva la data. Questa è
/// una preferenza — «voglio che il consiglio si aggiorni da solo» — e nel
/// database è un booleano, non una data.
///
/// 💡 Spegnerlo **non cancella** il consiglio che c'è: ferma la spesa, non la
/// lettura. Chi lo spegne e poi apre «Oggi» trova ancora l'ultimo scritto, con
/// l'ora.
class _InterruttoreConsiglio extends ConsumerStatefulWidget {
  const _InterruttoreConsiglio({required this.acceso});

  final bool acceso;

  @override
  ConsumerState<_InterruttoreConsiglio> createState() =>
      _InterruttoreConsiglioState();
}

class _InterruttoreConsiglioState
    extends ConsumerState<_InterruttoreConsiglio> {
  bool _inCorso = false;

  Future<void> _cambia(bool acceso) async {
    setState(() => _inCorso = true);

    try {
      await ref.read(cambiaConsensoProvider)('consiglio_automatico', acceso);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Non ha funzionato: $e')));
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Aggiorna il consiglio da solo',
                    style: testo.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: widget.acceso,
                  onChanged: _inCorso ? null : _cambia,
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Tre volte al giorno — mattina, primo pomeriggio e sera. '
              'Ogni aggiornamento costa un gettone. Se lo spegni, il consiglio '
              'resta quello dell\'ultima volta e lo aggiorni tu quando vuoi.',
              style: testo.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
