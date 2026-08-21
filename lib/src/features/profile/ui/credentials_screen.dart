import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../auth/auth_controller.dart';
import '../../auth/data/password_strength.dart';
import '../../auth/ui/widgets/password_meter.dart';
import '../profile_controller.dart';

/// Cambiare la propria email e la propria password — G8.
///
/// 🚨 **Entrambe chiedono la password attuale.** Un telefono lasciato sbloccato
/// sulla panca dello spogliatoio non deve bastare a spostare l'account su un
/// indirizzo altrui — e da lì, con un recupero password, a prenderselo.
///
/// ⏸️ **Chi entra con Google o Apple non vede questa schermata.** Una password
/// ce l'ha, ma casuale e mai vista: il modulo gli chiederebbe «quella attuale»
/// e non potrebbe compilarlo. Il profilo mostra invece con quale servizio
/// accede.
class CredentialsScreen extends ConsumerWidget {
  const CredentialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final utente = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Email e password'),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          _CambiaEmail(attuale: utente?.email ?? ''),
          const SizedBox(height: Gap.lg),
          const _CambiaPassword(),
        ],
      ),
    );
  }
}

class _CambiaEmail extends ConsumerStatefulWidget {
  const _CambiaEmail({required this.attuale});

  final String attuale;

  @override
  ConsumerState<_CambiaEmail> createState() => _CambiaEmailState();
}

class _CambiaEmailState extends ConsumerState<_CambiaEmail> {
  late final _email = TextEditingController(text: widget.attuale);
  final _password = TextEditingController();

  bool _inCorso = false;
  Map<String, List<String>> _errori = const {};

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    setState(() {
      _inCorso = true;
      _errori = const {};
    });

    try {
      await ref
          .read(profileActionsProvider)
          .cambiaEmail(
            email: _email.text.trim(),
            passwordAttuale: _password.text,
          );

      if (!mounted) return;

      _password.clear();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Email aggiornata.')));
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      setState(() {
        if (tradotto is ValidationException) {
          _errori = tradotto.errors;
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tradotto.message)));
        }
      });
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Email', style: theme.textTheme.titleMedium),
            const SizedBox(height: Gap.md),

            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Nuova email',
                prefixIcon: const Icon(Icons.alternate_email_rounded),
                errorText: _errori['email']?.first,
              ),
            ),
            const SizedBox(height: Gap.md),

            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'La tua password attuale',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                errorText: _errori['current_password']?.first,
              ),
            ),

            const SizedBox(height: Gap.sm),
            Text(
              'Serve a essere sicuri che sia tu: con l\'email si recupera '
              'l\'accesso, quindi cambiarla è come cambiare le chiavi.',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: Gap.md),
            FilledButton(
              onPressed: _inCorso ? null : _salva,
              child: _inCorso
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cambia email'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CambiaPassword extends ConsumerStatefulWidget {
  const _CambiaPassword();

  @override
  ConsumerState<_CambiaPassword> createState() => _CambiaPasswordState();
}

class _CambiaPasswordState extends ConsumerState<_CambiaPassword> {
  final _attuale = TextEditingController();
  final _nuova = TextEditingController();
  final _conferma = TextEditingController();

  PasswordStrength _forza = const PasswordStrength(
    score: 0,
    level: PasswordLevel.inesistente,
    suggerimenti: [],
  );

  bool _inCorso = false;
  Map<String, List<String>> _errori = const {};

  @override
  void dispose() {
    _attuale.dispose();
    _nuova.dispose();
    _conferma.dispose();
    super.dispose();
  }

  Future<void> _salva() async {
    if (_nuova.text != _conferma.text) {
      setState(
        () => _errori = {
          'password': ['Le due password non coincidono.'],
        },
      );

      return;
    }

    // Stessa soglia della registrazione: sotto, il server risponde 422 e far
    // premere il pulsante per fallire dopo un giro di rete è solo più lento.
    if (!_forza.accettabile) {
      setState(
        () => _errori = {
          'password': ['Troppo debole: segui il consiglio qui sotto.'],
        },
      );

      return;
    }

    setState(() {
      _inCorso = true;
      _errori = const {};
    });

    try {
      await ref
          .read(profileActionsProvider)
          .cambiaPassword(
            passwordAttuale: _attuale.text,
            nuova: _nuova.text,
            conferma: _conferma.text,
          );

      if (!mounted) return;

      _attuale.clear();
      _nuova.clear();
      _conferma.clear();

      setState(() {
        _forza = const PasswordStrength(
          score: 0,
          level: PasswordLevel.inesistente,
          suggerimenti: [],
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password aggiornata. Gli altri dispositivi sono stati disconnessi.',
          ),
        ),
      );
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      setState(() {
        if (tradotto is ValidationException) {
          _errori = tradotto.errors;
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(tradotto.message)));
        }
      });
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final utente = ref.watch(authControllerProvider).user;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Password', style: theme.textTheme.titleMedium),
            const SizedBox(height: Gap.md),

            TextField(
              controller: _attuale,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password attuale',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                errorText: _errori['current_password']?.first,
              ),
            ),
            const SizedBox(height: Gap.md),

            TextField(
              controller: _nuova,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Nuova password',
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                errorText: _errori['password']?.first,
              ),
              onChanged: (v) => setState(() {
                _forza = PasswordStrength.valuta(
                  v,
                  nome: utente?.name,
                  email: utente?.email,
                  username: utente?.username,
                );
              }),
            ),

            PasswordMeter(forza: _forza),
            const SizedBox(height: Gap.md),

            TextField(
              controller: _conferma,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Ripeti la nuova password',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: Gap.sm),
            Text(
              // ⚠️ Va detto **prima**: chi cambia password da un telefono
              // secondario e si ritrova disconnesso altrove senza preavviso
              // pensa che qualcosa sia andato storto.
              'Cambiandola, gli altri dispositivi verranno disconnessi. '
              'Questo no.',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: Gap.md),
            FilledButton(
              onPressed: _inCorso ? null : _salva,
              child: _inCorso
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Cambia password'),
            ),
          ],
        ),
      ),
    );
  }
}
