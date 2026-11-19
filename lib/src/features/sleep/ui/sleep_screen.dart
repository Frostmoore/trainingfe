import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/barra_della_data.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/sezioni.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/testata_scura.dart';
import '../../health/sessioni_di_sonno.dart';
import '../../health/ui/widgets/cosa_leggiamo.dart';
import '../sleep_controller.dart';

/// Il sonno — C14.
///
/// ⚠️ **Il backend era pronto da B9 e non lo usava nessuno.** Ipnogramma,
/// minuti per fase, percentuali e giudizi arrivano già calcolati: questa
/// schermata li disegna e basta. Le soglie di ciò che è un sonno sano sono una
/// scelta di prodotto e stanno in `SleepAnalyzer`, in un posto solo.
class SleepScreen extends ConsumerWidget {
  const SleepScreen({super.key});

  static const _colori = <int, Color>{
    1: Color(0xFFE5564A), // sveglio
    2: Color(0xFF5B74E8), // leggero
    3: Color(0xFF7D54D8), // profondo
    4: Color(0xFF2FBF6B), // REM
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notte = ref.watch(sleepProvider);
    final pisolini = ref.watch(pisoliniProvider).valueOrNull ?? const [];

    return Scaffold(
      // 🌑 Senza angoli solo quando sotto c'è il seguito scuro con la notte —
      // I8. Senza notte (vuoto, errore, solo riposi brevi) li tiene lei.
      appBar: IntestazioneApp(
        titolo: 'Sonno',
        arrotondata: notte.valueOrNull == null,
      ),
      body: notte.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(sleepProvider),
        ),
        data: (n) => n == null
            /*
             * 🚨 **Senza notte, ma con pennichelle, si mostrano quelle** —
             * 21/08/2026.
             *
             * ⚠️ Prima qui compariva «Nessun dato sul sonno» anche a chi aveva
             * dormito due ore nel pomeriggio: il dato c'era, era letto, era
             * salvato, e la schermata diceva che non esisteva. 💡 Dire «non ho
             * dati» quando i dati ci sono è il modo più rapido per far smettere
             * di fidarsi di una schermata.
             */
            ? (pisolini.isEmpty
                  ? const EmptyState(
                      icon: Icons.bedtime_outlined,
                      title: 'Nessun dato sul sonno',
                      message:
                          'I dati arrivano dall\'orologio. Assicurati che la categoria '
                          'Sonno sia attiva nell\'app che li invia, e fai una sincronizzazione.',
                    )
                  : ListView(
                      padding: const EdgeInsets.all(Gap.md),
                      children: [
                        const _SenzaNotte(),
                        const SizedBox(height: Gap.md),
                        _Pisolini(pisolini: pisolini),
                      ],
                    ))
            : _Notte(notte: n, ref: ref, pisolini: pisolini),
      ),
    );
  }
}

/// 💡 C'è la giornata, ma non una dormita principale.
class _SenzaNotte extends StatelessWidget {
  const _SenzaNotte();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.nights_stay_outlined,
              color: tema.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                'Per questa giornata non risulta una dormita notturna — solo '
                'riposi brevi. Non li sommiamo come se fossero una notte.',
                style: tema.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// I riposi brevi della giornata — 21/08/2026.
///
/// ══ 🚨 PERCHÉ STANNO A PARTE, E NON NEL TOTALE ════════════════════════════
///
/// 📌 Il committente: *«la notte ho dormito 5:16 ma poi ho fatto due pisolini,
/// vedi se ti risultano perché sull'app non si vedono»*.
///
/// ⚠️ Il 20/08 il difetto era **l'opposto**: le pennichelle finivano dentro il
/// totale della notte e la facevano sembrare riposante. La correzione le ha
/// tolte dal conto — giustamente — ma le ha tolte **anche dalla vista**.
///
/// 💡 Qui si rimettono dove devono stare: **visibili e separate**. Sommarle alla
/// notte sarebbe rifare il difetto vecchio; nasconderle è buttare via un'ora e
/// mezza di sonno vera.
class _Pisolini extends StatelessWidget {
  const _Pisolini({required this.pisolini});

  final List<SessioneSonno> pisolini;

  static String _durata(Duration d) {
    final ore = d.inHours;
    final minuti = d.inMinutes % 60;

    return ore > 0 ? '${ore}h ${minuti}m' : '${minuti}m';
  }

