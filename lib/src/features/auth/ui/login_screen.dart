import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/branding_controller.dart';
import '../../onboarding/ui/widgets/marchio_in_cima.dart';
import '../auth_controller.dart';
import 'widgets/social_buttons.dart';

/// 🚬 **La rassicurazione per chi trova l'abbonamento sospeso.**
///
/// ⛔ Il giro UX del 23/09: sospesa la palestra e rifatto l'accesso, l'app
/// rispondeva con la sola riga del server, mentre la frase che conta — **che i
/// dati sono al sicuro** — la riceveva solo chi era già dentro. ⚠️ Cioè chi è
/// più in ansia non la vedeva.
///
/// ── 📦 Perché vive qui, dal 27/09/2026 ─────────────────────────────────
///
/// 🚨 Stava in `gym_inactive_screen.dart`, che è stato **cancellato**: quella
/// schermata a tutto schermo era irraggiungibile da quando, il 26/09, è stata
/// tolta la regola del router che ci portava — e diceva l'opposto di quello che
/// è stato deciso, cioè una porta chiusa invece dell'interfaccia dei non abbonati.
///
/// ⚠️ **Ma il file non era del tutto morto**: il widget sì, questa costante no.
/// 💡 È la lezione al rovescio — non basta chiedersi *«chi naviga qui?»*, va
/// chiesto anche *«cos'altro c'è dentro questo file?»*. L'ha trovato l'analisi
/// statica, in un secondo.
const rassicurazionePalestraSospesa =
    'Il tuo account e i tuoi dati sono al sicuro: torneranno disponibili '
    "appena l'abbonamento riprenderà. Nel frattempo resta tutto quello che è "
    'tuo: allenamenti, diario e progressi.';

