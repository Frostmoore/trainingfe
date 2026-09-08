import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/gate_dell_abbonamento.dart';
import '../modale_acquisti.dart';

/// 🔒 Una card che chi non è abbonato **vede sfumata** — 08/09/2026.
///
/// ══ 📌 LA RICHIESTA, E IL CAMBIO DI REGOLA ════════════════════════════════
///
/// Il committente: *«Le cards devono rimanere visibili ma offuscate (per far
/// capire che manca qualcosa)»*.
///
/// ⚠️ **Ribalta la regola del 26/08**, che diceva *«verbi, non viste: chiudere
/// un grafico che c'era ieri si legge come un furto»*. 🚨 È una decisione presa
/// sapendolo — *«è vero questa era la mia regola, ma ho cambiato idea»* — e sta
/// scritta qui perché chi legge questo file non concluda che la regola vecchia
/// sia stata dimenticata.
///
/// ── 🚨 Perché `ImageFiltered` e non `Opacity` ─────────────────────────────
///
/// 💡 È la stessa scelta già fatta in `ProgressoDellEsercizio`: un testo
/// trasparente **resta leggibile** — si seleziona, lo legge lo screen reader,
/// si legge inclinando lo schermo. Non sarebbe un limite, sarebbe un limite
/// finto. ⛔ E un limite finto è peggio di nessun limite: chi lo scopre non
/// pensa «ho trovato un trucco», pensa «mi stavano prendendo in giro».
class SottoAbbonamento extends ConsumerWidget {
  const SottoAbbonamento({required this.child, this.motivo, super.key});

  final Widget child;

