import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/miniatura.dart';
import '../../../core/ui/states.dart';
import '../../acquisti/ui/modale_acquisti.dart';
import '../../profile/corpo_controller.dart';
import '../../progress/ui/progress_screen.dart';
import '../data/calorie_allenamento.dart';
import '../data/catalogo_esercizi.dart';
import '../data/limiti_delle_schede.dart';
import '../data/progressione.dart';
import '../data/stima_della_scheda.dart';
import '../muscoli_allenati.dart';
import '../progressione_controller.dart';
import '../session_controller.dart';
import '../settimana_controller.dart';
import '../storico_unificato_controller.dart';
import '../training_controller.dart';
import 'history_screen.dart';
import 'widgets/barra_settimana.dart';
import 'widgets/esercizio_della_scheda.dart';
import 'widgets/muscoli_della_scheda.dart';
import 'widgets/scelta_tipo_scheda.dart';

/// La sezione Allenamento — A5.1, riorganizzata in G6.
///
/// 🚨 **Si apre sullo STORICO, non sulle schede.**
/// Entrando qui la domanda è «quando mi sono allenato l'ultima volta, e come è
/// andata» — non «quali schede ho», che si sa già. Le schede servono in due
/// momenti soli: quando si comincia una seduta (e per quello c'è il pulsante in
/// basso, che le propone) e quando se ne modifica una. Tenerle come pagina
/// principale metteva davanti un elenco che non cambia quasi mai e nascondeva
/// dietro un pulsantino l'unica cosa che cresce ogni settimana.
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  /// 0 = storico, 1 = schede.
  int _vista = 0;

  @override
  Widget build(BuildContext context) {
    final schede = ref.watch(schedeUniteProvider);

    return Scaffold(
      appBar: IntestazioneApp(
        titolo: 'Allenamento',
        /*
         * ⛔ Niente `BottoneProfilo` fra le azioni — 3b-O.1a.6: sta nella riga
         * d'identita', su ogni pagina.
         */
        // Il selettore sta **nella barra**, sotto il titolo: è la posizione in
        // cui si cerca un cambio di vista, e non ruba una riga al contenuto.
        /*
         * 🆕 **Il navigatore per settimana, e solo sullo Storico** — 3b-A.4.1.
         *
         * ⚠️ **Solo lì**, e non per risparmiare spazio: su «Schede» e «Foto»
         * una freccia per settimana comanderebbe qualcosa che non c'è. Un
         * comando che non fa niente insegna a non fidarsi degli altri.
         *
         * 🚨 `altezzaSotto` va **sommata a mano**: `Scaffold` non sa quanto
         * spazio serve a `sotto` e lo taglierebbe. Sbagliarla non dà un errore,
         * dà un navigatore mezzo tagliato.
         */
        // ⚠️ **Anche «Foto» adesso**: da 3b-C.7 le foto si guardano per
        // settimana, quindi il navigatore serve su due delle tre viste.
        altezzaSotto: _vista == 1 ? 52 : 52 + altezzaBarraSettimana,
        sotto: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
                /*
             * 🎯 **Centrato** — 3b-A.1.1, 23/08/2026, su richiesta del
             * committente: *«Le pasticche con storico, schede e foto devono
             * essere centrate, non allineate a sinistra»*.
             *
             * ⚠️ **Il `Center` non basta da solo**: `SegmentedButton` dentro un
             * `Padding` si prende tutta la larghezza e distribuisce i segmenti,
             * quindi *sembra* centrato ma è **stirato**. Con tre segmenti su un
             * telefono largo le pasticche diventano enormi.
             *
             * 💡 `Center` + `mainAxisSize` implicito: il gruppo prende la
             * larghezza che gli serve e sta in mezzo.
             */
                child: Center(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Storico'),
                        icon: Icon(Icons.history_rounded),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Schede'),
                        icon: Icon(Icons.assignment_outlined),
                      ),
                      /*
                 * 📷 **Le foto dei progressi** — 3b-P.9.1, 22/08/2026.
                 *
                 * 📌 Il committente: *«Non ha senso che sia qui [nelle
                 * impostazioni], mettila in una nuova tab nella sezione
                 * allenamento»*.
                 *
                 * 💡 **Una tab, non una barra nuova**: il selettore esisteva
                 * gia' con «Storico» e «Schede». ⚠️ Aggiungere una `TabBar`
                 * accanto a un `SegmentedButton` avrebbe dato due comandi
                 * diversi per la stessa cosa nella stessa schermata.
                 */
                      ButtonSegment(
                        value: 2,
                        label: Text('Foto'),
                        icon: Icon(Icons.photo_camera_outlined),
                      ),
                    ],
                    selected: {_vista},
                    onSelectionChanged: (s) => setState(() => _vista = s.first),
                    showSelectedIcon: false,
                  ),
                ),
              ),
            ),
            /*
             * ⚠️ **Su «Schede» no**, e non è per risparmiare spazio: là una
             * freccia per settimana comanderebbe qualcosa che non c'è, e un
             * comando che non fa niente insegna a non fidarsi degli altri.
             *
             * 💡 Su «Foto» conta le foto, non le sedute: la stessa barra, con
             * un'etichetta che dice cosa sta contando.
             */
            if (_vista == 0) const BarraSettimana(),
            if (_vista == 2)
              BarraSettimana(
                quanti: ref.watch(fotoDellaSettimanaProvider).valueOrNull,
                uno: 'foto',
                molti: 'foto',
              ),
          ],
        ),
      ),
      /*
       * ══ 🚨 IL PULSANTE CAMBIA CON LA VISTA — 3b-P.9.2 ═══════════════════
       *
       * C9: si comincia da qui. Il pulsante e' grande e sempre visibile perche'
       * «inizia l'allenamento» e' l'unica cosa che si fa entrando in palestra.
       *
       * ⚠️ **Ma sul segmento «Foto» quella non e' piu' l'azione della
       * schermata.** Un flottante che avvia un allenamento mentre si guardano
       * le foto e' un tasto che mente: e' il posto dove il pollice va per
       * fare *la cosa di questa vista*, e ci troverebbe un'altra.
       */
      floatingActionButton: _vista == 2
          ? const AggiungiFoto()
          : const _AvviaAllenamento(),
      body: Column(
        children: [
          // 🚨 L'allenamento lasciato a metà si vede **prima di tutto il
          // resto**, in **entrambe** le viste.
          //
          // Prima l'unico segnale era l'etichetta del pulsante in basso, che
          // passava da «Inizia» a «Riprendi»: chi chiudeva l'app nel mezzo di
          // una seduta non aveva modo di capire che quella seduta esisteva
          // ancora, e ne apriva una nuova — lasciando la prima aperta per
          // sempre. Una riga in cima, con dentro il nome e da quanto è aperta,
          // è l'unica cosa che lo rende evidente.
          const _SessioneAperta(),
          Expanded(
            child: switch (_vista) {
              0 => const StoricoAllenamenti(),
              2 => const CorpoFotoProgressi(),
              _ => _corpo(context, ref, schede),
            },
          ),
        ],
      ),
    );
  }

  Widget _corpo(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<WorkoutPlan>> schede,
  ) {
    return schede.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(schedeUniteProvider),
      ),
      data: (elenco) => elenco.isEmpty
          // 🚨 Il vuoto dice **di chi è la palla**: l'iscritto non può darsi
          // una scheda da solo, e un «nessuna scheda» senza spiegazione lo
          // lascerebbe a chiedersi se l'app è rotta.
          // 🚨 Il vuoto è cambiato con C2: adesso l'iscritto **può** farsi
          // una scheda, quindi il messaggio non deve più dire che dipende
          // dal trainer — sarebbe una bugia che scoraggia dal provarci.
          ? EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Nessuna scheda',
              message:
                  'Il tuo trainer non te ne ha ancora assegnata una, '
                  'ma puoi scrivertene una tu.',
              action: FilledButton.icon(
                onPressed: () => nuovaScheda(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea una scheda'),
              ),
            )
          : RefreshIndicator(
              /*
               * 📌 *«si deve vedere anche quando aggiorno scorrendo in basso»*
               * — B.16.14.
               *
               * ⚠️ **Non basta invalidare `schedeUniteProvider`**: quello legge
               * la copia locale, e senza rifare la sincronizzazione mostrerebbe
               * di nuovo esattamente quello che mostrava prima. Il gesto
               * sembrerebbe funzionare e non farebbe niente.
               */
              onRefresh: () => aggiornaTutto(
                context,
                ref,
                () => ref.invalidate(schedeUniteProvider),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 96),

                /*
                 * ══ 📅 LA SETTIMANA STA IN CIMA — corretto il 27/08/2026 ═══
                 *
                 * 📌 *«Come faccio a fargli programmare le schede nei
                 * giorni?»*.
                 *
                 * ⛔ **L'unico ingresso era nella dashboard**, dentro la card
                 * «Allenamento» di «Oggi». 🚨 Ma chi vuole programmare le
                 * schede va nella **sezione Allenamento**, dove ci sono
                 * Storico, Schede e Foto — e lì non c'era niente. La funzione
                 * esisteva e non si trovava, che per chi guarda è identico al
                 * non averla.
                 *
                 * 💡 **Qui e non in un quarto segmento**: programmare la
                 * settimana è una cosa che si fa *alle schede*, e la riga sta
                 * sopra l'elenco di quelle che si stanno per distribuire.
                 * ⚠️ Un quarto segmento accanto a Storico/Schede/Foto avrebbe
                 * stretto tutti e quattro i nomi per una schermata che si apre
                 * una volta ogni tanto.
                 *
                 * ⛔ Quello della dashboard **resta**: là è «cosa tocca oggi»,
                 * qui è «come voglio la settimana». Sono due momenti diversi.
                 */
                itemCount: elenco.length + 2,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: Gap.md),
                itemBuilder: (context, index) => switch (index) {
                  0 => const _ProgrammaLaSettimana(),
                  _ when index == elenco.length + 1 => OutlinedButton.icon(
                    onPressed: () => nuovaScheda(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Nuova scheda'),
                  ),
                  _ => _SchedaCard(
                    scheda: elenco[index - 1],
                    // 💡 La regola sta in `schedeBloccateProvider`, non
                    // qui: la stessa domanda la fa anche il dettaglio.
                    bloccata: ref
                        .watch(schedeBloccateProvider)
                        .valueOrNull?[elenco[index - 1].id],
                  ),
                },
              ),
            ),
    );
  }
}

