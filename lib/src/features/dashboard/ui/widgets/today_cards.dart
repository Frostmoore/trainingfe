import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/storage/archivio_salute.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/avvertenza_nutrizionale.dart';
import '../../../diary/data/bruciate_del_giorno.dart';
import '../../../diary/data/target_del_giorno.dart';
import '../../../health/dati_salute.dart';
import '../../../health/health_controller.dart';
import '../../../health/media_di_riferimento.dart';
import '../../../health/recupero_controller.dart';
import '../../../profile/corpo_controller.dart';
import '../../../profile/target_locale_controller.dart';
import '../../../profile/ui/widgets/manca_per_il_target.dart';
import '../../../sleep/sleep_controller.dart';
import '../../data/dashboard_models.dart';
import 'onda_metrica.dart';

/// Le schede del riepilogo di oggi — D5.

/// Le calorie, lette **rispetto all'ora che è**.
///
/// 🚨 La barra ha due indicatori: quanto si è mangiato e **a che punto è la
/// giornata**. 1.200 kcal su 2.400 non vogliono dire niente da sole: a metà
/// mattina sono tantissime, alle nove di sera sono poche. È la differenza fra
/// un'app che informa e una che sembra giudicare a caso.
class CaloriesCard extends ConsumerWidget {
  const CaloriesCard({required this.riepilogo, super.key});

  final DashboardSummary riepilogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final n = riepilogo.nutrition;
    final scostamento = riepilogo.scostamentoRitmo;

    /*
     * 🚨 **Se il server non ha un obiettivo, se lo calcola l'app** — correzione
     * di S7 su un difetto nato in S5.
     *
     * Da quando il peso è uscito dal server, `Profile::computedTargets()` non
     * può più calcolare niente: senza peso non c'è BMR, senza BMR non c'è TDEE.
     * Il backend restituisce `null`, ed è corretto — ⚠️ **ma nell'app non lo
     * calcolava nessuno**, e la card diceva «Nessun obiettivo impostato» a
     * chi il profilo lo aveva compilato e il peso lo aveva registrato.
     *
     * 💡 L'ordine di precedenza è quello di sempre: **il piano del trainer
     * vince sul calcolo**, e il calcolo vince sul nulla.
     */
    final esito = n.haTarget
        ? null
        : ref.watch(targetLocaleProvider).valueOrNull;
    final locale = esito?.target;

    // 🚨 Le bruciate entrano nell'obiettivo — N23.B1. La regola sta in
    // `TargetDelGiorno` e in nessun altro posto: le schermate che mostrano un
    // obiettivo calorico sono tre, e tre copie divergono.
    /*
     * 🚨 **La catena, non il numero del server** — difetto del 19/08 sera.
     *
     * ⚠️ Qui passava `n.burnedKcal`, che e' la **stima della nostra formula**:
     * l'orologio non lo conosceva, e chi lasciava il campo vuoto vedeva
     * l'obiettivo senza le calorie che aveva davvero bruciato. La catena era
     * agganciata a **una sola** delle tre schermate.
     */
    final bruciate = BruciateDelGiorno.scegli(
      manuale: n.bruciateAMano,
      daHealth: ref.watch(kcalAttiveOggiProvider).valueOrNull ?? 0,
      stimate: n.burnedKcal,
    );

    final delGiorno = TargetDelGiorno.scegli(
      dalServer: n.haTarget ? n.targetKcal : null,
      locale: locale?.kcal.toDouble(),
      bruciate: bruciate.kcal,
    );

    final target = delGiorno.kcal ?? 0;
    final haObiettivo = delGiorno.esiste;

