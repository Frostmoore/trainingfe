import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/profile/data/calcolatore_calorie.dart';

/// 🚨 **Il ritratto di `CalorieCalculatorTest` — S5.1.**
///
/// I valori attesi sono **gli stessi del test PHP**, non ricalcolati: è così che
/// si dimostra che la traduzione è fedele. Se un giorno i due lati
/// divergessero, il confronto si fa riga per riga.
void main() {
  const calc = CalcolatoreCalorie();

  group('gli indici', () {
    test('il BMI è quello classico', () {
      expect(calc.bmi(80, 180), 24.7);
    });

    test('un\'altezza a zero non produce infinito, lancia', () {
      // ⚠️ Senza questo controllo il BMI sarebbe `Infinity`, che poi viaggia
      // silenziosamente dentro TDEE e target: il primo numero visibile
      // sarebbe un obiettivo calorico assurdo, e nessuno risalirebbe qui.
      expect(() => calc.bmi(80, 0), throwsArgumentError);
    });

    test('il metabolismo basale segue Mifflin-St Jeor', () {
      expect(calc.bmr(sesso: 'male', kg: 80, cm: 180, eta: 30), 1780.0);
      expect(calc.bmr(sesso: 'female', kg: 60, cm: 165, eta: 30), 1320.3);
    });

    /// 🚨 Un sesso sconosciuto usa la costante **femminile**, la più prudente.
    ///
    /// Un fabbisogno sottostimato porta a un deficit più piccolo del previsto;
    /// uno sovrastimato porta a mangiare più del necessario credendo di essere
    /// a target. Fra i due errori si sceglie sempre il primo.
    test('un sesso sconosciuto usa la costante più prudente', () {
      expect(
        calc.bmr(sesso: 'altro', kg: 60, cm: 165, eta: 30),
        calc.bmr(sesso: 'female', kg: 60, cm: 165, eta: 30),
      );
    });

    test('il TDEE moltiplica per il livello di attività', () {
      expect(calc.tdee(1780, 'moderate'), 2759.0);
    });

    /// ⚠️ Un livello sconosciuto vale `sedentary`: è il più basso, quindi il
    /// più prudente. Lanciare avrebbe rotto un profilo salvato con un valore
    /// vecchio.
    test('un livello sconosciuto vale sedentario', () {
      expect(calc.tdee(2000, 'divano'), calc.tdee(2000, 'sedentary'));
    });
  });

  group('il target calorico', () {
    test('applica lo scostamento dell\'obiettivo', () {
      expect(calc.targetCalorico(3000, 'lose'), 2550);
      expect(calc.targetCalorico(3000, 'cut'), 2250);
      expect(calc.targetCalorico(3000, 'maintain'), 3000);
      expect(calc.targetCalorico(3000, 'bulk'), 3360);
    });

    /// 🚨 **Il pavimento a 1.200 kcal non è negoziabile.**
    ///
    /// Sotto quella soglia un piano alimentare non è più una dieta, e questo
    /// sistema non è un dispositivo medico. È la prima riga che si perde
    /// riscrivendo «uguale ma in un'altra lingua», e la sola il cui
    /// smarrimento farebbe male a qualcuno.
    test('non scende mai sotto 1200 kcal', () {
      expect(calc.targetCalorico(1400, 'cut'), 1200);
      expect(calc.targetCalorico(800, 'cut'), 1200);
    });

    test('un obiettivo sconosciuto vale mantenimento', () {
      expect(calc.targetCalorico(2500, 'qualcosa'), calc.targetCalorico(2500, 'maintain'));
    });
  });

  group('i macro', () {
    test('si ripartiscono in percentuale del target', () {
      final m = calc.macro(2000, 'maintain');

      expect(m.proteineG, 125);
      expect(m.carboidratiG, 240);
      expect(m.grassiG, 60);
    });

    /// ⚠️ In deficit le proteine salgono: servono a limitare la perdita di massa
    /// magra, che è esattamente ciò che chi dimagrisce non vuole perdere.
    test('in deficit le proteine salgono', () {
      final mantieni = calc.macro(2000, 'maintain');
      final taglia = calc.macro(2000, 'cut');

      expect(taglia.proteineG, greaterThan(mantieni.proteineG));
    });

    /// 🚨 I macro devono **ricomporre** il target, o l'app mostrerebbe tre
    /// barre che sommate danno un numero diverso da quello scritto sopra.
    test('i macro ricompongono il target entro l\'arrotondamento', () {
      for (final obiettivo in ['lose', 'cut', 'maintain', 'bulk']) {
        final m = calc.macro(2000, obiettivo);
        final ricomposto = calc.kcalDaMacro(
          m.proteineG.toDouble(),
          m.carboidratiG.toDouble(),
          m.grassiG.toDouble(),
        );

        expect(ricomposto, closeTo(2000, 6), reason: 'obiettivo $obiettivo');
      }
    });
  });

  group('l\'età', () {
    /// ⚠️ **Compiuta**, non «anni trascorsi»: chi compie gli anni domani ne ha
    /// ancora uno in meno oggi.
    test('chi non ha ancora compiuto gli anni ne ha uno in meno', () {
      final nascita = DateTime(1990, 8, 12);

      expect(calc.etaDa(nascita, adesso: DateTime(2026, 8, 11)), 35);
      expect(calc.etaDa(nascita, adesso: DateTime(2026, 8, 12)), 36);
    });
  });
}