/// La riga dell'allenamento lasciato aperto.
///
/// ⚠️ Non disegna niente quando non c'è niente da riprendere — **e nemmeno
/// mentre carica**: una striscia che compare mezzo secondo dopo l'apertura e
/// sposta tutto il contenuto in basso fa premere la cosa sbagliata.
class _SessioneAperta extends ConsumerWidget {
  const _SessioneAperta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aperta = ref.watch(openSessionProvider).valueOrNull;

    if (aperta == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final da = DateTime.now().difference(aperta.startedAt);
    final quanto = da.inHours >= 1
        ? '${da.inHours} h fa'
        : '${da.inMinutes} min fa';

    return Material(
      color: theme.colorScheme.tertiaryContainer,
      child: InkWell(
        onTap: () => context.push(AppRoutes.player(aperta.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Allenamento in corso',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    Text(
                      '${aperta.titolo} · cominciato $quanto',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              FilledButton(
                onPressed: () => context.push(AppRoutes.player(aperta.id)),
                child: const Text('Riprendi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchedaCard extends StatelessWidget {
  const _SchedaCard({required this.scheda, this.bloccata});

  final WorkoutPlan scheda;

  /// Perché non si può usare, o `null` se si può — 3b-C.6.
  final MotivoBlocco? bloccata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final motivo = bloccata;

    /*
     * ══ 🔒 SI VEDE, E NON SI APRE — 3b-C.6 ═══════════════════════════════
     *
     * 📌 *«le altre le deve vedere disabilitate, con scritto che senza
     * abbonamento il massimo è 3»*.
     *
     * ⛔ **Disabilitata, non nascosta.** Chi non si abbona deve vedere cosa si
     * sta perdendo — è il punto di un limite commerciale — e una scheda mandata
     * dal trainer che sparisce sarebbe un danno vero: quel trainer l'ha scritta
     * per quella persona.
     *
     * 💡 Il grigio da solo non basta: **si dice perché**. Una card spenta senza
     * spiegazione si legge come un guasto, e chi la vede pensa che l'app sia
     * rotta invece di capire che c'è un abbonamento da fare.
     */
    return Opacity(
      opacity: motivo == null ? 1 : 0.55,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(Gap.radius),
          onTap: motivo == null
              ? () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        DettaglioScheda(id: scheda.id, nome: scheda.name),
                  ),
                )
              /*
               * ══ 💳 TOCCARLA PORTA A SBLOCCARLA — 3b-H.4, 26/08/2026 ══════
               *
               * 📌 *«fai in modo che si vada su quell'interfaccia quando clicco
               * su una cosa bloccata ai non abbonati»*.
               *
               * ⛔ Prima usciva un avviso in fondo allo schermo con **la stessa
               * frase che sta già scritta sulla card**: ripeteva il problema e
               * non offriva la via d'uscita. 💡 Il perché si legge lì sotto;
               * qui serve il come.
               */
              : () => ModaleAcquisti.mostra(context),
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                // C23 — la copertina. Fra sei «Full body A/B/C» e' la sola cosa
                // che le distingue a colpo d'occhio.
                Miniatura(url: scheda.imageUrl, etichetta: scheda.name),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        scheda.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      /*
                       * ══ 🎫 SINGLE O MULTI, SEMPRE — 3b-D.9.1 ═════════════
                       *
                       * 📌 *«Le schede devono indicare chiaramente se sono
                       * single-day o multi-day»*.
                       *
                       * ⛔ Prima i giorni comparivano **solo** sopra l'uno, e
                       * l'assenza doveva valere «un giorno». 🚨 Un'assenza non
                       * si legge: chi guarda un elenco misto vede alcune schede
                       * con «3 giorni» e altre senza niente, e non sa se le
                       * seconde sono a giorno unico o se il dato manca.
                       */
                      Text(
                        '${scheda.exercisesCount} esercizi · '
                        '${scheda.giorni} '
                        '${scheda.giorni == 1 ? 'giorno' : 'giorni'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      _MuscoliDellaCard(scheda: scheda),

                      // 🔒 Il perché, sotto il nome: senza, una card spenta si
                      // legge come un guasto.
                      if (motivo != null)
                        Padding(
                          padding: const EdgeInsets.only(top: Gap.xs),
                          child: Text(
                            motivo.spiegazione,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  motivo == null
                      ? Icons.chevron_right_rounded
                      : Icons.lock_outline_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// I due o tre gruppi più coinvolti da una scheda — 3b-D.9.2.
///
/// 📌 *«e indicare brevemente i muscoli più coinvolti»*.
///
/// ══ ⚠️ SE NON SI SA, NON SI SCRIVE ════════════════════════════════════════
///
/// 🚨 I muscoli li sa il **catalogo**, non la scheda: se gli esercizi sono
/// scritti a mano con nomi che il catalogo non conosce, qui non compare niente.
/// ⛔ Meglio muto che sbagliato — tre pasticche indovinate su una scheda che
/// allena altro sono peggio di nessuna pasticca.
///
/// 💡 È anche il motivo per cui scegliere l'esercizio dall'elenco mentre si
/// scrive (3b-D.4) conviene: da lì in poi la scheda si racconta da sola.
class _MuscoliDellaCard extends ConsumerWidget {
  const _MuscoliDellaCard({required this.scheda});

  final WorkoutPlan scheda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoEserciziProvider).valueOrNull;

    if (catalogo == null || scheda.exercises.isEmpty) {
      return const SizedBox.shrink();
    }

    final pesi = pesiDellaScheda(scheda, catalogo);

    if (pesi.isEmpty) return const SizedBox.shrink();

    final ordinati = pesi.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        // ⚠️ **Tre e non tutti**: in una riga di elenco l'elenco completo
        // diventa una frase da leggere, e questa va colta di sfuggita.
        ordinati.take(3).map((e) => e.key.etichetta).join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: tema.textTheme.labelSmall?.copyWith(
          color: tema.colorScheme.primary,
        ),
      ),
    );
  }
}

/// La pagina di una scheda: cosa allena, i numeri, i progressi, gli esercizi.
///
/// ══ ⚠️ PUBBLICA DAL 27/08/2026, E NON PER COMODITÀ ════════════════════════
///
/// 📌 *«il tasto "Oggi tocca a" deve rimandare direttamente a quella scheda,
/// non allo storico in generale»*.
///
/// ⛔ Era privata, e la riga in «Oggi» poteva solo mandare **alla sezione**
/// Allenamento: chi la toccava si trovava davanti all'elenco e doveva cercare
/// da solo la scheda di cui aveva appena letto il nome.
///
/// 🚨 **Aprirla da qui e dall'elenco deve essere la stessa cosa**, e per questo
/// non è nata una rotta nuova: due strade per la stessa pagina sono due posti
/// dove un domani si comportano diversamente. È la stessa `MaterialPageRoute`
/// che usa la card dell'elenco.
class DettaglioScheda extends ConsumerWidget {
  const DettaglioScheda({required this.id, required this.nome, super.key});

  final int id;
  final String nome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheda = ref.watch(planDetailProvider(id));

    return Scaffold(
      appBar: IntestazioneApp(
        titolo: nome,
        azioni: [
          // 🚨 Il pulsante compare **solo** se il server dice che è
          // modificabile. Mostrarlo sempre porterebbe l'utente a un 403 su una
          // scheda che il trainer ha scritto per lui: un pulsante che apre una
          // schermata destinata a fallire è peggio di un pulsante assente.
          if (scheda.valueOrNull?.editable ?? false)
            IconButton(
              onPressed: () => context.push(AppRoutes.planEdit(id)),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifica',
            ),
        ],
      ),
      body: scheda.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(planDetailProvider(id)),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            /*
             * ══ 🧍 COSA ALLENA, E QUANTO COSTA — 3b-D.16, 25/08/2026 ═══════
             *
             * 📌 *«Mettici le cards con l'uomo e il diagramma a stella, e una
             * stima del tempo di esecuzione e delle calorie bruciate»* · *«E
             * mettici anche quante volte l'ho fatta»*.
             *
             * ⛔ Questa schermata era **un elenco di esercizi e basta**: la
             * stessa cosa che si legge meglio nel player, dove serve davvero.
             * 💡 Quello che qui serviva e non c'era e' **decidere**: questa
             * scheda cosa allena, quanto dura, quanto costa, e da quanto la
             * faccio.
             *
             * 🚨 Gli **stessi widget** dello storico e dell'editor
             * (`MuscoliInCard`): tre posti, una figura sola.
             */
            _CosaAllena(scheda: p),

            _SchedaInNumeri(scheda: p),

            /*
             * ══ 📈 I PROGRESSI — 3b-I.A, 27/08/2026 ═══════════════════════
             *
             * 📌 *«nella pagina della scheda possiamo mettere un grafico che
             * indica i progressi solo a chi è abbonato, con sotto un'analisi da
             * parte dell'ai»*.
             *
             * 🚨 **Il pulsante sta in cima, le righe sotto ogni esercizio.**
             * Sono due cose: qui si *chiede* l'analisi — una volta, per tutta
             * la scheda — e là la si *legge*, accanto a ciò di cui parla.
             */
            _ProgressiDellaScheda(scheda: p),

            const SizedBox(height: Gap.md),

            if (p.attribuzione.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Text(
                  p.attribuzione,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (p.notes != null && p.notes!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Text(p.notes!),
                ),
              ),
              const SizedBox(height: Gap.md),
            ],
            /*
             * ══ 📋 OGNI ESERCIZIO, CON LE SUE SERIE — 3b-D.18 ══════════════
             *
             * 📌 *«in ogni esercizio deve essere mostrata la foto (se c'è) e
             * tutti i dettagli di ogni serie, non solo rec. 60s o 11.0kg come
             * adesso»*.
             *
             * ⛔ Qui c'era una `ListTile` che mostrava **il riassunto del
             * formato vecchio**: un recupero e un peso soli, uguali per tutte
             * le serie. 🚨 Le righe vere c'erano da 3b-D.1 e non le leggeva
             * nessuno — il difetto peggiore di una funzione nuova, perche' il
             * dato si scrive, si salva, entra nel backup, e a schermo continua
             * a comparire quello di prima.
             */
            /*
             * ⚠️ `p.id` e' l'id **del server**: e' lo stesso che il player
             * scrive in `sedute_allenamento.scheda_server_id` quando si
             * comincia (`SessionActions.start(planId: …)`). 🚨 Passare l'id
             * locale qui vorrebbe dire cercare uno storico che non esiste, e
             * la progressione non comparirebbe mai — senza nessun errore.
             */
            for (final e in p.exercises)
              EsercizioDellaScheda(esercizio: e, schedaLocale: p.id),
          ],
        ),
      ),
    );
  }
}

/// La figura e la stella di una scheda — 3b-D.16.
///
/// ⚠️ **Muta finche' il catalogo non sa niente** degli esercizi: una figura
/// tutta spenta sotto una scheda piena sembra un difetto dell'app, non
/// un'informazione.
class _CosaAllena extends ConsumerWidget {
  const _CosaAllena({required this.scheda});

  final WorkoutPlan scheda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoEserciziProvider).valueOrNull;

    if (catalogo == null) return const SizedBox.shrink();

    final intensita = intensitaDellaScheda(scheda, catalogo);

    if (intensita.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: MuscoliInCard(intensita: intensita),
    );
  }
}

