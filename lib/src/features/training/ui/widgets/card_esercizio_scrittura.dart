/// La card di un esercizio mentre lo si scrive — 3b-D.3/D.4/D.5, 25/08/2026.
///
/// ══ 📌 LE RICHIESTE, TUTTE INSIEME ════════════════════════════════════════
///
/// *«i label dei campi non si leggono, vanno tutti in overflow. Questa è
/// l'interfaccia di creazione, e c'è un motivo: un campo di troppo che adesso
/// toglieremo (il campo serie)»* · *«Ogni esercizio deve avere un campo
/// immagine facoltativo»* · *«un modo chiaro per indicare i muscoli usati.
/// Adesso è un simbolo di info mentre scrivo, tra l'altro orribile»* · *«Mentre
/// scrivo il nome dell'esercizio, mi deve mostrare una lista di esercizi dal
/// server»* · *«Ogni serie deve essere una riga, che posso rimuovere slidandola
/// via o premendo una x»* · *«le righe devono essere più chiaramente separate,
/// e i campi più chiaramente separati»*.
///
/// ══ 🚨 IL CAMPO CHE SE N'E' ANDATO E' QUELLO CHE HA RISOLTO LE ETICHETTE ══
///
/// ⛔ Le etichette andavano in overflow perché in riga c'erano **cinque** campi:
/// serie, ripetizioni, riposo, peso, note. 💡 Il committente l'ha visto e ha
/// detto anche il perché: *«un campo di troppo che adesso toglieremo (il campo
/// serie)»* — le serie adesso **sono righe**, e il loro numero lo dice la loro
/// quantità.
///
/// ⚠️ Non è stato risolto stringendo i caratteri: **è stato risolto togliendo
/// una colonna**. È la stessa lezione della terza card (3b-B.14): lo spazio non
/// si trova disponendo meglio quello che c'è.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/catalogo_esercizi.dart';
import '../../data/gruppo_muscolare.dart';
import '../../data/scheda_in_scrittura.dart';
import 'immagine_dell_esercizio.dart';
import 'righe_delle_serie.dart';
import 'scelta_muscoli.dart';

class CardEsercizioScrittura extends ConsumerWidget {
  const CardEsercizioScrittura({
    required this.esercizio,
    required this.numero,
    required this.onCambio,
    required this.onRimuovi,
    this.posizione,
    this.etichetta,
    this.codaDellaRiga,
    super.key,
  });

  final EsercizioInScrittura esercizio;
  final int numero;

  /// Cosa c'e' scritto in cima al posto di «Esercizio 3» — 3b-E.2.
  ///
  /// 💡 Durante l'allenamento dice anche **a che punto si e'** («Esercizio 3 ·
  /// 2 di 4»): e' l'unica informazione che serve guardando il telefono da un
  /// metro, appoggiato sulla panca. ⚠️ `null` = l'etichetta di casa.
  final String? etichetta;

  /// La coda delle righe delle serie — vedi `RigheDelleSerie.coda`.
  final Widget Function(int indice)? codaDellaRiga;

