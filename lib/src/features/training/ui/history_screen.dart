import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/storage/archivio_salute.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/foto_locale.dart';
import '../../../core/ui/states.dart';
import '../../health/tipo_allenamento.dart';
import '../../progress/progress_controller.dart';
import '../data/session_models.dart';
import '../data/storico_unificato.dart';
import '../schede_ricevute_controller.dart';
import '../session_controller.dart';
import '../storico_unificato_controller.dart';

/// Lo storico degli allenamenti — C10.
///
/// Raggruppato **per settimana** come nell'app storica: la domanda che ci si
/// fa guardandolo è «quante volte mi sono allenato questa settimana», e un
/// elenco piatto di date costringe a contarle a mano.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Storico allenamenti')),
    body: const StoricoAllenamenti(),
  );
}

/// Lo storico **senza Scaffold**, per poterlo mettere dentro un'altra schermata.
///
/// ⚠️ Da G6 vive dentro la sezione Allenamento, sotto il selettore
/// Storico/Schede. `HistoryScreen` resta come rotta a sé perché ci si arriva
/// anche dalla scheda «Allenamento» del riepilogo di oggi, dove una schermata
/// propria con il suo titolo è la cosa giusta.
class StoricoAllenamenti extends ConsumerWidget {
  const StoricoAllenamenti({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /*
     * 🆕 FASE 1.10 — non più `sessionsProvider`, ma lo storico **fuso**.
     *
     * 🚨 Perché una corsa registrata dall'orologio è un allenamento, e prima di
     * oggi non compariva da nessuna parte: *«molta gente probabilmente o non
     * userà l'app quando si allena o non userà l'orologio»*.
     *
     * ⚠️ La fusione non è concatenazione: chi si allena con l'app aperta **e**
     * l'orologio al polso registra la stessa ora due volte, e le due
     * registrazioni vanno riconosciute come una. Vedi `StoricoUnificato`.
     */
    final voci = ref.watch(storicoUnificatoProvider);

    return voci.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
          error: ApiClient.unwrapError(e),
          onRetry: () => ref.invalidate(storicoUnificatoProvider),
        ),
        data: (lista) => lista.isEmpty
            ? const EmptyState(
                icon: Icons.fitness_center_rounded,
                title: 'Nessun allenamento',
                message: 'Quando ne registri uno lo ritrovi qui, settimana per settimana.',
              )
            : RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(sessionsProvider);
                  ref.invalidate(allenamentiDalPolsoProvider);
                },
                child: _PerSettimana(voci: lista),
              ),
    );
  }
}

class _PerSettimana extends StatelessWidget {
  const _PerSettimana({required this.voci});

  final List<VoceStorico> voci;

  /// Il lunedì della settimana di una data.
  ///
  /// 🚨 **`d` dev'essere già locale** — A3. `DateTime(y, m, d)` costruisce una
  /// data nel fuso del telefono, ma legge `year`/`month`/`day` **dall'oggetto
  /// che riceve**: su un `DateTime` in UTC quei campi sono i componenti UTC, e
  /// una seduta di lunedì alle 00:30 finiva raggruppata nella settimana prima.
  ///
  /// ⚠️ Il `.toLocal()` sta a monte, in `WorkoutSession.fromJson`: qui non si
  /// rimedia, perché rimediare due volte nasconde dove sta la regola.
  static DateTime _lunedi(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  @override
  Widget build(BuildContext context) {
    final gruppi = <DateTime, List<VoceStorico>>{};

    for (final v in voci) {
      gruppi.putIfAbsent(_lunedi(v.quando), () => []).add(v);
    }

    final settimane = gruppi.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(Gap.md),
      itemCount: settimane.length,
      itemBuilder: (context, i) {
        final inizio = settimane[i];
        final fine = inizio.add(const Duration(days: 6));
        final delle = gruppi[inizio]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.sm),
              child: Text(
                '${DateFormat('d MMM', 'it').format(inizio)} – '
                '${DateFormat('d MMM y', 'it').format(fine)}'
                '   ·   ${delle.length} ${delle.length == 1 ? 'seduta' : 'sedute'}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final v in delle)
              switch (v) {
                /*
                 * 💡 `switch` esaustivo su una gerarchia `sealed`: se domani
                 * nasce una terza origine — un allenamento inserito a mano — il
                 * compilatore ferma qui invece di lasciarla sparire dallo
                 * schermo senza un errore.
                 */
                VoceSeduta() => _CardSessione(voce: v),
                VoceOrologio() => _CardOrologio(voce: v),
              },
          ],
        );
      },
    );
  }
}

class _CardSessione extends ConsumerWidget {
  const _CardSessione({required this.voce});

  final VoceSeduta voce;

