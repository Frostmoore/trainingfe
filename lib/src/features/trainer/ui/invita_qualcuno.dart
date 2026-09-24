import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../data/invito_in_sospeso.dart';
import '../trainer_controller.dart';

/// 📨 **«Invita una persona»: copio il link, o lo mando io** — B1, 24/09/2026.
///
/// ══ ⛔ COSA FACEVA PRIMA, E PERCHE' ERA MEZZO GESTO ══════════════════════════
///
/// Il pulsante faceva **una cosa sola**: creava l'invito e metteva il link negli
/// appunti, con la scritta *«Link copiato. Vale una volta sola e scade fra 7
/// giorni»*.
///
/// 🚨 Da quel momento l'invito **non esisteva più da nessuna parte**: non si
/// rivedeva, non si ricopiava, non si revocava. ⚠️ E se prima di incollarlo si
/// copiava qualcos'altro, **quel posto restava occupato sette giorni** — perché
/// un invito valido tiene un posto del piano, ed è giusto che lo faccia.
///
/// 📌 Il committente, il 23/09: *«devono poter creare il link di invito e
/// inviarlo per mail o copiarlo»*. 💡 Due strade, e si sceglie **prima** di
/// consumare il posto — non dopo averlo già consumato.
///
/// ⚠️ **L'API lo permetteva già dal 22/09** (`email` su `POST /trainer/invites`):
/// era l'app a non usarlo.
class InvitaQualcuno extends ConsumerStatefulWidget {
  const InvitaQualcuno({this.chi = ChiInvita.trainer, super.key});

  /// 🆕 Chi sta invitando — B2, 24/09/2026: decide **la rotta** e se compare la
  /// scelta fra iscritto e trainer.
  final ChiInvita chi;

  /// Apre la scheda. Torna `true` se un invito è stato creato davvero.
  static Future<bool> mostra(
    BuildContext context, {
    ChiInvita chi = ChiInvita.trainer,
  }) async {
    final fatto = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.lg),
        child: InvitaQualcuno(chi: chi),
      ),
    );

    return fatto ?? false;
  }

  @override
  ConsumerState<InvitaQualcuno> createState() => _InvitaQualcunoState();
}

class _InvitaQualcunoState extends ConsumerState<InvitaQualcuno> {
  final _email = TextEditingController();
  bool _inCorso = false;

  /// 🆕 Con che cappello entra chi riceve l'invito — B2.
  ///
  /// 💡 **Di serie «iscritto»**, che è il caso di gran lunga più frequente: una
  /// palestra invita trainer una volta ogni tanto e iscritti tutti i giorni.
  RuoloInvitato _ruolo = RuoloInvitato.iscritto;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        Gap.lg,
        0,
        Gap.lg,
        MediaQuery.viewInsetsOf(context).bottom + Gap.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Invita una persona',
            style: tema.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: Gap.sm),

          /*
           * 💡 **Si dice subito che costa un posto.** Il contatore sta nella
           * schermata di prima, ma chi apre questa scheda sta per consumarne
           * uno: scoprirlo dopo è il modo di far sembrare rotto un limite che
           * invece è scritto nel piano.
           */
          Text(
            'L\'invito vale una volta sola e scade fra 7 giorni. '
            'Finché è in piedi tiene occupato un posto del '
            '${widget.chi.sceglieIlRuolo ? 'vostro' : 'tuo'} piano: se sbagli, '
            'puoi revocarlo da «${widget.chi.titolo}».',
            style: tema.textTheme.bodyMedium?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Gap.lg),

          /*
           * 🆕 🏷️ **Iscritto o trainer** — B2, 24/09/2026, e **solo per una
           * palestra**: un trainer indipendente ha una specie sola di allievo.
           *
           * 🚨 Sta **prima dell'email** perché decide **quale posto** si sta
           * per consumare: sceglierlo dopo aver scritto l'indirizzo vorrebbe
           * dire tornare indietro quando il limite che salta non è quello che
           * si stava guardando.
           */
          if (widget.chi.sceglieIlRuolo) ...[
            SegmentedButton<RuoloInvitato>(
              segments: const [
                ButtonSegment(
                  value: RuoloInvitato.iscritto,
                  icon: Icon(Icons.person_outline),
                  label: Text('Iscritto'),
                ),
                ButtonSegment(
                  value: RuoloInvitato.trainer,
                  icon: Icon(Icons.sports_outlined),
                  label: Text('Trainer'),
                ),
              ],
              selected: {_ruolo},
              onSelectionChanged: _inCorso
                  ? null
                  : (scelta) => setState(() => _ruolo = scelta.first),
            ),
            const SizedBox(height: Gap.lg),
          ],

          TextField(
            controller: _email,
            enabled: !_inCorso,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email (facoltativa)',
              helperText: 'Se la scrivi, il link glielo mando io.',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            onSubmitted: (_) => _crea(manda: true),
          ),
          const SizedBox(height: Gap.lg),

          FilledButton.icon(
            onPressed: _inCorso ? null : () => _crea(manda: true),
            icon: const Icon(Icons.send),
            label: const Text('Crea e manda per email'),
          ),
          const SizedBox(height: Gap.sm),

          OutlinedButton.icon(
            onPressed: _inCorso ? null : () => _crea(manda: false),
            icon: const Icon(Icons.link),
            label: const Text('Crea e copia il link'),
          ),
        ],
      ),
    );
  }

  /// Crea l'invito. Con `manda` si pretende l'email, senza si copia il link.
  Future<void> _crea({required bool manda}) async {
    final indirizzo = _email.text.trim();

    if (manda && indirizzo.isEmpty) {
      /*
       * ⛔ **Non si crea l'invito e poi si dice «però scrivi l'email»**: quello
       * consumerebbe un posto per un gesto che la persona non ha finito.
       */
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Scrivi l\'email, oppure scegli «Crea e copia il link».',
          ),
        ),
      );

      return;
    }

    setState(() => _inCorso = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final invito = await ref
          .read(trainerActionsProvider)
          .invita(
            email: manda ? indirizzo : null,
            chi: widget.chi,
            ruolo: _ruolo,
          );

      /*
       * 🚨 **Il link finisce negli appunti in tutti e due i casi.** Anche
       * quando la mail parte: se non arriva — spam, indirizzo sbagliato — chi
       * invita ha già in mano il link da mandare a mano, senza dover tornare
       * indietro a cercarlo.
       */
      await Clipboard.setData(ClipboardData(text: invito.url));

      navigator.pop(true);

      messenger.showSnackBar(
        SnackBar(
          content: Text(switch ((manda, invito.emailInviata)) {
            (true, true) =>
              'Mandata a $indirizzo. Il link è anche negli appunti.',
            /*
               * ⚠️ **Non si mente quando l'invio fallisce.** L'invito resta
               * valido di proposito — il link c'è — ma dire «mandata» farebbe
               * aspettare una mail che non arriverà mai.
               */
            (true, false) =>
              'Invito creato, ma la mail non è partita: il link è negli appunti.',
            _ => 'Link copiato. Vale una volta sola e scade fra 7 giorni.',
          }),
        ),
      );
    } on Object catch (errore) {
      setState(() => _inCorso = false);

      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    }
  }
}
