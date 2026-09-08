import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../consensi_controller.dart';
import 'presa_d_atto_ai.dart';

/// ⚖️ Tutti i consensi, in un posto solo — 08/09/2026.
///
/// ══ 📌 PERCHÉ ESISTE QUESTO FILE ══════════════════════════════════════════
///
/// Il committente, guardando la modale del dispositivo: *«il mio consenso non
/// deve essere uno, devono essere tutti i miei consensi, parliamo di dati
/// sanitari, quindi ci devono essere tutti (con sopra il toggle concedi
/// tutto)»*.
///
/// ⛔ **Ha ragione, e il difetto era di merito, non di comodità.** La modale
/// mostrava il solo consenso `health` perché è l'unico *tecnicamente*
/// necessario a leggere Health Connect. 🚨 Ma chi collega un orologio sta
/// decidendo cosa fare dei propri dati sanitari **in blocco**, e vedere una
/// casella sola gli fa credere che quella sia tutta la decisione: scopre le
/// altre due dopo, in un'altra schermata, e a quel punto la domanda che si fa
/// è «cos'altro non mi avete detto?».
///
/// ══ 🚨 E PERCHÉ SONO USCITI DALLA LORO SCHERMATA ══════════════════════════
///
/// ⛔ **Erano privati di `SchermataConsensi`.** Copiarli nella modale voleva
/// dire due stesure degli stessi tre testi — e sono testi che descrivono una
/// **base giuridica**: il giorno in cui una copia dice «anche il percorso» e
/// l'altra no, una delle due sta raccogliendo un consenso su una descrizione
/// falsa.
///
/// 💡 Un file solo, due schermate che lo mostrano.

/// L'elenco completo, con il «concedi tutto» in cima.
class ElencoDeiConsensi extends ConsumerWidget {
  const ElencoDeiConsensi({required this.dati, super.key});

  final Consensi dati;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ConcediTutto(dati: dati),
        const SizedBox(height: Gap.md),
        InterruttoreConsenso(
          titolo: 'Dati su sonno e recupero',
          /*
               * ══ 🚨 «NON LI MANDIAMO A NESSUNO» SI CONTRADDICEVA ══════════
               *
               * ⛔ Diceva *«Restano sul tuo telefono: non li mandiamo a
               * nessuno, nemmeno a noi»* — e **due interruttori più giù** ce
               * n'è uno che serve proprio a mandarli ad Anthropic.
               *
               * 🚨 Due frasi che si smentiscono a quindici centimetri di
               * distanza non sono un doppione: chi legge la prima e si ferma
               * ha capito il contrario di quello che succede se accende il
               * terzo. ⚠️ Ed è la stessa frase, sbagliata allo stesso modo,
               * che stava nella spiegazione sotto l'ipnogramma.
               *
               * 💡 Adesso il «di base» è esplicito, e rimanda al consenso che
               * fa l'eccezione invece di negarne l'esistenza.
               */
          /*
               * ══ ⚠️ L'ELENCO ERA RIMASTO INDIETRO — 08/09/2026 ═════════════
               *
               * ⛔ **Diceva «sonno, battito e variabilità»**, e nel frattempo
               * questo interruttore era diventato la porta anche per i passi
               * della giornata, gli allenamenti e — dall'08/09 — il
               * **percorso** delle uscite.
               *
               * 🚨 Un consenso che descrive meno di quello che autorizza non è
               * un consenso informato, ed è il difetto che passa piu' facilmente
               * inosservato: la frase è vera parola per parola, e sbagliata in
               * quello che lascia credere.
               *
               * 💡 Regola, per chi aggiunge una lettura domani: **se aggiungi
               * un `HealthDataType` a `PonteSalute`, questa riga si aggiorna
               * nello stesso commit.** L'ordine non è alfabetico — il percorso
               * sta per primo perche' e' quello su cui uno decide.
               */
          spiegazione:
              'Permette all\'app di leggere da Health Connect il percorso '
              'delle tue uscite, i passi, gli allenamenti, il sonno, il '
              'battito e la variabilità. Restano sul tuo telefono: non li '
              'vede la palestra, non li vede il trainer, e non arrivano ai '
              'nostri server — l\'unica eccezione è il terzo consenso qui '
              'sotto, se lo dai. Il percorso non fa eccezione mai: '
              'all\'AI non arriva nemmeno con quello acceso.',
          concessoIl: dati.salute,
          chiave: 'health',
        ),
        const SizedBox(height: Gap.md),