    return Card(
      margin: EdgeInsets.zero,

      /*
       * 🆕 **Toccandola si va al cibo di oggi** — 3b-O.2.3, 21/08/2026.
       *
       * 💡 È il criterio di tutta la pagina: «Oggi» è un **riassunto**, e ogni
       * scheda porta al posto dove si fa la cosa. ⚠️ Il numero delle calorie
       * senza una strada per correggerlo è un numero che si guarda e basta.
       */
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.diary),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    n.kcal.round().toString(),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: Gap.xs),
                  Text(
                    haObiettivo ? '/ ${target.round()} kcal' : 'kcal',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (bruciate.esistono)
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 18,
                          color: theme.colorScheme.tertiary,
                        ),
                        Text(
                          '${bruciate.kcal}',
                          style: theme.textTheme.titleSmall,
                        ),
                      ],
                    ),
                ],
              ),

              if (haObiettivo) ...[
                const SizedBox(height: Gap.sm),
                _BarraConRitmo(
                  percentualeMangiata: (n.kcal / target).clamp(0.0, 1.5),
                  percentualeGiornata: riepilogo.dayProgressPct / 100,
                ),
                const SizedBox(height: Gap.xs),
                Text(
                  _frase(
                    // ⚠️ Il ritmo si ricalcola sull'obiettivo **che si sta
                    // mostrando**: usare quello del server quando il numero viene
                    // dal calcolo locale darebbe una frase che non c'entra niente
                    // con la barra sopra.
                    n.haTarget
                        ? scostamento
                        : n.kcal - target * riepilogo.dayProgressPct / 100,
                    target - n.kcal,
                    riepilogo.dayProgressPct,
                  ),
                  style: theme.textTheme.bodySmall,
                ),

                // 🚨 S7.5 — se l'obiettivo viene dal piano del trainer, si dice.
                //
                // ⚠️ **Il numero calcolato non compare affatto**, e non è una
                // dimenticanza: due numeri diversi nella stessa schermata sono un
                // invito a non fidarsi di nessuno dei due, e chi paga un trainer
                // vuole seguire il trainer. La formula però continua a girare —
                // serve quando il piano scade, e per chi un trainer non ce l'ha.
                if (n.targetDaPiano)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.xs),
                    child: Text(
                      'Dal piano del tuo trainer',
                      style: theme.textTheme.labelSmall,
                    ),
                  )
                else
                  /*
                 * 🆕 20/08/2026 — l'avvertenza dove sta il numero.
                 *
                 * 🚨 **Era l'unico posto in cui mancava**, ed era il peggiore in
                 * cui mancare: qui c'è il numero più visibile dell'app, quello
                 * su cui una persona decide quanto mangiare oggi. Il riepilogo
                 * macro, l'importazione del piano, la revisione e il profilo
                 * l'avevano già.
                 *
                 * ⚠️ **Solo quando l'obiettivo lo calcoliamo noi.** Se il numero
                 * viene dal piano del trainer non è una nostra stima da formule
                 * generiche: è la scelta di un professionista, e scriverci sotto
                 * «stima da formule generiche» sarebbe falso e gli darebbe torto.
                 */
                  const Padding(
                    padding: EdgeInsets.only(top: Gap.xs),
                    child: AvvertenzaNutrizionale(compatta: true),
                  ),
              ] else ...[
                const SizedBox(height: Gap.sm),

                /*
               * ⚠️ Si dice **cosa** manca, non «compila i tuoi dati».
               *
               * Il peso non sta nel profilo: vive nell'archivio locale (S5) e si
               * registra da un altro foglio. Mandare al profilo chi ha già
               * compilato tutto tranne la pesata è un giro a vuoto — ed è
               * esattamente com'è stato riferito provando l'app.
               */
                if (esito != null && !esito.riuscito)
                  MancaPerIlTarget(esito: esito)
                else
                  Text(
                    'Nessun obiettivo impostato.',
                    style: theme.textTheme.bodySmall,
                  ),
              ],

              const SizedBox(height: Gap.sm),
              Row(
                children: [
                  // ⚠️ Anche i macro seguono la stessa precedenza del totale:
                  // mostrarne uno calcolato accanto a un totale che viene dal
                  // piano — o viceversa — darebbe una scheda che si contraddice.
                  _Macro(
                    nome: 'P',
                    valore: n.protein,
                    target:
                        n.targetProtein ?? locale?.macro.proteineG.toDouble(),
                  ),
                  _Macro(
                    nome: 'C',
                    valore: n.carbs,
                    target:
                        n.targetCarbs ?? locale?.macro.carboidratiG.toDouble(),
                  ),
                  _Macro(
                    nome: 'G',
                    valore: n.fat,
                    target: n.targetFat ?? locale?.macro.grassiG.toDouble(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La frase che dà senso ai numeri, e **cambia con l'ora**.
  static String _frase(double? scostamento, double residuo, int giornata) {
    if (giornata >= 90) {
      return residuo >= 0
          ? 'Giornata quasi finita: sei rimasto sotto di ${residuo.round()} kcal.'
          : 'Giornata quasi finita: hai superato di ${(-residuo).round()} kcal.';
    }

    if (giornata <= 20) {
      return 'La giornata è appena cominciata. Ti restano ${residuo.round()} kcal.';
    }

    if (scostamento == null) return 'Ti restano ${residuo.round()} kcal.';

    // Sopra le 250 kcal di scarto vale la pena dirlo: sotto è rumore, e
    // segnalare rumore insegna a ignorare i segnali.
    if (scostamento > 250) {
      return 'Sei avanti rispetto all\'ora: ti restano ${residuo.round()} kcal per il resto della giornata.';
    }

    if (scostamento < -250) {
      return 'Sei indietro rispetto all\'ora: hai ancora ${residuo.round()} kcal.';
    }

    return 'In linea con l\'ora. Ti restano ${residuo.round()} kcal.';
  }
}

/// La barra con il segno di dove **dovrebbe** essere la giornata.
class _BarraConRitmo extends StatelessWidget {
  const _BarraConRitmo({
    required this.percentualeMangiata,
    required this.percentualeGiornata,
  });

  final double percentualeMangiata;
  final double percentualeGiornata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sfora = percentualeMangiata > 1;

    return LayoutBuilder(
      builder: (context, vincoli) => SizedBox(
        height: 14,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: percentualeMangiata.clamp(0.0, 1.0),
                minHeight: 10,
                color: sfora
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            // Il segno del ritmo: senza, la barra dice quanto si è mangiato ma
            // non se è troppo **per l'ora che è**.
            Positioned(
              left: (vincoli.maxWidth * percentualeGiornata).clamp(
                0.0,
                vincoli.maxWidth - 2,
              ),
              child: Container(
                width: 2,
                height: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.nome, required this.valore, this.target});

  final String nome;
  final double valore;
  final double? target;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Text(
      target == null
          ? '$nome ${valore.round()} g'
          : '$nome ${valore.round()}/${target!.round()} g',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

/// Sonno, HRV e battito: come sta andando il recupero.
///
/// 🚨 **Legge dal TELEFONO, non dalla risposta del server** — S4.3.
///
/// Fino a `v4.8.1` prendeva `sleep` e `vitals` da `DashboardSummary`, cioè da
/// `GET /dashboard`. Dopo S1 quel payload non li contiene più: i dati del
/// sensore restano sul telefono (decisione D9) e questa card li chiede a
/// `recuperoProvider`, che li calcola da `ArchivioSalute`.
///
/// ⚠️ **Per questo non prende più `riepilogo`**: portarsi dietro un parametro
/// che non si usa avrebbe lasciato credere che la sorgente fosse ancora quella.
/// Il recupero di oggi — 3b-O.5, riscritta il 21/08/2026.
///
/// ══ 🚨 COSA CAMBIA, E PERCHÉ ══════════════════════════════════════════════
///
/// 📌 Dettata dal committente: *«all'inizio ci deve proprio essere
/// l'ipnogramma, con sotto i riposini; variabilità cardiaca deve essere un
/// grafico, e idem battito a riposo, uno sotto l'altro (non a colonne, a onda);
/// calorie attive deve essere un fuoco con vicino scritte le calorie»*.
///
/// ⚠️ Prima era un elenco di righe tutte uguali — un'icona, un nome, un numero —
/// e le tre informazioni avevano lo **stesso peso visivo** pur essendo cose
/// diverse: com'è andata la notte, come sta il cuore, quanto ti sei mosso.
///
/// 💡 Adesso ognuna ha la forma della domanda a cui risponde: la notte è una
/// striscia da guardare, il cuore è una linea che sale o scende, il movimento è
/// un numero solo.
class RecoveryCard extends ConsumerWidget {
  const RecoveryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recupero = ref.watch(recuperoProvider).valueOrNull;

    // ⚠️ Mentre si legge dal database locale non si mostra uno scheletro: sono
    // millisecondi, e un lampo di caricamento a ogni apertura della schermata
    // principale si nota più del dato.
    if (recupero == null || !recupero.haQualcosa) {
      return const _InvitoACollegare();
    }

    final notte = recupero.notte;
    final pisolini = ref.watch(pisoliniProvider).valueOrNull ?? const [];

    final hrv = recupero.parametri[MetricaSalute.hrv];
    final battito = recupero.parametri[MetricaSalute.battitoARiposo];

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        // 📌 «Va bene che se ci clicco mi manda alla pagina del sonno.»
        onTap: () => context.push(AppRoutes.sleep),
        borderRadius: BorderRadius.circular(Gap.radius),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Recupero',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (notte != null)
                    Text(
                      notte.durata,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _colore(context, notte.complessivo),
                      ),
                    ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),

              /*
               * 🚨 **L'ipnogramma in cima** — è la richiesta, ed è anche la cosa
               * giusta: la domanda che porta su questa scheda è «come ho
               * dormito», e una striscia risponde prima di qualunque numero.
               */
              if (notte != null) ...[
                const SizedBox(height: Gap.sm),
                _StrisciaSonno(fasi: notte.ipnogramma),
                const SizedBox(height: Gap.xs),
                Text(
                  'profondo ${notte.profondoPct.round()}% · REM ${notte.remPct.round()}%',
                  style: theme.textTheme.bodySmall,
                ),
              ],

              // 💡 I riposini **sotto** la notte, come chiesto. Spariscono da
              // soli quando non ce ne sono.
              if (pisolini.isNotEmpty) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  pisolini.length == 1
                      ? 'più un riposo di ${_breve(pisolini.first.durata)}'
                      : 'più ${pisolini.length} riposi, '
                            '${_breve(pisolini.fold(Duration.zero, (a, p) => a + p.durata))} in tutto',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              if (hrv != null || battito != null)
                const SizedBox(height: Gap.md),

              if (hrv != null)
                _Onda(
                  lettura: hrv,
                  colore: theme.colorScheme.primary,
                  valori: ref
                      .watch(andamentoMetricaProvider(MetricaSalute.hrv))
                      .valueOrNull,
                ),

              if (battito != null) ...[
                const SizedBox(height: Gap.sm),
                _Onda(
                  lettura: battito,
                  colore: theme.colorScheme.tertiary,
                  valori: ref
                      .watch(
                        andamentoMetricaProvider(MetricaSalute.battitoARiposo),
                      )
                      .valueOrNull,
                ),
              ],

              /*
               * 🔥 **Le calorie attive: un fuoco e un numero** — 3b-O.5.4.
               *
               * ⚠️ `null` e non `0`: «non lo so» e «non ti sei mosso» sono due
               * frasi diverse, e uno zero che vuol dire «manca il dato» fa
               * credere a qualcuno di essere stato fermo.
               */
              if (recupero.kcalAttive != null) ...[
                const SizedBox(height: Gap.md),
                Row(
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 22,
                      color: Color(0xFFE0603A),
                    ),
                    const SizedBox(width: Gap.sm),
                    Text(
                      '${recupero.kcalAttive} kcal',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Text(
                        'bruciate oggi con l\'attività',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _breve(Duration d) {
    final ore = d.inHours;
    final minuti = d.inMinutes % 60;

    return ore > 0 ? '${ore}h ${minuti}m' : '${minuti}m';
  }

  static Color? _colore(BuildContext context, Giudizio giudizio) =>
      switch (giudizio) {
        Giudizio.bad => Theme.of(context).colorScheme.error,
        Giudizio.warn => const Color(0xFFE0B341),
        Giudizio.ok => null,
      };
}

/// L'ipnogramma **in miniatura**: una striscia, non un grafico.
///
/// 🚨 Qui non si rifà quello della pagina del sonno, e non è pigrizia: là serve
/// poterlo **leggere** — con le ore, le fasi, la legenda. ⚠️ In una scheda di
/// riassunto quella roba non entra, e infilarcela a forza produrrebbe un
/// grafico illeggibile che occupa il posto di tre informazioni.
///
/// 💡 Qui basta la **forma della notte**: dove è stato profondo, dove ci si è
/// svegliati. Chi vuole i dettagli tocca e va alla pagina.
class _StrisciaSonno extends StatelessWidget {
  const _StrisciaSonno({required this.fasi});

  final List<CampioneSonno> fasi;

  @override
  Widget build(BuildContext context) {
    if (fasi.isEmpty) return const SizedBox.shrink();

    /*
     * ⚠️ **La larghezza è proporzionale alla DURATA**, non al numero di
     * segmenti: venti minuti di REM e due ore di profondo non possono occupare
     * lo stesso spazio, o la striscia racconta una notte che non c'è stata.
     */
    final totale = fasi.fold<int>(
      0,
      (a, c) => a + c.finitoIl.difference(c.iniziatoIl).inSeconds,
    );

    if (totale <= 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            for (final c in fasi)
              Expanded(
                flex: c.finitoIl
                    .difference(c.iniziatoIl)
                    .inSeconds
                    .clamp(1, 1 << 30),
                child: ColoredBox(
                  color: _coloreFase(context, c.fase),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ⚠️ `CampioneSonno.fase` è un **intero** — il codice di `FaseSonno` — e non
  /// una stringa: l'archivio lo salva così.
  static Color _coloreFase(BuildContext context, int fase) {
    final schema = Theme.of(context).colorScheme;

    return switch (FaseSonno.daCodice(fase)) {
      FaseSonno.profondo => schema.primary,
      FaseSonno.rem => schema.tertiary,
      FaseSonno.leggero => schema.primary.withValues(alpha: 0.45),
      // 💡 Lo sveglio è un **buco**, non una fase: un colore pieno lo farebbe
      // sembrare tempo dormito.
      _ => schema.surfaceContainerHighest,
    };
  }
}

/// Una metrica con il suo andamento a onda.
class _Onda extends StatelessWidget {
  const _Onda({required this.lettura, required this.colore, this.valori});

  final LetturaConMedia lettura;
  final Color colore;
  final List<double>? valori;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 96,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lettura.metrica.etichetta,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${_numero(lettura.valore)} ${lettura.metrica.unita}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: OndaMetrica(valori: valori ?? const [], colore: colore),
        ),
      ],
    );
  }

  static String _numero(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// Quando non c'è niente da mostrare.
///
/// 🚨 **Adesso la frase è vera, e porta da qualche parte.** Prima di S3 diceva
/// «compaiono appena il tuo orologio comincia a inviarli» — una promessa che
/// dopo S1 nessuno poteva mantenere, perché il canale di ingest non esisteva
/// più. Adesso c'è qualcosa che l'utente **può fare**, ed è a un tocco.
class _InvitoACollegare extends StatelessWidget {
  const _InvitoACollegare();

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: ListTile(
      leading: const Icon(Icons.monitor_heart_outlined),
      title: const Text('Sonno e recupero'),
      subtitle: const Text(
        'Collega Health Connect per vedere qui come dormi e come stai '
        'recuperando. I dati restano sul tuo telefono.',
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      isThreeLine: true,
      onTap: () => context.push(AppRoutes.salute),
    ),
  );
}

class TrainingCard extends ConsumerWidget {
  const TrainingCard({required this.riepilogo, super.key});

  final DashboardSummary riepilogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = riepilogo.training;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Allenamento',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.history),
                  child: const Text('Storico'),
                ),
              ],
            ),

            Text(
              // «Non ti alleni da 5 giorni» è l'informazione che fa tornare in
              // palestra: un elenco di date costringe a fare il conto a mente.
              switch (t.daysSinceLast) {
                null => 'Nessun allenamento registrato.',
                0 =>
                  'Ti sei allenato oggi. ${t.last30Days} sedute negli ultimi 30 giorni.',
                1 =>
                  'Ultimo allenamento ieri. ${t.last30Days} negli ultimi 30 giorni.',
                final g =>
                  'Non ti alleni da $g giorni. ${t.last30Days} negli ultimi 30.',
              },
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: Gap.sm),

            for (final s in t.recent.take(3))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.isOpen
                      ? Icons.play_circle_outline_rounded
                      : Icons.fitness_center_rounded,
                  size: 20,
                ),
                title: Text(s.name),
                subtitle: Text(
                  [
                    DateFormat('EEE d/MM', 'it').format(s.startedAt),
                    if (s.isOpen)
                      'in corso'
                    else if (s.durationMinutes != null)
                      '${s.durationMinutes} min',
                    '${s.setsCount} serie',
                  ].join(' · '),
                ),
                trailing: s.kcal == null ? null : Text('${s.kcal} kcal'),
                // Conclusa → riepilogo; ancora aperta → player. Riaprire
                // come «allenamento in corso» una seduta di tre giorni fa non
                // ha senso, e rischia di sporcarla con dati di oggi.
                onTap: () => context.push(
                  s.isOpen ? AppRoutes.player(s.id) : AppRoutes.riepilogo(s.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Il peso, con la direzione in cui si sta muovendo.
/// Il peso e come sta cambiando.
///
/// 🚨 **Legge dal TELEFONO** — S5.2. Prendeva `body` da `GET /dashboard`; dopo
/// S5 quel payload non lo contiene più, perché peso e misure sono dati del
/// corpo e non stanno sul server (decisione **D9-bis**).
///
/// ⚠️ **Il peso OBIETTIVO invece resta sul server**, dentro il profilo: è una
/// **preferenza**, non una misura del corpo. Per questo la card mette insieme
/// due sorgenti — ed è l'unico punto dell'app in cui succede.
class WeightCard extends ConsumerWidget {
  const WeightCard({this.pesoObiettivo, super.key});

  /// Da `profileProvider`, cioè dal server.
  final double? pesoObiettivo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locale = ref.watch(corpoOggiProvider).valueOrNull;

    final body = BodyToday(
      weightKg: locale?.weightKg,
      weightDelta: locale?.weightDelta,
      targetWeightKg: pesoObiettivo,
    );

    if (body.weightKg == null) {
      return const Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.monitor_weight_outlined),
          title: Text('Nessuna pesata'),
          subtitle: Text('Registrala dal profilo per vedere l\'andamento.'),
        ),
      );
    }

    final delta = body.weightDelta;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.monitor_weight_outlined),
        title: Text(
          '${body.weightKg!.toStringAsFixed(1)} kg',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (body.weightAt != null)
              DateFormat('d MMM', 'it').format(body.weightAt!),
            if (body.targetWeightKg != null)
              'obiettivo ${body.targetWeightKg!.toStringAsFixed(1)} kg',
          ].join(' · '),
        ),
        trailing: delta == null
            ? null
            : Text(
                '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
