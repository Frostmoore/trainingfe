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
import '../../../health/tipo_allenamento.dart';
import '../../../profile/corpo_controller.dart';
import '../../../profile/somma_bruciate.dart';
import '../../../profile/target_locale_controller.dart';
import '../../../profile/ui/widgets/manca_per_il_target.dart';
import '../../../sleep/sleep_controller.dart';
import '../../../training/bruciate_locali.dart';
import '../../../training/data/storico_unificato.dart';
import '../../data/dashboard_models.dart';
import '../../riassunto_settimana.dart';
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

    /*
     * ══ 🆕 IL CONSUMO STIMATO, ACCANTO AL TARGET — 3b-O.2.4, 21/08/2026 ═════
     *
     * 📌 *«Nella card delle calorie sopra, vicino al target ci deve essere
     * scritto anche il mio tdaa»*.
     *
     * 💡 **Sono due numeri diversi e serve saperlo**: il *target* è quanto si
     * dovrebbe mangiare per arrivare dove si vuole, il *consumo* è quanto si
     * brucia stando come si sta. **La distanza fra i due è la dieta**, e finora
     * non si vedeva da nessuna parte se non entrando nel profilo.
     *
     * ⚠️ **Si legge sempre**, anche quando l'obiettivo arriva dal piano del
     * trainer: lì `esito` resta `null` di proposito (non si mostrano due
     * obiettivi), ma il consumo non è un secondo obiettivo — è un fatto sul
     * corpo, e non contraddice il piano di nessuno.
     *
     * 🚨 A schermo si scrive **`TDEE`** — vedi la nota più sotto, dove il
     * numero viene disegnato: la parola «consumo», in quella riga, si legge
     * come un terzo conteggio.
     */
    final consumo = ref.watch(targetLocaleProvider).valueOrNull?.target?.tdee;

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
    /*
     * ══ 🚨 LE BRUCIATE VENGONO DAL TELEFONO — FASE 11.5 ═══════════════════
     *
     * ⚠️ `n.bruciateAMano` e `n.burnedKcal` arrivavano da `/dashboard`, che li
     * calcolava da `workout_sessions` e `daily_burns`. 🚨 Con quelle tabelle
     * via, sarebbero diventati **zero senza un errore**: l'obiettivo calorico
     * avrebbe smesso di comprendere le bruciate, e chi si allena avrebbe
     * mangiato meno di quanto poteva credendo di essere in regola.
     *
     * 💡 `BruciateDelGiorno.scegli` resta dov'era: la regola di precedenza non
     * cambia, cambia **da dove arrivano i tre numeri**.
     */
    final oggi = DateTime.now();

    final bruciate = BruciateDelGiorno.scegli(
      manuale: null,
      daHealth: ref.watch(kcalAttiveOggiProvider).valueOrNull ?? 0,
      stimate:
          ref
              .watch(
                bruciateLocaliDelGiornoProvider(
                  DateTime(oggi.year, oggi.month, oggi.day),
                ),
              )
              .valueOrNull ??
          0,
    );

    final delGiorno = TargetDelGiorno.scegli(
      dalServer: n.haTarget ? n.targetKcal : null,
      locale: locale?.kcal.toDouble(),
      bruciate: bruciate.kcal,
      sommaLeBruciate: ref.watch(sommaLeBruciateProvider),
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

                  /*
                   * ══ 🚨 LA SIGLA, NON «CONSUMO» — 21/08/2026 sera ═════════
                   *
                   * 📌 Il committente, vedendola sul telefono: *«mi dice
                   * "consumato" 2271. Non va bene, mi dovrebbe dire il tdee,
                   * non il consumo. Cioè il discorso è che io qui devo avere:
                   * consumate/target | tdee | bruciate»*.
                   *
                   * ⚠️ **Aveva ragione, ed era un difetto di lettura, non di
                   * numero**: 2.271 era già il valore giusto. Ma la parola
                   * «consumo» accanto a «1.694 consumate» e a «60 bruciate» si
                   * legge come *«finora hai consumato 2.271»* — cioè un terzo
                   * numero della stessa famiglia, in contraddizione con gli
                   * altri due. 🚨 Una sigla non si può confondere con un
                   * conteggio: è il suo unico vantaggio qui.
                   *
                   * 💡 **La sigla è `TDEE`** — *Total Daily Energy
                   * Expenditure*. ⚠️ Per un giro è stata «TDAA», che il
                   * committente aveva usato a voce; corretta da lui stesso il
                   * 21/08 sera: *«se si dice tdee scrivici così»*. 🚨 Qui
                   * resta scritto perché la stessa sigla compare nei documenti
                   * e in due messaggi: chi la ritrova scritta «TDAA» da
                   * qualche parte sta leggendo qualcosa di superato.
                   */
                  if (consumo != null)
                    Padding(
                      padding: const EdgeInsets.only(right: Gap.sm),
                      child: Text(
                        'TDEE ${consumo.round()}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
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
      /*
       * ⚠️ **Porta dove si collega davvero** — 3b-P.8.3, 22/08/2026.
       *
       * Il pulsante dice «collega Health Connect»: da oggi il collegamento sta
       * in «Privacy e consensi», e mandare a `/sonno` — dove c'e' solo la
       * spiegazione — vorrebbe dire un invito che non porta all'azione che
       * promette.
       */
      onTap: () => context.push(AppRoutes.consensi),
    ),
  );
}

