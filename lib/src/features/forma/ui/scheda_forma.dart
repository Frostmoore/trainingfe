import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../forma_controller.dart';
import '../indici_di_forma.dart';

/// La scheda di stanchezza e carica — FASE 2-sexies.
///
/// ── 🚨 L'avvertenza sta SOPRA i numeri ────────────────────────────────────
///
/// Decisione D-2s/B del committente, e la posizione non è un dettaglio: sotto la
/// leggerebbe chi ha già letto i numeri, cioè **troppo tardi**. ⚠️ È la stessa
/// regola già imparata sul consiglio del giorno (§49.4) — chi si è appena
/// allenato deve sapere **mentre** legge che quella è una stima.
class SchedaForma extends ConsumerWidget {
  const SchedaForma({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forma = ref.watch(formaProvider).valueOrNull;

    /*
     * ⚠️ Mentre carica **non si mostra niente**, e non è come il consiglio del
     * giorno: là la card che spariva era un difetto perché il testo c'era già e
     * si poteva ricordare. Qui non c'è niente da ricordare — il calcolo dura
     * un istante, e una scheda che lampeggia sarebbe peggio di una che compare.
     */
    if (forma == null) return const SizedBox.shrink();

    final tema = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,

      /*
       * 🚨 **Si tocca, e si vede che si tocca.**
       *
       * ⚠️ `InkWell` dentro la `Card` e non un `GestureDetector`: senza
       * l'ondina al tocco, una card che apre una pagina è indistinguibile da una
       * che non fa niente, e nessuno la prova due volte.
       */
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.forma),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.battery_charging_full_rounded,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'Carico e carica',
                      style: tema.textTheme.titleMedium,
                    ),
                  ),

                  // 💡 La freccia dice «qui sotto c'è altro»: l'avvertenza
                  // sopra i numeri promette una spiegazione, e questa è la porta.
                  Icon(
                    Icons.chevron_right_rounded,
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),

              const SizedBox(height: Gap.sm),
              const AvvertenzaStima(),
              const SizedBox(height: Gap.md),

              Row(
                children: [
                  Expanded(
                    child: _Numero(
                      etichetta: 'Carico',
                      indice: forma.stanchezza,
                      // 💡 L'ACWR è un rapporto: «142%» vuol dire «il 142% del tuo
                      // carico abituale», che è letteralmente quello che è. ⚠️ Non
                      // si inventa una scala: quella della carica sì, e infatti è
                      // dichiarata.
                      formato: (v) => '${(v * 100).round()}%',
                      sotto: _fascia(forma.fascia),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: _Numero(
                      etichetta: 'Carica',
                      indice: forma.carica,
                      formato: (v) => v.round().toString(),
                      sotto: 'su 100',
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

  static String _fascia(FasciaCarico? f) => switch (f) {
    FasciaCarico.scarico => 'sotto il tuo solito',
    FasciaCarico.normale => 'nella tua norma',
    FasciaCarico.inSalita => 'in salita',
    FasciaCarico.alto => 'molto sopra il solito',
    null => '',
  };
}

/// Un numero, con **quanto vale** scritto sotto.
class _Numero extends StatelessWidget {
  const _Numero({
    required this.etichetta,
    required this.indice,
    required this.formato,
    required this.sotto,
  });

  final String etichetta;
  final Indice indice;
  final String Function(double) formato;
  final String sotto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final valore = indice.valore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etichetta, style: tema.textTheme.labelMedium),
        const SizedBox(height: 2),

        /*
         * ══ 🚨 IL NUMERO C'È SEMPRE CHE SI POSSA CALCOLARE ══
         *
         * Decisione D-2s/A: *«certo che si calcola. Si stima, e sotto c'è
         * scritto che è una stima poco veritiera perché mancano x giorni»*.
         *
         * ⚠️ L'unica eccezione è quando il numero **non può esistere** — per il
         * carico, zero allenamenti in ventotto giorni: è una divisione per zero,
         * non una stima imprecisa.
         */
        if (valore == null)
          Text(
            '—',
            style: tema.textTheme.headlineMedium?.copyWith(
              color: tema.colorScheme.outline,
            ),
          )
        else
          Text(
            formato(valore),
            style: tema.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: tema.colorScheme.primary,
            ),
          ),

        Text(
          valore == null ? 'non calcolabile' : sotto,
          style: tema.textTheme.bodySmall,
        ),

        /*
         * 💡 La nota dice **quanti giorni mancano**, non «dati insufficienti»:
         * la prima è un'attesa che finisce, la seconda sembra un guasto.
         */
        if (valore != null && !indice.eAttendibile)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'stima poco attendibile: mancano '
              '${indice.giorniCheMancano} giorni di dati',
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        if (valore == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Serve almeno un allenamento registrato.',
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}

/// L'avvertenza di questi due numeri — D-2s/B.
///
/// ── ⚠️ Perché NON si riusa `AvvertenzaNutrizionale` ───────────────────────
///
/// Perché quel testo parla di **calorie** e di formule nutrizionali: infilarlo
/// sotto un indice di stanchezza direbbe la cosa sbagliata con le parole di
/// un'altra. 💡 Stesso mestiere, testo suo.
///
/// 🚨 E dice **due** cose, non una: che è una stima da formule, e che **non è
/// confrontabile con quella di un'altra persona**. La seconda è specifica di
/// questi numeri, e senza di essa l'indice diventa una gara.
class AvvertenzaStima extends StatelessWidget {
  const AvvertenzaStima({super.key});

  static const testo =
      'Stima calcolata dal telefono su sonno, battito, allenamenti e cibo. '
      'Non è una misura e non è un parere medico. '
      'È costruita sulle tue medie: non si confronta con quella di altri.';

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final colore = tema.colorScheme.onSurfaceVariant;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 14, color: colore),
        const SizedBox(width: Gap.xs),
        Expanded(
          child: Text(
            testo,
            style: tema.textTheme.labelSmall?.copyWith(
              color: colore,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
