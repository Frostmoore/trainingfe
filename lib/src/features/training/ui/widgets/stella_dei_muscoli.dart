/// Il grafico a stella sui gruppi muscolari — 3b-A.6.2, 24/08/2026.
///
/// 📌 Il committente: *«una con un grafico a stella con tutti i gruppi
/// muscolari e ovviamente più è stato allenato un gruppo più è alto il
/// valore»*.
///
/// ══ 🚨 DISEGNATO A MANO, ANCHE SE `fl_chart` C'È ══════════════════════════
///
/// ⛔ `fl_chart` ha un `RadarChart`, ed è già una dipendenza del progetto. Non
/// si usa qui per una ragione precisa: **le etichette**. Sono undici gruppi
/// attorno a una card alta 200 px, e il posizionamento dei titoli di quel
/// componente non si controlla abbastanza da garantire che «Quadricipiti» non
/// esca dal riquadro su uno schermo da 280 px.
///
/// ⚠️ È lo stesso motivo per cui la figura del corpo è disegnata: quando quello
/// che conta è **stare dentro lo spazio**, un componente generico va combattuto
/// invece che usato.
///
/// 💡 E le due card così condividono la stessa idea di intensità (`0..1`), lo
/// stesso colore e lo stesso silenzio quando non c'è niente.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/gruppo_muscolare.dart';

class StellaDeiMuscoli extends StatelessWidget {
  const StellaDeiMuscoli({required this.intensita, super.key});

  /// `gruppo → 0..1`.
  final Map<GruppoMuscolare, double> intensita;

  /// Gli assi, sempre gli stessi e sempre nello stesso ordine.
  ///
  /// 🚨 **Tutti i gruppi, anche quelli a zero**, come chiesto: una stella che
  /// mostra solo i muscoli allenati non fa vedere quello che manca — che è la
  /// domanda per cui uno guarda un grafico del genere.
  ///
  /// ⛔ Fuori `cardio` e `full_body`: non sono zone, e un asse «cardio» in
  /// mezzo ai muscoli renderebbe la stella una cosa che non si sa leggere.
  static final assi = GruppoMuscolare.values
      .where((g) => g.eUnMuscolo)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return CustomPaint(
      painter: _PittoreDellaStella(
        valori: [for (final g in assi) intensita[g] ?? 0],
        // ⚠️ **La forma corta**: undici parole intere attorno a un cerchio
        // piccolo si accavallano — «Addome» e «Avambracci» lo facevano.
        etichette: [for (final g in assi) g.etichettaBreve],
        linea: tema.colorScheme.outlineVariant,
        area: tema.colorScheme.error,
        testo: tema.colorScheme.onSurfaceVariant,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Quanto spazio serve alle parole attorno al grafico.
///
/// ⚠️ È mezza etichetta per lato più un margine: le etichette sono **centrate**
/// sul vertice, quindi ne sporge metà.
const double _larghezzaEtichetta = 58;
const double _spazioEtichette = _larghezzaEtichetta / 2 + 6;

class _PittoreDellaStella extends CustomPainter {
  const _PittoreDellaStella({
    required this.valori,
    required this.etichette,
    required this.linea,
    required this.area,
    required this.testo,
  });

  final List<double> valori;
  final List<String> etichette;
  final Color linea;
  final Color area;
  final Color testo;

  @override
  void paint(Canvas canvas, Size size) {
    final centro = Offset(size.width / 2, size.height / 2);

    /*
     * ══ 🚨 IL RAGGIO SI CALCOLA DALLE ETICHETTE, NON A OCCHIO ═════════════
     *
     * ⛔ Al primo giro era `min(w,h)/2 * 0.62`, cioè una frazione scelta a
     * sentimento. **Sullo schermo del committente la stella usciva dalla
     * card**: metà delle etichette di destra erano tagliate dal bordo, e il
     * grafico era illeggibile.
     *
     * 🚨 Una frazione non può funzionare, perché le etichette **non scalano**
     * con la card: «Quadricipiti» è largo uguale su una card da 250 px e su una
     * da 400. 💡 Quindi si toglie prima lo spazio che serve a loro, e il raggio
     * è quello che resta.
     */
    final meta = math.min(size.width, size.height) / 2;
    final raggio = math.max(meta - _spazioEtichette, meta * 0.25);

    final n = valori.length;

    if (n < 3) return;

    Offset punto(int i, double quanto) {
      // 💡 Si parte da −90°, cioè in alto: una stella che comincia a destra
      // sembra ruotata.
      final angolo = -math.pi / 2 + 2 * math.pi * i / n;

      return centro +
          Offset(math.cos(angolo), math.sin(angolo)) * (raggio * quanto);
    }

    // ── La ragnatela: tre anelli, non di più ─────────────────────────────
    final filo = Paint()
      ..color = linea
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final anello in [0.33, 0.66, 1.0]) {
      final p = Path();

      for (var i = 0; i < n; i++) {
        final o = punto(i, anello);
        i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
      }

      canvas.drawPath(p..close(), filo);
    }

    for (var i = 0; i < n; i++) {
      canvas.drawLine(centro, punto(i, 1), filo);
    }

    // ── L'area, se c'è qualcosa da disegnare ─────────────────────────────
    //
    // ⛔ Con tutti i valori a zero non si disegna un punto al centro: sarebbe
    // un puntino rosso che sembra un dato. Il vuoto lo dice la card.
    if (valori.any((v) => v > 0)) {
      final forma = Path();

      for (var i = 0; i < n; i++) {
        // 💡 Un minimo visibile: un gruppo a 0,01 dentro una ragnatela grande
        // darebbe una figura che sembra vuota anche quando non lo è.
        final o = punto(i, valori[i] == 0 ? 0 : math.max(valori[i], 0.06));
        i == 0 ? forma.moveTo(o.dx, o.dy) : forma.lineTo(o.dx, o.dy);
      }

      forma.close();

      canvas
        ..drawPath(forma, Paint()..color = area.withValues(alpha: 0.28))
        ..drawPath(
          forma,
          Paint()
            ..color = area
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
    }

    // ── Le etichette ─────────────────────────────────────────────────────
    for (var i = 0; i < n; i++) {
      final dove = punto(i, 1.16);

      final p =
          (ui.ParagraphBuilder(
                  ui.ParagraphStyle(textAlign: TextAlign.center, fontSize: 9),
                )
                ..pushStyle(ui.TextStyle(color: testo))
                ..addText(etichette[i]))
              .build()
            ..layout(const ui.ParagraphConstraints(width: _larghezzaEtichetta));

      /*
       * 🚨 **E comunque si tengono dentro il riquadro.** Il raggio lascia lo
       * spazio giusto per la parola più lunga, ma una parola più lunga di
       * quella prevista uscirebbe lo stesso: `clamp` è la rete sotto, e costa
       * una riga.
       */
      final x = (dove.dx - _larghezzaEtichetta / 2)
          .clamp(0.0, math.max(0.0, size.width - _larghezzaEtichetta))
          .toDouble();

      canvas.drawParagraph(p, Offset(x, dove.dy - p.height / 2));
    }
  }

  @override
  bool shouldRepaint(_PittoreDellaStella vecchio) =>
      vecchio.area != area ||
      vecchio.valori.length != valori.length ||
      !_uguali(vecchio.valori, valori);

  static bool _uguali(List<double> a, List<double> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }
}
