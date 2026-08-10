import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../rest_timer.dart';

/// La barra del riposo — C9.3.
///
/// Compare solo mentre il recupero è in corso e sta **in fondo**, dove si legge
/// da lontano con il telefono appoggiato: fra una serie e l'altra nessuno tiene
/// il telefono in mano.
class RestBar extends StatelessWidget {
  const RestBar({required this.timer, super.key});

  final RestTimer timer;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: timer,
    builder: (context, _) {
      if (!timer.attivo) return const SizedBox.shrink();

      final theme = Theme.of(context);

      return Material(
        color: theme.colorScheme.primaryContainer,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: timer.progresso.clamp(0, 1),
                minHeight: 3,
                backgroundColor: Colors.transparent,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Gap.md,
                  vertical: Gap.sm,
                ),
                child: Row(
                  children: [
                    Text(
                      timer.testo,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onPrimaryContainer,
                        // Le cifre non devono ballare mentre scorrono: con la
                        // larghezza variabile il numero si sposta a ogni
                        // secondo ed è fastidioso da guardare.
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(width: Gap.sm),
                    Text(
                      'recupero',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => timer.aggiungi(30),
                      child: const Text('+30s'),
                    ),
                    FilledButton(
                      onPressed: timer.salta,
                      child: const Text('Salta'),
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
