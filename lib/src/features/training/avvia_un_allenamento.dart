import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/router/app_router.dart';
import '../acquisti/ui/modale_acquisti.dart';
import 'session_controller.dart';
import 'training_controller.dart';

/// 🏋️ Far partire un allenamento — estratta da `plans_screen` l'08/09/2026.
///
/// ══ 🚨 PERCHÉ È USCITA DA LÌ ══════════════════════════════════════════════
///
/// ⛔ **Era un metodo privato di `_AvviaAllenamento`**, cioè del pulsante
/// «Inizia» nella schermata delle schede. 🚨 Dall'08/09 lo stesso gesto si fa
/// anche dal tasto `+` in «Oggi», e copiarlo avrebbe voluto dire **due
/// stesure** di una funzione che contiene tre regole delicate:
///
/// | Regola | Cosa succede se una copia se la dimentica |
/// |---|---|
/// | Le schede bloccate | Ci si allena con una scheda che l'elenco dice bloccata |
/// | `await …future` e non `valueOrNull` | ⛔ Il limite **non scatta mai**, senza nessun errore: è già successo |
/// | `TroppiAllenamentiOggi` | Il limite dell'abbonamento esce come uno snackbar di errore |
///
/// 💡 Le note qui sotto sono quelle originali, spostate insieme al codice: se
/// restassero nella schermata delle schede parlerebbero di un codice che lì non
/// c'è più.

Future<void> avviaUnAllenamento(BuildContext context, WidgetRef ref) async {
  /*
   * ══ 🚨 LA SEDUTA APERTA SI CERCA QUI, NON LA PASSA CHI CHIAMA ═══════════
   *
   * ⛔ **Prima arrivava come parametro**, perché l'unico chiamante era il
   * pulsante «Inizia», che quel valore lo guardava già per scrivere «Riprendi»
   * sulla propria etichetta.
   *
   * 🚨 Dall'08/09 chiama anche il tasto `+` di «Oggi», che non lo guarda: con
   * il parametro avrebbe passato `null` e aperto una **seconda** seduta sopra
   * una già aperta. ⚠️ Due sedute aperte non danno nessun errore — `sedutaAperta()`
   * prende la più recente — e il difetto si vede solo dopo, quando le serie di
   * ieri e di oggi si sono divise fra due allenamenti.
   *
   * 💡 Quindi la domanda se la fa la funzione: chi chiama non deve ricordarsi
   * di niente, e non c'è modo di dimenticarsene.
   *
   * ⚠️ `await …future` e non `valueOrNull`: `openSessionProvider` è
   * `autoDispose`, e chi non lo guarda già lo fa nascere adesso — cioè
   * `AsyncLoading`, cioè `null`, cioè esattamente il difetto che questa stessa
   * funzione ha già avuto con le schede bloccate.
   */
  final aperta = await ref.read(openSessionProvider.future);

  if (aperta != null) {
    if (!context.mounted) return;

    await context.push(AppRoutes.player(aperta.id));

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(bloccate[idScheda]!.spiegazione)));
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
  } on TroppiAllenamentiOggi {
    /*
     * ══ 🔒 IL LIMITE NON E' UN ERRORE, E NON VA MOSTRATO COME TALE ══════
     *
     * 📌 *«un utente non abbonato può far partire dall'app un solo
     * allenamento al giorno»*.
     *
     * ⛔ **Uno snackbar sarebbe stato sbagliato due volte**: sparisce da solo
     * prima che uno abbia finito di leggerlo, e non porta da nessuna parte.
     * 🚨 Chi ha appena premuto «comincia» sta per allenarsi **adesso**: se il
     * modo di sbloccarlo non è a portata di pollice in quel secondo, non lo
     * cerca più.
     *
     * 💡 La modale dice cosa è successo e apre il listino nello stesso posto.
     */
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (dialogo) => AlertDialog(
          icon: const Icon(Icons.lock_rounded),
          title: const Text('Uno al giorno'),
          content: const Text(
            'Senza abbonamento puoi far partire un allenamento al giorno. '
            'Quello di oggi c\'è già, e resta tuo: lo trovi nello storico.\n\n'
            'Con l\'abbonamento non c\'è nessun limite.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(),
              child: const Text('Va bene'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogo).pop();
                ModaleAcquisti.mostra(context);
              },
              child: const Text('Abbonati'),
            ),
          ],
        ),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(error).message)),
      );
    }
  }
}
