import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/branding_controller.dart';
import '../auth_controller.dart';
import 'widgets/gym_header.dart';
import 'widgets/social_buttons.dart';

/// L'accesso — A2.3.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Accetta **email o nome utente**: si chiama così perché è quello che è.
  final _login = TextEditingController();
  final _password = TextEditingController();

  bool _inCorso = false;
  bool _nascondiPassword = true;
  String? _errore;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _accedi() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(
            login: _login.text,
            password: _password.text,
            joinCode: ref.read(brandingControllerProvider).joinCode,
          );
      // Il router porta dentro da solo: `redirect` reagisce al cambio di stato.
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      setState(() {
        // 🚨 **Solo un 422 è «credenziali sbagliate».**
        //
        // Prima qui c'era un `_ =>` che mappava *qualunque* errore su «email o
        // password non corretti», e ha nascosto per un pomeriggio un difetto
        // del client: il login non funzionava per nessuno, e l'app dava la
        // colpa all'utente. Un messaggio che accusa chi sta davanti allo
        // schermo di un errore nostro è peggio di nessun messaggio, perché
        // porta a cercare nel posto sbagliato — e chi lo cerca è l'utente.
        //
        // Il messaggio unico per credenziali sbagliate, utente inesistente e
        // account disattivato resta: distinguerli direbbe a chi prova indirizzi
        // quali sono registrati in questa palestra, e il backend risponde già
        // allo stesso modo apposta.
        _errore = switch (tradotto) {
          ValidationException() =>
            'Email, nome utente o password non corretti.',
          NetworkException() => tradotto.message,
          GymInactiveException() => tradotto.message,
          RateLimitedException() => 'Troppi tentativi. Aspetta un minuto.',
          // Tutto il resto mostra il proprio messaggio: se è un guasto nostro,
          // deve sembrare un guasto nostro.
          _ => tradotto.message,
        };
      });
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branding = ref.watch(brandingControllerProvider).branding;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Gap.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GymHeader(branding: branding),
                    const SizedBox(height: Gap.xl),

                    TextFormField(
                      controller: _login,
                      // ⚠️ `emailAddress` **no**: quella tastiera mette la «@»
                      // in evidenza e su iOS attiva la correzione, che su un
                      // nome utente è un modo per sbagliarlo. `text` con
                      // correzione e maiuscole spente va bene per entrambi.
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Email o nome utente',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Serve la tua email o il tuo nome utente.'
                          : null,
                    ),
                    const SizedBox(height: Gap.md),

                    TextFormField(
                      controller: _password,
                      obscureText: _nascondiPassword,
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _nascondiPassword = !_nascondiPassword,
                          ),
                          icon: Icon(
                            _nascondiPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v ?? '').isEmpty ? 'Serve la tua password.' : null,
                      onFieldSubmitted: (_) => _accedi(),
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
                      onPressed: _inCorso ? null : _accedi,
                      child: _inCorso
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Accedi'),
                    ),

                    // Non disegna niente finché il server non dichiara un
                    // fornitore configurato.
                    const SocialButtons(),

                    const SizedBox(height: Gap.sm),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.register),
                      child: const Text('Non ho ancora un account'),
                    ),

                    /*
                     * 🚨 **Stessa dignità dell'accesso** — difetto riferito il
                     * 13/08/2026.
                     *
                     * ⚠️ Era un `TextButton` in fondo, largo quanto il suo
                     * testo. Ma «cambia palestra» è la via d'uscita di chi si
                     * trova nel posto sbagliato — un iscritto che ha digitato
                     * il codice di un'altra palestra, o chi vuole passare
                     * all'accesso senza palestra — e chi è nel posto sbagliato
                     * non deve cercare l'uscita scritta più piccola.
                     */
                    const SizedBox(height: Gap.md),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await ref
                            .read(brandingControllerProvider.notifier)
                            .forget();
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: Text(
                        ref.watch(brandingControllerProvider).hasGym
                            ? 'Cambia palestra'
                            : 'Entra con una palestra',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
