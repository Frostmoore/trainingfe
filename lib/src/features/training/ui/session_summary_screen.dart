import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/states.dart';
import '../data/session_models.dart';
import '../session_controller.dart';
import '../storico_unificato_controller.dart';
import 'widgets/azioni_dell_allenamento.dart';
import 'widgets/calorie_dell_allenamento.dart';
import 'widgets/carosello_dell_allenamento.dart';
import 'widgets/esercizi_fatti.dart';
import 'widgets/foto_dell_allenamento.dart';
import 'widgets/testa_dell_allenamento.dart';

/// Il riepilogo di fine allenamento — G7.
///
/// 🚨 **Il momento in cui si guarda cosa si è fatto è appena finito, non dopo.**
/// Prima l'app chiudeva la sessione e riportava all'elenco: l'allenamento
/// spariva in uno storico e nessuno lo riapriva. Qui invece si vede subito il
/// lavoro fatto, si può aggiungere la foto e correggere le calorie — le tre
/// cose che dopo cinque minuti non fa più nessuno.
///
/// ⚠️ Ci si arriva **dopo** `finish()`, quindi la stima delle calorie c'è già.
/// La schermata la mostra e permette di sostituirla, non di anticiparla.
class SessionSummaryScreen extends ConsumerWidget {
  const SessionSummaryScreen({required this.sessionId, super.key});

  final int sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessione = ref.watch(sessionProvider(sessionId));

    return Scaffold(
      // ⚠️ La freccia indietro **c'è**, e va bene: il player è stato
      // sostituito (`pushReplacement`), quindi tornare indietro porta
      // all'elenco, non a una sessione chiusa. E da G13 a questa schermata si
      // arriva anche dallo storico e dal calendario, dove una schermata senza
      // via d'uscita sarebbe un vicolo cieco.
      appBar: const IntestazioneApp(titolo: 'Allenamento concluso'),
      body: sessione.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(sessionProvider(sessionId)),
        ),
        data: (s) => _Corpo(sessione: s),
      ),
    );
  }
}

class _Corpo extends ConsumerWidget {
  const _Corpo({required this.sessione});

  final WorkoutSession sessione;

  /// Le serie raggruppate per esercizio, nell'ordine in cui sono state fatte.
  ///
  /// ⚠️ `Map` di Dart conserva l'ordine di inserimento: è quello che rende il
  /// riepilogo leggibile come il racconto della seduta invece che come un
  /// elenco alfabetico.
  Map<String, List<LoggedSet>> get _perEsercizio {
    final out = <String, List<LoggedSet>>{};

    for (final s in sessione.sets) {
      out.putIfAbsent(s.exerciseName, () => []).add(s);
    }

    return out;
  }

  // 💡 `_volume` se n'è andato con la riga dei numeri che lo mostrava: i chili
  // sollevati li conta la terza card del carosello, e li conta **sul gruppo**
  // invece che sulla singola seduta.

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gruppi = _perEsercizio;

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        // 📌 *«stesso layout»*: la stessa prima riga della pagina del polso.
        _TestaDiQuestaSeduta(sessione: sessione),

        const SizedBox(height: Gap.lg),

        /*
         * ⛔ **Qui c'era una riga di quattro numeri**, e diceva le stesse cose
         * della terza card del carosello — minuti, serie, chili — a dieci pixel
         * di distanza. 🚨 Due volte lo stesso numero nella stessa schermata è il
         * difetto segnalato due volte dal committente: l'etichetta «consumo» il
         * 21/08, la fiammella il 25/08.
         *
         * 💡 E toglierla è anche ciò che rende questa pagina **identica** a
         * quella di un allenamento del polso: là non poteva esserci, perché
         * senza serie registrate «esercizi» e «serie» sarebbero due trattini.
         */

        /*
         * 📌 *«aggiungere sopra le tre cards a carosello come nella sezione
         * storico, ma limitate allo specifico allenamento»* — 3b-B.20.1.
         *
         * ⚠️ **Serve il gruppo, non la singola seduta**: una seduta fermata per
         * sbaglio e ripresa è *un* allenamento, e le tre card devono parlare di
         * quello. 💡 `voceDelloStoricoProvider` lo trova nello storico già fuso.
         */
        _CaroselloDiQuestaSeduta(sessione: sessione),

        const SizedBox(height: Gap.lg),
        _CalorieDiQuestaSeduta(sessione: sessione),

        const SizedBox(height: Gap.lg),
        FotoDellAllenamento(sedutaId: sessione.id),

        const SizedBox(height: Gap.lg),
        Text('Cosa hai fatto', style: theme.textTheme.titleMedium),
        const SizedBox(height: Gap.sm),

