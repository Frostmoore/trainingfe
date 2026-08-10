import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../profile_controller.dart';

/// Registrare il peso — C8.
///
/// ⚠️ Il peso **non sta nel profilo**: è una serie storica (`body_metrics`), ed
/// è per questo che la dashboard può disegnarne l'andamento. Metterlo fra i
/// campi del profilo avrebbe voluto dire un solo valore, sempre sovrascritto,
/// e nessun grafico possibile.
class WeightSheet extends ConsumerStatefulWidget {
  const WeightSheet({this.iniziale, super.key});

  final double? iniziale;

  static Future<void> mostra(BuildContext context, {double? iniziale}) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: WeightSheet(iniziale: iniziale),
    ),
  );

  @override
  ConsumerState<WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends ConsumerState<WeightSheet> {
  late final _peso = TextEditingController(
    text: widget.iniziale?.toStringAsFixed(1) ?? '',
  );
  final _massaGrassa = TextEditingController();

  bool _inCorso = false;
  String? _errore;

  @override
  void dispose() {
    _peso.dispose();
    _massaGrassa.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    final kg = double.tryParse(_peso.text.trim().replaceAll(',', '.'));

    if (kg == null || kg < 30 || kg > 400) {
      setState(() => _errore = 'Scrivi un peso fra 30 e 400 kg.');

      return;
    }

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await ref
          .read(profileActionsProvider)
          .logWeight(
            kg: kg,
            bodyFatPct: double.tryParse(_massaGrassa.text.trim().replaceAll(',', '.')),
          );

      if (mounted) Navigator.of(context).pop();
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

    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Registra il peso', style: theme.textTheme.titleLarge),
          const SizedBox(height: Gap.md),

          TextField(
            controller: _peso,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Peso',
              suffixText: 'kg',
              prefixIcon: Icon(Icons.monitor_weight_outlined),
            ),
            onSubmitted: (_) => _salva(),
          ),
          const SizedBox(height: Gap.md),

          TextField(
            controller: _massaGrassa,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Massa grassa (facoltativa)',
              suffixText: '%',
              prefixIcon: Icon(Icons.percent_rounded),
            ),
          ),

          // Pesarsi due volte lo stesso giorno è una correzione, non un secondo
          // punto: lo dice qui perché il comportamento sia prevedibile.
          const SizedBox(height: Gap.sm),
          Text(
            'Si registra sul giorno di oggi. Se ti pesi di nuovo, il valore si aggiorna.',
            style: theme.textTheme.bodySmall,
          ),

          if (_errore != null) ...[
            const SizedBox(height: Gap.sm),
            Text(_errore!, style: TextStyle(color: theme.colorScheme.error)),
          ],

          const SizedBox(height: Gap.lg),
          FilledButton(
            onPressed: _inCorso ? null : _salva,
            child: _inCorso
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salva'),
          ),
        ],
      ),
    );
  }
}
