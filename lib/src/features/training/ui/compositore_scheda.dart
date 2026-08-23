import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/states.dart';
import '../compositore_scheda_controller.dart';
import '../data/scheda_allenamento.dart';
import 'widgets/scelta_muscoli.dart';

/// Comporre una scheda dal telefono — G7.2 (D11).
///
/// ── 🚨 Un giorno alla volta, e non è una semplificazione ─────────────────
///
/// Stessa forma del compositore dei piani alimentari, per la stessa ragione:
/// l'albero intero su 328 px è illeggibile. Si sceglie **un giorno**, si lavora
/// dentro quel giorno, e le alternative sono un foglio che si apre sopra.
///
/// ── ⚠️ Non è `plan_editor_screen.dart`, e le due restano separate ────────
///
/// `PlanEditorScreen` è la scheda che **l'iscritto scrive per sé**: una lista
/// piatta, nessun giorno, nessun «Rif. Allievo», nessuna alternativa. È ancora
/// giusta così, ed estenderla avrebbe voluto dire mettere davanti a chi si
/// scrive tre esercizi un modulo pensato per chi ne prescrive trenta.
///
/// 💡 Quello che le due **condividono** è l'endpoint: `/workout-plans` è lo
/// stesso, e il server distingue da solo. Due rotte per la stessa cosa
/// divergerebbero alla prima modifica.
class CompositoreScheda extends ConsumerStatefulWidget {
  const CompositoreScheda({this.schedaId, super.key});

  /// `null` = scheda nuova.
  final int? schedaId;

  @override
  ConsumerState<CompositoreScheda> createState() => _CompositoreSchedaState();
}

class _CompositoreSchedaState extends ConsumerState<CompositoreScheda> {
  SchedaAllenamento? _scheda;
  int _giornoCorrente = 0;
  bool _salvando = false;
  bool _caricato = false;

  @override
  Widget build(BuildContext context) {
    if (widget.schedaId == null && !_caricato) {
      // Una scheda nuova nasce con **un** giorno e **un** esercizio vuoto:
      // cominciare da zero vorrebbe dire mostrare una schermata vuota a chi ha
      // appena premuto «nuova scheda».
      _scheda = SchedaAllenamento(
        giorni: [
          GiornoDellaScheda(esercizi: [EsercizioDellaScheda()]),
        ],
      );
      _caricato = true;
    }

    if (widget.schedaId != null && !_caricato) {
      final stato = ref.watch(schedaProvider(widget.schedaId!));

      return stato.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          appBar: const IntestazioneApp(),
          body: ErrorState(
            error: ApiClient.unwrapError(e),
            onRetry: () => ref.invalidate(schedaProvider(widget.schedaId!)),
          ),
        ),
        data: (scheda) {
          // ⚠️ Si copia nello stato locale **una volta sola**: da qui in poi il
          // modulo è la fonte di verità, e un `invalidate` del provider non deve
          // buttare via quello che il trainer sta scrivendo.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            setState(() {
              _scheda = scheda;
              _caricato = true;
            });
          });

          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      );
    }

    final scheda = _scheda!;

    return Scaffold(
      appBar: IntestazioneApp(
        titolo: scheda.nuova ? 'Nuova scheda' : scheda.nome,
        azioni: [
          TextButton(
            onPressed: _salvando ? null : _salva,
            child: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Salva'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          _TestaDellaScheda(scheda: scheda, onCambio: () => setState(() {})),

          const SizedBox(height: Gap.lg),

          _SceltaGiorno(
            scheda: scheda,
            corrente: _giornoCorrente,
            onCambio: (i) => setState(() => _giornoCorrente = i),
            onAggiungi: () => setState(() {
              scheda.giorni.add(
                GiornoDellaScheda(esercizi: [EsercizioDellaScheda()]),
              );
              _giornoCorrente = scheda.giorni.length - 1;
            }),
          ),

          const SizedBox(height: Gap.md),

          if (scheda.giorni.isNotEmpty)
            _Giorno(
              // 🚨 `clamp`: togliere l'ultimo giorno lascia `_giornoCorrente`
              // oltre la fine della lista, e senza questo la schermata va in
              // errore invece di mostrare il giorno prima.
              giorno: scheda
                  .giorni[_giornoCorrente.clamp(0, scheda.giorni.length - 1)],
              onCambio: () => setState(() {}),
              onEliminaGiorno: scheda.giorni.length > 1
                  ? () => setState(() {
                      scheda.giorni.removeAt(
                        _giornoCorrente.clamp(0, scheda.giorni.length - 1),
                      );
                      _giornoCorrente = 0;
                    })
                  : null,
            ),

          const SizedBox(height: Gap.xl),
        ],
      ),
    );
  }

  Future<void> _salva() async {
    final scheda = _scheda!;

    if (scheda.nome.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dai un nome alla scheda.')));

      return;
    }

    /*
     * ⚠️ **Una scheda senza un solo esercizio non si salva.**
     *
     * Il server la accetterebbe — `exercises` è facoltativo — e il risultato
     * sarebbe una scheda vuota nell'elenco, che sembra un guasto. 💡 Qui non si
     * sta difendendo il database: si sta evitando che il trainer creda di aver
     * salvato qualcosa che poi non trova.
     */
    if (scheda.quantiEsercizi == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metti almeno un esercizio.')),
      );

      return;
    }

    setState(() => _salvando = true);

    try {
      final salvata = await ref.read(azioniSchedaProvider).salva(scheda);

      if (!mounted) return;

      setState(() {
        // 🚨 Si sostituisce con quella **riletta**: il server riscrive i giorni
        // da zero, quindi gli id di prima non esistono più.
        _scheda = salvata;
        _giornoCorrente = 0;
        _salvando = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Scheda salvata.')));
    } on Object catch (e) {
      if (!mounted) return;

      setState(() => _salvando = false);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ApiClient.unwrapError(e).message)));
    }
  }
}

