import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../forma/carica_controller.dart';
import '../../../forma/forma_controller.dart';
import '../../../forma/ui/barra_carico.dart';
import '../../../forma/ui/pezzi_della_forma.dart';
import '../../../forma/ui/tachimetro_prontezza.dart';
import '../../../health/dati_salute.dart';
import '../../../health/recupero_controller.dart';

/// 🎛️ **La plancia di Oggi** — `plan_interfaccia.md` I2, 19/11/2026.
///
/// 📌 Tavola «Oggi — la 5 con la testata della 4»: nella testata scura, a
/// sinistra la batteria della Carica, al centro il tachimetro della Prontezza,
/// a destra sonno, HRV e battito; sotto, il carico.
///
/// ══ 🚨 È LA VECCHIA `SchedaForma`, NON UN DISEGNO NUOVO ═══════════════════
///
/// Gli strumenti sono **gli stessi widget** di prima — `BatteriaCarica`,
/// `TachimetroProntezza`, `BarraCarico` — con la loro forma e, per il
/// tachimetro, la sua scala colorata (rosso, giallo, neutro, verde: 28/08).
/// ⛔ Cambia il posto, non il disegno: è la regola R1 del piano.
///
/// E le frasi che stavano nella card sono venute con loro: il perché della
/// prontezza, la fascia del carico, l'affidabilità della carica, il «stamattina
/// eri a». Le due avvertenze non stanno qui: stanno nel posto dell'avvertenza
/// della testata, **sopra** questa plancia (D-2s/B).
///
/// ══ 🔑 TOCCARLA APRE LE FORMULE ═══════════════════════════════════════════
///
/// Prima a `AppRoutes.forma` — la pagina con gli ingredienti e le formule —
/// ci si arrivava toccando la card. 🚨 Tolta la card, la strada non doveva
/// sparire con lei: è la pagina che permette di **non essere d'accordo** con un
/// indice (2-sexies), e senza un ingresso è come se non ci fosse.
///
/// ══ ⚠️ SOLO PER CHI È ABBONATO ═══════════════════════════════════════════
///
/// Chi non è abbonato **non la vede**, e non vede nemmeno un suo posto vuoto:
/// regola dell'08/09/2026, *«dall'header dei non abbonati devono sparire»* —
/// sparire, non sfumare. La sceglie `TodayHeader`.
class PlanciaDiOggi extends ConsumerWidget {
  const PlanciaDiOggi({this.apreLaForma = true, super.key});

  /// `true` su «Oggi»: toccarla apre «Carico e carica». `false` dentro quella
  /// pagina — I8, 19/11/2026 —, dove sta in testata: aprire la pagina in cui
  /// si è già sarebbe un tocco che impila la stessa schermata due volte.
  ///
  /// 💡 **La stessa plancia, non una copia**: su «Oggi» e in testata a «Carico
  /// e carica» gli strumenti devono dire la stessa cosa nello stesso modo, e
  /// due disegni divergerebbero al primo ritocco.
  final bool apreLaForma;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final forma = ref.watch(formaProvider).valueOrNull;

    // 🔋 `null` senza TDEE: *«un TDEE inventato darebbe una scarica
    // inventata»*. E allora la batteria non si disegna.
    final carica = ref.watch(caricaProvider).valueOrNull;
    final recupero = ref.watch(recuperoProvider).valueOrNull;

    /*
     * 🚨 **La stessa prontezza di prima, non l'altra** — 08/09/2026.
     *
     * ⛔ Due numeri con la stessa etichetta nella stessa schermata — 26 e 57 —
     * è il difetto che il committente ha già visto una volta. Dal 07/09 la
     * prontezza mostrata è la **reattività** quando c'è.
     */
    final reattivita = forma?.reattivita;
    final prontezza = reattivita?.valore ?? forma?.prontezza.valore;

    final sonno = recupero?.notte?.durata;
    final hrv = recupero?.parametri[MetricaSalute.hrv];
    final battito = recupero?.parametri[MetricaSalute.battitoARiposo];

    return InkWell(
      onTap: apreLaForma ? () => context.push(AppRoutes.forma) : null,
      borderRadius: BorderRadius.circular(Gap.radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (carica != null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BatteriaCarica(livello: carica.adesso, altezza: 92),
                    const SizedBox(height: Gap.xs),
                    const _Etichetta('carica'),
                  ],
                ),

              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TachimetroProntezza(valore: prontezza, lato: 168),
                    const _Etichetta('prontezza'),
                  ],
                ),
              ),

              /*
               * 💡 **Se manca, sparisce** — 3b-O.1b.1: un trattino occupa lo
               * spazio di un numero e non dice niente.
               */
              SizedBox(
                width: 72,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sonno != null)
                      _Lettura(valore: sonno, etichetta: 'sonno'),
                    if (hrv != null)
                      _Lettura(
                        valore: _numero(hrv.valore),
                        etichetta: 'hrv ms',
                      ),
                    if (battito != null)
                      _Lettura(
                        valore: _numero(battito.valore),
                        etichetta: 'bpm riposo',
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: Gap.sm),

          Text(
            fraseDellaProntezza(reattivita, prontezza),
            style: tema.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),

          if (prontezza != null &&
              forma != null &&
              !forma.prontezza.eAttendibile)
            Text(
              'stima poco attendibile: mancano '
              '${forma.prontezza.giorniCheMancano} giorni di dati',
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),

          if (forma != null) ...[
            const SizedBox(height: Gap.md),
            DecoratedBox(
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(Gap.radius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(Gap.sm + 4),
                child: SezioneCarico(forma: forma),
              ),
            ),
          ],

          if (carica != null) ...[
            const SizedBox(height: Gap.sm),
            AffidabilitaDellaCarica(carica: carica),
          ],
        ],
      ),
    );
  }

  /// 💡 Senza decimali quando non servono: «48» invece di «48.0».
  static String _numero(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

class _Etichetta extends StatelessWidget {
  const _Etichetta(this.testo);

  final String testo;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Text(
      testo,
      style: tema.textTheme.labelSmall?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Una lettura della colonna di destra: il numero grande, il nome sotto.
class _Lettura extends StatelessWidget {
  const _Lettura({required this.valore, required this.etichetta});

  final String valore;
  final String etichetta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valore,
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _Etichetta(etichetta),
        ],
      ),
    );
  }
}
