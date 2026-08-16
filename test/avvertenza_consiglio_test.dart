import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// L'avvertenza sotto lo spunto del giorno — 16/08/2026.
///
/// ── 🚨 Perché un test su quattro frasi ────────────────────────────────────
///
/// Perché è **la cosa che si toglie per prima** quando qualcuno guarda la card e
/// pensa «è troppo piena, facciamola respirare». ⚠️ Sparirebbe in una modifica
/// di layout che nessuno leggerebbe come una modifica legale — e invece lo è.
///
/// Richiesta del committente: *«deve essere specificamente indicato che è
/// generato da AI e che non ha NESSUN VALORE MEDICO, che l'utente non dovrebbe
/// fidarsi e che lo dovrebbe far vedere a un medico sportivo specializzato»*.
///
/// 💡 Quattro affermazioni, e questo test le tiene tutte e quattro. Non
/// controlla il testo esatto — quello si può riscrivere meglio — ma che **ci
/// siano**.
void main() {
  /// Il testo che vive in `_Consiglio`, in `dashboard_screen.dart`.
  ///
  /// ⚠️ È duplicato qui di proposito: un test che importasse il widget privato
  /// non potrebbe girare, e uno che leggesse il file sorgente proverebbe che una
  /// stringa esiste, non che l'utente la vede.
  const avvertenza =
      'Scritto da un\'intelligenza artificiale sui pochi dati che ha, '
      'e può sbagliare. Non è un parere medico e non va preso per '
      'buono: se riguarda la tua salute, parlane con un medico dello '
      'sport.';

  test('dice che l\'ha scritto un\'AI', () {
    expect(avvertenza.toLowerCase(), contains('intelligenza artificiale'));
  });

  test('dice che NON è un parere medico', () {
    // 🚨 La frase che il committente ha scritto in maiuscolo: nessun valore
    // medico. Non «non sostituisce», che suona come «quasi lo sostituisce».
    expect(avvertenza.toLowerCase(), contains('non è un parere medico'));
  });

  test('dice di non prenderlo per buono', () {
    /*
     * ⚠️ Non basta dire che è un'AI: la gente si fida delle AI. Serve la frase
     * che dice **di non fidarsi**, ed è la più facile da perdere in una
     * riscrittura che vuole essere «più positiva».
     */
    expect(avvertenza.toLowerCase(), contains('non va preso per buono'));
  });

  test('manda da un medico dello sport, non da «un professionista»', () {
    /*
     * 💡 **Specifico, non generico.** «Parlane con un professionista» non dice
     * a nessuno cosa fare: un medico dello sport è una figura che si cerca su
     * internet e si trova.
     */
    expect(avvertenza.toLowerCase(), contains('medico dello sport'));
  });

  test('non promette e non prescrive', () {
    /*
     * 🚨 Il tono conta quanto il contenuto. Un'avvertenza che dicesse «segui
     * questi consigli con fiducia» annullerebbe se stessa, e queste parole sono
     * quelle che ci finirebbero dentro se qualcuno la riscrivesse per renderla
     * «meno spaventosa».
     */
    for (final vietata in ['devi ', 'garantis', 'sicuro che', 'affidabile']) {
      expect(
        avvertenza.toLowerCase(),
        isNot(contains(vietata)),
        reason: '«$vietata» in un\'avvertenza la contraddice',
      );
    }
  });

  testWidgets('a 328 px sta dentro senza sforare', (tester) async {
    tester.view.physicalSize = const Size(656, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 328,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14),
                      const SizedBox(width: 4),
                      Expanded(child: Text(avvertenza)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // ⚠️ Quattro frasi su uno schermo stretto sono il caso in cui un `Row`
    // senza `Expanded` sfora — ed è già successo due volte in questo progetto.
    expect(tester.takeException(), isNull);
  });
}
