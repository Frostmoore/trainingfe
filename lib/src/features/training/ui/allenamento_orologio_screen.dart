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
import '../data/storico_unificato.dart';
import '../storico_unificato_controller.dart';
import 'widgets/carosello_dell_allenamento.dart';

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

    // 💡 I muscoli adesso li calcola `CaroselloDellAllenamento`, che è anche
    // l'unico a disegnarli: tenerne una seconda copia qui vorrebbe dire due
    // conti della stessa cosa nella stessa pagina.

    // 💡 **I numeri se ne sono andati nel carosello** — B.20.1. Erano una
    // card a sé sotto l'intestazione, e da quando il carosello ne ha una
    // dedicata dicevano la stessa cosa due volte nella stessa schermata.

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        /*
         * 📌 *«aggiungere sopra le tre cards a carosello come nella sezione
         * storico, ma limitate allo specifico allenamento»* — 3b-B.20.1.
         *
         * ⛔ Qui sotto c'era la figura del corpo dentro un riquadro suo, a metà
         * pagina. È diventata **la prima card del carosello**: la stessa cosa,
         * nello stesso posto in cui sta nello storico.
         */
        CaroselloDellAllenamento(voce: voce),
        const SizedBox(height: Gap.md),

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

  // 💡 `_distanza` e `_ritmo` se ne sono andati con i numeri che formattavano:
  // adesso vivono in `carosello_dell_allenamento.dart`, accanto a chi li usa.
}
