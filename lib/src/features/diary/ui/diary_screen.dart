import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/aggiornamento.dart';
import '../../../core/ui/barra_della_data.dart';
import '../../../core/ui/sezioni.dart';
import '../../../core/ui/states.dart';
import '../../../core/ui/testata_scura.dart';
import '../../achievements/achievement.dart';
import '../../achievements/ui/carosello_achievements.dart';
import '../data/diary_models.dart';
import '../diary_controller.dart';
import '../pasti_chiusi.dart';
import '../preferiti_gia_salvati.dart';
import 'widgets/add_food_sheet.dart';
import 'widgets/edit_entry_sheet.dart';
import 'widgets/favorites_sheet.dart';
import 'widgets/macro_summary.dart';
import 'widgets/stima_ritrovata.dart';

/// Il diario del giorno — A4.1.
class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final giorno = ref.watch(selectedDateProvider);
    final diario = ref.watch(diaryProvider);

    /*
     * ══ 🌑 LA TESTATA SCURA, CON DENTRO IL RIEPILOGO — I3, 19/11/2026 ════════
     *
     * 📌 Tavola «Diario A»: calorie, bruciate e macro salgono in testata.
     *
     * ⚠️ La testata c'è **anche mentre carica e in errore**: è la riga con la
     * palestra (R2), e una pagina che compare senza e poi la mette sposta tutto
     * mezzo secondo dopo. Gli strumenti invece arrivano col diario.
     *
     * ⛔ **Il riassunto tolto il 22/08 non torna** (3b-D.2.1): *«non mi piace
     * sto header della sezione cibo, togli il riassunto»*. Quello era una
     * **copia** della card, messa sopra la card stessa. Qui sale la card, e
     * sotto non resta un doppione: la ragione di quella regola non c'è più.
     */
    Widget testata({Widget? strumenti}) => TestataScura(
      titolo: 'Diario',
      azioni: [
        IconButton(
          onPressed: () => _scegliData(context, ref, giorno),
          icon: const Icon(Icons.calendar_today_rounded),
          tooltip: 'Cambia giorno',
        ),
        // C13 — il mese intero. Sta qui perché la domanda «come è andata la
        // settimana» nasce guardando la giornata, non da un'altra sezione.
        IconButton(
          onPressed: () => context.push(AppRoutes.calendar),
          icon: const Icon(Icons.calendar_month_rounded),
          tooltip: 'Calendario',
        ),
      ],
      navigatore: _barraDelGiorno(ref, giorno),
      strumenti: strumenti,
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => AddFoodSheet.show(context),
        icon: const Icon(Icons.add),
        label: const Text('Aggiungi'),
      ),
      body: diario.when(
        loading: () => Column(
          children: [
            testata(),
            const Expanded(child: LoadingState()),
          ],
        ),
        error: (e, _) => Column(
          children: [
            testata(),
            Expanded(
              child: ErrorState(
                error: e,
                onRetry: () => ref.invalidate(diaryProvider),
              ),
            ),
          ],
        ),
        data: (day) => RefreshIndicator(
          onRefresh: () =>
              aggiornaTutto(context, ref, () => ref.invalidate(diaryProvider)),
          child: ListView(
            // ⚠️ Niente padding orizzontale: la testata arriva ai bordi. Il
            // margine lo mette il `Padding` sotto. ⚠️ 120 in fondo e non 96: il
            // pulsante «Aggiungi» è **esteso**, e copriva la riga «Preferiti»
            // dell'ultimo pasto — cioè un pulsante vero, non uno spazio vuoto.
            padding: const EdgeInsets.only(bottom: 120),
            children: [
              testata(strumenti: MacroSummary(day: day)),

              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    /*
                     * 🆕 FASE 9.7 — la stima lasciata a metà. 🚨 **In cima**:
                     * chi ha chiuso l'app mentre il server pensava sta
                     * cercando *quel* piatto. Nel caso normale non si vede e
                     * non costa niente.
                     */
                    const StimaRitrovata(),

                    /*
                     * 🏅 **Le medaglie, subito sotto le calorie** — 3b-A.8.4:
                     * *«nella pagina diario deve stare subito sotto alla card
                     * delle calorie»*. ⛔ Solo l'alimentazione.
                     */
                    const CaroselloAchievements(
                      ambito: AmbitoAchievement.alimentazione,
                    ),

                    const TitoloDiSezione('Pasti'),
                    const SizedBox(height: Gap.sm),

                    for (final pasto in day.meals) _Pasto(pasto: pasto),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La data con le frecce, nel posto del navigatore della testata.
  ///
  /// 💡 Cambiare giorno è il gesto più frequente del diario, e farlo passare
  /// da un calendario ogni volta è troppo attrito. ⛔ La freccia avanti si
  /// spegne su oggi: il diario non si compila in anticipo.
  ///
  /// ⚠️ **Il provider resta quello del diario** (`selectedDateProvider`), non
  /// quello di Oggi: `BarraDellaData` unifica il disegno, non lo stato.
  static Widget _barraDelGiorno(WidgetRef ref, DateTime giorno) {
    final oggi = DateTime.now();
    final eOggi = DateUtils.isSameDay(giorno, oggi);
    final data = ref.read(selectedDateProvider.notifier);

    return BarraDellaData(
      testo: eOggi
          ? 'Oggi · ${DateFormat('d MMMM', 'it').format(giorno)}'
          : DateFormat('EEEE d MMMM', 'it').format(giorno),
      onPrima: () => data.state = giorno.subtract(const Duration(days: 1)),
      onDopo: eOggi
          ? null
          : () => data.state = giorno.add(const Duration(days: 1)),
      onTesto: eOggi ? null : () => data.state = DateUtils.dateOnly(oggi),
    );
  }

  Future<void> _scegliData(
    BuildContext context,
    WidgetRef ref,
    DateTime attuale,
  ) async {
    final scelta = await showDatePicker(
      context: context,
      initialDate: attuale,
      // Il diario non si compila in anticipo: non si sa cosa si mangerà.
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('it'),
    );

    if (scelta != null) {
      ref.read(selectedDateProvider.notifier).state = scelta;
    }
  }
}

class _Pasto extends ConsumerWidget {
  const _Pasto({required this.pasto});

  final DiaryMeal pasto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    /*
     * 🚨 **Le voci scorse via escono dalla lista SUBITO.**
     *
     * `Dismissible` pretende che l'elemento sparisca nello stesso frame del
     * gesto; aspettare la risposta del server produce
     * *«a dismissed Dismissible widget is still part of the tree»* — il
     * rettangolo rosso che compariva mentre la cancellazione funzionava.
     *
     * ⚠️ Il filtro sta **qui e non dentro `_Voce`**: un widget non può togliersi
     * dalla lista da solo, e nasconderlo con `Visibility` lascerebbe comunque
     * l'elemento nell'albero — cioè esattamente ciò di cui Flutter si lamenta.
     */
    final chiuso = ref.watch(pastiChiusiProvider).contains(pasto.meal);

    final inUscita = ref.watch(vociInUscitaProvider);
    final visibili = pasto.entries
        .where((v) => !inUscita.contains(v.id))
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /*
             * ══ 🆕 UNA PICCOLA INTESTAZIONE PER PASTO — 3b-D.3, 22/08/2026 ══
             *
             * 📌 Il committente: *«tutte le cards sotto devono avere una specie
             * di piccolo header dove sta il nome del pasto con le calorie, e
             * ogni card deve avere un'icona a sinistra»*. E: *«Le sezioni dei
             * pasti devono essere collassabili»*.
             *
             * 💡 **Toccare l'intestazione apre e chiude.** Sei pasti aperti su
             * un telefono sono uno scorrimento lungo per arrivare alla cena, e
             * chi guarda il diario a metà giornata ha tre sezioni vuote in
             * mezzo.
             *
             * ⚠️ **Le calorie restano visibili da chiuso**, ed è il punto: una
             * sezione chiusa deve dire quanto pesa, o chiuderla vorrebbe dire
             * perdere l'informazione invece che lo spazio.
             */
            InkWell(
              onTap: () =>
                  ref.read(pastiChiusiProvider.notifier).cambia(pasto.meal),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.md,
                  Gap.md,
                  Gap.md,
                  Gap.sm,
                ),
                child: Row(
                  children: [
                    // 🍽️ L'icona del pasto: si riconosce prima del nome.
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(Gap.radiusSm),
                      ),
                      child: Icon(
                        _iconaDelPasto(pasto.meal),
                        size: 18,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: Gap.sm),

                    Expanded(
                      child: Text(
                        pasto.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${pasto.kcal.round()} kcal',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    // D2 — «salva questo pasto fra i preferiti». È la funzione
                    // che fa risparmiare davvero: una colazione si ripete uguale
                    // per mesi, e riscriverne cinque voci ogni mattina è ciò che
                    // fa smettere di registrare.
                    //
                    // 🔖 Da 3b-D.5.2 è un **interruttore**, come la stella.
                    if (pasto.entries.isNotEmpty) _Segnalibro(pasto: pasto),

                    // ⌄ La freccia gira: è l'unica cosa che dice che si può
                    // toccare.
                    AnimatedRotation(
                      turns: chiuso ? -0.25 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        Icons.expand_more_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (chiuso)
              // ⛔ Chiuso vuol dire chiuso: niente elenco, niente pulsanti.
              const SizedBox.shrink()
            else if (visibili.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
                child: Text(
                  'Niente ancora.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final voce in visibili) _Voce(voce: voce),

            if (!chiuso)
              Row(
                children: [
                  /*
                   * ⚠️ **Niente `Expanded`, e i due pulsanti stanno a
                   * sinistra** — 22/08/2026.
                   *
                   * 🚨 Con «Aggiungi» espanso, «Preferiti» finiva all'estrema
                   * destra — **esattamente sotto il pulsante flottante**, che
                   * lo copriva. ⛔ E non bastava aggiungere spazio in fondo
                   * alla lista: quando il contenuto è più corto dello schermo
                   * quel margine non spinge su niente.
                   *
                   * 💡 Stringendoli a sinistra, sotto il flottante resta il
                   * vuoto — che è quello che deve esserci sotto un pulsante
                   * che galleggia.
                   */
                  TextButton.icon(
                    onPressed: () =>
                        AddFoodSheet.show(context, meal: pasto.meal),
                    icon: const Icon(Icons.add, size: 18),
                    /*
                     * 💡 **«Aggiungi» e basta** — 22/08/2026.
                     *
                     * ⚠️ Diceva «Aggiungi a colazione», e il nome del pasto è
                     * scritto **due righe sopra**, nell'intestazione che prima
                     * non c'era (3b-D.3.1). 🚨 Ripeterlo non chiariva niente e
                     * spingeva «Preferiti» sotto il pulsante flottante, che lo
                     * copriva.
                     */
                    label: const Text('Aggiungi'),
                  ),
                  TextButton.icon(
                    onPressed: () =>
                        FavoritesSheet.mostra(context, meal: pasto.meal),
                    icon: const Icon(Icons.star_outline_rounded, size: 18),
                    label: const Text('Preferiti'),
                  ),
                  const Spacer(),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// L'icona di un pasto — 3b-D.3.2.
///
/// 💡 Si riconosce **prima** del nome, ed è tutto il suo mestiere: chi scorre
/// cerca «la cena», non legge sei etichette.
IconData _iconaDelPasto(String pasto) => switch (pasto) {
  'breakfast' => Icons.free_breakfast_outlined,
  'morning_snack' || 'afternoon_snack' => Icons.apple_rounded,
  'lunch' => Icons.restaurant_rounded,
  'dinner' => Icons.dinner_dining_rounded,
  'evening_snack' => Icons.nightlight_outlined,
  _ => Icons.restaurant_menu_rounded,
};

/// Salva l'intero pasto del giorno che si sta guardando.
///
/// Il nome si propone («Colazione 10/08») ma si può cambiare: «la mia
/// colazione» dice molto di più di una data, e un preferito che non si
/// riconosce dal nome non viene riusato.
///
/// ⚠️ **È una funzione libera e non un metodo di `_Pasto`**: da 3b-D.5.2 la
/// chiama `_Segnalibro`, che è un widget a sé perché deve **guardare** i
/// preferiti per sapere come disegnarsi.
Future<void> _salvaPasto(
  BuildContext context,
  WidgetRef ref,
  DiaryMeal pasto,
) async {
  final giorno = ref.read(selectedDateProvider);
  final controller = TextEditingController(
    text: '${pasto.label} ${DateFormat('d/MM', 'it').format(giorno)}',
  );

  final nome = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Salva il pasto fra i preferiti'),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Nome del preferito'),
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

  if (nome == null || nome.isEmpty || !context.mounted) return;

  try {
    await ref
        .read(favoriteActionsProvider)
        .saveMeal(meal: pasto.meal, description: nome);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('«$nome» salvato fra i preferiti')),
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

/// La stella di un alimento: piena se è già fra i preferiti — 3b-D.5.1.
///
/// ⛔ **Toglierlo non chiede conferma.** Un preferito non è un dato: è una
/// scorciatoia, e rimetterlo costa un tocco. 🚨 Una finestra di conferma su un
/// gesto reversibile e senza conseguenze è attrito e basta.
class _Stella extends ConsumerWidget {
  const _Stella({required this.voce});

  final FoodEntry voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gia = ref
        .watch(preferitiGiaSalvatiProvider)
        .perAlimento(voce.description);

    return IconButton(
      onPressed: () => _tocca(context, ref, gia),
      icon: Icon(
        gia == null ? Icons.star_outline_rounded : Icons.star_rounded,
        size: 18,
        // 💡 Pieno **e** colorato: la differenza fra i due contorni si perde a
        // 18 px, il colore no.
        color: gia == null ? null : theme.colorScheme.tertiary,
      ),
      tooltip: gia == null ? 'Salva fra i preferiti' : 'Togli dai preferiti',
      visualDensity: VisualDensity.compact,
    );
  }

  Future<void> _tocca(
    BuildContext context,
    WidgetRef ref,
    FoodFavorite? gia,
  ) async {
    final messaggi = ScaffoldMessenger.of(context);

    try {
      if (gia == null) {
        await ref.read(diaryActionsProvider).favorite(voce.id);
        ref.invalidate(favoritesProvider);

        messaggi.showSnackBar(
          SnackBar(
            content: Text('«${voce.description}» salvato fra i preferiti'),
          ),
        );
      } else {
        await ref.read(favoriteActionsProvider).remove(gia.id);

        messaggi.showSnackBar(
          SnackBar(content: Text('«${gia.description}» tolto dai preferiti')),
        );
      }
    } on Object catch (error) {
      messaggi.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(error).message)),
      );
    }
  }
}

/// Il segnalibro di un pasto intero — 3b-D.5.2.
///
/// 🚨 **Si riconosce dal contenuto, non dal nome**: il nome lo sceglie chi
/// salva, e un pasto salvato come «la mia colazione» resterebbe senza
/// segnalibro per sempre. Vedi `PreferitiGiaSalvati.perPasto`.
class _Segnalibro extends ConsumerWidget {
  const _Segnalibro({required this.pasto});

  final DiaryMeal pasto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final gia = ref
        .watch(preferitiGiaSalvatiProvider)
        .perPasto(voci: pasto.entries.length, kcal: pasto.kcal);

    return IconButton(
      onPressed: () => _tocca(context, ref, gia),
      icon: Icon(
        gia == null ? Icons.bookmark_add_outlined : Icons.bookmark_rounded,
        size: 20,
        color: gia == null ? null : theme.colorScheme.tertiary,
      ),
      tooltip: gia == null
          ? 'Salva questo pasto fra i preferiti'
          : 'Togli questo pasto dai preferiti',
    );
  }

  Future<void> _tocca(
    BuildContext context,
    WidgetRef ref,
    FoodFavorite? gia,
  ) async {
    if (gia == null) {
      await _salvaPasto(context, ref, pasto);

      return;
    }

    final messaggi = ScaffoldMessenger.of(context);

    try {
      await ref.read(favoriteActionsProvider).remove(gia.id);

      messaggi.showSnackBar(
        SnackBar(content: Text('«${gia.description}» tolto dai preferiti')),
      );
    } on Object catch (error) {
      messaggi.showSnackBar(
        SnackBar(content: Text(ApiClient.unwrapError(error).message)),
      );
    }
  }
}

class _Voce extends ConsumerWidget {
  const _Voce({required this.voce});

  final FoodEntry voce;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(voce.id),
      direction: DismissDirection.endToStart,
      background: ColoredBox(
        color: theme.colorScheme.errorContainer,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: Gap.lg),
            child: Icon(Icons.delete_outline_rounded),
          ),
        ),
      ),
      // ⚠️ `deleteSubito` toglie la riga **prima** di chiamare il server, e la
      // rimette se la chiamata fallisce. Vedi `vociInUscitaProvider`.
      onDismissed: (_) async {
        final messaggi = ScaffoldMessenger.of(context);

        try {
          await ref.read(diaryActionsProvider).deleteSubito(voce.id);
        } on Object catch (error) {
          messaggi.showSnackBar(
            SnackBar(content: Text(ApiClient.unwrapError(error).message)),
          );
        }
      },
      /*
       * ══ 🆕 OGNI ALIMENTO IN UN SUO RIQUADRO — 22/08/2026 ═══════════════
       *
       * 📌 Il committente: *«Voglio anche che gli alimenti nelle cards siano
       * più chiaramente separati, così non sembrano tanti elementi uno dopo
       * l'altro»*.
       *
       * ⚠️ Con dei `ListTile` nudi uno sotto l'altro, cinque voci di una
       * colazione si leggono come **un blocco di testo**: dove finisce una e
       * comincia l'altra lo si capisce solo contando le righe.
       *
       * 💡 Un fondo appena più chiaro e un margine: costa due pixel e ognuna
       * diventa una cosa a sé. ⛔ Non una `Card` dentro una `Card` — due ombre
       * annidate fanno sembrare la scheda del pasto un contenitore rotto.
       */
      child: Container(
        margin: const EdgeInsets.fromLTRB(Gap.sm, 0, Gap.sm, Gap.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(Gap.radiusSm),
        ),
        child: ListTile(
          dense: true,
          // C15 — toccare una voce la apre in modifica. È il gesto che ci si
          // aspetta, e senza restava l'unico modo per correggere una stima
          // sbagliata: cancellarla e riscriverla.
          onTap: () => EditEntrySheet.mostra(context, voce),
          title: Text(voce.description),
          subtitle: Text(voce.quantita),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                voce.kcal != null ? '${voce.kcal!.round()} kcal' : '—',
                style: theme.textTheme.labelMedium,
              ),
              /*
             * ══ ⭐ LA STELLA È UN INTERRUTTORE — 3b-D.5.1, 22/08/2026 ═══════
             *
             * 📌 Il committente: *«Quando clicco sulla stella per rendere un
             * cibo preferito, la stella si deve riempire, e se ci clicco di
             * nuovo, si deve togliere dai preferiti»*.
             *
             * ⚠️ Prima era **a senso unico**: si poteva aggiungere e non
             * togliere, e non c'era modo di sapere se un cibo era già salvato
             * senza aprire l'altro elenco. 🚨 Un'icona che non cambia stato non
             * è un interruttore: è un pulsante travestito.
             *
             * 💡 D2 resta: si parte da una voce esistente, con quantità e macro
             * già dentro, invece che da un modulo vuoto.
             */
              _Stella(voce: voce),
              // 🚨 Eliminare deve essere **visibile**. Lo scorrimento a sinistra
              // resta come scorciatoia, ma un gesto che niente annuncia è una
              // funzione che per la maggior parte delle persone non esiste — e
              // senza, il diario è una lista che si può solo far crescere.
              IconButton(
                onPressed: () => _elimina(context, ref),
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Elimina',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          // L'icona dice da dove viene la voce: serve a capire, guardando lo
          // storico, quali stime sono dell'AI quando un totale non torna.
          leading: Icon(
            switch (voce.source) {
              'ai_text' => Icons.auto_awesome_outlined,
              'ai_photo' => Icons.photo_camera_outlined,
              'favorite' => Icons.star_outline_rounded,
              'plan' => Icons.assignment_outlined,
              _ => Icons.edit_outlined,
            },
            size: 18,
            color: theme.colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Future<void> _elimina(BuildContext context, WidgetRef ref) async {
    final conferma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminare «${voce.description}»?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (conferma == true) {
      await ref.read(diaryActionsProvider).delete(voce.id);
    }
  }
}
