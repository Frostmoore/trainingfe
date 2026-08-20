import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/states.dart';
import '../data/utente_seguito.dart';
import '../trainer_controller.dart';

/// «I miei utenti» — F5.1 e F6 della Parte B.
///
/// 🚨 **Un trainer si allena anche lui**: questa non è un'app diversa né un
/// secondo accesso. È una sezione in più dentro lo stesso account, raggiunta dal
/// profilo — e chi non segue nessuno non la vede affatto.
class MieiUtentiScreen extends ConsumerWidget {
  const MieiUtentiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stato = ref.watch(mieiUtentiProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('I miei utenti')),
      body: stato.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(mieiUtentiProvider),
        ),
        data: (dati) => _Elenco(dati: dati),
      ),
    );
  }
}

class _Elenco extends ConsumerWidget {
  const _Elenco({required this.dati});

  final MieiUtenti dati;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () => aggiornaTutto(context, ref, () => ref.invalidate(mieiUtentiProvider)),
      child: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          _Posti(posti: dati.posti),
          const SizedBox(height: Gap.md),

          if (dati.utenti.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.group_add_outlined,
                    size: 56,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    'Non segui ancora nessuno',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Invita una persona con un link: vale una volta sola e scade '
                    'dopo una settimana.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...dati.utenti.map((u) => _Riga(utente: u)),

          const SizedBox(height: Gap.lg),
          FilledButton.icon(
            // 🚨 Spento **prima** che qualcuno lo prema: scoprire il limite dopo
            // aver compilato un modulo fa sembrare rotto un vincolo commerciale.
            onPressed: dati.posti.puoInvitare ? () => _invita(context, ref) : null,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Invita una persona'),
          ),

          if (!dati.posti.puoInvitare) ...[
            const SizedBox(height: Gap.sm),
            Text(
              'Hai occupato tutti i posti del tuo piano. Per averne di più serve '
              'un piano superiore.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _invita(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final link = await ref.read(trainerActionsProvider).invita();

      await Clipboard.setData(ClipboardData(text: link));

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Link copiato. Vale una volta sola e scade fra 7 giorni.'),
        ),
      );
    } on Object catch (errore) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    }
  }
}

/// I posti del piano, in cima.
class _Posti extends StatelessWidget {
  const _Posti({required this.posti});

  final PostiDelTrainer posti;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text(
          posti.illimitato
              ? 'Utenti illimitati'
              : '${posti.rimasti ?? 0} posti liberi su ${posti.limite}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        // 💡 Gli inviti ancora validi occupano un posto: senza dirlo, un trainer
        // che ha mandato tre inviti e vede zero utenti non capirebbe perché non
        // può invitarne un quarto.
        subtitle: const Text('Anche gli inviti non ancora accettati occupano un posto.'),
      ),
    );
  }
}

class _Riga extends ConsumerWidget {
  const _Riga({required this.utente});

  final UtenteSeguito utente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: utente.avatarUrl != null
              ? NetworkImage(utente.avatarUrl!)
              : null,
          child: utente.avatarUrl == null
              ? Text(utente.nome.isEmpty ? '?' : utente.nome[0].toUpperCase())
              : null,
        ),
        title: Text(utente.nome),
        subtitle: Text(
          utente.attivo ? utente.email : 'Conversazione chiusa',
          style: utente.attivo
              ? null
              : TextStyle(color: theme.colorScheme.error),
        ),
        trailing: IconButton(
          tooltip: utente.attivo ? 'Chiudi la conversazione' : 'Riapri la conversazione',
          icon: Icon(
            utente.attivo ? Icons.pause_circle_outline : Icons.play_circle_outline,
          ),
          onPressed: () => _cambia(context, ref),
        ),
      ),
    );
  }

  /// 🚨 **Chiede conferma, e la richiesta dice cosa succede davvero.**
  ///
  /// «Disattivare» è una parola che fa pensare a una cancellazione. Qui non si
  /// cancella niente: si chiude il canale dei messaggi, la storia resta, ed è
  /// reversibile. ⚠️ E c'è una cosa che **non** si può fare, e va detta prima:
  /// i piani già ricevuti restano sul telefono di quella persona.
  Future<void> _cambia(BuildContext context, WidgetRef ref) async {
    if (utente.attivo) {
      final conferma = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: Text('Chiudere la conversazione con ${utente.nome}?'),
          content: const Text(
            'Non potrete più scrivervi, e non potrai mandarle piani nuovi.\n\n'
            'I messaggi già scritti restano, e puoi riaprire quando vuoi. '
            'I piani che le hai già mandato restano sul suo telefono.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );

      if (conferma != true) return;
    }

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(trainerActionsProvider).cambiaStato(utente.id);
    } on Object catch (errore) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    }
  }
}
