import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../profile/corpo_controller.dart';
import '../../../profile/ui/widgets/weight_sheet.dart';
import '../../dashboard_controller.dart';

/// Il peso e la sua storia, in **una scheda sola** — 3b-O.6+8, 21/08/2026.
///
/// ══ 🚨 ERANO DUE SCHEDE, E LONTANE ════════════════════════════════════════
///
/// 📌 Il committente: *«non ha senso che siano due cards separate, facciamone
/// una unica. La card deve avere sopra il peso attuale in grande, con vicino il
/// tasto "Aggiungi una pesata" o roba simile e sotto il grafico»*.
///
/// ⚠️ `WeightCard` stava in mezzo alla pagina e `_GraficoPeso` in fondo, con
/// quattro schede in mezzo. 🚨 Ma il numero di oggi e la sua storia rispondono
/// alla **stessa** domanda — «sto andando dove volevo?» — e separarle costringe
/// a tenerne uno a mente mentre si scorre fino all'altro.
///
/// ── 🎯 La linea dell'obiettivo, e perché cambia tutto ─────────────────────
///
/// 📌 *«mettendo come baseline il peso target»*.
///
/// ⚠️ Prima il grafico disegnava una curva che sale o scende **senza un
/// riferimento**: per sapere se si stava andando bene bisognava ricordarsi
/// l'obiettivo e farne la differenza a mente. 💡 Con la linea tracciata, «quanto
/// manca» si legge dalla **distanza fra la curva e la linea**.
///
/// ⛔ **Se l'obiettivo non c'è, la linea non si disegna**, e non si inventa un
/// valore: una linea di riferimento sbagliata è peggio di nessuna linea, perché
/// si continua a leggerla come se fosse giusta.
class SchedaPeso extends ConsumerWidget {
  const SchedaPeso({this.pesoObiettivo, super.key});

  /// Da `profileProvider`, cioè dal server.
  final double? pesoObiettivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oggi = ref.watch(corpoOggiProvider).valueOrNull;
    final peso = oggi?.weightKg;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Testa(
              peso: peso,
              differenza: oggi?.weightDelta,
              quando: oggi?.weightAt,
              obiettivo: pesoObiettivo,
            ),

            const SizedBox(height: Gap.md),
            _Grafico(obiettivo: pesoObiettivo),
          ],
        ),
      ),
    );
  }
}

/// Il peso in grande, e accanto il pulsante per aggiungerne uno.
class _Testa extends StatelessWidget {
  const _Testa({
    required this.peso,
    required this.differenza,
    required this.quando,
    required this.obiettivo,
  });

  final double? peso;
  final double? differenza;
  final DateTime? quando;
  final double? obiettivo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /*
     * 💡 Il contesto sotto il numero: **quando** è stato preso e **quanto** è
     * cambiato. ⚠️ Un peso da solo non dice se si sta andando da qualche parte,
     * e la data evita di scambiare una pesata di dieci giorni fa per quella di
     * stamattina.
     */
    final contesto = <String>[
      if (quando != null) DateFormat('d MMM', 'it').format(quando!),
      if (obiettivo != null) 'obiettivo ${obiettivo!.toStringAsFixed(1)} kg',
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    // ⛔ Niente trattino quando non c'è: è la regola di O.1b.1.
                    peso == null ? '—' : peso!.toStringAsFixed(1),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: Gap.xs),
                  Text('kg', style: theme.textTheme.titleMedium),

                  if (differenza != null) ...[
                    const SizedBox(width: Gap.sm),
                    Text(
                      '${differenza! > 0 ? '+' : ''}'
                      '${differenza!.toStringAsFixed(1)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),

              if (contesto.isNotEmpty)
                Text(contesto, style: theme.textTheme.bodySmall),
            ],
          ),
        ),

        /*
         * 🚨 **Apre LA STESSA modale delle impostazioni** — 3b-O.6+8.3.
         *
         * 📌 *«mi deve aprire una modale con gli stessi campi di quello nelle
         * opzioni»*.
         *
         * ⛔ **Non si riscrive**: `WeightSheet` ha già il selettore del giorno,
         * la massa grassa e le sue validazioni. ⚠️ Due moduli per la stessa
         * pesata divergerebbero al primo campo aggiunto — e il campo lo si
         * aggiungerebbe a uno solo dei due, senza accorgersene.
         *
         * 💡 `iniziale: peso` fa partire il campo dall'ultimo valore: chi si
         * pesa ogni giorno cambia un decimale, non riscrive tutto.
         */
        FilledButton.tonalIcon(
          onPressed: () => WeightSheet.mostra(context, iniziale: peso),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Pesata'),
        ),
      ],
    );
  }
}

class _Grafico extends ConsumerWidget {
  const _Grafico({required this.obiettivo});

