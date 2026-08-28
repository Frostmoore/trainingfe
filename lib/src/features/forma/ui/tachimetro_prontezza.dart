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

  /// Il verde di «sopra il tuo solito».
  ///
  /// ⚠️ **Non viene dal tema**: `primary` è il colore della palestra, e su una
  /// palestra rossa il lato «bene» sarebbe rosso. 🚨 Qui il colore *è*
  /// l'informazione, quindi non può dipendere dal marchio.
  static const verde = Color(0xFF2E9E5B);

  static const rosso = Color(0xFFC0392B);

  /// A che colore corrisponde un valore.
  ///
  /// ══ 🚦 IL SEMAFORO QUI SI FA, E ALTROVE NO ══════════════════════════════
  ///
  /// 📌 Richiesto il 28/08/2026: *«lo vorrei colorato. Neutro al centro, verde a
  /// dx e rosso a sx»*.
  ///
  /// ⚠️ **`BatteriaCarica` invece resta senza semaforo**, ed è una differenza
  /// voluta: là il rosso starebbe su una carica **bassa**, e suggerirebbe un
  /// allarme — che è esattamente ciò che l'avvertenza dice di non fare. 💡 Qui
  /// il rosso sta su «sotto il tuo solito», che è uno scostamento da sé stessi,
  /// non un livello.
  ///
  /// 💡 **Il colore è ridondante**, e va tenuto tale: la posizione dell'ago e il
  /// numero dicono già tutto. ⛔ Rosso e verde sono la coppia peggiore per chi
  /// non li distingue, e un'informazione affidata **solo** a quella sarebbe
  /// persa per una persona su dodici.
  static Color coloreDi(double valore, Color neutro) {
    final scarto = (valore - 50) / 50;

    if (scarto.abs() < 0.1) return neutro;

    return Color.lerp(
          neutro,
          scarto > 0 ? verde : rosso,

          // 💡 La saturazione cresce con la distanza dal centro: un 55 è appena
          // tinto, un 90 è pieno.
          (scarto.abs() - 0.1) / 0.9,
        ) ??
        neutro;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final colore = valore == null
        ? tema.colorScheme.outline
        : coloreDi(valore!, tema.colorScheme.onSurfaceVariant);

    return SizedBox(
      width: lato,

      // 💡 Un semicerchio: l'altezza è poco più della metà del lato, e lo spazio
      // sotto ospita il numero.
      height: lato * 0.66,
      child: CustomPaint(
        painter: _Quadrante(
          valore: valore,
          neutro: tema.colorScheme.onSurfaceVariant,
          ago: colore,
          tacche: tema.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
        /*
         * ⛔ **Dentro il quadrante ci sta solo il numero** — corretto il
         * 28/08/2026: *«la scritta "50 è il tuo normale" sta dentro il
         * tachimetro e non si legge bene»*.
         *
         * ⚠️ Ed era vero: sotto l'arco restano una trentina di pixel, e una
         * riga da nove punti lì dentro è un'etichetta che nessuno legge. 💡 La
         * spiegazione è passata **accanto** al quadrante, dove c'è la larghezza
         * per scriverla in chiaro.
         */
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Text(
            valore == null ? '—' : valore!.round().toString(),
            style: tema.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colore,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _Quadrante extends CustomPainter {
  const _Quadrante({
    required this.valore,
    required this.neutro,
    required this.ago,
    required this.tacche,
  });

  final double? valore;
  final Color neutro;
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

    /*
     * 🌈 **L'arco è sfumato**, non a settori: rosso a sinistra, neutro in cima,
     * verde a destra.
     *
     * ⛔ Tre settori netti disegnerebbero **tre categorie** — «male, normale,
     * bene» — con due confini che non esistono: questo indice è continuo, e un
     * 49 non è in una fascia diversa da un 51. 💡 La sfumatura dice «più a
     * destra, meglio» senza inventare soglie.
     */
    canvas.drawArc(
      rettangolo,
      _inizio,
      _ampiezza,
      false,
      Paint()
        ..shader = const SweepGradient(
          // ⚠️ `startAngle`/`endAngle` seguono il mezzo giro del quadrante: un
          // gradiente sul giro intero metterebbe il verde in basso a sinistra.
          startAngle: _inizio,
          endAngle: _inizio + _ampiezza,
          colors: [
            TachimetroProntezza.rosso,
            Color(0x00000000),
            TachimetroProntezza.verde,
          ],
          stops: [0.0, 0.5, 1.0],
        ).createShader(rettangolo)
        ..color = neutro
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
      vecchio.valore != valore ||
      vecchio.ago != ago ||
      vecchio.neutro != neutro;
}