/// Quanto dura, quanto costa, e quante volte l'hai fatta — 3b-D.16.
class _SchedaInNumeri extends ConsumerWidget {
  const _SchedaInNumeri({required this.scheda});

  final WorkoutPlan scheda;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);

    final catalogo =
        ref.watch(catalogoEserciziProvider).valueOrNull ??
        CatalogoEsercizi.vuoto;

    final stima = stimaDellaScheda(
      scheda: scheda,
      catalogo: catalogo,
      /*
       * ⚠️ Il peso vero se c'e', il ripiego prudente se no — la stessa catena
       * di `bruciate_locali.dart`. 🚨 Non si inventa un peso «medio» diverso da
       * quello che usa il resto dell'app, o due schermate direbbero due numeri
       * per la stessa seduta.
       */
      kg:
          ref.watch(corpoOggiProvider).valueOrNull?.weightKg ??
          CalorieAllenamento.pesoDiRipiego,
    );

    /*
     * ══ 🔁 QUANTE VOLTE L'HO FATTA ════════════════════════════════════════
     *
     * 💡 Lo storico unificato tiene l'id della scheda su ogni voce, quindi si
     * contano **anche gli allenamenti visti solo dall'orologio** a cui e' stata
     * associata questa scheda. ⛔ Contare solo le sedute registrate nell'app
     * direbbe «due volte» a chi ne ha fatte sei col telefono in tasca.
     */
    final volte = ref
        .watch(storicoUnificatoProvider)
        .valueOrNull
        ?.where((v) => v.schedaId == scheda.id)
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Questa scheda',
              style: tema.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Gap.sm),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: Gap.md,
              runSpacing: Gap.sm,
              children: [
                /*
                 * 🚨 **«circa» e i minuti tondi a cinque.** Nessuno di questi
                 * numeri e' misurato: il tempo di una serie dipende da come la
                 * si fa, le calorie da chi la fa. ⛔ «47 minuti» sarebbe una
                 * bugia con l'aria di una misura.
                 */
                _Numero(
                  valore: 'circa ${stima.minutiTondi}',
                  etichetta: 'minuti',
                ),
                if (stima.kcal case final k?)
                  _Numero(valore: 'circa $k', etichetta: 'kcal'),
                _Numero(valore: '${stima.esercizi}', etichetta: 'esercizi'),
                _Numero(valore: '${stima.serie}', etichetta: 'serie'),
                if (volte != null)
                  _Numero(
                    // ⚠️ «Mai» e non «0 volte»: zero volte e' un conteggio,
                    // mai e' una risposta.
                    valore: volte == 0 ? 'Mai' : '$volte',
                    etichetta: volte == 1 ? 'volta fatta' : 'volte fatta',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.valore, required this.etichetta});

  final String valore;
  final String etichetta;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          valore,
          style: tema.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: tema.colorScheme.primary,
          ),
        ),
        Text(
          etichetta,
          style: tema.textTheme.labelSmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Il pulsante che apre una sessione — C9.
///
/// ⚠️ Se ce n'è una **già aperta** si riprende quella invece di aprirne una
/// nuova: chi chiude l'app a metà seduta altrimenti si ritroverebbe con lo
/// storico pieno di allenamenti monchi.
class _AvviaAllenamento extends ConsumerWidget {
  const _AvviaAllenamento();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aperta = ref.watch(openSessionProvider).valueOrNull;

    return FloatingActionButton.extended(
      // Vedi la nota su `heroTag` in `conversations_screen.dart`.
      heroTag: 'fab-allenamento',
      onPressed: () => _avvia(context, ref, aperta?.id),
      icon: Icon(
        aperta == null ? Icons.play_arrow_rounded : Icons.replay_rounded,
      ),
      label: Text(aperta == null ? 'Inizia' : 'Riprendi'),
    );
  }

  Future<void> _avvia(
    BuildContext context,
    WidgetRef ref,
    int? apertaId,
  ) async {
    if (apertaId != null) {
      await context.push(AppRoutes.player(apertaId));

      return;
    }

    /*
     * 🔒 **Le bloccate non si possono nemmeno cominciare** — 3b-C.6. ⛔ Senza
     * questa riga il limite sarebbe solo estetico: la card non si apre, ma il
     * pulsante «Inizia» offre la stessa scheda in un foglio, e chi la sceglie
     * si allena con una scheda che l'elenco dice bloccata.
     */
    /*
     * ══ 🚨 `await …future`, NON `ref.read(...).valueOrNull` ════════════════
     *
     * ⛔ **Era il difetto, e il committente l'ha visto subito**: *«non è vero,
     * controlla, se faccio inizia vedo tutte le mie schede»*.
     *
     * 🚨 `schedeBloccateProvider` è `autoDispose` e **questo widget non lo
     * guarda**: la prima `read` lo fa nascere in quel momento, quindi risponde
     * `AsyncLoading` e `valueOrNull` è `null`. Il ripiego `?? {}` diventava
     * allora «nessuna scheda bloccata», e il foglio le offriva tutte.
     *
     * ⚠️ **Il difetto peggiore della sua specie**: il codice c'era, si leggeva
     * giusto, e non faceva niente. Nessun errore, nessun avviso — solo un
     * limite che non scatta mai.
     *
     * 💡 `await …future` aspetta il valore vero. Costa un istante prima che il
     * foglio si apra, ed è il momento giusto per pagarlo: chi tocca «Inizia» sta
     * per allenarsi, non sta scorrendo.
     */
    final bloccate = await ref.read(schedeBloccateProvider.future);

    final schede = (await ref.read(
      schedeUniteProvider.future,
    )).where((s) => !bloccate.containsKey(s.id)).toList();

    int? scelta;

    if (schede.isNotEmpty && context.mounted) {
      scelta = await showModalBottomSheet<int>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Con quale scheda?')),
              for (final s in schede)
                ListTile(
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(s.name),
                  subtitle: Text(s.attribuzione),
                  onTap: () => Navigator.of(context).pop(s.id),
                ),
              // Allenarsi senza scheda è normale: un giorno di corsa, una
              // seduta improvvisata. Obbligare a sceglierne una farebbe
              // inventare schede finte.
              ListTile(
                leading: const Icon(Icons.bolt_rounded),
                title: const Text('Senza scheda'),
                onTap: () => Navigator.of(context).pop(0),
              ),
            ],
          ),
        ),
      );

      if (scelta == null) return;
    }

    final idScheda = (scelta ?? 0) == 0 ? null : scelta;

    /*
     * ══ 🔒 E QUI SI CHIUDE DAVVERO — 3b-C.6, 25/08/2026 ═══════════════════
     *
     * 📌 *«il limite di schede ovviamente deve esserci anche nel tasto inizia,
     * altrimenti non ha senso: non puoi iniziare un allenamento con una scheda
     * bloccata, è ovvio»*.
     *
     * ⚠️ **Filtrare l'elenco del foglio non basta.** Quello toglie la scheda
     * dalla vista, ma l'elenco è una fotografia presa quando il foglio si è
     * aperto: se nel frattempo il limite cambia — l'abbonamento scade mentre il
     * foglio è aperto, o il profilo arriva un istante dopo — si partirebbe lo
     * stesso.
     *
     * 🚨 Un controllo **al momento di partire** è l'unico che guarda lo stato
     * di quel momento. ⛔ È lo stesso ragionamento per cui il server non si
     * fida mai del client: qui il client non si fida della propria lista.
     */
    if (idScheda != null && bloccate.containsKey(idScheda)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(bloccate[idScheda]!.spiegazione)),
        );
      }

      return;
    }

    try {
      /*
       * 🆕 **Il nome viaggia con la seduta** — FASE 11.4.
       *
       * 🚨 Prima lo risolveva il server unendo `workout_plan_id` a `plans`.
       * Adesso la seduta sta sul telefono e la scheda no, quindi il nome si
       * **copia** al momento in cui si comincia.
       *
       * 💡 Ed è anche più giusto: una scheda archiviata o rinominata non deve
       * cambiare quello che lo storico dice di un allenamento di tre mesi fa.
       */
      final sessione = await ref
          .read(sessionActionsProvider)
          .start(
            planId: idScheda,
            planName: idScheda == null
                ? null
                : schede
                      .where((s) => s.id == idScheda)
                      .map((s) => s.name)
                      .firstOrNull,
          );

      if (context.mounted) await context.push(AppRoutes.player(sessione.id));
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.unwrapError(error).message)),
        );
      }
    }
  }
}

