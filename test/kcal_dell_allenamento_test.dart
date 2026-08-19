import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:training_companion/src/features/health/ponte_salute.dart';

/// Le calorie di un allenamento — corretto il 20/08/2026.
///
/// ── ══ 🚨 Il difetto che questo file impedisce di rifare ══ ────────────────
///
/// La prima versione prendeva `WorkoutHealthValue.totalEnergyBurned`, cioè
/// `TotalCaloriesBurnedRecord`, che comprende il **metabolismo basale**.
///
/// ⚠️ Il committente se n'è accorto in un minuto, perché aveva il numero vero
/// sotto gli occhi: *«l'app zepp mi dice che quell'allenamento ha bruciato 680
/// kcal»*, e la nostra ne mostrava **835**.
///
/// 💡 È lo **stesso** errore che la regola sul totale giornaliero vieta, solo in
/// scala più piccola — ed era sfuggito proprio perché quella regola parlava
/// della giornata e questa è una sessione.
void main() {
  final inizio = DateTime(2026, 8, 19, 17, 46, 48);
  final fine = DateTime(2026, 8, 19, 18, 48, 33);

  HealthDataPoint punto({
    required HealthDataType tipo,
    required HealthValue valore,
    required DateTime da,
    required DateTime a,
  }) =>
      HealthDataPoint(
        uuid: '$tipo-$da',
        value: valore,
        type: tipo,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: da,
        dateTo: a,
        sourcePlatform: HealthPlatformType.googleHealthConnect,
        sourceDeviceId: 'orologio',
        sourceId: 'com.huami.watch.hmwatchmanager',
        sourceName: 'com.huami.watch.hmwatchmanager',
      );

  HealthDataPoint allenamento({int? totali}) => punto(
        tipo: HealthDataType.WORKOUT,
        valore: WorkoutHealthValue(
          workoutActivityType: HealthWorkoutActivityType.STRENGTH_TRAINING,
          totalEnergyBurned: totali,
          totalDistance: 211,
          totalSteps: 662,
        ),
        da: inizio,
        a: fine,
      );

  HealthDataPoint attive(num kcal, {DateTime? da, DateTime? a}) => punto(
        tipo: HealthDataType.ACTIVE_ENERGY_BURNED,
        valore: NumericHealthValue(numericValue: kcal),
        da: da ?? inizio,
        a: a ?? fine,
      );

  /// ══ Il caso vero, con i numeri veri del 19/08 ═══════════════════════════
  test('vince il campione ATTIVO, non il totale con il basale dentro', () {
    final letti = PonteSalute.allenamentiDa([
      allenamento(totali: 835),
      attive(680),
    ]);

    expect(letti.single.kcal, 680, reason: 'È il numero che mostra l\'app dell\'orologio.');
  });

  /// 🚨 Nessun ripiego su `totalEnergyBurned`: sarebbe rimettere dentro il
  /// basale di nascosto, e il numero tornerebbe plausibile e sbagliato.
  test('senza campioni attivi non si inventa niente', () {
    final letti = PonteSalute.allenamentiDa([allenamento(totali: 835)]);

    expect(letti.single.kcal, isNull);
  });

  /// ⚠️ «Non lo so» e «non hai bruciato niente» sono due cose diverse: uno zero
  /// inventato è peggio di un campo vuoto.
  test('e nemmeno uno zero', () {
    final letti = PonteSalute.allenamentiDa([allenamento()]);

    expect(letti.single.kcal, isNot(0));
    expect(letti.single.kcal, isNull);
  });

  group('I campioni che non coincidono con la sessione', () {
    /// 💡 Zepp ne scrive uno solo, che coincide. Altre app spezzettano.
    test('più campioni dentro si sommano', () {
      final meta = inizio.add(const Duration(minutes: 30));

      final letti = PonteSalute.allenamentiDa([
        allenamento(),
        attive(300, da: inizio, a: meta),
        attive(380, da: meta, a: fine),
      ]);

      expect(letti.single.kcal, 680);
    });

    /// 🚨 Un campione che sborda si conta **in proporzione**: contarlo intero
    /// gonfierebbe una corsa di venti minuti con l'ora di camminata che la
    /// precede.
    test('un campione a cavallo entra solo per la parte che ci sta', () {
      // Un'ora di campione, di cui solo la seconda metà dentro l'allenamento.
      final letti = PonteSalute.allenamentiDa([
        allenamento(),
        attive(
          200,
          da: inizio.subtract(const Duration(minutes: 30)),
          a: inizio.add(const Duration(minutes: 30)),
        ),
      ]);

      expect(letti.single.kcal, 100);
    });

    /// ⚠️ E uno completamente fuori non entra affatto: è la camminata di
    /// stamattina, non l'allenamento di stasera.
    test('un campione fuori dalla finestra non entra', () {
      final letti = PonteSalute.allenamentiDa([
        allenamento(),
        attive(
          500,
          da: inizio.subtract(const Duration(hours: 5)),
          a: inizio.subtract(const Duration(hours: 4)),
        ),
      ]);

      expect(letti.single.kcal, isNull);
    });
  });

  /// 💡 Distanza e passi restano quelli dell'orologio: lì non c'è nessun basale
  /// da togliere, e il pacchetto li legge dai record giusti.
  test('distanza e passi restano quelli della sessione', () {
    final letti = PonteSalute.allenamentiDa([allenamento(), attive(680)]);

    expect(letti.single.distanzaMetri, 211);
    expect(letti.single.passi, 662);
    expect(letti.single.tipo, 'STRENGTH_TRAINING');
  });
}
