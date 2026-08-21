import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/intestazione_app.dart';
import '../../../core/ui/miniatura.dart';
import '../../../core/ui/states.dart';
import '../session_controller.dart';
import '../training_controller.dart';
import 'history_screen.dart';

/// La sezione Allenamento — A5.1, riorganizzata in G6.
///
/// 🚨 **Si apre sullo STORICO, non sulle schede.**
/// Entrando qui la domanda è «quando mi sono allenato l'ultima volta, e come è
/// andata» — non «quali schede ho», che si sa già. Le schede servono in due
/// momenti soli: quando si comincia una seduta (e per quello c'è il pulsante in
/// basso, che le propone) e quando se ne modifica una. Tenerle come pagina
/// principale metteva davanti un elenco che non cambia quasi mai e nascondeva
/// dietro un pulsantino l'unica cosa che cresce ogni settimana.
class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  /// 0 = storico, 1 = schede.
  int _vista = 0;

  @override
  Widget build(BuildContext context) {
    final schede = ref.watch(schedeUniteProvider);

    return Scaffold(
      appBar: IntestazioneApp(
        titolo: 'Allenamento',
        /*
         * ⛔ Niente `BottoneProfilo` fra le azioni — 3b-O.1a.6: sta nella riga
         * d'identita', su ogni pagina.
         */
        // Il selettore sta **nella barra**, sotto il titolo: è la posizione in
        // cui si cerca un cambio di vista, e non ruba una riga al contenuto.
        altezzaSotto: 52,
        sotto: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Storico'),
                  icon: Icon(Icons.history_rounded),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Schede'),
                  icon: Icon(Icons.assignment_outlined),
                ),
              ],
              selected: {_vista},
              onSelectionChanged: (s) => setState(() => _vista = s.first),
              showSelectedIcon: false,
            ),
          ),
        ),
      ),
      // C9: si comincia da qui. Il pulsante è grande e sempre visibile perché
      // «inizia l'allenamento» è l'unica cosa che si fa entrando in palestra.
      floatingActionButton: const _AvviaAllenamento(),
      body: Column(
        children: [
          // 🚨 L'allenamento lasciato a metà si vede **prima di tutto il
          // resto**, in **entrambe** le viste.
          //
          // Prima l'unico segnale era l'etichetta del pulsante in basso, che
          // passava da «Inizia» a «Riprendi»: chi chiudeva l'app nel mezzo di
          // una seduta non aveva modo di capire che quella seduta esisteva
          // ancora, e ne apriva una nuova — lasciando la prima aperta per
          // sempre. Una riga in cima, con dentro il nome e da quanto è aperta,
          // è l'unica cosa che lo rende evidente.
          const _SessioneAperta(),
          Expanded(
            child: _vista == 0
                ? const StoricoAllenamenti()
                : _corpo(context, ref, schede),
          ),
        ],
      ),
    );
  }

  Widget _corpo(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<WorkoutPlan>> schede,
  ) {
    return schede.when(
      loading: () => const LoadingState(),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(schedeUniteProvider),
      ),
      data: (elenco) => elenco.isEmpty
          // 🚨 Il vuoto dice **di chi è la palla**: l'iscritto non può darsi
          // una scheda da solo, e un «nessuna scheda» senza spiegazione lo
          // lascerebbe a chiedersi se l'app è rotta.
          // 🚨 Il vuoto è cambiato con C2: adesso l'iscritto **può** farsi
          // una scheda, quindi il messaggio non deve più dire che dipende
          // dal trainer — sarebbe una bugia che scoraggia dal provarci.
          ? EmptyState(
              icon: Icons.assignment_outlined,
              title: 'Nessuna scheda',
              message:
                  'Il tuo trainer non te ne ha ancora assegnata una, '
                  'ma puoi scrivertene una tu.',
              action: FilledButton.icon(
                onPressed: () => context.push(AppRoutes.planNew),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Crea una scheda'),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => aggiornaTutto(
                context,
                ref,
                () => ref.invalidate(schedeUniteProvider),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 96),
                itemCount: elenco.length + 1,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: Gap.md),
                itemBuilder: (context, index) => index == elenco.length
                    ? OutlinedButton.icon(
                        onPressed: () => context.push(AppRoutes.planNew),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Nuova scheda'),
                      )
                    : _SchedaCard(scheda: elenco[index]),
              ),
            ),
    );
  }
}

