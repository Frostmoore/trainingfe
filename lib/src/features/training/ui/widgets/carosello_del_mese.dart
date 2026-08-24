/// Il carosello delle tre card — 3b-A.6, 24/08/2026.
///
/// 📌 Il committente: *«All'inizio della schermata ci deve essere un carosello
/// di cards con tre card di **altezza identica**»*.
///
/// ══ 🚨 «ALTEZZA IDENTICA» È UN VINCOLO, NON UN AUSPICIO — A.6.4 ═══════════
///
/// ⛔ Lasciare che l'altezza la decida il contenuto vuol dire tre card diverse:
/// la figura del corpo è alta, i quattro numeri sono bassi, e scorrendo il
/// carosello **salterebbe**. ⚠️ E non salterebbe sempre: dipende da quanti
/// numeri ci sono quel mese, quindi il difetto comparirebbe e sparirebbe.
///
/// 💡 Qui l'altezza è **dichiarata una volta** e vale per tutte e tre. Il
/// contenuto ci si adatta, e quello che non ci sta si stringe.
///
/// ── ⚠️ Il periodo è il MESE, e non è un'incoerenza con l'intestazione ─────
///
/// L'intestazione naviga per **settimane**, ma questo blocco parla del **mese**
/// che le contiene — come chiesto (*«il numero di sessioni del mese»*) e come
/// il calendario qui sotto.
///
/// 🚨 Ed è la scelta giusta anche per le altre due card: una settimana sola
/// dice poco di come ti alleni. Chi fa un «giorno gambe» avrebbe la figura
/// mezza spenta il martedì e mezza accesa il giovedì, e la stella sembrerebbe
/// dire che ha uno squilibrio quando invece ha solo una scheda divisa.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../mese_in_numeri.dart';
import '../../muscoli_allenati.dart';
import '../../settimana_scelta.dart';
import 'figura_del_corpo.dart';
import 'stella_dei_muscoli.dart';

/// L'altezza di tutte e tre le card.
///
/// 🚨 **Un numero solo**, ed è quello che rende vero «altezza identica». ⚠️ Non
/// si scala con il carattere: dentro non ci sono blocchi di testo che crescono,
/// e i pochi numeri hanno spazio di sovrappiù.
const double altezzaCarosello = 232;

/// L'aria fra l'intestazione e la prima card — 3b-B.7.
///
/// 📌 *«le cards a carosello … sono troppo attaccate all'header, ci va qualche
/// pixel di margine»*.
const double ariaSopraIlCarosello = Gap.md;

/// La riga dei puntini sotto le card.
///
/// 🚨 **Non è un vezzo, è la conseguenza della larghezza piena.** Prima si
/// vedeva **spuntare** la card accanto, e quello diceva da solo «ce n'è
/// un'altra». ⛔ A tutta pagina quel segnale sparisce: senza i puntini, due card
/// su tre diventano invisibili a chi non prova a trascinare.
const double _altezzaPuntini = 18;

/// La chiave dell'i-esimo puntino, per i test.
///
/// 💡 Senza, contarli vorrebbe dire cercare `AnimatedContainer` — che nella
/// card ci può stare per mille altri motivi. Un test che conta la cosa
/// sbagliata passa lo stesso, ed è il peggio dei due mondi.
@visibleForTesting
ValueKey<String> chiavePuntino(int i) => ValueKey('carosello.puntino.$i');

class CaroselloDelMese extends ConsumerStatefulWidget {
  const CaroselloDelMese({super.key});

  @override
  ConsumerState<CaroselloDelMese> createState() => _CaroselloDelMeseState();
}

class _CaroselloDelMeseState extends ConsumerState<CaroselloDelMese> {
  /*
   * ⛔ **Il controller vive quanto il widget, non quanto una `build`.**
   * Crearlo dentro `build` lo rifarebbe a ogni ridisegno: la pagina tornerebbe
   * alla prima ogni volta che cambia un numero, e il vecchio non verrebbe mai
   * chiuso.
   */
  final _pagine = PageController();
  int _pagina = 0;

