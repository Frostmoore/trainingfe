import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/avvertenza_nutrizionale.dart';
import '../../../profile/target_locale_controller.dart';
import '../../../profile/ui/widgets/manca_per_il_target.dart';
import '../../data/diary_models.dart';
import '../../diary_controller.dart';

/// Il riepilogo in cima al diario — A4.1.
///
/// 🚨 **Rosso quando si sfora, e la barra non si ferma a fine corsa.**
/// Una barra che si riempie e si blocca al 100% dice «sei arrivato», non «hai
/// superato»: sono due cose diverse e l'utente deve poter distinguere 2.000 su
/// 2.000 da 2.600 su 2.000 con un'occhiata, senza leggere i numeri.
class MacroSummary extends ConsumerWidget {
  const MacroSummary({required this.day, super.key});

  final DiaryDay day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    /*
     * 🚨 **Il diario non guardava affatto il calcolo locale** — difetto riferito
     * il 12/08/2026: *«Non mi mostra il mio obiettivo calorico né in cibo né in
     * Oggi»*.
     *
     * Su «Oggi» il ripiego c'era già (correzione di S7); qui no, e il risultato
     * era che il diario diceva «Nessun obiettivo impostato» **anche a chi
     * l'obiettivo ce l'aveva**, calcolato e mostrato nella schermata accanto.
     *
     * 💡 La precedenza è la stessa di sempre: **il piano del trainer vince sul
     * calcolo**, e il calcolo vince sul nulla (D8).
     */
    final esito = day.hasTarget ? null : ref.watch(targetLocaleProvider).valueOrNull;
    final locale = esito?.target;

    final targetKcal = day.hasTarget
        ? day.targetKcal
        : locale?.kcal.toDouble();

    final haTarget = targetKcal != null && targetKcal > 0;
    final sforato = haTarget && day.kcal > targetKcal;

    // ⚠️ Ricalcolati sull'obiettivo **che si sta mostrando**: `day.progresso` e
    // `day.residuoKcal` guardano quello del server, che quando si usa il calcolo
    // locale non c'è — e darebbero una barra che non c'entra col numero sopra.
    final progresso = haTarget ? day.kcal / targetKcal : 0.0;
    final residuo = haTarget ? targetKcal - day.kcal : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  day.kcal.round().toString(),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: sforato ? theme.colorScheme.error : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: Gap.xs),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    haTarget ? '/ ${targetKcal.round()} kcal' : 'kcal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                // Le bruciate si mostrano perché il target del giorno le
                // comprende già: senza, l'utente vedrebbe un target più alto
                // del solito e non capirebbe perché.
                //
                // C15 — ed è toccabile: il totale bruciato si può dichiarare a
                // mano, per chi porta un orologio che conta meglio della nostra
                // stima o per chi ha fatto qualcosa che non ha registrato.
                ActionChip(
                  avatar: const Icon(Icons.local_fire_department_rounded, size: 16),
                  label: Text('${day.burnedKcal}'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _bruciateAMano(context, ref, day.burnedKcal),
                ),
              ],
            ),

            if (haTarget) ...[
              const SizedBox(height: Gap.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  // `clamp` a 1 solo per il disegno: il colore dice il resto.
                  value: progresso.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: sforato ? theme.colorScheme.error : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: Gap.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sforato
                          ? 'Hai superato di ${(-residuo).round()} kcal'
                          : 'Ti restano ${residuo.round()} kcal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: sforato
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                  // 🚨 D8 / S7.5 — da dove viene il numero. «Calcolato sui tuoi
                  // dati» e «prescritto dal tuo trainer» meritano fiducia
                  // diversa, e il secondo non si discute.
                  Text(
                    day.hasTarget ? 'Dal tuo piano' : 'Calcolato sui tuoi dati',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),

              /*
               * 🚨 N17.2 — l'avvertenza **accanto al numero**, non nei termini
               * d'uso.
               *
               * ⚠️ Solo quando il numero e' il NOSTRO: se l'obiettivo arriva
               * dal piano del trainer, l'avvertenza sulle formule generiche
               * parlerebbe di un calcolo che non abbiamo fatto noi.
               */
              if (!day.hasTarget) const AvvertenzaNutrizionale(compatta: true),
            ] else ...[
              const SizedBox(height: Gap.sm),

              /*
               * 🚨 Si dice **cosa** manca invece di mostrare un numero
               * inventato — che diventerebbe la dieta di qualcuno — e invece di
               * mandare genericamente «a compilare i dati».
               */
              if (esito != null && !esito.riuscito)
                MancaPerIlTarget(esito: esito, compatto: true)
              else
                Text(
                  'Nessun obiettivo impostato. Chiedi al tuo trainer un piano '
                  'alimentare.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],

            const SizedBox(height: Gap.md),

            /*
             * ⚠️ **Anche i macro seguono la stessa precedenza del totale.**
             *
             * Il committente li ha chiesti esplicitamente: *«in cibo,
             * l'obiettivo calorico deve essere anche diviso in
             * macronutrienti»*. Prima venivano **solo** dal server, quindi
             * sparivano insieme al totale per chiunque non avesse un piano.
             *
             * 🚨 Mostrarne uno calcolato accanto a un totale che viene dal
             * piano — o viceversa — darebbe una scheda che si contraddice.
             */
            Row(
              children: [
                _Macro(
                  nome: 'Proteine',
                  valore: day.protein,
                  target: day.targetProtein ?? locale?.macro.proteineG.toDouble(),
                ),
                _Macro(
                  nome: 'Carboidrati',
                  valore: day.carbs,
                  target: day.targetCarbs ?? locale?.macro.carboidratiG.toDouble(),
                ),
                _Macro(
                  nome: 'Grassi',
                  valore: day.fat,
                  target: day.targetFat ?? locale?.macro.grassiG.toDouble(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dichiarare a mano le calorie bruciate del giorno — C15.
///
/// ⚠️ **Svuotare il campo rimette la stima**, non azzera: è la differenza fra
/// «non lo so» e «oggi ho bruciato zero», e il backend la rispetta. Va detto nel
/// modulo, o l'unico modo per scoprirlo è provare.
Future<void> _bruciateAMano(BuildContext context, WidgetRef ref, int attuale) async {
  final controller = TextEditingController(text: attuale > 0 ? attuale.toString() : '');

  final valore = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Calorie bruciate oggi'),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'kcal',
          helperText: 'Vuoto = usa la stima degli allenamenti',
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
      .read(diaryActionsProvider)
      .setDailyBurn(valore.isEmpty ? null : int.tryParse(valore));
}

class _Macro extends StatelessWidget {
  const _Macro({required this.nome, required this.valore, this.target});

  final String nome;
  final double valore;
  final double? target;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            target != null
                ? '${valore.round()} / ${target!.round()} g'
                : '${valore.round()} g',
            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            nome,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
