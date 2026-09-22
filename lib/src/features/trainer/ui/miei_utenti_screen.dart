import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/states.dart';
import '../../auth/auth_controller.dart';
import '../data/utente_seguito.dart';
import '../trainer_controller.dart';
import 'abbonamento_scaduto.dart';
import 'scelta_del_piano.dart';

/// «I miei utenti» — F5.1 e F6 della Parte B.
///
/// 🚨 **Un trainer si allena anche lui**: questa non è un'app diversa né un
/// secondo accesso. È una sezione in più dentro lo stesso account, raggiunta dal
/// profilo — e chi non segue nessuno non la vede affatto.
class MieiUtentiScreen extends ConsumerWidget {
  const MieiUtentiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /*
     * ── 🚨 Si guarda PRIMA di chiedere — 3b-U.3.1, 29/08/2026 ─────────────
     *
     * 📌 *«è una merda se esce solo un errore, si deve capire che è perché non
     * ha pagato»*.
     *
     * ⛔ `abbonato` arriva da `/me`, quindi l'app **sa già** che il server dirà
     * di no: chiederglielo per poi mostrare un errore è un giro inutile che
     * finisce con la persona che non capisce.
     *
     * ⚠️ **`== false` e non `!= true`**: `null` vuol dire «non lo so» — il
     * profilo non è ancora arrivato, o la rete non va — e un flag che manca non
     * deve chiudere fuori chi ha pagato. È la stessa regola già scritta in
     * `limiti_delle_schede.dart`.
     */
    /*
     * 🐛 `puoFareIlTrainer` e non `abbonato` — giro A6, 22/09/2026: la palestra
     * paga il lavoro del suo trainer, non il suo Plus. Vedi `AppUser.puoAllenare`.
     */
    if (ref.watch(authControllerProvider).user?.puoFareIlTrainer == false) {
      return const Scaffold(
        appBar: IntestazioneApp(titolo: 'I miei utenti'),
        body: AbbonamentoTrainerScaduto(),
      );
    }

    final stato = ref.watch(mieiUtentiProvider);

    return Scaffold(
      appBar: const IntestazioneApp(titolo: 'I miei utenti'),
      body: stato.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          final errore = ApiClient.unwrapError(e);

          /*
           * 🚨 **Il secondo ramo serve, e non è una ridondanza.**
           *
           * Il flag qui sopra può essere vecchio di un'ora: l'abbonamento è
           * scaduto **mentre l'app era aperta**, che è poi il caso più
           * probabile di tutti. ⛔ Senza questo, proprio quel caso mostrerebbe
           * l'errore generico.
           */
          if (errore is AbbonamentoTrainerScadutoException) {
            return AbbonamentoTrainerScaduto(messaggio: errore.message);
          }

          return ErrorState(
            error: errore,
            onRetry: () => ref.invalidate(mieiUtentiProvider),
          );
        },
        data: (dati) => _Elenco(dati: dati),
      ),
    );
  }
}

class _Elenco extends ConsumerWidget {
  const _Elenco({required this.dati});

  final MieiUtenti dati;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () =>
          aggiornaTutto(context, ref, () => ref.invalidate(mieiUtentiProvider)),
      child: ListView(
        padding: const EdgeInsets.all(Gap.md),
        children: [
          /*
           * ══ 🆕 I POSTI LI VEDE CHI CE LI HA — 15/09/2026 ══════════════
           *
           * 📌 *«un trainer di una palestra non serve che veda il banner
           * utenti illimitati, e un trainer indipendente (anche se lavora in
           * una palestra) deve vederlo con il numero di allievi possibili per
           * il suo piano»*.
           *
           * ⛔ A un trainer di sola palestra diceva **«Utenti illimitati»**,
           * perché il limite arrivava `null` e `null` qui vuol dire «senza
           * limite». 🚨 La verità è l'opposto: di posti **suoi** non ne ha
           * nessuno, e gli iscritti li paga la palestra.
           */
          if (dati.posti.allieviPropri) ...[
            _Posti(posti: dati.posti),

            /*
             * 🆕 💳 **Il piano si sceglie da qui** — §9.6, 18/09/2026.
             *
             * ⛔ Prima un trainer non aveva nessun posto dove pagare il suo
             * piano. 💡 Accanto ai posti, perché è guardando i posti che si
             * capisce di volerne di più.
             */
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => SceltaDelPiano.mostra(context),
                icon: const Icon(Icons.credit_card_rounded, size: 18),
                label: const Text('Il tuo piano'),
              ),
            ),
            const SizedBox(height: Gap.sm),
          ],

