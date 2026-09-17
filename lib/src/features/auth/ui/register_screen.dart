import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/branding_controller.dart';
import '../../onboarding/ui/widgets/marchio_in_cima.dart';
import '../auth_controller.dart';
import '../data/password_strength.dart';
import 'widgets/password_meter.dart';
import 'widgets/social_buttons.dart';

/// L'iscrizione — A2.3.
///
/// ══ ⛔ IL CODICE PALESTRA NON SI CHIEDE, E DA 3b-J.1 NON C'È PROPRIO ══════
///
/// 📌 *«al primo accesso, rimuovi l'opzione di registrarsi con una palestra …
/// per accedere con una palestra si farà dopo che l'utente si è già
/// registrato»*.
///
/// ⚠️ **Qui c'era scritto che il codice «è già stato inserito nella schermata
/// precedente»**, ed era vero fino al 27/08/2026: la prima schermata lo
/// chiedeva. Adesso la prima schermata è `SchermataBenvenuto` — accedi o
/// registrati — e in palestra si entra **dopo**, da Profilo › Entra in una
/// palestra.
///
/// 💡 Quindi ci si registra sempre **senza palestra**, e il server la sa
/// gestire: fa nascere un tenant personale.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key, this.invito});

  /// 🆕 🔗 **Il token dell'invito da cui si sta arrivando** — 17/09/2026.
  ///
  /// 📌 Il committente ha scelto *«due passi, ma detti chiari»*: chi riceve un
  /// invito e non ha un account si registra, e **torna all'invito** invece di
  /// ritrovarsi a casa senza sapere che fine abbia fatto la palestra.
  ///
  /// ⚠️ `null` per chi si registra normalmente, e in quel caso non cambia
  /// niente.
  final String? invito;

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _conferma = TextEditingController();

  /// Il nome utente si propone dal nome, ma **smette** appena l'utente lo
  /// tocca: continuare a sovrascriverlo mentre corregge il cognome sarebbe il
  /// modo più rapido per fargli odiare il modulo.
  bool _usernameToccato = false;

  /// La robustezza, ricalcolata a ogni tasto.
  ///
  /// Sta nello stato e non dentro il `build` perché serve anche al `validator`,
  /// che deve poter rifiutare l'invio senza rifare il conto.
  PasswordStrength _forza = const PasswordStrength(
    score: 0,
    level: PasswordLevel.inesistente,
    suggerimenti: [],
  );

  /// 🚨 Le due password si vedono in chiaro insieme, o non si vedono affatto.
  ///
  /// Mostrarne una sola renderebbe il secondo campo un test di battitura alla
  /// cieca su qualcosa che si è appena letto: chi si accorge di un errore di
  /// digitazione nel primo campo deve poter controllare **entrambi**.
  bool _nascondi = true;

  bool _inCorso = false;

  /// 🚨 S9.2 — la dichiarazione di maggiore età, e le condizioni d'uso.
  ///
  /// ⚠️ **Partono da `false` e non si possono spuntare in blocco.** Sono due
  /// caselle separate perché sono due cose diverse: una è un'affermazione su di
  /// sé, l'altra è l'accettazione di un contratto.
  ///
  /// 💡 Le funzioni facoltative — dati sanitari, invio del diario all'AI —
  /// **non stanno qui**: si concedono dopo, dal profilo. Un consenso richiesto
  /// per potersi iscrivere non è «liberamente dato» (art. 7(4) GDPR), e quindi
  /// non è consenso.
  bool _maggiorenne = false;

  bool _condizioni = false;

  bool get _dichiarazioniComplete => _maggiorenne && _condizioni;
  String? _errore;
  Map<String, List<String>> _erroriCampo = const {};

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _conferma.dispose();
    super.dispose();
  }

  /// Ricalcola la robustezza tenendo conto dei dati personali già digitati.
  ///
  /// ⚠️ Va richiamata anche quando cambiano **nome, email e nome utente**, non
  /// solo la password: chi scrive prima la password e poi il nome creerebbe
  /// altrimenti «riccardo1234» senza che nessuno glielo dica più.
  void _ricalcolaForza() {
    setState(() {
      _forza = PasswordStrength.valuta(
        _password.text,
        nome: _nome.text,
        email: _email.text,
        username: _username.text,
      );
    });
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

    _username.text = proposta.length > 30
        ? proposta.substring(0, 30)
        : proposta;
  }

  Future<void> _registrati() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    /*
     * 🆕 **Il codice può non esserci, e non è più un errore** — F3.
     *
     * Qui c'era un blocco che rifiutava l'iscrizione con «Manca il codice della
     * palestra», ed era giusto finché ogni utente doveva appartenere a una: chi
     * arrivava senza codice ci era arrivato per sbaglio.
     *
     * ⚠️ Da F3 «nessun codice» era una scelta esplicita — il pulsante «continuo
     * senza palestra» della schermata precedente — e il server la sa gestire:
     * fa nascere un tenant personale.
     *
     * ⛔ **Da 3b-J.1 non è più nemmeno una scelta: è l'unica strada.** Nessuno
     * scrive più `joinCode`, quindi qui vale sempre `null`.
     *
     * 🚨 **La riga resta**, e non è codice morto per sbaglio: è il punto in cui
     * un domani si riattacca un invito che arriva da fuori — un link, un QR
     * sul volantino della palestra. 💡 Toglierla vorrebbe dire dover ritrovare
     * *tutti e tre* i punti che lo mandano al server (accesso, iscrizione,
     * social) invece di riempirne uno solo.
     */
    final code = ref.read(brandingControllerProvider).joinCode;

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
            passwordConfirmation: _conferma.text,
            maggiorenne: _maggiorenne,
            condizioniAccettate: _condizioni,
          );

      /*
       * 🆕 🔗 **Chi arriva da un invito ci torna** — 17/09/2026.
       *
       * ⛔ Senza questo, finita l'iscrizione la regola 7 del router lo
       * porterebbe **a casa**: la palestra che l'aveva invitato sparirebbe
       * senza un errore, e quella persona non saprebbe nemmeno cosa ha
       * sbagliato. 💡 E' il secondo dei «due passi detti chiari».
       *
       * ⚠️ `mounted` prima di toccare il contesto: fra la chiamata al server e
       * questa riga c'e' una rete di mezzo.
       */
      if (widget.invito != null && mounted) {
        context.go('${AppRoutes.invito}/${widget.invito}');

        return;
      }
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

  /*
   * ══ 🆕 I DUE DOCUMENTI SI APRONO DAVVERO — 14/09/2026 ════════════════════
   *
   * 📌 Il committente, dopo il giro sull'emulatore: *«Mettici il link»*.
   *
   * ⛔ **Prima la casella nominava due documenti e non ne apriva nessuno.**
   * Chiedere di accettare un testo che non si può leggere non è un consenso:
   * è una formalità, e per giunta una che non regge se qualcuno la contesta.
   *
   * 💡 **Si aprono nel browser, non dentro l'app.** Il sito li serve già
   * (`/privacy` e `/condizioni`, `routes/web.php`), sono impaginati, e
   * cambiano senza dover pubblicare una versione nuova dell'app.
   */
  TextStyle? _stileLink(ThemeData tema) => tema.textTheme.bodyMedium?.copyWith(
    color: tema.colorScheme.primary,
    decoration: TextDecoration.underline,
    decorationColor: tema.colorScheme.primary,
  );

  /// Apre `/privacy` o `/condizioni` del sito.
  ///
  /// ══ ⚠️ L'INDIRIZZO SI RICAVA, NON SI SCRIVE ══════════════════════════════
  ///
  /// 🚨 Si toglie `/api/v1` dall'indirizzo dell'API. ⛔ Una costante col
  /// dominio vero manderebbe **anche le build locali** sul sito pubblicato: lo
  /// sviluppo gira su `10.0.2.2`, lo staging su `training.riccardoronconi.it`,
  /// e i documenti non sono gli stessi mentre si lavora a un testo nuovo.
  ///
  /// 💡 Se il browser non parte lo si dice: un tocco che non fa niente lascia
  /// pensare che il documento non esista.
  Future<void> _apriDocumento(String quale) async {
    final api = ref.read(appConfigProvider).apiBaseUrl;
    final sito = api.replaceFirst(RegExp(r'/api/v\d+/?$'), '');
    final indirizzo = '$sito/$quale';

    final url = Uri.tryParse(indirizzo);
    final aperto =
        url != null &&
        await launchUrl(url, mode: LaunchMode.externalApplication);

    if (!aperto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Non sono riuscito ad aprire $indirizzo")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branding = ref.watch(brandingControllerProvider).branding;

    return Scaffold(
      /*
       * ⛔ **QUI RESTA UN'`AppBar`, E NON E' UNA DIMENTICANZA** — 3b-O.1a.6.
       *
       * L'intestazione condivisa ([IntestazioneApp]) e' andata su tutte le
       * pagine dell'app tranne quattro, e questa e' una di quelle.
       *
       * 🚨 **Qui non c'e' ancora un utente.** L'intestazione condivisa mostra
       * il saldo dei gettoni e l'avatar del profilo: entrambi vogliono una
       * sessione, e prima della registrazione non esiste. Ne uscirebbe una
       * barra con il nome dell'app e due buchi.
       */
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
                    MarchioInCima(branding: branding),
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
                      onChanged: (v) {
                        _proponiUsername(v);
                        // Il nome entra nel giudizio della password: chi scrive
                        // prima la password e poi il nome creerebbe altrimenti
                        // «riccardo1234» senza che nessuno glielo dica più.
                        _ricalcolaForza();
                      },
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
                        /*
                         * 🆕 **La busta, non la chiocciola** — 14/09/2026.
                         *
                         * ⛔ Email e «Nome utente» avevano tutti e due
                         * `alternate_email`: due campi diversi con lo stesso
                         * segno, uno sopra l'altro. 🚨 In un modulo di cinque
                         * campi l'icona è l'unica cosa che si guarda scorrendo,
                         * e due uguali dicono «hai già compilato questo».
                         */
                        prefixIcon: const Icon(Icons.mail_outline_rounded),
                        errorText: _erroriCampo['email']?.first,
                      ),
                      onChanged: (_) => _ricalcolaForza(),
                      validator: (v) {
                        final value = (v ?? '').trim();

                        if (value.isEmpty) return 'Serve la tua email.';

                        // Controllo volutamente lasco: la validazione vera è
                        // del backend, e una regex severa qui rifiuterebbe
                        // indirizzi legittimi che il server accetta.
                        return value.contains('@')
                            ? null
                            : 'Non sembra un\'email.';
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
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z0-9._\-]'),
                        ),
                        TextInputFormatter.withFunction(
                          (_, nuovo) =>
                              nuovo.copyWith(text: nuovo.text.toLowerCase()),
                        ),
                      ],
                      maxLength: 30,
                      decoration: InputDecoration(
                        labelText: 'Nome utente',
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                        helperText:
                            'Ti servirà per accedere, al posto dell\'email.',
                        counterText: '',
                        errorText: _erroriCampo['username']?.first,
                      ),
                      onChanged: (_) {
                        _usernameToccato = true;
                        _ricalcolaForza();
                      },
                      validator: (v) {
                        final value = (v ?? '').trim();

                        if (value.length < 3) return 'Almeno 3 caratteri.';

                        // Deve cominciare e finire con lettera o numero: un
                        // nome utente che finisce con un punto confonde chi lo
                        // legge ad alta voce al telefono.
                        return RegExp(
                              r'^[a-z0-9](?:[a-z0-9._\-]*[a-z0-9])?$',
                            ).hasMatch(value)
                            ? null
                            : 'Lettere, numeri, punto, trattino e trattino basso.';
                      },
                    ),
                    const SizedBox(height: Gap.md),

                    TextFormField(
                      controller: _password,
                      obscureText: _nascondi,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        helperText:
                            'Almeno ${PasswordStrength.lunghezzaMinima} '
                            'caratteri, con lettere e numeri.',
                        errorText: _erroriCampo['password']?.first,
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _nascondi = !_nascondi),
                          icon: Icon(
                            _nascondi
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _nascondi ? 'Mostra' : 'Nascondi',
                        ),
                      ),
                      onChanged: (_) => _ricalcolaForza(),
                      validator: (v) {
                        final value = v ?? '';

                        if (value.length < PasswordStrength.lunghezzaMinima) {
                          return 'Almeno ${PasswordStrength.lunghezzaMinima} caratteri.';
                        }

                        // 🚨 Si blocca sul **giudizio**, non solo sulla
                        // lunghezza: sotto questa soglia il backend risponde
                        // 422 comunque, e far premere il pulsante per fallire
                        // dopo un giro di rete è solo un modo più lento di dire
                        // la stessa cosa.
                        return _forza.accettabile
                            ? null
                            : 'Troppo debole: segui il consiglio qui sotto.';
                      },
                    ),

                    PasswordMeter(forza: _forza),
                    const SizedBox(height: Gap.md),

                    TextFormField(
                      controller: _conferma,
                      obscureText: _nascondi,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'Ripeti la password',
                        prefixIcon: const Icon(Icons.lock_reset_rounded),
                        // ⚠️ La spunta compare solo quando **combaciano e non
                        // sono vuote**: un segno di conferma su due campi vuoti
                        // è una bugia rassicurante.
                        suffixIcon:
                            _conferma.text.isNotEmpty &&
                                _conferma.text == _password.text
                            ? Icon(
                                Icons.check_circle_outline_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if ((v ?? '').isEmpty) return 'Riscrivi la password.';

                        return v == _password.text
                            ? null
                            : 'Le due password non coincidono.';
                      },
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

                    const SizedBox(height: Gap.md),
                    CheckboxListTile(
                      value: _maggiorenne,
                      onChanged: (v) =>
                          setState(() => _maggiorenne = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text('Dichiaro di avere almeno 18 anni.'),
                    ),
                    CheckboxListTile(
                      value: _condizioni,
                      onChanged: (v) =>
                          setState(() => _condizioni = v ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      /*
                       * ══ 🆕 I DUE DOCUMENTI SONO LINK — 14/09/2026 ════════
                       *
                       * ⛔ Qui c'era una frase e basta: *«ho letto
                       * l'informativa sulla privacy»* **senza niente da
                       * leggere**. ⚖️ È la spunta su cui poggia il consenso, e
                       * chiedere di dichiarare di aver letto un documento che
                       * non si può aprire non è una svista di grafica.
                       *
                       * ⚠️ **Si aprono nel browser, non dentro l'app**: sono le
                       * stesse pagine che il sito pubblica, e una copia dentro
                       * l'app sarebbe un secondo testo da tenere allineato —
                       * cioè due versioni dello stesso impegno.
                       */
                      title: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Accetto le '),
                            TextSpan(
                              text: 'condizioni d\'uso',
                              style: _stileLink(theme),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _apriDocumento('condizioni'),
                            ),
                            const TextSpan(text: ' e ho letto l\''),
                            TextSpan(
                              text: 'informativa sulla privacy',
                              style: _stileLink(theme),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => _apriDocumento('privacy'),
                            ),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: Gap.lg),
                    FilledButton(
                      onPressed: _inCorso || !_dichiarazioniComplete
                          ? null
                          : _registrati,
                      child: _inCorso
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Crea account'),
                    ),

                    // Sull'iscrizione servono quanto sull'accesso: con Google o
                    // Apple non c'è nessun modulo da compilare, ed è il motivo
                    // principale per cui la gente li usa.
                    //
                    // 🚨 **Le due caselle valgono anche per loro.** Chi entra
                    // con Google si iscrive esattamente come chi compila il
                    // modulo: lasciare la strada social scoperta vorrebbe dire
                    // che lo sbarramento non c'è per metà delle persone — e
                    // nella Parte B, con i *free user*, sarà la maggioranza.
                    SocialButtons(dichiarazioniDate: _dichiarazioniComplete),
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