        InterruttoreConsenso(
          titolo: 'Consiglio del giorno e riconoscimento dei pasti',
          /*
               * ⚠️ **«quello che hai scritto nel diario» era impreciso**, e in
               * due direzioni opposte — 22/08/2026, dopo aver verificato.
               *
               * 🚨 Il **consiglio del giorno** il diario non lo manda affatto:
               * manda i **totali** (`contestoConsiglio()` prende
               * `$giornata['totals']`, non `['meals']`). ⛔ Il
               * **riconoscimento** invece manda esattamente quello che scrivi,
               * parola per parola — che è di più, non di meno.
               *
               * 💡 Dirlo separato: sono due cose diverse dietro lo stesso
               * consenso, e chi decide deve sapere quale fa cosa.
               */
          spiegazione:
              'Il riconoscimento manda ad Anthropic, negli Stati Uniti, '
              'quello che scrivi o fotografi per farti stimare un '
              'alimento. Il consiglio del giorno manda solo numeri: '
              'calorie, macro e obiettivo, senza il nome di quello che hai '
              'mangiato.\n\n'
              'In nessuno dei due casi alleghiamo il tuo nome, la tua '
              'email o il tuo account: dall\'altra parte non c\'è niente '
              'che dica chi sei.\n\n'
              'Resta un\'azienda diversa dalla nostra, e da quello che '
              'mangi si possono dedurre cose sulla tua salute: per questo '
              'te lo chiediamo a parte.',
          concessoIl: dati.ai,
          chiave: 'ai',

          // ⚖️ 3b-J.3 — vedi `presa_d_atto_ai.dart`.
          presaDAtto: true,
        ),

        const SizedBox(height: Gap.md),

        /*
             * ══ ⚖️ LA PRESA D'ATTO SI VEDE — 3b-J.3, secondo giro ═════════
             *
             * 📌 *«tra i consensi mettiamo anche un consenso obbligatorio»* ·
             * poi, provando: *«non c'è il nuovo consenso»*.
             *
             * ⛔ **Al primo giro esisteva solo come finestra** che compare
             * accendendo l'AI. 🚨 Chi l'AI ce l'ha già accesa non la vedeva mai
             * — cioè proprio chi, a database, risulta con l'AI attiva e la
             * presa d'atto mancante: lo stato che si è creato con la migrazione,
             * e l'unico che andava mostrato.
             *
             * 💡 E un consenso che non si può rileggere non è un consenso: la
             * schermata dei consensi serve a **ricordarsi cosa si è deciso**.
             */
        _PresaDAtto(concessoIl: dati.aiPresaDAtto, aiAccesa: dati.aiDato),
        const SizedBox(height: Gap.md),

        /*
             * 🚨 **Il terzo consenso — 16/08/2026.**
             *
             * Riapre una porta che era stata chiusa apposta in S1.5: sonno,
             * battito e variabilità erano stati tolti dal contesto del
             * consiglio perché non uscissero dal telefono (D9).
             *
             * ⚠️ Si può riaprire **solo così**: casella separata, revocabile,
             * e con scritto dove finiscono i dati. §C12 di
             * `todo-2026-08-11.md` dice che è esattamente quello che serve —
             * e che non serve nient'altro.
             *
             * 💡 `abilitato: dati.aiDato` — spento e non toccabile finché
             * l'AI è spenta: un consenso figlio che non può valere senza il
             * padre non deve nemmeno potersi accendere.
             */
        InterruttoreConsenso(
          titolo: 'Sonno e recupero nel consiglio del giorno',
          spiegazione:
              'Il consiglio tiene conto anche di come hai dormito: ore, '
              'risvegli, sonno profondo, variabilità cardiaca e battito a '
              'riposo. Questi dati partono verso Anthropic insieme al '
              'resto — come numeri, e senza niente che dica che sono i '
              'tuoi.\n\n'
              'Sono comunque più intimi di quello che mangi: per questo te '
              'lo chiediamo a parte. Senza, il consiglio funziona lo '
              'stesso — solo, non sa se stanotte hai dormito male.',
          concessoIl: dati.recupero,
          chiave: 'sleep_ai',
          abilitato: dati.aiDato,
        ),
      ],
    );
  }
}