/// L'accesso — A2.3.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.invito, this.diUnTrainer = false});

  /// 🆕 🔗 **Il token dell'invito da cui si sta arrivando** — 17/09/2026.
  ///
  /// 📌 Il committente: *«se ho già un account non ha senso essere rimandati
  /// alla registrazione»*. ⚠️ Chi riceve un invito può averlo già — telefono
  /// nuovo, app reinstallata, sessione scaduta — e deve poter **entrare**
  /// invece di crearne un secondo.
  ///
  /// 💡 Quando c'è, la schermata dice **perché** si sta accedendo e, finito,
  /// riporta all'invito invece che a casa.
  final String? invito;

  /// 🆕 🤝 **L'invito e' di un trainer, non di una palestra** — 17/09/2026.
  ///
  /// ⚠️ Sono due percorsi diversi (`/invito` e `/invito-palestra`) e tornarci
  /// sul quello sbagliato aprirebbe *«questo invito non e' piu' valido»* su un
  /// invito buono: un difetto che si legge come una scadenza.
  final bool diUnTrainer;

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

  /// Questo 422 dice «non ti riconosco», o dice qualcos'altro?
  ///
  /// 🚨 **Si guarda il messaggio del server, e non è bello ma è l'unica cosa
  /// che c'è**: `POST /auth/login` non manda un codice per distinguere i suoi
  /// rifiuti, manda solo la frase. ⚠️ Chi aggiunge un codice lato server tolga
  /// questo controllo, che è un ripiego.
  ///
  /// 💡 Il confronto è **sul testo del rifiuto per credenziali**, non su quello
  /// dell'account disattivato: se un giorno il server aggiungesse un terzo
  /// motivo, il ripiego lo mostrerebbe per esteso invece di mascherarlo da
  /// password sbagliata — che è la direzione giusta in cui sbagliare.
  bool _eSoloCredenziali(ValidationException errore) =>
      errore.message.toLowerCase().contains('credenziali');

  Future<void> _accedi() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _inCorso = true;
      _errore = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(login: _login.text, password: _password.text);

      /*
       * 🆕 🔗 **Chi arriva da un invito ci torna** — 17/09/2026.
       *
       * ⛔ Senza, il router lo porterebbe **a casa** e la palestra che l'aveva
       * invitato sparirebbe senza un errore.
       */
      if (widget.invito != null && mounted) {
        context.go(
          '${widget.diUnTrainer ? AppRoutes.invitoTrainer : AppRoutes.invito}'
          '/${widget.invito}',
        );

        return;
      }

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
        /*
         * ══ 🆕 L'ACCOUNT DISATTIVATO NON È UNA PASSWORD SBAGLIATA ════════════
         *
         * ⛔ **Qui c'era scritto che il messaggio unico vale anche per
         * l'account disattivato, «perché il backend risponde già allo stesso
         * modo apposta». Il backend non lo fa**: risponde *«Questo account non
         * è attivo.»*, e l'app la sostituiva con «email o password non
         * corretti» — cioè dava la colpa a chi aveva digitato tutto giusto.
         *
         * 🚨 Visto sull'emulatore il 15/09 disattivando l'account di prova.
         *
         * ⚖️ **E non è un buco**: quel ramo del server scatta **dopo**
         * `Hash::check`, quindi ci arriva solo chi la password ce l'ha giusta —
         * e chi ha la password sa già che l'account esiste. L'unicità del
         * messaggio serve contro chi **prova** indirizzi, e per quelli la
         * risposta resta la stessa di sempre.
         *
         * 💡 La regola diventa: credenziali sbagliate → messaggio unico; tutto
         * il resto → quello che dice il server, che è più preciso di quello che
         * l'app può inventarsi.
         */
        _errore = switch (tradotto) {
          ValidationException() when _eSoloCredenziali(tradotto) =>
            'Email, nome utente o password non corretti.',
          ValidationException() => tradotto.message,
          NetworkException() => tradotto.message,
          /*
           * ⚠️ **Anche qui si dice che i dati sono al sicuro** — 23/09/2026.
           *
           * ⛔ Prima si mostrava la sola riga del server. La rassicurazione
           * viveva soltanto in `GymInactiveScreen`, cioè la vedeva **solo chi
           * era già dentro** quando la palestra veniva sospesa — non chi sta
           * provando a entrare, che è chi se lo sta chiedendo davvero.
           *
           * 💡 Non si manda alla schermata dedicata: quella ha un pulsante
           * «Controlla di nuovo» che chiama `/auth/me`, e dopo un accesso
           * fallito **non c'è nessun token** — riporterebbe al login perdendo
           * la spiegazione. La spiegazione va dove la persona può agire.
           */
          GymInactiveException() =>
            '${tradotto.message}\n\n$rassicurazionePalestraSospesa',
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
                    MarchioInCima(branding: branding),

                    /*
                     * 🆕 🔗 **Perché sei qui** — 17/09/2026.
                     *
                     * 📌 Il committente: *«un pannello di accesso con tipo un
                     * toast o qualcosa del genere»*.
                     *
                     * ⚠️ **Una riga e non un toast**, e la differenza conta: un
                     * toast dura tre secondi e chi sta cercando la password non
                     * lo legge. 💡 Questa resta finché serve, e sparisce da sola
                     * per chi arriva da un accesso normale.
                     */
                    if (widget.invito != null) ...[
                      const SizedBox(height: Gap.md),
                      Text(
                        "Accedi per accettare l'invito: appena entri te lo "
                        'ritrovi qui.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],

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
                      /*
                       * 🆕 🔗 **E l'invito si porta dietro anche di qua** —
                       * 17/09/2026. ⚠️ Chi scopre qui di non avere un account non
                       * deve perdere la palestra che l'ha invitato.
                       */
                      onPressed: () => context.go(
                        widget.invito == null
                            ? AppRoutes.register
                            : widget.diUnTrainer
                            ? AppRoutes.registratiPerInvitoTrainer(
                                widget.invito!,
                              )
                            : AppRoutes.registratiPerInvito(widget.invito!),
                      ),
                      child: const Text('Non ho ancora un account'),
                    ),

                    /*
                     * ══ ⛔ QUI C'ERA «CAMBIA PALESTRA» — tolto il 27/08/2026 ═══
                     *
                     * 📌 *«Nella schermata di accesso non devi proprio parlare
                     * di palestre. Se c'è una palestra, l'utente lo saprà»*.
                     *
                     * ⚠️ Il pulsante aveva un senso quando il codice palestra si
                     * digitava **prima** del login: era la via d'uscita di chi
                     * aveva sbagliato codice. 🚨 Da 3b-J.1 non c'è più niente da
                     * sbagliare prima di entrare — la palestra si aggiunge dopo,
                     * dal profilo — e quel pulsante era rimasto a nominare una
                     * cosa che qui non esiste.
                     *
                     * 💡 Chi è iscritto a una palestra **lo sa già**: è la
                     * palestra che gli ha dato il codice. Ricordarglielo mentre
                     * digita la password è rumore, e a chi una palestra non ce
                     * l'ha fa credere di doverne avere una.
                     */
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
