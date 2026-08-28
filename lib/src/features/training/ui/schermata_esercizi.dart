/// La pagina «Esercizi» — 3b-N, 28/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«All'inizio non la volevo, però a sto punto perché no? Sì, mettiamo anche
/// una pagina "Esercizi". Ci si deve accedere dalla pagina delle schede»*.
///
/// ══ 🚨 COSA MANCAVA DAVVERO ═══════════════════════════════════════════════
///
/// ⛔ Aggiungere esercizi si poteva **già**: scrivendone il nome in una scheda,
/// o registrando una serie fuori scheda. E finiscono sul server con i permessi
/// giusti da 3b-M.
///
/// 💡 Quello che non c'era è **vederli**. Un utente che ne aveva scritti venti
/// non aveva nessun posto dove guardarli tutti insieme, e non poteva sapere
/// quali fossero suoi e quali arrivassero dal trainer. ⚠️ Una libreria che non
/// si può guardare è una libreria di cui non ci si fida, e chi non si fida
/// riscrive il nome un po' diverso — che è il modo in cui il catalogo degenera.
///
/// ══ ⛔ COSA QUESTA PAGINA NON FA, E PERCHÉ ════════════════════════════════
///
/// 🚨 **Non cancella.** Un esercizio può essere dentro la scheda di qualcun
/// altro, dentro lo storico di chi l'ha usato, o dentro il piano che un trainer
/// ha consegnato. ⛔ Farlo sparire da qui vorrebbe dire romperlo a distanza in
/// posti che questa schermata non vede — ed è la cosa che tutto il resto del
/// progetto è costruito per non fare.
///
/// ⏳ Se servirà, la strada è un `DELETE` che il server valuta guardando i
/// riferimenti: non un pulsante qui.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/miniatura.dart';
import '../data/catalogo_esercizi.dart';
import '../data/gruppo_muscolare.dart';
import 'widgets/scelta_muscoli.dart';

class SchermataEsercizi extends ConsumerStatefulWidget {
  const SchermataEsercizi({super.key});

  @override
  ConsumerState<SchermataEsercizi> createState() => _SchermataEserciziState();
}

class _SchermataEserciziState extends ConsumerState<SchermataEsercizi> {
  String _cerca = '';

  /*
   * ⚠️ **L'ordine dei gruppi non è alfabetico ed è voluto**: si apre questa
   * pagina per cercare qualcosa di proprio, non per sfogliare i trecento della
   * piattaforma. 💡 Quelli stanno in fondo perché sono i più numerosi e i meno
   * cercati qui dentro.
   */
  static const _ordine = [
    OrigineEsercizio.mia,
    OrigineEsercizio.condivisa,
    OrigineEsercizio.piattaforma,
  ];

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoEserciziProvider);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Esercizi'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _aggiungi,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuovo'),
      ),
      body: catalogo.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Errore(
          onRiprova: () => ref.invalidate(catalogoEserciziProvider),
        ),
        data: (c) => _elenco(c.tutti),
      ),
    );
  }

  Widget _elenco(List<EsercizioDelCatalogo> tutti) {
    final filtro = CatalogoEsercizi.normalizza(_cerca);

    final visti = filtro.isEmpty
        ? tutti
        : tutti
              .where(
                (e) => CatalogoEsercizi.normalizza(e.nome).contains(filtro),
              )
              .toList(growable: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xs),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Cerca un esercizio',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(Gap.radiusSm),
              ),
            ),
            onChanged: (v) => setState(() => _cerca = v),
          ),
        ),

        if (visti.isEmpty)
          Expanded(child: _Vuoto(cercava: _cerca))
        else
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 88),
              children: [
                for (final origine in _ordine)
                  ..._gruppo(
                    origine,
                    visti.where((e) => e.origine == origine).toList(),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _gruppo(
    OrigineEsercizio origine,
    List<EsercizioDelCatalogo> righe,
  ) {
    // ⛔ Un'intestazione sopra il vuoto direbbe «qui non hai niente» a chi sta
    // cercando: il gruppo semplicemente non compare.
    if (righe.isEmpty) return const [];

    final tema = Theme.of(context);

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xs),
        child: Row(
          children: [
            Text(
              origine.titolo,
              style: tema.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: tema.colorScheme.primary,
              ),
            ),
            const SizedBox(width: Gap.xs),
            Text(
              '${righe.length}',
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      for (final e in righe) _Riga(esercizio: e),
    ];
  }

  /// ⚠️ **Il nome prima, i muscoli dopo.** Chiedere i muscoli di un esercizio
  /// che non si è ancora nominato è una domanda senza contesto — e il foglio
  /// dei muscoli scrive il nome in cima, quindi lo deve già sapere.
  Future<void> _aggiungi() async {
    final nome = await _chiediIlNome();

    if (nome == null || !mounted) return;

    /*
     * 💡 **Se quel nome esiste già, non si chiede niente.** Il server lo sa, e
     * `chiediIMuscoli` mostrerebbe una domanda che non cambia nulla: 3b-A.3.4
     * dice che quando una domanda non serve si smette di leggerla anche quando
     * serve.
     */
    final gia = ref
        .read(catalogoEserciziProvider)
        .valueOrNull
        ?.perNome(nome);

    if (gia != null) {
      _dillo('«${gia.nome}» c\'è già.');

      return;
    }

    final muscoli = await chiediIMuscoli(context, nomeEsercizio: nome);

    if (muscoli == null || !mounted) return;

    try {
      await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/exercises',
            body: {'name': nome, ...muscoliInJson(muscoli)},
          );

      /*
       * 🚨 **Si rilegge dal server, non si aggiunge a mano all'elenco.** Il
       * server può aver riconosciuto il nome e restituito un esercizio che
       * esisteva già — o averlo creato con i muscoli completati. ⛔ Ricostruire
       * la riga qui vorrebbe dire tenere una seconda verità che invecchia.
       */
      ref.invalidate(catalogoEserciziProvider);

      if (mounted) _dillo('«$nome» aggiunto.');
    } on Object catch (_) {
      if (mounted) _dillo('Non è riuscito. Riprova fra poco.');
    }
  }

  Future<String?> _chiediIlNome() async {
    final campo = TextEditingController();

    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuovo esercizio'),
        content: TextField(
          controller: campo,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Come si chiama',
            hintText: 'Es. Panca piana con presa stretta',
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(campo.text.trim()),
            child: const Text('Avanti'),
          ),
        ],
      ),
    );

    campo.dispose();

    return (nome == null || nome.isEmpty) ? null : nome;
  }

  void _dillo(String cosa) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(cosa)));
  }
}

