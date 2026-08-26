import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../diary/data/target_del_giorno.dart';
import '../../../health/health_controller.dart';
import '../../../profile/somma_bruciate.dart';
import '../../../profile/target_locale_controller.dart';
import '../../../training/bruciate_locali.dart';
import '../../dashboard_controller.dart';
import '../../saldo_calorico.dart';
import 'barra_del_consumo.dart';

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

    /*
     * ══ 🚨 DUE NUMERI, DUE DOMANDE DIVERSE — 3b-F, 26/08/2026 ═══════════════
     *
     * 📌 *«il modo giusto di calcolare il grafico sotto è quello di mettere su 0
     * l'obbiettivo, sopra le calorie consumate, sotto le calorie bruciate
     * (dall'allenamento) e fare la sottrazione di queste cose. Lì il tdee non
     * dovrebbe avere spazio»*.
     *
     * 💡 Il **riquadro del dito** parla dell'obiettivo, che è la linea di base
     * del grafico: rispondere lì con un'altra grandezza vorrebbe dire un numero
     * che non c'entra con quello che si sta guardando.
     *
     * ⚠️ La **media in fondo** invece parla del consumo, e deve: «deficit» vuol
     * dire *rispetto a quanto spendi*, non rispetto a quanto ti eri ripromesso —
     * ed è quella che diventa peso.
     */
    final tdee = locale?.tdee;

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
                  tdee: tdee,
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
    required this.tdee,
    required this.finestra,
  });

  final Series serie;
  final Map<String, int> daHealth;
  final Map<String, int> locali;
  final double? target;

  /// Il consumo della **vita quotidiana** — serve solo alla media in fondo.
  final double? tdee;

  final CaloriesWindow finestra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    /*
     * ══ 🚨 L'OBIETTIVO SI COMPONE QUI, E NON PIU' IN BASSO ══════════════════
     *
     * ⚠️ `TargetDelGiorno.scegli` va chiamato **dove il `ref` c'è**, con dentro
     * `ref.watch(sommaLeBruciateProvider)` scritto per esteso. 🚨 Non è pedanteria:
     * c'è una guardia in `impostazioni_riordinate_test.dart` che scandisce tutto
     * `lib/` e fa fallire chi passa un valore fisso — perché quello **compila**,
     * e sarebbe un'app che ignora l'interruttore in una sola delle schermate che
     * mostrano l'obiettivo.
     *
     * 💡 Un obiettivo per giorno: le bruciate cambiano giorno per giorno, quindi
     * l'obiettivo pure — ed è esattamente il numero contro cui il riquadro del
     * dito confronta le assunte.
     */
    final obiettivi = <double>[
      for (var i = 0; i < serie.dates.length; i++)
        TargetDelGiorno.scegli(
              dalServer: null,
              locale: target,
              bruciate: bruciateDi(serie, i, daHealth, locali).round(),
              sommaLeBruciate: ref.watch(sommaLeBruciateProvider),
              bruciateExtra:
                  ref
                      .watch(
                        bruciateExtraDelGiornoProvider(
                          DateTime.tryParse(serie.dates[i]) ?? DateTime(0),
                        ),
                      )
                      .valueOrNull ??
                  0,
            ).kcal ??
            (target ?? 0),
    ];

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
              _dati(context, serie, daHealth, locali, target!, obiettivi),
            ),
          ),

        const SizedBox(height: Gap.sm),

        _Pasticche(
          serie: serie,
          daHealth: daHealth,
          locali: locali,
          obiettivi: obiettivi,
        ),
      ],
    );
  }
}

/// Il riassunto del periodo, in **tre pasticche** — 3b-F.9, 26/08/2026.
///
/// ══ 📌 LA SEGNALAZIONE ════════════════════════════════════════════════════
///
/// *«fa cagare messo così, o me lo metti in un elenco puntato o me lo metti in
/// delle pasticche, perché le frasi "Media x calorie sugli y giorni in cui hai
/// registrato. Media x kcal bruciate su y giorni bla bla e media x kcal sotto il
/// target sugli y giorni eccetera" fa veramente schifo»*.
///
/// ⛔ **Aveva ragione, ed era colpa di come sono cresciute.** Le tre righe sono
/// nate in tre momenti diversi — le assunte in 3b-O.9, le bruciate il 22/08, il
/// target stanotte — e ognuna, presa da sola, era una frase ragionevole. 🚨
/// Messe in fila diventavano *«Media … sui … giorni in cui …»* per tre volte:
/// nessuno le legge, e chi ci prova non trova il numero che cerca.
///
/// 💡 Sono **tre misure dello stesso periodo**, e una griglia lo dice meglio di
/// tre frasi: il numero grande si trova a colpo d'occhio, e il contesto — su
/// quanti giorni — sta sotto, dove serve solo a chi lo cerca.
///
/// ⚠️ **Il contesto resta però su ognuna, e non in fondo**: i tre conteggi sono
/// diversi (i giorni con diario, quelli in cui ci si è mossi, quelli completi) e
/// una nota sola in fondo si leggerebbe come se valesse per tutti e tre.
///
/// ⛔ **Una pasticca senza dati non compare.** È la regola di tutta la pagina:
/// uno zero afferma qualcosa, un'assenza no.
class _Pasticche extends StatelessWidget {
  const _Pasticche({
    required this.serie,
    required this.daHealth,
    required this.locali,
    required this.obiettivi,
  });

