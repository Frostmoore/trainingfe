import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/foto_locale.dart';
import '../../../core/ui/states.dart';
import '../../health/tipo_allenamento.dart';
import '../../progress/progress_controller.dart';
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
                onRefresh: () => aggiornaTutto(context, ref, () {
                  ref.invalidate(sessionsProvider);
                  ref.invalidate(allenamentiDalPolsoProvider);
                }),
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
                /*
                 * 🚨 Si contano i **gruppi**, non le registrazioni — FASE 1-bis.
                 *
                 * 💡 È il numero che rende visibile tutto il lavoro del
                 * raggruppamento: «1 seduta» al posto di «2 sedute» è l'unica
                 * cosa che si nota a colpo d'occhio quando l'app e l'orologio
                 * hanno registrato la stessa ora.
                 */
                '${DateFormat('d MMM', 'it').format(inizio)} – '
                '${DateFormat('d MMM y', 'it').format(fine)}'
                '   ·   ${delle.length} ${delle.length == 1 ? 'seduta' : 'sedute'}',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            /*
             * 💡 Una card sola, che si adatta. Fino al 20/08 erano due classi e
             * uno `switch`: con i gruppi la distinzione non è più «da dove
             * viene» ma «contiene una seduta o no», e una proprietà non merita
             * due gerarchie.
             */
            for (final v in delle) _CardAllenamento(voce: v),
          ],
        );
      },
    );
  }
}

/// Una riga dello storico — FASE 1-bis.
///
/// ── 🚨 Una card sola per due casi che si somigliano ───────────────────────
///
/// Fino al 20/08 erano due classi: la seduta del player e l'allenamento del
/// polso. Con i gruppi la distinzione non è più «da dove viene» — una riga può
/// contenerli **entrambi, più volte** — ma «contiene una seduta o no», e una
/// proprietà non merita due gerarchie.
class _CardAllenamento extends ConsumerWidget {
  const _CardAllenamento({required this.voce});

  final VoceStorico voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final seduta = voce.seduta;

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: ListTile(
        leading: SizedBox(width: 52, height: 52, child: _Miniatura(voce: voce)),
        title: Text(
          _titolo(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_riga1()),

            /*
             * 💡 La riga dell'orologio compare **anche** quando il gruppo ha una
             * seduta: il player sa quali esercizi hai fatto, l'orologio sa
             * quanto ti è costato, e tenerli insieme dice più di quanto ognuno
             * dei due saprebbe dire da solo.
             */
            if (voce.dalPolso.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _RigaOrologio(voce: voce),
              ),

            /*
             * 🚨 **Le riprese si dicono.** Se il gruppo contiene più di una
             * seduta vuol dire che qualcuno ha fermato e ripreso: senza questa
             * riga, la durata del gruppo sembrerebbe sbagliata — «un'ora» per
             * una seduta che sullo storico del server ne dura venti.
             */
            if (voce.sedute.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  voce.sedute.length == 2
                      ? 'ripresa una volta'
                      : 'ripresa ${voce.sedute.length - 1} volte',
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

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
        trailing: seduta != null && seduta.isOpen
            ? FilledButton(
                onPressed: () => _apri(context),
                child: const Text('Riprendi'),
              )
            : _Azioni(voce: voce),
        onTap: () => _apri(context),
      ),
    );
  }

  /// 💡 Il titolo viene dalla seduta quando c'è: è il nome che la persona
  /// riconosce. Solo se non c'è si usa il tipo dell'orologio.
  String _titolo() {
    final seduta = voce.seduta;
    if (seduta != null) return seduta.titolo;

    return TipoAllenamento.da(voce.dalPolso.first.tipo).nome;
  }

  String _riga1() {
    final seduta = voce.seduta;

    return [
      DateFormat('EEE d/MM · HH:mm', 'it').format(voce.quando),

      if (seduta != null && seduta.isOpen)
        'in corso'
      else
        /*
         * ⚠️ La durata del **gruppo**, buchi compresi, non quella della singola
         * seduta. Una seduta fermata alle 18:30 e ripresa alle 18:35 è durata
         * dalle 18:00 alle 19:00: è il tempo che ci hai messo, che è la domanda
         * che si fa chi guarda.
         */
        '${voce.durata.inMinutes} min',

      if (_kcal() != null) '${_kcal()} kcal${_fonteKcal()}',
    ].join(' · ');
  }

