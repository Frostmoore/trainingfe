import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../profile_controller.dart';

/// Eliminazione dell'account — C6 lato app.
///
/// 🚨 **Apple la pretende** per ogni app che permette di registrarsi: dev'essere
/// raggiungibile dall'app stessa, senza scrivere a nessuno e senza passare da un
/// sito. Senza, la pubblicazione viene rifiutata.
///
/// ⚠️ **L'elenco di cosa sparisce arriva dal server**, non è scritto qui: una
/// lista scritta nell'app diventa falsa il giorno che il server cambia
/// politica, e nessuno se ne accorge finché qualcuno non si lamenta di aver
/// perso qualcosa che credeva salvo.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _password = TextEditingController();

  bool _inCorso = false;
  String? _errore;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _elimina() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminare davvero l\'account?'),
        content: const Text(
          'I tuoi dati verranno cancellati e non sarà possibile recuperarli.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (conferma != true) return;

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await ref.read(profileActionsProvider).deleteAccount(_password.text);
      // Il router porta fuori da solo: reagisce al cambio di stato.
    } on Object catch (error) {
      setState(() {
        _errore = ApiClient.unwrapError(error).message;
        _inCorso = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Elimina account'),
      body: FutureBuilder<Map<String, dynamic>>(
        future: ref.read(profileActionsProvider).deletionPreview(),
        builder: (context, snapshot) {
          final dati = snapshot.data;
          final cancellati = ((dati?['deleted'] as List?) ?? const [])
              .cast<String>();
          final conservati = ((dati?['kept'] as List?) ?? const [])
              .cast<String>();

          return ListView(
            padding: const EdgeInsets.all(Gap.md),
            children: [
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Text(
                    'Questa operazione non si può annullare.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(Gap.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),

              if (cancellati.isNotEmpty) ...[
                const SizedBox(height: Gap.md),
                Text('Verranno cancellati', style: theme.textTheme.titleMedium),
                for (final riga in cancellati)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: Text(riga),
                  ),
              ],

              if (conservati.isNotEmpty) ...[
                const SizedBox(height: Gap.md),
                Text('Resteranno', style: theme.textTheme.titleMedium),
                for (final riga in conservati)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.info_outline_rounded),
                    title: Text(riga),
                  ),
              ],

              const SizedBox(height: Gap.lg),
              // La password si richiede perché un telefono sbloccato lasciato
              // sul tavolo non deve bastare a compiere l'unica azione
              // irreversibile dell'app.
              TextField(
                controller: _password,
                obscureText: true,
                // Senza il `setState`, il pulsante resterebbe disabilitato
                // anche dopo aver scritto la password: la sua condizione
                // dipende dal testo, e il testo cambia senza ricostruire.
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Conferma con la tua password',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),

              if (_errore != null) ...[
                const SizedBox(height: Gap.sm),
                Text(
                  _errore!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],

              const SizedBox(height: Gap.lg),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                onPressed: _inCorso || _password.text.isEmpty ? null : _elimina,
                child: _inCorso
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Elimina definitivamente'),
              ),
              const SizedBox(height: Gap.xl),
            ],
          );
        },
      ),
    );
  }
}