/// Apre la creazione di una scheda, **dopo** aver chiesto che forma avra' —
/// 3b-D.2.
///
/// ══ 🚨 LA DOMANDA STA QUI E NON DENTRO L'EDITOR ═══════════════════════════
///
/// 📌 *«Prima di entrare nella vera interfaccia di creazione scheda mi deve
/// chiedere se voglio una scheda single-day o multi-day»*.
///
/// ⚠️ Chiederlo dentro — un interruttore in cima al modulo — vorrebbe dire che
/// chi non e' abbonato scrive tre esercizi e **poi** scopre che quella forma non
/// puo' averla. 💡 Un limite incontrato prima di lavorare e' una regola; lo
/// stesso limite incontrato dopo e' lavoro buttato.
///
/// 🚨 Chi chiude il foglio senza scegliere **non entra**: un editor che si apre
/// lo stesso renderebbe la domanda una formalita' da saltare.
Future<void> nuovaScheda(BuildContext context) async {
  final tipo = await chiediIlTipoDiScheda(context);

  if (tipo == null || !context.mounted) return;

  await context.push(AppRoutes.planNew, extra: tipo);
}

/// Il pulsante che chiede l'analisi, e cosa dice quando non si può — 3b-I.A.
///
/// ══ 🔒 IL PULSANTE C'È ANCHE PER CHI NON PUÒ ══════════════════════════════
///
/// 📌 *«i tasti per fare quella cosa ci devono essere e si deve capire che sono
/// bloccati dietro un abbonamento»*. ⛔ Toccandolo si apre la modale, non un
/// messaggio di errore: un limite che si può superare va mostrato insieme al
/// modo di superarlo.
class _ProgressiDellaScheda extends ConsumerStatefulWidget {
  const _ProgressiDellaScheda({required this.scheda});

