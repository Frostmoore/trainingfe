import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/states.dart';
import '../../../nutrition/data/piano_alimentare.dart';
import '../../../training/schede_ricevute_controller.dart';
import '../../diary_controller.dart';

/// «Dal tuo piano alimentare» — G9.1/G9.2.
///
/// ── 🚨 Legge dall'ARCHIVIO LOCALE, non dal server ─────────────────────────
///
/// È la conseguenza diretta di D4: i piani si consegnano via chat cifrata e
/// restano **anonimi**. Il server non sa a chi è stato mandato niente, quindi
/// non c'è nessun «il mio piano» da chiedergli — c'è quello che è arrivato su
/// **questo** telefono.
///
/// ⚠️ Il vecchio `POST /nutrition-plan/meals/{meal}/eaten` faceva la stessa cosa
/// **sul server**, e non può più funzionare: leggeva un piano che dal server è
/// sparito. È stato ritirato in `G9.4`.
///
/// ── 💡 Perché la linguetta esiste solo se c'è un piano ────────────────────
///
/// Una linguetta sempre presente e sempre vuota insegna a ignorarla. Chi non ha
/// mai ricevuto un piano non deve nemmeno vederla.
class DalPianoTab extends ConsumerWidget {
  const DalPianoTab({required this.onScelti, super.key});

  /// Chiamata con gli alimenti che la persona ha scelto di registrare.
  final void Function(List<AlimentoDelPiano>) onScelti;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stato = ref.watch(pianiRicevutiProvider);

    return stato.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Non riesco a leggere i tuoi piani.\n$e')),
      data: (piani) {
        if (piani.isEmpty) {
          /*
           * 💡 **Da qui si importa** — N20. E' il punto in cui la mancanza
           * si sente: chi apre questa scheda un piano lo sta cercando, e chi
           * ce l'ha su carta non ha nessun altro posto dove dirlo.
           */
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const EmptyState(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Nessun piano',
                  message: 'Quando il tuo trainer te ne manda uno, lo trovi qui.',
                ),
                const SizedBox(height: Gap.md),
                FilledButton.tonalIcon(
                  onPressed: () => context.push(AppRoutes.importaPiano),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Ho un piano su PDF: importalo'),
                ),
              ],
            ),
          );
        }

        // 💡 Il più recente: chi ne ha più d'uno segue quello nuovo, e gli altri
        // restano perché li ha pagati (R8) — non perché servano ogni giorno.
        final piano = PianoAlimentare.fromJson(
          json.decode(piani.first.piano) as Map<String, dynamic>,
        );

        return _Piano(piano: piano, onScelti: onScelti);
      },
    );
  }
}

class _Piano extends StatefulWidget {
  const _Piano({required this.piano, required this.onScelti});

  final PianoAlimentare piano;
  final void Function(List<AlimentoDelPiano>) onScelti;

  @override
  State<_Piano> createState() => _PianoState();
}

class _PianoState extends State<_Piano> {
  int _giorno = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final giorni = widget.piano.giorni;

    if (giorni.isEmpty) {
      return const EmptyState(
        icon: Icons.restaurant_menu_outlined,
        title: 'Piano vuoto',
        message: 'Questo piano non ha ancora nessun giorno.',
      );
    }

    final giorno = giorni[_giorno.clamp(0, giorni.length - 1)];

    return ListView(
      padding: const EdgeInsets.all(Gap.md),
      children: [
        Text(widget.piano.nome, style: theme.textTheme.titleMedium),

        const SizedBox(height: Gap.xs),

        _Aderenza(previste: giorno.kcal),

        const SizedBox(height: Gap.sm),

        // ⚠️ La striscia compare solo se i giorni sono più d'uno: su un piano a
        // un giorno sarebbe una scelta fra una cosa sola.
        if (giorni.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < giorni.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: Gap.sm),
                    child: ChoiceChip(
                      selected: i == _giorno,
                      onSelected: (_) => setState(() => _giorno = i),
                      label: Text(
                        giorni[i].nome?.trim().isNotEmpty == true
                            ? giorni[i].nome!
                            : 'Giorno ${i + 1}',
                      ),
                    ),
                  ),
              ],
            ),
          ),

        const SizedBox(height: Gap.sm),

        for (final pasto in giorno.pasti)
          _Pasto(pasto: pasto, onScelti: widget.onScelti),
      ],
    );
  }
}

