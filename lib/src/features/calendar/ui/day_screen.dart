import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../calendar_controller.dart';

/// Il dettaglio di un giorno — C13.
class DayScreen extends ConsumerWidget {
  const DayScreen({required this.date, super.key});

  /// `YYYY-MM-DD`.
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giorno = ref.watch(calendarDayProvider(date));

    return Scaffold(
      appBar: AppBar(title: const Text('Giornata')),
      body: giorno.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(calendarDayProvider(date)),
        ),
        data: (d) {
          final voci = ((d['entries'] as List?) ?? const []).cast<Map<String, dynamic>>();
          final sessioni = ((d['sessions'] as List?) ?? const []).cast<Map<String, dynamic>>();
          final bruciate = (d['burned'] as Map?)?.cast<String, dynamic>() ?? const {};

          return ListView(
            padding: const EdgeInsets.all(Gap.md),
            children: [
              Text(
                d['title']?.toString() ?? '',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Gap.md),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Row(
                    children: [
                      _Numero(valore: '${d['kcal'] ?? 0}', etichetta: 'kcal assunte'),
                      _Numero(valore: '${bruciate['kcal'] ?? 0}', etichetta: 'kcal bruciate'),
                      _Numero(valore: '${voci.length}', etichetta: 'alimenti'),
                      _Numero(valore: '${sessioni.length}', etichetta: 'allenamenti'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: Gap.md),
              Text('Pasti', style: Theme.of(context).textTheme.titleSmall),
              if (voci.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Gap.sm),
                  child: Text('Nessun alimento registrato.'),
                )
              else
                for (final v in voci)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(v['description']?.toString() ?? ''),
                    subtitle: Text(
                      'P ${v['protein'] ?? 0} · C ${v['carbs'] ?? 0} · G ${v['fat'] ?? 0}',
                    ),
                    trailing: Text('${v['kcal'] ?? 0} kcal'),
                  ),

              const SizedBox(height: Gap.md),
              Text('Allenamenti', style: Theme.of(context).textTheme.titleSmall),
              if (sessioni.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: Gap.sm),
                  child: Text('Nessun allenamento.'),
                )
              else
                for (final s in sessioni)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(s['plan_name']?.toString() ?? 'Sessione libera'),
                    subtitle: Text(
                      [
                        if (s['is_open'] == true)
                          'in corso'
                        else if (s['duration_min'] != null)
                          '${s['duration_min']} min',
                        '${s['sets_count'] ?? 0} serie',
                      ].join(' · '),
                    ),
                    trailing: s['kcal'] == null ? null : Text('${s['kcal']} kcal'),
                    // go_router, non `Navigator.pushNamed`: con un router
                    // dichiarativo il `Navigator` non ha `onGenerateRoute` e
                    // una rotta con nome lancia sempre.
                    onTap: () => context.push(AppRoutes.player(s['id'] as int)),
                  ),
              const SizedBox(height: Gap.xl),
            ],
          );
        },
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.valore, required this.etichetta});

  final String valore;
  final String etichetta;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          valore,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          etichetta,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
