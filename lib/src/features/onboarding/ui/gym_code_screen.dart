import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../branding_controller.dart';

/// «Inserisci il codice della tua palestra» — A2.1.
///
/// È la primissima schermata di un'app white-label: prima di questa, l'app non
/// sa nemmeno di che colore essere.
///
/// 🚨 **Un solo messaggio d'errore per tutti i casi negativi.** Il backend
/// risponde 404 sia per un codice inesistente sia per una palestra sospesa, e lo
/// fa apposta: distinguere i due casi permetterebbe a chiunque di provare codici
/// a tappeto e ricavare l'elenco dei clienti — quali palestre esistono e quali
/// hanno smesso di pagare. L'app non deve reintrodurre la distinzione.
class GymCodeScreen extends ConsumerStatefulWidget {
  const GymCodeScreen({super.key});

  @override
  ConsumerState<GymCodeScreen> createState() => _GymCodeScreenState();
}

class _GymCodeScreenState extends ConsumerState<GymCodeScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _inCorso = false;
  String? _errore;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _cerca() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await ref.read(brandingControllerProvider.notifier).lookup(_controller.text);

      if (mounted) context.go(AppRoutes.login);
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      setState(() {
        _errore = tradotto is NetworkException
            ? tradotto.message
            // Un solo messaggio: vedi la nota di classe.
            : 'Codice non valido. Controllalo con la tua palestra.';
      });
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  /// Prosegue **senza** palestra — F3.
  ///
  /// 🚨 Non valida il campo e non chiama la rete: non c'è niente da cercare, e
  /// far passare questa strada dalla validazione vorrebbe dire chiedere un
  /// codice di 8 caratteri a chi ha appena detto di non averne uno.
  Future<void> _prosegui() async {
    setState(() {
      _inCorso = true;
      _errore = null;
    });

    await ref.read(brandingControllerProvider.notifier).senzaPalestra();

    if (mounted) {
      setState(() => _inCorso = false);
      context.go(AppRoutes.register);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    Icon(Icons.fitness_center_rounded, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: Gap.lg),

                    Text(
                      'Benvenuto',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      'Inserisci il codice che ti ha dato la tua palestra.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Gap.xl),

                    TextFormField(
                      controller: _controller,
                      autofocus: true,
                      // 🚨 `characters` e non `text`: la tastiera numerica non
                      // basta (il codice ha lettere) e quella predefinita su
                      // iOS attiva la maiuscola automatica e la correzione, che
                      // su un codice sono due modi per sbagliarlo.
                      keyboardType: TextInputType.visiblePassword,
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      maxLength: 8,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        letterSpacing: 8,
                        fontWeight: FontWeight.w700,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                        // Si maiuscolizza mentre si digita: il backend confronta
                        // in maiuscolo, e chiedere all'utente di ricordarsene è
                        // un errore che possiamo evitare noi.
                        TextInputFormatter.withFunction(
                          (_, nuovo) => nuovo.copyWith(text: nuovo.text.toUpperCase()),
                        ),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'ABCD1234',
                        counterText: '',
                      ),
                      validator: (v) => (v ?? '').trim().length == 8
                          ? null
                          : 'Il codice è di 8 caratteri.',
                      onFieldSubmitted: (_) => _cerca(),
                    ),

                    if (_errore != null) ...[
                      const SizedBox(height: Gap.md),
                      Text(
                        _errore!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                      ),
                    ],

                    const SizedBox(height: Gap.lg),
                    FilledButton(
                      onPressed: _inCorso ? null : _cerca,
                      child: _inCorso
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Continua'),
                    ),

                    /*
                     * 🆕 **La via d'uscita per chi non ha una palestra** — F3.
                     *
                     * ⚠️ È un `TextButton` e non un secondo `FilledButton`, ed è
                     * una scelta: due pulsanti di pari peso costringerebbero a
                     * scegliere fra due strade prima di aver capito la
                     * differenza. La strada principale resta il codice —
                     * chi ce l'ha lo digita e non legge nemmeno questa riga.
                     *
                     * 💡 La frase dice cosa si perde, non cosa si guadagna:
                     * «senza palestra» è l'informazione che serve a decidere, e
                     * un invito entusiasta a proseguire da soli farebbe saltare
                     * il codice a gente che ce l'ha in tasca.
                     */
                    const SizedBox(height: Gap.sm),
                    TextButton(
                      onPressed: _inCorso ? null : _prosegui,
                      child: const Text('Non ho un codice: continuo senza palestra'),
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