  /// Le calorie da mostrare, secondo la catena decisa in §5 FASE 1.
  ///
  /// ══ 🚨 Le fonti si SOSTITUISCONO, non si sommano ════════════════════════
  ///
  /// | Ordine | Fonte |
  /// |---|---|
  /// | 1 | La correzione **a mano**, se c'è |
  /// | 2 | L'**orologio**, che ha misurato |
  /// | 3 | La nostra **stima** (MET × kg × ore) |
  ///
  /// ⚠️ Fino al 20/08 la card mostrava la stima **e sotto** il numero misurato:
  /// due numeri per la stessa ora, senza dire quale valesse. 📌 Il committente:
  /// *«devono essere usati i dati dell'orologio assegnandoli all'allenamento
  /// sull'app»*.
  ///
  /// 🚨 **La correzione a mano resta sopra a tutto**: chi ha scritto un numero
  /// l'ha scritto apposta, e un sensore non lo sconfessa.
  /// ⚠️ **Tutto si somma sul gruppo, da entrambe le parti.** Fino al 20/08 i
  /// tratti dell'orologio si sommavano e le sedute no — si prendeva solo la
  /// prima — e chi si fermava a metà si vedeva contare metà allenamento.
  int? _kcal() {
    if (voce.kcalCorrettaAMano) return voce.kcalDalleSedute;

    return voce.kcalDalPolso ?? voce.kcalDalleSedute;
  }

  String _fonteKcal() {
    if (voce.kcalCorrettaAMano) return ' (a mano)';
    if (voce.kcalDalPolso != null) return ' (dall\'orologio)';
    if (voce.kcalDalleSedute != null) {
      return ' (${voce.seduta!.etichettaKcal})';
    }

    return '';
  }

  /// 🚨 **Una seduta conclusa si GUARDA, non si riapre.**
  ///
  /// Toccando una riga dello storico si finiva nel player: una schermata che
  /// tiene lo schermo acceso, fa partire i recuperi e invita a registrare serie
  /// — su un allenamento di tre giorni fa.
  ///
  /// ⚠️ Se la riga è **solo** dell'orologio non c'è niente da aprire: non ha
  /// esercizi, e una schermata di dettaglio vuota è peggio di nessuna schermata.
  void _apri(BuildContext context) {
    final seduta = voce.seduta;
    if (seduta == null) return;

    context.push(
      seduta.isOpen ? AppRoutes.player(seduta.id) : AppRoutes.riepilogo(seduta.id),
    );
  }
}

/// 💡 La foto della seduta quando c'è, l'icona del tipo quando la riga è solo
/// dell'orologio. ⚠️ Un riquadro vuoto su una corsa sembrerebbe una foto che non
/// si è caricata.
class _Miniatura extends ConsumerWidget {
  const _Miniatura({required this.voce});

  final VoceStorico voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final seduta = voce.seduta;

    if (seduta == null) {
      final tipo = TipoAllenamento.da(voce.dalPolso.first.tipo);

      return DecoratedBox(
        decoration: BoxDecoration(
          color: tema.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(Gap.radiusSm),
        ),
        child: Icon(tipo.icona, color: tema.colorScheme.onSecondaryContainer),
      );
    }

    // 🚨 La miniatura viene dal TELEFONO — S5.3. `sessione.photos` arrivava dal
    // server (C5) e da S5 non c'e' piu': le foto sono file locali.
    final foto = ref.watch(fotoSessioneProvider(seduta.id)).valueOrNull;
    final prima = (foto == null || foto.isEmpty) ? null : foto.first;

    if (prima == null) return const RiquadroFotoAssente();

    return ClipRRect(
      borderRadius: BorderRadius.circular(Gap.radiusSm),
      child: FotoLocale(file: prima.file),
    );
  }
}

/// La riga che dice cosa ha visto l'orologio.
///
/// 💡 Piccola e grigia di proposito: sotto una seduta del player è un
/// **complemento**, non la notizia.
class _RigaOrologio extends StatelessWidget {
  const _RigaOrologio({required this.voce});

  final VoceStorico voce;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    var minuti = 0;
    for (final a in voce.dalPolso) {
      minuti += a.finitoIl.difference(a.iniziatoIl).inMinutes;
    }

    final distanza = voce.distanzaMetri ?? 0;

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
              /*
               * 💡 Quante sessioni ha visto l'orologio: se sono più di una vuol
               * dire che è stato fermato e ripreso, e dirlo spiega perché i
               * minuti qui non tornano con la durata del gruppo.
               */
              voce.dalPolso.length == 1
                  ? 'dall\'orologio'
                  : 'dall\'orologio (${voce.dalPolso.length} tratti)',
              '$minuti min',
              if (distanza > 0) _distanza(distanza),
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

/// I gesti su una riga.
///
/// 🚨 **Un menu e non tre pulsanti.** Sono azioni che si usano di rado — una
/// correzione, un'assegnazione, uno scollegamento — e tre icone su ogni riga
/// renderebbero lo storico un pannello di comando invece di un elenco.
class _Azioni extends ConsumerWidget {
  const _Azioni({required this.voce});

