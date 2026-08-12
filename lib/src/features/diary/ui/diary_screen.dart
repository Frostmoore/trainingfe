import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../data/diary_models.dart';
import '../diary_controller.dart';
import 'widgets/add_food_sheet.dart';
import 'widgets/edit_entry_sheet.dart';
import 'widgets/favorites_sheet.dart';
import 'widgets/macro_summary.dart';

/// Il diario del giorno — A4.1.
class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giorno = ref.watch(selectedDateProvider);
    final diario = ref.watch(diaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diario'),
        actions: [
          IconButton(
            onPressed: () => _scegliData(context, ref, giorno),
            icon: const Icon(Icons.calendar_today_rounded),
            tooltip: 'Cambia giorno',
          ),
          // C13 — il mese intero. Sta qui perché la domanda «come è andata la
          // settimana» nasce guardando la giornata, non da un'altra sezione.
          IconButton(
            onPressed: () => context.push(AppRoutes.calendar),
            icon: const Icon(Icons.calendar_month_rounded),
            tooltip: 'Calendario',
          ),
        ],
        bottom: _BarraGiorno(giorno: giorno, ref: ref),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddFoodSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      body: diario.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(diaryProvider)),
        data: (day) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(diaryProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 96),
            children: [
              MacroSummary(day: day),
              const SizedBox(height: Gap.md),
              for (final pasto in day.meals) _Pasto(pasto: pasto),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scegliData(BuildContext context, WidgetRef ref, DateTime attuale) async {
    final scelta = await showDatePicker(
      context: context,
      initialDate: attuale,
      // Il diario non si compila in anticipo: non si sa cosa si mangerà.
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('it'),
    );

    if (scelta != null) {
      ref.read(selectedDateProvider.notifier).state = scelta;
    }
  }
}

/// La riga con «ieri / oggi / domani»: cambiare giorno è il gesto più frequente
/// del diario, e farlo passare da un calendario a ogni volta è troppo attrito.
class _BarraGiorno extends StatelessWidget implements PreferredSizeWidget {
  const _BarraGiorno({required this.giorno, required this.ref});

  final DateTime giorno;
  final WidgetRef ref;

  @override
  Size get preferredSize => const Size.fromHeight(48);

  @override
  Widget build(BuildContext context) {
    final oggi = DateTime.now();
    final isOggi = DateUtils.isSameDay(giorno, oggi);

    return SizedBox(
      height: 48,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => ref.read(selectedDateProvider.notifier).state =
                giorno.subtract(const Duration(days: 1)),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          SizedBox(
            width: 180,
            child: Text(
              isOggi ? 'Oggi' : DateFormat('EEEE d MMMM', 'it').format(giorno),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            // Disabilitato su oggi: in avanti non c'è niente da vedere.
            onPressed: isOggi
                ? null
                : () => ref.read(selectedDateProvider.notifier).state =
                      giorno.add(const Duration(days: 1)),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _Pasto extends ConsumerWidget {
  const _Pasto({required this.pasto});

  final DiaryMeal pasto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    /*
     * 🚨 **Le voci scorse via escono dalla lista SUBITO.**
     *
     * `Dismissible` pretende che l'elemento sparisca nello stesso frame del
     * gesto; aspettare la risposta del server produce
     * *«a dismissed Dismissible widget is still part of the tree»* — il
     * rettangolo rosso che compariva mentre la cancellazione funzionava.
     *
     * ⚠️ Il filtro sta **qui e non dentro `_Voce`**: un widget non può togliersi
     * dalla lista da solo, e nasconderlo con `Visibility` lascerebbe comunque
     * l'elemento nell'albero — cioè esattamente ciò di cui Flutter si lamenta.
     */
    final inUscita = ref.watch(vociInUscitaProvider);
    final visibili = pasto.entries.where((v) => !inUscita.contains(v.id)).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      pasto.label,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${pasto.kcal.round()} kcal',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  // D2 — «salva questo pasto fra i preferiti». È la funzione
                  // che fa risparmiare davvero: una colazione si ripete uguale
                  // per mesi, e riscriverne cinque voci ogni mattina è ciò che
                  // fa smettere di registrare.
                  if (pasto.entries.isNotEmpty)
                    IconButton(
                      onPressed: () => _salvaPasto(context, ref),
                      icon: const Icon(Icons.bookmark_add_outlined, size: 20),
                      tooltip: 'Salva questo pasto fra i preferiti',
                    ),
                ],
              ),
            ),

            if (visibili.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
                child: Text(
                  'Niente ancora.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final voce in visibili) _Voce(voce: voce),

            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => AddFoodSheet.show(context, meal: pasto.meal),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text('Aggiungi a ${pasto.label.toLowerCase()}'),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => FavoritesSheet.mostra(context, meal: pasto.meal),
                  icon: const Icon(Icons.star_outline_rounded, size: 18),
                  label: const Text('Preferiti'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

extension on _Pasto {
  /// Salva l'intero pasto del giorno che si sta guardando.
  ///
  /// Il nome si propone («Colazione 10/08») ma si può cambiare: «la mia
  /// colazione» dice molto di più di una data, e un preferito che non si
  /// riconosce dal nome non viene riusato.
  Future<void> _salvaPasto(BuildContext context, WidgetRef ref) async {
    final giorno = ref.read(selectedDateProvider);
    final controller = TextEditingController(
      text: '${pasto.label} ${DateFormat('d/MM', 'it').format(giorno)}',
    );

    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Salva il pasto fra i preferiti'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Nome del preferito'),
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

    if (nome == null || nome.isEmpty || !context.mounted) return;

    try {
      await ref
          .read(favoriteActionsProvider)
          .saveMeal(meal: pasto.meal, description: nome);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('«$nome» salvato fra i preferiti')));
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiClient.unwrapError(error).message)));
      }
    }
  }
}

