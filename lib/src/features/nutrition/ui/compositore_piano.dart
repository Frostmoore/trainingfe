import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../../auth/auth_controller.dart';
import '../compositore_piano_controller.dart';
import '../data/piano_alimentare.dart';

/// Comporre un piano alimentare dal telefono — G7.4 (D11).
///
/// ── 🚨 Un giorno alla volta, e non è una semplificazione ─────────────────
///
/// `plan_parte_b.md` D6 diceva che i modelli si compongono sul web perché *«un
/// piano a sei pasti con le alternative su un telefono è penoso»*. La
/// preoccupazione **resta vera**: l'albero intero, tutto insieme, su 328 px è
/// illeggibile.
///
/// 💡 Quello che la rende superabile è la forma: si sceglie **un giorno** e si
/// lavora dentro quel giorno. L'albero intero non si vede mai — e non serve
/// vederlo, perché non si scrive mai in due punti insieme.
///
/// ── ⏸ Le alternative da qui NON si scrivono, ed è un debito dichiarato ────
///
/// 🚨 I modelli le reggono e `toJson()` le manda, ma **non c'è nessun campo per
/// aggiungerle**: un piano composto dall'app esce sempre senza alternative, e
/// per metterle bisogna passare dal pannello web.
///
/// ⚠️ Questo commento diceva che «le alternative sono un foglio che si apre
/// sopra». Non era vero, e una promessa in un commento è peggio di un silenzio:
/// chi legge smette di cercare. Il foglio esiste davvero, ma nel **compositore
/// delle schede** (`compositore_scheda.dart`, `_FoglioAlternative`) — è lì che
/// si trova la forma da riusare quando questo debito si chiude. Vedi §7.8 del
/// piano.
///
/// ⚠️ **La misura vera è 328 px**, la larghezza utile dello Xiaomi del
/// committente: è lì che il difetto delle tendine del profilo è stato misurato,
/// ed è lì che va provato ogni widget nuovo.
class CompositorePiano extends ConsumerStatefulWidget {
  const CompositorePiano({this.pianoId, super.key});

  /// `null` = piano nuovo.
  final int? pianoId;

  @override
  ConsumerState<CompositorePiano> createState() => _CompositorePianoState();
}

class _CompositorePianoState extends ConsumerState<CompositorePiano> {
  PianoAlimentare? _piano;
  int _giornoCorrente = 0;
  bool _salvando = false;
  bool _caricato = false;

  @override
  Widget build(BuildContext context) {
    if (widget.pianoId == null && !_caricato) {
      // Un piano nuovo nasce con **un** giorno: cominciare da zero giorni
      // vorrebbe dire mostrare una schermata vuota a chi ha appena premuto
      // «nuovo piano».
      _piano = PianoAlimentare(giorni: [GiornoDelPiano()]);
      _caricato = true;
    }

    if (widget.pianoId != null && !_caricato) {
      final stato = ref.watch(pianoProvider(widget.pianoId!));

      return stato.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorState(
            error: ApiClient.unwrapError(e),
            onRetry: () => ref.invalidate(pianoProvider(widget.pianoId!)),
          ),
        ),
        data: (piano) {
          // ⚠️ Si copia nello stato locale **una volta sola**: da qui in poi il
          // modulo è la fonte di verità, e un `invalidate` del provider non deve
          // buttare via quello che il trainer sta scrivendo.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            setState(() {
              _piano = piano;
              _caricato = true;
            });
          });

          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      );
    }

    final piano = _piano!;

    return Scaffold(
      appBar: AppBar(
        title: Text(piano.nuovo ? 'Nuovo piano' : piano.nome),
        actions: [
          TextButton(
            onPressed: _salvando ? null : _salva,
            child: _salvando
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salva'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          _TestaDelPiano(piano: piano, onCambio: () => setState(() {})),

          const SizedBox(height: Gap.lg),

          _SceltaGiorno(
            piano: piano,
            corrente: _giornoCorrente,
            onCambio: (i) => setState(() => _giornoCorrente = i),
            onAggiungi: () => setState(() {
              piano.giorni.add(GiornoDelPiano());
              _giornoCorrente = piano.giorni.length - 1;
            }),
          ),

          const SizedBox(height: Gap.md),

          if (piano.giorni.isNotEmpty)
            _Giorno(
              giorno: piano.giorni[_giornoCorrente],
              onCambio: () => setState(() {}),
            ),
        ],
      ),
    );
  }

  Future<void> _salva() async {
    final piano = _piano!;

    if (piano.nome.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dai un nome al piano.')),
      );

      return;
    }

    setState(() => _salvando = true);

    try {
      final salvato = await ref.read(azioniPianoProvider).salva(piano);

      if (!mounted) return;

      setState(() {
        _piano = salvato;
        _salvando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Piano salvato.')),
      );
    } on Object catch (e) {
      if (!mounted) return;

      setState(() => _salvando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(e).message)),
      );
    }
  }
}

