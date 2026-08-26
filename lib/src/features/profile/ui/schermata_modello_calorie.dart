import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../data/calcolatore_calorie.dart';
import '../data/modello_calorie.dart';
import '../livello_attivita.dart';
import '../target_locale_controller.dart';
import '../tdee_misurato_controller.dart';

/// La scelta del modello di calcolo, e poi del livello — 3b-G.1, 26/08/2026.
///
/// ══ 📌 COM'E' STATA CHIESTA ═══════════════════════════════════════════════
///
/// *«Livello di attività deve diventare un bottone che rimanda a una pagina con
/// le descrizioni di entrambi i modelli di misura, quando ne seleziono uno (che
/// dovrà essere accuratamente dettagliato anche con la formula usata) potrò
/// scegliere il livello di attività»*.
///
/// ══ 🚨 PERCHE' DUE PASSI E NON UNA TENDINA ════════════════════════════════
///
/// ⛔ Prima era una tendina sola con nove voci possibili, e non c'era modo di
/// capire che le prime cinque e le ultime quattro **rispondono a due domande
/// diverse**. 💡 Il modello si sceglie una volta e cambia cosa vogliono dire
/// tutti i numeri della pagina «Oggi»: merita una pagina, non una riga.
///
/// ⚠️ **E il livello compare solo dopo il modello**, di proposito: un gradino
/// scelto senza sapere in quale delle due tabelle si trova è un gradino scelto
/// a caso.
class SchermataModelloCalorie extends ConsumerStatefulWidget {
  const SchermataModelloCalorie({super.key});

  @override
  ConsumerState<SchermataModelloCalorie> createState() =>
      _SchermataModelloCalorieState();
}

class _SchermataModelloCalorieState
    extends ConsumerState<SchermataModelloCalorie> {
  ModelloCalorie? _modello;
  String? _livello;
  bool _inizializzato = false;

  /// Riempie la scelta con quello che c'è già, la prima volta sola.
  ///
  /// ⚠️ Non in `initState`: il livello in uso dipende dal profilo, che al primo
  /// fotogramma può essere ancora in arrivo. 🚨 E **una volta sola**, o ogni
  /// ricostruzione riporterebbe la selezione indietro mentre la persona sta
  /// scegliendo.
  void _preselezione(String? livelloInUso) {
    if (_inizializzato) return;

    final modello = modelloDelLivello(livelloInUso);
    if (modello == null) return;

    _inizializzato = true;
    _modello = modello;
    _livello = livelloInUso;
  }

  Future<void> _salva() async {
    final livello = _livello;
    if (livello == null) return;

    await ref
        .read(livelloAttivitaSceltoProvider.notifier)
        .scegliLivello(livello);

    if (!mounted) return;

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final inUso = ref.watch(livelloAttivitaProvider);

    _preselezione(inUso);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Come contiamo le calorie'),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          Text(
            'Ci sono due modi di stimare quanto consumi in un giorno. '
            'Cambiano cosa vuol dire il tuo obiettivo, quindi vale la pena '
            'leggerli tutti e due.',
            style: tema.textTheme.bodyMedium,
          ),
          const SizedBox(height: Gap.md),
          const _LaMisura(),
          const SizedBox(height: Gap.lg),

          for (final m in ModelloCalorie.values) ...[
            _CartaModello(
              modello: m,
              scelto: _modello == m,
              onScelto: () => setState(() {
                _modello = m;

                // ⛔ Il livello di prima non sopravvive al cambio di modello:
                // apparterrebbe all'altra tabella, e resterebbe selezionato
                // qualcosa che nell'elenco sotto non c'è più.
                _livello = m.livello(_livello)?.chiave;
              }),
            ),
            const SizedBox(height: Gap.md),
          ],

          if (_modello case final modello?) ...[
            const SizedBox(height: Gap.sm),
            const Divider(),
            const SizedBox(height: Gap.md),

            Text('Quanto ti muovi', style: tema.textTheme.titleMedium),
            const SizedBox(height: Gap.xs),
            Text(
              modello == ModelloCalorie.misurata
                  ? 'Senza contare palestra e corsa: quelle le misuriamo a '
                        'parte.'
                  : 'Allenamenti compresi: è quello che il fattore già '
                        'contiene.',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.md),

            if (modello == ModelloCalorie.misurata) const _Suggerimento(),

            for (final l in modello.livelli)
              _RigaLivello(
                livello: l,
                scelto: _livello == l.chiave,
                onScelto: () => setState(() => _livello = l.chiave),
              ),

            const SizedBox(height: Gap.md),
            if (_livello case final livello?) _Anteprima(livello: livello),
            const SizedBox(height: Gap.lg),

            FilledButton(
              onPressed: _livello == null ? null : _salva,
              child: const Text('Salva'),
            ),
            const SizedBox(height: Gap.xl),
          ],
        ],
      ),
    );
  }
}

