/// Le serie di un esercizio, una per riga — 3b-D.5, 25/08/2026.
///
/// ══ 📌 LE RICHIESTE ═══════════════════════════════════════════════════════
///
/// *«ogni esercizio deve partire di base con 3 serie (devo anche poterle
/// rimuovere e aggiungere)»* · *«Ogni serie deve essere una riga, che posso
/// rimuovere slidandola via o premendo una x»* · *«ogni serie deve avere
/// Ripetizioni, Peso (o niente o Iso.) e Recupero»* · *«Quando compilo la prima
/// si devono autocompilare anche le altre sotto»* · *«Sotto l'ultima serie ci
/// deve essere un tasto "Aggiungi Serie"»*.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/scheda_in_scrittura.dart';
import '../../data/serie_prevista.dart';

class RigheDelleSerie extends StatelessWidget {
  const RigheDelleSerie({
    required this.esercizio,
    required this.onCambio,
    super.key,
  });

  final ConLeSerie esercizio;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /*
         * ══ ⚠️ L'ETICHETTA E IL SELETTORE SU DUE RIGHE, NON UNA ═══════════
         *
         * ⛔ Stavano in riga con uno `Spacer` in mezzo, e a **328 px** — la
         * larghezza utile dello Xiaomi del committente — sforavano di 175:
         * `SegmentedButton` non si comprime, quindi non c'era niente da
         * stringere. 🚨 Trovato dai test del compositore, che montano proprio
         * quella larghezza: la stessa misura su cui era stato trovato il
         * difetto delle tendine del profilo.
         *
         * 💡 Su una riga sua ci sta comodo, e l'etichetta resta dov'era.
         */
        Align(
          alignment: Alignment.centerLeft,
          child: Text('Serie', style: tema.textTheme.labelLarge),
        ),

        const SizedBox(height: Gap.xs),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: _SceltaDelCarico(esercizio: esercizio, onCambio: onCambio),
        ),

        const SizedBox(height: Gap.xs),

        for (var i = 0; i < esercizio.righe.length; i++)
          /*
           * 📌 *«che posso rimuovere slidandola via o premendo una x»*.
           *
           * ⚠️ **Tutti e due, non uno**: la x si trova senza sapere che c'e',
           * lo slide e' piu' veloce quando lo si sa. Chi ne offre uno solo
           * costringe meta' delle persone al gesto sbagliato per loro.
           */
          Dismissible(
            key: ObjectKey(esercizio.righe[i]),
            direction: esercizio.righe.length > 1
                ? DismissDirection.endToStart
                : DismissDirection.none,
            background: ColoredBox(
              color: tema.colorScheme.errorContainer,
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: Gap.md),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: tema.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
            onDismissed: (_) => _togli(i),
            child: _RigaSerie(
              numero: i + 1,
              riga: esercizio.righe[i],
              carico: esercizio.carico,
              // ⛔ L'ultima riga non si toglie: un esercizio con zero serie
              // non e' un esercizio.
              onTogli: esercizio.righe.length > 1 ? () => _togli(i) : null,
              /*
               * 🚨 **La prima riga propaga, le altre si marcano** — 3b-D.15.
               *
               * ⛔ Prima le righe sotto chiamavano solo `onCambio`, e chi le
               * riempiva a mano non lasciava traccia: l'autocompilazione le
               * riconosceva «gia' scritte» solo perche' avevano del testo
               * dentro — e bastava che ce l'avessero messo lei.
               *
               * 💡 Adesso battere un tasto in una riga la dichiara **di chi
               * scrive**, e da li' in poi non si tocca piu'.
               */
              onCambioRiga: i == 0
                  ? () {
                      esercizio.autocompila();
                      onCambio();
                    }
                  : () {
                      esercizio.righe[i].toccataAMano = true;
                      onCambio();
                    },
            ),
          ),

        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              esercizio.righe.add(SerieInScrittura());
              esercizio.autocompila();
              onCambio();
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Aggiungi serie'),
          ),
        ),
      ],
    );
  }

  void _togli(int i) {
    esercizio.righe.removeAt(i).dispose();

    if (esercizio.righe.isEmpty) esercizio.righe.add(SerieInScrittura());

    onCambio();
  }
}

