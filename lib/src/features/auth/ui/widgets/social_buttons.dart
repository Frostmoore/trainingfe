import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../onboarding/branding_controller.dart';
import '../../auth_controller.dart';
import '../../data/social_sign_in.dart';

/// «Accedi con Google» / «Accedi con Apple» — C17.
///
/// 🚨 **Non disegna niente finché il server non dichiara il fornitore.**
/// `GymBranding.social` arriva dal backend ed è vuoto finché mancano le
/// credenziali: un pulsante che risponde sempre errore fa sembrare rotta tutta
/// l'applicazione, non solo quel pulsante. È anche il motivo per cui la
/// disponibilità non è una costante dentro l'app — cambiarla richiederebbe una
/// pubblicazione sugli store.
class SocialButtons extends ConsumerStatefulWidget {
  const SocialButtons({super.key});

  @override
  ConsumerState<SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends ConsumerState<SocialButtons> {
  String? _inCorso;
  String? _errore;

  Future<void> _accedi(String provider) async {
    setState(() {
      _inCorso = provider;
      _errore = null;
    });

    try {
      // ⚠️ Il codice palestra si manda **se lo sappiamo**: serve solo al primo
      // accesso, e il server lo ignora dal secondo in poi. Chi arriva qui l'ha
      // già inserito nella schermata precedente, quindi nella pratica c'è
      // sempre — ma il server risponde comunque `join_code_required` se manca,
      // e quel caso va detto invece di mostrare un errore generico.
      await ref
          .read(authControllerProvider.notifier)
          .loginWithSocial(
            provider,
            joinCode: ref.read(brandingControllerProvider).joinCode,
          );
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      setState(() => _errore = tradotto.message);
    } finally {
      if (mounted) setState(() => _inCorso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palestra = ref.watch(brandingControllerProvider).branding;

    final disponibili = SocialProviderId.tutti
        .where(palestra.supporta)
        .toList(growable: false);

    if (disponibili.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              child: Text('oppure', style: theme.textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: Gap.md),

        for (final provider in disponibili) ...[
          OutlinedButton.icon(
            onPressed: _inCorso != null ? null : () => _accedi(provider),
            icon: _inCorso == provider
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_icona(provider)),
            label: Text('Continua con ${SocialProviderId.etichetta(provider)}'),
          ),
          const SizedBox(height: Gap.sm),
        ],

        if (_errore != null)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Text(
              _errore!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }

  /// ⚠️ Icone di sistema, non i marchi.
  ///
  /// I loghi di Google e Apple hanno regole d'uso precise (dimensioni, spazi,
  /// colori, sfondo) e vanno inclusi come immagini fornite da loro. Metterne una
  /// versione approssimata è il genere di cosa che fa **rifiutare la
  /// pubblicazione** — quindi finché non ci sono gli asset ufficiali, meglio
  /// un'icona neutra che una imitazione.
  IconData _icona(String provider) => switch (provider) {
    SocialProviderId.apple => Icons.phone_iphone_rounded,
    _ => Icons.account_circle_outlined,
  };
}
