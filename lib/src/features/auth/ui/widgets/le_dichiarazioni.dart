import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/social_sign_in.dart';

/// ⚖️ **Le due dichiarazioni, chieste solo a chi si sta iscrivendo** — voce 25,
/// 26/09/2026.
///
/// ══ 🔑 PERCHE' QUI E NON SULLA SCHERMATA ═══════════════════════════════════
///
/// 📌 Decisione del committente, 26/09, fra tre strade: *«chiedile solo se
/// servono davvero»*.
///
/// 🚨 Sulla schermata di benvenuto **nessuno sa** se la persona sta entrando o
/// si sta iscrivendo: è la domanda a cui quella schermata serve a rispondere.
/// ⛔ Mettere le caselle lì vorrebbe dire farle spuntare anche a chi sta solo
/// rientrando nel proprio account — un adempimento chiesto a chi l'ha già
/// fatto, che è il modo migliore per farlo leggere a nessuno.
///
/// 💡 Si scopre che è un'iscrizione **solo** quando il server risponde
/// `consents_required`, cioè dopo aver parlato col fornitore. Allora si chiede.
///
/// ⚖️ **Restano esplicite**: due caselle separate, spente di partenza, e il
/// pulsante non si accende finché non sono spuntate tutte e due. ⛔ Niente
/// «continuando accetti»: un consenso che si dà senza accorgersene non è un
/// consenso (art. 7 GDPR), e queste due cose — la maggiore età e le condizioni
/// — sono **distinte**, quindi non si possono accorpare in una casella sola.
Future<bool?> mostraLeDichiarazioni(BuildContext context, String provider) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _LeDichiarazioni(provider: provider),
    );

class _LeDichiarazioni extends StatefulWidget {
  const _LeDichiarazioni({required this.provider});

  final String provider;

  @override
  State<_LeDichiarazioni> createState() => _LeDichiarazioniState();
}

class _LeDichiarazioniState extends State<_LeDichiarazioni> {
  bool _maggiorenne = false;
  bool _condizioni = false;

  bool get _complete => _maggiorenne && _condizioni;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fornitore = SocialProviderId.etichetta(widget.provider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        Gap.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ancora due cose',
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Gap.sm),

          /*
           * 💡 Si dice **perché** compaiono adesso. ⛔ Due caselle che
           * spuntano dal nulla dopo aver scelto l'account sembrano un
           * inciampo: qui si spiega che è un'iscrizione, non un errore.
           */
          Text(
            'Non hai ancora un account: entrando con $fornitore te ne stiamo '
            'creando uno. Per farlo servono queste due dichiarazioni.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Gap.md),

          CheckboxListTile(
            value: _maggiorenne,
            onChanged: (v) => setState(() => _maggiorenne = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Dichiaro di essere maggiorenne'),
          ),
          CheckboxListTile(
            value: _condizioni,
            onChanged: (v) => setState(() => _condizioni = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Accetto le condizioni d\'uso'),
          ),
          const SizedBox(height: Gap.md),

          FilledButton(
            // ⛔ Spento finché non sono spuntate tutte e due: il server le
            // pretende comunque, e un pulsante che fallisce di sicuro è
            // peggio di un pulsante spento.
            onPressed: _complete ? () => Navigator.of(context).pop(true) : null,
            child: const Text('Continua'),
          ),
          const SizedBox(height: Gap.xs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );
  }
}