          if (dati.utenti.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.xl),
              child: Column(
                children: [
                  Icon(
                    Icons.group_add_outlined,
                    size: 56,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: Gap.md),
                  Text(
                    dati.posti.allieviPropri
                        ? 'Non segui ancora nessuno'
                        : "Qui non c'è ancora nessuno",
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Gap.sm),
                  /*
                   * 🆕 ⚠️ **Due vuoti diversi, perché sono due situazioni
                   * diverse.** Chi ha allievi suoi può invitarne; un trainer di
                   * palestra no, e dirgli di invitare qualcuno lo manderebbe a
                   * cercare un pulsante che non ha — gli iscritti li porta la
                   * palestra, e quando ci sono li vede tutti.
                   */
                  Text(
                    dati.posti.allieviPropri
                        ? 'Invita una persona con un link: vale una volta sola '
                              'e scade dopo una settimana.'
                        : 'Quando la palestra avrà degli iscritti li troverai '
                              'qui: sono di tutti i trainer, nessuno deve '
                              'assegnarteli.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...dati.utenti.map((u) => _Riga(utente: u)),

          /*
           * 🆕 ⛔ **E chi non può avere allievi suoi non vede nemmeno il
           * pulsante.** Un trainer di sola palestra lo toccava e riceveva un
           * rifiuto del server: è la stessa regola che vale per l'icona «manda
           * a più persone» nella chat — un pulsante che apre un cartello di
           * scuse è peggio di un pulsante che non c'è.
           */
          if (dati.posti.allieviPropri) ...[
            const SizedBox(height: Gap.lg),
            FilledButton.icon(
              // 🚨 Spento **prima** che qualcuno lo prema: scoprire il limite
              // dopo aver compilato un modulo fa sembrare rotto un vincolo
              // commerciale.
              onPressed: dati.posti.puoInvitare
                  ? () => _invita(context, ref)
                  : null,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Invita una persona'),
            ),
          ],

          if (dati.posti.allieviPropri && !dati.posti.puoInvitare) ...[
            const SizedBox(height: Gap.sm),
            Text(
              'Hai occupato tutti i posti del tuo piano. Per averne di più serve '
              'un piano superiore.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),

            /*
             * 🆕 ⛔ **La frase qui sopra rimandava a un pulsante che non
             * esisteva** — §9.6. Diceva «serve un piano superiore» e lasciava lì
             * il trainer, senza nessun modo di prenderlo.
             */
            OutlinedButton(
              onPressed: () => SceltaDelPiano.mostra(context),
              child: const Text('Scegli un piano superiore'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _invita(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final link = await ref.read(trainerActionsProvider).invita();

      await Clipboard.setData(ClipboardData(text: link));

      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Link copiato. Vale una volta sola e scade fra 7 giorni.',
          ),
        ),
      );
    } on Object catch (errore) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    }
  }
}

/// I posti del piano, in cima.
class _Posti extends StatelessWidget {
  const _Posti({required this.posti});

  final PostiDelTrainer posti;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: Text(
          posti.illimitato
              ? 'Utenti illimitati'
              : '${posti.rimasti ?? 0} posti liberi su ${posti.limite}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        // 💡 Gli inviti ancora validi occupano un posto: senza dirlo, un trainer
        // che ha mandato tre inviti e vede zero utenti non capirebbe perché non
        // può invitarne un quarto.
        subtitle: const Text(
          'Anche gli inviti non ancora accettati occupano un posto.',
        ),
      ),
    );
  }
}

