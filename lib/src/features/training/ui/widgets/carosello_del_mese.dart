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
import '../../data/gruppo_muscolare.dart';
import '../../mese_in_numeri.dart';
import '../../muscoli_allenati.dart';
import '../../settimana_scelta.dart';
import 'cilindro_del_numero.dart';
import 'figura_del_corpo.dart';
import 'grafico_dei_mesi.dart';
import 'stella_dei_muscoli.dart';

/// ══ 🧩 E QUI DENTRO C'È LA VESTIZIONE, NON SOLO IL MESE — 3b-B.20.1 ═══════
///
/// 📌 *«aggiungere sopra le tre cards a carosello come nella sezione storico,
/// ma limitate allo specifico allenamento»*.
///
/// ⚠️ **«Come nella sezione storico» vuol dire *le stesse*, non *simili*.**
/// `CardDelCarosello`, `RiquadroBianco`, `StellaInRiquadro` e
/// `PuntinoDelCarosello` erano private: adesso sono pubbliche perché le usa
/// anche `CaroselloDellAllenamento`. ⛔ Rifarle di là avrebbe prodotto due
/// caroselli che si somigliano finché qualcuno non tocca uno dei due.
///
/// 💡 Quello che resta privato è ciò che parla **del mese**: da dove vengono i
/// numeri, e la card che li mostra.

