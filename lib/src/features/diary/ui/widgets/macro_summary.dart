import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/ui/avvertenza_nutrizionale.dart';
import '../../../health/health_controller.dart';
import '../../../profile/target_locale_controller.dart';
import '../../../profile/ui/widgets/manca_per_il_target.dart';
import '../../../training/bruciate_locali.dart';
import '../../data/bruciate_del_giorno.dart';
import '../../data/diary_models.dart';
import '../../data/target_del_giorno.dart';
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
    final esito = day.hasTarget
        ? null
        : ref.watch(targetLocaleProvider).valueOrNull;
    final locale = esito?.target;

    /*
     * 🆕 **La catena delle bruciate** — FASE 1: manuale → orologio → stima.
     *
     * 🚨 Le calorie di Google Health **non escono dal telefono**: si leggono
     * dall'archivio locale e la somma si fa qui, a runtime. Il server non le
     * vede.
     *
     * 💡 `valueOrNull ?? 0` e non un caricamento bloccante: se l'archivio non
     * ha ancora risposto si mostra la stima, e al giro dopo il numero si
     * aggiorna. Una rotellina al posto dell'obiettivo calorico sarebbe peggio
     * di un numero che si corregge da solo in mezzo secondo.
     */
    /*
     * 🚨 **Da FASE 11.5 anche la stima e la dichiarazione vengono dal
     * telefono.** Erano `day.bruciateAMano` e `day.burnedKcal`, cioè il campo
     * `burned` di `/diary`, che il server calcolava da `workout_sessions` e
     * `daily_burns`. ⚠️ Con quelle tabelle via sarebbero diventati **zero senza
     * un errore**, e l'obiettivo calorico avrebbe smesso di comprenderle.
     */
    final aMano = ref
        .watch(bruciateAManoDelGiornoProvider(day.date))
        .valueOrNull;

    final bruciate = BruciateDelGiorno.scegli(
      manuale: aMano,
      daHealth:
          ref.watch(kcalAttiveDelGiornoProvider(day.date)).valueOrNull ?? 0,
      stimate:
          ref.watch(bruciateLocaliDelGiornoProvider(day.date)).valueOrNull ?? 0,
    );

    /*
     * 🚨 **Le bruciate entrano nell'obiettivo QUI** — N23.B1, 19/08/2026.
     *
     * Fino a oggi la somma esisteva solo sul server, e dopo D9-bis il server
     * non conosce piu' il peso: `targets` torna `null` a chiunque non abbia un
     * piano del trainer, e questo ramo cadeva sul calcolo locale — che le
     * bruciate non le guardava. ⚠️ Il committente lo ha riferito il 19/08, ed
     * era vero.
     *
     * 💡 `TargetDelGiorno` decide **anche** quando NON sommare: se il numero
     * arriva dal server le bruciate ci sono gia' dentro, e risommarle darebbe a
     * chi ha un trainer il doppio del margine.
     */
    final target = TargetDelGiorno.scegli(
      dalServer: day.hasTarget ? day.targetKcal : null,
      locale: locale?.kcal.toDouble(),
      bruciate: bruciate.kcal,
    );

    // 💡 `?? 0` e non `!`: il numero si usa solo dentro rami protetti da
    // `haTarget`, e uno zero non fa esplodere niente se un giorno uno di quei
    // rami cambia. Un `!` invece diventerebbe un guasto a schermo.
    // 🆕 3b-D.1.3 — lo stesso numero che «Oggi» mostra accanto al target.
    final consumo = ref.watch(targetLocaleProvider).valueOrNull?.target?.tdee;

    final targetKcal = target.kcal ?? 0;
    final haTarget = target.esiste;
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
            /*
             * ══ 🚨 DUE RIGHE, PERCHÉ UNA NON CI STA — 22/08/2026 ════════════
             *
             * 📌 Il committente, guardandola sul telefono: *«Le calorie bruciate
             * vanno in overflow sulla card […] il TDEE è tutto appiccicato…
             * puoi anche mandare a capo se vuoi, sai?»*.
             *
             * ⚠️ Su una riga sola c'erano **quattro** cose: il numero grande,
             * «/ 2364 kcal», «TDEE 2271» e la pasticca delle bruciate — che è
             * la più lunga di tutte perché dice **da dove viene** il numero
             * («547 · dall'orologio»), e quella parte serve (FASE 1.6).
             *
             * 🚨 Quattro cose su 360 px non ci stanno, e il `Row` non va a capo
             * da solo: sfora e basta. 💡 Due righe — il numero sopra, il
             * contesto sotto — e ognuna ha lo spazio che le serve.
             */
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  day.kcal.round().toString(),
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: sforato
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: Gap.xs),
                Expanded(
                  child: Text(
                    haTarget ? '/ ${targetKcal.round()} kcal' : 'kcal',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: Gap.xs),

            /*
             * ⚠️ **`Wrap` e non `Row`** — 22/08/2026, terzo giro su questa riga.
             *
             * 🚨 Con il carattere ingrandito «547 · dall'orologio» non ci sta
             * comunque, e un `Row` non ha un'altra scelta che **troncare**: si
             * leggeva «547 · dall'or…», cioè spariva proprio la parte che dice
             * da dove viene il numero (FASE 1.6).
             *
             * 💡 Un `Wrap` manda a capo. ⛔ È la stessa lezione di §56.3 n° 1:
             * una riga che «di solito ci sta» è una riga che su qualche
             * telefono non ci sta, e l'analizzatore non lo vede.
             */
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Gap.md,
              runSpacing: Gap.xs,
              children: [
                /*
                 * 🆕 Il consumo stimato — 3b-D.1.3. Sta **sotto** il target e
                 * non accanto: sono due numeri della stessa famiglia, e in fila
                 * sulla stessa riga si leggono come uno solo lungo.
                 */
                if (consumo != null)
                  Text(
                    'TDEE ${consumo.round()}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                // Le bruciate si mostrano perché il target del giorno le
                // comprende già: senza, l'utente vedrebbe un target più alto
                // del solito e non capirebbe perché.
                //
                // C15 — ed è toccabile: il totale bruciato si può dichiarare a
                // mano, per chi porta un orologio che conta meglio della nostra
                // stima o per chi ha fatto qualcosa che non ha registrato.
                /*
                 * ══ 🚨 UNA PASTICCA, PERCHÉ SI DEVE CAPIRE CHE SI TOCCA ═════
                 *
                 * 📌 Il committente, 22/08/2026: *«le calorie bruciate nella
                 * card delle calorie deve essere una pasticca perché si deve
                 * capire che ci posso cliccare»*.
                 *
                 * ⚠️ Per un giro era diventata una riga di testo, per far
                 * stare «547 · dall'orologio» senza troncarlo. 🚨 Ma un testo
                 * che si tocca **non si distingue da uno che non si tocca**, e
                 * qui dietro c'è una funzione vera: dichiarare a mano le
                 * calorie bruciate. Un'azione che nessuno trova è un'azione che
                 * non esiste.
                 *
                 * 💡 **La soluzione non era togliere il vestito, era accorciare
                 * il contenuto**: la fonte diventa un'icona — un orologio, una
                 * matita, una calcolatrice — e il testo per esteso resta nel
                 * `tooltip`, per chi non la riconosce e per i lettori di
                 * schermo.
                 */
                ActionChip(
                  avatar: Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: theme.colorScheme.tertiary,
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${bruciate.kcal}'),
                      if (bruciate.fonte.icona != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          bruciate.fonte.icona,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                  tooltip: bruciate.fonte == FonteBruciate.nessuna
                      ? 'Dichiara le calorie bruciate'
                      : 'Calorie bruciate ${bruciate.fonte.etichetta}',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _bruciateAMano(context, ref, aMano),
                ),
              ],
            ),

            const SizedBox(height: Gap.xs),

            if (haTarget) ...[
              const SizedBox(height: Gap.sm),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  // `clamp` a 1 solo per il disegno: il colore dice il resto.
                  value: progresso.clamp(0.0, 1.0),
                  minHeight: 10,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: sforato
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
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
                  colore: theme.colorScheme.primary,
                  target:
                      day.targetProtein ?? locale?.macro.proteineG.toDouble(),
                ),
                _Macro(
                  nome: 'Carboidrati',
                  valore: day.carbs,
                  colore: theme.colorScheme.tertiary,
                  target:
                      day.targetCarbs ?? locale?.macro.carboidratiG.toDouble(),
                ),
                _Macro(
                  nome: 'Grassi',
                  valore: day.fat,
                  colore: theme.colorScheme.secondary,
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
Future<void> _bruciateAMano(
  BuildContext context,
  WidgetRef ref,
  int? attuale,
) async {
  /*
   * 🚨 **`int?` e non `int`**: il campo parte vuoto quando non c'è un valore
   * dichiarato, e parte con **zero scritto** se qualcuno ha davvero dichiarato
   * zero. Con un `int` i due casi erano lo stesso, e riaprendo il modulo dopo
   * aver scritto 0 si sarebbe trovato il campo vuoto — cioè il contrario di
   * quello che si era detto.
   */
  final controller = TextEditingController(text: attuale?.toString() ?? '');

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
          helperText: "Vuoto = usa l'orologio, o la stima degli allenamenti",
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
  const _Macro({
    required this.nome,
    required this.valore,
    required this.colore,
    this.target,
  });

  final String nome;
  final double valore;
  final double? target;
  final Color colore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    /*
     * ══ 🆕 DENTRO UN QUADRATO — 3b-D.1.4, 22/08/2026 ═══════════════════════
     *
     * 📌 Il committente: *«i macro devono essere dentro dei quadrati»*.
     *
     * 💡 E non è solo estetica: tre numeri in fila senza cornice si leggono
     * come una frase sola. Il riquadro dice che sono **tre cose separate**, e
     * a colpo d'occhio si trova quello che si cerca.
     *
     * ⚠️ **Il colore lo dà il macro, non il caso**: gli stessi tre di «Oggi»
     * (`P`, `C`, `G` nella scheda calorie). Due tavolozze per la stessa cosa
     * in due schermate sono due cose diverse per chi guarda.
     */
    final pieno = target != null && valore >= target!;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Gap.xs / 2),
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        decoration: BoxDecoration(
          color: colore.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Gap.radiusSm),
          /*
           * 🚨 Il bordo compare **solo** a obiettivo raggiunto: un contorno
           * sempre acceso non direbbe niente, e a quel punto tanto varrebbe
           * non averlo.
           */
          border: pieno
              ? Border.all(color: colore.withValues(alpha: 0.55), width: 1.5)
              : null,
        ),
        child: Column(
          children: [
            Text(
              nome,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colore,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${valore.round()}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
            ),
            Text(
              // ⛔ Senza obiettivo si scrive «g» e non «/ 0 g»: uno zero
              // inventato è peggio di un'assenza dichiarata.
              target == null ? 'g' : 'di ${target!.round()} g',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
