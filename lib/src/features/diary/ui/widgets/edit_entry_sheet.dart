import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/diary_models.dart';
import '../../diary_controller.dart';

/// Modifica di una voce del diario — C15.
///
/// 🚨 **I macro NON si ricalcolano qui.** Cambiando la quantità si manda quella
/// e basta: il ricalcolo lo fa il server, che possiede la tabella unità→grammi e
/// i valori per 100 g. Farlo anche in Dart vorrebbe dire due conversioni da
/// tenere allineate, e il giorno che ne cambia una sola il diario mostrerebbe un
/// totale e il database ne conterrebbe un altro — senza che niente lo segnali.
///
/// ⚠️ Se invece l'utente **scrive** un macro, quello si manda e vince: correggere
/// a mano una stima è il motivo principale per cui si apre questa schermata.
class EditEntrySheet extends ConsumerStatefulWidget {
  const EditEntrySheet({required this.voce, super.key});

  final FoodEntry voce;

  static Future<void> mostra(BuildContext context, FoodEntry voce) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: EditEntrySheet(voce: voce),
    ),
  );

  @override
  ConsumerState<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<EditEntrySheet> {
  /// Le unità che il backend conosce (`FoodUnit::ORDER`), nell'ordine in cui le
  /// mostra l'app storica.
  ///
  /// ⚠️ È un elenco per la tendina, **non** una tabella di conversione: i
  /// fattori restano sul server, dove sono già.
  static const _unita = [
    'g', 'mg', 'hg', 'kg',
    'ml', 'dl', 'cl', 'l',
    'bicchiere', 'cucchiaio', 'tazza', 'cucchiaino', 'scoop',
  ];

  late final _descrizione = TextEditingController(text: widget.voce.description);
  late final _qty = TextEditingController(text: _pulito(widget.voce.qty ?? widget.voce.grams));
  late final _kcal = TextEditingController(text: _pulito(widget.voce.kcal));
  late final _proteine = TextEditingController(text: _pulito(widget.voce.protein));
  late final _carbo = TextEditingController(text: _pulito(widget.voce.carbs));
  late final _grassi = TextEditingController(text: _pulito(widget.voce.fat));

  late String _unitaScelta = widget.voce.unit ?? 'g';

  /// I macro toccati a mano: solo questi si mandano.
  final _toccati = <String>{};

  bool _inCorso = false;
  String? _errore;

  static String _pulito(double? v) {
    if (v == null) return '';

    return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _descrizione.dispose();
    _qty.dispose();
    _kcal.dispose();
    _proteine.dispose();
    _carbo.dispose();
    _grassi.dispose();
    super.dispose();
  }

  double? _valore(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _salva() async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await ref
          .read(diaryActionsProvider)
          .update(
            widget.voce.id,
            description: _descrizione.text.trim(),
            qty: _valore(_qty),
            unit: _unitaScelta,
            // Solo ciò che è stato toccato: mandarli tutti impedirebbe per
            // sempre il ricalcolo lato server.
            kcal: _toccati.contains('kcal') ? _valore(_kcal) : null,
            protein: _toccati.contains('protein') ? _valore(_proteine) : null,
            carbs: _toccati.contains('carbs') ? _valore(_carbo) : null,
            fat: _toccati.contains('fat') ? _valore(_grassi) : null,
          );

      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      setState(() {
        _errore = ApiClient.unwrapError(error).message;
        _inCorso = false;
      });
    }
  }

  Future<void> _elimina() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminare «${widget.voce.description}»?'),
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

    setState(() => _inCorso = true);

    try {
      await ref.read(diaryActionsProvider).delete(widget.voce.id);

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

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Modifica', style: theme.textTheme.titleLarge),
            const SizedBox(height: Gap.md),

            TextField(
              controller: _descrizione,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Alimento'),
            ),
            const SizedBox(height: Gap.md),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _qty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantità'),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unita.contains(_unitaScelta) ? _unitaScelta : 'g',
                    decoration: const InputDecoration(labelText: 'Unità'),
                    items: _unita
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => _unitaScelta = v ?? 'g'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.xs),
            Text(
              // 🚨 Si dice **se** il ricalcolo avverrà. Senza valori per 100 g
              // non avviene, e lasciar credere il contrario farebbe salvare
              // una porzione doppia con le calorie di prima.
              widget.voce.siRicalcola
                  ? 'Cambiando la quantità, calorie e macro si aggiornano da soli.'
                  : 'Questa voce non ha valori per 100 g: cambiando la quantità '
                        'dovrai correggere anche calorie e macro.',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(child: _campoMacro(_kcal, 'kcal', 'kcal')),
                const SizedBox(width: Gap.sm),
                Expanded(child: _campoMacro(_proteine, 'protein', 'Proteine')),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Row(
              children: [
                Expanded(child: _campoMacro(_carbo, 'carbs', 'Carboidrati')),
                const SizedBox(width: Gap.sm),
                Expanded(child: _campoMacro(_grassi, 'fat', 'Grassi')),
              ],
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
                  : const Text('Salva'),
            ),

            const SizedBox(height: Gap.sm),
            // 🚨 L'eliminazione sta QUI, in chiaro.
            //
            // Esiste anche lo scorrimento a sinistra sulla riga, ma un gesto
            // senza nessun segno che lo annunci è una funzione che per la
            // maggior parte delle persone non esiste: e senza un modo visibile
            // di togliere un alimento sbagliato, il diario diventa una lista
            // che si può solo far crescere.
            TextButton.icon(
              onPressed: _inCorso ? null : _elimina,
              icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
              label: Text('Elimina', style: TextStyle(color: theme.colorScheme.error)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoMacro(TextEditingController controller, String chiave, String etichetta) =>
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: etichetta, isDense: true),
        // Toccarlo significa «questo lo decido io»: da quel momento il valore
        // viaggia nella richiesta e vince sul ricalcolo.
        onChanged: (_) => _toccati.add(chiave),
      );
}