  WorkoutSession get sessione => voce.sessione;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🚨 La miniatura viene dal TELEFONO — S5.3. `sessione.photos` arrivava
    // dal server (C5) e da S5 non c'e' piu': le foto sono file locali.
    final foto = ref.watch(fotoSessioneProvider(sessione.id)).valueOrNull;
    final prima = (foto == null || foto.isEmpty) ? null : foto.first;

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ListTile(
        // La miniatura è ciò che rende lo storico leggibile a colpo d'occhio:
        // per questo il backend la manda già nell'elenco (C5).
        leading: SizedBox(
          width: 52,
          height: 52,
          child: prima == null
              ? const RiquadroFotoAssente()
              : ClipRRect(
                  borderRadius: BorderRadius.circular(Gap.radiusSm),
                  child: FotoLocale(file: prima.file),
                ),
        ),
        title: Text(
          sessione.titolo,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                DateFormat('EEE d/MM · HH:mm', 'it').format(sessione.startedAt),
                if (sessione.isOpen)
                  'in corso'
                else if (sessione.durationMinutes != null)
                  '${sessione.durationMinutes} min',
                if (sessione.kcal != null) '${sessione.kcal} kcal (${sessione.etichettaKcal})',
              ].join(' · '),
            ),

            /*
             * 🆕 FASE 1.10 — l'orologio che ha visto la stessa ora.
             *
             * 🚨 **Non è un doppione da nascondere**: è la stessa cosa vista da
             * due strumenti. Il player sa quali esercizi hai fatto, l'orologio
             * sa quanto ti è costato. Una riga sola che li tiene insieme dice
             * più di quanto ognuno dei due saprebbe dire.
             *
             * ⚠️ E soprattutto: **non fa numero a parte**. Prima di questa
             * fusione la settimana avrebbe contato due sedute dove ce n'è stata
             * una.
             */
            if (voce.orologio != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _RigaOrologio(allenamento: voce.orologio!),
              ),
          ],
        ),
        isThreeLine: voce.orologio != null,
        trailing: sessione.isOpen
            ? FilledButton(
                onPressed: () => _apri(context),
                child: const Text('Riprendi'),
              )
            : IconButton(
                onPressed: () => _correggiKcal(context, ref),
                icon: const Icon(Icons.local_fire_department_outlined),
                tooltip: 'Correggi le calorie',
              ),
        onTap: () => _apri(context),
      ),
    );
  }

  /// 🚨 **Una seduta conclusa si GUARDA, non si riapre.**
  ///
  /// Toccando una riga dello storico si finiva nel player: una schermata che
  /// tiene lo schermo acceso, fa partire i recuperi e invita a registrare
  /// serie — su un allenamento di tre giorni fa. Non ha senso, e il rischio è
  /// di sporcare una seduta chiusa con dati di oggi.
  ///
  /// Il player resta per quella **ancora aperta**: lì «riprendi» è esattamente
  /// ciò che si vuole, ed è il pulsante che la riga mostra al suo posto.
  ///
  /// ⚠️ `context.push` di go_router, **non** `Navigator.pushNamed`: il
  /// `Navigator` di un'app con go_router non ha nessun `onGenerateRoute`, e una
  /// rotta con nome lancia sempre.
  void _apri(BuildContext context) => context.push(
    sessione.isOpen
        ? AppRoutes.player(sessione.id)
        : AppRoutes.riepilogo(sessione.id),
  );

  /// Correzione manuale delle calorie.
  ///
  /// ⚠️ Svuotare il campo **rimette la stima**, non azzera: è la differenza fra
  /// «non lo so» e «oggi ho bruciato zero», e il backend la rispetta.
  Future<void> _correggiKcal(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
      text: sessione.kcalSource == 'manual' ? sessione.kcal?.toString() ?? '' : '',
    );

    final valore = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calorie bruciate'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'kcal',
            helperText: 'Vuoto = usa la stima (${sessione.kcal ?? 0})',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Salva'),
          ),
        ],
      ),
    );

    if (valore == null) return;

    await ref
        .read(sessionActionsProvider)
        .setKcal(sessione.id, valore.isEmpty ? null : int.tryParse(valore));
  }
}

/// La riga che dice cosa ha visto l'orologio — FASE 1.10.
///
/// 💡 Piccola e grigia di proposito: sotto una seduta del player è un
/// **complemento**, non la notizia. Sopra una card sua invece è tutto quello che
/// c'è, e infatti lì la si legge da sola.
class _RigaOrologio extends StatelessWidget {
  const _RigaOrologio({required this.allenamento});

  final AllenamentoDaOrologio allenamento;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final minuti = allenamento.finitoIl.difference(allenamento.iniziatoIl).inMinutes;

