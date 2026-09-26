import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../onboarding/branding_controller.dart';
import '../../auth_controller.dart';
import '../../data/accesso_social_vero.dart';
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
  const SocialButtons({this.dichiarazioniDate = true, super.key});

  /// 🚨 S9.2 — se questa schermata **iscrive**, le due caselle valgono anche
  /// qui: chi entra con Google si iscrive esattamente come chi compila il
  /// modulo.
  ///
  /// ⚠️ Il valore di serie è `true` perché sulla schermata di **accesso** non
  /// c'è niente da dichiarare — lì non nasce nessun account. È la schermata di
  /// registrazione che lo mette a `false` finché le caselle non sono spuntate.
  final bool dichiarazioniDate;

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
      // ⛔ F11 — niente più codice palestra: al primo accesso il server collega
      // l'identità all'account con la stessa email verificata.
      await ref
          .read(authControllerProvider.notifier)
          .loginWithSocial(
            provider,
            // 🚨 Arrivano fin qui solo se le caselle sono spuntate: il pulsante
            // è disabilitato altrimenti. Il server le pretende comunque al primo
            // accesso, quindi anche un percorso che le saltasse fallirebbe con
            // un 422 — rumorosamente, invece che in silenzio.
            maggiorenne: widget.dichiarazioniDate,
            condizioniAccettate: widget.dichiarazioniDate,
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

    /*
     * 🆕 ⚖️ **Due condizioni, non una** — voce 25, 26/09/2026.
     *
     * 1. il **server** deve dichiarare il fornitore (`palestra.supporta`);
     * 2. la **piattaforma** deve saperlo fare davvero.
     *
     * 🚨 La seconda serviva e non c'era. 📌 Il committente, 26/09: *«Apple solo
     * su iOS»*. ⛔ Ma il server dichiara i fornitori **una volta per tutti**,
     * senza sapere da che telefono arriva la richiesta: con Apple acceso lato
     * server, il pulsante sarebbe comparso **anche su Android**, dove l'accesso
     * nativo con Apple non esiste. 💡 Un pulsante che non può funzionare è
     * peggio di un pulsante assente.
     */
    final disponibili = SocialProviderId.tutti
        .where(palestra.supporta)
        .where(
          (p) => fornitoreUsabileQui(
            p,
            sistemaApple: AccessoSocialVero.supportaApple,
          ),
        )
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
            onPressed: _inCorso != null || !widget.dichiarazioniDate
                ? null
                : () => _accedi(provider),
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
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
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
