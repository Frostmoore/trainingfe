import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../dati_salute.dart';
import '../../media_di_riferimento.dart';
import '../../recupero_controller.dart';
import '../../serie_salute_controller.dart';

/// L'andamento di HRV o battito a riposo — richiesto il 12/08/2026.
///
/// ── 🚨 Perché serviva un grafico e non un numero ─────────────────────────
///
/// *«Come ti ho già detto HRV e battito a riposo devono avere dei grafici.»*
///
/// E non è una preferenza estetica: **un valore assoluto di HRV non si può
/// interpretare**. 55 ms è ottimo per qualcuno e pessimo per qualcun altro;
/// l'unica lettura sensata è *«rispetto a come stai di solito»*. La scheda
/// Recupero lo dice già a parole («−18% dalla tua media»), ma una frase non
/// mostra **se sta scendendo da tre giorni o se è un buco isolato** — che è la
/// differenza fra «hai dormito male» e «ti stai ammalando».
///
/// ⚠️ È la stessa ragione per cui `MediaDiRiferimento` esiste, e la regola non
/// è stata riscritta qui: il grafico disegna, il giudizio resta lì.
class GraficoMetrica extends ConsumerWidget {
  const GraficoMetrica({required this.metrica, super.key});

  final MetricaSalute metrica;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final serie = ref.watch(serieSaluteProvider(metrica)).valueOrNull;
    final conMedia = ref.watch(recuperoProvider).valueOrNull?.parametri[metrica];

    if (serie == null) {
      return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    }

    if (serie.isEmpty) {
      return _Vuoto(metrica: metrica);
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Intestazione(metrica: metrica, conMedia: conMedia),
            const SizedBox(height: Gap.md),
            SizedBox(height: 130, child: _Linea(serie: serie, metrica: metrica)),
            const SizedBox(height: Gap.xs),
            Text(
              serie.length == 1
                  ? 'Un solo giorno di dati: l\'andamento comincia a dire '
                        'qualcosa dopo una settimana.'
                  : '${serie.length} giorni con dati negli ultimi 30.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Intestazione extends StatelessWidget {
  const _Intestazione({required this.metrica, required this.conMedia});

  final MetricaSalute metrica;
  final LetturaConMedia? conMedia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scostamento = conMedia?.scostamentoPct;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metrica.etichetta,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (conMedia != null)
                Text(
                  '${conMedia!.valore.round()} ${metrica.unita}',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
            ],
          ),
        ),

        /*
         * 🚨 Lo scostamento e NON un voto sul valore assoluto.
         *
         * ⚠️ E solo **sotto** la media conta come anomalia: un HRV più alto
         * del solito non è un problema, mentre uno più basso indica che il
         * corpo non ha recuperato. È la regola di `MediaDiRiferimento`, che
         * qui si mostra e non si riscrive.
         */
        if (scostamento != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm,
              vertical: Gap.xs,
            ),
            decoration: BoxDecoration(
              color: conMedia!.anomalo
                  ? theme.colorScheme.errorContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${scostamento >= 0 ? '+' : ''}${scostamento.round()}% '
              'dalla tua media',
              style: theme.textTheme.labelSmall?.copyWith(
                color: conMedia!.anomalo
                    ? theme.colorScheme.onErrorContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.serie, required this.metrica});

  final List<MediaGiornaliera> serie;
  final MetricaSalute metrica;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final punti = <FlSpot>[
      for (var i = 0; i < serie.length; i++) FlSpot(i.toDouble(), serie[i].media),
    ];

    final valori = serie.map((p) => p.media).toList();
    final minimo = valori.reduce((a, b) => a < b ? a : b);
    final massimo = valori.reduce((a, b) => a > b ? a : b);

    /*
     * ⚠️ Un margine del 10%, e mai una scala che parte da zero.
     *
     * Un HRV oscilla fra 40 e 60: con l'asse a zero quella variazione — che è
     * **tutta l'informazione** — diventa una riga piatta a metà del grafico.
     * Per una metrica che si legge come scostamento, partire da zero significa
     * nascondere proprio la cosa che si sta guardando.
     */
    final margine = ((massimo - minimo).abs() * 0.1).clamp(1.0, double.infinity);

    return LineChart(
      LineChartData(
        minY: minimo - margine,
        maxY: massimo + margine,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (v, meta) => Text(
                v.round().toString(),
                style: theme.textTheme.labelSmall,
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              // ⚠️ Non una data per punto: con trenta giorni si sovrappongono e
              // non si legge niente. Solo il primo, il mezzo e l'ultimo.
              interval: (serie.length / 2).clamp(1, 30).toDouble(),
              getTitlesWidget: (v, meta) {
                final i = v.round();

                if (i < 0 || i >= serie.length) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: Gap.xs),
                  child: Text(
                    DateFormat('d/M').format(serie[i].giorno),
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (punti) => punti.map((p) {
              final g = serie[p.x.round()];

              return LineTooltipItem(
                '${DateFormat('d MMM', 'it').format(g.giorno)}\n'
                '${g.media.round()} ${metrica.unita}',
                theme.textTheme.labelMedium ?? const TextStyle(),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: punti,
            isCurved: true,
            curveSmoothness: 0.25,
            color: theme.colorScheme.primary,
            barWidth: 2.5,
            // I pallini solo quando i punti sono pochi: su trenta giorni
            // diventano una collana che copre la linea.
            dotData: FlDotData(show: serie.length <= 10),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Vuoto extends StatelessWidget {
  const _Vuoto({required this.metrica});

  final MetricaSalute metrica;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metrica.etichetta,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Gap.xs),
            Text(
              'Ancora nessun dato. Arriva dall\'orologio, quando si sincronizza '
              'con il telefono.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