    return Row(
      children: [
        Icon(
          Icons.watch_outlined,
          size: 14,
          color: tema.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            [
              'dall\'orologio',
              '$minuti min',
              /*
               * ⚠️ Le calorie della **sessione**, non della giornata: vengono da
               * `TotalCaloriesBurnedRecord` e comprendono il metabolismo basale
               * del periodo. Su un'ora è una manciata di kcal e descrive bene
               * quella seduta — ma non si somma da nessuna parte. Vedi la nota
               * su `AllenamentiDaOrologio.kcal`.
               */
              if (allenamento.kcal != null) '${allenamento.kcal} kcal',
              if ((allenamento.distanzaMetri ?? 0) > 0)
                _distanza(allenamento.distanzaMetri!),
            ].join(' · '),
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// 💡 Sotto il chilometro si scrivono i metri: «0,2 km» per una camminata in
  /// palestra sarebbe una precisione finta.
  static String _distanza(int metri) => metri < 1000
      ? '$metri m'
      : '${(metri / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Un allenamento che esiste **solo** perché l'orologio l'ha registrato.
///
/// ── 🚨 Perché sta nello stesso elenco delle sedute ────────────────────────
///
/// Perché è un allenamento. *«Se un utente si vuole allenare è fighissimo fare
/// in modo che possa registrare sia una corsetta che un allenamento in palestra
/// che — che ne so — un allenamento in bicicletta»*: tenerli in due liste
/// diverse vorrebbe dire chiedere a chi guarda di sommare a mente.
class _CardOrologio extends ConsumerWidget {
  const _CardOrologio({required this.voce});

  final VoceOrologio voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final allenamento = voce.allenamento;
    final tipo = TipoAllenamento.da(allenamento.tipo);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ListTile(
        leading: SizedBox(
          width: 52,
          height: 52,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: tema.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(Gap.radiusSm),
            ),
            child: Icon(tipo.icona, color: tema.colorScheme.onSecondaryContainer),
          ),
        ),
        title: Text(
          tipo.nome,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEE d/MM · HH:mm', 'it').format(allenamento.iniziatoIl)),
            _RigaOrologio(allenamento: allenamento),

            /*
             * 💡 La scheda assegnata si vede **senza aprire niente**: è
             * l'informazione che questa persona ha aggiunto di sua mano, ed è
             * l'unica cosa in questa riga che non viene da un sensore.
             */
            if (voce.scheda != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 14,
                      color: tema.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        voce.scheda!.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        isThreeLine: true,
        trailing: IconButton(
          onPressed: () => _scegliScheda(context, ref),
          icon: const Icon(Icons.assignment_outlined),
          tooltip: 'Assegna una scheda',
        ),
        onTap: () => _scegliScheda(context, ref),
      ),
    );
  }

  /// «Ok, ho fatto questa scheda» — la richiesta del 19/08.
  ///
  /// ⚠️ **Si può sempre togliere.** Una scelta che non si disfa è una trappola,
  /// e qui è facilissimo toccare la riga sbagliata: le corse di due giorni
  /// diversi si somigliano molto.
  Future<void> _scegliScheda(BuildContext context, WidgetRef ref) async {
    final schede = await ref.read(schedeRicevuteProvider.future);

    if (!context.mounted) return;

    if (schede.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Non hai ancora nessuna scheda da assegnare. '
            'Quelle che crei o che ricevi dal trainer compaiono qui.',
          ),
        ),
      );

      return;
    }

    final scelta = await showModalBottomSheet<_Scelta>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.sm),
              child: Text(
                'Che scheda hai fatto?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final s in schede)
              ListTile(
                leading: const Icon(Icons.assignment_outlined),
                title: Text(s.nome),
                selected: s.id == voce.allenamento.schedaAssegnata,
                onTap: () => Navigator.of(context).pop(_Scelta(s.id)),
              ),
            if (voce.allenamento.schedaAssegnata != null) ...[
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Togli l\'assegnazione'),
                onTap: () => Navigator.of(context).pop(const _Scelta(null)),
              ),
            ],
          ],
        ),
      ),
    );

    if (scelta == null) return;

    await assegnaSchedaAllAllenamento(
      ref,
      allenamentoId: voce.allenamento.id,
      schedaId: scelta.schedaId,
    );
  }
}

/// 💡 Un tipo apposta perché `null` dal bottom sheet vuol dire «ho chiuso senza
/// scegliere», e `_Scelta(null)` vuol dire «togli l'assegnazione». ⚠️ Senza
/// questa distinzione chiudere il foglio cancellerebbe la scheda assegnata.
class _Scelta {
  const _Scelta(this.schedaId);

  final int? schedaId;
}