// ══════════════════════════════════════════════════════════════════════════
// La riga
// ══════════════════════════════════════════════════════════════════════════

class _Riga extends StatelessWidget {
  const _Riga({required this.esercizio});

  final EsercizioDelCatalogo esercizio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final muscoli = descriviMuscoli((
      primario: esercizio.primario,
      secondari: esercizio.secondari,
    ));

    return ListTile(
      leading: Miniatura(
        url: esercizio.immagine,
        etichetta: esercizio.nome,
        // ⚠️ Stessa regola di `FotoDellEsercizio`: si tinge solo quando è un
        // disegno nostro, cioè quando c'è un credito da rendere.
        tinta: esercizio.credito == null
            ? null
            : tema.colorScheme.onSurfaceVariant,
      ),
      title: Text(esercizio.nome),
      subtitle: muscoli.isEmpty
          ? null
          : Text(muscoli, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => _apriIlDettaglio(context, esercizio),
    );
  }
}

Future<void> _apriIlDettaglio(
  BuildContext context,
  EsercizioDelCatalogo e,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) {
    final tema = Theme.of(context);

    final muscoli = descriviMuscoli((
      primario: e.primario,
      secondari: e.secondari,
    ));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Miniatura(
                url: e.immagine,
                etichetta: e.nome,
                lato: 160,
                tinta: e.credito == null
                    ? null
                    : tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.md),

            Text(
              e.nome,
              style: tema.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            if (muscoli.isNotEmpty) ...[
              const SizedBox(height: Gap.xs),
              Text(
                muscoli,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: Gap.sm),
            Text(
              e.origine.spiegazione,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),

            /*
             * ⚖️ Il credito, quando è dovuto — stessa regola della pagina della
             * scheda: le illustrazioni sono CC BY-SA 4.0, e l'attribuzione è
             * una condizione della licenza.
             */
            if (e.credito case final credito?) ...[
              const SizedBox(height: Gap.sm),
              Text(
                'Illustrazione: $credito',
                style: tema.textTheme.labelSmall?.copyWith(
                  color: tema.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  },
);

// ══════════════════════════════════════════════════════════════════════════
// Gli stati che non sono un elenco
// ══════════════════════════════════════════════════════════════════════════

class _Vuoto extends StatelessWidget {
  const _Vuoto({required this.cercava});

  final String cercava;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 48,
              color: tema.colorScheme.outline,
            ),
            const SizedBox(height: Gap.sm),

            /*
             * 💡 **Il nome cercato dentro il messaggio**, e il suggerimento di
             * crearlo: chi cerca un esercizio che non c'è ha in mano
             * esattamente il nome che servirebbe per aggiungerlo.
             */
            Text(
              cercava.isEmpty
                  ? 'Non c\'è ancora nessun esercizio.'
                  : 'Nessun esercizio per «$cercava».',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              'Puoi aggiungerlo con «Nuovo».',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Errore extends StatelessWidget {
  const _Errore({required this.onRiprova});

  final VoidCallback onRiprova;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Gli esercizi non sono arrivati.'),
          const SizedBox(height: Gap.sm),
          FilledButton.tonal(onPressed: onRiprova, child: const Text('Riprova')),
        ],
      ),
    ),
  );
}