  /// Cosa si sblocca, per **chi non vede lo schermo**.
  ///
  /// ══ ⚠️ NON È PIÙ IL TESTO DEL PULSANTE — 08/09/2026, secondo giro ══════
  ///
  /// 📌 Il committente, guardandolo a schermo: *«Non mi piace quel "tasto" col
  /// nome della card. Scrivici "Sblocca" che è più carino e più intuitivo»*.
  ///
  /// ⛔ **Aveva ragione, e il motivo è più profondo di come suona.** Il nome
  /// della card era scritto **due volte a tre centimetri di distanza** — sulla
  /// card, sfumato, e sul pulsante, nitido. 🚨 Un pulsante deve dire cosa
  /// **fa**, non ripetere accanto a cosa sta.
  ///
  /// 💡 Il nome resta qui, e serve ancora: è quello che lo screen reader legge,
  /// perché lì la card sfumata sopra non c'è.
  final String? motivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(abbonatoProvider)) return child;

    final tema = Theme.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: AbsorbPointer(
            child: Stack(
              children: [
                /*
                 * ══ 🚨 SFUMATURA FORTE, E POI UN VELO — secondo giro ═══════
                 *
                 * 📌 *«così com'è ora si vedono comunque i dati, un non
                 * abbonato capisce lo stesso il livello di carica ad esempio,
                 * o la prontezza»*.
                 *
                 * ⛔ **A `sigma: 5` i numeri grandi restavano leggibili.** È il
                 * difetto peggiore che questo widget potesse avere: sembra un
                 * limite e non lo è, e chi legge il 72 della carica attraverso
                 * la sfumatura ha esattamente quello per cui gli si chiedeva
                 * di pagare.
                 *
                 * 💡 **Due cose insieme, e nessuna delle due basta da sola**:
                 * a `sigma: 16` un numero enorme è ancora una macchia che si
                 * indovina, e un velo da solo si «legge attraverso»
                 * schiarendo lo schermo. Sfumato **e** velato non si recupera
                 * in nessun modo.
                 *
                 * ⚠️ `decal`: senza, la sfumatura ripete i pixel del bordo e la
                 * card sembra sporca invece che coperta.
                 */
                ImageFiltered(
                  imageFilter: ui.ImageFilter.blur(
                    sigmaX: 16,
                    sigmaY: 16,
                    tileMode: TileMode.decal,
                  ),
                  child: child,
                ),

                /*
                 * 🎭 Il velo prende **la forma della card che copre**: senza il
                 * `Positioned.fill` sarebbe un rettangolo, e sugli angoli
                 * arrotondati si vedrebbe lo spigolo.
                 */
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tema.colorScheme.surface.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(Gap.radius),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        /*
         * 🔒 **Il lucchetto è un pulsante, non una decorazione.**
         *
         * ⛔ Una card sfumata senza niente da toccare lascia una sola strada:
         * cercare da qualche altra parte cosa è successo. 💡 Qui il tocco porta
         * dove si risolve.
         */
        Semantics(
          button: true,
          label: motivo == null
              ? 'Sblocca con l\'abbonamento'
              : 'Sblocca $motivo con l\'abbonamento',
          child: Material(
            color: tema.colorScheme.surface,
            shape: const StadiumBorder(),
            elevation: 2,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => ModaleAcquisti.mostra(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_open_rounded,
                      size: 18,
                      color: tema.colorScheme.primary,
                    ),
                    const SizedBox(width: Gap.sm),
                    Text(
                      'Sblocca',
                      style: tema.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tema.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 💳 Il banner che spiega perché cinque card sono sfumate — 08/09/2026.
///
/// 📌 *«sotto alla card delle calorie iniziale, ci va un banner che propone di
/// abbonarsi per sbloccare le analisi avanzate dei propri dati»*, e al secondo
/// giro: *«mettici un po' di sfumatura sul colore di sfondo, e fai in modo che
/// si muova un po' come se brillasse. Deve catturare l'attenzione»*.
///
/// ══ 🚨 STA SOTTO LE CALORIE, E IL POSTO È IL MESSAGGIO ════════════════════
///
/// 💡 La card delle calorie è l'unica cosa **completa** che un non abbonato
/// vede: sopra di lei il banner sembrerebbe un annuncio prima del prodotto,
/// sotto di lei arriva **dopo** che l'app ha già dato qualcosa.
///
/// ⛔ **Sparisce per gli abbonati**, e non «si spegne»: chi ha pagato non deve
/// vedere nemmeno lo spazio dove stava.
class BannerAbbonamento extends ConsumerStatefulWidget {
  const BannerAbbonamento({super.key});

  @override
  ConsumerState<BannerAbbonamento> createState() => _BannerAbbonamentoState();
}

class _BannerAbbonamentoState extends ConsumerState<BannerAbbonamento>
    with SingleTickerProviderStateMixin {
  /// ⚠️ **Tre secondi e mezzo, non uno.** Un luccichio veloce su una schermata
  /// che si legge diventa un tic nervoso a bordo campo visivo: cattura
  /// l'attenzione la prima volta e infastidisce dalla terza.
  ///
  /// ══ 🚨 NASCE IN `initState`, E IL PERCHÉ È UN DIFETTO VERO ══════════════
  ///
  /// ⛔ **Prima era `late final … = AnimationController(…)`**, cioè creato al
  /// primo uso. 🚨 Per un abbonato il primo uso non arriva mai — `build` esce
  /// subito con `SizedBox.shrink()` — e allora l'unico a toccarlo era
  /// `dispose()`: il controllore **nasceva dentro il proprio smontaggio**,
  /// chiedendo un `vsync` a uno `State` già staccato.
  ///
  /// ⚠️ *«Looking up a deactivated widget's ancestor is unsafe»*, e l'ha
  /// trovato un test — non lo schermo: a schermo sarebbe successo solo
  /// **chiudendo** la pagina da abbonato, cioè nel momento in cui uno non
  /// guarda più.
  late final AnimationController _controllore;

  @override
  void initState() {
    super.initState();
    _controllore = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );
  }

  @override
  void dispose() {
    _controllore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(abbonatoProvider)) {
      // 💡 Chi si abbona mentre guarda la pagina: il banner sparisce, e con lui
      // deve fermarsi il ticker — o continuerebbe a chiedere fotogrammi per
      // disegnare niente.
      if (_controllore.isAnimating) _controllore.stop();

      return const SizedBox.shrink();
    }

    final tema = Theme.of(context);

    /*
     * ══ ♿ CHI HA CHIESTO MENO MOVIMENTO NON LO RICEVE ═══════════════════════
     *
     * 🚨 `disableAnimations` è acceso da chi soffre di **cinetosi** o ha
     * disturbi vestibolari: per quelle persone un luccichio che scorre in
     * continuo su una schermata che stanno leggendo non è vivace, è nausea.
     *
     * 💡 Il banner resta comunque **sfumato e ben visibile**: si perde il
     * movimento, non l'attenzione che deve catturare.
     */
    final fermo = MediaQuery.disableAnimationsOf(context);

    /*
     * ⚠️ **Avviare qui e non in `initState`**: se il movimento è disattivato,
     * o se chi guarda è abbonato, il ticker non deve partire affatto — e
     * `initState` non sa ancora né l'una né l'altra cosa.
     *
     * 💡 `repeat()` non chiama `setState`: mette in coda un fotogramma, che è
     * esattamente quello che questo `build` sta già producendo.
     */
    if (!fermo && !_controllore.isAnimating) _controllore.repeat();

    final contenuto = Padding(
      padding: const EdgeInsets.all(Gap.md),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome_rounded,
            color: tema.colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sblocca le analisi dei tuoi dati',
                  style: tema.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tema.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 2),

                /*
                 * ⚠️ **Elenca le cinque card per nome**, e non dice «e altro».
                 * 🚨 Un banner che promette genericamente «più funzioni»
                 * costringe a scorrere per capire cosa manca — cioè fa fare
                 * alla persona il lavoro di chi vende.
                 */
                Text(
                  'Spunto di oggi, carico e carica, recupero, com\'è fatto e i '
                  'tuoi allenamenti. I dati restano tuoi: l\'abbonamento apre '
                  'le letture, non i numeri.',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Icon(
            Icons.chevron_right_rounded,
            color: tema.colorScheme.onPrimaryContainer,
          ),
        ],
      ),
    );

    return Card(
      // 🚨 `clipBehavior`: il gradiente esce dagli angoli arrotondati se la
      // card non ritaglia quello che ha dentro.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ModaleAcquisti.mostra(context),
        child: fermo
            ? DecoratedBox(
                decoration: BoxDecoration(gradient: _fondo(tema, 0.5)),
                child: contenuto,
              )
            : AnimatedBuilder(
                animation: _controllore,
                // 💡 `child` costruito **una volta**: il testo non cambia a
                // ogni fotogramma, e ricostruirlo sessanta volte al secondo
                // sarebbe lavoro buttato su una schermata che scorre.
                child: contenuto,
                builder: (context, figlio) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _fondo(tema, _controllore.value),
                  ),
                  child: figlio,
                ),
              ),
      ),
    );
  }

  /// Il fondo sfumato, con la luce che ci passa sopra.
  ///
  /// ══ 💡 COME È FATTO IL LUCCICHIO ══════════════════════════════════════════
  ///
  /// ⛔ **Non è un'opacità che pulsa**: quella lampeggia, e un lampeggio su una
  /// schermata di dati sembra un allarme. 🚨 Qui a muoversi sono le **fermate**
  /// del gradiente — una banda chiara che attraversa il banner da sinistra a
  /// destra, come la luce su una superficie lucida.
  ///
  /// ⚠️ `t` va da 0 a 1 e la banda parte **fuori** dal banner (`-0.3`) e finisce
  /// **fuori** (`1.3`): così non compare e non svanisce a metà: entra da un
  /// bordo ed esce dall'altro.
  LinearGradient _fondo(ThemeData tema, double t) {
    final c = tema.colorScheme;
    final centro = -0.3 + t * 1.6;

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      // 🚨 `clamp` sulle fermate: `LinearGradient` pretende che siano ordinate
      // e dentro [0, 1], e senza lancia proprio mentre l'animazione entra o
      // esce dal bordo — cioè due volte a giro.
      stops: [
        (centro - 0.25).clamp(0.0, 1.0),
        centro.clamp(0.0, 1.0),
        (centro + 0.25).clamp(0.0, 1.0),
      ],
      colors: [
        c.primaryContainer,
        // 💡 Il colore della luce è il `primary` **molto diluito**: un bianco
        // secco stonerebbe con il tema di ogni palestra white-label.
        Color.alphaBlend(c.primary.withValues(alpha: 0.22), c.primaryContainer),
        c.primaryContainer,
      ],
    );
  }
}
