import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../palestra_controller.dart';

/// La tua palestra — 3b-P.13.4, 23/08/2026.
///
/// 📌 Il committente: *«Una volta connesso con una palestra ci dovranno essere i
/// dettagli della palestra e la possibilità di disconnettersi da quella
/// palestra»*.
class SchermataPalestra extends ConsumerWidget {
  const SchermataPalestra({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palestra = ref.watch(dettagliPalestraProvider);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'La tua palestra'),
      body: palestra.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text('Non riesco a leggere i dati della palestra.\n$e'),
          ),
        ),
        data: (p) => p == null
            // 💡 Non è un errore non avere una palestra: è uno stato.
            ? const _NessunaPalestra()
            : _Dettagli(palestra: p),
      ),
    );
  }
}

class _NessunaPalestra extends StatelessWidget {
  const _NessunaPalestra();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Text(
        'Non sei iscritto a nessuna palestra.',
        style: Theme.of(context).textTheme.bodyLarge,
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _Dettagli extends ConsumerStatefulWidget {
  const _Dettagli({required this.palestra});

  final DettagliPalestra palestra;

  @override
  ConsumerState<_Dettagli> createState() => _DettagliState();
}

class _DettagliState extends ConsumerState<_Dettagli> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.palestra;

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined, size: 32),
                    const SizedBox(width: Gap.md),
                    Expanded(
                      child: Text(
                        p.nome,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),

                if (p.iscrittoDal != null) ...[
                  const SizedBox(height: Gap.md),
                  _Riga(
                    icona: Icons.event_outlined,
                    etichetta: 'Iscritto dal',
                    valore: DateFormat('d MMMM y', 'it').format(p.iscrittoDal!),
                  ),
                ],

                if (p.contatto != null && p.contatto!.isNotEmpty) ...[
                  const SizedBox(height: Gap.sm),
                  _Riga(
                    icona: Icons.alternate_email_rounded,
                    etichetta: 'Contatto',
                    valore: p.contatto!,
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: Gap.lg),

        /*
         * ⛔ **Il pulsante è defilato, e non per timidezza.** È un'azione che
         * non si annulla da sola: per rientrare serve di nuovo il codice della
         * palestra, e quello lo dà la palestra. 💡 Un `OutlinedButton` in fondo
         * si trova quando lo si cerca, e non si tocca per sbaglio scorrendo.
         */
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: theme.colorScheme.error,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: _inCorso ? null : _conferma,
          icon: _inCorso
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout_rounded),
          label: const Text('Esci dalla palestra'),
        ),
      ],
    );
  }

  /// ══ 🚨 LA CONFERMA DICE COSA SI PERDE, NON «SEI SICURO?» ═══════════════
  ///
  /// ⚠️ «Sei sicuro?» non aggiunge nessuna informazione: chi ha premuto era
  /// sicuro. 💡 Quello che serve sapere è **cosa cambia**, e sono tre cose
  /// precise — le schede del trainer, i messaggi, e come si rientra.
  ///
  /// ⛔ La terza è la più importante e la si dimentica sempre: rientrare non
  /// dipende da chi esce.
  Future<void> _conferma() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text('Uscire da ${widget.palestra.nome}?'),
        content: const Text(
          'Il tuo diario, le tue misure e le schede che ti sei scritto da solo '
          'restano tuoi e ti seguono.\n\n'
          'Restano invece alla palestra: le schede e i piani che ti ha scritto '
          'il trainer, e la conversazione con lui — i messaggi sono di tutti e '
          'due, e non te li puoi portare via.\n\n'
          'Per rientrare ti servirà di nuovo il codice della palestra, e te lo '
          'può dare solo lei.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Esci'),
          ),
        ],
      ),
    );

    if (conferma != true || !mounted) return;

    setState(() => _inCorso = true);
    final messaggeria = ScaffoldMessenger.of(context);
    final navigatore = Navigator.of(context);

    try {
      await ref.read(esciDallaPalestraProvider)();

      if (!mounted) return;

      messaggeria.showSnackBar(
        SnackBar(content: Text('Sei uscito da ${widget.palestra.nome}.')),
      );

      // 💡 Si torna indietro: restare su una schermata che si chiama «La tua
      // palestra» dopo esserne usciti è la contraddizione più visibile
      // possibile.
      navigatore.pop();
    } on Object catch (errore) {
      messaggeria.showSnackBar(SnackBar(content: Text(errore.toString())));
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }
}

class _Riga extends StatelessWidget {
  const _Riga({
    required this.icona,
    required this.etichetta,
    required this.valore,
  });

  final IconData icona;
  final String etichetta;
  final String valore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icona, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: Gap.sm),
        Text(
          '$etichetta: ',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(child: Text(valore, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