class _TestaDellaScheda extends StatelessWidget {
  const _TestaDellaScheda({required this.scheda, required this.onCambio});

  final SchedaAllenamento scheda;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: scheda.nome,
          decoration: const InputDecoration(labelText: 'Nome della scheda'),
          onChanged: (v) => scheda.nome = v,
        ),

        const SizedBox(height: Gap.md),

        /*
         * D3 — il promemoria privato.
         *
         * 🚨 **Non entra nella busta cifrata** (R4): è l'etichetta del trainer,
         * e mandarla vorrebbe dire mostrare all'allievo come lo si chiama negli
         * appunti.
         *
         * ⚠️ Il suggerimento alle iniziali non è cortesia: il campo sta **in
         * chiaro sul server**, e da una scheda post-infortunio si capisce cos'è
         * successo a chi la esegue.
         */
        TextFormField(
          initialValue: scheda.rifAllievo,
          decoration: const InputDecoration(
            labelText: 'Rif. Allievo',
            helperText:
                'Un tuo promemoria. Meglio le iniziali: lo vedi solo tu, ma resta sul server.',
            helperMaxLines: 3,
          ),
          onChanged: (v) => scheda.rifAllievo = v,
        ),

        const SizedBox(height: Gap.md),

        TextFormField(
          initialValue: scheda.note,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Note della scheda (facoltative)',
          ),
          onChanged: (v) => scheda.note = v,
        ),
      ],
    );
  }
}

/// La striscia dei giorni: è ciò che rende possibile «un giorno alla volta».
class _SceltaGiorno extends StatelessWidget {
  const _SceltaGiorno({
    required this.scheda,
    required this.corrente,
    required this.onCambio,
    required this.onAggiungi,
  });

  final SchedaAllenamento scheda;
  final int corrente;
  final ValueChanged<int> onCambio;
  final VoidCallback onAggiungi;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < scheda.giorni.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: ChoiceChip(
                selected: i == corrente,
                onSelected: (_) => onCambio(i),
                // 💡 Il nome può essere vuoto: una scheda a un giorno solo non
                // deve mostrare un'intestazione che nessuno ha scritto. Nella
                // striscia serve però un'etichetta, e «Giorno N» è la sola che
                // non inventa niente.
                label: Text(
                  scheda.giorni[i].nome?.trim().isNotEmpty == true
                      ? scheda.giorni[i].nome!
                      : 'Giorno ${i + 1}',
                ),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Giorno'),
            onPressed: onAggiungi,
          ),
        ],
      ),
    );
  }
}

