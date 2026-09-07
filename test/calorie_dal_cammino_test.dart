import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/calorie_dal_cammino.dart';

/// Le calorie del cammino — 07/09/2026.
///
/// ══ 🚨 COSA DIFENDONO QUESTI TEST ════════════════════════════════════════
///
/// Questo numero entra nell'**obiettivo calorico**: decide quanto una persona
/// può mangiare. ⛔ Un errore qui non si vede da nessuna parte — esce un numero
/// plausibile, e chi lo segue mangia trecento calorie di troppo tutti i giorni
/// per mesi.
void main() {
  group('l\'ordine di grandezza', () {
    test('⚠️ una giornata normale sta in una banda sensata', () {
      /*
       * ══ ⛔ QUESTO TEST DICEVA DI ESSERE UN'ANCORA, E NON LO ERA ══════════
       *
       * 🚨 Si chiamava *«8.500 passi a 87 kg e 175 cm fanno ~269 kcal»* e
       * sosteneva di verificare la formula contro il numero vero dell'orologio
       * del committente.
       *
       * ⛔ **Peso e altezza erano quelli del profilo demo del PDF di prova**
       * (*«uomo di 30 anni, 1.75 m, 85 kg»*), non i suoi — che pesa **95/96
       * kg** — e i passi di quel giorno non erano stati misurati ma scelti.
       * 💡 Due incognite adattate a una sola osservazione tornano **sempre**.
       *
       * ⚠️ Quindi adesso questo test dice quello che sa davvero: che una
       * giornata di cammino normale, per una persona di quella corporatura, dà
       * un numero **di quell'ordine di grandezza**. 🚨 Non che sia giusto: che
       * non sia assurdo. La verifica vera è nell'handoff, e serve il telefono.
       */
      /*
       * ✅ **E il 07/09/2026 la verifica vera e arrivata**: 8.192 passi
       * misurati con l aggregato di Health Connect il 06/09, 95 kg dichiarati
       * dal committente, e l orologio quel giorno diceva **269 kcal**.
       *
       * 💡 La stima da fra 275 e 291 kcal a seconda dell altezza: **fra il 2%
       * e l 8%**, sempre per eccesso. 🚨 Gli ingredienti sono stati misurati
       * prima di guardare il risultato — nessuno e stato scelto per farlo
       * tornare.
       */
      final kcal = CalorieDalCammino.kcal(
        passi: 8192,
        pesoKg: 95,
        altezzaCm: 178,
      );

      expect(kcal, closeTo(269, 30));
    });

    test('💡 e i chilometri sono quelli che direbbe un contapassi', () {
      // 8.500 × 0,726 m ≈ 6,2 km.
      expect(
        CalorieDalCammino.km(passi: 8500, altezzaCm: 175),
        closeTo(6.17, 0.05),
      );
    });
  });

  group('le proporzioni', () {
    test('chi pesa di più consuma di più, a parità di passi', () {
      final leggero = CalorieDalCammino.kcal(passi: 8000, pesoKg: 60);
      final pesante = CalorieDalCammino.kcal(passi: 8000, pesoKg: 95);

      expect(pesante, greaterThan(leggero));
    });

    test('chi è più alto fa più strada, a parità di passi', () {
      final basso = CalorieDalCammino.kcal(
        passi: 8000,
        pesoKg: 80,
        altezzaCm: 160,
      );
      final alto = CalorieDalCammino.kcal(
        passi: 8000,
        pesoKg: 80,
        altezzaCm: 190,
      );

      expect(alto, greaterThan(basso));
    });

    test('il doppio dei passi vale il doppio', () {
      final uno = CalorieDalCammino.kcal(passi: 5000, pesoKg: 80);
      final due = CalorieDalCammino.kcal(passi: 10000, pesoKg: 80);

      expect(due, closeTo(uno * 2, 1));
    });
  });

  group('quello che NON si stima', () {
    test('⛔ sotto i 500 passi non è movimento, è andare in bagno', () {
      expect(CalorieDalCammino.kcal(passi: 400, pesoKg: 87), 0);
      expect(CalorieDalCammino.kcal(passi: 0, pesoKg: 87), 0);
    });

    test('⚠️ ma un peso mancante non ferma la stima', () {
      /*
       * 🚨 Il ripiego è **prudente**: chi non si è mai pesato non deve ricevere
       * un margine calorico generoso basato su un peso inventato al rialzo.
       */
      final senzaPeso = CalorieDalCammino.kcal(passi: 8000);
      final conPesoAlto = CalorieDalCammino.kcal(passi: 8000, pesoKg: 95);

      expect(senzaPeso, greaterThan(0));
      expect(senzaPeso, lessThan(conPesoAlto));
    });
  });

  test('🚨 il costo è NETTO, non lordo', () {
    /*
     * ⛔ Camminare costa circa 1 kcal per kg e per km **in tutto**, ma metà è il
     * basale che sarebbe avvenuto comunque. Il nostro obiettivo è già un TDEE,
     * che il basale ce l'ha dentro: col lordo lo conteremmo due volte.
     *
     * 💡 È lo stesso difetto per cui non si legge mai `TOTAL_CALORIES_BURNED`,
     * e vale ~1.600 kcal al giorno con un numero che resta plausibile.
     */
    expect(CalorieDalCammino.costoAlKgPerKm, lessThan(0.7));

    // ⚠️ E non così basso da rendere la stima inutile.
    expect(CalorieDalCammino.costoAlKgPerKm, greaterThan(0.4));
  });
}
