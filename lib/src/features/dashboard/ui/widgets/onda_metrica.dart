import 'package:flutter/material.dart';

/// Una metrica degli ultimi giorni, disegnata **a onda** — 3b-O.5.3.
///
/// ══ 🚨 PERCHÉ A ONDA E NON A COLONNE ══════════════════════════════════════
///
/// 📌 Richiesta del committente il 21/08: *«variabilità cardiaca deve essere un
/// grafico, e idem battito a riposo, uno sotto l'altro (non a colonne, a
/// onda)»*.
///
/// 💡 E ha una ragione oltre al gusto: una colonna dice **quanto**, una linea
/// dice **come sta andando**. Per HRV e battito a riposo il numero singolo non
/// vuol dire quasi niente — conta il verso, e il verso lo si legge solo se i
/// punti sono uniti.
///
/// ── ⚠️ La scala parte dai dati, non da zero ───────────────────────────────
///
/// Un HRV oscilla fra 40 e 70 ms: partendo da zero, quella variazione diventa
/// una riga piatta e la scheda non dice niente. 🚨 Qui la scala è **il minimo e
/// il massimo del periodo**, con un margine — che è l'unico modo perché una
/// differenza vera si veda.
///
/// ⚠️ **Ed è un grafico senza numeri sugli assi, di proposito**: dice l'andamento
/// e basta. Chi vuole il numero ha quello grande accanto, e chi vuole la storia
/// ha la pagina del sonno.
class OndaMetrica extends StatelessWidget {
  const OndaMetrica({
    required this.valori,
    required this.colore,
    this.altezza = 34,
    super.key,
  });

  /// Dal **più vecchio al più recente**.
  ///
  /// ⚠️ L'ordine conta e invertirlo darebbe un disegno plausibile e sbagliato:
  /// una risalita sembrerebbe una discesa.
  final List<double> valori;

  final Color colore;
  final double altezza;

  @override
  Widget build(BuildContext context) {
    // 💡 Con meno di due punti non c'è una linea da disegnare: si sparisce
    // invece di mostrare un puntino solo, che sembrerebbe un guasto.
    if (valori.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: altezza,
      width: double.infinity,
      child: CustomPaint(
        painter: _Pennello(valori: valori, colore: colore),
      ),
    );
  }
}

class _Pennello extends CustomPainter {
  const _Pennello({required this.valori, required this.colore});

  final List<double> valori;
  final Color colore;

  @override
  void paint(Canvas tela, Size misura) {
    final minimo = valori.reduce((a, b) => a < b ? a : b);
    final massimo = valori.reduce((a, b) => a > b ? a : b);

    /*
     * 🚨 **Un intervallo zero va gestito, o è una divisione per zero.**
     *
     * Succede davvero: sette giorni con lo stesso battito a riposo non sono
     * un'ipotesi di laboratorio. ⚠️ In quel caso la linea va **in mezzo**, che
     * è la verità — non è cambiato niente.
     */
    final intervallo = massimo - minimo;
    final piatta = intervallo <= 0;

    final passo = misura.width / (valori.length - 1);

    double y(double v) => piatta
        ? misura.height / 2
        : misura.height - ((v - minimo) / intervallo) * misura.height;

    final linea = Path()..moveTo(0, y(valori.first));

    for (var i = 1; i < valori.length; i++) {
      /*
       * 💡 Curva e non spezzata: `quadraticBezierTo` con il controllo a metà
       * strada arrotonda gli angoli senza inventare punti che non ci sono.
       * ⚠️ Le curve più morbide (Catmull-Rom) **superano** i valori veri sui
       * picchi, e su un dato di salute è una bugia disegnata.
       */
      final xPrec = passo * (i - 1);
      final x = passo * i;
      final meta = (xPrec + x) / 2;

      linea.cubicTo(
        meta,
        y(valori[i - 1]),
        meta,
        y(valori[i]),
        x,
        y(valori[i]),
      );
    }

    // La sfumatura sotto la linea: dà il verso della lettura senza aggiungere
    // inchiostro dove servono i dati.
    final sotto = Path.from(linea)
      ..lineTo(misura.width, misura.height)
      ..lineTo(0, misura.height)
      ..close();

    tela.drawPath(
      sotto,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colore.withValues(alpha: 0.22), colore.withValues(alpha: 0)],
        ).createShader(Offset.zero & misura),
    );

    tela.drawPath(
      linea,
      Paint()
        ..color = colore
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // 💡 Il pallino sull'ultimo punto: dice **dove sei adesso** su una linea che
    // altrimenti finisce e basta.
    tela.drawCircle(
      Offset(misura.width, y(valori.last)),
      3,
      Paint()..color = colore,
    );
  }

  @override
  bool shouldRepaint(_Pennello vecchio) =>
      vecchio.colore != colore || !identical(vecchio.valori, valori);
}
