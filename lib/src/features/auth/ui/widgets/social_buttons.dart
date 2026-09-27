import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth_controller.dart';
import '../../data/accesso_social_vero.dart';
import '../../data/fornitori_social.dart';
import '../../data/social_sign_in.dart';
import 'le_dichiarazioni.dart';

/// «Accedi con Google» / «Accedi con Apple» — C17.
///
/// 🚨 **Non disegna niente finché il server non dichiara il fornitore.**
/// `GymBranding.social` arriva dal backend ed è vuoto finché mancano le
/// credenziali: un pulsante che risponde sempre errore fa sembrare rotta tutta
/// l'applicazione, non solo quel pulsante. È anche il motivo per cui la
/// disponibilità non è una costante dentro l'app — cambiarla richiederebbe una
/// 🎨 Il marchio «G» di Google.
///
/// ⚠️ Vive in una costante e non scritto a mano nel widget perché lo nomina
/// anche il test che ne pretende l'esistenza: ⛔ due stringhe uguali scritte in
/// due posti divergono, e il giorno che divergono il test passa mentre l'app
/// mostra il ripiego.
const marchioGoogle = 'assets/marchio/google_g.png';

/// pubblicazione sugli store.
class SocialButtons extends ConsumerStatefulWidget {
  const SocialButtons({this.dichiarazioniDate = true, super.key});

  /// 🚨 S9.2 — se questa schermata **iscrive**, le due caselle valgono anche
  /// qui: chi entra con Google si iscrive esattamente come chi compila il
  /// modulo.
  ///
  /// ⚠️ Il valore di serie è `true` perché sulla schermata di **accesso** non
  /// c'è niente da dichiarare — lì non nasce nessun account. È la schermata di
  /// registrazione che lo mette a `false` finché le caselle non sono spuntate.
  final bool dichiarazioniDate;

  @override
  ConsumerState<SocialButtons> createState() => _SocialButtonsState();
}

class _SocialButtonsState extends ConsumerState<SocialButtons> {
  String? _inCorso;
  String? _errore;

  /// 🆕 Il token del primo tentativo, tenuto per il secondo.
  ///
  /// ⚠️ Vive quanto la schermata e non viene mai mandato altrove: serve solo a
  /// non far scegliere l'account due volte quando il server chiede le
  /// dichiarazioni.
  SocialCredential? _ultimaCredenziale;

  Future<void> _accedi(String provider) async {
    setState(() {
      _inCorso = provider;
      _errore = null;
    });

    try {
      /*
       * 🆕 🔁 **Il token si ottiene QUI, una volta sola** — voce 25, 26/09.
       *
       * ⛔ Non dentro `loginWithSocial`: se il server chiede le dichiarazioni
       * bisogna riprovare, e riprovare riaprendo la finestra di Google
       * farebbe scegliere l'account **due volte** per una cosa sola.
       */
      final credenziale = await SocialSignIn.instance.accedi(provider);

      // 🚨 Ha annullato. Non è un errore e non va mostrato come tale.
      if (credenziale == null) return;

      _ultimaCredenziale = credenziale;

      // ⛔ F11 — niente più codice palestra: al primo accesso il server collega
      // l'identità all'account con la stessa email verificata.
      await _mandaAlServer(provider, credenziale, widget.dichiarazioniDate);
    } on ConsensiRichiestiException {
      /*
       * 🆕 ⚖️ **È un primo accesso: si iscrive** — decisione del committente,
       * 26/09/2026, fra tre strade possibili: *«chiedile solo se servono
       * davvero»*.
       *
       * 🔑 Non si potevano chiedere prima: su questa schermata **nessuno sa**
       * se la persona sta entrando o si sta iscrivendo — è la domanda a cui
       * la schermata serve a rispondere. ⛔ Farle spuntare a tutti vorrebbe
       * dire chiederle anche a chi sta solo rientrando nel proprio account.
       *
       * ⚠️ Il consenso resta **esplicito**: due caselle, non un «continuando
       * accetti». Vale l'art. 7 GDPR e vale S9.2.
       */
      await _chiediLeDichiarazioniERiprova(provider);
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      setState(() => _errore = tradotto.message);
    } finally {
      if (mounted) setState(() => _inCorso = null);
    }
  }

  Future<void> _mandaAlServer(
    String provider,
    SocialCredential credenziale,
    bool dichiarazioni,
  ) => ref
      .read(authControllerProvider.notifier)
      .loginWithSocial(
        provider,
        maggiorenne: dichiarazioni,
        condizioniAccettate: dichiarazioni,
        credenzialeGiaOttenuta: credenziale,
      );

