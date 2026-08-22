import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../health/health_controller.dart';
import '../../../profile/target_locale_controller.dart';
import '../../../training/bruciate_locali.dart';
import '../../dashboard_controller.dart';

/// Le calorie del periodo, **due linee attorno a una linea di base** —
/// 3b-O.9, 21/08/2026, ridisegnato il 22/08.
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
/// ── 🚨 DUE LINEE CON I PUNTI, TERZO GIRO ────────────────────────────────
///
/// 📌 La storia di questo grafico, per intero: *«non mi piace a colonne, lo
/// preferisco a onda doppia»* → *«forse sarebbe meglio a colonne, così non si
/// capisce nulla»* → **22/08/2026**: *«non mi piace come si mostra il grafico.
/// Facciamo che sono due linee con dei punti»*.
///
/// ⚠️ **Non è un giro a vuoto, e la differenza dalla prima onda conta.** Quello
/// che non funzionava allora era la curva morbida: `isCurved: true` *inventa* i
/// valori fra un giorno e l'altro, e con scostamenti che cambiano segno ogni
/// giorno diventava un ghirigoro da cui non si estraeva nessuna giornata.
///
/// 💡 **I punti sono la correzione di quel difetto.** Segmenti dritti
/// (`isCurved: false`) più un pallino su ogni misura: la linea dice il **verso**
/// — sto salendo o scendendo rispetto a ieri — e i pallini dicono **dove sono i
/// dati veri**, cioè quello che la curva nascondeva.
///
/// ⛔ **I pallini spariscono oltre i 31 giorni**: a novanta giorni distano tre
/// pixel e tornano a essere la macchia che si voleva evitare. Lì resta la linea,
/// che a quella scala è l'unica cosa leggibile.
///
/// ── 🚨 Il buco è un dato, lo zero no ─────────────────────────────────────
///
/// ⚠️ Un giorno senza diario **interrompe la linea** (`FlSpot.nullSpot`), non la
/// porta a zero. 🚨 Con la linea questo pesa più che con le colonne: una colonna
/// mancante è un vuoto che si nota, ma una linea tirata da un giorno all'altro
/// **passa comunque per il mezzo**, e disegna un valore che nessuno ha mai
/// misurato.
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

    // 🚨 Le bruciate degli allenamenti: dall'archivio locale — FASE 11.5.
    final locali = giorni.isEmpty
        ? const <String, int>{}
        : (ref.watch(bruciateLocaliProvider(giorni.join(','))).valueOrNull ??
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
                  locali: locali,
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
    required this.locali,
    required this.target,
    required this.consumo,
    required this.finestra,
  });

  final Series serie;
  final Map<String, int> daHealth;
  final Map<String, int> locali;
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
            child: LineChart(
              _dati(context, serie, daHealth, locali, target!, consumo),
            ),
          ),

        const SizedBox(height: Gap.sm),

        /*
         * ══ 🚨 «0 BRUCIATE» ERA UNA BUGIA — 22/08/2026 ═══════════════════
         *
         * ⚠️ Qui c'era `serie.avgBurned`, che è la media del **server**. ⛔ Dopo
         * la FASE 11 il server gli allenamenti non ce li ha più: quel campo
         * vale **zero per tutti**, e la riga diceva «0 bruciate» sotto un
         * grafico che nella stessa schermata disegnava la linea arancione, e
         * sopra una scheda che diceva «1227».
         *
         * 🚨 **Tre numeri per la stessa cosa, due dei quali falsi.** È la quinta
         * volta che il server sopravvive in un angolo dopo il trasloco (O.D.6,
         * O.D.9, la `bruciateDi` qui sopra): 🚨 non dà errore, dà **zero**, e
         * uno zero credibile non si distingue da un dato.
         *
         * 💡 Si conta dalla stessa `bruciateDi` che disegna la linea: una
         * funzione sola, quindi non possono più discordare.
         */
        Builder(
          builder: (context) {
            var totale = 0.0;
            var giorniMossi = 0;

            for (var i = 0; i < serie.labels.length; i++) {
              final b = bruciateDi(serie, i, daHealth, locali);
              if (b > 0) {
                totale += b;
                giorniMossi++;
              }
            }

            // 🚨 Il contesto della media è parte della media: «2.200 di media»
            // su due giorni registrati su sette non è lo stesso numero che su
            // sette, e senza dirlo si legge come se lo fosse.
            final cibo = serie.daysWithData == 0
                ? 'Nessun giorno registrato in questo periodo.'
                : 'Media ${serie.avgConsumed} kcal assunte sui '
                      '${serie.daysWithData} giorni in cui hai registrato '
                      'qualcosa.';

            /*
             * ⛔ **Zero giorni mossi si dice, non si stampa come «0 bruciate»**:
             * la media di niente non è zero, è assente. Sono due frasi diverse
             * perché sono due notizie diverse.
             */
            final mosso = giorniMossi == 0
                ? ''
                : ' Media ${(totale / giorniMossi).round()} kcal bruciate sui '
                      '$giorniMossi giorni in cui ti sei mosso.';

            return Text(
              '$cibo$mosso',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            );
          },
        ),
      ],
    );
  }
}