  @override
  void dispose() {
    _pagine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /*
     * 💡 Il mese lo decide la **settimana scelta**: navigando indietro fino a
     * luglio, il blocco in cima parla di luglio. ⛔ Un carosello fermo sul mese
     * corrente mentre la griglia sotto mostra un'altra settimana sarebbe una
     * schermata che parla di due periodi senza dirlo.
     */
    final settimana = ref.watch(settimanaSceltaProvider);
    final mese = DateTime(settimana.year, settimana.month);

    final intensita = ref.watch(muscoliDelMeseProvider(mese));
    final numeri = ref.watch(numeriDelMeseProvider(mese));

    /*
     * ⛔ **Un mese senza allenamenti non mostra tre card vuote.** Una figura
     * tutta grigia, una stella schiacciata al centro e quattro trattini sono
     * tre modi di dire «niente» — ripetuto tre volte, con lo scorrimento.
     */
    if (numeri.eVuoto) return const SizedBox.shrink();

    final titolo = DateFormat('MMMM y', 'it').format(mese);

    final card = [
      _Card(
        titolo: 'Cosa hai allenato',
        sottotitolo: titolo,
        child: FiguraDelCorpo(intensita: intensita),
      ),
      _Card(
        titolo: 'I gruppi muscolari',
        sottotitolo: titolo,
        child: StellaDeiMuscoli(intensita: intensita),
      ),
      _Card(
        titolo: 'Il mese in numeri',
        sottotitolo: titolo,
        child: _Numeri(numeri: numeri),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: ariaSopraIlCarosello),
      child: Column(
        children: [
          SizedBox(
            height: altezzaCarosello,

            /*
             * 🚨 **`PageView` e non `ListView`**: 📌 *«dovrebbero essere larghe
             * tutta la pagina e scorrere una per una»*. ⛔ Una lista orizzontale
             * si ferma dove la lasci, e con card a tutta pagina vuol dire
             * restare quasi sempre **a cavallo di due**, con mezza figura di
             * qua e mezza stella di là. Qui lo scatto è garantito dal widget,
             * non da noi.
             */
            child: PageView(
              controller: _pagine,
              onPageChanged: (i) => setState(() => _pagina = i),
              children: card,
            ),
          ),
          SizedBox(
            height: _altezzaPuntini,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < card.length; i++)
                  _Puntino(key: chiavePuntino(i), acceso: i == _pagina),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Puntino extends StatelessWidget {
  const _Puntino({required this.acceso, super.key});

  final bool acceso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      width: acceso ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),

        // ⚠️ Lo spento non è trasparente: su una scheda chiara sparirebbe, e
        // resterebbe un puntino solo — cioè l'informazione sbagliata.
        color: acceso
            ? tema.colorScheme.primary
            : tema.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.titolo,
    required this.sottotitolo,
    required this.child,
  });

  final String titolo;
  final String sottotitolo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    /*
     * 💡 **La larghezza non è più un numero nostro**: la decide la pagina, e la
     * card ci sta dentro con lo stesso margine laterale del resto della
     * schermata. ⚠️ Il `250` di prima serviva a far spuntare la card accanto;
     * adesso quel compito ce l'hanno i puntini.
     */
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Gap.md),
      child: Padding(
        padding: const EdgeInsets.all(Gap.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titolo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              sottotitolo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.xs),

            // 🚨 `Expanded`: il contenuto prende quello che resta, qualunque
            // sia. È la riga che fa funzionare l'altezza unica.
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _Numeri extends StatelessWidget {
  const _Numeri({required this.numeri});

  final MeseInNumeri numeri;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final righe = <(IconData, String, String)>[
      (
        Icons.fitness_center_rounded,
        '${numeri.sessioni}',
        numeri.sessioni == 1 ? 'sessione' : 'sessioni',
      ),

      /*
       * ⛔ **Quello che non c'è non si mostra.** Chi fa solo pesi non ha km, e
       * «0 km» sarebbe un numero falso travestito da informazione — la stessa
       * lezione del «0 bruciate» del 23/08.
       */
      if (numeri.kgSollevati != null)
        (
          Icons.monitor_weight_outlined,
          _migliaia(numeri.kgSollevati!.round()),
          'kg sollevati',
        ),
      if (numeri.metri != null)
        (Icons.route_outlined, _distanza(numeri.metri!), 'percorsi'),
      if (numeri.kcal != null)
        (
          Icons.local_fire_department_outlined,
          _migliaia(numeri.kcal!),
          'kcal bruciate',
        ),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icona, valore, etichetta) in righe)
          Row(
            children: [
              Icon(icona, size: 18, color: tema.colorScheme.primary),
              const SizedBox(width: Gap.sm),
              Text(
                valore,
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  etichetta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// 💡 Sotto il chilometro si scrivono i metri: «0,2 km» per una camminata in
  /// palestra sarebbe una precisione finta. Stessa regola di `_RigaOrologio`.
  static String _distanza(int metri) => metri < 1000
      ? '$metri m'
      : '${(metri / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  static String _migliaia(int n) => NumberFormat.decimalPattern('it').format(n);
}
