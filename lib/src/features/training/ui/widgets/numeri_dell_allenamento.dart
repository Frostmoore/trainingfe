import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/storico_unificato.dart';
import '../../statistiche_controller.dart';

/// I numeri di un allenamento: tempo, andatura, cuore — 08/09/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// Il committente: *«nella pagina di riassunto dell'esercizio ci devono essere
/// tutti i dati dell'allenamento, quindi tempo velocità media inclinazione passo
/// medio per minuto e tutte queste cose qui»*.
///
/// ══ 🚨 «TUTTI I DATI» NON VUOL DIRE «TUTTI I RIQUADRI» ════════════════════
///
/// ⛔ **Ogni voce compare solo se ha un valore**, ed è la regola che questa
/// pagina aveva già: *«un campo vuoto perché il tipo non lo prevede non si
/// mostra: "0 km" su una seduta di pesi e "— passi" su una nuotata sono due modi
/// di riempire lo schermo con niente»*.
///
/// 🚨 E l'assenza qui è **quasi sempre del tipo giusto**: una seduta di pesi non
/// ha un passo al km perché non ce l'ha, non perché l'orologio si sia
/// dimenticato. Vedi `StatisticheAllenamento`, dove la decisione è presa una
/// volta sola e per iscritto.
///
/// ✅ **E il dislivello c'è**, dall'08/09: lo legge un canale nativo nostro,
/// perché il pacchetto `health` il tipo `ElevationGainedRecord` non lo conosce.
/// ⚠️ **Non dipende dal consenso del percorso** — è un dato a sé, e su una
/// camminata vera ha dato **27 m**. Vedi `SaluteInPiu`.
class NumeriDellAllenamento extends ConsumerWidget {
  const NumeriDellAllenamento({required this.voce, super.key});

  final VoceStorico voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stat = ref
        .watch(statisticheAllenamentoProvider(voce.dalPolso))
        .valueOrNull;

    /*
     * ⛔ **Niente riquadro vuoto.** Un titolo, una cornice e niente dentro si
     * legge come un guasto — non come «di questo non sappiamo niente».
     */
    if (stat == null || !stat.qualcosaDaDire) return const SizedBox.shrink();

    final theme = Theme.of(context);

    final voci = <(IconData, String, String)>[
      (Icons.timer_outlined, 'Tempo', _durata(stat.durata)),

      if (stat.km case final km?)
        (Icons.straighten_rounded, 'Distanza', '${_conLaVirgola(km, 2)} km'),

      if (stat.velocitaKmH case final v?)
        (
          Icons.speed_rounded,
          /*
           * 🚨 **L'etichetta dice da dove viene, e non è un dettaglio.**
           *
           * ⛔ Sulla camminata dell'08/09 le due strade danno 3,79 km/h
           * (l'orologio) e 2,8 km/h (distanza ÷ durata): il 34% di scarto. La
           * differenza è la sosta al bar — 📌 *«tiene da conto il fatto che mi
           * sono fermato 10 minuti»*.
           *
           * ⚠️ Chiamarle tutte e due «velocità media» farebbe sembrare rotta
           * l'app a chi confronta con l'orologio. 💡 Dire «stimata» dice
           * **quale domanda** quel numero sta rispondendo.
           */
          stat.velocitaDallOrologio
              ? 'Velocità media'
              : 'Velocità media stimata',
          '${_conLaVirgola(v, 1)} km/h',
        ),

      if (stat.passoAlKm case final p?)
        (Icons.timeline_rounded, 'Passo', '${_minutiESecondi(p)} /km'),

      if (stat.cadenzaAlMinuto case final c?)
        (Icons.directions_walk_rounded, 'Cadenza', '${c.round()} passi/min'),

      if (stat.lunghezzaDelPasso case final l?)
        (
          Icons.height_rounded,
          'Lunghezza del passo',
          '${_conLaVirgola(l, 2)} m',
        ),

      if (stat.passi case final p?)
        (Icons.follow_the_signs_rounded, 'Passi', _conIPunti(p)),

      if (stat.battitoMedio case final b?)
        (Icons.favorite_rounded, 'Battito medio', '$b bpm'),

      if (stat.battitoMassimo case final b?)
        (Icons.favorite_border_rounded, 'Battito massimo', '$b bpm'),

      if (stat.dislivelloMetri case final d?)
        (Icons.terrain_rounded, 'Dislivello', '${d.round()} m'),

      if (stat.kcalAlMinuto case final k?)
        (
          Icons.local_fire_department_rounded,
          'Intensità',
          '${_conLaVirgola(k, 1)} kcal/min',
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('I numeri', style: theme.textTheme.titleMedium),
            const SizedBox(height: Gap.sm),

            /*
             * 💡 Una griglia a due colonne e non un elenco: dieci righe di
             * `ListTile` sarebbero uno schermo intero da scorrere per dei numeri
             * che si guardano tutti insieme, a colpo d'occhio.
             *
             * ⚠️ `Wrap` e non `GridView`: la card sta dentro una `ListView`, e
             * una griglia con altezza propria dentro uno scorrevole è la strada
             * più breve per un `RenderBox was not laid out`.
             */
            LayoutBuilder(
              builder: (context, vincoli) {
                // ⚠️ `- 1` e non `/ 2` netto: a metà esatta un pixel di
                // arrotondamento manda la seconda colonna a capo.
                final larghezza = (vincoli.maxWidth - Gap.md) / 2 - 1;

                return Wrap(
                  spacing: Gap.md,
                  runSpacing: Gap.md,
                  children: [
                    for (final (icona, etichetta, valore) in voci)
                      SizedBox(
                        width: larghezza,
                        child: _Numero(
                          icona: icona,
                          etichetta: etichetta,
                          valore: valore,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// `1h 24m`, oppure `47m` quando l'ora non c'è.
  ///
  /// ⛔ Mai `0h 47m`: uno zero davanti a un'unità che non serve fa contare due
  /// volte per capire un numero che si doveva leggere di colpo.
  @visibleForTesting
  static String durata(Duration d) => _durata(d);

  static String _durata(Duration d) {
    final ore = d.inHours;
    final minuti = d.inMinutes % 60;

    if (ore <= 0) return '${minuti}m';

    return '${ore}h ${minuti}m';
  }

  /// `5:42` — il passo si legge così e non come `5,7 min`.
  @visibleForTesting
  static String minutiESecondi(Duration d) => _minutiESecondi(d);

  static String _minutiESecondi(Duration d) {
    final minuti = d.inMinutes;
    final secondi = d.inSeconds % 60;

    return '$minuti:${secondi.toString().padLeft(2, '0')}';
  }

  /// 💡 La virgola, non il punto: `7,4 km/h`. Qui si scrive in italiano.
  static String _conLaVirgola(double n, int decimali) =>
      n.toStringAsFixed(decimali).replaceAll('.', ',');

  static String _conIPunti(int n) {
    final testo = n.toString();
    final fuori = StringBuffer();

    for (var i = 0; i < testo.length; i++) {
      if (i > 0 && (testo.length - i) % 3 == 0) fuori.write('.');

      fuori.write(testo[i]);
    }

    return fuori.toString();
  }
}

class _Numero extends StatelessWidget {
  const _Numero({
    required this.icona,
    required this.etichetta,
    required this.valore,
  });

  final IconData icona;
  final String etichetta;
  final String valore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icona, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: Gap.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                valore,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                etichetta,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
