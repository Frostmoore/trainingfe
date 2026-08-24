/// La pagina di un allenamento visto solo dall'orologio — 3b-A.9, 24/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«Gli allenamenti con l'orologio e basta devono comunque avere una pagina
/// loro, ovviamente con le informazioni che si possono prendere e le cose che
/// hanno rilevanza (tipo se è una corsa, i km, se è allenamento di pesi le
/// calorie bruciate eccetera)»*.
///
/// ── ⛔ Prima toccarli non faceva niente, ed era scritto ───────────────────
///
/// 🚨 `_CardAllenamento._apri()` faceva `if (seduta == null) return;`, e
/// `QuadratoAllenamento` lo spiegava: *«una pagina di dettaglio esiste per le
/// sedute registrate nell'app»*. ⚠️ Era una scelta, non una dimenticanza — e
/// va **rovesciata**, insieme al commento che la difendeva.
///
/// ⛔ **Una card che si tocca e non fa niente è peggio di una che non si tocca**:
/// chi prova due volte pensa che l'app si sia bloccata.
///
/// ── 🚨 «Le cose che hanno rilevanza» è la parte difficile ─────────────────
///
/// Un campo vuoto perché il tipo non lo prevede **non si mostra**: «0 km» su
/// una seduta di pesi e «— passi» su una nuotata sono due modi di riempire lo
/// schermo con niente. 💡 Qui ogni riga compare solo se ha un valore, e la
/// figura del corpo dice cosa hai mosso anche quando i numeri sono pochi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/states.dart';
import '../../health/tipo_allenamento.dart';
import '../data/catalogo_esercizi.dart';
import '../data/storico_unificato.dart';
import '../muscoli_allenati.dart';
import '../storico_unificato_controller.dart';
import 'widgets/figura_del_corpo.dart';

class AllenamentoOrologioScreen extends ConsumerWidget {
  const AllenamentoOrologioScreen({required this.id, super.key});

  /// L'id della riga nell'archivio locale.
  ///
  /// ⚠️ **Non è l'id di una seduta**: quelle hanno già `/allenamento/:id`. Qui
  /// si parla di una riga letta dall'orologio, che vive solo sul telefono.
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voci = ref.watch(storicoUnificatoProvider);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Allenamento'),
      body: voci.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(storicoUnificatoProvider),
        ),
        data: (lista) {
          /*
           * 🚨 Si cerca **il gruppo** che contiene questo allenamento, non
           * l'allenamento da solo: se l'orologio ha spezzato la corsa in tre
           * tratti, la pagina deve parlare della corsa — non di un terzo.
           */
          final voce = lista
              .where((v) => v.dalPolso.any((a) => a.id == id))
              .firstOrNull;

          if (voce == null) {
            return const EmptyState(
              icon: Icons.watch_off_outlined,
              title: 'Non lo trovo più',
              message:
                  'Questo allenamento non è più nell\'archivio del telefono.',
            );
          }

          return _Dettaglio(voce: voce);
        },
      ),
    );
  }
}

class _Dettaglio extends ConsumerWidget {
  const _Dettaglio({required this.voce});

  final VoceStorico voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final tipo = TipoAllenamento.da(voce.dalPolso.first.tipo);

    final catalogo =
        ref.watch(catalogoEserciziProvider).valueOrNull ??
        CatalogoEsercizi.vuoto;

    /*
     * ⚠️ **Anche qui i muscoli passano dalla scheda associata** — B.9. ⛔ Senza
     * questa riga la pagina di un allenamento del polso sarebbe l'unico posto in
     * cui la scheda associata non colora niente: la stessa domanda, due risposte
     * diverse a seconda di dove la guardi.
     */
    final intensita = intensitaDeiMuscoli(
      voci: [voce],
      catalogo: catalogo,
      pesiDelleSchede:
          ref.watch(muscoliDelleSchedeProvider).valueOrNull ?? const {},
    );

    var passi = 0;
    for (final a in voce.dalPolso) {
      passi += a.passi ?? 0;
    }

    final kcal = voce.kcalDalPolso ?? voce.kcalDalleSedute;
    final metri = voce.distanzaMetri;
    final minuti = voce.durata.inMinutes;

    /*
     * ══ 🚨 «LE COSE CHE HANNO RILEVANZA» ═══════════════════════════════════
     *
     * ⛔ Ogni riga compare **solo se c'è**. Un «0 km» su una seduta di pesi o
     * un «— passi» su una nuotata non sono informazioni: sono spazio riempito,
     * e insegnano a non leggere il riquadro.
     *
     * 💡 Il ritmo si calcola solo quando ha senso — cioè quando ci sono dei
     * metri: «5:30 /km» su un allenamento di pesi sarebbe una divisione per
     * zero travestita da dato.
     */
    final numeri = <(IconData, String, String)>[
      (Icons.timer_outlined, '$minuti', 'minuti'),
      if (metri != null && metri > 0)
        (Icons.route_outlined, _distanza(metri), 'percorsi'),
      if (metri != null && metri >= 1000 && minuti > 0)
        (Icons.speed_outlined, _ritmo(metri, minuti), 'al chilometro'),
      if (kcal != null && kcal > 0)
        (Icons.local_fire_department_outlined, '$kcal', 'kcal bruciate'),
      if (passi > 0) (Icons.directions_walk_rounded, '$passi', 'passi'),
    ];

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Row(
          children: [
            Icon(tipo.icona, size: 32, color: tema.colorScheme.primary),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tipo.nome, style: tema.textTheme.titleLarge),
                  Text(
                    DateFormat('EEEE d MMMM, HH:mm', 'it').format(voce.quando),
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: Gap.md),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Column(
              children: [
                for (final (icona, valore, etichetta) in numeri)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(icona, size: 20, color: tema.colorScheme.primary),
                        const SizedBox(width: Gap.sm),
                        Text(
                          valore,
                          style: tema.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            etichetta,
                            style: tema.textTheme.bodyMedium?.copyWith(
                              color: tema.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        /*
         * 🧍 **La figura, riusata** — è il motivo per cui A.6.1 chiedeva un
         * servizio: *«dovrà andare anche in ogni pagina dell'allenamento
         * specifico»*.
         *
         * ⛔ Non si mostra se non c'è niente da colorare: uno sport che la
         * tabella non conosce darebbe una figura tutta grigia, cioè un riquadro
         * che dice «non hai allenato niente» a chi si è appena allenato.
         */
        if (intensita.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cosa hai mosso',
                    style: tema.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: Gap.sm),
                  SizedBox(
                    height: 200,
                    child: FiguraDelCorpo(intensita: intensita),
                  ),
                ],
              ),
            ),
          ),
        ],

        const SizedBox(height: Gap.md),

        /*
         * ⚠️ **Da dove viene, e quanti tratti.** Un'ora di corsa spezzata in
         * tre dall'orologio dà una durata di gruppo che non torna con la somma:
         * dirlo qui è l'unico posto in cui la differenza si può spiegare.
         */
        Text(
          voce.dalPolso.length == 1
              ? 'Registrato dall\'orologio.'
              : 'Registrato dall\'orologio in ${voce.dalPolso.length} tratti.',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// 💡 Sotto il chilometro si scrivono i metri, come ovunque nell'app.
  static String _distanza(int metri) => metri < 1000
      ? '$metri m'
      : '${(metri / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  /// Minuti e secondi per chilometro.
  static String _ritmo(int metri, int minuti) {
    final secondiPerKm = (minuti * 60) / (metri / 1000);
    final m = secondiPerKm ~/ 60;
    final s = (secondiPerKm % 60).round();

    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
