/// La figura e la stella, sotto una scheda — 3b-D.6, 25/08/2026.
///
/// 📌 *«In fondo alla scheda, ci deve essere la card con l'uomo e i muscoli
/// allenati e il grafico a stella (le stesse dello storico e dell'esercizio
/// individuale)»*.
///
/// ══ 🚨 «LE STESSE» ALLA LETTERA ═══════════════════════════════════════════
///
/// 💡 Gli **stessi widget** — `FiguraDelCorpo`, `LegendaDeiMuscoli`,
/// `StellaInRiquadro`, `RiquadroBianco` — non una copia che gli somiglia.
/// ⛔ Due figure che divergono sono peggio di una figura sola: chi guarda non
/// ha modo di sapere quale delle due sta mentendo.
///
/// ⚠️ **La differenza è cosa colora.** Nello storico l'intensità viene da quello
/// che hai **fatto**; qui da quello che hai **scritto**. Stessa forma, tempo
/// verbale diverso — ed è il motivo per cui questa card, mentre si compila la
/// scheda, si accende un esercizio alla volta.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/gruppo_muscolare.dart';
import 'carosello_del_mese.dart';
import 'figura_del_corpo.dart';

class MuscoliInCard extends StatelessWidget {
  const MuscoliInCard({required this.intensita, super.key});

  final Map<GruppoMuscolare, double> intensita;

  /// 💡 Alta come il carosello dello storico: sfogliando le due schermate la
  /// figura resta della stessa taglia, e non sembra un'altra cosa.
  static const _altezzaFigura = 260.0;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Cosa allena questa scheda',
              style: tema.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.sm),

            SizedBox(
              height: _altezzaFigura,
              child: Row(
                children: [
                  Expanded(
                    // 📌 Nel quadrato bianco anche col tema scuro (3b-C.1): il
                    // PNG è disegnato per un fondo chiaro, e su nero le linee
                    // spariscono.
                    child: RiquadroBianco(
                      sempreBianco: true,
                      child: FiguraDelCorpo(intensita: intensita),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(child: StellaInRiquadro(intensita: intensita)),
                ],
              ),
            ),

            const SizedBox(height: Gap.sm),
            const LegendaDeiMuscoli(),
          ],
        ),
      ),
    );
  }
}
