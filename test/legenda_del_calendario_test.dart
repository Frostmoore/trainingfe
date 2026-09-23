import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/calendar/calendar_controller.dart';
import 'package:training_companion/src/features/calendar/ui/calendar_screen.dart';

import 'aiuto/intestazione.dart';

/// 📅 **La legenda del calendario spiega solo quello che si vede** — 23/09/2026.
///
/// ══ ⛔ IL DIFETTO, E LA CORREZIONE FATTA A METÀ ════════════════════════════
///
/// La riga in fondo dice *«La barra è la percentuale sul tuo fabbisogno»*. ⚠️ Ma
/// la barra si disegna **solo se c'è un fabbisogno** (`_Cella`:
/// `if (target != null)`), e senza profilo il giorno mostra il solo numero.
///
/// 🚨 A settembre il difetto era stato visto e corretto **a metà**: la
/// condizione controllava «c'è qualche kcal in questo mese», che copre il mese
/// vuoto di un account nuovo ma **non** il mese di chi ha scritto nel diario
/// prima di compilare il profilo — cioè di quasi tutti, all'inizio.
///
/// 💡 Per questo il test guarda **i due casi insieme**: una condizione giusta a
/// metà passa un test scritto a metà.
void main() {
  CalendarDay giorno(int n, {int? kcal}) => CalendarDay(
    date: DateTime(2026, 9, n),
    day: n,
    dow: 'Dom',
    workouts: 0,
    burned: 0,
    inMonth: true,
    today: false,
    kcal: kcal,
  );

  Future<void> disegna(WidgetTester tester, CalendarPage pagina) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...await intestazioneFinta(),
          calendarProvider.overrideWith((ref) async => pagina),
        ],
        child: const MaterialApp(home: CalendarScreen()),
      ),
    );

    await tester.pumpAndSettle();
  }

  const frasedellaBarra = 'La barra è la percentuale sul tuo fabbisogno. '
      'Tocca un giorno per il dettaglio.';

  testWidgets('con le kcal ma senza fabbisogno non promette nessuna barra', (
    tester,
  ) async {
    await disegna(
      tester,
      CalendarPage(
        title: 'Settembre 2026',
        prev: '2026-08',
        next: '2026-10',
        days: [giorno(20, kcal: 1400)],
      ),
    );

    expect(find.text(frasedellaBarra), findsNothing);
    expect(
      find.text('Tocca un giorno per vedere cosa hai registrato.'),
      findsOneWidget,
    );
  });

  testWidgets('col fabbisogno la barra c\'è, e la legenda la spiega', (
    tester,
  ) async {
    await disegna(
      tester,
      CalendarPage(
        title: 'Settembre 2026',
        prev: '2026-08',
        next: '2026-10',
        days: [giorno(20, kcal: 1400)],
        targetKcal: 2200,
      ),
    );

    expect(find.text(frasedellaBarra), findsOneWidget);
  });
}
