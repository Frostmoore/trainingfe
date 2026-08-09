import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/branding_controller.dart';
import '../auth_controller.dart';
import 'widgets/gym_header.dart';

/// L'iscrizione — A2.3.
///
/// Il `join_code` non si chiede: è già stato inserito nella schermata
/// precedente e sta nella cache. Richiederlo qui sarebbe far ridigitare a mano
/// una cosa che l'app già sa — il modo più rapido per far sbagliare qualcuno.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  /// Il nome utente si propone dal nome, ma **smette** appena l'utente lo
  /// tocca: continuare a sovrascriverlo mentre corregge il cognome sarebbe il
  /// modo più rapido per fargli odiare il modulo.
  bool _usernameToccato = false;

  bool _inCorso = false;
  String? _errore;
  Map<String, List<String>> _erroriCampo = const {};

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Propone un nome utente dal nome e cognome.
  ///
  /// 🚨 Solo finché l'utente non lo tocca. Continuare a sovrascriverlo mentre
  /// corregge il cognome cancellerebbe quello che ha appena scritto, ed è il
  /// tipo di «aiuto» che fa abbandonare un modulo.
  void _proponiUsername(String nome) {
    if (_usernameToccato) return;

    final proposta = nome
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), '.');

    _username.text = proposta.length > 30 ? proposta.substring(0, 30) : proposta;
  }

  Future<void> _registrati() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final code = ref.read(brandingControllerProvider).joinCode;

    if (code == null || code.isEmpty) {
      setState(() => _errore = 'Manca il codice della palestra.');

      return;
    }

    setState(() {
      _inCorso = true;
      _errore = null;
      _erroriCampo = const {};
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .register(
            joinCode: code,
            name: _nome.text,
            email: _email.text,
            username: _username.text,
            password: _password.text,
          );
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      setState(() {
        // 🚨 Gli errori di validazione vanno **sotto il campo giusto**, non in
        // un elenco in cima: su uno schermo di telefono un messaggio in cima e
        // il campo sbagliato in fondo non si vedono insieme, e l'utente non
        // capisce cosa correggere.
        if (tradotto is ValidationException) {
          _erroriCampo = tradotto.errors;
          _formKey.currentState?.validate();
        } else {
          _errore = tradotto.message;
        }
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
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go(AppRoutes.login),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
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
                    const SizedBox(height: Gap.sm),
                    Text(
                      'Crea il tuo account',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Gap.xl),

                    TextFormField(
                      controller: _nome,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: 'Nome e cognome',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        errorText: _erroriCampo['name']?.first,
                      ),
                      onChanged: _proponiUsername,
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Come ti chiami?' : null,
                    ),
                    const SizedBox(height: Gap.md),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        errorText: _erroriCampo['email']?.first,
                      ),
                      validator: (v) {
                        final value = (v ?? '').trim();

                        if (value.isEmpty) return 'Serve la tua email.';

                        // Controllo volutamente lasco: la validazione vera è
                        // del backend, e una regex severa qui rifiuterebbe
                        // indirizzi legittimi che il server accetta.
                        return value.contains('@') ? null : 'Non sembra un\'email.';
                      },
                    ),
                    const SizedBox(height: Gap.md),

                    TextFormField(
                      controller: _username,
                      // Le stesse restrizioni del backend, applicate mentre si
                      // digita: scoprire al salvataggio che «Marco Rossi» non
                      // va bene come nome utente è un giro inutile.
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9._\-]')),
                        TextInputFormatter.withFunction(
                          (_, nuovo) => nuovo.copyWith(text: nuovo.text.toLowerCase()),
                        ),
                      ],
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: 'Nome utente',
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        helperText: 'Ti servirà per accedere, al posto dell\'email.',
                        counterText: '',
                        errorText: _erroriCampo['username']?.first,
                      ),
                      onChanged: (_) => _usernameToccato = true,
                      validator: (v) {
                        final value = (v ?? '').trim();

                        if (value.length < 3) return 'Almeno 3 caratteri.';

                        // Deve cominciare e finire con lettera o numero: un
                        // nome utente che finisce con un punto confonde chi lo
                        // legge ad alta voce al telefono.
                        return RegExp(r'^[a-z0-9](?:[a-z0-9._\-]*[a-z0-9])?$').hasMatch(value)
                            ? null
                            : 'Lettere, numeri, punto, trattino e trattino basso.';
                      },
                    ),
                    const SizedBox(height: Gap.md),

                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        helperText: 'Almeno 8 caratteri.',
                        errorText: _erroriCampo['password']?.first,
                      ),
                      validator: (v) =>
                          (v ?? '').length >= 8 ? null : 'Almeno 8 caratteri.',
                      onFieldSubmitted: (_) => _registrati(),
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
                      onPressed: _inCorso ? null : _registrati,
                      child: _inCorso
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crea account'),
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
