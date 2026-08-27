import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../health/ui/widgets/connessione_salute.dart';
import '../consensi_controller.dart';
import 'widgets/dove_vanno_i_dati.dart';
import 'widgets/presa_d_atto_ai.dart';

/// I consensi facoltativi — S9.1.
///
/// ── 🚨 Perché sono due interruttori e non uno ─────────────────────────────
///
/// *«Accetto il trattamento dei dati»* in una casella sola **non è consenso
/// esplicito** ai sensi dell'art. 9(2)(a) GDPR. Tenere i propri dati **sul
/// proprio telefono** e mandare il diario **ad Anthropic, negli Stati Uniti**
/// sono due decisioni diverse, e chi accetta la prima non ha per questo
/// accettato la seconda.
///
/// ⚠️ **L'app funziona con entrambi spenti**, ed è la ragione per cui sono
/// facoltativi davvero: un consenso necessario per usare il servizio non è
/// «liberamente dato» (art. 7(4)), e quindi non è consenso.
class SchermataConsensi extends ConsumerWidget {
  const SchermataConsensi({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consensi = ref.watch(consensiProvider);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Privacy e consensi'),
      body: consensi.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text('Non riesco a leggere i tuoi consensi.\n$e'),
          ),
        ),
        data: (dati) => ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            /*
           * ══ 🔗 IL COLLEGAMENTO A HEALTH CONNECT — 3b-P.8.3/P.10.2 ════════
           *
           * 📌 Il committente: *«la parte di connessione a Google Health
           * Connect deve andare in privacy e consensi»* · *«Deve includere
           * anche tutto quello che c'e' nella pagina di connessione»*.
           *
           * 💡 **Sta in cima**, prima degli altri consensi: e' l'unico che
           * apre una porta verso un'altra app, ed e' quello da cui dipendono
           * meta' dei dati che le card qui sotto elencano.
           */
            const ConnessioneSalute(),
            const SizedBox(height: Gap.lg),

            /*
             * ══ 📋 DOVE VANNO I DATI — 3b-P.10.1 ═══════════════════════════
             *
             * 📌 *«Deve avere una serie di cards che dettagliano esattamente
             * quali dati prendiamo, quali salviamo sul server e quali inviamo
             * all'AI (se l'AI è attiva)»*.
             *
             * 💡 **Prima degli interruttori, non dopo.** Un consenso si dà
             * sapendo a cosa: mettere la spiegazione sotto i pulsanti vorrebbe
             * dire che la legge solo chi ha già deciso.
             */
            const DoveVannoIDati(),
            const SizedBox(height: Gap.lg),

            Text(
              'Quello che decidi qui puoi cambiarlo quando vuoi, e togliere '
              'costa quanto mettere.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.lg),

            _Interruttore(
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
              spiegazione:
                  'Permette all\'app di leggere sonno, battito e variabilità '
                  'da Health Connect. Restano sul tuo telefono: non li vede la '
                  'palestra, non li vede il trainer, e non arrivano ai nostri '
                  'server — l\'unica eccezione è il terzo consenso qui sotto, '
                  'se lo dai.',
              concessoIl: dati.salute,
              chiave: 'health',
            ),
            const SizedBox(height: Gap.md),

            _Interruttore(
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
            _Interruttore(
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

            const SizedBox(height: Gap.lg),

            /*
             * 💡 **Qui sotto non è un consenso, ed è separato apposta.**
             *
             * È una preferenza: «voglio che il consiglio si aggiorni da solo».
             * Sta nella stessa schermata perché è lì che uno la cerca, ma sotto
             * una riga e con un titolo che non parla di dati.
             */
            const Divider(height: Gap.xl),
            Text(
              'Come funziona il consiglio',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: Gap.sm),

            _InterruttoreConsiglio(acceso: dati.consiglioAutomatico),

            const SizedBox(height: Gap.lg),
            Text(
              // ⚠️ Art. 7(3), terzo periodo: la revoca non ha effetto
              // retroattivo, e dirlo qui evita di prometterlo per sbaglio.
              'Se togli un consenso, smettiamo subito. Quello che è già stato '
              'fatto resta fatto: per cancellare anche i dati usa '
              '«Elimina account» dal profilo.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Interruttore extends ConsumerStatefulWidget {
  const _Interruttore({
    required this.titolo,
    required this.spiegazione,
    required this.concessoIl,
    required this.chiave,
    this.abilitato = true,
    this.presaDAtto = false,
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
  ConsumerState<_Interruttore> createState() => _InterruttoreState();
}

class _InterruttoreState extends ConsumerState<_Interruttore> {
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

/// L'interruttore del consiglio automatico — 16/08/2026.
///
/// 🚨 **Non è un consenso, e sta apposta sotto una riga separata.** Un consenso
/// è una base giuridica: si dà, si revoca, e se ne conserva la data. Questa è
/// una preferenza — «voglio che il consiglio si aggiorni da solo» — e nel
/// database è un booleano, non una data.
///
/// 💡 Spegnerlo **non cancella** il consiglio che c'è: ferma la spesa, non la
/// lettura. Chi lo spegne e poi apre «Oggi» trova ancora l'ultimo scritto, con
/// l'ora.
class _InterruttoreConsiglio extends ConsumerStatefulWidget {
  const _InterruttoreConsiglio({required this.acceso});

  final bool acceso;

  @override
  ConsumerState<_InterruttoreConsiglio> createState() =>
      _InterruttoreConsiglioState();
}

class _InterruttoreConsiglioState
    extends ConsumerState<_InterruttoreConsiglio> {
  bool _inCorso = false;

  Future<void> _cambia(bool acceso) async {
    setState(() => _inCorso = true);

    try {
      await ref.read(cambiaConsensoProvider)('consiglio_automatico', acceso);
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
                    'Aggiorna il consiglio da solo',
                    style: testo.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: widget.acceso,
                  onChanged: _inCorso ? null : _cambia,
                ),
              ],
            ),
            const SizedBox(height: Gap.sm),
            Text(
              'Tre volte al giorno — mattina, primo pomeriggio e sera. '
              'Ogni aggiornamento costa un gettone. Se lo spegni, il consiglio '
              'resta quello dell\'ultima volta e lo aggiorni tu quando vuoi.',
              style: testo.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
