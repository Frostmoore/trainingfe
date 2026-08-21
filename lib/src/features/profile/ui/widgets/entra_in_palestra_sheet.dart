import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/auth_controller.dart';
import '../../../onboarding/branding_controller.dart';

/// «Entra in una palestra» — requisito **B4**, chiesto il 13/08/2026.
///
/// ── 🚨 Cosa succede davvero quando si preme «Entra» ────────────────────────
///
/// **Non è un cambio di etichetta: è una migrazione di dati.** Diario,
/// allenamenti, piani e foto sono tutti marcati con il tenant personale, e il
/// server li sposta uno per uno sotto quello della palestra. Senza, resterebbero
/// in tabella e **sparirebbero dalla vista** — non cancellati, invisibili.
///
/// ⚠️ **Ed è a senso unico.** Da una palestra non si esce da soli: spostare un
/// iscritto da una palestra a un'altra è un'operazione commerciale, non una
/// scelta dell'utente. Per questo il foglio lo dice **prima**, non dopo.
class EntraInPalestraSheet extends ConsumerStatefulWidget {
  const EntraInPalestraSheet({super.key});

  static Future<void> mostra(BuildContext context) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const Padding(
          padding: EdgeInsets.only(bottom: 0),
          child: EntraInPalestraSheet(),
        ),
      );

  @override
  ConsumerState<EntraInPalestraSheet> createState() =>
      _EntraInPalestraSheetState();
}

class _EntraInPalestraSheetState extends ConsumerState<EntraInPalestraSheet> {
  final _codice = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _inCorso = false;
  String? _errore;

  @override
  void dispose() {
    _codice.dispose();
    super.dispose();
  }

  Future<void> _entra() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final risposta = await ref
          .read(apiClientProvider)
          .post<Map<String, dynamic>>(
            '/account/join-gym',
            body: {'join_code': _codice.text.trim().toUpperCase()},
            unwrap: false,
          );

      /*
       * 🚨 **Tre cose da rifare, e in quest'ordine.**
       *
       * 1. il **branding**, o l'app resterebbe vestita di neutro dentro una
       *    palestra che ha i suoi colori — e sembrerebbe non aver funzionato;
       * 2. l'**utente**, perché il suo tenant e i suoi ruoli sono cambiati;
       * 3. la **chiusura** del foglio, per ultima: chiuderlo prima farebbe
       *    vedere per un istante la schermata vecchia con i dati vecchi.
       */
      final branding = risposta['branding'];

      if (branding is Map<String, dynamic>) {
        await ref.read(brandingControllerProvider.notifier).adotta(branding);
      }

      await ref.read(authControllerProvider.notifier).refresh();

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            risposta['message']?.toString() ?? 'Sei entrato nella palestra.',
          ),
        ),
      );
    } on Object catch (errore) {
      setState(() => _errore = ApiClient.unwrapError(errore).message);
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: Gap.lg,
        right: Gap.lg,
        top: Gap.lg,
        // La tastiera non deve coprire il campo: è l'unico campo del foglio.
        bottom: MediaQuery.of(context).viewInsets.bottom + Gap.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Entra in una palestra',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: Gap.sm),

            /*
             * 🚨 **Le due cose che vanno dette PRIMA di premere.**
             *
             * La prima rassicura, la seconda avverte — e la seconda è quella
             * che conta: da una palestra non si esce da soli. Scriverlo dopo
             * vorrebbe dire spiegare una porta a chi l'ha già attraversata.
             */
            Text(
              'Diario, allenamenti, schede e foto vengono con te: non perdi niente.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Attenzione: una volta dentro, per uscire dovrai parlarne con la '
              'palestra. E il tuo eventuale piano personale a pagamento lascia il '
              'posto a quello della palestra.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.lg),

            TextFormField(
              controller: _codice,
              autofocus: true,
              // Le stesse scelte della schermata d'ingresso: tastiera senza
              // correzione, maiuscole automatiche, otto caratteri.
              keyboardType: TextInputType.visiblePassword,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,

              // 🚨 E anche questo: `visiblePassword` + `autofocus` fanno
              // scattare il gestore di password del telefono, che chiede
              // l'impronta per riempire un codice che non è una credenziale.
              // ⚠️ Il predefinito è `const []`, che **accende** l'autofill:
              // solo `null` lo spegne. Vedi la nota lunga in
              // `gym_code_screen.dart`.
              autofillHints: null,
              maxLength: 8,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                letterSpacing: 6,
                fontWeight: FontWeight.w700,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                TextInputFormatter.withFunction(
                  (_, nuovo) => nuovo.copyWith(text: nuovo.text.toUpperCase()),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Codice della palestra',
                hintText: 'ABCD1234',
                counterText: '',
              ),
              validator: (v) => (v ?? '').trim().length == 8
                  ? null
                  : 'Il codice è di 8 caratteri.',
              onFieldSubmitted: (_) => _entra(),
            ),

            if (_errore != null) ...[
              const SizedBox(height: Gap.md),
              Text(
                _errore!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],

            const SizedBox(height: Gap.lg),
            FilledButton(
              onPressed: _inCorso ? null : _entra,
              child: _inCorso
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Entra'),
            ),
          ],
        ),
      ),
    );
  }
}
