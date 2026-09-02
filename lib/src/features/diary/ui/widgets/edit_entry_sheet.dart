import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/diario_locale.dart';
import '../../data/diary_models.dart';
import '../../data/unita_di_misura.dart';
import '../../diary_controller.dart';

/// Modifica di una voce del diario — C15.
///
/// ══ 🚨 L'ANTEPRIMA E IL SALVATAGGIO USANO LA STESSA FUNZIONE — I2.5 ══════
///
/// Qui c'era scritto che *«i macro NON si ricalcolano qui: il ricalcolo lo fa il
/// server, che possiede la tabella unità→grammi»*, e questo foglio teneva una
/// **terza** tabella privata (`_grammiPer`) con dentro solo le unità in cui un
/// grammo è un grammo, per non discordare da lui.
///
/// ⛔ Dopo il trasloco del diario il server non ricalcola più niente. 🚨 E la
/// paura era giusta ma il rimedio no: la difesa contro «due conversioni che
/// divergono» non è tenerne una monca, è averne **una sola**. Adesso l'anteprima
/// e il salvataggio chiamano tutti e due [grammiPerLaQuantita].
///
/// 💡 Il guadagno si vede: prima, cambiando «2 cucchiai» in «3», i campi
/// restavano fermi perché il peso di un cucchiaio lo sapeva solo il server. Ora
/// si aggiornano — e con il peso che l'AI aveva dato a **quell'olio**, non con i
/// 15 g della tabella generica.
///
/// ⚠️ Se invece l'utente **scrive** un macro, quello vince: correggere a mano
/// una stima è il motivo principale per cui si apre questa schermata.
class EditEntrySheet extends ConsumerStatefulWidget {
  const EditEntrySheet({required this.voce, super.key});

  final FoodEntry voce;

  static Future<void> mostra(BuildContext context, FoodEntry voce) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: EditEntrySheet(voce: voce),
        ),
      );

  @override
  ConsumerState<EditEntrySheet> createState() => _EditEntrySheetState();
}

class _EditEntrySheetState extends ConsumerState<EditEntrySheet> {
  /// 💡 **L'elenco è `ordineDelleUnita`**, cioè `FoodUnit::ORDER` portato in
  /// Dart: le stesse tredici unità, e una copia in meno da tenere allineata.
  ///
  /// ⚠️ L'ordine cambia leggermente — prima quelle che si usano davvero, non
  /// l'ordine alfabetico dell'app storica.
  static const _unita = ordineDelleUnita;

  late final _descrizione = TextEditingController(
    text: widget.voce.description,
  );
  late final _qty = TextEditingController(
    text: _pulito(widget.voce.qty ?? widget.voce.grams),
  );
  late final _kcal = TextEditingController(text: _pulito(widget.voce.kcal));
  late final _proteine = TextEditingController(
    text: _pulito(widget.voce.protein),
  );
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

  /// Quanto peserà questa voce con la quantità che si sta scrivendo.
  ///
  /// 🚨 **È la stessa funzione che userà il salvataggio.** Un secondo calcolo
  /// qui, anche identico oggi, sarebbe la cosa che diverge domani: il foglio
  /// mostrerebbe un numero e il diario ne conterrebbe un altro, senza che
  /// niente lo segnali.
  ///
  /// 💡 `null` quando non si sa convertire, e allora non si riscala niente.
  double? get _grammiPrevisti => grammiPerLaQuantita(
    quantita: _valore(_qty),
    unita: _unitaScelta,
    grammiPrima: widget.voce.grams,
    quantitaPrima: widget.voce.qty,
    unitaPrima: widget.voce.unit,
  );

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
  /// ⚠️ **Quello che si salva non cambia**: i macro riscritti da qui NON entrano
  /// in `_toccati`, quindi non viaggiano fra i valori passati, e il ricalcolo
  /// resta di [DiarioLocale.aggiorna]. È un'anteprima, non una decisione — e usa
  /// la stessa proporzione, sugli stessi grammi.
  ///
  /// 🚨 **Un campo corretto a mano non si tocca più.** Chi ha scritto «32» nelle
  /// proteine sta dicendo che ne sa più della stima, e vederselo riscrivere al
  /// carattere successivo sarebbe un campo che si rifiuta di obbedire.
  void _quantitaCambiata() {
    final grammi = _grammiPrevisti;

    // ⛔ Senza un peso o senza valori per 100 g non si riscala niente, e non si
    // inventa: i campi restano come sono, e la riga sotto il modulo lo dice.
    if (grammi == null || grammi <= 0 || !widget.voce.siRicalcola) return;

    final nuovi = widget.voce.riscalataA(grammi);

    setState(() {
      if (!_toccati.contains('kcal')) _kcal.text = _pulito(nuovi.kcal);
      if (!_toccati.contains('protein'))
        _proteine.text = _pulito(nuovi.proteine);
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
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Quantità'),
                    onChanged: (_) => _quantitaCambiata(),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _unita.contains(_unitaScelta)
                        ? _unitaScelta
                        : 'g',
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
                  : _grammiPrevisti == null
                  // ⛔ Resta un caso, ed è quello in cui il peso non si sa:
                  // meglio dirlo che lasciar credere a un ricalcolo che non
                  // avverrà.
                  ? 'Non so quanto pesa una quantità in $_unitaScelta: '
                        'correggi anche calorie e macro.'
                  : 'Calorie e macro si aggiornano mentre scrivi. Quelli che '
                        'correggi a mano restano come li hai messi.',
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
              icon: Icon(
                Icons.delete_outline_rounded,
                color: theme.colorScheme.error,
              ),
              label: Text(
                'Elimina',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoMacro(
    TextEditingController controller,
    String chiave,
    String etichetta,
  ) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: etichetta, isDense: true),
    // Toccarlo significa «questo lo decido io»: da quel momento il valore
    // viaggia nella richiesta e vince sul ricalcolo.
    onChanged: (_) => _toccati.add(chiave),
  );
}
