import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../../health/health_controller.dart';
import '../../profile/corpo_controller.dart';
import '../dashboard_controller.dart';
import '../gettoni_controller.dart';
import 'widgets/today_cards.dart';
import 'widgets/today_header.dart';

/// La dashboard — C12.
///
/// Due grafici e un consiglio, come nell'app storica: il peso nel tempo e le
/// calorie assunte contro quelle bruciate. Sono le due domande su cui una
/// persona prende decisioni.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riepilogo = ref.watch(dashboardProvider);
    final consiglio = ref.watch(adviceProvider);

    return Scaffold(
      // 🚨 Niente AppBar: l'intestazione **è** la scheda della palestra, e una
      // barra sopra di essa aggiungerebbe una seconda riga di titolo che dice
      // la stessa cosa due volte, rubando un quinto dello schermo.
      body: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(dashboardProvider)
            ..invalidate(weightSeriesProvider)
            ..invalidate(storicoCorpoProvider)
            ..invalidate(caloriesSeriesProvider)
            ..invalidate(adviceProvider);
        },
        child: riepilogo.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorState(
            error: ApiClient.unwrapError(e),
            onRetry: () => ref.invalidate(dashboardProvider),
          ),
          data: (r) => ListView(
            // ⚠️ Nessun `padding` orizzontale sulla lista: l'intestazione deve
            // arrivare ai bordi. Lo spazio lo mette `_Blocchi`, che è anche il
            // punto unico in cui vive la distanza fra una scheda e l'altra —
            // affidarla al margine di serie di `Card` le lasciava appiccicate.
            padding: EdgeInsets.zero,
            children: [
              TodayHeader(riepilogo: r),

              _Blocchi(
                children: [
                  CaloriesCard(riepilogo: r),

                  // 🚨 Se manca il consenso all'AI si **porta a darlo**, invece
                  // di tacere: il consiglio che sparisce in silenzio sembra un
                  // guasto, ed è così che è stato segnalato.
                  consiglio.maybeWhen(
                    data: (c) => c.haTesto
                        ? _Consiglio(testo: c.testo!)
                        : (c.serveConsenso ? const _ConsensoAiMancante() : null),
                    orElse: () => null,
                  ),

                  const RecoveryCard(),
                  WeightCard(pesoObiettivo: r.body.targetWeightKg),
                  TrainingCard(riepilogo: r),
                  const _GraficoPeso(),
                  const _GraficoCalorie(),
                ],
              ),

              const SizedBox(height: Gap.xl),
            ],
          ),
        ),
      ),
    );
  }
}

/// Impila le schede con **una** distanza, decisa in un posto solo.
///
/// 🚨 Lasciare la spaziatura al margine di serie di `Card` (4 px verticali) le
/// fa sembrare incollate, e aggiungerne una a mano dentro ogni scheda
/// significherebbe sette punti da tenere allineati. I `null` si scartano qui: chi
/// costruisce l'elenco non deve preoccuparsi di lasciare buchi.
class _Blocchi extends StatelessWidget {
  const _Blocchi({required this.children});

  final List<Widget?> children;

  @override
  Widget build(BuildContext context) {
    final visibili = children.whereType<Widget>().toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visibili.length; i++) ...[
            if (i > 0) const SizedBox(height: Gap.md),
            visibili[i],
          ],
        ],
      ),
    );
  }
}

/// La card del consiglio del giorno.
///
/// ── 🚨 L'avvertenza NON è una postilla: è metà della card ─────────────────
///
/// Richiesta del committente, 16/08/2026: *«deve essere specificamente indicato
/// che è generato da AI e che non ha NESSUN VALORE MEDICO, che l'utente non
/// dovrebbe fidarsi e che lo dovrebbe far vedere a un medico sportivo»*.
///
/// ⚠️ Perciò sta **sempre a schermo**, sotto il testo, e non dietro un tocco né
/// in fondo a una schermata di impostazioni. Un'avvertenza che bisogna cercare
/// è un'avvertenza che non c'è.
///
/// 💡 E il prompt lavora nella stessa direzione (regola 5): al modello è vietato
/// il tono della prescrizione — niente «devi», «ti serve». Un testo che dice
/// «devi» sotto una riga che dice «non fidarti» si contraddice da solo, e a
/// vincere è sempre il testo più grande.
class _Consiglio extends ConsumerStatefulWidget {
  const _Consiglio({required this.testo});

  final String testo;

  @override
  ConsumerState<_Consiglio> createState() => _ConsiglioState();
}

class _ConsiglioState extends ConsumerState<_Consiglio> {
  bool _inCorso = false;