class _Voce extends ConsumerWidget {
  const _Voce({required this.voce});

  final FoodEntry voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(voce.id),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: theme.colorScheme.errorContainer,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: Gap.lg),
            child: Icon(Icons.delete_outline_rounded),
          ),
        ),
      ),
      // ⚠️ `deleteSubito` toglie la riga **prima** di chiamare il server, e la
      // rimette se la chiamata fallisce. Vedi `vociInUscitaProvider`.
      onDismissed: (_) async {
        final messaggi = ScaffoldMessenger.of(context);

        try {
          await ref.read(diaryActionsProvider).deleteSubito(voce.id);
        } on Object catch (error) {
          messaggi.showSnackBar(
            SnackBar(content: Text(ApiClient.unwrapError(error).message)),
          );
        }
      },
      child: ListTile(
        dense: true,
        // C15 — toccare una voce la apre in modifica. È il gesto che ci si
        // aspetta, e senza restava l'unico modo per correggere una stima
        // sbagliata: cancellarla e riscriverla.
        onTap: () => EditEntrySheet.mostra(context, voce),
        title: Text(voce.description),
        subtitle: Text(voce.quantita),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              voce.kcal != null ? '${voce.kcal!.round()} kcal' : '—',
              style: theme.textTheme.labelMedium,
            ),
            // D2 — la stella salva **questo alimento** fra i preferiti, con
            // quantità e macro già dentro. Si parte da una voce esistente e non
            // da un modulo vuoto: chi ha appena registrato qualcosa di buono
            // vuole salvarlo con un tocco, non riscriverlo.
            IconButton(
              onPressed: () => _salvaPreferito(context, ref),
              icon: const Icon(Icons.star_outline_rounded, size: 18),
              tooltip: 'Salva fra i preferiti',
              visualDensity: VisualDensity.compact,
            ),
            // 🚨 Eliminare deve essere **visibile**. Lo scorrimento a sinistra
            // resta come scorciatoia, ma un gesto che niente annuncia è una
            // funzione che per la maggior parte delle persone non esiste — e
            // senza, il diario è una lista che si può solo far crescere.
            IconButton(
              onPressed: () => _elimina(context, ref),
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Elimina',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        // L'icona dice da dove viene la voce: serve a capire, guardando lo
        // storico, quali stime sono dell'AI quando un totale non torna.
        leading: Icon(
          switch (voce.source) {
            'ai_text' => Icons.auto_awesome_outlined,
            'ai_photo' => Icons.photo_camera_outlined,
            'favorite' => Icons.star_outline_rounded,
            'plan' => Icons.assignment_outlined,
            _ => Icons.edit_outlined,
          },
          size: 18,
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }

  Future<void> _elimina(BuildContext context, WidgetRef ref) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminare «${voce.description}»?'),
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

    if (conferma == true) {
      await ref.read(diaryActionsProvider).delete(voce.id);
    }
  }

  Future<void> _salvaPreferito(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(diaryActionsProvider).favorite(voce.id);
      ref.invalidate(favoritesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«${voce.description}» salvato fra i preferiti')),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiClient.unwrapError(error).message)));
      }
    }
  }
}
