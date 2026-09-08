import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../health/salute_in_piu.dart';

/// 🗺️ La forma di un percorso, disegnata — 08/09/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// Il committente: *«se non metto la foto, al posto di quella nella schermata
/// dello storico degli allenamenti ci deve essere **la forma del percorso** che
/// ho fatto»*.
///
/// ══ ⛔ LA FORMA, NON UNA MAPPA ════════════════════════════════════════════
///
/// 🚨 **Niente tessere, niente rete, nessuna chiave.** Una mappa vera vorrebbe
/// dire un servizio esterno a cui dire *dove è stata una persona* — cioè
/// mandare fuori dal telefono il dato più sensibile che abbiamo, per decorare
/// una miniatura.
///
/// 💡 E per riconoscere un'uscita la forma basta: il giro dell'isolato e la
/// salita al paese non si somigliano. ⚠️ Chi guarda una card di 150 px non sta
/// leggendo i nomi delle strade.
///
/// ⛔ **Vale anche se un domani si vorrà una mappa vera**: allora si deciderà
/// dove mandare i dati e lo si scriverà nell'informativa. Non è una cosa che si
/// aggiunge «già che ci siamo».
class FormaDelPercorso extends StatelessWidget {
  const FormaDelPercorso({
    required this.punti,
    this.spessore = 2.5,
    this.colore,
    super.key,
  });

  final List<PuntoDelPercorso> punti;
  final double spessore;
  final Color? colore;

  @override
  Widget build(BuildContext context) {
    if (punti.length < 2) return const SizedBox.shrink();

    return CustomPaint(
      painter: _Tracciato(
        punti: punti,
        colore: colore ?? Theme.of(context).colorScheme.primary,
        spessore: spessore,
      ),
      size: Size.infinite,
    );
  }
}

class _Tracciato extends CustomPainter {
  _Tracciato({
    required this.punti,
    required this.colore,
    required this.spessore,
  });

  final List<PuntoDelPercorso> punti;
  final Color colore;
  final double spessore;

  @override
  void paint(Canvas tela, Size misura) {
    if (misura.isEmpty) return;

    /*
     * ══ 🚨 LA CORREZIONE DEL COSENO, E PERCHE' NON E' PIGNOLERIA ═══════════
     *
     * Un grado di **latitudine** vale sempre ~111 km. Un grado di
     * **longitudine** vale 111 km all'equatore e **zero** ai poli: alle nostre
     * latitudini circa 111 × cos(45°) ≈ 78 km.
     *
     * ⛔ Disegnare lat e lon come se fossero x e y schiaccia il percorso in
     * orizzontale del 30%: un giro quadrato dell'isolato diventerebbe un
     * rettangolo, e una salita dritta sembrerebbe storta.
     *
     * 💡 Si moltiplica la longitudine per il coseno della latitudine media: è
     * la proiezione equirettangolare, ed è esatta abbastanza su qualche
     * chilometro — che è tutto quello che un allenamento copre.
     */
    final latMedia =
        punti.map((p) => p.latitudine).reduce((a, b) => a + b) / punti.length;

    final coseno = math.cos(latMedia * math.pi / 180);

    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;

    final grezzi = <Offset>[];

    for (final p in punti) {
      // ⚠️ La latitudine cresce verso NORD, la y dello schermo verso il BASSO:
      // il segno meno è quello che tiene il nord in alto.
      final x = p.longitudine * coseno;
      final y = -p.latitudine;

      grezzi.add(Offset(x, y));

      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    final larghezza = maxX - minX;
    final altezza = maxY - minY;

    // ⛔ Un percorso fermo — o un solo punto ripetuto — non ha una forma: non si
    // disegna un puntino ingrandito a tutta card.
    if (larghezza <= 0 && altezza <= 0) return;

    final bordo = spessore * 2;
    final utileX = math.max(1.0, misura.width - bordo * 2);
    final utileY = math.max(1.0, misura.height - bordo * 2);

    /*
     * 🚨 **Una scala sola per i due assi.** Scalarli separatamente riempirebbe
     * meglio il riquadro e **cambierebbe la forma**: un percorso lungo e stretto
     * diventerebbe tondo, e la cosa che si sta mostrando è proprio la forma.
     */
    final scala = math.min(
      larghezza > 0 ? utileX / larghezza : double.infinity,
      altezza > 0 ? utileY / altezza : double.infinity,
    );

    // 💡 Centrato: un tracciato appiccicato in un angolo sembra tagliato.
    final scartoX = (misura.width - larghezza * scala) / 2;
    final scartoY = (misura.height - altezza * scala) / 2;

    final tratto = Path();

    for (var i = 0; i < grezzi.length; i++) {
      final punto = Offset(
        (grezzi[i].dx - minX) * scala + scartoX,
        (grezzi[i].dy - minY) * scala + scartoY,
      );

      if (i == 0) {
        tratto.moveTo(punto.dx, punto.dy);
      } else {
        tratto.lineTo(punto.dx, punto.dy);
      }
    }

    tela.drawPath(
      tratto,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = spessore
        ..strokeCap = StrokeCap.round
        // 💡 `round` anche sulle giunzioni: un percorso ha centinaia di angoli, e
        // con le giunzioni squadrate ogni curva diventa una scaletta.
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true
        ..color = colore,
    );
  }

  @override
  bool shouldRepaint(_Tracciato vecchio) =>
      vecchio.punti != punti ||
      vecchio.colore != colore ||
      vecchio.spessore != spessore;
}