  /// Rigenera **pagando**: è una chiamata vera al modello.
  ///
  /// 🚨 `manuale: true` fa saltare la cache al server. Senza, il tocco
  /// restituirebbe lo stesso testo di prima senza spendere niente — e
  /// sembrerebbe rotto.
  Future<void> _rigenera() async {
    setState(() => _inCorso = true);

    try {
      await ref.read(rigeneraConsiglioProvider)();
      ref
        ..invalidate(adviceProvider)
        // 💡 Il saldo è appena cambiato: senza questa riga l'intestazione
        // continuerebbe a mostrare il numero di prima fino al prossimo avvio.
        ..invalidate(gettoniProvider);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.unwrapError(e).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sopra = theme.colorScheme.onPrimaryContainer;

    return Card(
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: sopra),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Spunto di oggi',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: sopra,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                /*
                 * 🚨 **Il costo è scritto sul pulsante, non in un avviso dopo.**
                 * Stessa regola delle linguette del cibo: chi sta per spendere
                 * lo deve sapere **mentre decide**, non mentre scopre il saldo
                 * calato.
                 */
                if (_inCorso)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: Gap.sm),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else
                  TextButton.icon(
                    onPressed: _rigenera,
                    icon: Icon(Icons.refresh_rounded, size: 18, color: sopra),
                    label: Text(
                      '1 gettone',
                      style: theme.textTheme.labelSmall?.copyWith(color: sopra),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: Gap.sm),

            Text(
              widget.testo,
              style: theme.textTheme.bodyMedium?.copyWith(color: sopra),
            ),

            const SizedBox(height: Gap.md),
            Divider(height: 1, color: sopra.withValues(alpha: 0.20)),
            const SizedBox(height: Gap.sm),

            // 🚨 L'avvertenza. Sempre visibile, mai dietro un tocco.
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: sopra.withValues(alpha: 0.75)),
                const SizedBox(width: Gap.xs),
                Expanded(
                  child: Text(
                    'Scritto da un\'intelligenza artificiale sui pochi dati che ha, '
                    'e può sbagliare. Non è un parere medico e non va preso per '
                    'buono: se riguarda la tua salute, parlane con un medico dello '
                    'sport.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: sopra.withValues(alpha: 0.75),
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GraficoPeso extends ConsumerWidget {
  const _GraficoPeso();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serie = ref.watch(weightSeriesProvider);
    final finestra = ref.watch(weightWindowProvider);

    return _Riquadro(
      titolo: 'Peso',
      selettore: _Finestre(
        opzioni: const {30: '30g', 90: '90g', 365: '1a', 0: 'tutto'},
        attuale: finestra,
        onCambia: (g) => ref.read(weightWindowProvider.notifier).state = g,
      ),
      child: serie.when(
        loading: () => const SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
        error: (_, _) => const SizedBox(height: 160, child: Center(child: Text('Non disponibile'))),
        // ⚠️ «in due giorni diversi» e non «due volte»: pesarsi due volte lo
        // stesso giorno è una correzione e lascia **un** punto solo. Chi lo ha
        // fatto e legge «due volte» conclude che l'app abbia perso il dato.
        data: (s) => s.values.length < 2
            ? const _NienteDati(
                messaggio: 'Registra il peso in almeno due giorni diversi '
                    'per vedere l\'andamento.',
              )
            : SizedBox(
                height: 180,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: _titoli(s.labels),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < s.values.length; i++)
                            FlSpot(i.toDouble(), s.values[i]),
                        ],
                        isCurved: true,
                        barWidth: 3,
                        color: Theme.of(context).colorScheme.primary,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _GraficoCalorie extends ConsumerWidget {
  const _GraficoCalorie();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serie = ref.watch(caloriesSeriesProvider);
    final finestra = ref.watch(caloriesWindowProvider);
    final theme = Theme.of(context);

    /*
     * 💡 Le date come **una stringa sola**: e' la chiave della `family`, e una
     * lista non va bene — due liste con lo stesso contenuto non sono uguali per
     * Riverpod, e il provider si ricreerebbe a ogni ridisegno. E' la stessa
     * trappola di `DateTime.now()`, in un'altra forma.
     */
    final giorni = serie.valueOrNull?.dates ?? const <String>[];

    final daHealth = giorni.isEmpty
        ? const <String, int>{}
        : (ref.watch(kcalAttivePerGiorniProvider(giorni.join(','))).valueOrNull ??
              const <String, int>{});

    return _Riquadro(
      titolo: 'Calorie',
      sottotitolo: 'assunte contro bruciate',
      selettore: _Finestre(
        opzioni: const {7: '7g', 30: '30g', 90: '3m', 365: '1a', 0: 'tutto'},
        attuale: finestra.days,
        onCambia: (g) => ref.read(caloriesWindowProvider.notifier).state = CaloriesWindow(days: g),
      ),
      child: serie.when(
        loading: () => const SizedBox(height: 180, child: Center(child: CircularProgressIndicator())),
        error: (_, _) => const SizedBox(height: 180, child: Center(child: Text('Non disponibile'))),
        data: (s) => Column(
          children: [
            Row(
              children: [
                IconButton(
                  // «Tutto» non scorre: non c'è niente prima di tutto. Lo dice
                  // il server con `can_go_back`, così la regola non è
                  // duplicata qui.
                  onPressed: s.canGoBack
                      ? () => ref.read(caloriesWindowProvider.notifier).state =
                            finestra.copyWith(offset: finestra.offset + 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    s.period ?? '',
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
            if (s.vuota)
              const _NienteDati(messaggio: 'Nessun dato in questo periodo.')
            else
              SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: _titoli(s.labels),
                    barGroups: [
                      for (var i = 0; i < s.labels.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: i < s.consumed.length ? s.consumed[i] : 0,
                              color: theme.colorScheme.primary,
                              width: 6,
                            ),
                            BarChartRodData(
                              /*
                               * 🚨 **Le bruciate vengono dalla stessa fonte
                               * dell'intestazione** — 19/08/2026.
                               *
                               * Qui c'era `s.burned[i]`, cioe' la serie del
                               * **server**: quello calcola con la formula sulle
                               * sedute registrate e le calorie dell'orologio non
                               * le ha — restano sul telefono per decisione del
                               * committente.
                               *
                               * ⚠️ Risultato: l'intestazione diceva 680 e il
                               * grafico zero. Non due numeri sbagliati: **due
                               * fonti diverse per lo stesso numero**, e ne avevo
                               * corretta una sola.
                               */
                              toY: _bruciateDi(s, i, daHealth),
                              color: theme.colorScheme.tertiary,
                              width: 6,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: Gap.sm),
            // 🚨 Il contesto della media è parte della media: «2.200 di media»
            // su due giorni registrati su sette non è lo stesso numero che su
            // sette, e senza dirlo si legge come se lo fosse.
            Text(
              s.daysWithData == 0
                  ? 'Nessun giorno registrato in questo periodo.'
                  : 'Media ${s.avgConsumed} kcal assunte e ${s.avgBurned} bruciate, '
                        'sui ${s.daysWithData} giorni in cui hai registrato qualcosa.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

FlTitlesData _titoli(List<String> etichette) => FlTitlesData(
  topTitles: const AxisTitles(),
  rightTitles: const AxisTitles(),
  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 38)),
  bottomTitles: AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      // Un'etichetta ogni tot: con trenta barre si sovrapporrebbero fino a
      // diventare una macchia nera.
      interval: (etichette.length / 6).ceilToDouble().clamp(1, 100),
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

class _Riquadro extends StatelessWidget {
  const _Riquadro({
    required this.titolo,
    required this.child,
    this.sottotitolo,
    this.selettore,
  });

  final String titolo;
  final String? sottotitolo;
  final Widget? selettore;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titolo,
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (sottotitolo != null)
                      Text(sottotitolo!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (selettore != null) ...[const SizedBox(height: Gap.sm), selettore!],
          const SizedBox(height: Gap.md),
          child,
        ],
      ),
    ),
  );
}

class _Finestre extends StatelessWidget {
  const _Finestre({required this.opzioni, required this.attuale, required this.onCambia});

  final Map<int, String> opzioni;
  final int attuale;
  final ValueChanged<int> onCambia;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final voce in opzioni.entries)
          Padding(
            padding: const EdgeInsets.only(right: Gap.xs),
            child: ChoiceChip(
              label: Text(voce.value),
              selected: attuale == voce.key,
              onSelected: (_) => onCambia(voce.key),
            ),
          ),
      ],
    ),
  );
}

class _NienteDati extends StatelessWidget {
  const _NienteDati({required this.messaggio});

  final String messaggio;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        child: Text(
          messaggio,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    ),
  );
}

/// Il consiglio del giorno c'è, ma serve il consenso — S9.
///
/// 🚨 **Non è un errore da nascondere: è un'azione da proporre.** Prima questo
/// caso spariva dentro un `catch` che inghiottiva tutto allo stesso modo, e la
/// card semplicemente non compariva — indistinguibile da un guasto.
class _ConsensoAiMancante extends StatelessWidget {
  const _ConsensoAiMancante();

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
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: Gap.sm),
                Text(
                  'Il consiglio del giorno',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Per prepararlo dobbiamo mandare quello che hai scritto nel '
              'diario a un servizio esterno. Non lo facciamo senza il tuo '
              'permesso.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonal(
                onPressed: () => context.push(AppRoutes.consensi),
                child: const Text('Decidi tu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le bruciate della colonna `i`: quelle dell'orologio se ci sono, altrimenti
/// quelle della serie del server.
///
/// 🚨 **Si sostituiscono, non si sommano.** L'orologio ha gia' misurato
/// l'allenamento che la formula del server sta stimando: sommarli darebbe il
/// doppio, con un numero che resta plausibile. E' la stessa regola di
/// `BruciateDelGiorno`, applicata al grafico.
double _bruciateDi(Series s, int i, Map<String, int> daHealth) {
  final data = i < s.dates.length ? s.dates[i] : null;
  final orologio = data == null ? null : daHealth[data];

  if (orologio != null && orologio > 0) return orologio.toDouble();

  return i < s.burned.length ? s.burned[i] : 0;
}
