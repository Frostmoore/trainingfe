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

  /// ⚠️ **I colori NON vengono dal tema**: `primary` è il colore della
  /// palestra, e su una palestra rossa il lato «bene» sarebbe rosso. 🚨 Qui il
  /// colore *è* l'informazione, quindi non può dipendere dal marchio.
  static const verde = Color(0xFF2E9E5B);

  /// 💡 Il giallo sta **fra il neutro e il rosso**, non dall'altra parte: è la
  /// zona «sotto il tuo solito ma non tanto».
  static const giallo = Color(0xFFD9A404);

  static const rosso = Color(0xFFC0392B);

  /// La scala, in un posto solo.
  ///
  /// ══ 🚦 ASIMMETRICA, ED È IL PUNTO ═══════════════════════════════════════
  ///
  /// 📌 Corretta il 28/08/2026: *«al centro facciamolo neutro, un po' sotto
  /// giallo e sopra verde. E poi perché ai margini è rosso anche a destra? A dx
  /// deve essere solo verde, a sx solo rosso»*.
  ///
  /// | Dove | Colore |
  /// |---|---|
  /// | `0` | 🔴 rosso |
  /// | `30` | 🟡 giallo |
  /// | `50` | ⚪ neutro |
  /// | `100` | 🟢 verde |
  ///
  /// ⛔ **Il rosso a destra era un difetto vero**: il gradiente girava sul cerchio
  /// intero invece di fermarsi sul mezzo giro, e il colore d'inizio ricompariva
  /// alla fine. ⚠️ E il centro era **trasparente**, non neutro — da cui il
  /// grigiume: sfumare verso il trasparente lascia vedere lo sfondo, non un
  /// colore.
  ///
  /// 💡 **A destra non serve una seconda tinta**: stare sopra il proprio solito
  /// non ha gradi di allarme. È sotto che ne ha due — «un po'» e «parecchio» —
  /// ed è per questo che il giallo esiste solo di là.
  ///
  /// ⚠️ **`BatteriaCarica` resta senza semaforo**, ed è voluto: là il rosso
  /// starebbe su una carica **bassa** e suggerirebbe un allarme. Qui sta su
  /// «sotto il tuo solito», che è uno scostamento da sé stessi.
  ///
  /// 💡 **Il colore è ridondante**, e va tenuto tale: l'ago e il numero dicono
  /// già tutto. ⛔ Un'informazione affidata **solo** al rosso-verde sarebbe persa
  /// per una persona su dodici.
  static Color coloreDi(double valore, Color neutro) {
    final q = (valore / 100).clamp(0.0, 1.0);

    if (q >= 0.5) {
      // 💡 Dal neutro al verde, e nient'altro: a destra c'è una cosa sola.
      return Color.lerp(neutro, verde, (q - 0.5) / 0.5) ?? neutro;
    }

    if (q >= 0.3) return Color.lerp(giallo, neutro, (q - 0.3) / 0.2) ?? neutro;

    return Color.lerp(rosso, giallo, q / 0.3) ?? rosso;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final colore = valore == null
        ? tema.colorScheme.outline
        : coloreDi(valore!, tema.colorScheme.onSurfaceVariant);

    /*
     * ══ ⛔ IL NUMERO STA SOTTO IL QUADRANTE, NON DENTRO ═══════════════════
     *
     * 📌 Corretto il 28/08/2026: *«il valore del tachimetro adesso sta sotto
     * all'ago, non va bene, deve stare sopra al tachimetro o sotto di esso»*.
     *
     * ⚠️ **Dentro finiva addosso al perno dell'ago.** Con l'ago verso il basso
     * — cioè agli estremi della scala, dove il numero conta di più — le due
     * cose si sovrapponevano. 🚨 Un numero che si legge peggio proprio nei casi
     * estremi è un numero che non si legge.
     *
     * 💡 Sotto e fuori: il quadrante fa il suo lavoro con la forma, il numero
     * col testo, e nessuno dei due sta addosso all'altro.
     */
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: lato,

          // 💡 Poco più della metà del lato: è un semicerchio, e sotto non c'è
          // più niente da ospitare.
          height: lato * 0.56,
          child: CustomPaint(
            painter: _Quadrante(
              valore: valore,
              neutro: tema.colorScheme.onSurfaceVariant,
              ago: colore,
              tacche: tema.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ),

        Text(
          valore == null ? '—' : valore!.round().toString(),
          style: tema.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: colore,
            height: 1.1,
          ),
        ),
      ],
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
     * 🌈 **L'arco si disegna a pezzetti, non con un gradiente.**
     *
     * ⛔ Con `SweepGradient` il colore d'inizio ricompariva a destra: il
     * gradiente è definito sul **giro intero**, e i bordi arrotondati del tratto
     * escono dal mezzo giro e vanno a pescare di là. 🚨 Risultato: rosso anche
     * sul lato buono — riferito il 28/08.
     *
     * 💡 Sessanta segmenti, ognuno col colore del suo punto: la sfumatura si
     * vede uguale e **non c'è nessun giro da cui il colore possa tornare**.
     *
     * ⚠️ E resta sfumato, non a settori: tre fasce nette disegnerebbero tre
     * categorie con due confini che non esistono — un 49 non sta in una fascia
     * diversa da un 51.
     */
    const passi = 60;

    for (var i = 0; i < passi; i++) {
      final quota = i / (passi - 1);

      canvas.drawArc(
        rettangolo,
        _inizio + _ampiezza * (i / passi),

        // 💡 Un filo più larghi del passo: senza, fra un segmento e l'altro
        // resterebbe una riga di sfondo, e l'arco sembrerebbe tratteggiato.
        _ampiezza / passi * 1.4,
        false,
        Paint()
          ..color = TachimetroProntezza.coloreDi(
            quota * 100,
            neutro,
          ).withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = spessore,
      );
    }

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