  final WorkoutPlan scheda;

  @override
  ConsumerState<_ProgressiDellaScheda> createState() =>
      _ProgressiDellaSchedaState();
}

class _ProgressiDellaSchedaState extends ConsumerState<_ProgressiDellaScheda> {
  bool _inCorso = false;

  /// 🚨 **Una volta sola per apertura della schermata.** ⛔ Senza, ogni
  /// ricostruzione — e ce n'è una a ogni provider che si risolve — riproverebbe.
  bool _giaTentata = false;

  Future<void> _chiedi({bool automatica = false}) async {
    /*
     * ⛔ **L'automatico non apre mai la modale.** ⚠️ Comparirebbe da sola
     * aprendo una scheda, senza che nessuno abbia toccato niente: è la
     * definizione di una finestra invadente. 💡 Chi non è abbonato la card la
     * vede lo stesso, e la modale la apre **toccando**.
     */
    if (!ref.read(puoVedereIProgressiProvider)) {
      if (!automatica) ModaleAcquisti.mostra(context);

      return;
    }

    setState(() => _inCorso = true);

    /*
     * ⚠️ **`ref.read` e non `ref.watch` dentro l'azione**, e il `mounted` dopo
     * l'`await`: questa schermata si può chiudere mentre il modello risponde,
     * e un `setState` su un widget morto è un errore rosso a schermo per una
     * cosa che è andata bene.
     */
    final esito = await chiediLAnalisi(
      ref,
      schedaLocale: widget.scheda.id,
      // ⚠️ Solo quelli che stanno nel catalogo: gli altri non hanno storico
      // (vedi la nota in `EsercizioDellaScheda`), quindi non c'è niente da
      // nominare.
      nomiDegliEsercizi: {
        for (final e in widget.scheda.exercises) ?e.exerciseId: e.name,
      },
      automatica: automatica,
    );

    if (!mounted) return;

    setState(() => _inCorso = false);

    if (esito == EsitoAnalisi.serveAbbonamento) {
      if (!automatica) ModaleAcquisti.mostra(context);

      return;
    }

    /*
     * ⛔ **L'automatico non parla mai.** ⚠️ Un avviso che compare da solo
     * aprendo una scheda — «non è riuscita», «gettoni finiti» — dà la colpa a
     * chi sta guardando per una cosa che non ha chiesto. 💡 Quello che c'è già
     * resta a schermo, e la card dice da quando è aggiornata.
     */
    if (automatica || esito == EsitoAnalisi.fatta) return;

    final spiegazione = _spiegazione(esito);

    if (spiegazione.isEmpty) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(spiegazione)));
  }

  /// 📌 *«deve avvenire in automatico, max 1 volta al giorno per chi è
  /// abbonato»* — 27/08/2026.
  ///
  /// ══ ⚠️ PERCHÉ NON IN `initState` ══════════════════════════════════════
  ///
  /// Perché lì lo storico **non c'è ancora**: arriva da una lettura del
  /// database, e partire prima vorrebbe dire chiedere l'analisi di una scheda
  /// che risulta senza sedute. 🚨 Qui si parte quando i dati ci sono davvero, e
  /// [_giaTentata] garantisce che succeda una volta sola.
  ///
  /// 💡 `addPostFrameCallback` perché una chiamata di rete non si lancia
  /// **dentro** un `build`: il `setState` dell'indicatore arriverebbe mentre
  /// l'albero si sta ancora costruendo.
  void _analisiDaSola() {
    if (_giaTentata) return;

    _giaTentata = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _chiedi(automatica: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final puo = ref.watch(puoVedereIProgressiProvider);

    final storia = ref
        .watch(storiaDellaSchedaProvider(widget.scheda.id))
        .valueOrNull;

    /*
     * ⛔ **Senza storico la card non compare affatto.** 🚨 Non è il gate
     * dell'abbonamento: è che non c'è niente da analizzare, e mostrare un
     * pulsante che risponderà «troppo poco storico» sarebbe un invito a
     * scoprire un rifiuto. 💡 Chi non è abbonato la vede comparire il giorno in
     * cui ha fatto la scheda due volte, che è il momento giusto per proporgliela.
     */
    if (storia == null || !valeLaPenaAnalizzare(storia)) {
      return const SizedBox.shrink();
    }

    final analisi = ref
        .watch(analisiDellaSchedaProvider(widget.scheda.id))
        .valueOrNull;

    /*
     * ⚠️ **Dopo aver letto anche l'analisi, non solo lo storico.** 🚨 Partendo
     * con `analisi` ancora in caricamento, `chiediLAnalisi` la rileggerebbe da
     * capo e non troverebbe niente: si spenderebbe un gettone per riscrivere
     * un'analisi che era già lì.
     */
    if (puo) _analisiDaSola();

    /*
     * ══ ⚠️ L'ARIA, AL SECONDO TENTATIVO — 27/08/2026 ══════════════════════
     *
     * 📌 *«la card "I Tuoi Progressi" è ancora senza aria (controlla con uno
     * screenshot, lo vedi)»*. Ed era vero: guardandola, era **incollata** a
     * «Questa scheda».
     *
     * ⛔ **Il primo tentativo aveva corretto la cosa sbagliata.** Avevo tolto
     * `margin: only(bottom:)` perché azzerava i lati — vero, ma il margine di
     * serie di `Card` è **4 pixel**, e fra due schede vicine fa 8: a schermo
     * non è uno stacco, è un difetto di allineamento.
     *
     * 💡 Adesso `Padding(top: Gap.md)` **fuori** dalla card, come fa
     * `_CosaAllena` due righe più su. 🚨 Il modo giusto era già lì accanto: se
     * avessi guardato lo schermo invece del codice l'avrei visto al primo giro.
     */
    return Padding(
      padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    puo ? Icons.insights_rounded : Icons.lock_rounded,
                    size: 18,
                    color: tema.colorScheme.primary,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'I tuoi progressi',
                      style: tema.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.xs),
              Text(
                puo
                    ? 'Sotto ogni esercizio trovi come è andata nelle ultime '
                          'sedute. L\'analisi si aggiorna da sola quando ti '
                          'alleni, al massimo una volta al giorno.'
                    : 'Con l\'abbonamento vedi l\'andamento di ogni esercizio e '
                          'un\'analisi scritta per te.',
                style: tema.textTheme.bodySmall,
              ),

              /*
               * ══ 🗣️ IL RIASSUNTO — 3b-I.F, 27/08/2026 ══════════════════════
               *
               * 📌 *«Mi deve dire qualcosa di utile, sennò che cazzo lo pago a
               * fare?»*.
               *
               * 🚨 **È la sola cosa che guarda gli esercizi insieme**, e per
               * questo è la più utile: una riga sotto un esercizio, per
               * costruzione, non può dire «cresci sulle spinte e sei fermo sulle
               * trazioni». ⛔ E costa **zero in più**: stessa chiamata, stesso
               * gettone, contesto già tutto davanti al modello.
               *
               * 💡 Sta **sopra** la spiegazione e il pulsante, perché è la cosa
               * per cui si è pagato: la spiegazione dice come funziona, questa è
               * il risultato.
               */
              if (analisi?.riassunto case final r? when r.isNotEmpty) ...[
                const SizedBox(height: Gap.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Gap.sm),
                  decoration: BoxDecoration(
                    color: tema.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(Gap.radiusSm),
                  ),
                  child: Text(
                    r,
                    style: tema.textTheme.bodyMedium?.copyWith(
                      color: tema.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.sm),
              ],

              if (analisi != null) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  /*
                 * 💡 **«Superata» e «vecchia» sono due cose diverse**, ed è il
                 * motivo per cui l'impronta esiste: un'analisi di un mese fa è
                 * ancora vera se da allora non ti sei allenato.
                 */
                  analisi.superata
                      ? 'Da quando è stata scritta hai fatto altre sedute.'
                      : 'Aggiornata al ${_giorno(analisi.fattaIl)}.',
                  style: tema.textTheme.labelSmall?.copyWith(
                    color: analisi.superata
                        ? tema.colorScheme.tertiary
                        : tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],

              const SizedBox(height: Gap.sm),

              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _inCorso ? null : () => _chiedi(),
                  icon: _inCorso
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          puo ? Icons.auto_awesome_rounded : Icons.lock_rounded,
                        ),
                  label: Text(
                    /*
                   * 💰 **Il prezzo sta sul pulsante** — 📌 *«il tasto deve avere
                   * scritto che costa 1 gettone»*.
                   *
                   * 🚨 È l'unico posto onesto per scriverlo: chi tocca sta
                   * spendendo, e leggerlo **dopo** nel saldo è il modo per non
                   * fidarsi più di nessun altro pulsante dell'app.
                   *
                   * ⛔ E non c'è nel percorso automatico: là non c'è niente da
                   * toccare, e il prezzo lo spiega la riga sopra.
                   */
                    analisi == null
                        ? 'Analizza adesso · 1 gettone'
                        : 'Rifai adesso · 1 gettone',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _spiegazione(EsitoAnalisi esito) => switch (esito) {
  EsitoAnalisi.fatta => '',

  // ⛔ Silenzio: l'analisi a schermo è già quella buona, e dirlo sarebbe
  // rispondere a una domanda che nessuno ha fatto.
  EsitoAnalisi.giaAggiornata => '',

  EsitoAnalisi.serveAbbonamento => 'Serve l\'abbonamento.',
  EsitoAnalisi.troppoPocoStorico =>
    'Serve almeno una seconda seduta per avere qualcosa da raccontare.',

  // ⚠️ Si dice **quando**, non «riprova più tardi»: un limite senza una data è
  // indistinguibile da un guasto.
  EsitoAnalisi.troppoPresto =>
    'L\'hai già rifatta oggi: si può di nuovo domani.',
  EsitoAnalisi.senzaGettoni => 'Gettoni finiti.',
  EsitoAnalisi.nonRiuscita => 'Non è riuscita. Riprova fra poco.',
};

String _giorno(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// 📅 L'ingresso alla settimana programmata, in cima alle schede — 27/08/2026.
///
/// ══ ⛔ IL DIFETTO CHE CHIUDE ══════════════════════════════════════════════
///
/// 📌 *«Come faccio a fargli programmare le schede nei giorni?»*.
///
/// 🚨 L'unico ingresso era nella card «Allenamento» della **dashboard**. Chi
/// cerca di programmare le schede però apre la **sezione Allenamento** — quella
/// con Storico, Schede e Foto — e lì non c'era niente. ⛔ Una funzione che
/// esiste e non si trova, per chi guarda, è identica a una che non c'è.
///
/// 💡 **Dice anche cosa c'è già**: senza, sarebbe un pulsante che non promette
/// niente. Con la riga sotto si sa, senza aprirla, se la settimana è vuota o
/// no — e chi ce l'ha piena non ha nessun motivo di entrare.
class _ProgrammaLaSettimana extends ConsumerWidget {
  const _ProgrammaLaSettimana();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final puo = ref.watch(puoProgrammareProvider);

    final settimana =
        ref.watch(settimanaProvider).valueOrNull ?? const <int?>[];

    final quanti = settimana.whereType<int>().length;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: () => context.push(AppRoutes.settimana),
        leading: Icon(
          Icons.event_repeat_rounded,
          color: tema.colorScheme.primary,
        ),
        title: Text(
          'Programma la settimana',
          style: tema.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          /*
           * ⚠️ **Tre frasi e non due.** ⛔ Chi non è abbonato deve leggere
           * *cosa serve*, non «non hai programmato niente» — che sarebbe vero e
           * lo manderebbe a cercare un difetto che non c'è.
           */
          !puo
              ? 'Serve l\'abbonamento'
              : quanti == 0
              ? 'Nessun giorno programmato'
              : '$quanti ${quanti == 1 ? 'giorno' : 'giorni'} a settimana',
          style: tema.textTheme.bodySmall,
        ),
        trailing: Icon(
          puo ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
          size: 20,
          color: puo ? null : tema.colorScheme.error,
        ),
      ),
    );
  }
}