class TrainingCard extends ConsumerWidget {
  /// ⛔ **Non prende più il riepilogo del server** — 21/08/2026: tutto quello
  /// che disegnava da lì (la frase, il conteggio, l'elenco) ignorava gli
  /// allenamenti dell'orologio. Adesso legge da `riassuntoSettimanaProvider`.
  const TrainingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

            /*
             * ══ 🚨 UNA FONTE SOLA PER TUTTA LA SCHEDA ═══════════════════════
             *
             * 📌 Difetto riferito il 21/08/2026: *«La card allenamento è
             * sbagliata, mi dice che ho registrato un esercizio e non me lo
             * mostra (quello dell'altro ieri dall'orologio)»*.
             *
             * ⚠️ Questa frase, il conteggio e l'elenco venivano da **due posti
             * diversi**: `riepilogo.training` è il riassunto del server, che gli
             * allenamenti dell'orologio non li ha. 🚨 Il risultato non era una
             * riga mancante: era una **contraddizione dentro la stessa scheda**,
             * che fa dubitare di tutti e due i numeri.
             *
             * 💡 Adesso tutto passa da `riassuntoSettimanaProvider`, che unisce
             * le sedute del server e gli allenamenti del polso — la stessa fonte
             * del carico (FASE 2-sexies).
             */
            const _Allenamenti(),

            /*
             * ══ 🆕 IL RIASSUNTO DEI SETTE GIORNI — 3b-O.7.3 ═════════════════
             *
             * 📌 *«sopra ci deve essere un riassunto di quanto peso ho
             * sollevato, quanti km ho corso/camminato/biciclettato, quante
             * calorie ho bruciato […] quante proteine ho assunto e quanto ho
             * riposato»*.
             *
             * 💡 **Sopra l'elenco e non sotto**: chi apre «Oggi» vuole sapere
             * come sta andando la settimana, non rileggere i nomi delle sedute
             * che ha fatto lui. L'elenco resta perché serve ad *aprirne* una.
             */
            const _SetteGiorni(),
          ],
        ),
      ),
    );
  }
}

/// La frase in cima e l'elenco degli allenamenti — 3b-O.7.2, corretto il
/// 21/08/2026.
///
/// 🚨 Legge **solo** da `riassuntoSettimanaProvider`: vedi il commento nella
/// scheda per il perché.
class _Allenamenti extends ConsumerWidget {
  const _Allenamenti();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = ref.watch(riassuntoSettimanaProvider).valueOrNull;

    // 💡 Mentre carica non si scrive «nessun allenamento»: sarebbe una notizia
    // falsa per mezzo secondo, ed è quella che resta in mente.
    if (r == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // «Non ti alleni da 5 giorni» è l'informazione che fa tornare in
          // palestra: un elenco di date costringe a fare il conto a mente.
          switch (r.giorniDallUltimo) {
            null => 'Nessun allenamento registrato.',
            0 =>
              'Ti sei allenato oggi. ${r.ultimi30} sedute negli ultimi 30 giorni.',
            1 =>
              'Ultimo allenamento ieri. ${r.ultimi30} negli ultimi 30 giorni.',
            final g =>
              'Non ti alleni da $g giorni. ${r.ultimi30} negli ultimi 30.',
          },
          style: theme.textTheme.bodySmall,
        ),

