import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../../progress/progress_controller.dart';
import '../data/session_models.dart';
import '../session_controller.dart';

/// Il riepilogo di fine allenamento — G7.
///
/// 🚨 **Il momento in cui si guarda cosa si è fatto è appena finito, non dopo.**
/// Prima l'app chiudeva la sessione e riportava all'elenco: l'allenamento
/// spariva in uno storico e nessuno lo riapriva. Qui invece si vede subito il
/// lavoro fatto, si può aggiungere la foto e correggere le calorie — le tre
/// cose che dopo cinque minuti non fa più nessuno.
///
/// ⚠️ Ci si arriva **dopo** `finish()`, quindi la stima delle calorie c'è già.
/// La schermata la mostra e permette di sostituirla, non di anticiparla.
class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({required this.sessionId, super.key});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessione = ref.watch(sessionProvider(sessionId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Allenamento concluso'),
        // ⚠️ Niente freccia indietro: si viene qui **dopo** aver chiuso la
        // sessione, e tornare al player vorrebbe dire riaprire una schermata
        // che non ha più senso. Si esce con «Fine».
        automaticallyImplyLeading: false,
      ),
      body: sessione.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(sessionProvider(sessionId)),
        ),
        data: (s) => _Corpo(sessione: s),
      ),
    );
  }
}

class _Corpo extends ConsumerWidget {
  const _Corpo({required this.sessione});

  final WorkoutSession sessione;

  /// Le serie raggruppate per esercizio, nell'ordine in cui sono state fatte.
  ///
  /// ⚠️ `Map` di Dart conserva l'ordine di inserimento: è quello che rende il
  /// riepilogo leggibile come il racconto della seduta invece che come un
  /// elenco alfabetico.
  Map<String, List<LoggedSet>> get _perEsercizio {
    final out = <String, List<LoggedSet>>{};

    for (final s in sessione.sets) {
      out.putIfAbsent(s.exerciseName, () => []).add(s);
    }

    return out;
  }

  /// Il volume totale: serie × ripetizioni × peso.
  ///
  /// È il numero che dice se la seduta è stata più dura della precedente, molto
  /// più del tempo passato in palestra.
  double get _volume {
    var totale = 0.0;

    for (final s in sessione.sets) {
      totale += (s.reps ?? 0) * (s.weight ?? 0);
    }

    return totale;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gruppi = _perEsercizio;

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Text(sessione.titolo, style: theme.textTheme.headlineSmall),
        Text(
          DateFormat('EEEE d MMMM, HH:mm', 'it').format(sessione.startedAt),
          style: theme.textTheme.bodySmall,
        ),

        const SizedBox(height: Gap.lg),

        Row(
          children: [
            _Numero(
              valore: sessione.durationMinutes == null
                  ? '—'
                  : '${sessione.durationMinutes}',
              etichetta: 'minuti',
            ),
            _Numero(valore: '${gruppi.length}', etichetta: 'esercizi'),
            _Numero(valore: '${sessione.sets.length}', etichetta: 'serie'),
            _Numero(
              valore: _volume == 0 ? '—' : NumberFormat.compact(locale: 'it').format(_volume),
              etichetta: 'kg totali',
            ),
          ],
        ),

        const SizedBox(height: Gap.lg),
        _Calorie(sessione: sessione),

        const SizedBox(height: Gap.lg),
        _Foto(sessione: sessione),

        const SizedBox(height: Gap.lg),
        Text('Cosa hai fatto', style: theme.textTheme.titleMedium),
        const SizedBox(height: Gap.sm),

        if (gruppi.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Text(
                'Non hai registrato nessuna serie. La prossima volta tocca «OK» '
                'accanto a ogni serie mentre la fai: è quello che finisce nello '
                'storico e nei grafici.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),

        for (final voce in gruppi.entries)
          Card(
            margin: const EdgeInsets.only(bottom: Gap.sm),
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voce.key,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: Gap.xs),
                  Text(
                    voce.value
                        .map((s) => '${s.reps ?? '—'}${s.weight == null ? '' : ' × ${_kg(s.weight!)} kg'}')
                        .join('   ·   '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: Gap.lg),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Fine'),
        ),
        const SizedBox(height: Gap.lg),
      ],
    );
  }

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Le calorie: la stima, e come sostituirla.
class _Calorie extends ConsumerStatefulWidget {
  const _Calorie({required this.sessione});

  final WorkoutSession sessione;