class _TestaDelPiano extends StatelessWidget {
  const _TestaDelPiano({required this.piano, required this.onCambio});

  final PianoAlimentare piano;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: piano.nome,
          decoration: const InputDecoration(labelText: 'Nome del piano'),
          onChanged: (v) => piano.nome = v,
        ),

        const SizedBox(height: Gap.md),

        /*
         * D3 — il promemoria privato.
         *
         * 🚨 **Non entra nella busta cifrata**: è l'etichetta del trainer, e
         * mandarla vorrebbe dire mostrare all'allievo come lo si chiama negli
         * appunti.
         *
         * ⚠️ Il suggerimento alle iniziali non è cortesia: il campo sta **in
         * chiaro sul server**, e da un piano si capisce molto di chi lo segue.
         */
        TextFormField(
          initialValue: piano.rifAllievo,
          decoration: const InputDecoration(
            labelText: 'Rif. Allievo',
            helperText: 'Un tuo promemoria. Meglio le iniziali: lo vedi solo tu, ma resta sul server.',
            helperMaxLines: 3,
          ),
          onChanged: (v) => piano.rifAllievo = v,
        ),
      ],
    );
  }
}

/// La striscia dei giorni: è ciò che rende possibile «un giorno alla volta».
class _SceltaGiorno extends StatelessWidget {
  const _SceltaGiorno({
    required this.piano,
    required this.corrente,
    required this.onCambio,
    required this.onAggiungi,
  });

  final PianoAlimentare piano;
  final int corrente;
  final ValueChanged<int> onCambio;
  final VoidCallback onAggiungi;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < piano.giorni.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: ChoiceChip(
                selected: i == corrente,
                onSelected: (_) => onCambio(i),
                // 💡 Il nome può essere vuoto: un piano a un giorno solo non
                // deve mostrare un'intestazione che nessuno ha scritto. Nella
                // striscia serve però un'etichetta, e «Giorno N» è la sola che
                // non inventa niente.
                label: Text(
                  piano.giorni[i].nome?.trim().isNotEmpty == true
                      ? piano.giorni[i].nome!
                      : 'Giorno ${i + 1}',
                ),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('Giorno'),
            onPressed: onAggiungi,
          ),
          const SizedBox(width: Gap.sm),
          Text(
            '${piano.kcalMedie.round()} kcal/giorno',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

class _Giorno extends StatelessWidget {
  const _Giorno({required this.giorno, required this.onCambio});

  final GiornoDelPiano giorno;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: ValueKey('nome-${giorno.hashCode}'),
          initialValue: giorno.nome,
          decoration: const InputDecoration(
            labelText: 'Nome del giorno',
            hintText: 'Lascia vuoto se il piano ha un giorno solo',
          ),
          onChanged: (v) {
            giorno.nome = v;
            onCambio();
          },
        ),

        const SizedBox(height: Gap.md),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pasti', style: theme.textTheme.titleMedium),
            Text(
              '${giorno.kcal.round()} kcal',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary),
            ),
          ],
        ),

        const SizedBox(height: Gap.sm),

        for (final pasto in giorno.pasti)
          _Pasto(
            pasto: pasto,
            onCambio: onCambio,
            onElimina: () {
              giorno.pasti.remove(pasto);
              onCambio();
            },
          ),

        const SizedBox(height: Gap.sm),

        OutlinedButton.icon(
          onPressed: () {
            giorno.pasti.add(PastoDelPiano());
            onCambio();
          },
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi pasto'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ],
    );
  }
}

class _Pasto extends ConsumerWidget {
  const _Pasto({required this.pasto, required this.onCambio, required this.onElimina});

  final PastoDelPiano pasto;
  final VoidCallback onCambio;
  final VoidCallback onElimina;