  final Series serie;
  final Map<String, int> daHealth;
  final Map<String, int> locali;
  final List<double> obiettivi;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    /*
     * ══ 🚨 LE BRUCIATE SI CONTANO DA `bruciateDi` — 22/08/2026 ═════════════
     *
     * ⚠️ Qui c'era `serie.avgBurned`, che è la media del **server**. ⛔ Dopo la
     * FASE 11 il server gli allenamenti non ce li ha più: quel campo vale
     * **zero per tutti**, e la riga diceva «0 bruciate» sotto un grafico che
     * nella stessa schermata disegnava la linea arancione.
     *
     * 💡 Si conta dalla stessa funzione che disegna la linea: una sola, quindi
     * non possono più discordare.
     */
    var bruciate = 0.0;
    var giorniMossi = 0;

    for (var i = 0; i < serie.labels.length; i++) {
      final b = bruciateDi(serie, i, daHealth, locali);

      if (b > 0) {
        bruciate += b;
        giorniMossi++;
      }
    }

    final medio = saldoMedioDelPeriodo(
      giorni: [
        for (final d in serie.dates) DateTime.tryParse(d) ?? DateTime(0),
      ],
      assunte: serie.consumed,
      obiettivi: obiettivi,
      adesso: DateTime.now(),
    );

    final pasticche = <Widget>[
      if (serie.daysWithData > 0)
        _Pasticca(
          icona: Icons.restaurant_rounded,
          valore: '${serie.avgConsumed}',
          etichetta: 'assunte',
          giorni: serie.daysWithData,
        ),
      if (giorniMossi > 0)
        _Pasticca(
          icona: Icons.local_fire_department_rounded,
          valore: '${(bruciate / giorniMossi).round()}',
          etichetta: 'bruciate',
          giorni: giorniMossi,
          colore: BarraDelConsumo.fuoco,
        ),
      if (medio != null)
        _Pasticca(
          icona: Icons.adjust_rounded,
          valore: '${medio.kcalAlGiorno.abs().round()}',
          /*
           * ⚠️ **«sotto/sopra il target» e non «deficit/surplus».** Quelle due
           * parole, in palestra, vogliono dire *rispetto a quanto spendi*: qui
           * si parla della distanza dall'obiettivo, ed è un'altra cosa.
           * 🚨 Il riferimento sta **nell'etichetta**, non in una nota altrove.
           */
          etichetta: medio.sotto ? 'sotto il target' : 'sopra il target',
          giorni: medio.giorni,
          colore: medio.sotto
              ? tema.colorScheme.tertiary
              : tema.colorScheme.primary,
        ),
    ];

    if (pasticche.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: Gap.sm),
        child: Text(
          'Nessun giorno registrato in questo periodo.',
          style: tema.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Column(
        children: [
          /*
           * 📌 *«ci va solo scritto sopra "Medie" sennò non si capisce che sono
           * medie»*.
           *
           * 🚨 **Le tre frasi lo dicevano, le pasticche no.** Togliendo le
           * parole per far posto ai numeri se n'era andata anche quella —
           * «2.200» accanto a «assunte» si legge come *«oggi ne hai mangiate
           * 2.200»*, che e' un'altra cosa e per giunta plausibile.
           *
           * ⚠️ E' il prezzo di ogni compattazione: si perde sempre qualcosa, e
           * il mestiere sta nel decidere **cosa** invece di scoprirlo dopo.
           */
          Text(
            'Medie del periodo',
            style: tema.textTheme.labelLarge?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: pasticche,
          ),
        ],
      ),
    );
  }
}

