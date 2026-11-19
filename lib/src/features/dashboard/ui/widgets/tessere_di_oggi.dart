import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/sezioni.dart';
import '../../../forma/ui/pezzi_della_forma.dart';
import '../../../health/dati_salute.dart';
import '../../../health/health_controller.dart';
import '../../../health/media_di_riferimento.dart';
import '../../../health/recupero_controller.dart';
import '../../../health/timeline_sonno.dart';
import '../../../sleep/sleep_controller.dart';
import 'onda_metrica.dart';

/// 🧱 **Le tessere di «Andamento» su Oggi** — `plan_interfaccia.md` I2,
/// 19/11/2026.
///
/// ══ 📌 DA DOVE VENGONO ═══════════════════════════════════════════════════
///
/// Fino al 19/11 erano **una card sola**, `RecoveryCard` (3b-O.5, riscritta il
/// 21/08 su dettatura del committente): l'ipnogramma con sotto i riposini, le
/// due onde di HRV e battito, e un fuoco con le calorie attive.
///
/// Con la nuova interfaccia la card si **scompone**, e niente si perde:
///
/// | Era nella card | Adesso |
/// |---|---|
/// | ipnogramma + riposini | [TesseraSonno] — tocco → `/sonno`, come prima |
/// | onda HRV, onda battito | [TesseraOnda] ×2, affiancate in [CoppiaDelCuore] |
/// | invito a collegare Health Connect | dentro [TesseraSonno], quando non c'è niente |
/// | 🔥 calorie attive | ⛔ non qui: sono già nella `BarraDelConsumo` della card delle calorie e nel totale «bruciate». Una terza volta sarebbe un doppione |
///
/// E [TesseraEffetto] viene dalla vecchia `SchedaForma`: l'Effetto (il TEI del
/// 07/09) è una misura della settimana, e sta con le altre.

