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

      /*
       * 🚨 **All'ACCESSO, non alla registrazione** — difetto riferito il
       * 19/08/2026.
       *
       * Chi non ha una palestra e ha gia' un account e' il caso **piu' comune**,
       * non quello raro: mandarlo a registrarsi gli fa credere di dover creare
       * un secondo utente. ⚠️ E chi lo crea davvero si ritrova i dati divisi
       * fra due utenze, che e' un guasto che non si ripara.
       *
       * 💡 La strada opposta resta aperta: la schermata di accesso ha gia' il
       * rimando alla registrazione. Si perde un tocco a chi si iscrive, se ne
       * guadagna uno a chi entra, e si evita un danno a chi sbaglia.
       */
      context.go(AppRoutes.login);
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
                      'Se sei iscritto a una palestra, inserisci il suo codice. '
                      'Altrimenti puoi cominciare da solo.',
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

                      /*
                       * 🚨 **`autofillHints: null` SPEGNE l'autofill, e serve
                       * davvero** — riferito provando l'app il 14/08/2026:
                       * *«mi chiede l'impronta prima ancora di aver fatto la
                       * scelta di palestra o autonomo»*.
                       *
                       * ⚠️ **Non era il nostro blocco biometrico.** Era il
                       * gestore di password del telefono: questo campo si
                       * dichiara `visiblePassword` (per avere la tastiera
                       * giusta, vedi sopra) ed è `autofocus`, quindi Android lo
                       * scambia per una casella di credenziali e al primo
                       * fotogramma dell'app offre di riempirla — con l'impronta.
                       *
                       * 🚨 **Il valore predefinito di `autofillHints` è
                       * `const <String>[]`, non `null`**, e la lista vuota
                       * significa «autofill acceso, indovina tu il tipo». Solo
                       * `null` lo spegne. È una trappola perfetta: il campo
                       * sembra non aver chiesto niente.
                       *
                       * 💡 Un codice palestra **non è** una credenziale
                       * personale: è la sigla che sta sul volantino della
                       * palestra. Non ha senso salvarlo in un gestore di
                       * password, e chiederlo dietro un'impronta prima ancora
                       * di sapere chi sia l'utente è il primo gesto che l'app
                       * fa vedere.
                       */
                      autofillHints: null,
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
                          : const Text('Continua con la palestra'),
                    ),

                    /*
                     * 🚨 **Due modi di entrare, con la stessa dignità** —
                     * difetto riferito il 13/08/2026.
                     *
                     * *«Il tasto "non ho un codice" è troppo poco visibile:
                     * devono essere modalità di accesso alternative, quindi
                     * devono avere la stessa dignità.»*
                     *
                     * ⚠️ Qui c'era un `TextButton` in fondo, con la
                     * motivazione che «la strada principale resta il codice».
                     * Era sbagliata: dopo F3 **non esiste più una strada
                     * principale**. Chi ha una palestra e chi non ce l'ha sono
                     * due pubblici, non un caso normale e un'eccezione — e un
                     * pubblico intero non deve cercare la propria porta in
                     * fondo alla pagina, scritto più piccolo.
                     *
                     * 💡 `OutlinedButton` e non un secondo `FilledButton`:
                     * stessa altezza, stessa larghezza, stesso peso nella
                     * gerarchia — ma due pulsanti pieni identici non direbbero
                     * *quale* dei due si è già cominciato a compilare, e il
                     * campo qui sopra riguarda solo il primo.
                     */
                    const SizedBox(height: Gap.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                          child: Text(
                            'oppure',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: Gap.lg),

                    OutlinedButton.icon(
                      onPressed: _inCorso ? null : _prosegui,
                      icon: const Icon(Icons.person_outline_rounded),
                      label: const Text('Continua senza palestra'),
                      style: OutlinedButton.styleFrom(
                        // 💡 L'altezza è quella di serie di `FilledButton`:
                        // pareggiarla è metà del «stessa dignità».
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    const SizedBox(height: Gap.sm),
                    Text(
                      'Ti alleni per conto tuo, o ti segue un trainer indipendente.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
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
