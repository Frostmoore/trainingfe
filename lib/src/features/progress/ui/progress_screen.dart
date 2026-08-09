import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../../auth/auth_controller.dart';
import '../../diary/diary_controller.dart';
import '../../diary/ui/widgets/macro_summary.dart';

/// Il consiglio del giorno, dal backend.
///
/// 🚨 Restituisce `null` quando la funzione è spenta o la quota è finita: in
/// quel caso la schermata **non mostra niente**, invece di un errore. Un
/// consiglio è un di più; farlo sembrare un guasto sarebbe sproporzionato.
final adviceProvider = FutureProvider.autoDispose<String?>((ref) async {
  try {
    final data = await ref.watch(apiClientProvider).get<Map<String, dynamic>?>('/ai/advice');

    return data?['body']?.toString();
  } on Object {
    return null;
  }
});

/// La schermata «Oggi» — A6.5.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utente = ref.watch(authControllerProvider).user;
    final diario = ref.watch(diaryProvider);
    final consiglio = ref.watch(adviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(utente != null ? 'Ciao, ${utente.name.split(' ').first}' : 'Oggi'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(diaryProvider)
            ..invalidate(adviceProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            diario.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(diaryProvider)),
              data: (day) => MacroSummary(day: day),
            ),

            const SizedBox(height: Gap.md),

            consiglio.maybeWhen(
              data: (testo) => testo == null || testo.isEmpty
                  ? const SizedBox.shrink()
                  : Card(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(Gap.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 20),
                            const SizedBox(width: Gap.sm),
                            Expanded(child: Text(testo)),
                          ],
                        ),
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
