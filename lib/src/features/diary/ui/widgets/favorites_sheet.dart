import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../diary_controller.dart';

/// I preferiti — D2.
///
/// 🚨 **Il pasto intero è la funzione, non il singolo alimento.** Una colazione
/// si ripete uguale per mesi: riscriverne cinque voci ogni mattina è ciò che fa
/// smettere di registrare. Il singolo alimento è comodo, il pasto intero è il
/// motivo per cui il diario si continua a compilare dopo la prima settimana.
class FavoritesSheet extends ConsumerWidget {
  const FavoritesSheet({required this.meal, super.key});

  /// Il pasto in cui finiranno: quello che si stava guardando.
  final String meal;

  static Future<void> mostra(BuildContext context, {required String meal}) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (_, controller) => FavoritesSheet(meal: meal),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferiti = ref.watch(favoritesProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: preferiti.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(Gap.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(Gap.xl),
          child: Text(ApiClient.unwrapError(e).message),
        ),
        data: (elenco) {
          if (elenco.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(Gap.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_outline_rounded, size: 48, color: theme.colorScheme.outline),
                  const SizedBox(height: Gap.md),
                  Text('Nessun preferito', style: theme.textTheme.titleMedium),
                  const SizedBox(height: Gap.sm),
                  // Si dice **come** se ne crea uno: un vuoto che non spiega
                  // come riempirlo resta vuoto.
                  Text(
                    'Tocca la stella accanto a un alimento che hai registrato, '
                    'oppure salva un pasto intero dal menu del pasto.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }

          // Prima i pasti interi: sono quelli che fanno risparmiare di più, e
          // in un elenco misto si perderebbero fra i singoli alimenti.
          final pasti = elenco.where((f) => f.isMeal).toList();
          final alimenti = elenco.where((f) => !f.isMeal).toList();

          return ListView(
            padding: const EdgeInsets.all(Gap.md),
            children: [
              Text(
                'Aggiungi ai preferiti',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: Gap.sm),

              if (pasti.isNotEmpty) ...[
                Text('Pasti completi', style: theme.textTheme.labelLarge),
                for (final f in pasti) _Riga(preferito: f, meal: meal),
                const SizedBox(height: Gap.md),
              ],

              if (alimenti.isNotEmpty) ...[
                Text('Alimenti', style: theme.textTheme.labelLarge),
                for (final f in alimenti) _Riga(preferito: f, meal: meal),
              ],
              const SizedBox(height: Gap.lg),
            ],
          );
        },
      ),
    );
  }
}

class _Riga extends ConsumerStatefulWidget {
  const _Riga({required this.preferito, required this.meal});

  final FoodFavorite preferito;
  final String meal;

  @override
  ConsumerState<_Riga> createState() => _RigaState();
}

class _RigaState extends ConsumerState<_Riga> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.preferito;
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        f.isMeal ? Icons.restaurant_menu_rounded : Icons.star_rounded,
        color: theme.colorScheme.primary,
      ),
      title: Text(f.description, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        [
          if (f.isMeal) '${f.itemsCount} alimenti' else ?f.quantita,
          if (f.kcal != null) '${f.kcal!.round()} kcal',
        ].join(' · '),
      ),
      trailing: _inCorso
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _elimina,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Togli dai preferiti',
                ),
                FilledButton(onPressed: _aggiungi, child: const Text('Aggiungi')),
              ],
            ),
    );
  }

  Future<void> _aggiungi() async {
    setState(() => _inCorso = true);

    try {
      await ref.read(favoriteActionsProvider).add(widget.preferito.id, meal: widget.meal);

      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() => _inCorso = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ApiClient.unwrapError(error).message)));
      }
    }
  }

  Future<void> _elimina() async {
    // Nessuna conferma: togliere un preferito non cancella niente del diario,
    // e richiedere un «sei sicuro?» per un'azione innocua insegna a rispondere
    // sì senza leggere — proprio dove poi servirebbe leggere.
    await ref.read(favoriteActionsProvider).remove(widget.preferito.id);
  }
}