/// Le bruciate del giorno `i`, dalla stessa fonte dell'intestazione.
///
/// ══ 🚨 NIENTE VIENE PIÙ DAL SERVER — FASE 11.5 ═══════════════════════════
///
/// ⚠️ Qui c'era `s.burned[i]`, cioè la serie del **server**. Il 19/08 era già
/// stato corretto una volta — l'intestazione diceva 680 e il grafico zero,
/// perché il server le calorie dell'orologio non le ha — e adesso il server non
/// ha nemmeno più le **sedute**.
///
/// 🚨 Lasciare `s.burned` sarebbe stato **zero per tutti senza un errore**: un
/// grafico credibile che dice che nessuno si muove.
///
/// 💡 Precedenza: l'orologio se ha misurato qualcosa, altrimenti quello che
/// dice l'archivio locale (dichiarazione a mano, o somma delle sedute).
double bruciateDi(
  Series s,
  int i,
  Map<String, int> daHealth,
  Map<String, int> locali,
) {
  final data = i < s.dates.length ? s.dates[i] : null;
  if (data == null) return 0;

  final dalPolso = daHealth[data];
  if (dalPolso != null && dalPolso > 0) return dalPolso.toDouble();

  return (locali[data] ?? 0).toDouble();
}

LineChartData _dati(
  BuildContext context,
  Series s,
  Map<String, int> daHealth,
  Map<String, int> locali,
  double target,
  double? consumo,
) {
  final theme = Theme.of(context);

  final cibo = <FlSpot>[];
  final mosso = <FlSpot>[];
  final valori = <double>[0];

  for (var i = 0; i < s.labels.length; i++) {
    final assunte = i < s.consumed.length ? s.consumed[i] : 0.0;
    final bruciate = bruciateDi(s, i, daHealth, locali);
    final x = i.toDouble();

    /*
     * ⚠️ **Un giorno senza diario NON è un giorno a digiuno.** Con `assunte = 0`
     * lo scostamento sarebbe `−target`, cioè il punto più basso del grafico:
     * chi ha saltato il diario per un giorno si vedrebbe un tuffo che non è
     * successo. 💡 Quel giorno la linea del cibo si **interrompe**.
     */
    if (assunte > 0) {
      final scostamento = assunte - target;
      valori.add(scostamento);
      cibo.add(FlSpot(x, scostamento));
    } else {
      cibo.add(FlSpot.nullSpot);
    }

    // 🚨 Stessa regola per il movimento: zero bruciate quasi mai vuol dire «è
    // stato fermo», vuol dire «nessuno ce l'ha detto» — né l'orologio né lui.
    if (bruciate > 0) {
      valori.add(-bruciate);
      mosso.add(FlSpot(x, -bruciate));
    } else {
      mosso.add(FlSpot.nullSpot);
    }
  }

  final estremo = valori
      .map((v) => v.abs())
      .reduce((a, b) => a > b ? a : b)
      .clamp(100.0, double.infinity);

  /*
   * 💡 I pallini finché si distinguono. A trenta giorni su una scheda da 330 px
   * ce n'è uno ogni undici pixel e si leggono; a novanta ogni tre, e tornano a
   * essere la macchia continua che le colonne sottili facevano prima.
   */
  final punti = s.labels.length <= 31;

  LineChartBarData linea(List<FlSpot> spots, Color colore) => LineChartBarData(
    spots: spots,
    // ⛔ **Mai `isCurved: true` qui**: è il difetto dell'onda del 19/08 — la
    // curva passa per valori che nessun giorno ha avuto.
    isCurved: false,
    color: colore,
    barWidth: 2,
    isStrokeCapRound: true,
    isStrokeJoinRound: true,
    dotData: FlDotData(
      show: punti,
      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
        radius: 3,
        color: colore,
        // 💡 L'anello del colore della scheda: due punti vicini restano due
        // punti invece di fondersi in una macchia sola.
        strokeWidth: 1.5,
        strokeColor: theme.colorScheme.surface,
      ),
    ),
  );

  return LineChartData(
    /*
     * 🚨 **La scala è simmetrica attorno allo zero**, e non è estetica: con
     * limiti calcolati sui dati la linea di base finirebbe a un terzo
     * dell'altezza, e «sopra» e «sotto» smetterebbero di essere confrontabili a
     * occhio — che è tutto il punto di questo grafico.
     */
    minY: -estremo * 1.15,
    maxY: estremo * 1.15,
    minX: 0,
    maxX: (s.labels.length - 1).toDouble().clamp(0, double.infinity),

    gridData: const FlGridData(show: false),
    borderData: FlBorderData(show: false),
    titlesData: _titoli(s.labels),

    lineBarsData: [
      // 🍽️ Il cibo: sopra la linea si è mangiato più del previsto.
      linea(cibo, theme.colorScheme.primary),
      // 🔥 Il movimento: sempre sotto, perché è sempre una spesa.
      linea(mosso, theme.colorScheme.tertiary),
    ],

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

    lineTouchData: _tocco(context, s, daHealth, locali, consumo),
  );
}

