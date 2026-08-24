/// Il numero che arriva girando, come un cilindro — 3b-B.14, 24/08/2026.
///
/// 📌 Il committente: *«si deve vedere tipo "cilindro" con vicino altri due o
/// tre numeri, e quando appare deve fare tipo l'animazione di un cilindro che si
/// ferma lì con un po' di bezier (diciamo tipo elastico)»*.
///
/// ══ 💡 PERCHÉ I VICINI SONO IL PEZZO CHE CONTA ════════════════════════════
///
/// 🚨 Senza i numeri accanto, un numero che si ferma è solo un numero che
/// compare: l'animazione non si capirebbe da dove viene. ⛔ Sono i vicini
/// sbiaditi sopra e sotto a dire **che cosa è quell'oggetto** — un cilindro che
/// gira — e quindi a far leggere il movimento come un arresto invece che come un
/// effetto decorativo.
///
/// ── ⚠️ L'elastico deve sforare, o non è un elastico ───────────────────────
///
/// `Curves.elasticOut` **supera** il valore d'arrivo e ci torna sopra. È quello
/// che fa sembrare l'oggetto pesante, e il motivo per cui la richiesta diceva
/// *«tipo elastico»* e non «una dissolvenza».
///
/// 💡 Sfora **verso il basso**, cioè scoprendo i numeri più bassi: parte da
/// sotto e sale, come una slot che rallenta. Partire da sopra farebbe *scendere*
/// il conteggio, che per un numero di sessioni è il verso sbagliato.
///
/// ── ⛔ E chi le animazioni le ha spente ───────────────────────────────────
///
/// 🚨 `MediaQuery.disableAnimationsOf` non è un dettaglio di accessibilità da
/// spuntare: chi lo attiva spesso lo fa perché il movimento gli dà **fastidio
/// fisico**. Lì il numero c'è e basta, senza giro e senza rimbalzo.
library;

import 'package:flutter/material.dart';

class CilindroDelNumero extends StatefulWidget {
  const CilindroDelNumero({
    required this.valore,
    required this.altezzaCifra,
    this.stile,
    this.stileVicini,
    super.key,
  });

  final int valore;

  /// Quanto è alta una cifra: è il passo del cilindro.
  final double altezzaCifra;

  final TextStyle? stile;
  final TextStyle? stileVicini;

  /// Quanti numeri si vedono **sopra e sotto** quello buono.
  ///
  /// 📌 *«con vicino altri due o tre numeri»*: due per parte, quindi quattro in
  /// tutto. ⚠️ Tre per parte a questa dimensione escono dal rettangolo, e un
  /// cilindro che sborda sembra un difetto di disegno.
  static const quantiVicini = 2;

  /// Da quanto più in basso parte il giro.
  ///
  /// ⚠️ Sei e non venti: un cilindro che gira mezzo secondo è un'animazione,
  /// uno che gira due secondi è un'attesa. ⛔ E qui non si sta caricando niente
  /// — il numero si sa già.
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
     * 💡 Il cilindro rigira **solo se il numero cambia davvero**. ⛔ Rifarlo a
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
    const vicini = CilindroDelNumero.quantiVicini;
    final altezza = widget.altezzaCifra * (vicini * 2 + 1);

    final stile =
        widget.stile ??
        tema.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900);

    final stileVicini =
        widget.stileVicini ??
        stile?.copyWith(color: tema.colorScheme.onSurfaceVariant);

    // ⛔ Chi ha spento le animazioni vede il numero e basta.
    if (MediaQuery.disableAnimationsOf(context)) {
      return SizedBox(
        height: altezza,
        child: Center(
          child: FittedBox(child: Text('${widget.valore}', style: stile)),
        ),
      );
    }

    return SizedBox(
      height: altezza,

      /*
       * ⚠️ **`ClipRect` è obbligatorio**: senza, i numeri del giro escono dal
       * rettangolo bianco e si vedono correre sopra il titolo della card.
       */
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _dove,
          builder: (context, _) {
            final centro = _dove.value;
            final primo = (centro - vicini).floor();
            final ultimo = (centro + vicini).ceil();

            return Stack(
              alignment: Alignment.center,
              children: [
                for (var n = primo; n <= ultimo; n++)
                  /*
                   * ⛔ Niente numeri negativi: un cilindro che passa da «-2»
                   * mentre sale verso «3» racconta una cosa che non esiste.
                   */
                  if (n >= 0)
                    _Cifra(
                      numero: n,
                      scarto: n - centro,
                      altezzaCifra: widget.altezzaCifra,
                      stile: (n == widget.valore ? stile : stileVicini),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.numero,
    required this.scarto,
    required this.altezzaCifra,
    required this.stile,
  });

  final int numero;

  /// Quanto dista dal centro, in cifre. Negativo = sopra.
  final double scarto;

  final double altezzaCifra;
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
      offset: Offset(0, -scarto * altezzaCifra),
      child: Opacity(
        opacity: 0.06 + quanto * 0.94,
        child: Transform.scale(
          scale: 0.45 + quanto * 0.55,
          child: SizedBox(
            height: altezzaCifra,
            child: FittedBox(child: Text('$numero', style: stile)),
          ),
        ),
      ),
    );
  }
}
