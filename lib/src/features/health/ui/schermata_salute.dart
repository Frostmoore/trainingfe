import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../health_controller.dart';

/// La schermata che spiega **cosa leggiamo e dove finisce** — S3.4.
///
/// 🚨 **Non è cortesia: senza, Google rifiuta la pubblicazione.** Health Connect
/// pretende che l'app dichiari l'uso dei dati e sappia rispondere all'intent
/// `ACTION_SHOW_PERMISSIONS_RATIONALE` — l'`intent-filter` nel manifest apre
/// esattamente questa schermata.
///
/// ⚠️ **E il permesso si chiede DA QUI, non all'avvio.** Chiedere prima che una
/// persona abbia capito a cosa serve è il modo più rapido per farselo negare
/// *per sempre*: su Android un rifiuto ripetuto rende il dialogo non più
/// riproponibile, e da lì l'unica strada è mandare l'utente nelle impostazioni
/// di sistema — cioè perderlo.
///
/// 💡 **La frase che conta è vera**, e per una volta non è una excusatio:
/// *«restano sul tuo telefono»*. Dopo S1 il server non ha nessun endpoint per
/// riceverli, quindi non è una promessa di condotta — è una cosa che il
/// software non è più capace di fare.
class SchermataSalute extends ConsumerWidget {
  const SchermataSalute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stato = ref.watch(healthControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sonno e recupero')),
      body: ListView(
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
                      Icon(Icons.phone_android_rounded, color: theme.colorScheme.primary),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          'Questi dati restano sul tuo telefono',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  const Text(
                    'Sonno, variabilità cardiaca e battito a riposo vengono letti '
                    'dal tuo telefono e salvati qui dentro. Non vengono inviati ai '
                    'nostri server, non li vede la tua palestra, non li vede il tuo '
                    'trainer e non vengono mandati a nessun servizio di '
                    'intelligenza artificiale.',
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Se disinstalli l\'app, spariscono con lei.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Gap.md),
          Text('Cosa leggiamo', style: theme.textTheme.titleSmall),
          const SizedBox(height: Gap.xs),

          const _Voce(
            icona: Icons.bedtime_outlined,
            titolo: 'Le fasi del sonno',
            testo: 'Per dirti quanto hai dormito davvero e quanto era sonno profondo.',
          ),
          const _Voce(
            icona: Icons.monitor_heart_outlined,
            titolo: 'Variabilità cardiaca (HRV)',
            testo: 'Confrontata solo con la tua media: un valore assoluto non vuol dire niente.',
          ),
          const _Voce(
            icona: Icons.favorite_outline,
            titolo: 'Battito a riposo',
            testo: 'Anche questo letto come scostamento dalla tua media, non come voto.',
          ),

          const SizedBox(height: Gap.md),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(Gap.md),
              child: Text(
                'Non scriviamo niente: chiediamo il permesso di sola lettura. '
                'Puoi revocarlo quando vuoi dalle impostazioni di Health Connect, '
                'e i dati già salvati li cancelli da qui.',
              ),
            ),
          ),

          const SizedBox(height: Gap.lg),

          if (stato.errore != null) ...[
            Text(
              stato.errore!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: Gap.sm),
          ],

          FilledButton.icon(
            style: bottonePieno(altezza: 52),
            onPressed: stato.inCorso
                ? null
                : () => ref.read(healthControllerProvider.notifier).collega(),
            icon: stato.inCorso
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_rounded),
            label: Text(stato.collegato ? 'Aggiorna adesso' : 'Collega Health Connect'),
          ),

          if (stato.collegato) ...[
            const SizedBox(height: Gap.sm),
            Center(
              child: Text(
                stato.ultimaSincronizzazione == null
                    ? 'Collegato'
                    : 'Ultimo aggiornamento: ${stato.ultimaSincronizzazione}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: Gap.md),

            /*
             * 🚨 La cancellazione sta QUI, accanto al collegamento, e non
             * sepolta nelle impostazioni.
             *
             * Con i dati sul telefono il server non puo' cancellarli per conto
             * di nessuno: se questo pulsante non c'e', l'unico modo di
             * liberarsene e' disinstallare l'app. Il diritto alla cancellazione
             * non puo' dipendere dal disinstallare un'applicazione.
             */
            OutlinedButton.icon(
              style: bottonePieno(),
              onPressed: stato.inCorso
                  ? null
                  : () => _confermaCancellazione(context, ref),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Cancella i dati salvati sul telefono'),
            ),
          ],

          const SizedBox(height: Gap.xl),
        ],
      ),
    );
  }

  Future<void> _confermaCancellazione(BuildContext context, WidgetRef ref) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancellare i dati?'),
        content: const Text(
          'Sonno, HRV e battito salvati su questo telefono vengono cancellati. '
          'Non si possono recuperare: non ne esiste nessuna copia altrove.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );

    if (conferma != true) return;

    await ref.read(healthControllerProvider.notifier).cancellaTutto();
  }
}

class _Voce extends StatelessWidget {
  const _Voce({required this.icona, required this.titolo, required this.testo});

  final IconData icona;
  final String titolo;
  final String testo;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icona),
    title: Text(titolo, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(testo),
    isThreeLine: true,
  );
}
