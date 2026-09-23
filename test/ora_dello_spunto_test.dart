import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/ui/dashboard_screen.dart';

/// 🕒 **Lo Spunto dice di quando è** — 23/09/2026.
///
/// 📌 Decisione del committente, dopo averlo visto sul suo telefono:
/// *«hai ragione, deve dire di quando è, facciamolo»*.
///
/// ⛔ **Il caso vero**: alle 21:29 lo Spunto diceva *«Sei a 982 kcal con il 73%
/// della giornata passato»* mentre la card sopra diceva **0 / 1904 kcal**. Due
/// numeri che si contraddicono a distanza di un dito.
///
/// 🚨 **E nessuno dei due era sbagliato**: il consiglio era stato scritto nel
/// pomeriggio, quando quei numeri erano veri. ⚠️ Ma senza un'ora accanto, chi
/// legge conclude che l'app conta male — la cosa peggiore che possa concludere
/// di un'applicazione che conta le calorie.
///
/// ══ 🚨 QUELLO CHE QUESTO TEST DIFENDE DAVVERO: `.toLocal()` ═════════════════
///
/// Il server gira in **UTC** (`config/app.php` → `'timezone' => 'UTC'`), quindi
/// `generated_at` arriva come `…T13:04:00+00:00`. `DateTime.parse` di un
/// istante con offset restituisce un `DateTime` **in UTC**: stamparlo così
/// scriverebbe «13:04» per un consiglio scritto alle **15:04** italiane.
///
/// 💡 Su una riga che esiste *apposta* per dire quando una cosa è stata
/// scritta, un'ora sbagliata è **peggio di nessuna ora**.
void main() {
  group('l\'ora dello Spunto', () {
    test('è quella del telefono, non quella del server', () {
      // Quello che manda il server: mezzogiorno e quattro, in UTC.
      final dalServer = DateTime.parse('2026-09-23T13:04:00+00:00');

      expect(
        dalServer.isUtc,
        isTrue,
        reason:
            'Se questo cambia, è cambiato Dart: l\'intera ragione di '
            '.toLocal() sta qui.',
      );

      final locale = dalServer.toLocal();
      final atteso =
          'Scritto alle ${locale.hour.toString().padLeft(2, '0')}'
          ':${locale.minute.toString().padLeft(2, '0')}';

      expect(scrittoAlle(dalServer), atteso);

      /*
       * ⚠️ **Onestà sul limite di questo test.** Su una macchina che gira in
       * UTC, ora locale e ora del server coincidono e togliere `.toLocal()`
       * non farebbe fallire niente: il test resterebbe verde su un difetto
       * vero. 💡 Qui lo si dice invece di fingere che copra tutto — e sulle
       * macchine italiane, che sono quelle su cui si lavora, copre.
       */
      if (locale.hour == dalServer.hour) {
        printOnFailure(
          'Questa macchina gira su UTC: il confronto non distingue '
          'toLocal() dal suo contrario.',
        );
      }
    });

    test('mette lo zero davanti alle ore piccole', () {
      // 🚨 Un consiglio scritto alle 9:05 non deve leggersi «9:5».
      final istante = DateTime(2026, 9, 23, 9, 5);

      expect(scrittoAlle(istante), 'Scritto alle 09:05');
    });

    test('a mezzanotte scrive 00, non 24', () {
      expect(scrittoAlle(DateTime(2026, 9, 23)), 'Scritto alle 00:00');
    });
  });
}