/// Peso · Nessuno · Iso., per **tutto** l'esercizio.
///
/// ⚠️ Vedi la nota su `CaricoDellEsercizio`: la scelta descrive il movimento,
/// non la singola serie.
class _SceltaDelCarico extends StatelessWidget {
  const _SceltaDelCarico({required this.esercizio, required this.onCambio});

  final ConLeSerie esercizio;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<CaricoDellEsercizio>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        for (final c in CaricoDellEsercizio.values)
          ButtonSegment(value: c, label: Text(c.etichetta)),
      ],
      selected: {esercizio.carico},
      onSelectionChanged: (scelta) {
        final prima = esercizio.carico;
        final adesso = scelta.first;

        esercizio.carico = adesso;

        /*
         * 🚨 **Passando da chili a secondi il numero si svuota.** Tenere «40»
         * quando la colonna diventa «Iso.» vorrebbe dire quaranta **secondi**
         * di tenuta scritti da nessuno — un dato inventato che sembra
         * dichiarato.
         *
         * ⚠️ Fra `peso` e `niente` invece non si tocca niente: chi spegne il
         * campo per sbaglio e lo riaccende ritrova i suoi numeri.
         */
        final cambiaUnita =
            prima == CaricoDellEsercizio.iso ||
            adesso == CaricoDellEsercizio.iso;

        if (cambiaUnita) {
          for (final riga in esercizio.righe) {
            riga.carico.clear();
          }
        }

        onCambio();
      },
    );
  }
}

class _RigaSerie extends StatelessWidget {
  const _RigaSerie({
    required this.numero,
    required this.riga,
    required this.carico,
    required this.onTogli,
    required this.onCambioRiga,
  });

  final int numero;
  final SerieInScrittura riga;
  final CaricoDellEsercizio carico;
  final VoidCallback? onTogli;
  final VoidCallback onCambioRiga;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Container(
      // 📌 *«le righe devono essere più chiaramente separate»*.
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: tema.dividerColor.withValues(alpha: 0.6)),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$numero',
              style: tema.textTheme.labelMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          Expanded(
            child: _Campo(
              controller: riga.ripetizioni,
              etichetta: 'Rip.',
              onCambio: onCambioRiga,
            ),
          ),

          /*
           * 📌 *«Il campo peso deve poter essere rimosso o sostituito con Iso»*.
           *
           * 💡 Con `niente` la colonna **sparisce** invece di restare spenta:
           * un campo grigio che non si puo' toccare fa chiedere perche', e la
           * risposta non c'e' a schermo.
           */
          if (carico != CaricoDellEsercizio.niente) ...[
            const SizedBox(width: Gap.xs),
            Expanded(
              child: _Campo(
                controller: riga.carico,
                etichetta: carico == CaricoDellEsercizio.iso ? 'Sec.' : 'Kg',
                onCambio: onCambioRiga,
              ),
            ),
          ],

          const SizedBox(width: Gap.xs),
          Expanded(
            child: _Campo(
              controller: riga.recupero,
              etichetta: 'Rec. s',
              onCambio: onCambioRiga,
            ),
          ),

          SizedBox(
            width: 36,
            child: onTogli == null
                ? null
                : IconButton(
                    onPressed: onTogli,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Togli questa serie',
                  ),
          ),
        ],
      ),
    );
  }
}

/// Un campo numerico stretto.
///
/// 📌 *«I campi possono avere anche meno padding interno»* — ed e' quello che
/// permette a tre campi e a un pulsante di stare su una riga sola di telefono.
class _Campo extends StatelessWidget {
  const _Campo({
    required this.controller,
    required this.etichetta,
    required this.onCambio,
  });

  final TextEditingController controller;
  final String etichetta;
  final VoidCallback onCambio;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      onChanged: (_) => onCambio(),
      decoration: InputDecoration(
        labelText: etichetta,
        isDense: true,
        // ⚠️ Il testo dell'etichetta e' corto **apposta**: «Rip.» invece di
        // «Ripetizioni». Le etichette lunghe sono quelle che andavano in
        // overflow, e qui di spazio non ce n'e' di piu' di ieri.
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.xs,
          vertical: Gap.xs,
        ),
      ),
    );
  }
}