  final VoceStorico voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<_Gesto>(
        icon: const Icon(Icons.more_vert),
        tooltip: 'Altro',
        onSelected: (g) => switch (g) {
          _Gesto.correggiKcal => _correggiKcal(context, ref),
          _Gesto.assegnaScheda => _scegliScheda(context, ref),
          _Gesto.stacca => _stacca(context, ref),
        },
        itemBuilder: (context) => [
          if (voce.seduta != null)
            const PopupMenuItem(
              value: _Gesto.correggiKcal,
              child: ListTile(
                leading: Icon(Icons.local_fire_department_outlined),
                title: Text('Correggi le calorie'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (voce.dalPolso.isNotEmpty)
            const PopupMenuItem(
              value: _Gesto.assegnaScheda,
              child: ListTile(
                leading: Icon(Icons.assignment_outlined),
                title: Text('Assegna una scheda'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          /*
           * 🚨 Lo scollegamento compare **solo quando c'è qualcosa da
           * scollegare**: una riga con una sola registrazione non è un gruppo, e
           * offrire di dividerla sarebbe un comando che non fa niente.
           */
          if (voce.dalPolso.isNotEmpty &&
              (voce.sedute.isNotEmpty || voce.dalPolso.length > 1))
            const PopupMenuItem(
              value: _Gesto.stacca,
              child: ListTile(
                leading: Icon(Icons.call_split),
                title: Text('Non è lo stesso allenamento'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      );

  /// Correzione manuale delle calorie della seduta.
  ///
  /// ⚠️ Svuotare il campo **rimette la stima**, non azzera: è la differenza fra
  /// «non lo so» e «oggi ho bruciato zero», e il backend la rispetta.
  Future<void> _correggiKcal(BuildContext context, WidgetRef ref) async {
    final sessione = voce.seduta;
    if (sessione == null) return;

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
            helperText: voce.kcalDalPolso != null
                // 💡 Se l'orologio ha misurato, la stima non è più il ripiego.
                ? 'Vuoto = usa l\'orologio (${voce.kcalDalPolso})'
                : 'Vuoto = usa la stima (${sessione.kcal ?? 0})',
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

    // 💡 Si assegna al **primo** allenamento del gruppo: è quello che il
    // raggruppamento considera l'inizio, e la card legge da lì.
    final bersaglio = voce.dalPolso.first;

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
                selected: s.id == bersaglio.schedaAssegnata,
                onTap: () => Navigator.of(context).pop(_Scelta(s.id)),
              ),
            if (bersaglio.schedaAssegnata != null) ...[
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
      allenamentoId: bersaglio.id,
      schedaId: scelta.schedaId,
    );
  }

  /// «Non è lo stesso allenamento» — FASE 1-bis.
  ///
  /// ── 🚨 È la contropartita della regola larga ──────────────────────────────
  ///
  /// Dal 20/08 basta **un istante** di sovrapposizione perché due registrazioni
  /// finiscano nella stessa riga. ⚠️ Senza questo comando un raggruppamento
  /// sbagliato — i pesi finiti alle 18:01 e la corsa cominciata alle 18:00 —
  /// farebbe **sparire** un allenamento vero, e non ci sarebbe modo di riaverlo.
  ///
  /// 💡 Si stacca l'**ultimo** allenamento del polso, che è quello che quasi
  /// sempre è di troppo: il gruppo si forma in avanti nel tempo, e l'intruso è
  /// chi è arrivato per ultimo.
  Future<void> _stacca(BuildContext context, WidgetRef ref) async {
    final bersaglio = voce.dalPolso.last;
    final tipo = TipoAllenamento.da(bersaglio.tipo);

    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Non è lo stesso allenamento?'),
        content: Text(
          '«${tipo.nome}» delle '
          '${DateFormat('HH:mm', 'it').format(bersaglio.iniziatoIl)} '
          'diventa un allenamento a sé, e non si unirà più a nessuno.\n\n'
          'Puoi rimetterlo insieme quando vuoi.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Separa'),
          ),
        ],
      ),
    );

    if (conferma != true) return;

    await staccaAllenamento(ref, allenamentoId: bersaglio.id, staccato: true);
  }
}

enum _Gesto { correggiKcal, assegnaScheda, stacca }

/// 💡 Un tipo apposta perché `null` dal bottom sheet vuol dire «ho chiuso senza
/// scegliere», e `_Scelta(null)` vuol dire «togli l'assegnazione». ⚠️ Senza
/// questa distinzione chiudere il foglio cancellerebbe la scheda assegnata.
class _Scelta {
  const _Scelta(this.schedaId);

  final int? schedaId;
}
