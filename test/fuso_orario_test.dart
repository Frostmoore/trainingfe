import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/data/dashboard_models.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';

/// A3 — **gli istanti che arrivano dal server vanno riportati in locale**.
///
/// ── 🚨 Il difetto ─────────────────────────────────────────────────────────
///
/// Il server manda un ISO8601 con l'offset (`2026-08-11T22:30:00+00:00`), e
/// `DateTime.parse` su una stringa così restituisce un `DateTime` **con
/// `isUtc == true`**. Dart non se ne dimentica, ma nemmeno lo converte: ogni
/// `DateFormat(...).format()` legge i componenti **UTC**.
///
/// Il risultato era che l'allenamento delle 20:00 compariva come «18:00», e
/// quello di mezzanotte e mezza veniva raggruppato nella settimana precedente —
/// perché `DateTime(d.year, d.month, d.day)` prende anno, mese e giorno
/// dall'oggetto che riceve, e su un `DateTime` in UTC quelli sono i componenti
/// di Greenwich.
///
/// ⚠️ **Questi test non guardano l'ora del telefono che li esegue.** Verificano
/// l'invariante — «l'istante è in locale» — che vale in qualunque fuso, CI
/// compresa. Un test che si aspettasse «le 20» passerebbe solo in Italia.
void main() {
  /// Le 00:30 del 12 agosto 2026 a Roma, cioè le 22:30 dell'11 in UTC.
  const dopoMezzanotteARoma = '2026-08-11T22:30:00+00:00';

  Map<String, dynamic> sessione(String quando) => {
    'id': 1,
    'started_at': quando,
    'ended_at': quando,
    'is_open': false,
    'sets': const [],
    'photos': const [],
  };

  group('WorkoutSession', () {
    test('l\'istante di inizio non resta in UTC', () {
      final s = WorkoutSession.fromJson(sessione(dopoMezzanotteARoma));

      expect(
        s.startedAt.isUtc,
        isFalse,
        reason: 'un DateTime in UTC verrebbe formattato con l\'ora di Greenwich',
      );
      expect(s.endedAt!.isUtc, isFalse);
    });

    test('l\'istante resta lo stesso: cambia il fuso, non il momento', () {
      final s = WorkoutSession.fromJson(sessione(dopoMezzanotteARoma));

      expect(
        s.startedAt.toUtc(),
        DateTime.parse(dopoMezzanotteARoma).toUtc(),
        reason: '.toLocal() non deve spostare l\'istante, solo come lo si legge',
      );
    });

    test('i componenti sono quelli dell\'orologio del telefono', () {
      final s = WorkoutSession.fromJson(sessione(dopoMezzanotteARoma));
      final atteso = DateTime.parse(dopoMezzanotteARoma).toLocal();

      // 🚨 È il campo che `_lunedi()` usa per raggruppare lo storico: se
      // `day` fosse quello UTC, la seduta finirebbe nella settimana sbagliata.
      expect(s.startedAt.year, atteso.year);
      expect(s.startedAt.month, atteso.month);
      expect(s.startedAt.day, atteso.day);
      expect(s.startedAt.hour, atteso.hour);
    });
  });

  group('RecentWorkout', () {
    test('anche gli allenamenti recenti della dashboard sono in locale', () {
      final r = RecentWorkout.fromJson({
        'id': 7,
        'name': 'Petto',
        'started_at': dopoMezzanotteARoma,
        'sets_count': 12,
        'is_open': false,
      });

      expect(r.startedAt.isUtc, isFalse);
      expect(r.startedAt.toUtc(), DateTime.parse(dopoMezzanotteARoma).toUtc());
    });
  });

  group('la data del riepilogo', () {
    /// ⚠️ **`date` è un\'etichetta, non un istante**, e va lasciata in pace.
    ///
    /// Il server manda `2026-08-12`: senza offset, `DateTime.parse` costruisce
    /// già una data locale. Aggiungerci `.toLocal()` non farebbe niente, ma
    /// trattarla come un istante — per esempio parsandola come UTC e poi
    /// convertendola — la sposterebbe **indietro di un giorno** a ogni fuso a
    /// est di Greenwich. È la stessa distinzione che lato server tiene separati
    /// `etichetta` e `inizio()`.
    test('resta il giorno che il server ha scritto', () {
      final d = DashboardSummary.fromJson({
        'date': '2026-08-12',
        'now': dopoMezzanotteARoma,
        'hour': 0,
        'day_progress_pct': 0,
      });

      expect(d.date.year, 2026);
      expect(d.date.month, 8);
      expect(d.date.day, 12);
    });
  });
}
