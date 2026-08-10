import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/providers.dart';

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
    // 🚨 `null` ≠ `0`: niente registrato è un'altra cosa da «registrato e vale
    // zero». Appiattirli disegnerebbe la stessa cella per una giornata a
    // digiuno e per una dimenticata.
    kcal: (j['kcal'] as num?)?.toInt(),
    workouts: (j['workouts'] as num?)?.toInt() ?? 0,
    burned: (j['burned'] as num?)?.toInt() ?? 0,
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

  return CalendarPage.fromJson(data);
});

/// Il dettaglio di un giorno.
final calendarDayProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((
  ref,
  data,
) async {
  return ref.watch(apiClientProvider).get<Map<String, dynamic>>('/calendar/$data');
});