  /// L'indice nella lista, per la maniglia di trascinamento — 3b-D.12.
  ///
  /// ⚠️ `null` quando la card non sta dentro un elenco riordinabile: la
  /// maniglia semplicemente non compare, invece di comparire e non fare niente.
  final int? posizione;
  final VoidCallback onCambio;
  final VoidCallback onRimuovi;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.md),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  etichetta ?? 'Esercizio $numero',
                  style: tema.textTheme.labelLarge?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onRimuovi,
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Togli questo esercizio',
                ),

                /*
                 * ↕️ La maniglia, e **solo** questa trascina — 3b-D.12.
                 *
                 * 💡 `ReorderableDragStartListener` invece del trascinamento su
                 * tutta la card: qui dentro ci sono sei campi di testo, e un
                 * trascinamento che parte da qualunque punto sposta l'esercizio
                 * mentre si prova a scrivere.
                 */
                if (posizione case final indice?)
                  ReorderableDragStartListener(
                    index: indice,
                    child: const Padding(
                      padding: EdgeInsets.only(left: Gap.xs),
                      child: Icon(Icons.drag_handle_rounded),
                    ),
                  ),
              ],
            ),

            /*
             * ══ 🔎 IL NOME, IN GRANDE E CON L'ELENCO — 3b-D.3.2/D.4 ═══════
             *
             * 📌 *«Va bene anche che la parte del nome sia più grande e più
             * chiara»*.
             *
             * ✅ **L'elenco non va in rete**: `catalogoEserciziProvider` tiene
             * gia' tutto il catalogo in memoria, con la sua cache. 💡 Meglio che
             * per gli alimenti, che invece ci vanno.
             */
            _NomeConElenco(
              esercizio: esercizio,
              onCambio: onCambio,
            ),

            const SizedBox(height: Gap.sm),

            /*
             * ══ 💪 I MUSCOLI, CHE PRIMA ERANO UN'ICONA «INFO» ════════════
             *
             * 📌 *«Adesso è un simbolo di info mentre scrivo, tra l'altro
             * orribile. Non va bene, facciamolo più chiaro»*.
             *
             * 💡 Adesso sono **le pasticche dei gruppi**, che si leggono senza
             * toccare niente, e il tocco serve a cambiarle e non a scoprirle.
             */
            _MuscoliDellEsercizio(esercizio: esercizio, onCambio: onCambio),

            const SizedBox(height: Gap.md),

            RigheDelleSerie(
              esercizio: esercizio,
              onCambio: onCambio,
              coda: codaDellaRiga,
            ),

            const SizedBox(height: Gap.md),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ImmagineDellEsercizio(
                  esercizio: esercizio,
                  onCambio: onCambio,
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: TextField(
                    controller: esercizio.note,
                    minLines: 2,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'es. gomiti stretti',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Il nome, con l'elenco del catalogo sotto mentre si scrive.
class _NomeConElenco extends ConsumerWidget {
  const _NomeConElenco({required this.esercizio, required this.onCambio});

  final EsercizioInScrittura esercizio;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final catalogo = ref.watch(catalogoEserciziProvider).valueOrNull;

    return Autocomplete<EsercizioDelCatalogo>(
      displayStringForOption: (e) => e.nome,
      optionsBuilder: (valore) {
        final cercato = valore.text.trim().toLowerCase();

        // ⚠️ Sotto i due caratteri l'elenco sarebbe tutto il catalogo: non
        // aiuta a scegliere, copre lo schermo e basta.
        if (cercato.length < 2 || catalogo == null) {
          return const Iterable<EsercizioDelCatalogo>.empty();
        }

        return catalogo.tutti
            .where((e) => e.nome.toLowerCase().contains(cercato))
            .take(8);
      },
      onSelected: (scelto) {
        esercizio.nome.text = scelto.nome;

        /*
         * ══ 🚨 QUESTO E' IL PEZZO CHE CONTA — 3b-D.4.2 ════════════════════
         *
         * 📌 *«Se ne seleziono uno, deve automaticamente compilarmi i muscoli
         * usati»*.
         *
         * 💡 L'`exerciseId` vale piu' del nome: con quello `pesiDellaScheda`
         * trova i muscoli **nel catalogo**, e la figura in fondo alla scheda si
         * accende da sola. ⛔ Scrivere i muscoli dentro la scheda sarebbe una
         * seconda copia che invecchia.
         */
        esercizio.exerciseId = scelto.id;

        if (scelto.primario != null || scelto.secondari.isNotEmpty) {
          esercizio.muscoli = (
            primario: scelto.primario,
            secondari: scelto.secondari,
          );
        }

        onCambio();
      },
      fieldViewBuilder: (context, controller, focus, _) {
        // 💡 `Autocomplete` vuole il **suo** controller: si tengono allineati
        // in un verso solo, e quello di casa resta la sorgente.
        if (controller.text != esercizio.nome.text) {
          controller.text = esercizio.nome.text;
        }

        return TextField(
          controller: controller,
          focusNode: focus,
          textCapitalization: TextCapitalization.sentences,
          style: tema.textTheme.titleMedium,
          decoration: const InputDecoration(
            labelText: 'Esercizio',
            hintText: 'es. Panca piana',
          ),
          onChanged: (v) {
            esercizio.nome.text = v;

            /*
             * ⚠️ **Chi riscrive il nome a mano perde l'aggancio al catalogo.**
             * 🚨 Tenerlo sarebbe peggio che perderlo: la figura mostrerebbe i
             * muscoli di un esercizio che non e' piu' quello scritto, e nessuno
             * avrebbe modo di accorgersene.
             */
            /*
             * ══ 🚨 E CON L'AGGANCIO DECADONO I MUSCOLI CHE VENIVANO DA LI' ══
             *
             * ⛔ Restavano appesi al nome nuovo: le pasticche dicevano «Pettorali»
             * sotto un esercizio che nel frattempo era diventato «Rematore», e
             * l'allenamento li mandava al server come muscoli di **quel** nome
             * (3b-A.3.5). ⚠️ Nessun errore: solo un dato sbagliato, dichiarato.
             *
             * 💡 **Solo quelli del catalogo pero'.** Se `exerciseId` era gia'
             * `null`, i muscoli li ha scelti una persona a mano: cancellarli
             * perche' si corregge un refuso nel nome sarebbe buttare via
             * l'unica cosa che nessuno puo' ricostruire.
             */
            if (esercizio.exerciseId != null) esercizio.muscoli = null;

            esercizio.exerciseId = null;

            onCambio();
          },
        );
      },
    );
  }
}

class _MuscoliDellEsercizio extends StatelessWidget {
  const _MuscoliDellEsercizio({required this.esercizio, required this.onCambio});

  final EsercizioInScrittura esercizio;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final muscoli = esercizio.muscoli;

    final gruppi = <GruppoMuscolare>[
      ?muscoli?.primario,
      ...?muscoli?.secondari,
    ];

    return InkWell(
      onTap: () async {
        final scelti = await chiediIMuscoli(
          context,
          nomeEsercizio: esercizio.nome.text.trim(),
          iniziali:
              muscoli ??
              const (primario: null, secondari: <GruppoMuscolare>[]),
        );

        if (scelti == null) return;

        esercizio.muscoli = scelti;
        onCambio();
      },
      borderRadius: BorderRadius.circular(Gap.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        child: Row(
          children: [
            Icon(
              Icons.fitness_center_rounded,
              size: 18,
              color: tema.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: gruppi.isEmpty
                  /*
                   * ⚠️ **Si dice cosa manca, non si mostra un'icona.** Un
                   * «info» grigio non dice ne' che c'e' una cosa da fare ne'
                   * cosa succede toccandolo.
                   */
                  ? Text(
                      'Muscoli: da indicare',
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    )
                  : Wrap(
                      spacing: Gap.xs,
                      runSpacing: Gap.xs,
                      children: [
                        for (final g in gruppi)
                          Chip(
                            label: Text(g.etichetta),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            labelStyle: tema.textTheme.labelSmall,
                          ),
                      ],
                    ),
            ),
            Icon(
              Icons.edit_rounded,
              size: 16,
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
