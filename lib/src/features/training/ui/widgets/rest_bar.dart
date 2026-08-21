import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../rest_timer.dart';

/// La barra del riposo — C9.3.
///
/// Compare solo mentre il recupero è in corso e sta **in fondo**, dove si legge
/// da lontano con il telefono appoggiato: fra una serie e l'altra nessuno tiene
/// il telefono in mano.
///
/// 🚨 **Niente `Row` con `Spacer` qui dentro.**
/// La versione precedente metteva conto alla rovescia, etichetta e tre pulsanti
/// su una riga sola: a 320 px sforava di 114 px, e un `RenderFlex overflowed`
/// durante il layout **non è solo una striscia gialla** — è un'eccezione che
/// lascia il `Material` senza dimensione, e da lì parte una cascata di
/// «RenderBox was not laid out» che finisce col non disegnare **niente**. Sul
/// telefono il risultato era che la barra del recupero non compariva affatto,
/// e sembrava che il timer non partisse.
///
/// Adesso: i numeri su una riga, i comandi su quella sotto. Non c'è nessuna
/// larghezza che possa non bastare.
class RestBar extends StatelessWidget {
  const RestBar({required this.timer, super.key});

  final RestTimer timer;

  /// Di quanto si allunga o si accorcia il recupero.
  ///
  /// Quindici secondi e non trenta: è il passo con cui si aggiusta davvero un
  /// recupero mentre lo si sta facendo, e permette di dare due colpi per
  /// arrivare a trenta.
  static const passoSecondi = 15;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: timer,
    builder: (context, _) {
      if (!timer.attivo) return const SizedBox.shrink();

      final theme = Theme.of(context);
      final colore = theme.colorScheme.onPrimaryContainer;

      return Material(
        color: theme.colorScheme.primaryContainer,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🚨 La barra di progresso è la cosa che si guarda da lontano:
              // dice «a che punto sono» senza dover leggere un numero.
              LinearProgressIndicator(
                value: timer.progresso.clamp(0, 1),
                minHeight: 4,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.md,
                  Gap.sm,
                  Gap.md,
                  Gap.sm,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          timer.testo,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colore,
                            // Le cifre non devono ballare mentre scorrono: con
                            // la larghezza variabile il numero si sposta a ogni
                            // secondo ed è fastidioso da guardare.
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Flexible(
                          child: Text(
                            'recupero',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colore,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: Gap.xs),

                    // I comandi su una riga loro: tre pulsanti e un conto alla
                    // rovescia grande non ci stanno insieme, e il caso in cui
                    // non ci stanno è quello in cui l'app smette di disegnare.
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => timer.aggiungi(-passoSecondi),
                            child: const Text('−$passoSecondi s'),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => timer.aggiungi(passoSecondi),
                            child: const Text('+$passoSecondi s'),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Expanded(
                          child: FilledButton(
                            onPressed: timer.salta,
                            child: const Text('Salta'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