/// L'altezza di tutte e tre le card.
///
/// 🚨 **Un numero solo**, ed è quello che rende vero «altezza identica».
///
/// ⚠️ **Cresciuto due volte**: 232 → 300 in B.11 (la stella ha guadagnato il
/// quadrato e la spiegazione), 300 → **420** in B.14 (la card dei numeri ha
/// guadagnato il cilindro, le pasticche e il grafico dei sei mesi).
///
/// ⛔ L'altezza è **una sola**, quindi la card più esigente decide per tutte. È
/// il vincolo che rende vero «altezza identica», e anche il motivo per cui la
/// card dei numeri sembrava vuota: era alta quanto la stella e non aveva niente
/// da metterci dentro.
const double altezzaCarosello = 420;

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
const double altezzaPuntiniDelCarosello = 18;

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
      CardDelCarosello(
        titolo: 'Cosa hai allenato',
        sottotitolo: titolo,
        // 📌 *«mettiamolo in un quadrato con fondo bianco (anche nello
        // storico)»*: il PNG è disegnato per un fondo chiaro, e col tema scuro
        // i contorni sparivano.
        child: Column(
          children: [
            Expanded(
              child: RiquadroBianco(
                child: FiguraDelCorpo(intensita: intensita),
              ),
            ),
            const SizedBox(height: Gap.xs),
            const LegendaDeiMuscoli(),
          ],
        ),
      ),
      CardDelCarosello(
        titolo: 'I gruppi muscolari',
        sottotitolo: titolo,
        child: StellaInRiquadro(intensita: intensita),
      ),
      CardDelCarosello(
        titolo: 'Il mese in numeri',
        sottotitolo: titolo,
        child: _Numeri(
          numeri: numeri,
          mesi: ref.watch(sessioniPerMeseProvider(mese)),
          mese: mese,
        ),
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
            height: altezzaPuntiniDelCarosello,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < card.length; i++)
                  PuntinoDelCarosello(
                    key: chiavePuntino(i),
                    acceso: i == _pagina,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PuntinoDelCarosello extends StatelessWidget {
  const PuntinoDelCarosello({required this.acceso, super.key});

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

class CardDelCarosello extends StatelessWidget {
  const CardDelCarosello({
    required this.titolo,
    required this.sottotitolo,
    required this.child,
    super.key,
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📌 *«Nelle cards i titoli devono essere centrati»* — B.11.
            Text(
              titolo,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tema.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              sottotitolo,
              textAlign: TextAlign.center,
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

/// Il rettangolo bianco che ospita un grafico o un numero — B.14.
///
/// 💡 Sta qui e non copiato in due posti: le card della stella e dei numeri
/// devono avere **lo stesso** riquadro, o accostate si vede che sono due cose
/// disegnate in momenti diversi.
class RiquadroBianco extends StatelessWidget {
  const RiquadroBianco({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final scuro = tema.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        /*
         * ══ 🌗 IL FONDO SEGUE IL TEMA, PER TUTTI — in tre puntate ══════════
         *
         * ⛔ **Prima**: `Colors.white` sempre, perche' il committente aveva
         * chiesto un riquadro bianco. Era vero, ed era vero **in tema chiaro**.
         *
         * ⛔ **Poi** (3b-C.1): segue il tema — *«i quadrati bianchi ti
         * carbonizzano la retina»* — **con la figura del corpo come eccezione
         * bianca**, perche' il suo PNG e' disegnato per un fondo chiaro.
         *
         * ⛔ **Poi ancora** (3b-D.13): l'eccezione bianca abbagliava lo stesso,
         * e allora era diventata «chiara ma non bianca». 🚨 **E anche quella era
         * sbagliata**: *«adesso lo sfondo e' ancora bianco»*.
         *
         * ✅ **Adesso l'eccezione non c'e' piu'**, ed e' la risposta giusta:
         * *«facciamola semplicemente piu' chiara dello sfondo»* vuol dire un
         * tono **appena sopra il fondo scuro**, cioe' esattamente quello che
         * fanno tutti gli altri riquadri.
         *
         * 💡 **La figura si vede lo stesso**, e il motivo e' in
         * `figura_del_corpo.dart`: il corpo si tinge con un colore preso dal
         * **tema**, quindi su un fondo scuro e' chiaro e su uno chiaro e'
         * scuro. Era **quello** il difetto che rendeva l'uomo «strano» col tema
         * scuro — non il fondo — e per tre giri l'ho curato dalla parte
         * sbagliata.
         *
         * 🚨 Il nome `RiquadroBianco` resta e in tema scuro non e' bianco
         * niente: rinominarlo vorrebbe dire toccare sei schermate per un nome.
         */
        color: scuro ? tema.colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(Gap.radiusSm),
        border: Border.all(
          color: tema.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(Gap.xs), child: child),
    );
  }
}

/// La stella a destra, i numeri a sinistra — B.11, rifatta in B.14.
///
/// 📌 *«quella della stella deve avere il grafico dentro a un quadrato bianco e
/// sotto ci deve essere una breve spiegazione»* e poi, a schermo: *«c'è troppo
/// poca aria nella frase di sotto, e — visto che c'è anche troppa aria a dx e sx
/// — metti qualche valore a sx e il quadrato a dx»*.
///
/// ══ ⚠️ IL VUOTO LATERALE NON ERA UN PROBLEMA DI MARGINI ═══════════════════
///
/// ⛔ Il quadrato è **quadrato**: dentro una card larga tutta la pagina e alta
/// quanto basta, il suo lato lo decide **l'altezza** — e la larghezza che
/// avanza resta vuota per forza. 🚨 Allargare il quadrato non si poteva
/// (diventerebbe un rettangolo e la stella si deformerebbe), quindi l'unica
/// risposta vera era **mettere qualcosa in quello spazio**.
///
/// 💡 E le tre cose che ci sono messe sono le domande che la stella fa venire
/// in mente e non risponde: quanti gruppi, qual è il più allenato, quale sto
/// trascurando.
class StellaInRiquadro extends StatelessWidget {
  const StellaInRiquadro({required this.intensita, super.key});

  final Map<GruppoMuscolare, double> intensita;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final numeri = numeriDeiMuscoli(intensita);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Valore(
                      etichetta: 'Gruppi allenati',
                      valore: '${numeri.toccati}/${numeri.possibili}',
                    ),
                    _Valore(
                      etichetta: 'Equilibrio',
                      valore: '${numeri.percentualeEquilibrio}%',
                    ),
                    _Valore(
                      etichetta: 'Il più allenato',
                      valore: numeri.piuAllenato?.etichettaBreve ?? '—',
                    ),

                    /*
                     * 🚨 **Il trascurato è il valore che serve davvero.** Gli
                     * altri tre raccontano come è andata; questo dice **cosa
                     * fare**. ⚠️ È il meno allenato fra *tutti* i gruppi, non fra
                     * quelli toccati: quello che non hai mai allenato è proprio
                     * quello che una classifica dei toccati non nominerebbe.
                     */
                    _Valore(
                      etichetta: 'Trascurato',
                      valore: numeri.trascurato?.etichettaBreve ?? '—',
                      acceso: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: Gap.sm),

              /*
               * 🚨 **`AspectRatio(1)` e non un lato fisso.** ⛔ Un numero scelto
               * a mano sarebbe giusto su un telefono solo: troppo grande su uno
               * stretto — e il quadrato uscirebbe dai bordi — troppo piccolo su
               * uno largo.
               */
              Expanded(
                flex: 6,
                child: AspectRatio(
                  aspectRatio: 1,
                  child: RiquadroBianco(
                    child: StellaDeiMuscoli(intensita: intensita),
                  ),
                ),
              ),
            ],
          ),
        ),

        /*
         * 📌 *«c'è troppo poca aria nella frase di sotto»*: un `Gap.xs` sopra e
         * niente sotto. Adesso la frase ha aria da tutte e quattro le parti.
         */
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.xs, Gap.md, Gap.xs, Gap.xs),
          child: Text(
            spiegazioneDeiMuscoli(intensita),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// Un'etichetta piccola sopra e un valore sotto.
class _Valore extends StatelessWidget {
  const _Valore({
    required this.etichetta,
    required this.valore,
    this.acceso = false,
  });

  final String etichetta;
  final String valore;

  /// 💡 Quello che merita l'occhio prende il colore d'accento. ⛔ Se lo
  /// prendessero tutti e quattro, non lo prenderebbe nessuno.
  final bool acceso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          etichetta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          valore,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tema.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: acceso
                ? tema.colorScheme.tertiary
                : tema.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// I numeri del mese: il cilindro, le pasticche e i sei mesi — B.11, rifatta in
/// B.13 e B.14.
///
/// 📌 *«la terza card continua a farmi cagare. Serve più aria tra tutti gli
/// elementi, il numero di sessioni deve essere più grande, il quadrato deve
/// essere un rettangolo, e si deve vedere tipo "cilindro" con vicino altri due o
/// tre numeri … Di base aggiungi anche altri dati finché la card non sembra
/// "piena", ci puoi mettere anche sotto un grafico dentro a un altro rettangolo
/// bianco con il confronto degli allenamenti degli ultimi x mesi»*.
///
/// ══ ⚠️ TRE GIRI SULLA STESSA CARD, E VALE LA PENA DIRE PERCHÉ ═════════════
///
/// | Giro | Cos'era | Perché non bastava |
/// |---|---|---|
/// | B.11 | tutto centrato, sessioni in grande | a schermo **sembrava vuota** |
/// | B.13 | numero dentro un quadrato bianco | riempiva il quadrato, non la card |
/// | B.14 | cilindro + pasticche + grafico | c'è **abbastanza roba** da riempirla |
///
/// 🚨 La lezione non è «era brutta»: è che **il vuoto non si toglie centrando
/// meglio**. Una card alta trecento punti con tre righe dentro resta vuota
/// comunque le si dispongano, e l'unica risposta vera è avere qualcosa da dire.
class _Numeri extends StatelessWidget {
  const _Numeri({required this.numeri, required this.mesi, required this.mese});

  final MeseInNumeri numeri;
  final List<({DateTime mese, int sessioni})> mesi;
  final DateTime mese;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    /*
     * ⛔ **Quello che non c'è non si mostra.** Chi fa solo pesi non ha km, e
     * «0 km» sarebbe un numero falso travestito da informazione — la stessa
     * lezione del «0 bruciate» del 23/08.
     */
    final pasticche = <(IconData, String)>[
      if (numeri.minuti != null)
        (Icons.timer_outlined, _durata(numeri.minuti!)),
      if (numeri.kcal != null)
        (
          Icons.local_fire_department_outlined,
          '${_migliaia(numeri.kcal!)} kcal',
        ),
      if (numeri.kgSollevati != null)
        (
          Icons.monitor_weight_outlined,
          '${_migliaia(numeri.kgSollevati!.round())} kg',
        ),
      if (numeri.serie != null) (Icons.repeat_rounded, '${numeri.serie} serie'),
      if (numeri.metri != null)
        (Icons.route_outlined, _distanza(numeri.metri!)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /*
         * 📌 *«il quadrato deve essere un rettangolo»*: `Expanded` con un peso,
         * non più `AspectRatio(1)`. 💡 Così il cilindro prende **tutta** la
         * larghezza della card, che è quello che rende il numero più grande
         * senza toccare nessun `fontSize`.
         */
        Expanded(
          flex: 5,
          child: RiquadroBianco(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, vincoli) => CilindroDelNumero(
                      valore: numeri.sessioni,

                      /*
                       * 💡 Il passo esce dalla **larghezza** disponibile, non da
                       * un numero scritto qui: cinque posizioni — due vicini a
                       * sinistra, due a destra, e quello buono in mezzo.
                       *
                       * ⚠️ È anche il motivo per cui questo riquadro è un
                       * rettangolo largo e non un quadrato: il nastro scorre in
                       * orizzontale, e lo spazio che gli serve è quello.
                       */
                      passo: vincoli.maxWidth / 5,
                      stile: tema.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: tema.colorScheme.tertiary,
                        height: 1,
                      ),
                      stileVicini: tema.textTheme.displayLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: tema.colorScheme.onSurfaceVariant,
                        height: 1,
                      ),
                    ),
                  ),
                ),
                Text(
                  numeri.sessioni == 1 ? 'sessione' : 'sessioni',
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 📌 *«Serve più aria tra tutti gli elementi»*.
        const SizedBox(height: Gap.md),

        /*
         * 🚨 **`Wrap` e non `Row`**: cinque pasticche con numeri a quattro cifre
         * non ci stanno in riga su un telefono stretto, e una `Row` non lo
         * direbbe con un errore — lo direbbe con la striscia gialla di overflow
         * addosso a chi guarda.
         */
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Gap.xs,
          runSpacing: Gap.xs,
          children: [
            for (final (icona, testo) in pasticche)
              _Pasticca(icona: icona, testo: testo),
          ],
        ),

        const SizedBox(height: Gap.md),

        /*
         * 📌 *«ci puoi mettere anche sotto un grafico dentro a un altro
         * rettangolo bianco con il confronto degli allenamenti degli ultimi x
         * mesi»*.
         */
        Expanded(
          flex: 4,
          child: RiquadroBianco(
            child: GraficoDeiMesi(mesi: mesi, corrente: mese),
          ),
        ),
      ],
    );
  }

  /// 💡 Sotto l'ora si scrivono i minuti: «0,7 h» per mezz'ora in palestra
  /// sarebbe una precisione finta. Stessa regola di `_distanza`.
  static String _durata(int minuti) => minuti < 60
      ? '$minuti min'
      : '${(minuti / 60).toStringAsFixed(minuti % 60 == 0 ? 0 : 1).replaceAll('.', ',')} h';

  /// 💡 Sotto il chilometro si scrivono i metri: «0,2 km» per una camminata in
  /// palestra sarebbe una precisione finta. Stessa regola di `_RigaOrologio`.
  static String _distanza(int metri) => metri < 1000
      ? '$metri m'
      : '${(metri / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  static String _migliaia(int n) => NumberFormat.decimalPattern('it').format(n);
}

/// Una pasticca: icona e numero, dentro un contenitore tondo — B.11.
///
/// 💡 L'etichetta lunga di prima («kg sollevati») è diventata **l'unità
/// attaccata al numero**: in una pasticca lo spazio è quello che è, e «1.240 kg»
/// dice la stessa cosa in metà larghezza.
class _Pasticca extends StatelessWidget {
  const _Pasticca({required this.icona, required this.testo});

  final IconData icona;
  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tema.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.sm,
          vertical: Gap.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icona, size: 14, color: tema.colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              testo,
              style: tema.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
