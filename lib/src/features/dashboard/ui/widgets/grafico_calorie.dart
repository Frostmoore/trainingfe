import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../health/health_controller.dart';
import '../../../profile/target_locale_controller.dart';
import '../../dashboard_controller.dart';

/// Le calorie del periodo, **a onda doppia attorno a una linea di base** —
/// 3b-O.9, 21/08/2026.
///
/// ══ 🚨 IL GRAFICO DI PRIMA NON ERA BRUTTO: ERA SBAGLIATO ══════════════════
///
/// 📌 Il committente: *«Il grafico è sbagliato per una ragione: mette le calorie
/// bruciate come assoluto, e quelle assunte come totale»*.
///
/// ⚠️ **Ed è una critica esatta, non di gusto.** Le due colonne affiancate non
/// erano la stessa grandezza: `consumed` è il **totale** della giornata (≈2.000
/// kcal), `burned` è quanto si è speso **in più** con l'attività (≈300).
/// Metterle vicine invita a confrontarle, e il confronto **non significa
/// niente**: la seconda sembra sempre minuscola, e se ne conclude di muoversi
/// pochissimo.
///
/// ── 💡 La correzione: due scostamenti, non due totali ────────────────────
///
/// | Dove | Cosa | Formula |
/// |---|---|---|
/// | **sopra** | quanto si è mangiato oltre il target | `assunte − target` |
/// | **sotto** | quanto si è bruciato con l'attività | `−bruciate` |
///
/// 🚨 Adesso le due grandezze sono **omogenee**: sono tutte e due scostamenti
/// dalla giornata prevista, e la linea di base è «tutto come previsto». Sopra si
/// è mangiato di più, sotto ci si è mossi di più.
///
/// ⚠️ **Il verso di sopra è con segno**: chi ha mangiato *meno* del target va
/// **sotto** la linea. Costringere il cibo a stare sempre sopra nasconderebbe
/// esattamente il giorno che si vuole vedere.
///
/// ── ⚠️ Il target del periodo è quello di OGGI ─────────────────────────────
///
/// 🚨 **Detto chiaramente perché è una semplificazione**: il server restituisce
/// le calorie assunte e bruciate giorno per giorno, ma **non** il target che era
/// in vigore allora. Qui si usa quello attuale per tutta la finestra.
///
/// 💡 Va bene finché il target non cambia spesso — e quando cambia, cambia
/// perché è cambiato il peso, cioè lentamente. ⛔ Ma se un giorno servisse la
/// verità storica, la strada è **salvare il target nel diario del giorno**, non
/// indovinarlo qui.
class GraficoCalorie extends ConsumerWidget {
  const GraficoCalorie({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final serie = ref.watch(caloriesSeriesProvider);
    final finestra = ref.watch(caloriesWindowProvider);

    /*
     * 💡 Le date come **una stringa sola**: è la chiave della `family`, e una
     * lista non va bene — due liste con lo stesso contenuto non sono uguali per
     * Riverpod, e il provider si ricreerebbe a ogni ridisegno.
     */
    final giorni = serie.valueOrNull?.dates ?? const <String>[];

    final daHealth = giorni.isEmpty
        ? const <String, int>{}
        : (ref
                  .watch(kcalAttivePerGiorniProvider(giorni.join(',')))
                  .valueOrNull ??
              const <String, int>{});

    /*
     * 🎯 Il target e il consumo: due numeri diversi, e servono tutti e due.
     *
     * ⚠️ Il **target** disegna la linea di base del cibo; il **consumo** (TDEE)
     * serve solo al riquadro che compare col dito, perché il committente ha
     * chiesto lì un saldo rispetto al consumo, non al target.
     *
     * 🚨 Il piano del trainer vince sul calcolo, come ovunque nell'app: chi paga
     * un trainer segue il trainer.
     */
    final n = ref.watch(dashboardProvider).valueOrNull?.nutrition;
    final locale = ref.watch(targetLocaleProvider).valueOrNull?.target;

    final target = (n?.haTarget ?? false)
        ? n!.targetKcal
        : locale?.kcal.toDouble();
    final consumo = locale?.tdee;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,

      /*
       * 🆕 **Toccandolo si va al diario di oggi** — 3b-O.9.1.
       *
       * 💡 È il criterio di tutta la pagina: «Oggi» è un riassunto, e ogni
       * scheda porta al posto dove si fa la cosa.
       */
      child: InkWell(
        onTap: () => context.push(AppRoutes.diary),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Calorie',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _Finestre(
                    attuale: finestra.days,
                    onCambia: (g) =>
                        ref.read(caloriesWindowProvider.notifier).state =
                            CaloriesWindow(days: g),
                  ),
                ],
              ),

