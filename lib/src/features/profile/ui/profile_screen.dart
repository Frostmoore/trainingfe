import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../../onboarding/branding_controller.dart';
import '../profile_controller.dart';
import 'widgets/weight_sheet.dart';

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

          // ── C8: le voci che prima non c'erano ────────────────────────
          Card(
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, _) {
                    final profilo = ref.watch(profileProvider);

                    return ListTile(
                      leading: const Icon(Icons.tune_rounded),
                      title: const Text('I tuoi dati'),
                      // Il sottotitolo dice a colpo d'occhio se il fabbisogno
                      // esiste: è la domanda che porta qui.
                      subtitle: Text(
                        profilo.maybeWhen(
                          data: (p) => p.isComplete
                              ? 'Fabbisogno: ${p.derived!.targetKcal} kcal al giorno'
                              : 'Da completare per avere il tuo fabbisogno',
                          orElse: () => 'Sesso, età, altezza, obiettivo',
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.push(AppRoutes.profileEdit),
                    );
                  },
                ),
                const Divider(height: 1),
                Consumer(
                  builder: (context, ref, _) {
                    final peso = ref.watch(weightHistoryProvider);

                    return ListTile(
                      leading: const Icon(Icons.monitor_weight_outlined),
                      title: const Text('Registra il peso'),
                      subtitle: Text(
                        peso.maybeWhen(
                          data: (lista) => lista.isEmpty
                              ? 'Nessuna pesata registrata'
                              : 'Ultima: ${lista.last.weightKg.toStringAsFixed(1)} kg',
                          orElse: () => '',
                        ),
                      ),
                      trailing: const Icon(Icons.add_rounded),
                      onTap: () => WeightSheet.mostra(
                        context,
                        iniziale: peso.valueOrNull?.isNotEmpty ?? false
                            ? peso.value!.last.weightKg
                            : null,
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: const Text('Sonno'),
                  subtitle: const Text('Ipnogramma e andamento delle fasi'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.sleep),
                ),
                const Divider(height: 1),
                // La galleria ha lasciato la prima scheda alla dashboard: si
                // guarda ogni tanto, non ogni volta che si apre l'app.
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Foto dei progressi'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push(AppRoutes.progress),
                ),
              ],
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

          const SizedBox(height: Gap.md),

          // ⚠️ In fondo e in colore d'errore, ma **presente**: Apple pretende
          // che l'eliminazione sia raggiungibile dall'app. Nasconderla dietro
          // un contatto via email è motivo di rifiuto.
          TextButton.icon(
            onPressed: () => context.push(AppRoutes.deleteAccount),
            icon: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              'Elimina account',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: Gap.xl),
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
