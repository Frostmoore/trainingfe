import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../privacy/consensi_controller.dart';
import '../../../privacy/ui/widgets/elenco_dei_consensi.dart';
import '../../health_controller.dart';

/// ⌚ Collegare un dispositivo — 08/09/2026.
///
/// ══ 🚨 NON SI «AGGIUNGE» NIENTE, E LA MODALE DEVE DIRLO ═══════════════════
///
/// 📌 Il committente: *«se io ho uno smartwatch non è che lo devo aggiungere,
/// devo solo chiedere a google health / apple health di darmi i permessi per
/// leggerne i dati, corretto?»* — ✅ **Sì, è esattamente così.**
///
/// 💡 Health Connect è un **magazzino**, non una fonte: ci scrivono Zepp,
/// Garmin, Fitbit, Strava, la bilancia. ⛔ Noi non parliamo con nessun
/// dispositivo, non ne conosciamo il modello, non ci accoppiamo a niente e non
/// abbiamo un elenco di apparecchi supportati — chiediamo al magazzino il
/// permesso di **leggere**.
///
/// 🚨 **Questa modale esiste perché quella verità, detta così, disorienta.**
/// Chi tocca «Dispositivo smart» si aspetta una ricerca Bluetooth e una lista
/// di orologi; trovarsi davanti a un consenso senza spiegazione sembra un
/// errore dell'app. ⚠️ Quindi la prima cosa che si legge è **perché** non c'è
/// niente da cercare.
///
/// ── ⚖️ I due passi, in quest'ordine e non nell'altro ──────────────────────
///
/// | | Chi lo chiede | Cosa decide |
/// |---|---|---|
/// | 1 | **Noi** | Se possiamo trattare i tuoi dati sanitari (art. 9(2)(a)) |
/// | 2 | **Android** | Se il sistema ce li fa leggere |
///
/// ⛔ **Il secondo non sostituisce il primo**, ed è la trappola in cui questo
/// progetto è già caduto l'08/09 con i canali nativi del percorso: il permesso
/// di sistema dice cosa Android ci lascia leggere, non cosa la persona ha
/// acconsentito che noi trattiamo. 🚨 Per questo il pulsante che apre Health
/// Connect **è spento** finché il consenso non c'è.
class ColleghiUnDispositivo extends ConsumerWidget {
  const ColleghiUnDispositivo({super.key});

  static Future<void> mostra(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => const ColleghiUnDispositivo(),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final consensi = ref.watch(consensiProvider);
    final salute = ref.watch(healthControllerProvider);

    /*
     * ⚠️ **`valueOrNull` e non `requireValue`**: mentre i consensi arrivano
     * dalla rete la modale deve già essere leggibile. 🚨 In dubbio la spunta è
     * **spenta**, che è lo stesso verso di `consensoSaluteProvider`: non poter
     * verificare un consenso vale quanto non averlo.
     */
    final dato = consensi.valueOrNull?.saluteDato ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.lg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Collega un dispositivo',
              style: tema.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: Gap.sm),

            /*
             * 🚨 **Questa è la parte che evita l'assistenza.** Senza, la
             * domanda che arriva è «non trova il mio orologio».
             */
            Text(
              'Non c\'è niente da cercare, e non è un limite dell\'app: '
              'il tuo orologio scrive già i suoi dati in Health Connect, '
              'insieme a quelli della bilancia e delle altre app. Quello che '
              'serve è il permesso di leggerli da lì.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: Gap.md),

            const Divider(),
            const SizedBox(height: Gap.sm),

            /*
             * ══ 1. I CONSENSI — TUTTI, NON UNO ════════════════════════════
             *
             * 📌 Il committente: *«il mio consenso non deve essere uno, devono
             * essere tutti i miei consensi, parliamo di dati sanitari, quindi
             * ci devono essere tutti (con sopra il toggle concedi tutto)»*.
             *
             * ⛔ **Prima c'era il solo `health`**, perché è l'unico
             * *tecnicamente* necessario a leggere Health Connect. 🚨 Ma chi
             * collega un orologio sta decidendo cosa fare dei propri dati
             * sanitari **in blocco**: una casella sola gli fa credere che
             * quella sia tutta la decisione, e scopre le altre due dopo, in
             * un'altra schermata. A quel punto la domanda che si fa è
             * «cos'altro non mi avete detto?».
             *
             * 💡 `ElencoDeiConsensi` è **lo stesso widget** della schermata
             * Privacy: un testo solo, due posti che lo mostrano.
             */
            _Passo(
              numero: 1,
              titolo: 'I tuoi consensi',
              fatto: dato,
              figlio: consensi.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(Gap.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  'Non riesco a leggere i tuoi consensi.\n$e',
                  style: tema.textTheme.bodySmall,
                ),
                data: (c) => ElencoDeiConsensi(dati: c),
              ),
            ),

            const SizedBox(height: Gap.sm),

            // ══ 2. Il permesso, che è di Android ═══════════════════════════
            _Passo(
              numero: 2,
              titolo: 'Il permesso di sistema',
              fatto: salute.collegato,
              figlio: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dato
                        ? 'Adesso lo chiede Android: si apre Health Connect e '
                              'decidi tu quali dati farci leggere. Puoi '
                              'toglierli quando vuoi, da lì.'
                        : 'Prima serve il consenso qui sopra: senza, non '
                              'apriamo nemmeno la finestra di Android.',
                    style: tema.textTheme.bodySmall,
                  ),
                  const SizedBox(height: Gap.sm),
                  FilledButton.icon(
                    style: bottonePieno(altezza: 52),
                    /*
                     * ⛔ **Spento senza consenso**, e non è solo coerenza: è la
                     * regola che l'08/09 mancava ai canali nativi del percorso.
                     * Il permesso di sistema **non sostituisce** il consenso.
                     */
                    onPressed: (!dato || salute.inCorso)
                        ? null
                        : () => ref
                              .read(healthControllerProvider.notifier)
                              .collega(),
                    icon: salute.inCorso
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link_rounded),
                    label: Text(
                      salute.collegato
                          ? 'Aggiorna adesso'
                          : 'Apri Health Connect',
                    ),
                  ),
                ],
              ),
            ),

            if (salute.errore != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                salute.errore!,
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ],

            if (salute.collegato) ...[
              const SizedBox(height: Gap.md),
              Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: tema.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      'Collegato. I dati arrivano da soli, anche quando l\'app '
                      'è chiusa da giorni.',
                      style: tema.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un passo numerato, con la spunta quando è fatto.
///
/// 💡 **Il numero serve più della spunta**: dice che i due passi hanno un
/// ordine, e che il secondo non si può fare prima del primo. ⛔ Due riquadri
/// uguali sembrerebbero due opzioni fra cui scegliere.
class _Passo extends StatelessWidget {
  const _Passo({
    required this.numero,
    required this.titolo,
    required this.fatto,
    required this.figlio,
  });

  final int numero;
  final String titolo;
  final bool fatto;
  final Widget figlio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: fatto
              ? tema.colorScheme.primary
              : tema.colorScheme.surfaceContainerHighest,
          child: fatto
              ? Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: tema.colorScheme.onPrimary,
                )
              : Text('$numero', style: tema.textTheme.labelMedium),
        ),
        const SizedBox(width: Gap.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titolo,
                style: tema.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              figlio,
            ],
          ),
        ),
      ],
    );
  }
}
