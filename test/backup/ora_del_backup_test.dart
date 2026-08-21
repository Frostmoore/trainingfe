import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/backup/backup_in_background.dart';

/// L'orario del backup notturno — FASE 2.1, 21/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// 📌 Il committente: *«mi metti l'orario in cui lo deve fare alle 4 di mattina,
/// così è attaccato sicuro»*.
///
/// ⚠️ Il vincolo che decide davvero se il lavoro parte è `requiresCharging`: con
/// la finestra a un'ora qualunque del giorno, su un telefono che si carica solo
/// la notte quel momento poteva **non arrivare mai**.
///
/// 💡 `quantoMancaAlleQuattro` è l'unico pezzo di questa storia che si può
/// provare: tutto il resto è Android, e Android in un test non c'è.
void main() {
  test('prima delle quattro punta a oggi', () {
    final quanto = quantoMancaAlleQuattro(DateTime(2026, 8, 21, 1, 30));

    expect(quanto, const Duration(hours: 2, minutes: 30));
  });

  test('dopo le quattro punta a domani', () {
    /*
     * 🚨 **Il caso che conta.** Un ritardo negativo — o zero — farebbe partire
     * il lavoro **subito**, cioè con il telefono probabilmente non in carica.
     * ⚠️ E da lì in poi l'orario resterebbe sbagliato per sempre, perché un
     * lavoro periodico si ancora alla **prima** esecuzione.
     */
    final quanto = quantoMancaAlleQuattro(DateTime(2026, 8, 21, 15, 40));

    expect(quanto, const Duration(hours: 12, minutes: 20));
    expect(quanto.isNegative, isFalse);
  });

  test('alle quattro in punto punta a domani, non adesso', () {
    // 💡 Il confine: `isAfter` e non `isAfterOrEqual`. Alle 04:00:00 esatte il
    // bersaglio è già passato — puntarci darebbe un ritardo di zero.
    final quanto = quantoMancaAlleQuattro(DateTime(2026, 8, 21, 4));

    expect(quanto, const Duration(hours: 24));
  });

  test('non è mai negativo, a qualunque ora', () {
    for (var ora = 0; ora < 24; ora++) {
      for (final minuto in [0, 1, 59]) {
        final quanto = quantoMancaAlleQuattro(
          DateTime(2026, 8, 21, ora, minuto),
        );

        expect(quanto.isNegative, isFalse, reason: 'alle $ora:$minuto');
        expect(quanto.inHours, lessThanOrEqualTo(24));
      }
    }
  });
}