              Text(
                target == null
                    ? 'scostamento dalla giornata prevista'
                    : 'sopra la linea hai mangiato più di ${target.round()} kcal, '
                          'sotto ti sei mosso',
                style: theme.textTheme.bodySmall,
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
                data: (s) => _Corpo(
                  serie: s,
                  daHealth: daHealth,
                  target: target,
                  consumo: consumo,
                  finestra: finestra,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Corpo extends ConsumerWidget {
  const _Corpo({
    required this.serie,
    required this.daHealth,
    required this.target,
    required this.consumo,
    required this.finestra,
  });

  final Series serie;
  final Map<String, int> daHealth;
  final double? target;
  final double? consumo;
  final CaloriesWindow finestra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              // «Tutto» non scorre: non c'è niente prima di tutto. Lo dice il
              // server con `can_go_back`, così la regola non è duplicata qui.
              onPressed: serie.canGoBack
                  ? () => ref.read(caloriesWindowProvider.notifier).state =
                        finestra.copyWith(offset: finestra.offset + 1)
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                serie.period ?? '',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton(
              onPressed: finestra.offset > 0
                  ? () => ref.read(caloriesWindowProvider.notifier).state =
                        finestra.copyWith(offset: finestra.offset - 1)
                  : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),

        if (serie.vuota)
          SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'Nessun dato in questo periodo.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else if (target == null)
          /*
           * ⛔ **Senza target il grafico non si disegna**, e non si ripiega su
           * zero: una linea di base sbagliata non si vede che è sbagliata, e
           * ogni scostamento letto da lì sarebbe falso.
           */
          SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'Serve un obiettivo calorico per vedere gli scostamenti.\n'
                'Compila il profilo per averlo.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          )
        else
          SizedBox(
            height: 190,
            child: LineChart(_dati(context, serie, daHealth, target!, consumo)),
          ),

        const SizedBox(height: Gap.sm),

        // 🚨 Il contesto della media è parte della media: «2.200 di media» su
        // due giorni registrati su sette non è lo stesso numero che su sette, e
        // senza dirlo si legge come se lo fosse.
        Text(
          serie.daysWithData == 0
              ? 'Nessun giorno registrato in questo periodo.'
              : 'Media ${serie.avgConsumed} kcal assunte e '
                    '${serie.avgBurned} bruciate, sui ${serie.daysWithData} '
                    'giorni in cui hai registrato qualcosa.',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Le bruciate del giorno `i`, dalla stessa fonte dell'intestazione.
///
/// 🚨 **Non `s.burned[i]`** — difetto del 19/08/2026: quella è la serie del
/// **server**, che calcola con la formula sulle sedute registrate e le calorie
/// dell'orologio non le ha (restano sul telefono per decisione del committente).
/// ⚠️ Risultato: l'intestazione diceva 680 e il grafico zero. Non due numeri
/// sbagliati: **due fonti diverse per lo stesso numero**.
double bruciateDi(Series s, int i, Map<String, int> daHealth) {
  final data = i < s.dates.length ? s.dates[i] : null;
  final dalPolso = data == null ? null : daHealth[data];

  if (dalPolso != null && dalPolso > 0) return dalPolso.toDouble();

  return i < s.burned.length ? s.burned[i] : 0;
}

LineChartData _dati(
  BuildContext context,
  Series s,
  Map<String, int> daHealth,
  double target,
  double? consumo,
) {
  final theme = Theme.of(context);

  final cibo = <FlSpot>[];
  final moto = <FlSpot>[];

  for (var i = 0; i < s.labels.length; i++) {
    final assunte = i < s.consumed.length ? s.consumed[i] : 0.0;
    final bruciate = bruciateDi(s, i, daHealth);

    /*
     * ⚠️ **Un giorno senza diario NON è un giorno a digiuno.** Con `assunte = 0`
     * lo scostamento sarebbe `−target`, cioè il punto più basso del grafico: chi
     * ha saltato il diario per un giorno si vedrebbe un tuffo che non è
     * successo. 💡 Quel giorno il cibo semplicemente non ha un punto.
     */
    if (assunte > 0) cibo.add(FlSpot(i.toDouble(), assunte - target));

    moto.add(FlSpot(i.toDouble(), -bruciate));
  }

  final tutti = <double>[...cibo.map((p) => p.y), ...moto.map((p) => p.y), 0];
  final estremo = tutti
      .map((v) => v.abs())
      .reduce((a, b) => a > b ? a : b)
      .clamp(100.0, double.infinity);

  return LineChartData(
    /*
     * 🚨 **La scala è simmetrica attorno allo zero**, e non è estetica: con
     * limiti calcolati sui dati la linea di base finirebbe a un terzo
     * dell'altezza, e «sopra» e «sotto» smetterebbero di essere confrontabili a
     * occhio — che è tutto il punto di questo grafico.
     */
    minY: -estremo * 1.15,
    maxY: estremo * 1.15,

    gridData: const FlGridData(show: false),
    borderData: FlBorderData(show: false),
    titlesData: _titoli(s.labels),

    // ── 🎯 La linea di base: «la giornata come prevista» ──────────────────
    extraLinesData: ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: 0,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          strokeWidth: 1.5,
        ),
      ],
    ),

    lineTouchData: _tocco(context, s, daHealth, consumo),

    lineBarsData: [
      _onda(
        punti: cibo,
        colore: theme.colorScheme.primary,
        // 💡 Il riempimento parte **dallo zero**, non dal fondo: è la distanza
        // dalla linea di base a voler essere vista, non l'altezza assoluta.
        versoZero: true,
      ),
      _onda(punti: moto, colore: theme.colorScheme.tertiary, versoZero: true),
    ],
  );
}

/// Una delle due onde — 3b-O.9.3.
///
/// 📌 *«non mi piace a colonne, lo preferisco a onda doppia»*.
///
/// 💡 E il linguaggio è già quello di «Sonno e recupero» (`OndaMetrica`): usarne
/// un secondo per la stessa idea renderebbe la pagina meno leggibile, non più
/// ricca.
LineChartBarData _onda({
  required List<FlSpot> punti,
  required Color colore,
  required bool versoZero,
}) => LineChartBarData(
  spots: punti,
  isCurved: true,
  // ⚠️ Senza questo, una curva morbida fra due giorni molto diversi «sfonda»
  // oltre i punti e disegna un massimo che non esiste in nessun giorno.
  preventCurveOverShooting: true,
  barWidth: 2.5,
  color: colore,
  dotData: const FlDotData(show: false),
  belowBarData: BarAreaData(
    show: true,
    applyCutOffY: versoZero,
    cutOffY: 0,
    color: colore.withValues(alpha: 0.18),
  ),
  aboveBarData: BarAreaData(
    show: true,
    applyCutOffY: versoZero,
    cutOffY: 0,
    color: colore.withValues(alpha: 0.18),
  ),
);

/// Il riquadro che compare col dito — 3b-O.9.4.
///
/// 📌 *«Se ci passo il dito mi deve dire il risultato di calorie assunte oltre
/// tdaa - calorie bruciate»*.
///
/// ⚠️ **Nota di lessico**: il committente scrive «tdaa» e intende il **TDEE**,
/// il consumo giornaliero totale. Nel codice si usa il nome vero, e a schermo la
/// parola che si capisce senza sapere la sigla: «consumo».
///
/// 🚨 Il saldo è `(assunte − consumo) − bruciate`: positivo vuol dire surplus —
/// si è mangiato più di quanto si è speso — negativo deficit.
LineTouchData _tocco(
  BuildContext context,
  Series s,
  Map<String, int> daHealth,
  double? consumo,
) {
  final theme = Theme.of(context);

  return LineTouchData(
    // 💡 Un solo riquadro anche se le onde sono due: due fumetti sovrapposti
    // sullo stesso giorno si coprono a vicenda.
    getTouchedSpotIndicator: (barData, indici) => indici
        .map(
          (_) => TouchedSpotIndicatorData(
            FlLine(color: theme.colorScheme.outline, strokeWidth: 1),
            const FlDotData(show: true),
          ),
        )
        .toList(),

    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (_) => theme.colorScheme.inverseSurface,
      getTooltipItems: (punti) {
        var primo = true;

        return punti.map((p) {
          // Solo sul primo punto: gli altri restituiscono `null` e spariscono.
          if (!primo) return null;
          primo = false;

          final i = p.x.toInt();
          final assunte = i < s.consumed.length ? s.consumed[i] : 0.0;
          final bruciate = bruciateDi(s, i, daHealth);
          final giorno = i < s.labels.length ? s.labels[i] : '';

          if (consumo == null || assunte <= 0) {
            return LineTooltipItem(
              '$giorno · nessun dato',
              theme.textTheme.labelSmall!.copyWith(
                color: theme.colorScheme.onInverseSurface,
              ),
            );
          }

          final saldo = (assunte - consumo) - bruciate;

          return LineTooltipItem(
            '$giorno\n'
            '${saldo > 0 ? '+' : ''}${saldo.round()} kcal '
            '${saldo > 0 ? 'in più' : 'in meno'}',
            theme.textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.onInverseSurface,
              fontWeight: FontWeight.w700,
            ),
          );
        }).toList();
      },
    ),
  );
}

FlTitlesData _titoli(List<String> etichette) => FlTitlesData(
  topTitles: const AxisTitles(),
  rightTitles: const AxisTitles(),
  leftTitles: const AxisTitles(
    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
  ),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      // Un'etichetta ogni tot: con trenta giorni si sovrapporrebbero fino a
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

class _Finestre extends StatelessWidget {
  const _Finestre({required this.attuale, required this.onCambia});

  final int attuale;
  final ValueChanged<int> onCambia;

  @override
  Widget build(BuildContext context) => SegmentedButton<int>(
    showSelectedIcon: false,
    style: const ButtonStyle(visualDensity: VisualDensity.compact),
    // 🚨 Solo periodi che `/series` accetta — vedi `giorniAmmessiPerLeSerie`.
    segments: const [
      ButtonSegment(value: 7, label: Text('7g')),
      ButtonSegment(value: 30, label: Text('30g')),
      ButtonSegment(value: 90, label: Text('3m')),
    ],
    selected: {attuale},
    onSelectionChanged: (s) => onCambia(s.first),
  );
}
