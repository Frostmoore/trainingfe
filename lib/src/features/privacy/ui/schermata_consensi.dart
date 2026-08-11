import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../consensi_controller.dart';

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
      appBar: AppBar(title: const Text('Privacy e consensi')),
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
            Text(
              'Quello che decidi qui puoi cambiarlo quando vuoi, e togliere '
              'costa quanto mettere.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.lg),

            _Interruttore(
              titolo: 'Dati su sonno e recupero',
              spiegazione:
                  'Permette all\'app di leggere sonno, battito e variabilità '
                  'da Health Connect. Restano sul tuo telefono: non li mandiamo '
                  'a nessuno, nemmeno a noi.',
              concessoIl: dati.salute,
              chiave: 'health',
            ),
            const SizedBox(height: Gap.md),

            _Interruttore(
              titolo: 'Consiglio del giorno e riconoscimento dei pasti',
              spiegazione:
                  'Per funzionare, queste due cose mandano quello che hai '
                  'scritto nel diario ad Anthropic, negli Stati Uniti. '
                  'È un\'azienda diversa dalla nostra, e da quello che mangi si '
                  'possono dedurre cose sulla tua salute: per questo te lo '
                  'chiediamo a parte.',
              concessoIl: dati.ai,
              chiave: 'ai',
            ),

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

class _Interruttore extends ConsumerStatefulWidget {
  const _Interruttore({
    required this.titolo,
    required this.spiegazione,
    required this.concessoIl,
    required this.chiave,
  });

  final String titolo;
  final String spiegazione;
  final DateTime? concessoIl;
  final String chiave;

  @override
  ConsumerState<_Interruttore> createState() => _InterruttoreState();
}

class _InterruttoreState extends ConsumerState<_Interruttore> {
  bool _inCorso = false;

  Future<void> _cambia(bool dato) async {
    setState(() => _inCorso = true);

    try {
      await ref.read(cambiaConsensoProvider)(widget.chiave, dato);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Non ha funzionato: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final concesso = widget.concessoIl != null;

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
                    widget.titolo,
                    style: testo.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: concesso,
                  onChanged: _inCorso ? null : _cambia,
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(widget.spiegazione, style: testo.bodyMedium),
            if (concesso) ...[
              const SizedBox(height: Gap.sm),
              Text(
                'Concesso il ${DateFormat('d MMMM y', 'it').format(widget.concessoIl!)}',
                style: testo.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
