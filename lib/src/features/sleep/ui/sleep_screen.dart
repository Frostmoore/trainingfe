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
  static Color? _coloreGiudizio(BuildContext context, String? giudizio) => switch (giudizio) {
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
              onPressed: () => ref.read(sleepNightProvider.notifier).state = notte.night.subtract(
                const Duration(days: 1),
              ),
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Text(
                DateFormat('EEEE d MMMM', 'it').format(notte.night),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: () => ref.read(sleepNightProvider.notifier).state = notte.night.add(
                const Duration(days: 1),
              ),
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
        _Fase(colore: SleepScreen._colori[2]!, nome: 'Leggero', minuti: notte.lightMinutes),
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
class _Ipnogramma extends StatelessWidget {
  const _Ipnogramma({required this.notte});

  final SleepNight notte;

  static const _altezzaBanda = 22.0;

  /// L'ordine verticale: sveglio in alto, profondo in basso, come su ogni
  /// dispositivo che disegna il sonno.
  static const _riga = {1: 0, 4: 1, 2: 2, 3: 3};

  @override
  Widget build(BuildContext context) {
    if (notte.hypnogram.isEmpty) {
      return Text(
        'Questa notte non ha il dettaglio delle fasi.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    final totale = notte.to.difference(notte.from).inSeconds;

    if (totale <= 0) return const SizedBox.shrink();

    return SizedBox(
      height: _altezzaBanda * 4,
      child: LayoutBuilder(
        builder: (context, vincoli) => Stack(
          children: [
            for (final blocco in notte.hypnogram)
              Positioned(
                left:
                    blocco.from.difference(notte.from).inSeconds / totale * vincoli.maxWidth,
                top: (_riga[blocco.stage] ?? 2) * _altezzaBanda,
                width: (blocco.to.difference(blocco.from).inSeconds / totale * vincoli.maxWidth)
                    .clamp(1.0, vincoli.maxWidth),
                height: _altezzaBanda,
                child: ColoredBox(
                  color: SleepScreen._colori[blocco.stage] ?? Colors.grey,
                ),
              ),
          ],
        ),
      ),
    );
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
        decoration: BoxDecoration(color: colore, borderRadius: BorderRadius.circular(3)),
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