  @override
  ConsumerState<_Calorie> createState() => _CalorieState();
}

class _CalorieState extends ConsumerState<_Calorie> {
  late final _campo = TextEditingController(
    text: widget.sessione.kcal?.toString() ?? '',
  );

  bool _inCorso = false;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _salva(int? kcal) async {
    setState(() => _inCorso = true);

    try {
      await ref.read(sessionActionsProvider).setKcal(widget.sessione.id, kcal);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.unwrapError(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.sessione;
    final aMano = s.kcalSource == 'manual';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_fire_department_rounded, color: theme.colorScheme.tertiary),
                const SizedBox(width: Gap.sm),
                Text('Calorie bruciate', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: Gap.sm),

            Text(
              // 🚨 Si dice **da dove viene** il numero. Senza, non si sa se sia
              // una misura o un'ipotesi — e non si sa se valga la pena
              // correggerlo.
              aMano
                  ? 'Valore inserito da te.'
                  : 'Stima calcolata dagli esercizi, dalla durata e dal tuo peso.',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _campo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Calorie',
                      suffixText: 'kcal',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                FilledButton(
                  onPressed: _inCorso
                      ? null
                      : () => _salva(int.tryParse(_campo.text.trim())),
                  child: const Text('Salva'),
                ),
              ],
            ),

            // ⚠️ Rimettere la stima è una funzione a sé, e serve: chi corregge
            // e poi si accorge di aver scritto una sciocchezza, senza questo
            // non ha nessun modo di tornare indietro se non indovinare il
            // numero di prima.
            if (aMano)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _inCorso ? null : () => _salva(null),
                  child: const Text('Rimetti la stima automatica'),
                ),
              ),

            /*
             * ⏸️ **Dall'orologio: non ancora.**
             *
             * Il ponte con il telefono manda solo il sonno; le calorie di un
             * allenamento non arrivano da nessuna parte. Dirlo qui e' meglio
             * che mettere un pulsante che non fa niente — e meglio che tacere,
             * perche' chi ha un orologio si aspetta che il numero arrivi da
             * solo e altrimenti pensa che l'app sia rotta.
             */
            const SizedBox(height: Gap.xs),
            Text(
              'Dall\'orologio non arrivano ancora: quando collegheremo Health '
              'Connect, il valore misurato prenderà il posto della stima.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La foto della sessione: caricarla, e **vederla qui**.
class _Foto extends ConsumerStatefulWidget {
  const _Foto({required this.sessione});

  final WorkoutSession sessione;

  @override
  ConsumerState<_Foto> createState() => _FotoState();
}

class _FotoState extends ConsumerState<_Foto> {
  bool _inCorso = false;

  Future<void> _carica({required bool daFotocamera}) async {
    setState(() => _inCorso = true);

    try {
      await ref
          .read(progressActionsProvider)
          .upload(daFotocamera: daFotocamera, workoutSessionId: widget.sessione.id);

      // 🚨 Si ricarica la sessione, non solo la galleria: la foto va mostrata
      // **qui**, e senza questo resterebbe una schermata che dice «caricata»
      // senza far vedere niente.
      ref.invalidate(sessionProvider(widget.sessione.id));
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.unwrapError(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foto = widget.sessione.photos;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera_outlined, color: theme.colorScheme.primary),
                const SizedBox(width: Gap.sm),
                Text('Foto', style: theme.textTheme.titleMedium),
              ],
            ),

            if (foto.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              SizedBox(
                height: 160,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: foto.length,
                  separatorBuilder: (context, i) => const SizedBox(width: Gap.sm),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(Gap.radiusSm),
                    child: CachedNetworkImage(
                      imageUrl: foto[i].url,
                      width: 130,
                      fit: BoxFit.cover,
                      // ⚠️ Il token serve anche qui: le foto sono dati
                      // personali e l'endpoint controlla di chi sono.
                      httpHeaders:
                          ref.watch(progressAuthHeaderProvider).valueOrNull ?? const {},
                      errorWidget: (context, _, _) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: Gap.sm),
            if (_inCorso)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Gap.sm),
                child: LinearProgressIndicator(),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _carica(daFotocamera: true),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Scatta'),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _carica(daFotocamera: false),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galleria'),
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

class _Numero extends StatelessWidget {
  const _Numero({required this.valore, required this.etichetta});

  final String valore;
  final String etichetta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            valore,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
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
    );
  }
}
