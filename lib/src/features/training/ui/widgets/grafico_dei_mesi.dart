/// Le sessioni degli ultimi mesi, a colonne — 3b-B.14, 24/08/2026.
///
/// 📌 Il committente: *«ci puoi mettere anche sotto un grafico dentro a un altro
/// rettangolo bianco con il confronto degli allenamenti degli ultimi x mesi»*.
///
/// ══ 💡 SCRITTO A MANO E NON CON `fl_chart` ════════════════════════════════
///
/// `fl_chart` c'è già fra le dipendenze e serve per i grafici del peso e delle
/// calorie, dove le curve, gli assi e i tocchi contano. ⛔ Qui servono **sei
/// rettangoli e sei lettere**: tirarci dentro una libreria di grafici vorrebbe
/// dire un albero di widget dieci volte più profondo, un tema da riallineare a
/// mano e nessun controllo su quanto è alta una colonna quando il mese è vuoto.
///
/// 🚨 **Il mese in corso è marcato**, e non è un vezzo: è l'unica colonna che
/// **non è finita**. Senza dirlo, un agosto a metà sembrerebbe un crollo, e
/// invece è il 24 del mese.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';

class GraficoDeiMesi extends StatelessWidget {
  const GraficoDeiMesi({required this.mesi, required this.corrente, super.key});

  /// Dal più vecchio al più recente.
  final List<({DateTime mese, int sessioni})> mesi;

  /// Il mese che la schermata sta guardando: quello **in corso** fra questi.
  final DateTime corrente;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    /*
     * ⚠️ **Il massimo non scende mai sotto 1.** Con tutti i mesi a zero, un
     * `massimo = 0` darebbe una divisione per zero; e con un solo mese a 1, una
     * colonna alta tutto direbbe «mese record» per un allenamento solo. 💡 Il
     * minimo di scala è quattro: sotto, le colonne raccontano più di quello che
     * sanno.
     */
    final piuAlto = mesi.fold<int>(
      0,
      (a, m) => m.sessioni > a ? m.sessioni : a,
    );
    final scala = piuAlto < 4 ? 4 : piuAlto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final m in mesi)
                Expanded(
                  child: _Colonna(
                    sessioni: m.sessioni,
                    frazione: m.sessioni / scala,
                    inCorso:
                        m.mese.year == corrente.year &&
                        m.mese.month == corrente.month,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 2),

        Row(
          children: [
            for (final m in mesi)
              Expanded(
                child: Text(
                  // 💡 La sola iniziale: sei etichette da tre lettere non ci
                  // stanno, e in una fila di mesi consecutivi l'iniziale basta.
                  DateFormat('MMM', 'it').format(m.mese)[0].toUpperCase(),
                  textAlign: TextAlign.center,
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                    fontWeight:
                        m.mese.year == corrente.year &&
                            m.mese.month == corrente.month
                        ? FontWeight.w800
                        : FontWeight.w400,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Colonna extends StatelessWidget {
  const _Colonna({
    required this.sessioni,
    required this.frazione,
    required this.inCorso,
  });

  final int sessioni;
  final double frazione;
  final bool inCorso;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          /*
           * ⛔ **Il numero sopra la colonna, non dentro.** Dentro sparisce nelle
           * colonne basse — che sono proprio quelle in cui uno vuole sapere se è
           * 0 o 1.
           */
          Text(
            '$sessioni',
            maxLines: 1,
            style: tema.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: sessioni == 0
                  ? tema.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)
                  : tema.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 2),

          /*
           * 💡 **Anche lo zero ha un filo di colonna.** Una colonna alta zero e
           * una colonna che non c'è si somigliano troppo, e la seconda vuol dire
           * un'altra cosa.
           */
          Expanded(
            child: FractionallySizedBox(
              alignment: Alignment.bottomCenter,
              heightFactor: frazione.clamp(0.04, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: inCorso
                      ? tema.colorScheme.tertiary
                      : tema.colorScheme.primary.withValues(alpha: 0.65),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(Gap.xs),
                  ),
                ),
                child: const SizedBox(width: double.infinity),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
