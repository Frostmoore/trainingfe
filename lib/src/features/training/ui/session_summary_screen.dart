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
import 'widgets/carosello_dell_allenamento.dart';
import 'widgets/esercizi_fatti.dart';
import 'widgets/foto_dell_allenamento.dart';

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

  /// Il volume totale: serie × ripetizioni × peso.
  ///
  /// È il numero che dice se la seduta è stata più dura della precedente, molto
  /// più del tempo passato in palestra.
  double get _volume {
    var totale = 0.0;

    for (final s in sessione.sets) {
      totale += (s.reps ?? 0) * (s.weight ?? 0);
    }

    return totale;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gruppi = _perEsercizio;

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Text(sessione.titolo, style: theme.textTheme.headlineSmall),
        Text(
          DateFormat('EEEE d MMMM, HH:mm', 'it').format(sessione.startedAt),
          style: theme.textTheme.bodySmall,
        ),

        const SizedBox(height: Gap.lg),

        Row(
          children: [
            _Numero(
              valore: sessione.durationMinutes == null
                  ? '—'
                  : '${sessione.durationMinutes}',
              etichetta: 'minuti',
            ),
            _Numero(valore: '${gruppi.length}', etichetta: 'esercizi'),
            _Numero(valore: '${sessione.sets.length}', etichetta: 'serie'),
            _Numero(
              valore: _volume == 0
                  ? '—'
                  : NumberFormat.compact(locale: 'it').format(_volume),
              etichetta: 'kg totali',
            ),
          ],
        ),

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
        _Calorie(sessione: sessione),

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

        const SizedBox(height: Gap.lg),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: const Text('Fine'),
        ),
        const SizedBox(height: Gap.lg),
      ],
    );
  }

  // 💡 `_kg` se n'è andato con le righe che lo usavano: adesso i chili li
  // formatta `CardEsercizioFatto.kg`, dove stanno anche le serie.
}

/// Le calorie: la stima, e come sostituirla.
class _Calorie extends ConsumerStatefulWidget {
  const _Calorie({required this.sessione});

  final WorkoutSession sessione;

  @override
  ConsumerState<_Calorie> createState() => _CalorieState();
}

class _CalorieState extends ConsumerState<_Calorie> {
  late final _campo = TextEditingController(
    text: widget.sessione.kcal?.toString() ?? '',
  );

  bool _inCorso = false;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  Future<void> _salva(int? kcal) async {
    setState(() => _inCorso = true);

    try {
      await ref.read(sessionActionsProvider).setKcal(widget.sessione.id, kcal);
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.unwrapError(error).message)),
        );
      }
    } finally {
      if (mounted) setState(() => _inCorso = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = widget.sessione;
    final aMano = s.kcalSource == 'manual';

    /*
     * 🆕 FASE 1-bis — quello che ha visto l'orologio nella stessa ora.
     *
     * 🚨 Serve a **non contraddire lo storico**: là la card mostra il numero
     * misurato, qui si mostrava la stima chiamandola «calcolata dagli
     * esercizi». Due schermate, la stessa seduta, due numeri diversi.
     *
     * ⚠️ `valueOrNull` e nessuna rotellina: è un'informazione **accessoria**,
     * e far aspettare il riepilogo per averla sarebbe sproporzionato. Se arriva
     * tardi, arriva al fotogramma dopo.
     */
    final dallOrologio = aMano
        ? null
        : ref.watch(voceDellaSedutaProvider(s.id)).valueOrNull?.kcalDalPolso;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_rounded,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: Gap.sm),
                Text('Calorie bruciate', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: Gap.sm),

            /*
             * 🚨 Si dice **da dove viene** il numero. Senza, non si sa se sia
             * una misura o un'ipotesi — e non si sa se valga la pena
             * correggerlo.
             *
             * 💡 La catena è quella di §5 FASE 1, e le fonti si
             * **sostituiscono**: a mano → orologio → stima.
             */
            if (dallOrologio != null) ...[
              Row(
                children: [
                  Icon(
                    Icons.watch_outlined,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$dallOrologio kcal misurate dal tuo orologio.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'È il numero che conta: la nostra stima '
                '(${s.kcal ?? 0} kcal) serve solo quando l\'orologio non c\'è.',
                style: theme.textTheme.bodySmall,
              ),
            ] else
              Text(
                aMano
                    ? 'Valore inserito da te.'
                    : 'Stima calcolata dagli esercizi, dalla durata e dal tuo peso.',
                style: theme.textTheme.bodySmall,
              ),

            const SizedBox(height: Gap.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _campo,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Calorie',
                      suffixText: 'kcal',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: Gap.sm),
                FilledButton(
                  onPressed: _inCorso
                      ? null
                      : () => _salva(int.tryParse(_campo.text.trim())),
                  child: const Text('Salva'),
                ),
              ],
            ),

            // ⚠️ Rimettere la stima è una funzione a sé, e serve: chi corregge
            // e poi si accorge di aver scritto una sciocchezza, senza questo
            // non ha nessun modo di tornare indietro se non indovinare il
            // numero di prima.
            if (aMano)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _inCorso ? null : () => _salva(null),
                  child: const Text('Rimetti la stima automatica'),
                ),
              ),

            /*
             * ⏸️ **Dall'orologio: non ancora.**
             *
             * Il ponte con il telefono manda solo il sonno; le calorie di un
             * allenamento non arrivano da nessuna parte. Dirlo qui e' meglio
             * che mettere un pulsante che non fa niente — e meglio che tacere,
             * perche' chi ha un orologio si aspetta che il numero arrivi da
             * solo e altrimenti pensa che l'app sia rotta.
             */
            const SizedBox(height: Gap.xs),
            Text(
              'Dall\'orologio non arrivano ancora: quando collegheremo Health '
              'Connect, il valore misurato prenderà il posto della stima.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 💡 `_Foto` se n'è andata in `widgets/foto_dell_allenamento.dart`: la stessa
// card deve stare anche sulla pagina di un allenamento del polso, e una card
// privata dentro una schermata non ci poteva arrivare.

class _Numero extends StatelessWidget {
  const _Numero({required this.valore, required this.etichetta});

  final String valore;
  final String etichetta;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            valore,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            maxLines: 1,
          ),
          Text(
            etichetta,
            style: theme.textTheme.labelSmall,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

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
