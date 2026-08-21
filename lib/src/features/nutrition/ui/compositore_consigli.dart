import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../compositore_piano_controller.dart';
import '../data/piano_alimentare.dart';

/// Il compositore dei **Consigli Alimentari** — N19.2.
///
/// ── 🚨 Perché uno nuovo invece di svuotare quello che c'era ────────────────
///
/// `CompositorePiano` sa comporre giorni, pasti, alternative e grammi: 625
/// righe che funzionano. ⚠️ Sventrarle sarebbe stato buttare via il lavoro che
/// serve ancora — al nutrizionista (N22) e all'importazione di un piano vero
/// (N20) — per poi doverlo riscrivere.
///
/// 💡 Quindi quello resta dov'è, dormiente, e questo lo affianca. Il trainer
/// arriva qui; il compositore completo lo raggiunge solo chi ha il titolo.
///
/// ── ⚠️ Cosa NON c'è dentro, e perché ───────────────────────────────────────
///
/// Niente grammi, niente orari, niente giorni. **Non è una semplificazione**:
/// è la differenza fra un consiglio e una dieta, e l'elaborazione di una dieta
/// è riservata a medici, biologi nutrizionisti e dietisti (art. 348 c.p.).
///
/// 🚨 **E il vincolo vero non è qui**: il server rifiuta con 422 una richiesta
/// di tipo `consigli` che porti dei giorni. Questa schermata evita di mandarla;
/// non è lei a impedirlo.
class CompositoreConsigli extends ConsumerStatefulWidget {
  const CompositoreConsigli({this.pianoId, super.key});

  final int? pianoId;

  @override
  ConsumerState<CompositoreConsigli> createState() =>
      _CompositoreConsigliState();
}

class _CompositoreConsigliState extends ConsumerState<CompositoreConsigli> {
  final _nome = TextEditingController();
  final _note = TextEditingController();
  final _nuovo = TextEditingController();

  /// Gli alimenti consigliati, in ordine.
  final _alimenti = <String>[];

  bool _inCorso = false;
  String? _errore;

  @override
  void dispose() {
    for (final c in [_nome, _note, _nuovo]) {
      c.dispose();
    }

    super.dispose();
  }

  void _aggiungi() {
    final testo = _nuovo.text.trim();

    if (testo.isEmpty) return;

    /*
     * 💡 Niente doppioni, e il confronto ignora maiuscole e spazi: chi scrive
     * un elenco a mano rischia di ripetersi, e due «pollo» in fila fanno
     * sembrare sciatto un consiglio che non lo è.
     */
    final gia = _alimenti.any((a) => a.toLowerCase() == testo.toLowerCase());

    setState(() {
      if (!gia) _alimenti.add(testo);
      _nuovo.clear();
    });
  }

  Future<void> _salva() async {
    if (_nome.text.trim().isEmpty) {
      setState(() => _errore = 'Dai un nome a questi consigli.');

      return;
    }

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await ref
          .read(azioniPianoProvider)
          .salva(
            PianoAlimentare(
              id: widget.pianoId,
              nome: _nome.text.trim(),
              // 🚨 Esplicito, anche se è già il default: qui si vede cosa si sta
              // creando senza doverlo andare a cercare nel modello.
              tipo: TipoPiano.consigli,
              note: _testoDegliAlimenti(),
            ),
          );

      if (mounted) context.pop();
    } on Object catch (e) {
      setState(() {
        _errore = ApiClient.unwrapError(e).message;
        _inCorso = false;
      });
    }
  }

  /// 💡 Gli alimenti viaggiano dentro `notes`, uno per riga.
  ///
  /// ⚠️ **Non in `days`**: quello è il campo che il server considera «una
  /// dieta», e riempirlo — anche solo con dei nomi — farebbe respingere la
  /// richiesta con 422. La forma povera non è un ripiego: è il punto.
  String _testoDegliAlimenti() {
    final note = _note.text.trim();
    final elenco = _alimenti.join('\n');

    return note.isEmpty ? elenco : '$elenco\n\n$note';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Consigli alimentari')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          /*
           * 🚨 **Detto in cima, prima che si cominci a scrivere.**
           *
           * ⚠️ Un trainer che scopre a metà di non poter mettere i grammi
           * pensa a un difetto dell'app. Sapendolo prima, sa cosa sta facendo —
           * e perché.
           */
          Card(
            color: tema.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'Qui si scrive un elenco di alimenti: niente quantità, '
                      'niente orari, niente giorni.\n\n'
                      'Un piano alimentare vero lo può fare solo un biologo '
                      'nutrizionista, un dietista o un medico.',
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Gap.lg),

          TextField(
            controller: _nome,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome',
              hintText: 'Es. Cosa tenere in dispensa',
            ),
          ),
          const SizedBox(height: Gap.lg),

          Text('Alimenti consigliati', style: tema.textTheme.titleSmall),
          const SizedBox(height: Gap.sm),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nuovo,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Es. Petto di pollo',
                  ),
                  onSubmitted: (_) => _aggiungi(),
                ),
              ),
              const SizedBox(width: Gap.sm),
              IconButton.filled(
                onPressed: _aggiungi,
                icon: const Icon(Icons.add),
                tooltip: 'Aggiungi',
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),

          if (_alimenti.isEmpty)
            Text(
              'Nessun alimento, per ora.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.outline,
              ),
            )
          else
            ..._alimenti.asMap().entries.map(
              (v) => Dismissible(
                key: ValueKey('${v.key}-${v.value}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => setState(() => _alimenti.remove(v.value)),
                background: ColoredBox(
                  color: tema.colorScheme.errorContainer,
                  child: const Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: EdgeInsets.only(right: Gap.md),
                      child: Icon(Icons.delete_outline),
                    ),
                  ),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, size: 8),
                  title: Text(v.value),
                ),
              ),
            ),

          const SizedBox(height: Gap.lg),
          TextField(
            controller: _note,
            textCapitalization: TextCapitalization.sentences,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Note (facoltative)',
              hintText: 'Es. Varia le verdure, bevi acqua durante il giorno',
            ),
          ),

          if (_errore != null) ...[
            const SizedBox(height: Gap.md),
            Text(
              _errore!,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.error,
              ),
            ),
          ],

          const SizedBox(height: Gap.lg),
          FilledButton.icon(
            onPressed: _inCorso ? null : _salva,
            icon: _inCorso
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Salva'),
          ),
          const SizedBox(height: Gap.sm),
          Text(
            'Poi potrai mandarli a un allievo dalla chat.',
            textAlign: TextAlign.center,
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}
