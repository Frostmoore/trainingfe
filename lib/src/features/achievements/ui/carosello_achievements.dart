/// Il carosello delle medaglie — 3b-A.8.1, 24/08/2026.
///
/// 📌 Il committente: *«un carosello di cards per gli "achievements" [...] con a
/// sinistra l'icona dell'achievement poi titolo achievement e descrizione»* ·
/// *«Ci deve essere una sezione achievements uguale anche in "Oggi" e in
/// "Diario" quindi tanto vale che le fai subito»*.
///
/// ══ 🚨 UN WIDGET SOLO PER TRE SCHERMATE ═══════════════════════════════════
///
/// ⛔ *«una sezione uguale»* è la specifica, e tre copie di un carosello non
/// restano uguali: alla prima modifica una delle tre resta indietro, e nessuno
/// se ne accorge perché stanno in pagine diverse. 💡 Qui cambia solo l'**ambito**
/// che si passa.
///
/// ── ⛔ Sparisce quando è vuoto — A.8.5 ────────────────────────────────────
///
/// 🚨 **Niente scheletro, niente «presto disponibile», niente medaglie
/// spente.** Una sezione vuota che promette premi è peggio di nessuna sezione:
/// occupa spazio in tre schermate, non dice niente, e insegna a scorrere oltre
/// — anche il giorno che avrà qualcosa da dire.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../achievement.dart';

class CaroselloAchievements extends ConsumerWidget {
  const CaroselloAchievements({required this.ambito, this.titolo, super.key});

  /// `null` = **tutte**, come vuole «Oggi».
  final AmbitoAchievement? ambito;

  /// L'intestazione sopra il carosello. `null` = nessuna.
  final String? titolo;

  /// L'altezza delle card, uguale per tutte.
  ///
  /// ⚠️ Stessa ragione del carosello del mese: con altezze diverse lo
  /// scorrimento **salta**, e salta in modo diverso a seconda di quante parole
  /// ha la descrizione — cioè a caso.
  static const altezza = 84.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medaglie = ref.watch(achievementsPerAmbitoProvider(ambito));

    // ⛔ A.8.5: vuoto vuol dire **niente**, nemmeno un titolo.
    if (medaglie.isEmpty) return const SizedBox.shrink();

    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titolo != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xs),
            child: Text(
              titolo!,
              style: tema.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

        SizedBox(
          height: altezza,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            itemCount: medaglie.length,
            itemBuilder: (context, i) => _CardMedaglia(medaglia: medaglie[i]),
          ),
        ),
      ],
    );
  }
}

class _CardMedaglia extends StatelessWidget {
  const _CardMedaglia({required this.medaglia});

  final Achievement medaglia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    /*
     * 💡 Una medaglia non ancora presa si vede **spenta**, non nascosta: sapere
     * cosa manca è metà del senso di un sistema di medaglie. ⚠️ Se FASE 12
     * deciderà di non mostrarle affatto, basta non passarle qui.
     */
    final presa = medaglia.ottenutoIl != null;

    return SizedBox(
      width: 260,
      child: Card(
        margin: const EdgeInsets.only(right: Gap.sm),
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm),
          child: Row(
            children: [
              // 📌 «a sinistra l'icona», come chiesto.
              DecoratedBox(
                decoration: BoxDecoration(
                  color: presa
                      ? tema.colorScheme.primaryContainer
                      : tema.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(Gap.sm),
                  child: Icon(
                    medaglia.icona,
                    size: 22,
                    color: presa
                        ? tema.colorScheme.onPrimaryContainer
                        : tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(width: Gap.sm),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      medaglia.titolo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      medaglia.descrizione,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