        if (r.voci.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          GrigliaAllenamenti(voci: r.voci),
        ],
      ],
    );
  }
}

/// Gli allenamenti in quadrati, quattro per riga — 22/08/2026.
///
/// 📌 Il committente: *«gli allenamenti li vorrei in dei quadrati, 4 per riga,
/// massimo 8 con icona, data e kcal bruciate»*.
///
/// ── 🚨 Perché un `LayoutBuilder` e non una larghezza scritta a mano ───────
///
/// «Quattro per riga» **non è una larghezza**: è una divisione. Su un telefono
/// stretto il quarto quadrato da 76 px va a capo e ne restano tre, che è
/// esattamente il difetto corretto lo stesso giorno nel `Wrap` delle voci. ⛔
/// Un numero fisso è giusto solo sullo schermo su cui è stato provato.
///
/// 💡 Quindi la larghezza si **calcola**: `(spazio − 3 spazi vuoti) / 4`. Così
/// sono quattro su qualunque telefono, e su un tablet sono quattro più larghi
/// invece di sette stretti.
///
/// ⚠️ **Otto è un tetto, non un caso raro**: chi si allena tutti i giorni ne ha
/// più di otto in una settimana, e la scheda «Oggi» non è lo storico. Se ce ne
/// sono di più, l'ultimo quadrato lo dice e porta allo storico — ⛔ troncare in
/// silenzio farebbe sembrare che gli altri non esistano.
class GrigliaAllenamenti extends StatelessWidget {
  const GrigliaAllenamenti({required this.voci, super.key});

  final List<VoceStorico> voci;

  /// Quanti quadrati stanno in una riga.
  static const perRiga = 4;

  /// Quanti se ne mostrano al massimo — due righe piene.
  static const massimo = 8;

  @override
  Widget build(BuildContext context) {
    final mostrate = voci.take(massimo).toList();
    final altri = voci.length - mostrate.length;

    return LayoutBuilder(
      builder: (context, vincoli) {
        const spazio = Gap.sm;
        final lato = (vincoli.maxWidth - spazio * (perRiga - 1)) / perRiga;

        return Wrap(
          spacing: spazio,
          runSpacing: spazio,
          children: [
            for (final v in mostrate)
              SizedBox(
                width: lato,
                child: QuadratoAllenamento(voce: v),
              ),
            if (altri > 0)
              SizedBox(
                width: lato,
                child: QuadratoAltri(quanti: altri),
              ),
          ],
        );
      },
    );
  }
}

/// Un allenamento in un quadrato.
///
/// ⛔ **Quello che viene solo dall'orologio non si apre**, e non è una
/// dimenticanza: una pagina di dettaglio esiste per le sedute registrate
/// nell'app, che hanno gli esercizi dentro. 💡 Chi tocca una corsa finisce sullo
/// storico, dove quella riga c'è per intero.
///
/// ⚠️ **Il nome non ci sta, e non si perde**: in settanta pixel «Spinte
/// verticali e trazioni» diventa «Spinte…», che non dice niente più
/// dell'icona. 🚨 Va nel `tooltip` **e** nel `Semantics`: senza il secondo, chi
/// usa un lettore di schermo sentirebbe solo una data e un numero.
class QuadratoAllenamento extends StatelessWidget {
  const QuadratoAllenamento({required this.voce, super.key});

  final VoceStorico voce;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seduta = voce.seduta;
    final kcal = voce.kcalDalPolso ?? voce.kcalDalleSedute;
    final aperta = seduta != null && seduta.isOpen;

    // 🚨 Lo stesso titolo dello storico: `seduta.titolo` se c'è, altrimenti il
    // nome del tipo letto dall'orologio. Due modi di chiamare la stessa riga in
    // due schermate sono due righe che sembrano due allenamenti.
    final titolo =
        seduta?.titolo ?? TipoAllenamento.da(voce.dalPolso.first.tipo).nome;

    final icona = switch (seduta) {
      null => Icons.watch_outlined,
      final s when s.isOpen => Icons.play_circle_outline_rounded,
      _ => Icons.fitness_center_rounded,
    };