  /// Apre le due caselle e, se vengono spuntate, **riprova col token che si ha
  /// già**.
  ///
  /// ⚠️ Se la persona chiude senza spuntare non succede niente e non compare
  /// nessun errore: ha cambiato idea, e non ha sbagliato niente.
  Future<void> _chiediLeDichiarazioniERiprova(String provider) async {
    final credenziale = _ultimaCredenziale;

    if (credenziale == null || !mounted) return;

    final accettate = await mostraLeDichiarazioni(context, provider);

    if (accettate != true || !mounted) return;

    setState(() {
      _inCorso = provider;
      _errore = null;
    });

    try {
      await _mandaAlServer(provider, credenziale, true);
    } on Object catch (error) {
      final tradotto = ApiClient.unwrapError(error);

      if (mounted) setState(() => _errore = tradotto.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /*
     * 🆕 ⚖️ **Due condizioni, non una** — voce 25, 26/09/2026.
     *
     * 1. il **server** deve dichiarare il fornitore;
     * 2. la **piattaforma** deve saperlo fare davvero.
     *
     * 🚨 La seconda serviva e non c'era. 📌 Il committente, 26/09: *«Apple solo
     * su iOS»*. ⛔ Ma il server dichiara i fornitori **una volta per tutti**,
     * senza sapere da che telefono arriva la richiesta: con Apple acceso lato
     * server, il pulsante sarebbe comparso **anche su Android**, dove l'accesso
     * nativo con Apple non esiste. 💡 Un pulsante che non può funzionare è
     * peggio di un pulsante assente.
     *
     * ══ 🚨 E LA PRIMA ARRIVA DA UNA ROTTA PUBBLICA, NON DAL BRANDING ════════
     *
     * ⛔ Prima si leggeva `GymBranding.social`, che arriva **con l'accesso**:
     * chi apriva l'app per la prima volta aveva `neutral`, con l'elenco vuoto,
     * e i pulsanti non comparivano **mai** — cioè proprio a chi servivano.
     * 💡 Ora la domanda ha una rotta sua, pubblica (`fornitoriSocialProvider`).
     */
    final dalServer = ref
        .watch(fornitoriSocialProvider)
        .maybeWhen(data: (f) => f, orElse: () => const <String>[]);

    final disponibili = dalServer
        .where(
          (p) => fornitoreUsabileQui(
            p,
            sistemaApple: AccessoSocialVero.supportaApple,
          ),
        )
        .toList(growable: false);

    if (disponibili.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Gap.lg),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              child: Text('oppure', style: theme.textTheme.bodySmall),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: Gap.md),

        for (final provider in disponibili) ...[
          /*
           * 🆕 🎨 **Ogni fornitore col proprio colore** — 26/09/2026.
           *
           * 📌 Il committente: *«il tasto continua con google deve essere di
           * colore rosso google e avere l'icona della g di google. Idem per
           * quello della apple, deve essere grigio scuro apple e avere la
           * mela»*.
           *
           * ⚠️ **Apple è conforme**: il nero è uno degli stili che Apple
           * ammette per «Accedi con Apple», e la mela è in Material
           * (`Icons.apple`). ⛔ Apple **respinge** le app il cui pulsante non
           * segue la sua specifica, quindi qui non si improvvisa.
           *
           * 🔄 **GOOGLE È CAMBIATO il 27/09/2026, e il rosso è andato via.**
           *
           * ⛔ Il rosso **non è uno stile ufficiale di Google** (i suoi sono
           * bianco, grigio neutro o nero). ⚠️ Finché dentro c'era una lettera
           * disegnata da noi era solo una scelta estetica; **col marchio vero
           * sopra diventa un uso non conforme**, ed è il genere di cosa che si
           * scopre a revisione dello store già avviata.
           *
           * ⚖️ Scelto dal committente fra i tre stili ammessi: **bianco con
           * bordo grigio**, che è quello che Google mette per primo.
           *
           * 🚨 E la «G» **non si ridisegna**: è il marchio ufficiale, incollato
           * dal loro snippet in `assets/marchio/google_g.svg` e rasterizzato da
           * `memory/scripts/fai-la-g-di-google.sh`.
           */
          FilledButton.icon(
            onPressed: _inCorso != null || !widget.dichiarazioniDate
                ? null
                : () => _accedi(provider),
            style: FilledButton.styleFrom(
              backgroundColor: _sfondo(provider),
              foregroundColor: _inchiostro(provider),
              minimumSize: const Size.fromHeight(48),

              /*
               * ⚠️ **Il bordo serve solo al bianco**, e non è decorazione: senza,
               * su uno sfondo chiaro il pulsante sparisce. 💡 È anche il motivo
               * per cui Google, nel suo stile chiaro, lo prescrive.
               */
              side: _bordo(provider),
            ),
            icon: _inCorso == provider
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      // ⚠️ Bianca su un pulsante bianco non si vedrebbe.
                      color: _inchiostro(provider),
                    ),
                  )
                : _segno(provider),
            label: Text('Continua con ${SocialProviderId.etichetta(provider)}'),
          ),
          const SizedBox(height: Gap.sm),
        ],

