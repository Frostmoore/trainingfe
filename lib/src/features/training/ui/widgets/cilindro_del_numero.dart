/// Il numero che arriva scorrendo, come un cilindro — 3b-B.14, 24/08/2026.
///
/// 📌 Il committente: *«si deve vedere tipo "cilindro" con vicino altri due o
/// tre numeri, e quando appare deve fare tipo l'animazione di un cilindro che si
/// ferma lì con un po' di bezier (diciamo tipo elastico)»* e poi, correggendo:
/// *«il cilindro deve scorrere in **orizzontale**, per quello ho detto rettangolo
/// bianco»*.
///
/// ══ ⚠️ ORIZZONTALE, E IL RETTANGOLO ERA LA SPECIFICA ══════════════════════
///
/// 🚨 **Al primo tentativo scorreva in verticale**, e la forma del contenitore
/// diceva già che era sbagliato: un cilindro verticale sta bene in un quadrato o
/// in una finestra alta e stretta, e chiedere un **rettangolo largo** vuol dire
/// che i vicini stanno a destra e a sinistra. ⛔ La richiesta conteneva la
/// risposta e non l'ho letta.
///
/// 💡 I numeri più bassi stanno **a sinistra**, i più alti a destra: il nastro
/// scorre verso sinistra e quello buono **arriva da destra**, come un contatore
/// che sale. Al contrario sembrerebbe che il conteggio scenda.
///
/// ══ 💡 PERCHÉ I VICINI SONO IL PEZZO CHE CONTA ════════════════════════════
///
/// 🚨 Senza i numeri accanto, un numero che si ferma è solo un numero che
/// compare: l'animazione non si capirebbe da dove viene. ⛔ Sono i vicini
/// sbiaditi ai lati a dire **che cosa è quell'oggetto** — un nastro che scorre —
/// e quindi a far leggere il movimento come un arresto invece che come un
/// effetto decorativo.
///
/// ── ⚠️ L'elastico deve sforare, o non è un elastico ───────────────────────
///
/// `Curves.elasticOut` **supera** il valore d'arrivo e ci torna sopra. È quello
/// che fa sembrare l'oggetto pesante, e il motivo per cui la richiesta diceva
/// *«tipo elastico»* e non «una dissolvenza».
///
/// ── ⛔ E chi le animazioni le ha spente ───────────────────────────────────
///
/// 🚨 `MediaQuery.disableAnimationsOf` non è un dettaglio di accessibilità da
/// spuntare: chi lo attiva spesso lo fa perché il movimento gli dà **fastidio
/// fisico**. Lì il numero c'è e basta, senza scorrimento e senza rimbalzo.
library;

import 'package:flutter/material.dart';

class CilindroDelNumero extends StatefulWidget {
  const CilindroDelNumero({
    required this.valore,
    required this.passo,
    this.stile,
    this.stileVicini,
    super.key,
  });

  final int valore;

  /// Quanto è **larga** una posizione: è il passo del nastro.
  final double passo;

  final TextStyle? stile;
  final TextStyle? stileVicini;

  /// Quanti numeri si vedono **a destra e a sinistra** di quello buono.
  ///
  /// 📌 *«con vicino altri due o tre numeri»*: due per parte, quindi quattro in
  /// tutto. ⚠️ Tre per parte a questa dimensione escono dal rettangolo, e un
  /// cilindro che sborda sembra un difetto di disegno.
  static const quantiVicini = 2;

  /// Da quanto più indietro parte lo scorrimento.
  ///
  /// ⚠️ Sei e non venti: un nastro che scorre mezzo secondo è un'animazione,
  /// uno che scorre due secondi è un'attesa. ⛔ E qui non si sta caricando
  /// niente — il numero si sa già.
  static const daQuantoParte = 6;

  @override
  State<CilindroDelNumero> createState() => _CilindroDelNumeroState();
}

class _CilindroDelNumeroState extends State<CilindroDelNumero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motore = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  late Animation<double> _dove = _versoIlValore();

  Animation<double> _versoIlValore() => Tween<double>(
    begin: (widget.valore - CilindroDelNumero.daQuantoParte).toDouble(),
    end: widget.valore.toDouble(),
  ).animate(CurvedAnimation(parent: _motore, curve: Curves.elasticOut));

  @override
  void initState() {
    super.initState();
    _motore.forward();
  }

  @override
  void didUpdateWidget(CilindroDelNumero vecchio) {
    super.didUpdateWidget(vecchio);

    /*
     * 💡 Il nastro riparte **solo se il numero cambia davvero**. ⛔ Rifarlo a
     * ogni ridisegno vorrebbe dire un'animazione che riparte quando si scorre la
     * pagina o cambia un'altra card: fastidiosa, e per giunta senza motivo.
     */
    if (vecchio.valore == widget.valore) return;

    _dove = _versoIlValore();
    _motore.forward(from: 0);
  }

  @override
  void dispose() {
    _motore.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final stile =
        widget.stile ??
        tema.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900);

    final stileVicini =
        widget.stileVicini ??
        stile?.copyWith(color: tema.colorScheme.onSurfaceVariant);

    // ⛔ Chi ha spento le animazioni vede il numero e basta.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Center(
        child: FittedBox(child: Text('${widget.valore}', style: stile)),
      );
    }

    /*
     * ⚠️ **`ClipRect` è obbligatorio**: senza, i numeri dello scorrimento escono
     * dal rettangolo bianco e si vedono correre sopra le pasticche e il grafico.
     */
    return ClipRect(
      child: AnimatedBuilder(
        animation: _dove,
        builder: (context, _) {
          final centro = _dove.value;
          const vicini = CilindroDelNumero.quantiVicini;
          final primo = (centro - vicini).floor();
          final ultimo = (centro + vicini).ceil();

          return Stack(
            alignment: Alignment.center,
            children: [
              for (var n = primo; n <= ultimo; n++)
                /*
                 * ⛔ Niente numeri negativi: un nastro che passa da «-2» mentre
                 * scorre verso «3» racconta una cosa che non esiste.
                 */
                if (n >= 0)
                  _Cifra(
                    numero: n,
                    scarto: n - centro,
                    passo: widget.passo,
                    stile: (n == widget.valore ? stile : stileVicini),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.numero,
    required this.scarto,
    required this.passo,
    required this.stile,
  });

  final int numero;

  /// Quanto dista dal centro, in posizioni. Negativo = a sinistra.
  final double scarto;

  final double passo;
  final TextStyle? stile;

  @override
  Widget build(BuildContext context) {
    final distanza = scarto.abs();

    /*
     * 💡 **Sbiadiscono e si rimpiccioliscono insieme**: la sola trasparenza fa
     * sembrare i vicini scritti male, la sola scala li fa sembrare un altro
     * dato. Tutte e due insieme li fanno leggere come **lo stesso oggetto visto
     * di lato**, che è quello che un cilindro fa.
     */
    final quanto = (1 - distanza / 2.2).clamp(0.0, 1.0);

    return Transform.translate(
      // ⚠️ Sull'asse X: è la riga che rende orizzontale tutto il resto.
      offset: Offset(scarto * passo, 0),
      child: Opacity(
        opacity: 0.06 + quanto * 0.94,
        child: Transform.scale(
          scale: 0.45 + quanto * 0.55,
          child: SizedBox(
            width: passo,
            child: FittedBox(child: Text('$numero', style: stile)),
          ),
        ),
      ),
    );
  }
}
