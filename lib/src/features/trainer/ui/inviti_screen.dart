import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/states.dart';
import '../data/invito_in_sospeso.dart';
import '../trainer_controller.dart';
import 'invita_qualcuno.dart';

/// 📨 **«Inviti in sospeso»** — blocco B1, 24/09/2026.
///
/// 📌 Il committente, il 23/09: *«trainer e palestre possono proprio fare gli
/// inviti direttamente dall'app… devono poter creare il link di invito e
/// inviarlo per mail o copiarlo»*.
///
/// ══ 🚨 COSA CURA ════════════════════════════════════════════════════════════
///
/// ⛔ **Un invito creato dall'app spariva.** Il link finiva negli appunti e da
/// quel momento non esisteva più: non si rivedeva, non si ricopiava, non si
/// revocava, non si sapeva a chi era stato mandato.
///
/// ⚠️ E ogni invito in piedi **tiene un posto del piano** finché non scade —
/// ed è giusto, è la difesa contro chi manda trenta inviti avendone tre. 🚨 Ma
/// senza questa pagina quel posto non si poteva liberare: un tocco distratto
/// costava **sette giorni** di un posto pagato.
///
/// 💡 È la gemella della pagina del pannello (`InvitoDelTrainerResource`), e fa
/// le stesse tre cose: **copia**, **rimanda**, **revoca**.
class InvitiScreen extends ConsumerWidget {
  const InvitiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stato = ref.watch(invitiProvider);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'Inviti in sospeso'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => InvitaQualcuno.mostra(context),
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Invita'),
      ),
      body: stato.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(invitiProvider),
        ),
        data: (dati) => RefreshIndicator(
          onRefresh: () =>
              aggiornaTutto(context, ref, () => ref.invalidate(invitiProvider)),
          child: dati.inviti.isEmpty
              /*
               * ⚠️ **Il vuoto resta scorrevole**: `ListView` e non `Center`, o
               * il gesto di strisciare in giù non avrebbe niente da afferrare
               * e la pagina sembrerebbe bloccata proprio quando non c'è niente.
               */
              ? ListView(
                  padding: const EdgeInsets.all(Gap.lg),
                  children: const [
                    SizedBox(height: Gap.xl),
                    EmptyState(
                      icon: Icons.mail_outline,
                      title: 'Nessun invito in sospeso',
                      message:
                          'Gli inviti che crei restano qui finché qualcuno li usa '
                          'o finché scadono: da qui li copi, li rimandi o li revochi.',
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(Gap.lg),
                  children: [
                    _Posti(posti: dati.posti),
                    const SizedBox(height: Gap.lg),
                    for (final invito in dati.inviti) _Riga(invito: invito),
                  ],
                ),
        ),
      ),
    );
  }
}

/// I posti del piano, in una riga sola.
///
/// 💡 Sta **sopra l'elenco** perché è la ragione per cui si guarda questa
/// pagina: non «quanti inviti ho mandato», ma «quanti posti mi restano».
class _Posti extends StatelessWidget {
  const _Posti({required this.posti});