class _Riga extends ConsumerWidget {
  const _Riga({required this.utente});

  final UtenteSeguito utente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: utente.avatarUrl != null
              ? NetworkImage(utente.avatarUrl!)
              : null,
          child: utente.avatarUrl == null
              ? Text(utente.nome.isEmpty ? '?' : utente.nome[0].toUpperCase())
              : null,
        ),
        title: Text(utente.nome),
        subtitle: Text(
          utente.attivo ? utente.email : 'Conversazione chiusa',
          style: utente.attivo
              ? null
              : TextStyle(color: theme.colorScheme.error),
        ),
        /*
         * ══ 🆕 NIENTE PULSANTE SU CHI NON È SUO — 16/09/2026 ═════════════════
         *
         * 🚨 Da quando il trainer vede **tutti** gli iscritti della palestra,
         * questa riga compariva anche per loro — col pulsante «chiudi la
         * conversazione», che sul server risponde **404 «Persona non
         * trovata»**: una persona lì in elenco, dichiarata inesistente.
         *
         * ⚠️ Il no del server è giusto: quel rapporto è della palestra, e non
         * sta al trainer chiuderlo. 💡 Quello che si toglie è la **promessa**,
         * non il permesso.
         */
        trailing: !utente.suo
            ? null
            : IconButton(
                tooltip: utente.attivo
                    ? 'Chiudi la conversazione'
                    : 'Riapri la conversazione',
                /*
           * ══ 🆕 UN'ICONA CHE PARLA DI MESSAGGI — 15/09/2026 ════════════════
           *
           * ⛔ **C'era «pausa» e «riproduci».** Quei due simboli dicono
           * «sospendi» e «riprendi» di *qualcosa che sta andando* — un audio,
           * un timer — e qui invece si apre e si chiude **il canale dei
           * messaggi** con una persona. ⚠️ Visto sull'emulatore il 15/09: due
           * righe con un ⏸ a destra, e nessun modo di sapere cosa facesse
           * senza tenerci il dito sopra per leggere il suggerimento.
           *
           * 💡 Il fumetto barrato lo dice da solo, e sta nella stessa famiglia
           * dell'icona dei Messaggi in fondo allo schermo.
           */
                icon: Icon(
                  utente.attivo
                      ? Icons.speaker_notes_off_outlined
                      : Icons.chat_bubble_outline_rounded,
                ),
                onPressed: () => _cambia(context, ref),
              ),
      ),
    );
  }

  /// 🚨 **Chiede conferma, e la richiesta dice cosa succede davvero.**
  ///
  /// «Disattivare» è una parola che fa pensare a una cancellazione. Qui non si
  /// cancella niente: si chiude il canale dei messaggi, la storia resta, ed è
  /// reversibile. ⚠️ E c'è una cosa che **non** si può fare, e va detta prima:
  /// i piani già ricevuti restano sul telefono di quella persona.
  Future<void> _cambia(BuildContext context, WidgetRef ref) async {
    if (utente.attivo) {
      final conferma = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AlertDialog(
          title: Text('Chiudere la conversazione con ${utente.nome}?'),
          content: const Text(
            'Non potrete più scrivervi, e non potrai mandarle piani nuovi.\n\n'
            'I messaggi già scritti restano, e puoi riaprire quando vuoi. '
            'I piani che le hai già mandato restano sul suo telefono.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Chiudi'),
            ),
          ],
        ),
      );

      if (conferma != true) return;
    }

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(trainerActionsProvider).cambiaStato(utente.id);
    } on Object catch (errore) {
      messenger.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(errore).message)),
      );
    }
  }
}