  final double? obiettivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final serie = ref.watch(weightSeriesProvider);
    final finestra = ref.watch(weightWindowProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: const [
              ButtonSegment(value: 30, label: Text('30g')),
              ButtonSegment(value: 90, label: Text('90g')),
              ButtonSegment(value: 365, label: Text('1a')),
              ButtonSegment(value: 0, label: Text('tutto')),
            ],
            selected: {finestra},
            onSelectionChanged: (s) =>
                ref.read(weightWindowProvider.notifier).state = s.first,
          ),
        ),

        const SizedBox(height: Gap.sm),

        serie.when(
          loading: () => const SizedBox(
            height: 180,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const SizedBox(
            height: 180,
            child: Center(child: Text('Non disponibile')),
          ),
          // ⚠️ «in due giorni diversi» e non «due volte»: pesarsi due volte lo
          // stesso giorno è una correzione e lascia **un** punto solo. Chi lo ha
          // fatto e legge «due volte» conclude che l'app abbia perso il dato.
          data: (s) => s.values.length < 2
              ? SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'Registra il peso in almeno due giorni diversi '
                      'per vedere l\'andamento.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                )
              : SizedBox(height: 180, child: LineChart(_dati(context, s))),
        ),
      ],
    );
  }

  LineChartData _dati(BuildContext context, Series s) {
    final theme = Theme.of(context);

    /*
     * ══ 🎯 LA SCALA COMPRENDE L'OBIETTIVO ═══════════════════════════════════
     *
     * ⚠️ Senza questo, una linea di base fuori dai valori misurati **non si
     * vedrebbe**: `fl_chart` calcola i limiti dai punti, e l'obiettivo di chi è
     * ancora lontano cadrebbe fuori dal riquadro. 🚨 Cioè proprio a chi ha più
     * strada da fare la linea sparirebbe — e sembrerebbe che non l'abbia
     * impostata.
     */
    final valori = <double>[...s.values, ?obiettivo];

    var minimo = valori.reduce((a, b) => a < b ? a : b);
    var massimo = valori.reduce((a, b) => a > b ? a : b);

    // 💡 Un margine, se no la curva tocca i bordi del riquadro. E mai zero: con
    // un solo valore ripetuto `massimo - minimo` è 0 e il grafico degenera.
    final margine = ((massimo - minimo) * 0.15).clamp(0.5, 10.0);
    minimo -= margine;
    massimo += margine;

    return LineChartData(
      minY: minimo,
      maxY: massimo,
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: _titoli(s.labels),

      /*
       * 🎯 **La linea dell'obiettivo** — 3b-O.6+8.4.
       *
       * ⛔ Tratteggiata e non piena: è un **riferimento**, non una misura, e
       * disegnarla come la curva la farebbe leggere come un secondo andamento.
       */
      extraLinesData: obiettivo == null
          ? const ExtraLinesData()
          : ExtraLinesData(
              horizontalLines: [
                HorizontalLine(
                  y: obiettivo!,
                  color: theme.colorScheme.tertiary,
                  strokeWidth: 2,
                  dashArray: [6, 4],
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                      fontWeight: FontWeight.w700,
                    ),
                    labelResolver: (_) =>
                        'obiettivo ${obiettivo!.toStringAsFixed(1)}',
                  ),
                ),
              ],
            ),

      lineBarsData: [
        LineChartBarData(
          spots: [
            for (var i = 0; i < s.values.length; i++)
              FlSpot(i.toDouble(), s.values[i]),
          ],
          isCurved: true,
          barWidth: 3,
          color: theme.colorScheme.primary,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  FlTitlesData _titoli(List<String> etichette) => FlTitlesData(
    topTitles: const AxisTitles(),
    rightTitles: const AxisTitles(),

    /*
     * 📏 **Un decimale sull'asse verticale** — 3b-O.6+8.5.
     *
     * 📌 *«sull'asse verticale il peso deve essere con un solo decimale (sennò
     * si vede male)»*.
     *
     * ⚠️ Di serie `fl_chart` scrive il valore grezzo, e i limiti calcolati
     * portano numeri come `97.90000000000001`: un'etichetta lunga il doppio,
     * che si accavalla con quella sopra e sotto.
     */
    leftTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        reservedSize: 42,
        getTitlesWidget: (valore, meta) => Text(
          valore.toStringAsFixed(1),
          style: const TextStyle(fontSize: 10),
        ),
      ),
    ),

    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        // Un'etichetta ogni tot: con trenta punti si sovrapporrebbero fino a
        // diventare una macchia nera.
        interval: (etichette.length / 5).ceilToDouble().clamp(1, 1000),
        getTitlesWidget: (valore, meta) {
          final i = valore.toInt();

          if (i < 0 || i >= etichette.length) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Text(etichette[i], style: const TextStyle(fontSize: 10)),
          );
        },
      ),
    ),
  );
}