/// 🌙 Il sonno di stanotte, in una tessera.
///
/// 🏷️ **«Sonno», non «Recupero»** — decisione del 23/09/2026: *«chiamali sonno
/// tutti e due»*. Lo stesso numero si leggeva con due nomi.
class TesseraSonno extends ConsumerWidget {
  const TesseraSonno({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final recupero = ref.watch(recuperoProvider).valueOrNull;
    final notte = recupero?.notte;

    /*
     * 🚨 **Senza dati invita a collegare, e porta dove si collega** — S2,
     * 3b-P.8.3. ⛔ Non «compaiono appena il tuo orologio…»: una promessa che
     * dopo S1 nessuno poteva mantenere. Il collegamento sta in «Privacy e
     * consensi», non in `/sonno`.
     */
    if (recupero == null || !recupero.haQualcosa) {
      return Tessera(
        etichetta: 'Sonno',
        onTap: () => context.push(AppRoutes.consensi),
        child: Text(
          'Collega Health Connect per vedere qui come dormi. '
          'I dati restano sul tuo telefono.',
          style: tema.textTheme.bodySmall,
        ),
      );
    }

    final pisolini = ref.watch(pisoliniProvider).valueOrNull ?? const [];

    return Tessera(
      etichetta: 'Sonno',
      // 📌 «Va bene che se ci clicco mi manda alla pagina del sonno.»
      onTap: () => context.push(AppRoutes.sleep),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            notte?.durata ?? '—',
            style: tema.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: notte == null ? null : _colore(context, notte.complessivo),
            ),
          ),

          /*
           * 🚨 **L'ipnogramma resta** — 21/08: *«all'inizio ci deve proprio
           * essere l'ipnogramma, con sotto i riposini»*. In una tessera a metà
           * schermo resta la striscia: la forma della notte, non il grafico.
           */
          if (notte != null) ...[
            const SizedBox(height: Gap.xs),
            StrisciaSonno(fasi: notte.ipnogramma),
            const SizedBox(height: Gap.xs),
            Text(
              'profondo ${notte.profondoPct.round()}% · '
              'REM ${notte.remPct.round()}%',
              style: tema.textTheme.bodySmall,
            ),
          ],

          // 💡 I riposini **sotto** la notte e separati: né sommati né nascosti.
          if (pisolini.isNotEmpty)
            Text(
              pisolini.length == 1
                  ? 'più un riposo di ${_breve(pisolini.first.durata)}'
                  : 'più ${pisolini.length} riposi',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
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
/// ⚠️ **La larghezza è proporzionale alla DURATA**, non al numero di segmenti:
/// venti minuti di REM e due ore di profondo non possono occupare lo stesso
/// spazio, o la striscia racconta una notte che non c'è stata.
class StrisciaSonno extends StatelessWidget {
  const StrisciaSonno({required this.fasi, super.key});

  final List<SegmentoSonno> fasi;

  @override
  Widget build(BuildContext context) {
    if (fasi.isEmpty) return const SizedBox.shrink();

    final totale = fasi.fold<int>(
      0,
      (tot, s) => tot + s.a.difference(s.da).inSeconds,
    );

    if (totale <= 0) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            for (final s in fasi)
              Expanded(
                flex: s.a.difference(s.da).inSeconds.clamp(1, 1 << 30),
                child: ColoredBox(
                  color: _coloreFase(context, s.fase.codice),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ⚠️ `CampioneSonno.fase` è un **intero** — il codice di `FaseSonno`.
  static Color _coloreFase(BuildContext context, int fase) {
    final schema = Theme.of(context).colorScheme;

    return switch (FaseSonno.daCodice(fase)) {
      FaseSonno.profondo => schema.primary,
      FaseSonno.rem => schema.tertiary,
      FaseSonno.leggero => schema.primary.withValues(alpha: 0.45),
      // 💡 Lo sveglio è un **buco**, non una fase.
      _ => schema.surfaceContainerHighest,
    };
  }
}

/// Una metrica del cuore con il suo andamento a onda — 3b-O.5.3.
///
/// 📌 *«variabilità cardiaca deve essere un grafico, e idem battito a riposo
/// (non a colonne, a onda)»*.
class TesseraOnda extends StatelessWidget {
  const TesseraOnda({
    required this.lettura,
    required this.colore,
    this.valori,
    super.key,
  });

  final LetturaConMedia lettura;
  final Color colore;
  final List<double>? valori;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Tessera(
      etichetta: lettura.metrica.etichetta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_numero(lettura.valore)} ${lettura.metrica.unita}',
            style: tema.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: Gap.sm),
          OndaMetrica(valori: valori ?? const [], colore: colore),
        ],
      ),
    );
  }

  static String _numero(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// HRV e battito, affiancati — o niente, se nessuno dei due c'è.
///
/// ⚠️ **Sparisce intera**, non lascia una metà vuota: una tessera senza numero
/// occupa lo spazio di un dato senza esserlo (3b-O.1b.1). Se ce n'è uno solo,
/// sta da solo a tutta larghezza.
class CoppiaDelCuore extends ConsumerWidget {
  const CoppiaDelCuore({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final recupero = ref.watch(recuperoProvider).valueOrNull;

    final hrv = recupero?.parametri[MetricaSalute.hrv];
    final battito = recupero?.parametri[MetricaSalute.battitoARiposo];

    final tessere = [
      if (hrv != null)
        TesseraOnda(
          lettura: hrv,
          colore: tema.colorScheme.primary,
          valori: ref
              .watch(andamentoMetricaProvider(MetricaSalute.hrv))
              .valueOrNull,
        ),
      if (battito != null)
        TesseraOnda(
          lettura: battito,
          colore: tema.colorScheme.tertiary,
          valori: ref
              .watch(andamentoMetricaProvider(MetricaSalute.battitoARiposo))
              .valueOrNull,
        ),
    ];

    return switch (tessere.length) {
      0 => const SizedBox.shrink(),
      1 => tessere.first,
      _ => Coppia(sinistra: tessere[0], destra: tessere[1]),
    };
  }
}

/// 🏃 L'Effetto della settimana, in una tessera.
class TesseraEffetto extends StatelessWidget {
  const TesseraEffetto({super.key});

  @override
  Widget build(BuildContext context) =>
      const Tessera(etichetta: 'Effetto', child: SezioneEffetto());
}