/// La riga dell'allenamento lasciato aperto.
///
/// ⚠️ Non disegna niente quando non c'è niente da riprendere — **e nemmeno
/// mentre carica**: una striscia che compare mezzo secondo dopo l'apertura e
/// sposta tutto il contenuto in basso fa premere la cosa sbagliata.
class _SessioneAperta extends ConsumerWidget {
  const _SessioneAperta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aperta = ref.watch(openSessionProvider).valueOrNull;

    if (aperta == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final da = DateTime.now().difference(aperta.startedAt);
    final quanto = da.inHours >= 1
        ? '${da.inHours} h fa'
        : '${da.inMinutes} min fa';

    return Material(
      color: theme.colorScheme.tertiaryContainer,
      child: InkWell(
        onTap: () => context.push(AppRoutes.player(aperta.id)),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.md,
            vertical: Gap.sm,
          ),
          child: Row(
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Allenamento in corso',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                    Text(
                      '${aperta.titolo} · cominciato $quanto',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.sm),
              FilledButton(
                onPressed: () => context.push(AppRoutes.player(aperta.id)),
                child: const Text('Riprendi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchedaCard extends StatelessWidget {
  const _SchedaCard({required this.scheda});

  final WorkoutPlan scheda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(Gap.radius),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _DettaglioScheda(id: scheda.id, nome: scheda.name),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              // C23 — la copertina. Fra sei «Full body A/B/C» e' la sola cosa
              // che le distingue a colpo d'occhio.
              Miniatura(url: scheda.imageUrl, etichetta: scheda.name),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheda.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${scheda.exercisesCount} esercizi',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _DettaglioScheda extends ConsumerWidget {
  const _DettaglioScheda({required this.id, required this.nome});

  final int id;
  final String nome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheda = ref.watch(planDetailProvider(id));

    return Scaffold(
      appBar: IntestazioneApp(
        titolo: nome,
        azioni: [
          // 🚨 Il pulsante compare **solo** se il server dice che è
          // modificabile. Mostrarlo sempre porterebbe l'utente a un 403 su una
          // scheda che il trainer ha scritto per lui: un pulsante che apre una
          // schermata destinata a fallire è peggio di un pulsante assente.
          if (scheda.valueOrNull?.editable ?? false)
            IconButton(
              onPressed: () => context.push(AppRoutes.planEdit(id)),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifica',
            ),
        ],
      ),
      body: scheda.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(
          error: e,
          onRetry: () => ref.invalidate(planDetailProvider(id)),
        ),
        data: (p) => ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            if (p.attribuzione.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.sm),
                child: Text(
                  p.attribuzione,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (p.notes != null && p.notes!.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Text(p.notes!),
                ),
              ),
              const SizedBox(height: Gap.md),
            ],
            for (final e in p.exercises)
              Card(
                margin: const EdgeInsets.only(bottom: Gap.sm),
                child: ListTile(
                  leading: Miniatura(
                    url: e.imageUrl,
                    etichetta: e.name,
                    lato: 44,
                  ),
                  title: Text(
                    e.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    [
                      e.prescription,
                      if (e.restSec != null) 'rec. ${e.restSec}s',
                      if (e.targetWeight != null) '${e.targetWeight} kg',
                    ].where((s) => s.isNotEmpty).join(' · '),
                  ),
                  isThreeLine: e.notes != null && e.notes!.isNotEmpty,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Il pulsante che apre una sessione — C9.
///
/// ⚠️ Se ce n'è una **già aperta** si riprende quella invece di aprirne una
/// nuova: chi chiude l'app a metà seduta altrimenti si ritroverebbe con lo
/// storico pieno di allenamenti monchi.
class _AvviaAllenamento extends ConsumerWidget {
  const _AvviaAllenamento();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aperta = ref.watch(openSessionProvider).valueOrNull;

    return FloatingActionButton.extended(
      // Vedi la nota su `heroTag` in `conversations_screen.dart`.
      heroTag: 'fab-allenamento',
      onPressed: () => _avvia(context, ref, aperta?.id),
      icon: Icon(
        aperta == null ? Icons.play_arrow_rounded : Icons.replay_rounded,
      ),
      label: Text(aperta == null ? 'Inizia' : 'Riprendi'),
    );
  }

  Future<void> _avvia(
    BuildContext context,
    WidgetRef ref,
    int? apertaId,
  ) async {
    if (apertaId != null) {
      await context.push(AppRoutes.player(apertaId));

      return;
    }

    final schede =
        ref.read(schedeUniteProvider).valueOrNull ?? const <WorkoutPlan>[];

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

    try {
      final idScheda = (scelta ?? 0) == 0 ? null : scelta;

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
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.unwrapError(error).message)),
        );
      }
    }
  }
}
