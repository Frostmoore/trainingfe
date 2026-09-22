import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/states.dart';
import '../../auth/auth_controller.dart';
import '../../trainer/ui/scelta_dello_slot_al_rientro.dart';
import '../branding_controller.dart';
import '../data/invito_in_palestra.dart';
import '../invito_controller.dart';

/// La pagina che si apre toccando un link d'invito — 3b-V.2.5.
///
/// ══ 📌 LA RICHIESTA, PUNTO PER PUNTO ══════════════════════════════════════
///
/// *«a chi ci clicca si deve aprire l'app in una pagina con la descrizione della
/// palestra, il logo, i colori, un messaggio di congratulazioni, le cose a cui
/// avrà accesso e due tasti, uno per accettare e uno per rifiutare»*.
///
/// | Chiesto | Dove sta |
/// |---|---|
/// | il logo | [_Intestazione] |
/// | i colori | 🚨 tutta la pagina, vedi sotto |
/// | congratulazioni | [_Intestazione] |
/// | la descrizione | [_Intestazione] |
/// | le cose a cui avrà accesso | [_CosaOttieni] — **le manda il server** |
/// | due tasti | [_DueTasti] |
///
/// ══ 🚨 I COLORI SONO QUELLI DELLA PALESTRA, NON QUELLI DELL'APP ═══════════
///
/// ⚠️ È l'unico momento in cui questa cosa è vera **prima** di entrarci: la
/// palestra si sta presentando, e presentarsi coi colori di qualcun altro è il
/// contrario di quello che serve. 💡 Il tema si costruisce qui, sopra la
/// schermata, e vale solo per questa pagina.
///
/// ══ ⛔ E NON SI ENTRA PER SBAGLIO ═════════════════════════════════════════
///
/// Il tasto che accetta **sposta una persona dentro un'organizzazione**, e da
/// lì si esce solo parlando con loro. 🚨 Per questo non c'è nessun gesto rapido,
/// nessuno scorrimento, nessun «tocca per continuare»: due tasti dichiarati, e
/// quello che accetta chiede conferma.
class SchermataInvito extends ConsumerWidget {
  const SchermataInvito({required this.token, super.key});

  final String token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invito = ref.watch(invitoProvider(token));

    return invito.when(
      loading: () => const Scaffold(body: LoadingState()),

      /*
       * ⛔ **Un invito non valido non dice PERCHÉ**, e qui l'app non potrebbe
       * saperlo nemmeno volendo: il server risponde lo stesso 404 a scaduto,
       * revocato, già usato e mai esistito, apposta — distinguerli darebbe a
       * chiunque un modo di sapere quali token sono buoni.
       *
       * 💡 Quindi si dice l'unica cosa vera e utile: chiedine un altro.
       */
      /*
       * ⚠️ **Niente intestazione, nemmeno qui.** `IntestazioneApp` porta i
       * colori della palestra, il saldo dei gettoni e il profilo: tre cose che
       * non esistono per chi sta guardando un invito e non è ancora nessuno.
       * 💡 La via d'uscita è il tasto, che basta.
       */
      error: (e, _) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: EmptyState(
            icon: Icons.link_off_rounded,
            title: 'Questo invito non è più valido',
            message:
                'Può essere scaduto, o già usato da qualcun altro. '
                'Chiedine uno nuovo alla palestra.',
            action: FilledButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Va bene'),
            ),
          ),
        ),
      ),

      data: (dati) => _Pagina(token: token, invito: dati),
    );
  }
}

class _Pagina extends ConsumerStatefulWidget {
  const _Pagina({required this.token, required this.invito});

  final String token;
  final InvitoInPalestra invito;

  @override
  ConsumerState<_Pagina> createState() => _PaginaState();
}

class _PaginaState extends ConsumerState<_Pagina> {
  bool _inCorso = false;

