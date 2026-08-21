import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../dati_salute.dart';
import '../health_controller.dart';
import 'widgets/grafico_metrica.dart';

/// La schermata che spiega **cosa leggiamo e dove finisce** — S3.4.
///
/// 🚨 **Non è cortesia: senza, Google rifiuta la pubblicazione.** Health Connect
/// pretende che l'app dichiari l'uso dei dati e sappia rispondere all'intent
/// `ACTION_SHOW_PERMISSIONS_RATIONALE` — l'`intent-filter` nel manifest apre
/// esattamente questa schermata.
///
/// ⚠️ **E il permesso si chiede DA QUI, non all'avvio.** Chiedere prima che una
/// persona abbia capito a cosa serve è il modo più rapido per farselo negare
/// *per sempre*: su Android un rifiuto ripetuto rende il dialogo non più
/// riproponibile, e da lì l'unica strada è mandare l'utente nelle impostazioni
/// di sistema — cioè perderlo.
///
/// 💡 **La frase che conta è vera**, e per una volta non è una excusatio:
/// *«restano sul tuo telefono»*. Dopo S1 il server non ha nessun endpoint per
/// riceverli, quindi non è una promessa di condotta — è una cosa che il
/// software non è più capace di fare.
class SchermataSalute extends ConsumerStatefulWidget {
  const SchermataSalute({super.key});

  @override
  ConsumerState<SchermataSalute> createState() => _SchermataSaluteState();
}