  @override
  Widget build(BuildContext context) {
    if (pisolini.isEmpty) return const SizedBox.shrink();

    final tema = Theme.of(context);
    final ora = DateFormat('HH:mm');

    final totale = pisolini.fold(Duration.zero, (somma, p) => somma + p.durata);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.weekend_outlined, color: tema.colorScheme.primary),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    pisolini.length == 1 ? 'Un riposo breve' : 'Riposi brevi',
                    style: tema.textTheme.titleMedium,
                  ),
                ),
                Text(
                  _durata(totale),
                  style: tema.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: tema.colorScheme.primary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.sm),

            for (final p in pisolini)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${ora.format(p.inizio)} – ${ora.format(p.fine)}',
                        style: tema.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      _durata(p.durata),
                      style: tema.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: Gap.sm),

            /*
             * 🚨 **Va detto che NON sono nel totale della notte**, o il numero
             * grande sopra sembrerà sbagliato a chi sa di aver dormito di più.
             * ⚠️ Un totale che non torna, senza una riga che spieghi perché, è un
             * totale di cui si smette di fidarsi.
             */
            Text(
              'Contati a parte: non entrano nel totale della notte né nel '
              'giudizio sul recupero.',
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notte extends StatelessWidget {
  const _Notte({
    required this.notte,
    required this.ref,
    this.pisolini = const [],
  });

  final SleepNight notte;
  final WidgetRef ref;

  /// I riposi brevi della stessa giornata, se ce ne sono.
  final List<SessioneSonno> pisolini;

  /// Il colore del giudizio: verde non serve, l'assenza di allarme è già
  /// l'informazione.
  static Color? _coloreGiudizio(BuildContext context, String? giudizio) =>
      switch (giudizio) {
        'bad' => Theme.of(context).colorScheme.error,
        'warn' => const Color(0xFFE0B341),
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /*
     * ══ 🌑 LA TESTATA — `plan_interfaccia.md` I8, 19/11/2026 ══════════════
     *
     * 📌 Tavola «Sonno»: in testata la notte (frecce e data), le ore, l'orario
     * e l'ipnogramma (I8.D2); nel corpo le fasi a coppie, i riposi brevi, e
     * quello che c'era sotto.
     *
     * 💡 L'ipnogramma è **lo stesso** di prima, con le larghezze proporzionali
     * alla durata (C14): cambia dove sta, non come disegna.
     */
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        CodaDellaTestata(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BarraDellaData(
                testo: DateFormat('EEEE d MMMM', 'it').format(notte.night),
                etichettaPrima: 'Notte prima',
                etichettaDopo: 'Notte dopo',
                onPrima: () => ref.read(sleepNightProvider.notifier).state =
                    notte.night.subtract(const Duration(days: 1)),
                onDopo: () => ref.read(sleepNightProvider.notifier).state =
                    notte.night.add(const Duration(days: 1)),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      notte.durata,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _coloreGiudizio(
                          context,
                          notte.ratings['asleep_minutes'],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    '${DateFormat('HH:mm').format(notte.from)} → '
                    '${DateFormat('HH:mm').format(notte.to)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              _Ipnogramma(notte: notte),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _corpo(context, theme),
          ),
        ),
      ],
    );
  }

  List<Widget> _corpo(BuildContext context, ThemeData theme) => [
    const TitoloDiSezione('Le fasi'),
    const SizedBox(height: 10),
    Coppia(
      sinistra: _Fase(
        colore: SleepScreen._colori[3]!,
        nome: 'Profondo',
        minuti: notte.deepMinutes,
        totale: notte.asleepMinutes + notte.awakeMinutes,
        percentuale: notte.deepPct,
        giudizio: notte.ratings['deep_pct'],
      ),
      destra: _Fase(
        colore: SleepScreen._colori[4]!,
        nome: 'REM',
        minuti: notte.remMinutes,
        totale: notte.asleepMinutes + notte.awakeMinutes,
        percentuale: notte.remPct,
        giudizio: notte.ratings['rem_pct'],
      ),
    ),
    const SizedBox(height: 10),
    Coppia(
      sinistra: _Fase(
        colore: SleepScreen._colori[2]!,
        nome: 'Leggero',
        minuti: notte.lightMinutes,
        totale: notte.asleepMinutes + notte.awakeMinutes,
      ),
      destra: _Fase(
        colore: SleepScreen._colori[1]!,
        nome: 'Sveglio',
        minuti: notte.awakeMinutes,
        totale: notte.asleepMinutes + notte.awakeMinutes,
        giudizio: notte.ratings['awake_minutes'],
      ),
    ),

    /*
         * 🆕 **I riposi brevi, sotto la notte e separati da essa** — 21/08.
         *
         * ⚠️ Sotto e non sopra: la domanda che porta qui è «come ho dormito
         * stanotte», e mettere le pennichelle prima farebbe leggere per primo il
         * numero più piccolo. 💡 Sparisce da sola quando non ce ne sono — e con
         * lei il suo titolo (I8.D3: né sommati né nascosti).
         */
    if (pisolini.isNotEmpty) ...[
      const TitoloDiSezione('Riposi brevi'),
      const SizedBox(height: 10),
      _Pisolini(pisolini: pisolini),
    ],

    if (notte.disclaimer != null) ...[
      const SizedBox(height: Gap.lg),
      Text(
        notte.disclaimer!,
        style: theme.textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    ],

    /*
         * ══ 🌙 QUI FINISCE «SONNO E RECUPERO» — 3b-P.8.1, 22/08/2026 ═══════
         *
         * 📌 Il committente: *«questa pagina dovrebbe apparire sotto
         * all'ipnogramma della pagina sonno, quindi non ha molto senso tenerla
         * qui nelle impostazioni»*.
         *
         * 💡 **Chi guarda il proprio sonno e' esattamente chi si chiede da
         * dove arrivino quei dati.** Nelle impostazioni quella spiegazione la
         * leggeva solo chi la cercava.
         *
         * ⛔ **Il collegamento a Health Connect non e' qui**: sta in «Privacy e
         * consensi», perche' collegare e' un consenso, non un'impostazione.
         */
    const SizedBox(height: Gap.xl),
    const CosaLeggiamoDaSalute(),

    const SizedBox(height: Gap.xl),
  ];
}

/// L'ipnogramma a bande.
///
/// 🚨 La larghezza di ogni blocco è **proporzionale alla sua durata reale**, non
/// al numero di blocchi: un risveglio di due minuti e uno di quaranta devono
/// vedersi diversi, o il grafico racconta una notte che non c'è stata.
class _Ipnogramma extends StatefulWidget {
  const _Ipnogramma({required this.notte});

  final SleepNight notte;

  @override
  State<_Ipnogramma> createState() => _IpnogrammaState();
}

class _IpnogrammaState extends State<_Ipnogramma> {
  static const _altezzaBanda = 22.0;

  /// La colonna dei nomi delle righe, a sinistra del grafico — I8.
  static const _larghezzaNomi = 60.0;

  /// L'ordine verticale: sveglio in alto, profondo in basso, come su ogni
  /// dispositivo che disegna il sonno.
  static const _riga = {1: 0, 4: 1, 2: 2, 3: 3};

  /// Dove sta il dito, in frazione della larghezza. `null` = non lo si sta
  /// toccando.
  double? _dito;

  SleepNight get _notte => widget.notte;

  /// L'istante sotto il dito.
  ///
  /// 💡 Si interpola sulla **durata reale** della notte, non sul numero di
  /// blocchi: è la stessa proporzione con cui sono disegnati, quindi l'ora che
  /// si legge è esattamente quella del punto che si sta guardando.
  DateTime _istanteA(double frazione) => _notte.from.add(
    Duration(
      seconds:
          (_notte.to.difference(_notte.from).inSeconds *
                  frazione.clamp(0.0, 1.0))
              .round(),
    ),
  );

  SleepBlock? _bloccoA(DateTime istante) {
    for (final b in _notte.hypnogram) {
      if (!istante.isBefore(b.from) && istante.isBefore(b.to)) return b;
    }

    return _notte.hypnogram.isEmpty ? null : _notte.hypnogram.last;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_notte.hypnogram.isEmpty) {
      return Text(
        'Questa notte non ha il dettaglio delle fasi.',
        style: theme.textTheme.bodySmall,
      );
    }

    final totale = _notte.to.difference(_notte.from).inSeconds;

    if (totale <= 0) return const SizedBox.shrink();

    final istante = _dito == null ? null : _istanteA(_dito!);
    final blocco = istante == null ? null : _bloccoA(istante);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        /*
         * 🚨 L'etichetta sta **sopra** il grafico e occupa sempre la sua riga.
         *
         * Mettendola sotto, o facendola comparire solo al tocco, il grafico si
         * sposterebbe sotto il dito mentre lo si trascina — e si finirebbe a
         * leggere l'ora di un punto diverso da quello che si sta toccando.
         */
        SizedBox(
          height: 20,
          child: blocco == null
              ? Text(
                  'Trascina il dito sul grafico per vedere l\'ora',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                )
              : Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: SleepScreen._colori[blocco.stage] ?? Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Gap.xs),
                    Text(
                      '${DateFormat('HH:mm').format(istante!)} · ${blocco.label}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: Gap.xs),

        /*
         * 🏷️ **I nomi delle righe, a sinistra** — I8, 19/11/2026.
         *
         * 📌 La leggenda dei colori stava sotto il grafico; ora le fasi sono
         * tessere più giù, e il grafico in testata si deve leggere da solo. 💡
         * Il nome sulla riga è più diretto di un colore da cercare in legenda.
         * ⚠️ Lo stesso ordine di [_riga]: sveglio in alto, profondo in basso.
         */
        Row(
          children: [
            SizedBox(
              width: _larghezzaNomi,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final nome in ['Sveglio', 'REM', 'Leggero', 'Profondo'])
                    SizedBox(
                      height: _altezzaBanda,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          nome,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SizedBox(
                height: _altezzaBanda * 4,
                child: LayoutBuilder(
                  builder: (context, vincoli) => GestureDetector(
                    // ⚠️ `opaque`: senza, il tocco passa attraverso gli spazi vuoti
                    // fra le bande e il trascinamento si interrompe da solo appena il
                    // dito attraversa una riga senza blocco.
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (d) =>
                        _aggiorna(d.localPosition.dx, vincoli.maxWidth),
                    onHorizontalDragUpdate: (d) =>
                        _aggiorna(d.localPosition.dx, vincoli.maxWidth),
                    onHorizontalDragEnd: (_) => setState(() => _dito = null),
                    onHorizontalDragCancel: () => setState(() => _dito = null),
                    onTapDown: (d) =>
                        _aggiorna(d.localPosition.dx, vincoli.maxWidth),
                    onTapUp: (_) => setState(() => _dito = null),
                    onTapCancel: () => setState(() => _dito = null),
                    child: Stack(
                      children: [
                        for (final b in _notte.hypnogram)
                          Positioned(
                            left:
                                b.from.difference(_notte.from).inSeconds /
                                totale *
                                vincoli.maxWidth,
                            top: (_riga[b.stage] ?? 2) * _altezzaBanda,
                            width:
                                (b.to.difference(b.from).inSeconds /
                                        totale *
                                        vincoli.maxWidth)
                                    .clamp(1.0, vincoli.maxWidth),
                            height: _altezzaBanda,
                            child: ColoredBox(
                              color:
                                  SleepScreen._colori[b.stage] ?? Colors.grey,
                            ),
                          ),

                        // La linea che segue il dito: senza, si legge un'ora e non si
                        // sa a quale punto del grafico appartenga.
                        if (_dito != null)
                          Positioned(
                            left: (_dito! * vincoli.maxWidth).clamp(
                              0.0,
                              vincoli.maxWidth - 2,
                            ),
                            top: 0,
                            width: 2,
                            height: _altezzaBanda * 4,
                            child: ColoredBox(
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _aggiorna(double dx, double larghezza) {
    if (larghezza <= 0) return;

    setState(() => _dito = (dx / larghezza).clamp(0.0, 1.0));
  }
}

class _Fase extends StatelessWidget {
  const _Fase({
    required this.colore,
    required this.nome,
    required this.minuti,
    required this.totale,
    this.percentuale,
    this.giudizio,
  });

  final Color colore;
  final String nome;
  final int minuti;
  final double? percentuale;
  final String? giudizio;

  /// I minuti dell'intera notte (sonno + veglia): la barra della fase è la sua
  /// quota di **tutta** la notte, così le quattro barre sommate fanno una notte.
  final int totale;

  @override
  Widget build(BuildContext context) {
    final allarme = _Notte._coloreGiudizio(context, giudizio);

    final theme = Theme.of(context);

    /*
     * 🃏 **Una tessera per fase** — I8, 19/11/2026 (tavola «Sonno»).
     *
     * 📌 Era la leggenda sotto l'ipnogramma, resa piccola apposta (3b-P.8.2:
     * *la leggenda spiegava l'ipnogramma e finiva per pesare più di lui*). 💡 Ora
     * il grafico sta in testata con i nomi delle righe accanto, e qui le fasi
     * sono una sezione a sé: non competono più con il grafico.
     *
     * ⛔ Il colore della fase resta — nella barra — perché è quello che lega la
     * tessera alla sua riga del grafico.
     */
    return Tessera(
      etichetta: nome,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${minuti ~/ 60}h ${(minuti % 60).toString().padLeft(2, '0')}',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Gap.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: totale <= 0 ? 0 : (minuti / totale).clamp(0.0, 1.0),
              minHeight: 6,
              color: colore,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          if (percentuale != null) ...[
            const SizedBox(height: Gap.xs),
            Text(
              '${percentuale!.toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: allarme,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