  @override
  Widget build(BuildContext context) {
    final marchio = widget.invito.palestra;

    /*
     * 🚨 **Il tema della PALESTRA, per questa pagina sola.**
     *
     * ⚠️ Non si tocca il tema dell'app: se la persona rifiuta — o l'invito non
     * va a buon fine — l'app deve restare com'era. Cambiare il tema globale per
     * mostrare un'anteprima vorrebbe dire vestirsi dei colori di una palestra
     * in cui non si è entrati.
     */
    final tema = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.dark(marchio)
        : AppTheme.light(marchio);

    return Theme(
      data: tema,
      child: Scaffold(
        backgroundColor: tema.colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(Gap.lg),
                  children: [
                    _Intestazione(invito: widget.invito),
                    const SizedBox(height: Gap.lg),
                    _CosaOttieni(righe: widget.invito.cosaOttieni),
                  ],
                ),
              ),

              _DueTasti(
                inCorso: _inCorso,
                nome: marchio.name,
                /*
                 * 🆕 🚨 **Senza un account non si entra, e va detto PRIMA**
                 * — 17/09/2026.
                 *
                 * ⛔ Fino al 16/09 il tasto diceva «Entro in Palestra Demo» a
                 * chiunque. Chi non aveva un account lo premeva, la richiesta
                 * partiva senza sessione, e tornava un errore tecnico: un
                 * vicolo cieco, e per la persona che l'invito esiste per
                 * raggiungere. 🔬 Provato sull'emulatore con i dati puliti.
                 *
                 * 📌 Il committente: *«due passi, ma detti chiari»*.
                 */
                serveUnAccount: !ref.watch(sessioneAttivaProvider),
                onAccetta: _accetta,
                /*
                 * 🆕 🔑 **All'accesso, non alla registrazione** — 17/09/2026.
                 *
                 * 📌 Il committente: *«e se sono su un telefono nuovo o
                 * semplicemente non ho fatto il login? Non mi deve mandare per
                 * forza alla registrazione»*.
                 *
                 * ⚠️ È il caso che il primo giro aveva dimenticato: chi riceve un
                 * invito **può avere già un account**. Mandarlo a registrarsi gli
                 * fa creare un secondo account, oppure lo blocca su un'email
                 * «già in uso» senza dirgli cosa fare.
                 *
                 * 💡 E dall'accesso la registrazione è a un tocco — col token
                 * ancora in tasca.
                 */
                onAccedi: () =>
                    context.push(AppRoutes.accediPerInvito(widget.token)),
                onRegistrati: () =>
                    context.push(AppRoutes.registratiPerInvito(widget.token)),
                onRifiuta: _rifiuta,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ⚠️ **Chiede conferma**: accettare cambia chi copre il tuo abbonamento.
  Future<void> _accetta() async {
    final marchio = widget.invito.palestra;

    final sicuro = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Entri in ${marchio.name ?? 'questa palestra'}?'),

        /*
         * 🆕 🚨 **La frase di prima diceva il falso due volte** — 18/09/2026.
         *
         * ⛔ *«I tuoi dati e i tuoi allenamenti si spostano dentro la palestra.
         * Per uscirne dovrai parlare con loro.»*
         *
         * 1. **I dati non si spostano da nessuna parte**: restano della persona
         *    e del suo telefono. Il committente, 18/09: *«quello (il tenant)
         *    riguarda solo chi paga, i dati restano account-bound o
         *    device-bound»*.
         * 2. **Da una palestra si esce da soli**: c'è «Dissocia palestra» nel
         *    profilo. Era vero quando la frase è stata scritta, e non lo è più.
         *
         * 💡 Adesso dice le due cose che cambiano davvero.
         */
        /*
         * 🆕 **E a un trainer si dice un'altra cosa** — giro del 18/09/2026.
         * ⛔ Riceveva questa stessa frase: ma chi allena tiene il suo piano, il
         * suo spazio e i suoi allievi, e non si veste della palestra.
         */
        content: Text(
          widget.invito.daTrainer
              ? 'Alleni anche qui: vedrai i suoi iscritti. Il tuo spazio, il '
                    'tuo piano e i tuoi allievi restano come sono.'
              : 'Da ora è la palestra a coprire il tuo abbonamento, e ti vesti '
                    'dei suoi colori. I tuoi allenamenti restano tuoi, e puoi '
                    'dissociarti quando vuoi dal profilo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Aspetta'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: const Text('Entro'),
          ),
        ],
      ),
    );

