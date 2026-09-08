import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../dati_salute.dart';
import 'grafico_metrica.dart';

/// Cosa leggiamo dal telefono, e dove finisce — 3b-P.8.1, 22/08/2026.
///
/// ══ 🚨 ERA UNA SCHERMATA, ADESSO STA SOTTO L'IPNOGRAMMA ═══════════════════
///
/// 📌 Il committente: *«questa pagina dovrebbe apparire sotto all'ipnogramma
/// della pagina sonno, quindi non ha molto senso tenerla qui nelle
/// impostazioni, rimuovila e metti tutti i suoi contenuti sotto
/// all'ipnogramma»*.
///
/// 💡 **Ed e' il posto giusto**: chi guarda il proprio sonno e' esattamente chi
/// si sta chiedendo da dove arrivino quei dati. Sepolta nelle impostazioni,
/// questa spiegazione la leggeva solo chi la cercava — cioe' nessuno.
///
/// ── ⛔ Il testo non si accorcia, e non e' una scelta editoriale ──────────
///
/// 🚨 **Health Connect lo pretende.** Google rifiuta la pubblicazione di
/// un'app che chiede questi permessi senza una schermata che spieghi **cosa**
/// legge e **perche'**: e' l'obiettivo dell'intent
/// `ACTION_SHOW_PERMISSIONS_RATIONALE`, e da oggi quell'intent atterra qui,
/// perche' `/salute` rimanda a `/sonno`.
///
/// ⚠️ Chi accorcia questo testo per farci stare meglio la pagina non sta
/// facendo una scelta di grafica: sta togliendo il motivo per cui l'app puo'
/// stare sul negozio.
class CosaLeggiamoDaSalute extends ConsumerWidget {
  const CosaLeggiamoDaSalute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        /*
         * 💡 I due grafici vengono con la spiegazione: erano in cima alla
         * vecchia schermata, e sono la ragione per cui qualcuno la apriva.
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
                /*
                 * ══ 🚨 ERA FALSA, ED È STATA CORRETTA — 22/08/2026 ══════════
                 *
                 * ⛔ **Diceva: «non vengono mandati a nessun servizio di
                 * intelligenza artificiale».** Senza condizioni.
                 *
                 * 🚨 Ma `SettimanaPerIlConsiglio` manda **sonno, HRV, battito e
                 * allenamenti** dentro il contesto del consiglio del giorno, e
                 * da lì vanno al modello. La frase era vera **solo** per chi
                 * non ha dato il consenso separato al recupero
                 * (`sleep_ai_consent_at`), che il server verifica in
                 * `AiController::recuperoDallApp`.
                 *
                 * ⚠️ **Una promessa senza condizioni su un fatto condizionato
                 * non è un'imprecisione: è una dichiarazione falsa**, e la
                 * legge chi sta decidendo se fidarsi. 🚨 Peggio: questa è la
                 * schermata che Android apre per
                 * `ACTION_SHOW_PERMISSIONS_RATIONALE`.
                 *
                 * 💡 Adesso dice cosa succede **di base** e nomina l'unica
                 * eccezione, insieme al posto dove la si governa.
                 */
                const Text(
                  'Sonno, variabilità cardiaca, battito a riposo, calorie '
                  'bruciate e allenamenti vengono letti dal tuo telefono e '
                  'salvati qui dentro. Di base non escono da qui: non li vede '
                  'la tua palestra e non li vede il tuo trainer.',
                ),
                const SizedBox(height: Gap.sm),
                const Text(
                  'L\'unica eccezione è il consiglio del giorno, e solo se '
                  'gliene dai il permesso: in «Privacy e consensi» c\'è un '
                  'consenso a parte — separato da quello per l\'AI — che '
                  'decide se la settimana di sonno e allenamenti entra nel '
                  'consiglio. Se non lo dai, non parte.',
                ),
                const SizedBox(height: Gap.sm),
                /*
                 * 💡 **Anche qui, e non solo in Privacy.** Chi legge questa
                 * pagina sta decidendo se dare un permesso: la garanzia che
                 * serve a decidere deve stare accanto alla frase che descrive
                 * il rischio, non tre schermate più in là.
                 */
                Text(
                  'E anche quando parte, parte come numeri: ore, minuti e '
                  'battiti, senza il tuo nome, la tua email o il tuo account.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: Gap.sm),
                /*
                 * ⚠️ **«spariscono con lei» era incompleto** — 22/08/2026.
                 *
                 * 🚨 Da quando esiste il backup automatico la frase, letta da
                 * sola, spaventa chi ha già una copia e **rassicura chi non ce
                 * l'ha**: chi legge «spariscono» pensa che sia inevitabile e non
                 * va a cercare la copia di sicurezza — che è esattamente la cosa
                 * che gli servirebbe fare.
                 *
                 * 💡 `informativa_privacy.md` lo dice già nel modo giusto:
                 * *«se disinstalla l'app **senza un backup**, questi dati si
                 * perdono»*. Le due frasi adesso combaciano.
                 */
                Text(
                  'Se disinstalli l\'app spariscono con lei, a meno che tu non '
                  'abbia una copia di sicurezza: quella li rimette a posto.',
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
         * ══ 🆕 IL BATTITO DURANTE IL GIORNO — 07/09/2026 ═══════════════════
         *
         * 🚨 **Va detto, ed è il dato più granulare che raccogliamo.** Un
         * campione ogni pochi minuti per tutta la giornata: dice quando ti
         * muovi, quando ti agiti, quando dormi male.
         *
         * ⛔ Presentarlo come «un dettaglio in più del battito a riposo» sarebbe
         * la scorciatoia comoda e disonesta: è un'altra cosa, e chi legge deve
         * poter dire di no proprio a questa.
         */
        const _Voce(
          icona: Icons.timeline_outlined,
          titolo: 'Il battito durante il giorno',
          testo:
              'Serve al Training Effect Index, che conta i minuti passati a uno '
              'sforzo vero. È il dato più fitto che leggiamo: un valore ogni '
              'pochi minuti. Resta sul telefono come tutto il resto.',
        ),
        const _Voce(
          icona: Icons.directions_walk_rounded,
          titolo: 'I passi della giornata',
          testo:
              'Tutti, non solo quelli fatti allenandoti. Da lì stimiamo le '
              'calorie del movimento quotidiano, perché il tuo orologio quelle '
              'non le scrive.',
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
          /*
           * ⚠️ **Era un'affermazione, adesso è una scelta** — 3b-P.2.3,
           * 22/08/2026.
           *
           * 🚨 Da oggi c'è un interruttore in «I tuoi dati» che decide se le
           * bruciate si sommano all'obiettivo. È acceso di default, quindi la
           * frase vecchia resta vera **per quasi tutti** — ⛔ ed è proprio
           * questo che la rende pericolosa: sarebbe falsa solo per chi l'ha
           * spento, cioè per chi ha deciso il contrario e non capirebbe perché
           * l'app gli racconta un'altra cosa.
           */
          testo:
              'Se lo lasci acceso in «I tuoi dati», si sommano al tuo obiettivo '
              'del giorno: mangi in base a quanto ti sei mosso davvero.',
        ),
        const _Voce(
          icona: Icons.fitness_center_outlined,
          titolo: 'Gli allenamenti',
          testo:
              'Corsa, bici, palestra e tutto il resto: finiscono nel tuo '
              'storico anche quando ti alleni senza aprire l\'app, e puoi dire '
              'quale scheda hai fatto.',
        ),

        /*
         * ⚖️ **Tre voci nuove — 08/09/2026**, e non sono decorazione: sono
         * altrettanti permessi in più nel manifest. 🚨 La regola scritta in
         * testa a questa schermata vale per loro come per le altre — Google
         * rifiuta un'app che chiede un permesso senza spiegare qui perché.
         */
        const _Voce(
          icona: Icons.speed_outlined,
          titolo: 'Velocità e dislivello',
          testo:
              'Quanto sei andato veloce e quanti metri hai salito, come li '
              'misura il tuo orologio. Servono al riassunto di un allenamento: '
              'la sua velocità tiene conto delle soste, la nostra no.',
        ),

        /*
         * 🚨 **Il percorso ha una voce SUA, e la più lunga.**
         *
         * ⛔ Metterlo insieme a velocità e dislivello sarebbe stato comodo e
         * sbagliato: quelli sono numeri, questo dice **dove sei stato e a che
         * ora**. E' la cosa più sensibile che l'app legga, e la sola per cui
         * esiste un consenso separato.
         *
         * ⚠️ Le due frasi finali sono una promessa, non una descrizione: se un
         * domani il percorso dovesse uscire dal telefono, si cambiano **prima**
         * del codice che le rende false.
         */
        const _Voce(
          icona: Icons.route_outlined,
          titolo: 'Il percorso di un\'uscita',
          testo:
              'Solo se glielo chiedi tu, uscita per uscita: Android ti mostra '
              'il tracciato e ti domanda se condividerlo. Serve a disegnarne la '
              'forma nello storico, al posto della foto.\n\n'
              'Resta sul telefono e nel tuo backup. Non lo mandiamo a nessuno, '
              'e non lo vede né la tua palestra né l\'AI.',
        ),
        const SizedBox(height: Gap.md),
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(Gap.md),
            child: Text(
              /*
               * ══ 🚨 «DA QUI» NON ERA PIÙ QUI — 22/08/2026, stesso giorno ══
               *
               * ⛔ Diceva *«i dati già salvati li cancelli da qui»*, e fino a
               * stamattina era vero: il pulsante di cancellazione stava nella
               * stessa schermata di questo testo.
               *
               * 🚨 **L'ho rotta io con 3b-P.8**, spostando il collegamento e la
               * cancellazione in «Privacy e consensi». La frase è rimasta dov'era
               * e ha smesso di essere vera nello stesso commit: manda a cercare
               * un pulsante in una pagina che non ce l'ha.
               *
               * ⚠️ **È la forma più insidiosa di frase falsa**: non è nata
               * sbagliata, lo è diventata perché è cambiato *il posto*. Nessun
               * analizzatore vede un «qui» che ha cambiato significato.
               */
              'Non scriviamo niente: chiediamo il permesso di sola lettura. '
              'Puoi revocarlo quando vuoi dalle impostazioni di Health Connect, '
              'e i dati già salvati li cancelli dal tuo profilo, in «Privacy e '
              'consensi».',
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

                /*
                 * ⚠️ **Questo testo diceva una cosa che dal 07/09 non è più
                 * vera.** Spiegava i passi come un extra che Health Connect
                 * pretende per consegnare un allenamento — e finché li
                 * leggevamo solo dentro le sessioni era esatto.
                 *
                 * 🚨 Adesso li leggiamo **tutta la giornata**, e lasciare il
                 * testo di prima vorrebbe dire far credere a qualcuno di aver
                 * concesso una cosa più piccola di quella che ha concesso. ⛔ È
                 * la stessa famiglia della riga che dice «invariato» accanto a
                 * un numero cambiato.
                 */
                const Text(
                  'La distanza serve solo agli allenamenti: Health Connect ne '
                  'consegna uno soltanto se può darci anche quella, e senza '
                  'quel permesso non arriva niente del tutto.\n\n'
                  'I passi invece li leggiamo per tutta la giornata, e ti '
                  'servono a te: sono l\'unico modo che abbiamo di sapere '
                  'quanto ti sei mosso quando non stavi allenandoti. Da lì '
                  'stimiamo le calorie del movimento quotidiano.\n\n'
                  'Il conto delle calorie resta basato solo su quelle bruciate '
                  'con l\'attività, mai sul totale che comprende il metabolismo '
                  'basale — altrimenti ti diremmo che puoi mangiare molto più '
                  'di quanto è vero.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
