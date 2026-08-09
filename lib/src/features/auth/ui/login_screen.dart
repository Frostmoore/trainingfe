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

/// L'accesso — A2.3.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _inCorso = false;
  bool _nascondiPassword = true;
  String? _errore;

  @override
  void dispose() {
    _email.dispose();
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
            email: _email.text,
            password: _password.text,
            joinCode: ref.read(brandingControllerProvider).joinCode,
          );
      // Il router porta dentro da solo: `redirect` reagisce al cambio di stato.
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      setState(() {
        // 🚨 Un solo messaggio per credenziali sbagliate, utente inesistente e
        // account disattivato. Distinguerli direbbe a chi prova indirizzi quali
        // sono registrati in questa palestra — e il backend risponde già allo
        // stesso modo apposta.
        _errore = switch (tradotto) {
          NetworkException() => tradotto.message,
          GymInactiveException() => tradotto.message,
          RateLimitedException() => 'Troppi tentativi. Aspetta un minuto.',
          _ => 'Email o password non corretti.',
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
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Serve la tua email.' : null,
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
                          onPressed: () =>
                              setState(() => _nascondiPassword = !_nascondiPassword),
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
                    const SizedBox(height: Gap.sm),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.register),
                      child: const Text('Non ho ancora un account'),
                    ),

                    const SizedBox(height: Gap.md),
                    TextButton.icon(
                      onPressed: () async {
                        await ref.read(brandingControllerProvider.notifier).forget();
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Cambia palestra'),
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