    if (sicuro != true || !mounted) return;

    await _entra();
  }

  /// Entra davvero. `lasciaLaPrecedente` arriva solo dopo averlo chiesto.
  Future<void> _entra({bool lasciaLaPrecedente = false}) async {
    setState(() => _inCorso = true);

    try {
      final marchioNuovo = await ref
          .read(rispostaAllInvitoProvider)
          .accetta(widget.token, lasciaLaPrecedente: lasciaLaPrecedente);

      // 🏷️ Adesso sì: da questo momento l'app **è** vestita della palestra.
      await ref.read(brandingControllerProvider.notifier).adotta(marchioNuovo);

      // 💡 Il profilo cambia tenant: senza questo, l'app resterebbe con
      // l'utente di prima finché non si riavvia.
      await ref.read(authControllerProvider.notifier).refresh();

      /*
       * 🎟️ Un trainer che entra qui può trovarci suoi allievi già iscritti: la
       * domanda sullo slot nasce **adesso**, e va fatta adesso — non al
       * prossimo rientro nell'app (giro A5 8.3.3, 22/09/2026). Per chi non è
       * trainer l'osservatore non fa niente.
       */
      ref.read(richiestaSceltaDelloSlotProvider.notifier).state++;

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Benvenuto in ${marchioNuovo['name'] ?? 'palestra'}!'),
        ),
      );

      context.go(AppRoutes.home);
    } on Object catch (e) {
      if (!mounted) return;

      setState(() => _inCorso = false);

      /*
       * 🚨 **`unwrapError` prima, e poi si guarda** — la trappola già pagata
       * sulla modale del secondo trainer. Il client rilancia l'errore grezzo
       * del trasporto: un `on <Tipo> catch` non prende mai niente.
       *
       * ⛔ E prima qui si stampava `$e` così com'era, cioè il testo di una
       * `DioException` davanti a una persona.
       */
      final errore = ApiClient.unwrapError(e);

      if (errore is SeiGiaInUnaPalestraException) {
        await _chiediSeLasciarla(errore.palestraAttuale);

        return;
      }

      if (!mounted) return;

      /*
       * 🚨 **Qui l'errore si mostra**, al contrario del rifiuto: la persona ha
       * chiesto di entrare e non è entrata. ⛔ Un silenzio la lascerebbe a
       * guardare la stessa pagina senza sapere se ha funzionato.
       */
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Non sono riuscito a farti entrare. ${errore.message}'),
        ),
      );
    }
  }

  /// 🆕 🏛️ **Sei già in un'altra palestra: la lasci?** — regola 8.1.4.
  ///
  /// 📌 Il committente: *«Nel caso di invito a una seconda palestra, la pagina
  /// dell'invito gli deve chiedere se desidera lasciare la palestra
  /// precedente.»*
  ///
  /// ⚖️ **«Resto in X» è il tasto pieno**, ed è lo stesso principio delle altre
  /// due domande di questo giro: la scelta che non cambia niente deve costare
  /// meno di quella che cambia. Chi ha toccato l'invito di un'altra palestra
  /// per curiosità non deve ritrovarsi fuori dalla sua con un tocco solo.
  Future<void> _chiediSeLasciarla(String attuale) async {
    final vecchia = attuale.isEmpty ? 'la tua palestra' : attuale;
    final nuova = widget.invito.palestra.name ?? 'questa palestra';

    final lascia = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Sei già iscritto a $vecchia'),

        /*
         * 💡 **Cosa comporta, detto prima della domanda.** ⚠️ E senza dire
         * che si perdono dati: non si perdono. Le schede ricevute restano sul
         * telefono.
         */
        content: Text(
          'Si può stare in una palestra sola. Se entri in $nuova, lasci '
          '$vecchia: da lì non ti coprirà più l\'abbonamento. Le tue schede '
          'restano sul telefono.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text('Passo a $nuova'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: Text('Resto in $vecchia'),
          ),
        ],
      ),
    );

    if (lascia != true || !mounted) return;

    await _entra(lasciaLaPrecedente: true);
  }

  Future<void> _rifiuta() async {
    setState(() => _inCorso = true);

    // ⚠️ Non si aspetta un esito da mostrare: il rifiuto è una cortesia verso
    // la palestra, non un'operazione della persona. Vedi `RispostaAllInvito`.
    await ref.read(rispostaAllInvitoProvider).rifiuta(widget.token);

    if (!mounted) return;

    context.go(AppRoutes.home);
  }
}