/// 🎚️ «Concedi tutto» — 08/09/2026.
///
/// 📌 *«con sopra il toggle concedi tutto»*.
///
/// ══ ⚖️ UN INTERRUTTORE UNICO È LEGALE SOLO SE NON SOSTITUISCE GLI ALTRI ═══
///
/// 🚨 **Una casella sola che accende tre consensi non sarebbe consenso
/// esplicito** (art. 9(2)(a)): il Garante lo chiama *consenso a strascico*, e
/// vale zero. ⛔ Quindi questo interruttore **non sostituisce** i tre qui
/// sotto: li accende uno per uno, e i tre restano visibili, spiegati e
/// spegnibili singolarmente.
///
/// 💡 È una **scorciatoia**, non una semplificazione: chi ha già letto e vuole
/// dire di sì a tutto non deve toccare tre volte, ma quello che sta accettando
/// gli resta scritto sotto, per intero.
///
/// ⚠️ **E l'AI passa comunque dalla presa d'atto.** Il testo sugli Stati Uniti
/// non si può saltare con un interruttore che dice «tutto»: se lo si rifiuta,
/// gli altri due si accendono lo stesso e l'AI no.
class _ConcediTutto extends ConsumerStatefulWidget {
  const _ConcediTutto({required this.dati});

  final Consensi dati;

  @override
  ConsumerState<_ConcediTutto> createState() => _ConcediTuttoState();
}

class _ConcediTuttoState extends ConsumerState<_ConcediTutto> {
  bool _inCorso = false;

  bool get _tutti =>
      widget.dati.saluteDato && widget.dati.aiDato && widget.dati.recuperoDato;

  Future<void> _cambia(bool acceso) async {
    setState(() => _inCorso = true);

    try {
      final cambia = ref.read(cambiaConsensoProvider);

      /*
       * ⚠️ **`health` per primo, e non è ordine alfabetico.** `sleep_ai`
       * dipende da `ai`: il server lo revoca a cascata, e accendere il figlio
       * prima del padre vorrebbe dire scrivere una data su un consenso che in
       * quel momento non può valere.
       */
      await cambia('health', acceso);

      if (acceso) {
        /*
         * ⚖️ **La presa d'atto non si salta.** Il testo sul trasferimento
         * negli Stati Uniti è una condizione dell'AI, non un dettaglio: se
         * qui si rifiuta, l'AI resta spenta e gli altri due consensi restano
         * accesi. 🚨 Un «concedi tutto» che accendesse l'AI senza farla
         * leggere sarebbe esattamente il consenso a strascico che questo
         * widget deve evitare.
         */
        if (!mounted) return;

        final accettata = await chiediLaPresaDAtto(context);

        if (accettata) {
          await cambia('ai', true, presaDAtto: true);
          await cambia('sleep_ai', true);
        }
      } else {
        // 💡 Spegnendo si va nel verso opposto: prima il figlio, poi il padre.
        await cambia('sleep_ai', false);
        await cambia('ai', false);
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Non ha funzionato: $e')));
      }
    } finally {
      ref.invalidate(consensiProvider);

      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      color: tema.colorScheme.surfaceContainerHighest,
      child: SwitchListTile(
        value: _tutti,
        onChanged: _inCorso ? null : _cambia,
        title: const Text(
          'Concedi tutto',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _tutti
              ? 'Hai concesso tutto. Puoi togliere quello che vuoi, uno per uno.'
              : 'Li accende tutti e tre. Restano qui sotto, spiegati e '
                    'spegnibili singolarmente.',
          style: tema.textTheme.bodySmall,
        ),
      ),
    );
  }
}

class InterruttoreConsenso extends ConsumerStatefulWidget {
  const InterruttoreConsenso({
    required this.titolo,
    required this.spiegazione,
    required this.concessoIl,
    required this.chiave,
    this.abilitato = true,
    this.presaDAtto = false,
    super.key,
  });

