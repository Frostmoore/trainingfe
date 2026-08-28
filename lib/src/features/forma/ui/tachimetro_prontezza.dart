/// Il tachimetro della Prontezza — 3b-K, 28/08/2026.
///
/// ══ 📌 PERCHÉ NON PIÙ UNA BATTERIA ════════════════════════════════════════
///
/// 📌 Il committente: *«la parte della "Carica" non sia una batteria ma una
/// specie di orologio con il 50 all'apice, perché a ben vedere non analizza la
/// carica vera e propria, ma quanto sto bene o male rispetto al solito, che è
/// 50, quindi il "tachimetro" è più adatto a rappresentarla»*.
///
/// ⛔ **Una batteria mente su questo numero.** Una batteria al 50% dice «sei a
/// metà, stai finendo»; questo numero al 50 dice **«sei esattamente nella tua
/// norma»**, che è il posto migliore in cui stare. 🚨 La forma diceva una cosa
/// diversa dal contenuto, ed è il tipo di errore che nessuno legge come un
/// errore.
///
/// 💡 Con l'ago in cima al 50, la lettura è immediata e **senza semaforo**: a
/// destra si sta sopra il proprio solito, a sinistra sotto. ⚠️ Né l'uno né
/// l'altro è «giusto» — sopra il solito può voler dire riposato, ma anche che
/// ieri non ci si è allenati.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

class TachimetroProntezza extends StatelessWidget {
  const TachimetroProntezza({required this.valore, this.lato = 96, super.key});

  /// Da `0` a `100`, con **50 al centro**. `null` quando non è calcolabile.
  final double? valore;

  final double lato;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return SizedBox(
      width: lato,

      // 💡 Un semicerchio: l'altezza è poco più della metà del lato, e lo spazio
      // sotto ospita il numero.
      height: lato * 0.66,
      child: CustomPaint(
        painter: _Quadrante(
          valore: valore,
          arco: tema.colorScheme.primary.withValues(alpha: 0.18),
          ago: valore == null
              ? tema.colorScheme.outline
              : tema.colorScheme.primary,
          tacche: tema.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                valore == null ? '—' : valore!.round().toString(),
                style: tema.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: valore == null
                      ? tema.colorScheme.outline
                      : tema.colorScheme.primary,
                  height: 1,
                ),
              ),

              /*
               * 💡 **«50 = normale» sta scritto sotto il numero**, non solo
               * disegnato sul quadrante: il 50 in cima è un aiuto per chi
               * guarda la forma, questa riga è per chi legge il numero e basta.
               */
              Text(
                '50 è il tuo normale',
                style: tema.textTheme.labelSmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Quadrante extends CustomPainter {
  const _Quadrante({
    required this.valore,
    required this.arco,
    required this.ago,
    required this.tacche,
  });

  final double? valore;
  final Color arco;
  final Color ago;
  final Color tacche;

  /// 🚨 **Mezzo giro esatto**, da sinistra a destra: è ciò che mette il 50
  /// **in cima**. ⛔ Un arco più stretto o più largo sposterebbe l'apice su un
  /// altro numero, e il senso della figura si perderebbe.
  static const _inizio = math.pi;
  static const _ampiezza = math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final spessore = size.width * 0.11;
    final raggio = (size.width - spessore) / 2;

    // 💡 Il centro sta **in basso**: il semicerchio è la metà di sopra.
    final centro = Offset(size.width / 2, size.height - spessore * 0.4);
    final rettangolo = Rect.fromCircle(center: centro, radius: raggio);

    canvas.drawArc(
      rettangolo,
      _inizio,
      _ampiezza,
      false,
      Paint()
        ..color = arco
        ..style = PaintingStyle.stroke
        ..strokeWidth = spessore
        ..strokeCap = StrokeCap.round,
    );

    /*
     * ⚠️ **Le tacche a 0, 50 e 100**, e quella del 50 più lunga: è l'unica
     * informazione che il quadrante deve dare da solo. ⛔ Una scala con undici
     * tacche inviterebbe a leggere il numero esatto dalla figura, che è
     * esattamente la precisione che questo indice non ha.
     */
    for (final t in [0.0, 0.5, 1.0]) {
      final centrale = t == 0.5;
      final angolo = _inizio + _ampiezza * t;

      final da = Offset(
        centro.dx + math.cos(angolo) * (raggio - spessore * 0.5),
        centro.dy + math.sin(angolo) * (raggio - spessore * 0.5),
      );

      final a = Offset(
        centro.dx + math.cos(angolo) * (raggio + spessore * (centrale ? 0.7 : 0.5)),
        centro.dy + math.sin(angolo) * (raggio + spessore * (centrale ? 0.7 : 0.5)),
      );

      canvas.drawLine(
        da,
        a,
        Paint()
          ..color = tacche
          ..strokeWidth = centrale ? 2.2 : 1.4
          ..strokeCap = StrokeCap.round,
      );
    }

    final v = valore;

    // ⛔ Senza valore l'ago **non si disegna**: un ago fermo a sinistra direbbe
    // «zero», che è una conclusione. Resta il quadrante vuoto e il trattino.
    if (v == null) return;

    final quota = (v / 100).clamp(0.0, 1.0);
    final angolo = _inizio + _ampiezza * quota;

    canvas.drawLine(
      centro,
      Offset(
        centro.dx + math.cos(angolo) * raggio * 0.82,
        centro.dy + math.sin(angolo) * raggio * 0.82,
      ),
      Paint()
        ..color = ago
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(centro, spessore * 0.42, Paint()..color = ago);
  }

  @override
  bool shouldRepaint(_Quadrante vecchio) =>
      vecchio.valore != valore || vecchio.ago != ago;
}
