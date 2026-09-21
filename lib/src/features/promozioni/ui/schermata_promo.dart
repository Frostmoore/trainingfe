import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/auth_controller.dart';
import '../data/promozioni.dart';
import 'schermata_offerte.dart';

/// 🔗 **Il link di attivazione di un'offerta, aperto nell'app** — 24/09/2026.
///
/// ⛔ Niente codici sconto: 📌 *«le promo si attivano solo in automatico o con
/// il link di attivazione»*. Si arriva da `https://…/promo/{codice}` (App Links).
///
/// | Chi | Cosa vede |
/// |---|---|
/// | con la sessione | la schermata delle offerte, con quella del link in cima e «Attiva» |
/// | senza | il codice si mette **da parte** (cache) e si propone di accedere: dopo l'accesso, «Offerte per te» lo ritrova — ⛔ senza, il link si perderebbe al login |
class SchermataPromo extends ConsumerWidget {
  const SchermataPromo({required this.codice, super.key});

  final String codice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dentro =
        ref.watch(authControllerProvider).status == AuthStatus.loggedIn;

    if (dentro) return SchermataOfferte(codiceIniziale: codice);

    ref
        .read(localCacheProvider)
        .setString(chiaveOffertaInAttesa, codice.toUpperCase());

    final tema = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.card_giftcard_rounded, size: 64),
              const SizedBox(height: Gap.md),
              Text(
                'Hai un\'offerta da attivare',
                textAlign: TextAlign.center,
                style: tema.textTheme.headlineSmall,
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Accedi, poi la trovi in Profilo → Offerte per te.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyLarge,
              ),
              const SizedBox(height: Gap.lg),
              FilledButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Accedi'),
              ),
              const SizedBox(height: Gap.sm),
              TextButton(
                onPressed: () => context.go(AppRoutes.register),
                child: const Text('Crea un account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