  final String titolo;
  final String spiegazione;
  final DateTime? concessoIl;
  final String chiave;

  /// 🚨 Un consenso **subordinato** a un altro non deve poter essere acceso.
  ///
  /// ⚠️ Non è cortesia d'interfaccia: accendere il sonno mentre l'AI è spenta
  /// scriverebbe una data su un consenso che non può valere, e il giorno che
  /// l'AI si riaccende quel consenso tornerebbe attivo **senza che nessuno
  /// l'abbia riconfermato**. Il server lo revoca a cascata; qui si evita che
  /// nasca.
  final bool abilitato;

  /// ⚖️ Accendere questo consenso richiede la **presa d'atto** — 3b-J.3.
  ///
  /// 📌 *«l'importante è che chi attiva l'ai legga questa cosa e vi
  /// acconsenta»*.
  ///
  /// 💡 Solo in accensione: spegnere non richiede di leggere niente, e chiedere
  /// una conferma a chi sta revocando un consenso sarebbe un ostacolo alla
  /// revoca — che l'art. 7(3) vieta.
  final bool presaDAtto;

  @override
  ConsumerState<InterruttoreConsenso> createState() =>
      _InterruttoreConsensoState();
}

class _InterruttoreConsensoState extends ConsumerState<InterruttoreConsenso> {
  bool _inCorso = false;