    /*
     * 💡 Le kcal se ci sono, altrimenti i minuti. ⛔ Non uno spazio vuoto e non
     * uno zero: lo zero direbbe «non hai bruciato niente», che è falso — vuol
     * dire solo che nessuno ce l'ha detto. La durata la sappiamo sempre.
     */
    final sotto = aperta
        ? 'in corso'
        : kcal != null
        ? '$kcal kcal'
        : '${voce.durata.inMinutes} min';

    return Tooltip(
      message: titolo,
      child: Semantics(
        label:
            '$titolo, ${DateFormat('d MMMM', 'it').format(voce.quando)}, '
            '$sotto',
        button: true,
        child: Material(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            // Conclusa → riepilogo; ancora aperta → player. Riaprire come
            // «allenamento in corso» una seduta di tre giorni fa non ha senso,
            // e rischia di sporcarla con dati di oggi.
            onTap: seduta == null
                ? () => context.push(AppRoutes.history)
                : () => context.push(
                    seduta.isOpen
                        ? AppRoutes.player(seduta.id)
                        : AppRoutes.riepilogo(seduta.id),
                  ),
            child: AspectRatio(
              // 🚨 Quadrati davvero: senza questo l'altezza la deciderebbe il
              // testo, e una riga con un titolo corto sarebbe più bassa
              // dell'altra. Erano «dei quadrati», non «dei rettangoli simili».
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (context, vincoli) {
                  final lato = vincoli.maxWidth;

                  /*
                   * ══ 🚨 IL CONTENUTO SI MISURA SUL QUADRATO ════════════════
                   *
                   * ⚠️ **Difetto trovato dal test, non a occhio.** Con misure
                   * fisse — icona 20, due righe di `labelSmall` — il contenuto
                   * chiede 60 px; su un telefono da 280 il quadrato ne ha 56, e
                   * sforava. 🚨 Sul telefono di sviluppo, dove il lato è 76, non
                   * si sarebbe visto mai.
                   *
                   * 💡 Quindi icona e testo si ricavano **dal lato**: tutti i
                   * quadrati della griglia hanno lo stesso lato, quindi hanno la
                   * stessa scala — non diventano otto misure diverse.
                   *
                   * ⛔ E il `FittedBox` sotto è la rete, non il piano: serve solo
                   * a chi ingrandisce il carattere di sistema, dove nessun
                   * calcolo fatto qui può prevedere l'altezza vera.
                   */
                  final iconaPx = (lato * 0.30).clamp(14.0, 22.0);
                  final testoPx = (lato * 0.16).clamp(8.0, 11.0);

                  return Padding(
                    padding: const EdgeInsets.all(3),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icona,
                            size: iconaPx,
                            color: aperta
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // 💡 «20 ago» e non «mer 20/08/2026»: in settanta
                            // pixel il giorno della settimana e l'anno sono i
                            // due pezzi che servono meno — l'anno perché sono
                            // gli ultimi sette giorni.
                            DateFormat('d MMM', 'it').format(voce.quando),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: testoPx,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                          ),
                          Text(
                            sotto,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: testoPx,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// L'ultimo quadrato quando ce ne sono più di otto.
///
/// ⛔ **Serve a non mentire per omissione.** Otto quadrati senza niente dopo
/// dicono «questi sono tutti»; chi si allena ogni giorno ne ha nove e crede di
/// averne perso uno.
class QuadratoAltri extends StatelessWidget {
  const QuadratoAltri({required this.quanti, super.key});

  final int quanti;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.history),
        child: AspectRatio(
          aspectRatio: 1,
          child: Center(
            // 💡 Stessa rete del quadrato accanto: a carattere ingrandito
            // «+12» in `titleMedium` non ci sta in 56 px.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Text(
                  '+$quanti',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Il riassunto degli ultimi sette giorni — 3b-O.7.3 e 3b-O.7.4.
///
/// ⛔ **Le voci senza dati spariscono**, e la scheda con nessuna voce non
/// disegna niente: è la regola di O.1b.1, e qui pesa di più perché questi numeri
/// sono somme su sette giorni. ⚠️ Uno zero da «dato mancante» non direbbe «non
/// lo so», direbbe «non hai fatto niente».
class _SetteGiorni extends ConsumerWidget {
  const _SetteGiorni();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final r = ref.watch(riassuntoSettimanaProvider).valueOrNull;

    if (r == null || r.vuoto) return const SizedBox.shrink();

    final voci = <(IconData, String, String)>[
      if (r.volumeKg != null)
        (Icons.fitness_center_rounded, _tonnellate(r.volumeKg!), 'sollevati'),
      if (r.metri != null)
        (
          Icons.directions_run_rounded,
          '${(r.metri! / 1000).toStringAsFixed(1)} km',
          'percorsi',
        ),
      if (r.kcalBruciate != null)
        (Icons.local_fire_department_rounded, '${r.kcalBruciate}', 'bruciate'),
      if (r.proteineG != null)
        (Icons.egg_alt_outlined, '${r.proteineG} g', 'proteine'),
      if (r.minutiDormiti != null)
        (
          Icons.bedtime_outlined,
          '${(r.minutiDormiti! / 60).round()} h',
          'di sonno',
        ),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ultimi 7 giorni · ${r.sedute} '
            '${r.sedute == 1 ? 'allenamento' : 'allenamenti'}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: Gap.sm),

          /*
           * ══ 🚨 UNA RIGA SOLA, E LO SPAZIO SI DIVIDE — 22/08/2026 ═════════
           *
           * 📌 Il committente: *«le 4 icone devono stare nella stessa riga, è
           * brutto che siano tre sopra e una sotto»*.
           *
           * ⚠️ Prima era un `Wrap` con i figli larghi 76 px fissi: su 328 px di
           * scheda ce ne stavano **tre**, e la quarta andava a capo da sola,
           * spaiata. 🚨 Una larghezza fissa dentro un contenitore che va a capo
           * decide quante colonne vengono **per caso**, in base allo schermo.
           *
           * 💡 Un `Row` con `Expanded` fa il contrario: il numero di colonne lo
           * decidiamo noi — sono quante sono le voci — e la larghezza la
           * calcola Flutter dividendo lo spazio. Con cinque voci diventano
           * cinque colonne più strette, mai due righe.
           *
           * ⛔ **`Expanded` qui è legale, dentro il `Wrap` di prima no**: è la
           * trappola di §56.3 n° 1 (`WrapParentData is not a subtype of
           * FlexParentData`), che l'analizzatore non vede e che esplode a
           * schermo. Il `Row` è un `Flex`, quindi va.
           *
           * ⚠️ Con cinque voci si scende sotto i 65 px a colonna: per questo
           * ogni testo ha `ellipsis`, invece di sforare.
           */
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (icona, valore, etichetta) in voci)
                Expanded(
                  child: Column(
                    children: [
                      Icon(icona, size: 16, color: theme.colorScheme.primary),
                      Text(
                        valore,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        etichetta,
                        style: theme.textTheme.labelSmall,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
            ],
          ),

          if (r.pesoStimatoKg != null) ...[
            const SizedBox(height: Gap.sm),
            _PesoStimato(kg: r.pesoStimatoKg!),
          ],
        ],
      ),
    );
  }

  /// 💡 In tonnellate sopra i mille chili: «12.400 kg» si legge male, e in una
  /// settimana di palestra ci si arriva senza sforzo.
  static String _tonnellate(double kg) =>
      kg >= 1000 ? '${(kg / 1000).toStringAsFixed(1)} t' : '${kg.round()} kg';
}

/// Quanto peso si sarebbe perso o guadagnato — 3b-O.7.4.
///
/// 🚨 **L'avvertenza non è facoltativa.** Il numero esce da 7.700 kcal per
/// chilo, che è una stima del 1958 e non tiene conto di acqua, glicogeno né
/// dell'adattamento metabolico. ⚠️ Senza la riga sotto si legge come una misura,
/// e chi non la vede confermata dalla bilancia smette di fidarsi dell'app.
class _PesoStimato extends StatelessWidget {
  const _PesoStimato({required this.kg});

  final double kg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ⚠️ Sotto i 50 grammi non si scrive «−0.0 kg», che sembra un guasto.
    final trascurabile = kg.abs() < 0.05;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Gap.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            trascurabile
                ? 'In pari con il tuo consumo, questa settimana.'
                : '${kg > 0 ? '+' : ''}${kg.toStringAsFixed(1)} kg '
                      'con quanto hai mangiato e speso',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            'Stima da 7.700 kcal per chilo: non è una misura, e le prime '
            'settimane sbaglia per eccesso.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
