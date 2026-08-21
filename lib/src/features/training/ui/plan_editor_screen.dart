import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../training_controller.dart';

/// L'editor delle schede — C11.
///
/// 🚨 Ci si arriva **solo per le schede proprie**: quelle del trainer hanno
/// `editable = false` e l'app non mostra il pulsante. Il server rifiuterebbe
/// comunque con `plan_not_editable`, ma un pulsante che porta a un errore è
/// peggio di un pulsante assente.
class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({this.planId, super.key});

  /// `null` = scheda nuova.
  final int? planId;

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  final _nome = TextEditingController();
  final _note = TextEditingController();
  final _righe = <_RigaEditor>[];

  bool _pronto = false;
  bool _inCorso = false;
  String? _errore;

  @override
  void initState() {
    super.initState();

    if (widget.planId == null) {
      _righe.add(_RigaEditor());
      _pronto = true;
    } else {
      _carica();
    }
  }

  @override
  void dispose() {
    _nome.dispose();
    _note.dispose();

    for (final r in _righe) {
      r.dispose();
    }

    super.dispose();
  }

  Future<void> _carica() async {
    try {
      final piano = await ref.read(planDetailProvider(widget.planId!).future);

      _nome.text = piano.name;
      _note.text = piano.notes ?? '';

      for (final e in piano.exercises) {
        _righe.add(
          _RigaEditor(
            nome: e.name,
            serie: _serieDa(e.prescription),
            reps: _repsDa(e.prescription),
            riposo: e.restSec,
            peso: e.targetWeight,
            note: e.notes,
          ),
        );
      }

      if (_righe.isEmpty) _righe.add(_RigaEditor());
    } on Object catch (error) {
      _errore = ApiClient.unwrapError(error).message;
    } finally {
      if (mounted) setState(() => _pronto = true);
    }
  }

  static int? _serieDa(String prescrizione) =>
      int.tryParse(prescrizione.split('×').first.trim());

  static String? _repsDa(String prescrizione) {
    final parti = prescrizione.split('×');

    return parti.length > 1 ? parti.last.trim() : null;
  }

  Future<void> _salva() async {
    if (_nome.text.trim().isEmpty) {
      setState(() => _errore = 'Dai un nome alla scheda.');

      return;
    }

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    // Le righe senza nome si scartano qui: l'editor ne tiene volentieri una
    // vuota in fondo, pronta da compilare, e non deve bloccare il salvataggio.
    final esercizi = _righe
        .where((r) => r.nome.text.trim().isNotEmpty)
        .map((r) => r.toJson())
        .toList();

    try {
      final azioni = ref.read(planActionsProvider);

      if (widget.planId == null) {
        await azioni.create(
          name: _nome.text.trim(),
          notes: _note.text.trim().isEmpty ? null : _note.text.trim(),
          exercises: esercizi,
        );
      } else {
        await azioni.update(
          id: widget.planId!,
          name: _nome.text.trim(),
          notes: _note.text.trim().isEmpty ? null : _note.text.trim(),
          exercises: esercizi,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (error) {
      setState(() {
        _errore = ApiClient.unwrapError(error).message;
        _inCorso = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_pronto) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: IntestazioneApp(
        titolo: widget.planId == null ? 'Nuova scheda' : 'Modifica scheda',
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          TextField(
            controller: _nome,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'es. Full body A',
            ),
          ),
          const SizedBox(height: Gap.md),
          TextField(
            controller: _note,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Note (facoltative)'),
          ),

          const SizedBox(height: Gap.lg),
          Text('Esercizi', style: theme.textTheme.titleMedium),
          const SizedBox(height: Gap.sm),

          // `ReorderableListView` dentro una `ListView` richiede
          // `shrinkWrap`: l'ordine degli esercizi è parte della prescrizione,
          // non una casualità, quindi dev'essere modificabile.
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            // ⚠️ `onReorderItem` e non `onReorder`: il secondo è deprecato
            // proprio perché costringeva a correggere a mano l'indice
            // (`a > da ? a - 1 : a`), e quella correzione dimenticata sposta
            // l'esercizio di una posizione sbagliata solo trascinando verso il
            // basso — un difetto che si nota tardi.
            onReorderItem: (da, a) =>
                setState(() => _righe.insert(a, _righe.removeAt(da))),
            children: [
              for (var i = 0; i < _righe.length; i++)
                _CardRiga(
                  key: ValueKey(_righe[i]),
                  indice: i,
                  riga: _righe[i],
                  onRimuovi: () => setState(() {
                    _righe.removeAt(i).dispose();
                    if (_righe.isEmpty) _righe.add(_RigaEditor());
                  }),
                ),
            ],
          ),

          OutlinedButton.icon(
            onPressed: () => setState(() => _righe.add(_RigaEditor())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Aggiungi esercizio'),
          ),

          if (_errore != null) ...[
            const SizedBox(height: Gap.md),
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
                : const Text('Salva scheda'),
          ),
          const SizedBox(height: Gap.xl),
        ],
      ),
    );
  }
}

/// Lo stato di una riga dell'editor.
class _RigaEditor {
  _RigaEditor({
    String? nome,
    int? serie,
    String? reps,
    int? riposo,
    double? peso,
    String? note,
  }) : nome = TextEditingController(text: nome ?? ''),
       serie = TextEditingController(text: (serie ?? 3).toString()),
       // 🚨 Le ripetizioni sono una STRINGA: «8-12», «cedimento», «max»,
       // «10+10» sono prescrizioni legittime. Un campo numerico qui
       // renderebbe impossibile scrivere metà delle schede vere.
       reps = TextEditingController(text: reps ?? '8-12'),
       riposo = TextEditingController(text: (riposo ?? 90).toString()),
       peso = TextEditingController(text: peso?.toString() ?? ''),
       note = TextEditingController(text: note ?? '');

  final TextEditingController nome;
  final TextEditingController serie;
  final TextEditingController reps;
  final TextEditingController riposo;
  final TextEditingController peso;
  final TextEditingController note;

  Map<String, dynamic> toJson() => {
    'name': nome.text.trim(),
    'sets': int.tryParse(serie.text.trim()),
    'reps': reps.text.trim().isEmpty ? null : reps.text.trim(),
    'rest_sec': int.tryParse(riposo.text.trim()),
    'target_weight': double.tryParse(peso.text.trim().replaceAll(',', '.')),
    'notes': note.text.trim().isEmpty ? null : note.text.trim(),
  };

  void dispose() {
    nome.dispose();
    serie.dispose();
    reps.dispose();
    riposo.dispose();
    peso.dispose();
    note.dispose();
  }
}

class _CardRiga extends StatelessWidget {
  const _CardRiga({
    required this.indice,
    required this.riga,
    required this.onRimuovi,
    super.key,
  });

  final int indice;
  final _RigaEditor riga;
  final VoidCallback onRimuovi;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: Gap.sm),
    child: Padding(
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: indice,
                child: const Padding(
                  padding: EdgeInsets.only(right: Gap.sm),
                  child: Icon(Icons.drag_handle_rounded),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: riga.nome,
                  decoration: const InputDecoration(
                    hintText: 'Nome esercizio',
                    isDense: true,
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: onRimuovi,
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: riga.serie,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'serie',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: riga.reps,
                  decoration: const InputDecoration(
                    labelText: 'ripetizioni',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: TextField(
                  controller: riga.riposo,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'rec. s',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: TextField(
                  controller: riga.peso,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'kg',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          TextField(
            controller: riga.note,
            decoration: const InputDecoration(labelText: 'note', isDense: true),
          ),
        ],
      ),
    ),
  );
}