/// Quanto di oggi corrisponde a quello che il piano prescrive — G9.3 (D4).
///
/// ── 🚨 L'aderenza si calcola QUI, e non e' un ripiego ─────────────────────
///
/// La migration di `nutrition_plans` diceva, nero su bianco, che piano e diario
/// sono **due tabelle** proprio per poter rispondere alla domanda «quanto ha
/// aderito?». ⚠️ Da D4 quella risposta il server non la puo' piu' dare: i piani
/// sono anonimi e lui non sa a chi sia stato mandato niente.
///
/// 💡 **Ma sul telefono ci sono entrambe le meta'**: il piano nell'archivio
/// locale e il diario dall'API. La domanda non e' sparita — ha cambiato posto,
/// e con lei **chi decide se condividerla**. Se l'allievo vuole mostrarla al
/// trainer, gliela manda in chat.
class _Aderenza extends ConsumerWidget {
  const _Aderenza({required this.previste});

  final double previste;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final diario = ref.watch(diaryProvider);

    // ⚠️ Un piano senza kcal non ha niente con cui confrontarsi: meglio non
    // mostrare la riga che mostrare «0 di 0».
    if (previste <= 0) return const SizedBox.shrink();

    return diario.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (giorno) {
        final registrate = giorno.kcal;
        final quota = (registrate / previste).clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Oggi ${registrate.round()} kcal delle ${previste.round()} previste',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: Gap.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: quota, minHeight: 6),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Pasto extends StatelessWidget {
  const _Pasto({required this.pasto, required this.onScelti});

  final PastoDelPiano pasto;
  final void Function(List<AlimentoDelPiano>) onScelti;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    pasto.titolo?.trim().isNotEmpty == true ? pasto.titolo! : 'Pasto',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${pasto.kcal.round()} kcal',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ],
            ),

            const SizedBox(height: Gap.sm),

            for (final alimento in pasto.alimenti)
              _Alimento(alimento: alimento, onScelti: onScelti),

            const SizedBox(height: Gap.sm),

            /*
             * 💡 **«Ho mangiato tutto»** — il gesto per cui questa schermata
             * esiste. Registrare sei alimenti uno per uno è il modo più veloce
             * per smettere di tenere il diario.
             *
             * ⚠️ Registra **solo i principali**: le alternative sono scelte, e
             * una scelta la fa la persona toccando quella che ha mangiato.
             */
            FilledButton.tonalIcon(
              onPressed: () => onScelti(pasto.alimenti),
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Ho mangiato tutto'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Alimento extends StatelessWidget {
  const _Alimento({required this.alimento, required this.onScelti});

  final AlimentoDelPiano alimento;
  final void Function(List<AlimentoDelPiano>) onScelti;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(alimento.descrizione),
          subtitle: alimento.kcal == null
              ? null
              : Text('${alimento.kcal!.round()} kcal'),
          trailing: IconButton(
            onPressed: () => onScelti([alimento]),
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Registra questo',
          ),
        ),

        /*
         * 🚨 **Le alternative si registrano al posto del principale.**
         *
         * È l'unica ragione per cui esistono, ed è anche il motivo per cui da G4
         * hanno le macro: un'alternativa senza kcal non direbbe al diario cosa
         * scrivere — e prima di G4 era esattamente così, un testo in una
         * colonna JSON.
         */
        for (final alt in alimento.alternative)
          Padding(
            padding: const EdgeInsets.only(left: Gap.md),
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Text('oppure', style: theme.textTheme.labelSmall),
              title: Text(alt.descrizione, style: theme.textTheme.bodySmall),
              subtitle: alt.kcal == null ? null : Text('${alt.kcal!.round()} kcal'),
              trailing: IconButton(
                onPressed: () => onScelti([alt]),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                tooltip: 'Registra questa',
              ),
            ),
          ),
      ],
    );
  }
}