  static const _tipi = {
    'breakfast': 'Colazione',
    'snack_morning': 'Spuntino',
    'lunch': 'Pranzo',
    'snack_afternoon': 'Merenda',
    'dinner': 'Cena',
    'snack_evening': 'Dopocena',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  child: DropdownButtonFormField<String>(
                    initialValue: _tipi.containsKey(pasto.pasto) ? pasto.pasto : 'lunch',
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Pasto', isDense: true),
                    items: [
                      for (final e in _tipi.entries)
                        DropdownMenuItem(
                          value: e.key,
                          // ⚠️ `overflow: ellipsis` e non un testo che sborda:
                          // è la lezione della tendina del profilo, misurata a
                          // 328 px.
                          child: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) pasto.pasto = v;
                      onCambio();
                    },
                  ),
                ),
                IconButton(
                  onPressed: onElimina,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Togli il pasto',
                ),
              ],
            ),

            const SizedBox(height: Gap.sm),

            for (final alimento in pasto.alimenti)
              _Alimento(
                alimento: alimento,
                onCambio: onCambio,
                onElimina: () {
                  pasto.alimenti.remove(alimento);
                  onCambio();
                },
              ),

            const SizedBox(height: Gap.sm),

            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {
                      pasto.alimenti.add(AlimentoDelPiano());
                      onCambio();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('A mano'),
                  ),
                ),
                Expanded(
                  child: _BottoneStima(pasto: pasto, onCambio: onCambio),
                ),
              ],
            ),

            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${pasto.kcal.round()} kcal',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Scrivilo e te lo calcolo» — D13.
///
/// 🚨 **Consuma la quota di chi sta componendo**, non quella dell'allievo. È il
/// motivo per cui il pulsante lo dice: scoprire di aver speso solo quando si
/// finisce è il modo peggiore di scoprirlo.
class _BottoneStima extends ConsumerStatefulWidget {
  const _BottoneStima({required this.pasto, required this.onCambio});

  final PastoDelPiano pasto;
  final VoidCallback onCambio;

  @override
  ConsumerState<_BottoneStima> createState() => _BottoneStimaState();
}

class _BottoneStimaState extends ConsumerState<_BottoneStima> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    // ⚠️ Chi non ha l'AI nel piano non vede un pulsante che darebbe 403: è la
    // stessa regola del foglio del cibo (§27.5 dell'atlante app).
    final aiOk = ref.watch(authControllerProvider).user?.aiAbilitata ?? true;

    if (!aiOk) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: _inCorso ? null : _chiedi,
      icon: _inCorso
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.auto_awesome_outlined, size: 18),
      label: const Text('Stima'),
    );
  }

  Future<void> _chiedi() async {
    final testo = await showDialog<String>(
      context: context,
      builder: (_) => const _ChiediAlimento(),
    );

    if (testo == null || testo.trim().length < 2 || !mounted) return;

    setState(() => _inCorso = true);

    try {
      final proposte = await ref.read(azioniPianoProvider).stima(testo);

      if (!mounted) return;

      // 💡 Le proposte si **aggiungono**, non sostituiscono: il trainer può
      // aver già scritto qualcosa a mano nello stesso pasto.
      widget.pasto.alimenti.addAll(proposte);
      widget.onCambio();
    } on Object catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(e).message)),
      );
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }
}

class _ChiediAlimento extends StatefulWidget {
  const _ChiediAlimento();

  @override
  State<_ChiediAlimento> createState() => _ChiediAlimentoState();
}

class _ChiediAlimentoState extends State<_ChiediAlimento> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cosa prescrivi?'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: '120 g di petto di pollo e 80 g di riso',
          helperText: 'Usa una chiamata AI della tua quota.',
          helperMaxLines: 2,
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Calcola'),
        ),
      ],
    );
  }
}

class _Alimento extends StatelessWidget {
  const _Alimento({
    required this.alimento,
    required this.onCambio,
    required this.onElimina,
  });

  final AlimentoDelPiano alimento;
  final VoidCallback onCambio;
  final VoidCallback onElimina;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  key: ValueKey('d-${alimento.hashCode}'),
                  initialValue: alimento.descrizione,
                  decoration: const InputDecoration(labelText: 'Alimento', isDense: true),
                  onChanged: (v) {
                    alimento.descrizione = v;
                    // 🚨 Toccare un campo riporta l'origine a «a mano»: è così
                    // che il trainer vede a colpo d'occhio cosa ha già
                    // controllato.
                    alimento.origineValori = 'manual';
                    onCambio();
                  },
                ),
              ),
              const SizedBox(width: Gap.sm),
              SizedBox(
                width: 80,
                child: TextFormField(
                  key: ValueKey('k-${alimento.hashCode}'),
                  initialValue: alimento.kcal?.round().toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'kcal', isDense: true),
                  onChanged: (v) {
                    alimento.kcal = double.tryParse(v);
                    alimento.origineValori = 'manual';
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
          if (alimento.dallAi)
            Padding(
              padding: const EdgeInsets.only(left: Gap.xs),
              child: Text(
                'valori proposti dall\'AI',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ),
        ],
      ),
    );
  }
}