/// Una pasticca: un numero grande, cosa vuol dire, e su quanti giorni.
///
/// 🚨 **Il conteggio dei giorni è parte del numero**, non una nota: «2.200 di
/// media» su due giorni su sette non è lo stesso dato che su sette, e senza
/// dirlo si legge come se lo fosse.
class _Pasticca extends StatelessWidget {
  const _Pasticca({
    required this.icona,
    required this.valore,
    required this.etichetta,
    required this.giorni,
    this.colore,
  });

  final IconData icona;
  final String valore;
  final String etichetta;
  final int giorni;
  final Color? colore;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final tinta = colore ?? tema.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Gap.sm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icona, size: 14, color: tinta),
              const SizedBox(width: 4),
              Text(
                valore,
                style: tema.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tinta,
                ),
              ),
            ],
          ),
          Text(etichetta, style: tema.textTheme.labelSmall),
          Text(
            // 💡 «su 5 gg» e non «sui 5 giorni in cui hai registrato qualcosa»:
            // in una pasticca lo spazio è quello, e la frase lunga era proprio
            // il difetto da cui si è partiti.
            'su $giorni ${giorni == 1 ? 'giorno' : 'gg'}',
            style: tema.textTheme.labelSmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
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
  List<double> obiettivi,
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

    lineTouchData: _tocco(context, s, obiettivi),
  );
}

/// Il riquadro che compare col dito — 3b-O.9.4.
///
/// 📌 Chiesto il 21/08 come *«calorie assunte oltre tdaa - calorie bruciate»*, e
/// **ridefinito dal committente il 26/08**: *«mettere su 0 l'obbiettivo, sopra le
/// calorie consumate, sotto le calorie bruciate (dall'allenamento) e fare la
/// sottrazione di queste cose. Li' il tdee non dovrebbe avere spazio»*.
///
/// 💡 Ed e' la lettura giusta: la linea di base del grafico **e'** l'obiettivo,
/// quindi il numero che compare col dito deve parlare di quello. ⚠️ Il consumo
/// non e' sparito: e' il riferimento della **media** in fondo alla card, dove
/// «deficit» vuol dire davvero *rispetto a quanto spendi*.
LineTouchData _tocco(BuildContext context, Series s, List<double> obiettivi) {
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
            _vocePerIlDito(theme, s, punto.x.toInt(), obiettivi),
      ],
    ),
  );
}

/// Il testo dentro il riquadro del dito.
///
/// ══ 🚨 IL SALDO E' RISPETTO ALL'OBIETTIVO, E IL TDEE NON C'ENTRA ══════════
///
/// 📌 *«mettere su 0 l'obbiettivo, sopra le calorie consumate, sotto le calorie
/// bruciate (dall'allenamento) e fare la sottrazione di queste cose. Lì il tdee
/// non dovrebbe avere spazio»*.
///
/// 💡 È la linea di base del grafico: rispondere col dito su un'altra grandezza
/// vorrebbe dire un numero che non c'entra con quello che si sta guardando.
///
/// ⚠️ **L'obiettivo lo compone `TargetDelGiorno`**, non questa funzione:
/// `obiettivo = target + allenamento` quando l'interruttore è acceso, e `target`
/// e basta quando è spento. 🚨 Scrivere qui `assunte − target − allenamento`
/// darebbe lo stesso numero **solo con l'interruttore acceso** — e a chi l'ha
/// spento il grafico contraddirebbe la card sopra, che è il modo più rapido per
/// far smettere di fidarsi di tutti e due.
LineTooltipItem? _vocePerIlDito(
  ThemeData theme,
  Series s,
  int i,
  List<double> obiettivi,
) {
  final assunte = i < s.consumed.length ? s.consumed[i] : 0.0;
  final giorno = i < s.labels.length ? s.labels[i] : '';

  if (assunte <= 0) {
    return LineTooltipItem(
      '$giorno · nessun dato',
      theme.textTheme.labelSmall!.copyWith(
        color: theme.colorScheme.onInverseSurface,
      ),
    );
  }

  final saldo = saldoDelGiorno(
    assunte: assunte,
    obiettivo: i < obiettivi.length ? obiettivi[i] : 0,
  );

  return LineTooltipItem(
    '$giorno\n'
    '${saldo > 0 ? '+' : ''}${saldo.round()} kcal '
    '${saldo > 0 ? 'in più' : 'in meno'}\n'
    // ⚠️ Si dice **rispetto a cosa**: senza, «−458» è un numero senza unità di
    // misura. E la media qui sotto parla di un'altra cosa ancora.
    'rispetto all\'obiettivo',
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
