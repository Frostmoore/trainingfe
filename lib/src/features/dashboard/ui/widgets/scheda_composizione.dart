import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../profile/corpo_controller.dart';
import '../../composizione.dart';

/// ⚖️ Cosa dice la composizione — 3b-Y, 30/08/2026.
///
/// 📌 *«mettiamo su oggi un'altra card con le conclusioni che si possono
/// ricavare dai dati che abbiamo aggiunto oggi (ovviamente sempre con la
/// guardia che se quei dati non ci sono si chiedono, si stimano o si nasconde
/// la card»*.
///
/// ══ 🎯 LA DOMANDA CHE LA SCHEDA DEL PESO NON PUO' FARE ═══════════════════
///
/// Non «quanto peso» — quello c'è già sopra. Ma **cosa** ho perso: ⛔ due chili
/// di grasso e due chili di muscolo sulla bilancia sono lo stesso numero, e
/// sono l'opposto l'uno dell'altro.
///
/// 💡 È l'unica conclusione che la massa grassa permette e il peso da solo no.
///
/// ══ 🚨 LE TRE STRADE QUANDO IL DATO NON C'E' ════════════════════════════
///
/// | Manca | Cosa si fa |
/// |---|---|
/// | il **peso** | 🫥 la card **non c'è**: la scheda del peso sopra dice già che manca, e ripeterlo qui sarebbe rumore |
/// | la **massa grassa** | 🙋 **si chiede** — con una riga sola, che apre il foglio dove si scrive |
/// | la **storia** (meno di tre settimane) | 📸 si mostra la **fotografia di adesso**, e si dice fra quanto arriva la conclusione |
///
/// ⛔ **E non si stima mai.** Esistono formule che tirano fuori una massa grassa
/// da BMI, età e sesso: sbagliano di cinque punti, cioè **cinque chili** su un
/// corpo da cento. 🚨 Una composizione stimata avrebbe l'aria di una misura e
/// non lo sarebbe — ed è esattamente il difetto che questo progetto insegue da
/// settimane.
class SchedaComposizione extends ConsumerWidget {
  const SchedaComposizione({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storico = ref.watch(storicoCorpoProvider).valueOrNull;

    // ⏳ Mentre carica non si disegna niente: una card che compare e sparisce
    // a ogni apertura è peggio di una che arriva un istante dopo.
    if (storico == null) return const SizedBox.shrink();

    final conPeso = storico.any((m) => m.pesoKg != null);

    /*
     * 🫥 **Senza peso la card non esiste.** ⛔ Non dice «manca il peso»: lo dice
     * già la scheda sopra, e due inviti alla stessa cosa uno sotto l'altro
     * sembrano un difetto.
     */
    if (!conPeso) return const SizedBox.shrink();

    final lettura = leggiLaComposizione(storico: storico);

    // 🙋 C'è il peso ma non la massa grassa: si chiede, una riga sola.
    if (lettura == null) return const _Invito();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.donut_small_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: Gap.sm),
                Text(
                  'Com\'è fatto',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: Gap.md),

            _Barra(composizione: lettura.adesso),
            const SizedBox(height: Gap.md),

            if (lettura.verdetto != null)
              _Conclusione(lettura: lettura)
            else
              const _AncoraPresto(),
          ],
        ),
      ),
    );
  }
}

/// 🙋 «Se ce la dai, ti diciamo una cosa che il peso da solo non dice.»
///
/// ⚠️ **Una riga, non una card grande.** Chi non ha una bilancia a
/// bioimpedenza non deve trovarsi un invito grosso quanto le card che
/// contengono dati veri: sarebbe una pubblicità dentro l'app.
class _Invito extends StatelessWidget {
  const _Invito();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Row(
          children: [
            Icon(
              Icons.donut_small_rounded,
              size: 20,
              color: tema.colorScheme.outline,
            ),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(
                'Con la massa grassa posso dirti se stai perdendo grasso o '
                'muscolo. La scrivi insieme al peso, o la manda la bilancia.',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La barra grasso/magra, e i due numeri in chili.
class _Barra extends StatelessWidget {
  const _Barra({required this.composizione});

  final Composizione composizione;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final quota = (composizione.grassoPct / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Row(
            children: [
              Expanded(
                flex: (quota * 1000).round(),
                child: Container(height: 12, color: tema.colorScheme.tertiary),
              ),
              Expanded(
                flex: ((1 - quota) * 1000).round(),
                child: Container(height: 12, color: tema.colorScheme.primary),
              ),
            ],
          ),
        ),
        const SizedBox(height: Gap.sm),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Voce(
              colore: tema.colorScheme.tertiary,
              titolo: 'grasso',
              valore:
                  '${composizione.grassoKg.toStringAsFixed(1)} kg '
                  '(${composizione.grassoPct.toStringAsFixed(1)}%)',
            ),
            _Voce(
              colore: tema.colorScheme.primary,
              titolo: 'massa magra',
              valore: '${composizione.magraKg.toStringAsFixed(1)} kg',
            ),
          ],
        ),
      ],
    );
  }
}

