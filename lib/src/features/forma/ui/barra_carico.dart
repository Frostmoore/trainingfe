import 'package:flutter/material.dart';

/// Il carico, come **barra con il 100% al centro** — 3b-O.4.3.
///
/// ══ 🚨 PERCHÉ IL CENTRO È IL 100% E NON LO ZERO ═══════════════════════════
///
/// 📌 Richiesta del committente il 21/08: *«la parte "carico" deve essere una
/// barra, con 100% al centro e si deve spostare a dx quando il valore è
/// superiore a 100% e a sx quando è inferiore»*.
///
/// 💡 Ed è la forma giusta per questo numero, non solo la richiesta.
/// L'`ACWR` è un **rapporto con sé stessi**: il centro non è «niente», è «come
/// al tuo solito». ⚠️ Una barra che riempie da sinistra racconterebbe una gara
/// in cui più è pieno meglio è — e qui **non è vero**: sopra il 150% è un
/// avviso, non un traguardo.
///
/// ── ⚠️ La scala si ferma, i valori no ─────────────────────────────────────
///
/// Chi riprende ad allenarsi dopo un mese può avere un `ACWR` del 400%. 🚨 Con
/// una scala che si allunga per contenerlo, il 100% smetterebbe di stare al
/// centro e la barra direbbe una cosa diversa ogni giorno. Qui la scala è fissa
/// (**50%–150%**) e i valori fuori si **appoggiano al bordo**: il numero esatto
/// è scritto sopra, la barra dice solo *da che parte* e *quanto lontano*.
class BarraCarico extends StatelessWidget {
  const BarraCarico({required this.acwr, super.key});

  /// `1.0` = il proprio abituale. `null` = non calcolabile.
  final double? acwr;

  /// Gli estremi della scala disegnata.
  static const minimo = 0.5;
  static const massimo = 1.5;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final v = acwr;

    return LayoutBuilder(
      builder: (context, vincoli) {
        final larghezza = vincoli.maxWidth;

        // 💡 La posizione in `0..1`, con i valori fuori scala appoggiati al
        // bordo invece che disegnati fuori dalla barra.
        final t = v == null
            ? 0.5
            : ((v - minimo) / (massimo - minimo)).clamp(0.0, 1.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 26,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  /*
                   * 🚨 **Le fasce colorate sono la legenda**, e stanno sotto
                   * l'indicatore invece che in una riga di testo a parte.
                   *
                   * ⚠️ Le proporzioni non sono a occhio: seguono le soglie vere
                   * di `FasciaCarico` — 0.8 e 1.3 e 1.5 — sulla scala 0.5–1.5.
                   * 💡 Una legenda disegnata che non corrisponde ai numeri è
                   * peggio di nessuna legenda.
                   */
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          // 0.5 → 0.8: sotto il proprio solito
                          Expanded(
                            flex: 30,
                            child: ColoredBox(
                              color: tema.colorScheme.primary.withValues(
                                alpha: 0.18,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          // 0.8 → 1.3: la zona in cui si sta bene
                          Expanded(
                            flex: 50,
                            child: ColoredBox(
                              color: tema.colorScheme.primary.withValues(
                                alpha: 0.45,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          // 1.3 → 1.5: in salita
                          Expanded(
                            flex: 20,
                            child: ColoredBox(
                              color: const Color(
                                0xFFE0B341,
                              ).withValues(alpha: 0.55),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 🚨 Il segno del 100%: senza, «al centro» è una cosa che
                  // sappiamo noi e non chi guarda.
                  Positioned(
                    left: larghezza / 2 - 1,
                    child: Container(
                      width: 2,
                      height: 18,
                      color: tema.colorScheme.onSurface.withValues(alpha: 0.35),
                    ),
                  ),

                  if (v != null)
                    Positioned(
                      left: (t * larghezza - 7).clamp(0.0, larghezza - 14),
                      child: Container(
                        width: 14,
                        height: 22,
                        decoration: BoxDecoration(
                          color: tema.colorScheme.primary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: tema.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 2),

            Row(
              children: [
                Text(
                  'meno del solito',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '100%',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'di più',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// La carica, come **batteria** — 3b-O.4.4.
///
/// 📌 *«la parte "Carica" deve essere una batteria più o meno carica in base al
/// livello da 0 a 100, con dentro scritto il numero»*.
///
/// 💡 È la forma che il numero già suggeriva: l'icona della scheda è una
/// batteria da sempre, e mostrare «61» accanto a una batteria disegnata piena a
/// metà è **la stessa cosa detta due volte, male**. Qui il disegno *è* il
/// numero.
class BatteriaCarica extends StatelessWidget {
  const BatteriaCarica({required this.livello, this.altezza = 64, super.key});

  /// Da `0` a `100`. `null` quando non è calcolabile.
  final double? livello;
  final double altezza;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final v = livello;

    // 💡 La quota di riempimento, al sicuro dai valori fuori scala.
    final quota = v == null ? 0.0 : (v / 100).clamp(0.0, 1.0);

    /*
     * 🚨 Il colore segue il livello, ma **senza semaforo**: rosso su una carica
     * bassa suggerirebbe un allarme medico, che è esattamente ciò che
     * l'avvertenza dice di non fare. ⚠️ Si usa il colore della palestra, più
     * spento in basso.
     */
    final colore = tema.colorScheme.primary.withValues(
      alpha: v == null ? 0.25 : (0.45 + quota * 0.55),
    );

    return SizedBox(
      width: altezza * 0.62,
      height: altezza,
      child: Column(
        children: [
          // Il polo, che è ciò che rende riconoscibile la forma.
          Container(
            width: altezza * 0.22,
            height: altezza * 0.07,
            decoration: BoxDecoration(
              color: tema.colorScheme.onSurfaceVariant,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: tema.colorScheme.onSurfaceVariant,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Stack(
                  children: [
                    // ⚠️ Si riempie **dal basso**: una batteria che si riempie
                    // dall'alto non è una batteria.
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: quota,
                        widthFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colore,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),

                    Center(
                      child: Text(
                        v == null ? '—' : v.round().toString(),
                        style: tema.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          /*
                           * 🚨 Il numero sta **dentro** la batteria, quindi
                           * finisce sopra il riempimento o sopra il vuoto a
                           * seconda del livello. ⚠️ Un colore fisso sarebbe
                           * illeggibile in uno dei due casi: qui si sceglie
                           * quello che regge su tutti e due.
                           */
                          color: tema.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
