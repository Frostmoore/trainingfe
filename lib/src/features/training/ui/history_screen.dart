import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/foto_protetta.dart';
import '../../../core/ui/states.dart';
import '../data/session_models.dart';
import '../session_controller.dart';

/// Lo storico degli allenamenti — C10.
///
/// Raggruppato **per settimana** come nell'app storica: la domanda che ci si
/// fa guardandolo è «quante volte mi sono allenato questa settimana», e un
/// elenco piatto di date costringe a contarle a mano.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Storico allenamenti')),
    body: const StoricoAllenamenti(),
  );
}

/// Lo storico **senza Scaffold**, per poterlo mettere dentro un'altra schermata.
///
/// ⚠️ Da G6 vive dentro la sezione Allenamento, sotto il selettore
/// Storico/Schede. `HistoryScreen` resta come rotta a sé perché ci si arriva
/// anche dalla scheda «Allenamento» del riepilogo di oggi, dove una schermata
/// propria con il suo titolo è la cosa giusta.
class StoricoAllenamenti extends ConsumerWidget {
  const StoricoAllenamenti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessioni = ref.watch(sessionsProvider);

    return sessioni.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(sessionsProvider),
        ),
        data: (lista) => lista.isEmpty
            ? const EmptyState(
                icon: Icons.fitness_center_rounded,
                title: 'Nessun allenamento',
                message: 'Quando ne registri uno lo ritrovi qui, settimana per settimana.',
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(sessionsProvider),
                child: _PerSettimana(sessioni: lista),
              ),
    );
  }
}

class _PerSettimana extends StatelessWidget {
  const _PerSettimana({required this.sessioni});

  final List<WorkoutSession> sessioni;

  /// Il lunedì della settimana di una data.
  static DateTime _lunedi(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final gruppi = <DateTime, List<WorkoutSession>>{};

    for (final s in sessioni) {
      gruppi.putIfAbsent(_lunedi(s.startedAt), () => []).add(s);
    }

    final settimane = gruppi.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(Gap.md),
      itemCount: settimane.length,
      itemBuilder: (context, i) {
        final inizio = settimane[i];
        final fine = inizio.add(const Duration(days: 6));
        final delle = gruppi[inizio]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.sm),
              child: Text(
                '${DateFormat('d MMM', 'it').format(inizio)} – '
                '${DateFormat('d MMM y', 'it').format(fine)}'
                '   ·   ${delle.length} ${delle.length == 1 ? 'seduta' : 'sedute'}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final s in delle) _CardSessione(sessione: s),
          ],
        );
      },
    );
  }
}

class _CardSessione extends ConsumerWidget {
  const _CardSessione({required this.sessione});

  final WorkoutSession sessione;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final foto = sessione.photos.isEmpty ? null : sessione.photos.first;

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ListTile(
        // La miniatura è ciò che rende lo storico leggibile a colpo d'occhio:
        // per questo il backend la manda già nell'elenco (C5).
        leading: SizedBox(
          width: 52,
          height: 52,
          child: foto == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(Gap.radiusSm),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(Gap.radiusSm),
                  // 🚨 `FotoProtetta`: qui non c'era **nessuna** intestazione,
                  // quindi la miniatura prendeva 401 e non si e' mai vista.
                  child: FotoProtetta(url: foto.url),
                ),
        ),
        title: Text(
          sessione.titolo,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            DateFormat('EEE d/MM · HH:mm', 'it').format(sessione.startedAt),
            if (sessione.isOpen)
              'in corso'
            else if (sessione.durationMinutes != null)
              '${sessione.durationMinutes} min',
            if (sessione.kcal != null) '${sessione.kcal} kcal (${sessione.etichettaKcal})',
          ].join(' · '),
        ),
        trailing: sessione.isOpen
            ? FilledButton(
                onPressed: () => _apri(context),
                child: const Text('Riprendi'),
              )
            : IconButton(
                onPressed: () => _correggiKcal(context, ref),
                icon: const Icon(Icons.local_fire_department_outlined),
                tooltip: 'Correggi le calorie',
              ),
        onTap: () => _apri(context),
      ),
    );
  }

  /// 🚨 **Una seduta conclusa si GUARDA, non si riapre.**
  ///
  /// Toccando una riga dello storico si finiva nel player: una schermata che
  /// tiene lo schermo acceso, fa partire i recuperi e invita a registrare
  /// serie — su un allenamento di tre giorni fa. Non ha senso, e il rischio è
  /// di sporcare una seduta chiusa con dati di oggi.
  ///
  /// Il player resta per quella **ancora aperta**: lì «riprendi» è esattamente
  /// ciò che si vuole, ed è il pulsante che la riga mostra al suo posto.
  ///
  /// ⚠️ `context.push` di go_router, **non** `Navigator.pushNamed`: il
  /// `Navigator` di un'app con go_router non ha nessun `onGenerateRoute`, e una
  /// rotta con nome lancia sempre.
  void _apri(BuildContext context) => context.push(
    sessione.isOpen
        ? AppRoutes.player(sessione.id)
        : AppRoutes.riepilogo(sessione.id),
  );

  /// Correzione manuale delle calorie.
  ///
  /// ⚠️ Svuotare il campo **rimette la stima**, non azzera: è la differenza fra
  /// «non lo so» e «oggi ho bruciato zero», e il backend la rispetta.
  Future<void> _correggiKcal(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: sessione.kcalSource == 'manual' ? sessione.kcal?.toString() ?? '' : '',
    );

    final valore = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calorie bruciate'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'kcal',
            helperText: 'Vuoto = usa la stima (${sessione.kcal ?? 0})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (valore == null) return;

    await ref
        .read(sessionActionsProvider)
        .setKcal(sessione.id, valore.isEmpty ? null : int.tryParse(valore));
  }
}
