import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/states.dart';
import '../../auth/auth_controller.dart';
import '../../import/data/importazione_da_documento.dart';
import '../../import/data/origine_della_bozza.dart';
import '../../import/data/salva_la_bozza.dart';
import '../../import/ui/barra_del_documento.dart';
import '../../import/ui/cappello_della_revisione.dart';
import '../compositore_scheda_controller.dart';
import '../data/scheda_allenamento.dart';
import 'widgets/campo_esercizio.dart';
import 'widgets/righe_delle_serie.dart';
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
  const CompositoreScheda({
    this.schedaId,
    this.bozza,
    this.origine,
    super.key,
  });

  /// `null` = scheda nuova. È la strada del trainer: si carica dal server.
  final int? schedaId;

  /// 🆕 **Apri su questa, che non è salvata da nessuna parte** — K3.
  ///
  /// 💡 Arriva da un documento importato. ⚠️ Con `bozza != null` non si legge
  /// niente dal server: quella scheda **non esiste** ancora da nessuna parte.
  final SchedaAllenamento? bozza;

  /// 🆕 Da dove viene la bozza, e dove va a finire — K3.
  ///
  /// 🚨 **È l'unico interruttore della modalità revisione.** Un secondo campo
  /// `bool revisione` sarebbe una seconda verità sullo stesso fatto: si possono
  /// disallineare, e il giorno che si disallineano il builder mostra la barra
  /// del documento senza avere il documento.
  final OrigineDellaBozza? origine;

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
    /*
     * 🆕 **La bozza importata** — K3.
     *
     * ⚠️ Si copia nello stato **una volta sola**, come si fa già per la scheda
     * che arriva dal server: da qui in poi il modulo è la fonte di verità, e
     * quello che la persona sta correggendo non deve essere buttato via da
     * niente.
     */
    if (widget.bozza != null && !_caricato) {
      _scheda = widget.bozza;
      _caricato = true;
    }

    if (widget.schedaId == null && widget.bozza == null && !_caricato) {
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

    if (widget.schedaId != null && widget.bozza == null && !_caricato) {
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
    final origine = widget.origine;

    return Scaffold(
      appBar: IntestazioneApp(
        titolo: origine != null
            ? 'Controlla la scheda'
            : scheda.nuova
                ? 'Nuova scheda'
                : scheda.nome,
        azioni: [
          TextButton(
            onPressed: _salvando ? null : _salva,
            child: _salvando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                /*
                 * 🚨 **«Ho controllato tutto», non «Salva»** — K4.
                 *
                 * 💡 Chiedere una **dichiarazione** invece di un assenso
                 * costringe a decidere, e chi non ha controllato se ne accorge
                 * nel momento in cui la legge.
                 */
                : Text(origine != null ? 'Ho controllato' : 'Salva'),
          ),
        ],
      ),

      /*
       * 📌 *«un tasto in basso a sx per vedere il documento originale»*.
       *
       * ⛔ Fissa e non dentro l'elenco: il confronto si fa riga per riga, e un
       * pulsante che scorre via fa smettere di confrontare dopo la quinta.
       */
      bottomNavigationBar:
          origine == null ? null : BarraDelDocumento(origine: origine),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          if (origine != null) ...[
            CappelloDellaRevisione(origine: origine),
            const SizedBox(height: Gap.md),
          ],
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

  /// Salva una bozza importata **su questo telefono**, e chiude l'importazione.
  ///
  /// ⚠️ **Si chiede conferma prima**, e la domanda non è «sei sicuro?»: è *«hai
  /// confrontato tutto?»*. 💡 Chiedere una dichiarazione invece di un assenso
  /// costringe a decidere, e chi non ha controllato se ne accorge nel momento in
  /// cui la legge.
  Future<void> _salvaLImportata(
    SchedaAllenamento scheda,
    OrigineDellaBozza origine,
  ) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hai confrontato tutto?'),
        content: Text(
          'Stai per salvare questa scheda come tua. Le '
          '${origine.righeDaControllare} righe qui sopra le ha lette '
          'un\'intelligenza artificiale dal tuo documento, e possono contenere '
          'errori che sembrano giusti.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Torno a controllare'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Ho controllato tutto'),
          ),
        ],
      ),
    );

    if (conferma != true || !mounted) return;

    setState(() => _salvando = true);

    try {
      final abbonato = ref.read(authControllerProvider).user?.abbonato ?? false;

      final esito = await ref
          .read(salvaLaBozzaProvider)
          .scheda(scheda, abbonato: abbonato, origine: origine);

      /*
       * ⚠️ **La chiusura non deve poter far fallire il salvataggio.** La scheda
       * è già al sicuro sul telefono; la riga di là scade da sola dopo sette
       * giorni. 🚨 Un errore di rete qui mostrerebbe un guasto per una cosa che
       * è andata bene.
       */
      try {
        await ref.read(importazioniProvider).chiudi(origine.importazioneId);
      } on Object {
        // Vedi il commento qui sopra.
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            esito.divisa
                ? '${esito.quante} schede salvate, una per giorno.'
                : 'Scheda salvata sul telefono.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;

      setState(() => _salvando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(e).message)),
      );
    }
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

    /*
     * ══ 🚨 UN IMPORT SI SALVA IN CASA, NON SUL SERVER — K3.3 ═══════════════
     *
     * ⛔ È il punto in cui si può sbagliare **in silenzio**: una scheda
     * importata salvata di là comparirebbe lo stesso nell'elenco, e nessuno se
     * ne accorgerebbe finché qualcuno non guarda il database — dove ci sarebbe
     * un programma di allenamento con un nome sopra, cioè l'opposto di D9-bis.
     */
    final origine = widget.origine;

    if (origine != null) {
      await _salvaLImportata(scheda, origine);

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
                  child: CampoEsercizio(
                    key: ValueKey('n-${esercizio.hashCode}'),
                    iniziale: esercizio.nome,
                    onCambiato: (v) {
                      esercizio.nome = v;
                      onCambio();
                    },

                    /*
                     * 💡 **Scegliendo dal catalogo si prendono anche i
                     * muscoli.** Il server li sa già per quell'esercizio:
                     * lasciare la domanda aperta vorrebbe dire farla a chi ha
                     * appena indicato la risposta.
                     */
                    onScelto: (scelto) {
                      esercizio.muscoli = (
                        primario: scelto.primario,
                        secondari: scelto.secondari,
                      );
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
             * ══ 📋 LE STESSE RIGHE DELL'EDITOR DELL'ISCRITTO — 3b-D.11 ═════
             *
             * 📌 *«queste modifiche devono riguardare anche l'editor del
             * trainer e quello del server, mi pare ovvio. A che cazzo serve
             * fare delle modifiche se poi non sono ovunque»*.
             *
             * ⛔ Qui c'erano quattro campi — serie, ripetizioni, recupero, kg —
             * che sapevano dire soltanto *«4 x 8-12 a 40 kg»*, uguale per tutte
             * le serie. 🚨 Un trainer che prescrive una piramide doveva
             * scriverla nelle note, dove nessuna funzione la legge.
             *
             * 💡 **Lo stesso identico widget** dell'editor dell'iscritto, non
             * una copia che gli somiglia: `RigheDelleSerie` lavora
             * sull'interfaccia `ConLeSerie`, che tutti e due i modelli
             * implementano. Due copie sarebbero divergute alla prima
             * correzione, e la prima a divergere sarebbe stata questa — che si
             * prova meno.
             */
            RigheDelleSerie(esercizio: esercizio, onCambio: onCambio),

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