class _Giorno extends StatelessWidget {
  const _Giorno({
    required this.giorno,
    required this.onCambio,
    required this.onEliminaGiorno,
  });

  final GiornoDellaScheda giorno;
  final VoidCallback onCambio;

  /// `null` quando è l'ultimo giorno rimasto: una scheda senza giorni non è
  /// componibile, e un pulsante che porta a quello stato è un pulsante rotto.
  final VoidCallback? onEliminaGiorno;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                key: ValueKey('nome-${giorno.hashCode}'),
                initialValue: giorno.nome,
                decoration: const InputDecoration(
                  labelText: 'Nome del giorno',
                  hintText: 'Lascia vuoto se la scheda ha un giorno solo',
                ),
                onChanged: (v) {
                  giorno.nome = v;
                  onCambio();
                },
              ),
            ),
            if (onEliminaGiorno != null)
              IconButton(
                onPressed: onEliminaGiorno,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Togli il giorno',
              ),
          ],
        ),

        const SizedBox(height: Gap.md),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Esercizi', style: theme.textTheme.titleMedium),
            Text(
              '${giorno.quantiEsercizi}',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: Gap.sm),

        for (final esercizio in giorno.esercizi)
          _Esercizio(
            esercizio: esercizio,
            onCambio: onCambio,
            onElimina: () {
              giorno.esercizi.remove(esercizio);
              onCambio();
            },
          ),

        const SizedBox(height: Gap.sm),

        OutlinedButton.icon(
          onPressed: () {
            giorno.esercizi.add(EsercizioDellaScheda());
            onCambio();
          },
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi esercizio'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ],
    );
  }
}

class _Esercizio extends StatelessWidget {
  const _Esercizio({
    required this.esercizio,
    required this.onCambio,
    required this.onElimina,
  });

  final EsercizioDellaScheda esercizio;
  final VoidCallback onCambio;
  final VoidCallback onElimina;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('n-${esercizio.hashCode}'),
                    initialValue: esercizio.nome,
                    decoration: const InputDecoration(
                      labelText: 'Esercizio',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      esercizio.nome = v;
                      onCambio();
                    },
                  ),
                ),
                IconButton(
                  onPressed: onElimina,
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Togli',
                ),
              ],
            ),

            RigaMuscoli(
              nome: esercizio.nome,
              muscoli: esercizio.muscoli,
              onScelti: (scelti) {
                esercizio.muscoli = scelti;
                onCambio();
              },
            ),

            const SizedBox(height: Gap.sm),

            /*
             * ⚠️ **Due righe da due campi, non una da quattro.**
             *
             * `plan_editor_screen.dart` mette serie/ripetizioni/recupero/kg
             * tutti in fila: a 328 px — la larghezza utile dello Xiaomi del
             * committente — quattro etichette in una riga si accavallano. È la
             * stessa misura su cui è stato trovato il difetto delle tendine del
             * profilo.
             */
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('s-${esercizio.hashCode}'),
                    initialValue: esercizio.serie?.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'serie',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      esercizio.serie = int.tryParse(v.trim());
                      onCambio();
                    },
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    key: ValueKey('r-${esercizio.hashCode}'),
                    initialValue: esercizio.ripetizioni,
                    // 🚨 **Nessun `keyboardType: number` qui**, ed è la
                    // differenza che conta: «8-12», «cedimento», «max» sono
                    // prescrizioni legittime, e una tastiera numerica le
                    // renderebbe impossibili da scrivere.
                    decoration: const InputDecoration(
                      labelText: 'ripetizioni',
                      hintText: '8-12',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      esercizio.ripetizioni = v;
                      onCambio();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.sm),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('rec-${esercizio.hashCode}'),
                    initialValue: esercizio.recuperoSec?.toString(),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'recupero (s)',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      esercizio.recuperoSec = int.tryParse(v.trim());
                      onCambio();
                    },
                  ),
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('kg-${esercizio.hashCode}'),
                    initialValue: esercizio.pesoTarget?.toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'kg',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      // ⚠️ La virgola: su una tastiera italiana è quella che si
                      // digita, e `double.tryParse` non la accetta.
                      esercizio.pesoTarget = double.tryParse(
                        v.trim().replaceAll(',', '.'),
                      );
                      onCambio();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.sm),

            // 💡 Le note dell'esercizio: «fermo un secondo al petto» riguarda la
            // panca, non l'allenamento intero.
            TextFormField(
              key: ValueKey('note-${esercizio.hashCode}'),
              initialValue: esercizio.note,
              decoration: const InputDecoration(
                labelText: 'note',
                isDense: true,
              ),
              onChanged: (v) {
                esercizio.note = v;
                onCambio();
              },
            ),

            const SizedBox(height: Gap.xs),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _apriAlternative(context),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(
                  esercizio.alternative.isEmpty
                      ? 'Alternative'
                      : 'Alternative (${esercizio.alternative.where((a) => !a.vuoto).length})',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.secondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _apriAlternative(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FoglioAlternative(esercizio: esercizio),
    );

    onCambio();
  }
}