/// 🚨 **Si collega da sola quando i permessi arrivano** — difetto riferito il
/// 13/08/2026.
///
/// *«Quando dò le autorizzazioni da Health Connect, non voglio dover cliccare
/// su "Collega Health Connect": lo deve fare da solo.»*
///
/// ── Perché prima non lo faceva ────────────────────────────────────────────
///
/// Il permesso si concede **fuori dall'app**: si apre Health Connect, si
/// spuntano le caselle, si torna indietro. ⚠️ Nel frattempo questa schermata è
/// rimasta viva e ferma: era un `ConsumerWidget`, e un widget senza stato non ha
/// modo di accorgersi che l'app è tornata in primo piano. Il permesso c'era già,
/// e l'app continuava a chiedere di collegarsi.
///
/// 💡 `WidgetsBindingObserver` è il pezzo che mancava: al rientro si richiama
/// `aggiornaInSilenzio()`, che **non apre nessun dialogo** — guarda solo se il
/// permesso c'è, e se c'è sincronizza. Chi non l'ha ancora dato non se ne
/// accorge nemmeno.
class _SchermataSaluteState extends ConsumerState<SchermataSalute>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    /*
     * ⚠️ **Anche all'apertura, non solo al rientro.**
     *
     * Ci si arriva anche dal collegamento che Health Connect stesso propone
     * (`ACTION_SHOW_PERMISSIONS_RATIONALE`), e in quel caso l'app non è mai
     * andata in secondo piano: senza questa riga la schermata si aprirebbe
     * dicendo «collega» a chi ha appena concesso tutto.
     *
     * 💡 `addPostFrameCallback` perché toccare un provider durante `initState`
     * modifica lo stato mentre l'albero si sta ancora costruendo.
     */
    WidgetsBinding.instance.addPostFrameCallback((_) => _provaACollegarti());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState stato) {
    // 🚨 Solo al **rientro**: `paused` e `inactive` scattano anche mentre si
    // apre il dialogo di sistema, e reagire lì vorrebbe dire leggere i permessi
    // prima che la persona abbia finito di concederli.
    if (stato == AppLifecycleState.resumed) _provaACollegarti();
  }

  /// ⚠️ Non chiede **niente** a nessuno: se il permesso manca, non succede
  /// nulla. Aprire il dialogo di sistema da qui sarebbe la cosa che
  /// `PonteSalute` vieta — un permesso chiesto prima che si capisca a cosa
  /// serve viene negato, e su Android un rifiuto ripetuto **non si ripropone
  /// più**.
  void _provaACollegarti() {
    if (!mounted) return;

    unawaited(ref.read(healthControllerProvider.notifier).aggiornaInSilenzio());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stato = ref.watch(healthControllerProvider);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Sonno e recupero'),
      body: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          /*
           * 🚨 **I dati stanno in cima, la spiegazione sotto** — richiesta del
           * 12/08/2026.
           *
           * Prima questa schermata era **solo testo**: cosa leggiamo, dove
           * resta, e due pulsanti. Chi ci arrivava dalla scheda Recupero per
           * guardare il proprio HRV trovava un'informativa sulla privacy.
           *
           * ⚠️ La spiegazione resta e non si accorcia — Health Connect la
           * pretende, ed è la promessa su cui si regge tutta la fase S1. Ma
           * viene **dopo** la cosa per cui si è aperta la schermata.
           */
          const GraficoMetrica(metrica: MetricaSalute.hrv),
          const SizedBox(height: Gap.md),
          const GraficoMetrica(metrica: MetricaSalute.battitoARiposo),
          const SizedBox(height: Gap.lg),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.phone_android_rounded,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          'Questi dati restano sul tuo telefono',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  const Text(
                    'Sonno, variabilità cardiaca, battito a riposo, calorie '
                    'bruciate e allenamenti vengono letti dal tuo telefono e '
                    'salvati qui dentro. Non vengono inviati ai nostri server, '
                    'non li vede la tua palestra, non li vede il tuo trainer e '
                    'non vengono mandati a nessun servizio di intelligenza '
                    'artificiale.',
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'Se disinstalli l\'app, spariscono con lei.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Gap.md),
          Text('Cosa leggiamo', style: theme.textTheme.titleSmall),
          const SizedBox(height: Gap.xs),

          const _Voce(
            icona: Icons.bedtime_outlined,
            titolo: 'Le fasi del sonno',
            testo:
                'Per dirti quanto hai dormito davvero e quanto era sonno profondo.',
          ),
          const _Voce(
            icona: Icons.monitor_heart_outlined,
            titolo: 'Variabilità cardiaca (HRV)',
            testo:
                'Confrontata solo con la tua media: un valore assoluto non vuol dire niente.',
          ),
          const _Voce(
            icona: Icons.favorite_outline,
            titolo: 'Battito a riposo',
            testo:
                'Anche questo letto come scostamento dalla tua media, non come voto.',
          ),

          /*
           * 🆕 FASE 1.8→1.10 — le due voci nuove.
           *
           * 🚨 **Vanno dette prima di chiedere il permesso**, non dopo. Questa
           * schermata è quella che convince: se l'elenco di Health Connect
           * mostra «Allenamenti», «Distanza», «Passi» e «Calorie totali» e qui
           * si parlava solo di sonno e battito, la richiesta sembra più larga di
           * quello che si era detto — ed è il modo più rapido per farsela negare
           * **per sempre**, perché su Android un rifiuto ripetuto non si
           * ripropone più.
           */
          const _Voce(
            icona: Icons.local_fire_department_outlined,
            titolo: 'Calorie bruciate con l\'attività',
            testo:
                'Si sommano al tuo obiettivo del giorno, così mangi in base a '
                'quanto ti sei mosso davvero.',
          ),
          const _Voce(
            icona: Icons.fitness_center_outlined,
            titolo: 'Gli allenamenti',
            testo:
                'Corsa, bici, palestra e tutto il resto: finiscono nel tuo '
                'storico anche quando ti alleni senza aprire l\'app, e puoi dire '
                'quale scheda hai fatto.',
          ),

          const SizedBox(height: Gap.md),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(Gap.md),
              child: Text(
                'Non scriviamo niente: chiediamo il permesso di sola lettura. '
                'Puoi revocarlo quando vuoi dalle impostazioni di Health Connect, '
                'e i dati già salvati li cancelli da qui.',
              ),
            ),
          ),

          /*
           * ⚠️ **Perché questo riquadro esiste.** Health Connect chiede anche
           * distanza, passi e calorie totali, e chi legge quella lista si chiede
           * legittimamente perché. La risposta onesta è «li pretende il
           * pacchetto per consegnarci un allenamento completo», e va detta —
           * altrimenti l'unica spiegazione disponibile è quella che uno si
           * immagina da solo.
           *
           * 🚨 E la promessa che c'è scritta è **vera e verificabile**:
           * `PonteSalute` tiene due liste apposta, e un test diventa rosso se
           * qualcuno le unisce.
           */
          const SizedBox(height: Gap.sm),
          Card(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perché ti chiede anche distanza e passi',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: Gap.xs),
                  const Text(
                    'Health Connect consegna un allenamento solo se può darci '
                    'anche la distanza, i passi e le calorie della sessione: '
                    'senza quei permessi non arriva niente del tutto.\n\n'
                    'Il conto delle calorie della giornata resta però basato '
                    'solo su quelle bruciate con l\'attività, mai sul totale '
                    'che comprende il metabolismo basale — altrimenti ti '
                    'diremmo che puoi mangiare molto più di quanto è vero.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: Gap.lg),

          if (stato.errore != null) ...[
            Text(
              stato.errore!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: Gap.sm),
          ],

          FilledButton.icon(
            style: bottonePieno(altezza: 52),
            onPressed: stato.inCorso
                ? null
                : () => ref.read(healthControllerProvider.notifier).collega(),
            icon: stato.inCorso
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_rounded),
            label: Text(
              stato.collegato ? 'Aggiorna adesso' : 'Collega Health Connect',
            ),
          ),

          if (stato.collegato) ...[
            const SizedBox(height: Gap.sm),
            Center(
              child: Text(
                stato.ultimaSincronizzazione == null
                    ? 'Collegato'
                    : 'Ultimo aggiornamento: ${stato.ultimaSincronizzazione}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: Gap.md),

            /*
             * 🚨 La cancellazione sta QUI, accanto al collegamento, e non
             * sepolta nelle impostazioni.
             *
             * Con i dati sul telefono il server non puo' cancellarli per conto
             * di nessuno: se questo pulsante non c'e', l'unico modo di
             * liberarsene e' disinstallare l'app. Il diritto alla cancellazione
             * non puo' dipendere dal disinstallare un'applicazione.
             */
            OutlinedButton.icon(
              style: bottonePieno(),
              onPressed: stato.inCorso
                  ? null
                  : () => _confermaCancellazione(context, ref),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Cancella i dati salvati sul telefono'),
            ),
          ],

          const SizedBox(height: Gap.xl),
        ],
      ),
    );
  }

  Future<void> _confermaCancellazione(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancellare i dati?'),
        content: const Text(
          'Sonno, HRV, battito, calorie e allenamenti salvati su questo telefono '
          'vengono cancellati. '
          'Non si possono recuperare: non ne esiste nessuna copia altrove.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancella'),
          ),
        ],
      ),
    );

    if (conferma != true) return;

    await ref.read(healthControllerProvider.notifier).cancellaTutto();
  }
}

class _Voce extends StatelessWidget {
  const _Voce({required this.icona, required this.titolo, required this.testo});

  final IconData icona;
  final String titolo;
  final String testo;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icona),
    title: Text(titolo, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(testo),
    isThreeLine: true,
  );
}