  final PostiDegliInviti posti;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rimasti = posti.rimasti;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Row(
          children: [
            const Icon(Icons.event_seat_outlined),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                posti.totali == null
                    ? 'Il tuo piano non mette limiti.'
                    : 'Posti liberi: ${rimasti ?? 0} su ${posti.totali}. '
                          'Contano anche gli inviti in sospeso.',
                style: tema.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Riga extends ConsumerStatefulWidget {
  const _Riga({required this.invito});

  final InvitoInSospeso invito;

  @override
  ConsumerState<_Riga> createState() => _RigaState();
}

class _RigaState extends ConsumerState<_Riga> {
  bool _inCorso = false;

  /*
   * 🚨 **Il campo della finestra «a quale indirizzo?» vive QUI.**
   *
   * ⛔ Prima lo creavo dentro `_chiediIndirizzo()` e lo buttavo via appena la
   * finestra tornava: ma la finestra si sta ancora **chiudendo**, e il suo
   * `TextField` è ancora montato. 💥 Flutter lo dice con
   * *«Failed assertion: `_dependents.isEmpty`»* — un errore che non nomina né
   * il campo né la finestra.
   *
   * 🔍 L'ha trovato un test di widget, non una prova a mano: a schermo
   * l'assertion salta solo in debug.
   */
  final _indirizzo = TextEditingController();

  @override
  void dispose() {
    _indirizzo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final invito = widget.invito;

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.md),
      child: Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              invito.email ?? 'Link da passare a mano',
              style: tema.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: Gap.xs),

            /*
             * 🚨 **«Mandata» solo quando è vero.** `email` dice a chi si voleva
             * mandarlo; `emailInviataIl` dice se è partita. ⚠️ Confonderle
             * farebbe aspettare una mail che non arriverà mai.
             */
            Text(
              [
                if (invito.mandatoPerEmail) 'Mandata per email' else 'Non mandata',
                'scade fra ${invito.giorniRimasti} '
                    '${invito.giorniRimasti == 1 ? 'giorno' : 'giorni'}',
              ].join(' · '),
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Gap.md),

            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _inCorso ? null : _copia,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copia link'),
                ),
                OutlinedButton.icon(
                  onPressed: _inCorso ? null : _rimanda,
                  icon: const Icon(Icons.send, size: 18),
                  label: const Text('Rimanda'),
                ),
                TextButton.icon(
                  onPressed: _inCorso ? null : _revoca,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Revoca'),
                  style: TextButton.styleFrom(
                    foregroundColor: tema.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copia() async {
    await Clipboard.setData(ClipboardData(text: widget.invito.url));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiato.')),
    );
  }

  /// Rimanda la mail. Se l'invito non ha un indirizzo, prima lo si chiede.
  Future<void> _rimanda() async {
    var indirizzo = widget.invito.email;

    if (indirizzo == null || indirizzo.isEmpty) {
      indirizzo = await _chiediIndirizzo();

      if (indirizzo == null || indirizzo.isEmpty) return;
    }

    // ⚠️ Dopo una finestra di dialogo questa riga può non esserci più: si
    //    chiede se siamo ancora vivi prima di toccare il contesto.
    if (!mounted) return;

    setState(() => _inCorso = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      final partita = await ref
          .read(trainerActionsProvider)
          .rimandaInvito(widget.invito.id, email: indirizzo);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            partita
                ? 'Mandata a $indirizzo.'
                : 'Non sono riuscito a mandarla: copia il link e passalo a mano.',
          ),
        ),
      );
    } on Object catch (errore) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  Future<String?> _chiediIndirizzo() async {
    _indirizzo.clear();

    final scritto = await showDialog<String>(
      context: context,
      builder: (contesto) => AlertDialog(
        title: const Text('A quale indirizzo?'),
        content: TextField(
          controller: _indirizzo,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contesto).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contesto).pop(_indirizzo.text.trim()),
            child: const Text('Manda'),
          ),
        ],
      ),
    );

    return scritto;
  }

  /// 🚨 **La revoca si conferma**, e la conferma dice cosa succede davvero:
  /// il link smette di funzionare **e il posto torna libero**.
  Future<void> _revoca() async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (contesto) => AlertDialog(
        title: const Text('Revocare l\'invito?'),
        content: const Text(
          'Il link smette di funzionare subito, e il posto che occupava torna '
          'libero. Chi l\'ha ricevuto non potrà più usarlo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contesto).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contesto).pop(true),
            child: const Text('Revoca'),
          ),
        ],
      ),
    );

    if (conferma != true || !mounted) return;

    setState(() => _inCorso = true);

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(trainerActionsProvider).revocaInvito(widget.invito.id);

      messenger.showSnackBar(
        const SnackBar(content: Text('Invito revocato: il posto è di nuovo libero.')),
      );
    } on Object catch (errore) {
      if (mounted) setState(() => _inCorso = false);

      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    }
  }
}