/// Un modello, spiegato per intero.
class _CartaModello extends StatelessWidget {
  const _CartaModello({
    required this.modello,
    required this.scelto,
    required this.onScelto,
  });

  final ModelloCalorie modello;
  final bool scelto;
  final VoidCallback onScelto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      color: scelto ? tema.colorScheme.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(Gap.radius),
        onTap: onScelto,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    scelto
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      modello.titolo,
                      style: tema.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),

              Text('«${modello.promessa}»', style: tema.textTheme.bodyMedium),
              const SizedBox(height: Gap.md),

              // 📌 La formula per esteso: chiesta esplicitamente, e comunque
              // è l'unica cosa che rende verificabile quello che l'app fa.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(Gap.sm),
                decoration: BoxDecoration(
                  color: tema.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Gap.radiusSm),
                ),
                child: Text(
                  modello.formula,
                  style: tema.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),

              Text(modello.comeFunziona, style: tema.textTheme.bodySmall),
              const SizedBox(height: Gap.sm),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.center_focus_strong_outlined,
                    size: 16,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(
                      modello.precisione,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Il gradino suggerito dai passi misurati — 3b-G.1.4.
class _Suggerimento extends ConsumerWidget {
  const _Suggerimento();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final passi = ref.watch(passiAlGiornoProvider).valueOrNull;

    // ⛔ Niente dati, niente suggerimento — e nessun riquadro vuoto che
    // faccia sembrare rotta la pagina.
    if (passi == null) return const SizedBox.shrink();

    final suggerito = livelloSuggeritoDaiPassi(passi);
    if (suggerito == null) return const SizedBox.shrink();

    final numero = NumberFormat.decimalPattern('it').format(passi);

    return Container(
      margin: const EdgeInsets.only(bottom: Gap.md),
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        color: tema.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Gap.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.directions_walk_rounded,
            size: 18,
            color: tema.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              'Nell\'ultimo mese hai fatto $numero passi al giorno: di solito '
              'corrisponde a «${suggerito.etichetta}».',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Un gradino da scegliere.
class _RigaLivello extends StatelessWidget {
  const _RigaLivello({
    required this.livello,
    required this.scelto,
    required this.onScelto,
  });

  final LivelloAttivita livello;
  final bool scelto;
  final VoidCallback onScelto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      color: scelto ? tema.colorScheme.primaryContainer : null,
      child: ListTile(
        onTap: onScelto,
        leading: Icon(
          scelto ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: tema.colorScheme.primary,
        ),
        title: Text(livello.etichetta),
        subtitle: Text(livello.dettaglio, style: tema.textTheme.bodySmall),
        trailing: Text(
          '×${livello.fattore.toStringAsFixed(2).replaceAll('.', ',')}',
          style: tema.textTheme.labelLarge?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Il conto vero, con il numero di chi sta guardando.
///
/// 🚨 **È la parte che convince.** *«BMR × fattore»* è una formula; *«1.880 ×
/// 1,25 = 2.350»* è il proprio fabbisogno, e si può controllare. ⚠️ Senza il
/// basale — perché manca il peso o l'altezza — resta la formula simbolica: si
/// dice quello che si sa, non si inventa il resto.
class _Anteprima extends ConsumerWidget {
  const _Anteprima({required this.livello});

  final String livello;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final bmr = ref.watch(metabolismoBasaleProvider).valueOrNull;
    final fattore = CalcolatoreCalorie.fattoreDi(livello);

    if (bmr == null || fattore == null) return const SizedBox.shrink();

    final numeri = NumberFormat.decimalPattern('it');
    final tdee = (bmr * fattore).round();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Gap.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Con questa scelta', style: tema.textTheme.labelLarge),
          const SizedBox(height: Gap.xs),
          Text(
            '${numeri.format(bmr.round())} × '
            '${fattore.toStringAsFixed(2).replaceAll('.', ',')} = '
            '${numeri.format(tdee)} kcal al giorno',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            modelloDelLivello(livello) == ModelloCalorie.misurata
                ? 'Più quello che bruci allenandoti, il giorno che lo fai. '
                      'L\'obiettivo si calcola da qui.'
                : 'Allenamenti compresi. L\'obiettivo si calcola da qui.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Il dispendio **misurato** sui dati veri — 3b-G.8.
///
/// ══ 🚨 SI PROPONE, NON SI SOSTITUISCE ═════════════════════════════════════
///
/// ⛔ L'app non passa da sola dalla stima alla misura, per quanto la misura sia
/// migliore: un obiettivo che cambia da solo non lo si può più controllare.
///
/// ⚠️ **E il ± si mostra sempre.** Un numero nudo si legge come esatto, e questo
/// esatto non è — dirlo senza incertezza sarebbe la stessa bugia della tabella,
/// con l'aggravante di sembrare una misura.
class _LaMisura extends ConsumerWidget {
  const _LaMisura();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final numeri = NumberFormat.decimalPattern('it');
    final accettato = ref.watch(tdeeAccettatoProvider);
    final misura = ref.watch(tdeeMisuratoProvider).valueOrNull;

    // ⛔ Finché non si sa niente non si dice niente: un riquadro «sto
    // calcolando» in cima a una pagina di scelte è solo rumore.
    if (accettato == null && (misura == null || !misura.riuscita)) {
      if (misura == null) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(Gap.md),
        decoration: BoxDecoration(
          color: tema.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Gap.radiusSm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Misurare invece di stimare',
              style: tema.textTheme.labelLarge,
            ),
            const SizedBox(height: Gap.xs),
            Text(
              'Con quattro settimane di diario e qualche pesata, questa app '
              'può '
              'calcolare quanto consumi davvero invece di stimarlo. '
              'Adesso non ancora: ${misura.motivo}.',
              style: tema.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    final kcal = accettato ?? misura!.kcal;

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tema.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(Gap.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            accettato != null
                ? 'Stai usando la misura'
                : 'I tuoi dati dicono un altro numero',
            style: tema.textTheme.labelLarge?.copyWith(
              color: tema.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text(
            misura != null && misura.riuscita
                ? '${numeri.format(kcal.round())} ± '
                      '${numeri.format(misura.incertezza.round())} kcal al '
                      'giorno, su ${misura.giorni} giorni con '
                      '${misura.giorniConDiario} di diario'
                : '${numeri.format(kcal.round())} kcal al giorno',
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: tema.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: Gap.xs),

          /*
           * ⚠️ **L'avvertenza sull'acqua non è facoltativa** — 3b-G.8.4. Le
           * prime settimane di deficit perdono glicogeno e acqua, non solo
           * grasso: il conto sopravvaluta il dispendio, e chi lo prende per
           * buono si dà un obiettivo troppo alto proprio all'inizio.
           */
          Text(
            'Stima da 7.700 kcal per chilo: le prime settimane di dieta '
            'sbaglia per eccesso.',
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: Gap.sm),

          if (accettato == null)
            FilledButton(
              onPressed: () =>
                  ref.read(tdeeAccettatoProvider.notifier).accetta(kcal),
              child: const Text('Usa la misura'),
            )
          else
            TextButton(
              onPressed: () =>
                  ref.read(tdeeAccettatoProvider.notifier).dimentica(),
              child: const Text('Torna alla stima'),
            ),
        ],
      ),
    );
  }
}