/// Logo, congratulazioni e descrizione.
class _Intestazione extends StatelessWidget {
  const _Intestazione({required this.invito});

  final InvitoInPalestra invito;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final marchio = invito.palestra;

    return Column(
      children: [
        /*
         * 🆕 🖼️ **La testata, in cima** — F6.2 (A2).
         *
         * ⚠️ Prima del logo, non dopo: è la foto della sala, e dice «questo
         * posto» prima ancora del nome. 💡 Se non si scarica non lascia un buco:
         * l'invito vale lo stesso.
         */
        if (invito.immagineTestata != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                invito.immagineTestata!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          const SizedBox(height: Gap.md),
        ],

        if (marchio.logoUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              marchio.logoUrl!,
              height: 96,
              // ⚠️ Un logo che non si scarica non deve lasciare un buco né far
              // fallire la pagina: l'invito vale lo stesso.
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: Gap.md),

        /*
         * 🚨 **Le congratulazioni prima del nome, e non viceversa.** È un
         * invito, non una notifica di sistema: la prima riga deve suonare come
         * qualcuno che ti apre la porta.
         */
        Text(
          'Ti hanno invitato!',
          style: tema.textTheme.titleSmall?.copyWith(
            color: tema.colorScheme.primary,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: Gap.sm),

        Text(
          marchio.name ?? 'Una palestra',
          style: tema.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),

        if (invito.descrizione != null && invito.descrizione!.isNotEmpty) ...[
          const SizedBox(height: Gap.md),
          Text(
            invito.descrizione!,
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        // 🆕 📍 F6.2 (A3) — dove sta, e un tocco per arrivarci.
        if (invito.indirizzo != null) ...[
          const SizedBox(height: Gap.md),
          _Indirizzo(indirizzo: invito.indirizzo!, mappa: invito.mappa),
        ],
      ],
    );
  }
}

/// 📍 **L'indirizzo della palestra, con «apri nelle mappe»** — F6.2 (A3).
///
/// 📌 *«serve anche l'indirizzo preciso (con cap provincia e tutto)»*, e
/// l'app deve poterlo aprire nelle mappe.
///
/// 💡 Il pulsante c'è solo se il server ha mandato il collegamento: ⛔ un
/// pulsante che non apre niente è peggio di nessun pulsante.
class _Indirizzo extends StatelessWidget {
  const _Indirizzo({required this.indirizzo, this.mappa});

  final String indirizzo;
  final String? mappa;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.place_outlined,
              size: 18,
              color: tema.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: Gap.xs),
            Flexible(
              child: Text(
                indirizzo,
                style: tema.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        if (mappa != null)
          TextButton.icon(
            onPressed: () => launchUrl(
              Uri.parse(mappa!),
              /*
               * ⚠️ `externalApplication`: le mappe si aprono **nell'app delle
               * mappe**, non in una vista web dentro la nostra — dove non ci
               * sarebbero la posizione, le indicazioni e la navigazione, cioè
               * le tre cose per cui la si apre.
               */
              mode: LaunchMode.externalApplication,
            ),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Apri nelle mappe'),
          ),
      ],
    );
  }
}