/// Il riquadro che compare col dito — 3b-O.9.4.
///
/// 📌 *«Se ci passo il dito mi deve dire il risultato di calorie assunte oltre
/// tdaa - calorie bruciate»*.
///
/// ⚠️ **Nota di lessico**: il committente scrive «tdaa» e intende il **TDEE**,
/// il consumo giornaliero totale. Nel codice si usa il nome vero, e a schermo la
/// parola che si capisce senza sapere la sigla: «consumo».
LineTouchData _tocco(
  BuildContext context,
  Series s,
  Map<String, int> daHealth,
  Map<String, int> locali,
  double? consumo,
) {
  final theme = Theme.of(context);

  return LineTouchData(
    touchTooltipData: LineTouchTooltipData(
      getTooltipColor: (_) => theme.colorScheme.inverseSurface,

      /*
       * ══ 🚨 UN RIQUADRO SOLO, NON UNO PER LINEA ══════════════════════════
       *
       * ⚠️ Con due linee il dito ne tocca **due** punti insieme, e la versione
       * ovvia scriverebbe due righe: una per il cibo e una per il movimento. 🚨
       * Ma il numero chiesto è **uno** — il saldo, che mette insieme tutte e
       * due — e stamparlo due volte lo farebbe sembrare un totale doppio.
       *
       * 💡 Quindi si risponde per il primo punto toccato e `null` per gli
       * altri: `fl_chart` salta le voci nulle, e resta un riquadro solo.
       */
      getTooltipItems: (toccati) => [
        for (final (indice, punto) in toccati.indexed)
          if (indice > 0)
            null
          else
            _vocePerIlDito(
              theme,
              s,
              punto.x.toInt(),
              daHealth,
              locali,
              consumo,
            ),
      ],
    ),
  );
}

/// Il testo dentro il riquadro del dito.
///
/// 🚨 Il saldo è `(assunte − consumo) − bruciate`: positivo vuol dire surplus —
/// si è mangiato più di quanto si è speso — negativo deficit.
LineTooltipItem? _vocePerIlDito(
  ThemeData theme,
  Series s,
  int i,
  Map<String, int> daHealth,
  Map<String, int> locali,
  double? consumo,
) {
  final assunte = i < s.consumed.length ? s.consumed[i] : 0.0;
  final bruciate = bruciateDi(s, i, daHealth, locali);
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
