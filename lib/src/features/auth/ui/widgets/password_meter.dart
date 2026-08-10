import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/password_strength.dart';

/// La barra della robustezza, con i consigli sotto.
///
/// 🚨 **I consigli non sono un di più: sono la ragione per cui il widget
/// esiste.** Una barra che diventa rossa senza spiegare perché fa aggiungere un
/// punto esclamativo in fondo — la mossa che gli attacchi si aspettano. Qui la
/// barra è l'attrattore visivo e il testo è il contenuto.
///
/// ⚠️ Si mostrano **al massimo due** consigli per volta, i primi due, che sono
/// i più utili: l'elenco è già ordinato per impatto. Cinque righe di
/// raccomandazioni sotto un campo password non le legge nessuno, e spingono
/// fuori schermo il pulsante «Crea account».
class PasswordMeter extends StatelessWidget {
  const PasswordMeter({required this.forza, super.key});

  final PasswordStrength forza;

  static const _quantiConsigli = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (forza.level == PasswordLevel.inesistente) {
      return const SizedBox.shrink();
    }

    final colore = _colore(theme);

    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Quattro segmenti separati e non una barra continua: dicono
              // «quanti passi mancano» invece di una percentuale, che su una
              // stima come questa sarebbe una precisione finta.
              for (var i = 0; i < 4; i++) ...[
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 4,
                    decoration: BoxDecoration(
                      color: i < forza.score
                          ? colore
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < 3) const SizedBox(width: Gap.xs),
              ],
            ],
          ),
          const SizedBox(height: Gap.xs),
          Text(
            forza.level.etichetta,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colore,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final consiglio in forza.suggerimenti.take(_quantiConsigli))
            Padding(
              padding: const EdgeInsets.only(top: Gap.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Gap.xs),
                  Expanded(
                    child: Text(
                      consiglio,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// ⚠️ Il verde del «va bene» è `tertiary`, non un verde scritto a mano: il
  /// tema nasce dai colori della palestra (ADR-A01) e un colore fisso stonerebbe
  /// su metà dei clienti. Il rosso invece è `error`, perché lì *deve* essere il
  /// rosso degli errori.
  Color _colore(ThemeData theme) => switch (forza.score) {
    0 => theme.colorScheme.error,
    1 => theme.colorScheme.error,
    2 => theme.colorScheme.tertiary,
    _ => theme.colorScheme.primary,
  };
}
