import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/profile_models.dart';
import '../../profile_controller.dart';

/// Registrare una pesata.
///
/// 🚨 **Il giorno si può scegliere, e non è un vezzo.**
/// Il backend fa UPSERT su `(utente, data)`: pesarsi due volte lo stesso giorno
/// è una **correzione**, non un secondo punto sul grafico — ed è il
/// comportamento giusto, perché la bilancia si guarda spesso due volte di
/// seguito. Ma senza poter scegliere la data, chi si pesa due volte in un
/// pomeriggio si aspetta due punti, non ne trova nessuno in più, e conclude che
/// l'app abbia perso il dato. È successo davvero.
///
/// Quindi: la data si vede, si cambia, e se per quel giorno c'è già una pesata
/// **si dice**, con il valore che verrà sostituito.
class WeightSheet extends ConsumerStatefulWidget {
  const WeightSheet({this.iniziale, super.key});

  final double? iniziale;

  static Future<void> mostra(BuildContext context, {double? iniziale}) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
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

  late DateTime _giorno = _soloData(DateTime.now());

  bool _inCorso = false;
  String? _errore;

  static DateTime _soloData(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void dispose() {
    _peso.dispose();
    _massaGrassa.dispose();
    super.dispose();
  }

  /// La pesata già registrata per il giorno scelto, se c'è.
  WeightEntry? _esistente() {
    final storico = ref.watch(weightHistoryProvider).valueOrNull;

    if (storico == null) return null;

    for (final e in storico) {
      if (_soloData(e.date) == _giorno) return e;
    }

    return null;
  }

  Future<void> _scegliGiorno() async {
    final scelto = await showDatePicker(
      context: context,
      initialDate: _giorno,
      firstDate: DateTime.now().subtract(const Duration(days: 730)),
      // ⚠️ Non si registra una pesata futura: il backend la rifiuta, e
      // permettere di sceglierla vorrebbe dire far compilare un modulo per
      // farlo fallire dopo.
      lastDate: DateTime.now(),
      locale: const Locale('it'),
    );

    if (scelto == null) return;

    setState(() {
      _giorno = _soloData(scelto);

      // Il campo si riempie con quello che c'è già per quel giorno: si sta
      // correggendo, e partire dal valore vecchio è ciò che si vuole.
      final gia = _esistente();

      if (gia != null) _peso.text = gia.weightKg.toStringAsFixed(1);
    });
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
            date: _giorno,
            bodyFatPct: double.tryParse(
              _massaGrassa.text.trim().replaceAll(',', '.'),
            ),
          );

      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      setState(() {
        _errore = ApiClient.unwrapError(error).message;
        _inCorso = false;
      });
    }
  }

  String get _etichettaGiorno {
    final oggi = _soloData(DateTime.now());

    if (_giorno == oggi) return 'Oggi';
    if (_giorno == oggi.subtract(const Duration(days: 1))) return 'Ieri';

    return DateFormat('EEEE d MMMM', 'it').format(_giorno);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gia = _esistente();

    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Registra il peso', style: theme.textTheme.titleLarge),
          const SizedBox(height: Gap.md),

          // Il giorno, visibile e modificabile.
          Row(
            children: [
              Icon(
                Icons.event_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(_etichettaGiorno, style: theme.textTheme.bodyLarge),
              ),
              TextButton(
                onPressed: _scegliGiorno,
                child: const Text('Cambia giorno'),
              ),
            ],
          ),

          const SizedBox(height: Gap.sm),

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

          const SizedBox(height: Gap.md),

          // 🚨 L'avviso che mancava: se per quel giorno c'è già una pesata, si
          // sta **correggendo**, e va detto con il numero — non con una frase
          // generica in grigio in fondo, che nessuno legge.
          if (gia != null)
            Container(
              padding: const EdgeInsets.all(Gap.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(Gap.radiusSm),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'Per questo giorno c\'è già ${gia.weightKg.toStringAsFixed(1)} kg: '
                      'salvando lo correggi, non aggiungi un secondo punto.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Per vedere l\'andamento servono pesate in giorni diversi.',
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
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(gia != null ? 'Correggi' : 'Salva'),
          ),
        ],
      ),
    );
  }
}