        if (gruppi.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Text(
                'Non hai registrato nessuna serie. La prossima volta tocca «OK» '
                'accanto a ogni serie mentre la fai: è quello che finisce nello '
                'storico e nei grafici.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),

        /*
         * ⛔ **Qui le serie stavano tutte su una riga sola**, separate da un
         * puntino. Con quattro si leggeva a fatica, con sette non si leggeva
         * più — e il numero della serie, che è quello che si cerca per sapere
         * dove si è calati, non c'era proprio.
         *
         * 💡 La card sta in `widgets/esercizi_fatti.dart` e non qui: la stessa
         * deve comparire sulla pagina di un allenamento del polso con una
         * scheda attaccata (B.20.4), e due copie divergono sempre.
         */
        for (final esercizio in raggruppaPerEsercizio(sessione.sets))
          CardEsercizioFatto(esercizio: esercizio),

        /*
         * 🗑️ **Rimuovere l'allenamento sta anche qui** — 3b-B.20.2/B.20.4. La
         * pagina di una seduta dell'app e quella di un allenamento del polso
         * devono poter fare le stesse cose, o «identica» resta una parola.
         */
        const SizedBox(height: Gap.lg),
        _AzioniDiQuestaSeduta(sessione: sessione),

        /*
         * ⛔ **Il pulsante «Fine» se n'è andato.** Faceva `pop()`, cioè quello
         * che fa già la freccia dell'intestazione — e sulla pagina di un
         * allenamento del polso non c'era mai stato. ⚠️ In una schermata che si
         * apre anche dallo storico e dal calendario, un pulsante grande che
         * duplica una freccia è un invito a uscire da una cosa appena aperta.
         */
        const SizedBox(height: Gap.lg),
      ],
    );
  }

  // 💡 `_kg` se n'è andato con le righe che lo usavano: adesso i chili li
  // formatta `CardEsercizioFatto.kg`, dove stanno anche le serie.
}

// 💡 `_Calorie` se n'e' andata in `widgets/calorie_dell_allenamento.dart`:
// lo stesso riquadro deve stare anche sulla pagina di un allenamento del polso,
// e una classe privata dentro una schermata non ci poteva arrivare.

// 💡 `_Numero` se n'e' andato con la riga che lo usava.

/// Le tre card di **questa** seduta — 3b-B.20.1.
///
/// 🚨 **Passa dallo storico fuso invece che dalla seduta**, e non è un giro
/// lungo: una seduta fermata per sbaglio e ripresa sono due righe in archivio e
/// **un** allenamento nella vita di chi l'ha fatto. Le card devono parlare di
/// quello, o i chili sollevati sarebbero solo quelli della prima metà.
///
/// ⚠️ Mentre lo storico carica non si mette uno scheletro: sopra c'è già il
/// titolo e sotto ci sono già i numeri, e una macchia grigia in mezzo che
/// compare per un istante a ogni apertura dà l'idea di una pagina che fatica.
class _CaroselloDiQuestaSeduta extends ConsumerWidget {
  const _CaroselloDiQuestaSeduta({required this.sessione});

  final WorkoutSession sessione;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voci = ref.watch(storicoUnificatoProvider).valueOrNull;

    if (voci == null) return const SizedBox.shrink();

    final voce = voci
        .where((v) => v.sedute.any((s) => s.id == sessione.id))
        .firstOrNull;

    if (voce == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Gap.lg),
      child: CaroselloDellAllenamento(voce: voce),
    );
  }
}

/// Le azioni di **questa** seduta — 3b-B.20.2.
///
/// ⚠️ Passa dallo storico fuso per la stessa ragione del carosello: rimuovere
/// deve portarsi via **tutto il gruppo**, non solo la metà su cui si è aperta la
/// pagina. Una seduta fermata e ripresa sono due righe e un allenamento solo.
class _AzioniDiQuestaSeduta extends ConsumerWidget {
  const _AzioniDiQuestaSeduta({required this.sessione});

  final WorkoutSession sessione;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voci = ref.watch(storicoUnificatoProvider).valueOrNull;

    if (voci == null) return const SizedBox.shrink();

    final voce = voci
        .where((v) => v.sedute.any((s) => s.id == sessione.id))
        .firstOrNull;

    if (voce == null) return const SizedBox.shrink();

    return AzioniDellAllenamento(voce: voce);
  }
}

/// Le calorie di **questa** seduta — 3b-C.4.
///
/// ⚠️ Passa dallo storico fuso come il carosello e le azioni: una seduta fermata
/// e ripresa sono due righe e **un** allenamento, e le calorie da mostrare sono
/// quelle del gruppo.
class _CalorieDiQuestaSeduta extends ConsumerWidget {
  const _CalorieDiQuestaSeduta({required this.sessione});

  final WorkoutSession sessione;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voci = ref.watch(storicoUnificatoProvider).valueOrNull;

    if (voci == null) return const SizedBox.shrink();

    final voce = voci
        .where((v) => v.sedute.any((s) => s.id == sessione.id))
        .firstOrNull;

    if (voce == null) return const SizedBox.shrink();

    return CalorieDellAllenamento(voce: voce);
  }
}

/// L'intestazione di **questa** seduta — 3b-C.4.
class _TestaDiQuestaSeduta extends ConsumerWidget {
  const _TestaDiQuestaSeduta({required this.sessione});

  final WorkoutSession sessione;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voci = ref.watch(storicoUnificatoProvider).valueOrNull;

    final voce = voci
        ?.where((v) => v.sedute.any((s) => s.id == sessione.id))
        .firstOrNull;

    /*
     * ⚠️ **Un ripiego che non fa aspettare.** Mentre lo storico carica il nome e
     * la data si sanno già dalla seduta: lasciare la prima riga vuota per un
     * istante a ogni apertura darebbe l'idea di una pagina che fatica.
     */
    if (voce == null) {
      final tema = Theme.of(context);

      return Row(
        children: [
          Icon(Icons.fitness_center, size: 32, color: tema.colorScheme.primary),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sessione.titolo, style: tema.textTheme.titleLarge),
                Text(
                  DateFormat(
                    'EEEE d MMMM, HH:mm',
                    'it',
                  ).format(sessione.startedAt),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return TestaDellAllenamento(voce: voce);
  }
}
