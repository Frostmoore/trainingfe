import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../health/dati_salute.dart';
import '../../../health/media_di_riferimento.dart';
import '../../../health/recupero_controller.dart';
import '../../../profile/corpo_controller.dart';
import '../../data/dashboard_models.dart';

/// Le schede del riepilogo di oggi — D5.

/// Le calorie, lette **rispetto all'ora che è**.
///
/// 🚨 La barra ha due indicatori: quanto si è mangiato e **a che punto è la
/// giornata**. 1.200 kcal su 2.400 non vogliono dire niente da sole: a metà
/// mattina sono tantissime, alle nove di sera sono poche. È la differenza fra
/// un'app che informa e una che sembra giudicare a caso.
class CaloriesCard extends StatelessWidget {
  const CaloriesCard({required this.riepilogo, super.key});

  final DashboardSummary riepilogo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = riepilogo.nutrition;
    final scostamento = riepilogo.scostamentoRitmo;

    return Card(
      margin: EdgeInsets.zero,
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
                  n.haTarget ? '/ ${n.targetKcal!.round()} kcal' : 'kcal',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (n.burnedKcal > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 18,
                        color: theme.colorScheme.tertiary,
                      ),
                      Text('${n.burnedKcal}', style: theme.textTheme.titleSmall),
                    ],
                  ),
              ],
            ),

            if (n.haTarget) ...[
              const SizedBox(height: Gap.sm),
              _BarraConRitmo(
                percentualeMangiata: (n.kcal / n.targetKcal!).clamp(0.0, 1.5),
                percentualeGiornata: riepilogo.dayProgressPct / 100,
              ),
              const SizedBox(height: Gap.xs),
              Text(
                _frase(scostamento, n.residuo!, riepilogo.dayProgressPct),
                style: theme.textTheme.bodySmall,
              ),
            ] else ...[
              const SizedBox(height: Gap.sm),
              Text(
                'Nessun obiettivo impostato.',
                style: theme.textTheme.bodySmall,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.profileEdit),
                  child: const Text('Compila i tuoi dati'),
                ),
              ),
            ],

            const SizedBox(height: Gap.sm),
            Row(
              children: [
                _Macro(nome: 'P', valore: n.protein, target: n.targetProtein),
                _Macro(nome: 'C', valore: n.carbs, target: n.targetCarbs),
                _Macro(nome: 'G', valore: n.fat, target: n.targetFat),
              ],
            ),
          ],
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
  const _BarraConRitmo({required this.percentualeMangiata, required this.percentualeGiornata});

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
                color: sfora ? theme.colorScheme.error : theme.colorScheme.primary,
              ),
            ),
            // Il segno del ritmo: senza, la barra dice quanto si è mangiato ma
            // non se è troppo **per l'ora che è**.
            Positioned(
              left: (vincoli.maxWidth * percentualeGiornata).clamp(0.0, vincoli.maxWidth - 2),
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

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recupero',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: Gap.sm),

            if (notte != null)
              InkWell(
                onTap: () => context.push(AppRoutes.sleep),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.xs),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bedtime_outlined,
                        size: 20,
                        color: _colore(context, notte.complessivo),
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(child: Text('Sonno · ${notte.durata}')),
                      Text(
                        'profondo ${notte.profondoPct.round()}% · REM ${notte.remPct.round()}%',
                        style: theme.textTheme.bodySmall,
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ),

            for (final lettura in recupero.parametri.values) _RigaParametro(lettura: lettura),
          ],
        ),
      ),
    );
  }

  static Color? _colore(BuildContext context, Giudizio giudizio) => switch (giudizio) {
    Giudizio.bad => Theme.of(context).colorScheme.error,
    Giudizio.warn => const Color(0xFFE0B341),
    Giudizio.ok => null,
  };
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

class _RigaParametro extends StatelessWidget {
  const _RigaParametro({required this.lettura});

  final LetturaConMedia lettura;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final delta = lettura.scostamentoPct;
    final anomalo = lettura.anomalo;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Gap.xs),
      child: Row(
        children: [
          Icon(
            lettura.metrica == MetricaSalute.hrv
                ? Icons.favorite_outline_rounded
                : Icons.monitor_heart_outlined,
            size: 20,
            color: anomalo ? theme.colorScheme.error : null,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(child: Text(lettura.metrica.etichetta)),
          Text(
            '${lettura.valore.round()} ${lettura.metrica.unita}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          // 🚨 Lo scostamento accanto al valore, sempre. Il numero assoluto non
          // si può giudicare: 42 ms sono ottimi per qualcuno e pessimi per un
          // altro, e conta solo il confronto con la propria media.
          if (delta != null) ...[
            const SizedBox(width: Gap.xs),
            Text(
              '${delta > 0 ? '+' : ''}${delta.round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: anomalo ? theme.colorScheme.error : theme.colorScheme.outline,
                fontWeight: anomalo ? FontWeight.w700 : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Peso e allenamenti recenti.
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
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                0 => 'Ti sei allenato oggi. ${t.last30Days} sedute negli ultimi 30 giorni.',
                1 => 'Ultimo allenamento ieri. ${t.last30Days} negli ultimi 30 giorni.',
                final g => 'Non ti alleni da $g giorni. ${t.last30Days} negli ultimi 30.',
              },
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: Gap.sm),

            for (final s in t.recent.take(3))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  s.isOpen ? Icons.play_circle_outline_rounded : Icons.fitness_center_rounded,
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
            if (body.weightAt != null) DateFormat('d MMM', 'it').format(body.weightAt!),
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
