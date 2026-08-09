import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../onboarding/branding_controller.dart';

/// Il profilo — A8.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utente = ref.watch(authControllerProvider).user;
    final palestra = ref.watch(brandingControllerProvider).branding;

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: palestra.primary,
                    child: Text(
                      utente?.initials ?? '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          utente?.name ?? '—',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          utente?.email ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Gap.md),

          Card(
            child: ListTile(
              leading: const Icon(Icons.storefront_outlined),
              title: const Text('La tua palestra'),
              subtitle: Text(palestra.name),
            ),
          ),

          const SizedBox(height: Gap.lg),

          OutlinedButton.icon(
            onPressed: () => _esci(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Esci'),
          ),
        ],
      ),
    );
  }

  /// 🚨 La conferma non è cortesia: uscire cancella il token, e rientrare
  /// richiede la password. Un tocco accidentale sull'ultima voce di un elenco
  /// non deve costare all'utente il ritrovarsi fuori.
  Future<void> _esci(BuildContext context, WidgetRef ref) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Uscire?'),
        content: const Text('Dovrai reinserire la password per rientrare.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Esci'),
          ),
        ],
      ),
    );

    if (conferma ?? false) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}