/// «Le cose a cui avrà accesso».
class _CosaOttieni extends StatelessWidget {
  const _CosaOttieni({required this.righe});

  final List<VantaggioInPalestra> righe;

  /// 💡 Il server manda **un nome**, non un `IconData`: non può mandare
  /// un'icona di Flutter, e non deve. ⚠️ Una parola che questa versione non
  /// conosce ricade sulla spunta, invece di lasciare un buco.
  static IconData _icona(String nome) => switch (nome) {
    'fitness_center' => Icons.fitness_center_rounded,
    'chat' => Icons.chat_bubble_outline_rounded,
    'restaurant' => Icons.restaurant_rounded,
    'auto_awesome' => Icons.auto_awesome_rounded,
    'group' => Icons.groups_rounded,
    'lock' => Icons.lock_outline_rounded,
    _ => Icons.check_circle_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    if (righe.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(Gap.md),
      decoration: BoxDecoration(
        color: tema.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cosa avrai', style: tema.textTheme.titleMedium),
          const SizedBox(height: Gap.md),

          for (final riga in righe)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icona(riga.icona), color: tema.colorScheme.primary),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(riga.titolo, style: tema.textTheme.titleSmall),
                        Text(
                          riga.dettaglio,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: tema.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// I due tasti, e la distanza fra loro.
class _DueTasti extends StatelessWidget {
  const _DueTasti({
    required this.inCorso,
    required this.nome,
    required this.serveUnAccount,
    required this.onAccetta,
    required this.onAccedi,
    required this.onRegistrati,
    required this.onRifiuta,
  });

  final bool inCorso;
  final String? nome;

  /// 🆕 Chi guarda non ha una sessione: il primo passo e' iscriversi.
  final bool serveUnAccount;

  final VoidCallback onAccetta;
  final VoidCallback onAccedi;
  final VoidCallback onRegistrati;
  final VoidCallback onRifiuta;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(Gap.lg),
      child: Column(
        children: [
          /*
           * 🆕 ⚠️ **La riga che spiega il primo passo** — 17/09/2026.
           *
           * 💡 Sta **sopra** il tasto e non dentro: chi legge deve sapere cosa
           * sta per succedere **prima** di premere, non scoprirlo dopo. E chi
           * un account ce l'ha gia' non la vede affatto.
           */
          if (serveUnAccount) ...[
            Text(
              "Per entrare serve il tuo account. L'invito ti aspetta qui.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: inCorso
                  ? null
                  : (serveUnAccount ? onAccedi : onAccetta),
              child: inCorso
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      serveUnAccount
                          ? 'Accedi'
                          : 'Entro in ${nome ?? 'palestra'}',
                    ),
            ),
          ),

          /*
           * 🆕 ⚖️ **E la registrazione accanto, non sotto** — 17/09/2026.
           *
           * ⚠️ Due porte, e non si sa quale serve: chi riceve un invito può
           * essere nuovo **o** avere già un account su un telefono che ha
           * cambiato. 💡 L'accesso è quello pieno perché è l'unico che può
           * fallire in modo confuso — un'email «già in uso» non dice a nessuno
           * che deve accedere invece di iscriversi.
           */
          if (serveUnAccount) ...[
            const SizedBox(height: Gap.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: inCorso ? null : onRegistrati,
                child: const Text('Non ho ancora un account'),
              ),
            ),
          ],
          const SizedBox(height: Gap.sm),

          /*
           * ⚠️ **Il rifiuto è un `TextButton`, non un secondo tasto pieno.**
           * Due tasti dello stesso peso trasformano una scelta facile in un
           * bivio, e chi è arrivato fin qui di solito vuole entrare. 💡 Ma c'è,
           * è leggibile e non è nascosto in un angolo: dire di no deve costare
           * un tocco, non una ricerca.
           */
          TextButton(
            onPressed: inCorso ? null : onRifiuta,
            child: const Text('No, grazie'),
          ),
        ],
      ),
    );
  }
}