  Future<void> _cambia(bool dato) async {
    /*
     * ══ ⚖️ CHI ACCENDE L'AI SI FERMA A LEGGERE — 3b-J.3 ═══════════════════
     *
     * ⛔ **Prima della chiamata, non dopo**: una finestra che compare a
     * consenso già dato non è una condizione, è un avviso.
     *
     * 💡 E se non si accetta non succede **niente** — nessuna chiamata, nessun
     * interruttore che si muove e torna indietro.
     */
    if (dato && widget.presaDAtto) {
      final accettata = await chiediLaPresaDAtto(context);

      if (!accettata) return;
    }

    setState(() => _inCorso = true);

    try {
      await ref.read(cambiaConsensoProvider)(
        widget.chiave,
        dato,

        // ⚠️ Viaggia nella **stessa** richiesta: il server rifiuta `ai: true`
        // senza, e due chiamate separate lascerebbero una finestra in cui l'AI
        // è accesa e la presa d'atto no.
        presaDAtto: dato && widget.presaDAtto,
      );
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Non ha funzionato: $e')));
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final testo = Theme.of(context).textTheme;
    final concesso = widget.concessoIl != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.titolo,
                    style: testo.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: concesso && widget.abilitato,
                  onChanged: (_inCorso || !widget.abilitato) ? null : _cambia,
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(widget.spiegazione, style: testo.bodyMedium),

            // 💡 Se è spento perché dipende da un altro, si dice **perché**:
            // un interruttore grigio senza spiegazione sembra un guasto.
            if (!widget.abilitato) ...[
              const SizedBox(height: Gap.sm),
              Text(
                'Per attivarlo serve prima il consenso qui sopra.',
                style: testo.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
            if (concesso) ...[
              const SizedBox(height: Gap.sm),
              Text(
                'Concesso il ${DateFormat('d MMMM y', 'it').format(widget.concessoIl!)}',
                style: testo.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ⚖️ La riga della presa d'atto — 3b-J.3.
///
/// ══ ⛔ NON È UN INTERRUTTORE, ED È IL PUNTO ═══════════════════════════════
///
/// 🚨 Un interruttore si accende con un tocco, e questa cosa **si accende
/// leggendo**. ⚠️ Con uno `Switch` si potrebbe dichiarare di aver capito senza
/// aver visto una parola — che è esattamente il contrario della richiesta.
///
/// 💡 Quindi: se manca, un pulsante che **apre il testo**; se c'è, la data. E
/// si può rileggere quando si vuole.
class _PresaDAtto extends ConsumerStatefulWidget {
  const _PresaDAtto({required this.concessoIl, required this.aiAccesa});

  final DateTime? concessoIl;
  final bool aiAccesa;

  @override
  ConsumerState<_PresaDAtto> createState() => _PresaDAttoState();
}

class _PresaDAttoState extends ConsumerState<_PresaDAtto> {
  bool _inCorso = false;

  /// ⚖️ Ritira la presa d'atto — 27/08/2026.
  ///
  /// 📌 *«se lo dis-flaggo, mi deve bloccare tutto quello che c'è con l'ai»*.
  ///
  /// 🚨 **E succede davvero, non solo a schermo**: il server revoca a cascata
  /// anche il consenso all'AI, e `puoUsareAi()` pretende tutti e due — quindi da
  /// quel momento ogni chiamata risponde 403.
  ///
  /// ⛔ **Non si chiede conferma.** Chiedere «sei sicuro?» a chi sta ritirando
  /// un consenso è un ostacolo alla revoca, che l'art. 7(3) vieta: revocare
  /// deve costare quanto concedere, o meno.
  Future<void> _ritira() async {
    setState(() => _inCorso = true);

    try {
      await ref.read(cambiaConsensoProvider)('ai_disclaimer', false);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Non ha funzionato: $e')));
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<void> _leggi() async {
    final accettata = await chiediLaPresaDAtto(context);

    if (!accettata || !mounted) return;

    setState(() => _inCorso = true);

    try {
      /*
       * ⚠️ **Si manda `ai: true` insieme**, e non la sola presa d'atto: chi è
       * qui o l'AI ce l'ha già accesa — e allora la riga non cambia niente — o
       * la sta accendendo adesso. 🚨 Mandare la sola presa d'atto lascerebbe
       * chi la accetta da qui con l'AI ancora spenta e nessun modo di capire
       * perché.
       */
      await ref.read(cambiaConsensoProvider)('ai', true, presaDAtto: true);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Non ha funzionato: $e')));
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final presa = widget.concessoIl != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  presa ? Icons.gavel_rounded : Icons.warning_amber_rounded,
                  color: presa
                      ? tema.colorScheme.onSurfaceVariant
                      : tema.colorScheme.error,
                ),
                const SizedBox(width: Gap.sm),
                Expanded(
                  child: Text(
                    'Cosa l\'AI non è',
                    style: tema.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),

            Text(
              presa
                  ? 'Hai preso atto che quello che l\'AI produce non è mai un '
                        'parere medico, ma una stima statistica che può '
                        'sbagliare.\n\n'
                        'Se la ritiri, tutte le funzioni con l\'AI si spengono.'
                  /*
                   * 🚨 **Questo è lo stato che si è creato con la migrazione**:
                   * l'AI accesa da prima che la presa d'atto esistesse. ⛔ Non
                   * si spegne l'AI da soli per farlo notare — sarebbe togliere
                   * una funzione che qualcuno sta usando — ma non si può
                   * nemmeno far finta di niente.
                   */
                  : 'Non hai ancora preso atto di cosa l\'AI non è. '
                        'Serve per usarla: è una lettura di un minuto.',
              style: tema.textTheme.bodyMedium,
            ),

            if (presa) ...[
              const SizedBox(height: Gap.sm),
              Text(
                'Accettato il ${DateFormat('d MMMM y', 'it').format(widget.concessoIl!.toLocal())}',
                style: tema.textTheme.bodySmall?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            const SizedBox(height: Gap.md),

            if (presa)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      // 💡 Rileggere non ricambia niente: la finestra si apre,
                      // si legge, e se si accetta di nuovo si aggiorna la data.
                      onPressed: _inCorso ? null : _leggi,
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('Rileggi'),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    /*
                     * ⚖️ **Ritirare costa un tocco, come concedere.** ⛔ Niente
                     * conferma, niente «sei sicuro?»: un ostacolo alla revoca lo
                     * vieta l'art. 7(3). 💡 La conseguenza è scritta sopra, che è
                     * il posto giusto — prima del gesto, non dopo.
                     */
                    child: TextButton.icon(
                      onPressed: _inCorso ? null : _ritira,
                      icon: const Icon(Icons.block_outlined, size: 18),
                      label: const Text('Ritira'),
                      style: TextButton.styleFrom(
                        foregroundColor: tema.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _inCorso ? null : _leggi,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: Text(
                    widget.aiAccesa ? 'Leggi adesso' : 'Leggi e attiva l\'AI',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
