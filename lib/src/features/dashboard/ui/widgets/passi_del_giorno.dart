import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../health/health_controller.dart';

/// I passi della giornata, sotto le bruciate — 07/09/2026.
///
/// ⚠️ **`ConsumerWidget` e non un parametro**: il numero arriva da un provider
/// che si aggiorna quando l'orologio manda dati nuovi, e passarlo dall'alto
/// avrebbe voluto dire far ridisegnare **tutta** la card di «Oggi» a ogni
/// sincronizzazione — cioè la più cara che abbiamo.
///
/// 📌 Stava nel Diario fino al 07/09/2026, per una mia lettura sbagliata di
/// *«nella prima card delle calorie»*.
class PassiDelGiorno extends ConsumerWidget {
  const PassiDelGiorno({required this.giorno, super.key});

  final DateTime giorno;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passi = ref.watch(passiDelGiornoProvider(giorno)).valueOrNull ?? 0;

    /*
     * 🚨 **Zero vuol dire «non lo sappiamo», non «non hai camminato».** Arriva
     * zero in due casi diversi: finché il permesso `STEPS` non è concesso, e nel
     * frame in cui il provider sta ancora caricando.
     *
     * ⛔ Mostrare «0 passi» a chi ha camminato tutto il giorno direbbe una cosa
     * falsa con l'aria di un dato misurato.
     *
     * ⚠️ **E la riga compare solo con la card a schermo**, cioè nella scheda
     * Diario: verificato il 07/09/2026 con una traccia temporanea, che diceva
     * `valore=8192 → mostro=true` appena si apriva quella scheda. 💡 Chi la
     * cerca dalla schermata «Oggi» non la trova, e non è un difetto.
     */
    if (passi <= 0) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: Gap.xs),
      child: Row(
        children: [
          Icon(
            Icons.directions_walk_rounded,
            size: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '${_conIPunti(passi)} passi',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// 💡 `10.482` e non `10482`: a colpo d'occhio le migliaia si contano da sole.
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