/// Le alternative a un esercizio — D10, **al massimo tre**.
///
/// ── 🚨 Un foglio che si apre sopra, e non righe annidate ─────────────────
///
/// È la forma che rende possibile «un giorno alla volta»: annidare le
/// alternative dentro la carta dell'esercizio vorrebbe dire quattro livelli di
/// rientro su 328 px, e a quel punto non si legge più niente.
///
/// ⚠️ **Il limite di tre lo applica anche il server** (`AlMassimoTreAlternative`).
/// Qui si toglie il pulsante quando si arriva a tre: un pulsante che porta a un
/// errore è peggio di un pulsante assente.
class _FoglioAlternative extends StatefulWidget {
  const _FoglioAlternative({required this.esercizio});

  final EsercizioDellaScheda esercizio;

  @override
  State<_FoglioAlternative> createState() => _FoglioAlternativeState();
}

class _FoglioAlternativeState extends State<_FoglioAlternative> {
  /// D2/D10 — lo stesso numero che vive in `AlMassimoTreAlternative` sul server.
  static const massimo = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alternative = widget.esercizio.alternative;

    return Padding(
      padding: EdgeInsets.only(
        left: Gap.md,
        right: Gap.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.md,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.esercizio.nome.trim().isEmpty
                  ? 'Alternative'
                  : 'Invece di ${widget.esercizio.nome}',
              style: theme.textTheme.titleMedium,
            ),

            const SizedBox(height: Gap.xs),

            Text(
              'Chi le sceglie deve trovarci serie e ripetizioni, o non saprebbe cosa fare.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),

            const SizedBox(height: Gap.md),

            if (alternative.isEmpty)
              Text(
                'Nessuna alternativa.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),

            for (final alt in alternative)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        key: ValueKey('an-${alt.hashCode}'),
                        initialValue: alt.nome,
                        decoration: const InputDecoration(
                          labelText: 'Esercizio',
                          isDense: true,
                        ),
                        onChanged: (v) => alt.nome = v,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    SizedBox(
                      width: 56,
                      child: TextFormField(
                        key: ValueKey('as-${alt.hashCode}'),
                        initialValue: alt.serie?.toString(),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'serie',
                          isDense: true,
                        ),
                        onChanged: (v) => alt.serie = int.tryParse(v.trim()),
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    SizedBox(
                      width: 72,
                      child: TextFormField(
                        key: ValueKey('ar-${alt.hashCode}'),
                        initialValue: alt.ripetizioni,
                        decoration: const InputDecoration(
                          labelText: 'rip.',
                          isDense: true,
                        ),
                        onChanged: (v) => alt.ripetizioni = v,
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => alternative.remove(alt)),
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Togli',
                    ),
                  ],
                ),
              ),

            const SizedBox(height: Gap.sm),

            if (alternative.length < massimo)
              OutlinedButton.icon(
                onPressed: () =>
                    setState(() => alternative.add(EsercizioDellaScheda())),
                icon: const Icon(Icons.add),
                label: const Text('Aggiungi alternativa'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              )
            else
              Text(
                'Massimo $massimo: più di così non è una scelta, è un secondo allenamento.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),

            const SizedBox(height: Gap.md),

            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Fatto'),
            ),
          ],
        ),
      ),
    );
  }
}
