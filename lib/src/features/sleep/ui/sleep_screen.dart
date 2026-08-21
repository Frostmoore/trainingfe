import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Sonno')),
      body: notte.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(sleepProvider),
        ),
        data: (n) => n == null
            ? const EmptyState(
                icon: Icons.bedtime_outlined,
                title: 'Nessun dato sul sonno',
                message:
                    'I dati arrivano dall\'orologio. Assicurati che la categoria '
                    'Sonno sia attiva nell\'app che li invia, e fai una sincronizzazione.',
              )
            : _Notte(notte: n, ref: ref),
      ),
    );
  }
}

class _Notte extends StatelessWidget {
  const _Notte({required this.notte, required this.ref});

  final SleepNight notte;
  final WidgetRef ref;

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

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => ref.read(sleepNightProvider.notifier).state =
                  notte.night.subtract(const Duration(days: 1)),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                DateFormat('EEEE d MMMM', 'it').format(notte.night),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: () => ref.read(sleepNightProvider.notifier).state =
                  notte.night.add(const Duration(days: 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),

        const SizedBox(height: Gap.sm),
        Center(
          child: Text(
            notte.durata,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: _coloreGiudizio(context, notte.ratings['asleep_minutes']),
            ),
          ),
        ),
        Center(
          child: Text(
            '${DateFormat('HH:mm').format(notte.from)} → ${DateFormat('HH:mm').format(notte.to)}',
            style: theme.textTheme.bodySmall,
          ),
        ),

        const SizedBox(height: Gap.lg),
        _Ipnogramma(notte: notte),

        const SizedBox(height: Gap.lg),
        _Fase(
          colore: SleepScreen._colori[3]!,
          nome: 'Profondo',
          minuti: notte.deepMinutes,
          percentuale: notte.deepPct,
          giudizio: notte.ratings['deep_pct'],
        ),
        _Fase(
          colore: SleepScreen._colori[4]!,
          nome: 'REM',
          minuti: notte.remMinutes,
          percentuale: notte.remPct,
          giudizio: notte.ratings['rem_pct'],
        ),
        _Fase(
          colore: SleepScreen._colori[2]!,
          nome: 'Leggero',
          minuti: notte.lightMinutes,
        ),
        _Fase(
          colore: SleepScreen._colori[1]!,
          nome: 'Sveglio',
          minuti: notte.awakeMinutes,
          giudizio: notte.ratings['awake_minutes'],
        ),

        if (notte.disclaimer != null) ...[
          const SizedBox(height: Gap.lg),
          Text(
            notte.disclaimer!,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: Gap.xl),
      ],
    );
  }
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

        SizedBox(
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
              onTapDown: (d) => _aggiorna(d.localPosition.dx, vincoli.maxWidth),
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
                        color: SleepScreen._colori[b.stage] ?? Colors.grey,
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
                      child: ColoredBox(color: theme.colorScheme.onSurface),
                    ),
                ],
              ),
            ),
          ),
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
    this.percentuale,
    this.giudizio,
  });

  final Color colore;
  final String nome;
  final int minuti;
  final double? percentuale;
  final String? giudizio;

  @override
  Widget build(BuildContext context) {
    final allarme = _Notte._coloreGiudizio(context, giudizio);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: colore,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      title: Text(nome),
      trailing: Text(
        [
          '${minuti ~/ 60}h ${(minuti % 60).toString().padLeft(2, '0')}',
          if (percentuale != null) '${percentuale!.toStringAsFixed(0)}%',
        ].join('  ·  '),
        style: TextStyle(fontWeight: FontWeight.w600, color: allarme),
      ),
    );
  }
}
