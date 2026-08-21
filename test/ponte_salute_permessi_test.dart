import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:training_companion/src/features/health/ponte_salute.dart';

/// Quello che chiediamo e quello che leggiamo — FASE 1.8, 19/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// `PonteSalute` tiene **due** elenchi di tipi, e la differenza fra i due non e'
/// una svista: e' la difesa contro il doppio conteggio del metabolismo basale.
///
/// | Elenco | A cosa serve |
/// |---|---|
/// | `tipiDaAutorizzare` | cosa compare nella schermata del consenso |
/// | `tipiDaLeggere` | cosa chiediamo davvero a Health Connect |
///
/// ⚠️ Il giorno in cui qualcuno «semplifica» unendo i due elenchi, questi test
/// diventano rossi. E' esattamente il loro mestiere: la semplificazione sembra
/// giusta, e costa +1.600 kcal al giorno con un numero che resta plausibile.
void main() {
  group('I permessi degli allenamenti', () {
    /// 🚨 Il difetto vero del 19/08: i tre permessi erano nel manifest ma
    /// **nessuno li chiedeva**, perche' il pacchetto costruisce l'elenco dai
    /// tipi e `WORKOUT` traduce nel solo `READ_EXERCISE`. Risultato:
    /// `granted=false` per sempre, e `SecurityException` a ogni lettura.
    test('si chiedono i tre tipi che il pacchetto pretende', () {
      expect(
        PonteSalute.tipiDaAutorizzare,
        contains(HealthDataType.DISTANCE_DELTA),
      );
      expect(PonteSalute.tipiDaAutorizzare, contains(HealthDataType.STEPS));
      expect(
        PonteSalute.tipiDaAutorizzare,
        contains(HealthDataType.TOTAL_CALORIES_BURNED),
      );
    });

    test('e ovviamente anche gli allenamenti', () {
      expect(PonteSalute.tipiDaAutorizzare, contains(HealthDataType.WORKOUT));
    });
  });

  group('La regola non negoziabile', () {
    /// ══ 🚨 Il test che conta piu' di tutti ═══════════════════════════════
    ///
    /// `TOTAL_CALORIES_BURNED` comprende il **metabolismo basale**. Lo chiediamo
    /// solo perche' il pacchetto lo legge da se', dentro l'intervallo di una
    /// singola sessione, per riempirne le calorie.
    ///
    /// ⚠️ Leggerlo per la **giornata** lo sommerebbe a un obiettivo che e' gia'
    /// un TDEE — il basale ce l'ha dentro — contandolo due volte.
    test('le calorie TOTALI non si leggono mai per la giornata', () {
      expect(
        PonteSalute.tipiDaLeggere,
        isNot(contains(HealthDataType.TOTAL_CALORIES_BURNED)),
        reason:
            'Comprende il metabolismo basale: per la giornata vale solo '
            'ACTIVE_ENERGY_BURNED, o si contano due volte ~1.600 kcal.',
      );
    });

    test('per la giornata vale ACTIVE_ENERGY_BURNED', () {
      expect(
        PonteSalute.tipiDaLeggere,
        contains(HealthDataType.ACTIVE_ENERGY_BURNED),
      );
    });

    /// 💡 Passi e distanza sono il dato buono **di una corsa**, non della
    /// giornata: li lascia il pacchetto dentro la sessione. Chiederli a parte
    /// vorrebbe dire tirarsi in casa migliaia di campioni che nessuno guarda.
    test('passi e distanza si chiedono ma non si leggono a parte', () {
      expect(PonteSalute.tipiDaLeggere, isNot(contains(HealthDataType.STEPS)));
      expect(
        PonteSalute.tipiDaLeggere,
        isNot(contains(HealthDataType.DISTANCE_DELTA)),
      );
    });
  });

  /// 🚨 La traccia GPS: dove abiti e che giro fai la domenica. E' il dato piu'
  /// identificante che il telefono possieda, e non serve a niente di quello che
  /// facciamo.
  test('la traccia GPS non si chiede e non si legge', () {
    expect(
      PonteSalute.tipiDaAutorizzare,
      isNot(contains(HealthDataType.WORKOUT_ROUTE)),
    );
    expect(
      PonteSalute.tipiDaLeggere,
      isNot(contains(HealthDataType.WORKOUT_ROUTE)),
    );
  });

  /// ⚠️ Chi legge deve poter fidarsi che l'elenco lungo **contenga** quello
  /// corto: chiedere meno di quel che si legge e' il difetto opposto, e finisce
  /// nello stesso posto — lista vuota e nessun errore visibile.
  test('si chiede sempre almeno tutto quello che si legge', () {
    for (final tipo in PonteSalute.tipiDaLeggere) {
      expect(PonteSalute.tipiDaAutorizzare, contains(tipo));
    }
  });
}
