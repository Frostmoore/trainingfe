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

  /// Le unità in cui **un grammo è un grammo**, senza sapere che alimento sia.
  ///
  /// 🚨 **Non è la tabella di `FoodUnit` portata in Dart**, ed è la differenza
  /// che rende questo codice lecito. Un chilo è mille grammi per qualunque cosa;
  /// un *cucchiaio* pesa 14 g d'olio e 21 g di miele, e quel numero lo sa solo
  /// il server. Duplicare quella tabella qui vorrebbe dire due conversioni da
  /// tenere allineate — che è ciò che il commento in cima a questo file vieta.
  ///
  /// ⚠️ Su `ml` e compagni si segue la scelta dichiarata di `FoodUnit`: 1 ml = 1 g.
  /// È un'approssimazione, ma è **la stessa** che farà il server, quindi
  /// l'anteprima non può discordare dal risultato.
  static const _grammiPer = {
    'g': 1.0, 'mg': 0.001, 'hg': 100.0, 'kg': 1000.0,
    'ml': 1.0, 'cl': 10.0, 'dl': 100.0, 'l': 1000.0,
  };

  /// La quantità è cambiata: **i macro si riscrivono mentre si digita**.
  ///
  /// ── 🚨 La richiesta, il 12/08/2026 ──────────────────────────────────────
  ///
  /// *«Quando modifico i grammi nella pagina di modifica alimento, i calcoli li
  /// deve fare in tempo reale mentre scrivo.»*
  ///
  /// Prima i campi restavano fermi e sotto c'era scritto che il ricalcolo sarebbe
  /// avvenuto. Vero, ma vuol dire premere «Salva» su una schermata che mostra i
  /// numeri di prima: si conferma un valore che si sa sbagliato, fidandosi.
  ///
  /// ⚠️ **Quello che si manda non cambia**: i macro riscritti da qui NON entrano
  /// in `_toccati`, quindi non viaggiano nella richiesta e il ricalcolo resta del
  /// server. È un'anteprima, non una decisione — e usa la stessa proporzione.
  ///
  /// 🚨 **Un campo corretto a mano non si tocca più.** Chi ha scritto «32» nelle
  /// proteine sta dicendo che ne sa più della stima, e vederselo riscrivere al
  /// carattere successivo sarebbe un campo che si rifiuta di obbedire.
  void _quantitaCambiata() {
    final fattore = _grammiPer[_unitaScelta];
    final q = _valore(_qty);

    // Senza un fattore certo o senza valori per 100 g non si riscala niente: si
    // lascia fare al server, che ha la tabella vera.
    if (fattore == null || q == null || q <= 0 || !widget.voce.siRicalcola) return;

    final nuovi = widget.voce.riscalataA(q * fattore);

    setState(() {
      if (!_toccati.contains('kcal')) _kcal.text = _pulito(nuovi.kcal);
      if (!_toccati.contains('protein')) _proteine.text = _pulito(nuovi.proteine);
      if (!_toccati.contains('carbs')) _carbo.text = _pulito(nuovi.carboidrati);
      if (!_toccati.contains('fat')) _grassi.text = _pulito(nuovi.grassi);
    });
  }

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
                    onChanged: (_) => _quantitaCambiata(),
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
                    onChanged: (v) {
                      // ⚠️ Cambiare unità cambia i grammi quanto cambiare il
                      // numero: da «200 g» a «200 kg» l'anteprima deve seguire.
                      setState(() => _unitaScelta = v ?? 'g');
                      _quantitaCambiata();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.xs),
            Text(
              // 🚨 Si dice **se** il ricalcolo avverrà. Senza valori per 100 g
              // non avviene, e lasciar credere il contrario farebbe salvare
              // una porzione doppia con le calorie di prima.
              !widget.voce.siRicalcola
                  ? 'Questa voce non ha valori per 100 g: cambiando la quantità '
                        'dovrai correggere anche calorie e macro.'
                  : _grammiPer.containsKey(_unitaScelta)
                  ? 'Calorie e macro si aggiornano mentre scrivi. Quelli che '
                        'correggi a mano restano come li hai messi.'
                  // 🚨 Su un\'unità che non è in grammi l\'app NON può riscalare:
                  // quanto pesi un cucchiaio lo sa la tabella del server.
                  : 'Cambiando la quantità in $_unitaScelta, calorie e macro li '
                        'ricalcola il server al salvataggio.',
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
