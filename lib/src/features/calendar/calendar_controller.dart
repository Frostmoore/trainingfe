import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';
import '../diary/data/diario_locale.dart';
import '../health/health_controller.dart';
import '../training/session_controller.dart';

/// Una cella del calendario — C13.
class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.day,
    required this.dow,
    required this.workouts,
    required this.burned,
    required this.inMonth,
    required this.today,
    this.kcal,
  });

  factory CalendarDay.fromJson(Map<String, dynamic> j) => CalendarDay(
    date: DateTime.parse(j['date'].toString()),
    day: (j['day'] as num).toInt(),
    dow: j['dow'].toString(),
    /*
     * ⛔ **Nemmeno le calorie si leggono più dal server** — Parte I, I2.5.
     *
     * 🚨 Erano l'ultima cosa che il calendario prendeva di là. Dopo il trasloco
     * del diario ogni cella avrebbe detto «niente registrato» — cioè un mese
     * intero vuoto e credibile, esattamente come era successo agli allenamenti
     * nella FASE 11.5.3.
     *
     * 💡 Le mette `conCalorie()` un istante dopo.
     */
    kcal: null,
    /*
     * ⛔ **Non si leggono più dal server** — FASE 11.5.3, 21/08/2026.
     *
     * 🚨 `workouts` e `burned` nascevano da `workout_sessions` e `daily_burns`,
     * che dopo il trasloco stanno sul telefono. ⚠️ Lasciando la lettura, ogni
     * cella del calendario avrebbe detto **zero allenamenti** senza un errore:
     * un mese vuoto e credibile.
     *
     * 💡 Li mette `conGliAllenamentiLocali()` un istante dopo.
     */
    workouts: 0,
    burned: 0,
    inMonth: j['in_month'] == true,
    today: j['today'] == true,
  );

  final DateTime date;
  final int day;
  final String dow;
  final int? kcal;
  final int workouts;
  final int burned;
  final bool inMonth;
  final bool today;

  CalendarDay conAllenamenti({required int quanti, required int kcal}) =>
      CalendarDay(
        date: date,
        day: day,
        dow: dow,
        kcal: this.kcal,
        workouts: quanti,
        burned: kcal,
        inMonth: inMonth,
        today: today,
      );

  /// Le calorie **assunte**, dal diario di questo telefono — I2.5.
  ///
  /// 🚨 `null` ≠ `0`: niente registrato è un'altra cosa da «registrato e vale
  /// zero». ⛔ Appiattirli disegnerebbe la stessa cella per una giornata a
  /// digiuno e per una dimenticata — ed è il motivo per cui chi chiama passa
  /// `null` quando quel giorno non ha voci, invece di uno zero comodo.
  CalendarDay conCalorie(int? assunte) => CalendarDay(
    date: date,
    day: day,
    dow: dow,
    kcal: assunte,
    workouts: workouts,
    burned: burned,
    inMonth: inMonth,
    today: today,
  );
}

class CalendarPage {
  const CalendarPage({
    required this.title,
    required this.days,
    required this.prev,
    required this.next,
    this.targetKcal,
  });

  factory CalendarPage.fromJson(Map<String, dynamic> j) => CalendarPage(
    title: j['title'].toString(),
    prev: j['prev'].toString(),
    next: j['next'].toString(),
    targetKcal: (j['target_kcal'] as num?)?.toInt(),
    days: ((j['days'] as List?) ?? const [])
        .map((e) => CalendarDay.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  final String title;
  final String prev;
  final String next;
  final int? targetKcal;
  final List<CalendarDay> days;
}

/// Il mese che si sta guardando, in formato `YYYY-MM`.
final calendarMonthProvider = StateProvider<String>(
  (ref) => DateFormat('yyyy-MM').format(DateTime.now()),
);

final calendarProvider = FutureProvider.autoDispose<CalendarPage>((ref) async {
  final mese = ref.watch(calendarMonthProvider);

  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/calendar', query: {'month': mese});

  final pagina = CalendarPage.fromJson(data);

  /*
   * ══ 🚨 TUTTO DAL TELEFONO, DA I2.5 ═════════════════════════════════════
   *
   * ⚠️ Fino al 03/09/2026 questo era l'ultimo punto in cui le due cose
   * convivevano: le calorie mangiate dal server, gli allenamenti dal telefono.
   * 🆕 Adesso hanno la **stessa casa**, e dal server restano solo la griglia del
   * mese e le sue etichette.
   *
   * 🚨 Senza questi innesti ogni cella direbbe «0 allenamenti» e «niente
   * registrato» — un mese vuoto, credibile, e senza nessun errore da nessuna
   * parte.
   */
  ref.watch(revisioneDiarioProvider);

  final sedute = await ref.watch(sessionsProvider.future);
  final archivio = ref.watch(archivioSaluteProvider);

  final quante = <String, int>{};
  final kcal = <String, int>{};

  for (final s in sedute) {
    // ⛔ Le sedute ancora aperte non si contano: non sono un allenamento fatto.
    if (s.isOpen) continue;

    final g = DateFormat('yyyy-MM-dd').format(s.startedAt);

    quante[g] = (quante[g] ?? 0) + 1;
    kcal[g] = (kcal[g] ?? 0) + (s.kcal ?? 0);
  }

  // 💡 La dichiarazione a mano **sostituisce** la somma delle sedute, non ci si
  // aggiunge: è la regola di `CalorieAllenamento.bruciateDelGiorno`.
  final aMano = await archivio.bruciateAManoFra(
    pagina.days.first.date,
    pagina.days.last.date,
  );

  for (final e in aMano.entries) {
    kcal[DateFormat('yyyy-MM-dd').format(e.key)] = e.value;
  }

  // 🚨 Una lettura sola per tutto il mese: trentuno letture per disegnare una
  // griglia sarebbero trentuno viaggi nel database per una risposta che sta in
  // uno.
  final assunte = await ref
      .watch(diarioLocaleProvider)
      .totaliFra(pagina.days.first.date, pagina.days.last.date);

  return CalendarPage(
    title: pagina.title,
    prev: pagina.prev,
    next: pagina.next,
    targetKcal: pagina.targetKcal,
    days: pagina.days.map((d) {
      final g = DateFormat('yyyy-MM-dd').format(d.date);

      return d
          .conAllenamenti(quanti: quante[g] ?? 0, kcal: kcal[g] ?? 0)
          /*
           * 💡 `?.round()` su un giorno **assente**: senza voci non c'è nessuna
           * chiave, e il `null` che ne esce è quello giusto — «non registrato»,
           * non «zero calorie».
           */
          .conCalorie(assunte[g]?.kcal.round());
    }).toList(),
  );
});

/// Il dettaglio di un giorno.
final calendarDayProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, data) async {
      return ref
          .watch(apiClientProvider)
          .get<Map<String, dynamic>>('/calendar/$data');
    });
