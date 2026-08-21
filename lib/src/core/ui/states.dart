import 'package:flutter/material.dart';

import '../errors/api_exception.dart';
import '../theme/app_theme.dart';

/// I tre stati che ogni schermata che carica qualcosa deve saper mostrare —
/// A3.2.
///
/// 🚨 **Esistono per impedire che ognuna se li inventi.** Senza, metà delle
/// schermate mostrano uno spinner nudo e l'altra metà un `CircularProgress`
/// centrato con un padding diverso; e soprattutto **l'errore diventa un testo
/// rosso senza un pulsante per riprovare**, che è la cosa che fa chiudere
/// l'app.

/// Il vuoto: nessun dato, ma niente di rotto.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.outline),
            const SizedBox(height: Gap.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: Gap.lg), action!],
          ],
        ),
      ),
    );
  }
}

/// L'errore, **sempre con un modo per riprovare**.
///
/// 🚨 Il pulsante non è facoltativo: un errore senza via d'uscita lascia
/// l'utente su una schermata morta, e l'unica azione che gli resta è chiudere
/// l'app. Se davvero non c'è niente da ritentare, si usa `EmptyState`.
class ErrorState extends StatelessWidget {
  const ErrorState({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tradotto = error is ApiException ? error as ApiException : null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icona(tradotto), size: 56, color: scheme.error),
            const SizedBox(height: Gap.md),
            Text(
              // Il messaggio arriva già in italiano dal client API: qui non si
              // riscrive niente, altrimenti si finisce ad avere due frasi
              // diverse per lo stesso errore.
              tradotto?.message ?? 'Qualcosa è andato storto.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: Gap.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icona(ApiException? e) => switch (e) {
    NetworkException() => Icons.wifi_off_rounded,
    AiQuotaExceededException() => Icons.auto_awesome_outlined,
    RateLimitedException() => Icons.hourglass_bottom_rounded,
    _ => Icons.error_outline_rounded,
  };
}

/// Il caricamento.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(Gap.xl),
      child: CircularProgressIndicator(),
    ),
  );
}
