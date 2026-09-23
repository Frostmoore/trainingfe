import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:training_companion/src/features/dashboard/ui/dashboard_screen.dart';

/// 🕒 **Lo Spunto dice di quando è** — 23/09/2026.
///
/// 📌 Decisione del committente: *«hai ragione, deve dire di quando è,
/// facciamolo»*.
///
/// ⛔ **Il caso che l'ha fatto notare**: alle 21:29 lo Spunto diceva *«Sei a
/// 982 kcal con il 73% della giornata passato»* mentre la card sopra diceva
/// **0 / 1904 kcal**.
///
/// ══ 🚨 E LA PRIMA CORREZIONE ERA SBAGLIATA ═════════════════════════════════
///
/// La prima versione scriveva **solo l'ora**, dando per buono che un consiglio
/// mostrato fosse di oggi. 🔍 Il committente, guardando la sua dashboard:
/// *«il consiglio non può essere stato scritto oggi alle 15 e qualcosa, era
/// ieri che avevo segnato gli alimenti, oggi non l'ho fatto»*.
///
/// 🚨 Aveva ragione, e l'ora da sola **peggiorava** le cose: «Scritto alle
/// 15:04» sopra un consiglio di ieri è una data falsa scritta da noi, dove
/// prima c'era solo un silenzio.
///
/// 💡 **Perché succede**: quando non c'è niente di nuovo da dire,
/// `chiediIlConsiglio` ripiega su `archivio.ultimoConsiglio()` — ed è *giusto*
/// (*«niente di nuovo, ma il consiglio di stamattina c'è»*). ⛔ Quel consiglio
/// però può essere di ieri, e `consiglio_da_mostrare.dart` lo marca comunque
/// `fresco`: la data non arrivava mai a schermo.
void main() {
  setUpAll(() => initializeDateFormatting('it'));

  /// Un momento fisso, per non dipendere dal giorno in cui gira il test.
  final adesso = DateTime(2026, 9, 23, 21, 29);

  group('l\'ora dello Spunto', () {
    test('di oggi: solo l\'ora', () {
      expect(
        scrittoAlle(DateTime(2026, 9, 23, 15, 4), adesso: adesso),
        'Scritto alle 15:04',
      );
    });

    test('🚨 di ieri: lo dice, invece di far credere che sia di oggi', () {
      // ⛔ È **esattamente** il caso del committente: segnato il cibo ieri,
      //    niente oggi, e il consiglio di ieri ancora a schermo.
      expect(
        scrittoAlle(DateTime(2026, 9, 22, 15, 4), adesso: adesso),
        'Scritto ieri alle 15:04',
      );
    });

    test('più vecchio: la data per esteso', () {
      expect(
        scrittoAlle(DateTime(2026, 9, 20, 9, 5), adesso: adesso),
        'Scritto il 20 settembre alle 09:05',
      );
    });

    test('⚠️ un orologio indietro non fa nascere un «domani»', () {
      /*
       * 🚨 Se l'orologio del telefono è indietro di qualche minuto rispetto al
       * server, un consiglio appena nato risulta del giorno dopo. ⛔ «Scritto
       * domani alle 00:02» è il tipo di assurdità che fa chiudere l'app.
       */
      expect(
        scrittoAlle(
          DateTime(2026, 9, 24, 0, 2),
          adesso: DateTime(2026, 9, 23, 23, 58),
        ),
        'Scritto alle 00:02',
      );
    });

    test('lo zero davanti alle ore piccole', () {
      expect(
        scrittoAlle(DateTime(2026, 9, 23, 9, 5), adesso: adesso),
        'Scritto alle 09:05',
      );
    });

    test('a mezzanotte scrive 00, non 24', () {
      expect(
        scrittoAlle(DateTime(2026, 9, 23), adesso: adesso),
        'Scritto alle 00:00',
      );
    });

    test('l\'ora è quella del telefono, non quella del server', () {
      /*
       * ⚠️ **Rete, non correzione.** `chiediIlConsiglio` localizza già
       * `generated_at` quando lo legge, quindi oggi qui arriva un orario
       * locale. 🚨 Resta coperto perché il server gira in **UTC**
       * (`trainingbe/config/app.php`): il giorno che un istante grezzo
       * arrivasse fin qui, senza `.toLocal()` si leggerebbe «13:04» per un
       * consiglio delle 15:04.
       *
       * ⛔ Su una macchina che gira in UTC questo confronto non distingue
       * niente: lo si dice invece di fingere che copra tutto.
       */
      final dalServer = DateTime.parse('2026-09-23T13:04:00+00:00');
      final locale = dalServer.toLocal();

      expect(
        scrittoAlle(dalServer, adesso: adesso),
        'Scritto alle ${locale.hour.toString().padLeft(2, '0')}'
        ':${locale.minute.toString().padLeft(2, '0')}',
      );
    });
  });
}