class _Voce extends StatelessWidget {
  const _Voce({
    required this.colore,
    required this.titolo,
    required this.valore,
  });

  final Color colore;
  final String titolo;
  final String valore;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: colore, shape: BoxShape.circle),
        ),
        const SizedBox(width: Gap.sm),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titolo,
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(valore, style: tema.textTheme.titleSmall),
          ],
        ),
      ],
    );
  }
}

/// ⏳ C'è la fotografia, non ancora il confronto.
///
/// 💡 **Si dice quando arriva**, invece di tacere: «fra due settimane» è
/// un'informazione, «non c'è niente» è un muro.
class _AncoraPresto extends StatelessWidget {
  const _AncoraPresto();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Text(
      'Fra qualche settimana potrò dirti anche cosa stai perdendo: il grasso '
      'o il muscolo. Servono almeno $giorniMinimi giorni di misure.',
      style: tema.textTheme.bodySmall?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// 🎯 La conclusione.
class _Conclusione extends StatelessWidget {
  const _Conclusione({required this.lettura});

  final LetturaDellaComposizione lettura;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    final (icona, colore, testo) = switch (lettura.verdetto!) {
      Verdetto.grassoGiuMuscoloTenuto => (
        Icons.trending_down_rounded,
        tema.colorScheme.primary,
        'Stai perdendo grasso e tenendo il muscolo. È il modo giusto.',
      ),
      Verdetto.giuAncheIlMuscolo => (
        Icons.warning_amber_rounded,
        tema.colorScheme.error,
        'Stai perdendo anche massa magra. Spesso vuol dire deficit troppo '
            'largo, poche proteine o poco allenamento di forza.',
      ),
      Verdetto.suSoprattuttoMuscolo => (
        Icons.fitness_center_rounded,
        tema.colorScheme.primary,
        'Stai mettendo su peso, e in buona parte è muscolo.',
      ),
      Verdetto.suSoprattuttoGrasso => (
        Icons.warning_amber_rounded,
        tema.colorScheme.error,
        'Il peso in più è soprattutto grasso.',
      ),
      Verdetto.fermo => (
        Icons.remove_rounded,
        tema.colorScheme.outline,
        'Niente si è mosso abbastanza da poterlo dire. Non vuol dire che non '
            'stia succedendo niente: vuol dire che è ancora dentro l\'errore '
            'della bilancia.',
      ),
    };

    final dg = lettura.deltaGrassoKg!;
    final dm = lettura.deltaMagraKg!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: Gap.sm),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icona, size: 18, color: colore),
            const SizedBox(width: Gap.sm),
            Expanded(child: Text(testo, style: tema.textTheme.bodyMedium)),
          ],
        ),

        const SizedBox(height: Gap.sm),

        /*
         * 💡 **I due numeri sotto la frase**, non al posto suo: la frase dice
         * cosa vuol dire, i numeri dicono quanto. ⚠️ Da soli sarebbero due
         * scostamenti che chi legge deve interpretare, ed è il lavoro che
         * questa card esiste per fare.
         */
        Text(
          'In ${lettura.giorni} giorni: '
          'grasso ${_segno(dg)} kg · massa magra ${_segno(dm)} kg',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 💡 Il segno si scrive **sempre**, anche quando è un più: «0,4» e «+0,4»
  /// si leggono in due modi diversi, e su uno scostamento il segno è metà
  /// dell'informazione.
  String _segno(double v) {
    final s = v >= 0 ? '+' : '−';

    return '$s${v.abs().toStringAsFixed(1)}';
  }
}