        if (_errore != null)
          Padding(
            padding: const EdgeInsets.only(top: Gap.xs),
            child: Text(
              _errore!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }

  /// ⚠️ Icone di sistema, non i marchi.
  ///
  /// I loghi di Google e Apple hanno regole d'uso precise (dimensioni, spazi,
  /// colori, sfondo) e vanno inclusi come immagini fornite da loro. Metterne una
  /// versione approssimata è il genere di cosa che fa **rifiutare la
  /// pubblicazione** — quindi finché non ci sono gli asset ufficiali, meglio
  /// un'icona neutra che una imitazione.
  /// 🎨 Il colore di sfondo del pulsante, per fornitore.
  ///
  /// ⚠️ **Apple `#1A1A1A`**: il nero è uno degli stili che Apple ammette, e
  /// discostarsene è motivo di rifiuto della pubblicazione.
  ///
  /// 🔄 **Google: bianco, dal 27/09/2026.** ⛔ Era `#DB4437`, il rosso del
  /// marchio, chiesto dal committente il 26/09 — ma il rosso **non è fra gli
  /// stili che Google ammette**, e col marchio vero sopra sarebbe un uso non
  /// conforme. ⚖️ Scelto il bianco con bordo, che è il primo dei suoi.
  Color _sfondo(String provider) => switch (provider) {
    SocialProviderId.apple => const Color(0xFF1A1A1A),
    SocialProviderId.google => Colors.white,
    _ => Theme.of(context).colorScheme.primary,
  };

  /// 🖋️ Il colore del testo.
  ///
  /// ⚠️ **Google `#1F1F1F`**, non nero pieno: è il grigio scurissimo che le sue
  /// linee guida indicano per il pulsante chiaro.
  Color _inchiostro(String provider) => switch (provider) {
    SocialProviderId.google => const Color(0xFF1F1F1F),
    _ => Colors.white,
  };

  /// 🔲 Il bordo: **solo** per il pulsante chiaro di Google.
  ///
  /// ⛔ `null` per gli altri, che hanno lo sfondo scuro e si vedono da soli.
  BorderSide? _bordo(String provider) => provider == SocialProviderId.google
      ? const BorderSide(color: Color(0xFFDADCE0))
      : null;

  /// Il segno dentro il pulsante.
  ///
  /// 🍎 Apple ha la sua mela in Material (`Icons.apple`), ed è quella giusta.
  ///
  /// 🎨 **Google: il marchio ufficiale**, da `assets/marchio/google_g.png`.
  /// ⛔ Non è ridisegnato: i tracciati vengono dallo snippet che Google pubblica
  /// (`google_g.svg`), rasterizzati da `memory/scripts/fai-la-g-di-google.sh`.
  Widget _segno(String provider) => switch (provider) {
    SocialProviderId.apple => const Icon(Icons.apple, size: 22),
    SocialProviderId.google => Image.asset(
      marchioGoogle,
      width: 20,
      height: 20,

      /*
       * 🚨 **La rete di sicurezza, e il test che la rende inutile.**
       *
       * ⛔ Se il file mancasse, `Image.asset` lancerebbe **a schermo**: la
       * persona vedrebbe una schermata di accesso rotta al posto di un pulsante
       * un po' più brutto. 💡 Qui invece ricompare la lettera di prima.
       *
       * ⚠️ Ma una rete che salva in silenzio è la cosa che questo progetto ha
       * già pagato troppe volte: per questo c'è
       * `test/marchio_di_google_test.dart`, che diventa **rosso** se l'asset non
       * c'è o non è dichiarato. 🔑 La rete evita lo schianto; il test evita che
       * ce ne dimentichiamo.
       */
      errorBuilder: (_, _, _) => const _LetteraDiRipiego(),
    ),
    _ => const Icon(Icons.account_circle_outlined, size: 22),
  };
}

/// 🔤 Il ripiego: **non è il marchio**, ed è dichiarato.
///
/// ⛔ Si vede solo se `assets/marchio/google_g.png` manca. 💡 Deliberatamente
/// una lettera e non un disegno somigliante: una «G» approssimata sarebbe una
/// **imitazione del marchio**, e quella sì che fa rifiutare la pubblicazione.
class _LetteraDiRipiego extends StatelessWidget {
  const _LetteraDiRipiego();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 20,
    height: 20,
    child: Center(
      child: Text(
        'G',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1F1F1F),
          height: 1,
        ),
      ),
    ),
  );
}
