import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 🌗 **Il semicerchio di un macronutriente** — `plan_interfaccia.md` I3,
/// 19/11/2026.
///
/// 📌 Tavola «Diario A»: i tre macro come **strumenti** nella testata scura.
///
/// ══ 🔑 DENTRO IL QUADRATO, NON AL SUO POSTO ═══════════════════════════════
///
/// 📌 22/08/2026, 3b-D.1.4: *«i macro devono essere dentro dei quadrati»*. La
/// tavola li disegnava senza cornice; la regola scritta batte il disegno, e le
/// due cose stanno insieme: il quadrato resta, e il semicerchio ci sta dentro.
///
/// ══ 🚨 SFORARE SI VEDE, ANCHE SE L'ARCO FINISCE ═══════════════════════════
///
/// La regola di `MacroSummary` (A4.1): *«rosso quando si sfora, e la barra non
/// si ferma a fine corsa»* — 2.000 su 2.000 e 2.600 su 2.000 si devono
/// distinguere con un'occhiata.
///
/// ⚠️ Un arco **non può** andare oltre la fine come una barra. 💡 Quindi oltre
/// il 100% l'arco è pieno, diventa `colorScheme.error`, e sotto compare **di
/// quanto** si è sforato («+12 g»): la parte che l'arco non può disegnare
/// diventa un numero.
class SemicerchioMacro extends StatelessWidget {
  const SemicerchioMacro({
    required this.grammi,
    required this.obiettivo,
    required this.colore,
    super.key,
  });

  final double grammi;

  /// `null` = nessun obiettivo: l'arco resta vuoto, e non si inventa niente.
  final double? obiettivo;

  /// Il colore del macro: lo stesso dei quadrati e di «Oggi».
  final Color colore;

  /// Quanti grammi oltre l'obiettivo, o `null` se non si è sforato.
  static double? sforo(double grammi, double? obiettivo) {
    if (obiettivo == null || obiettivo <= 0) return null;

    final oltre = grammi - obiettivo;

    return oltre > 0 ? oltre : null;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final oltre = sforo(grammi, obiettivo);

    final quota = obiettivo == null || obiettivo! <= 0
        ? 0.0
        : (grammi / obiettivo!).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64,
          height: 34,
          child: CustomPaint(
            painter: _Arco(
              quota: quota,
              colore: oltre == null ? colore : tema.colorScheme.error,
              fondo: colore.withValues(alpha: 0.18),
            ),
          ),
        ),
        if (oltre != null)
          Text(
            '+${oltre.round()} g',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _Arco extends CustomPainter {
  const _Arco({required this.quota, required this.colore, required this.fondo});

  final double quota;
  final Color colore;
  final Color fondo;

  static const _spessore = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Il semicerchio sta appoggiato sul bordo in basso, e tocca i due lati.
    final raggio = math.min(size.width / 2, size.height) - _spessore / 2;
    final centro = Offset(size.width / 2, size.height - _spessore / 2);
    final rettangolo = Rect.fromCircle(center: centro, radius: raggio);

    final pennello = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _spessore
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rettangolo, math.pi, math.pi, false, pennello..color = fondo);

    if (quota > 0) {
      canvas.drawArc(
        rettangolo,
        math.pi,
        math.pi * quota,
        false,
        pennello..color = colore,
      );
    }
  }

  @override
  bool shouldRepaint(_Arco vecchio) =>
      vecchio.quota != quota ||
      vecchio.colore != colore ||
      vecchio.fondo != fondo;
}
