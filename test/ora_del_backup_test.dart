import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/chiavi/ui/schermata_backup.dart';

/// L'ora dell'ultimo backup, **nel fuso di chi guarda** — 25/08/2026.
///
/// ══ 🚨 IL DIFETTO ═════════════════════════════════════════════════════════
///
/// 📌 *«il backup mi mette l'orario in UTC non nell'orario del mio fuso»*.
///
/// ⛔ Drive manda `modifiedTime` in **UTC** e `googleapis` lo consegna con
/// `isUtc = true`. La schermata ne leggeva `.hour` così com'era: in Italia
/// d'estate, **due ore indietro**.
///
/// ⚠️ **Il test non fissa un'ora scritta a mano** — sarebbe verde solo sul fuso
/// di chi l'ha scritto, e in CI direbbe bugie. Confronta invece la stessa
/// istante espresso nei due modi: qualunque sia il fuso della macchina, la
/// risposta deve essere **la stessa**.
void main() {
  group('🕒 l\'ora è quella di chi legge', () {
    test('UTC e locale dello stesso istante dicono la stessa cosa', () {
      final adesso = DateTime.now();

      expect(daQuando(adesso.toUtc()), daQuando(adesso));
    });

    /// 🚨 È il caso vero: la data arriva da Drive, quindi **è** UTC.
    test('e l\'ora mostrata è quella locale, non quella di Greenwich', () {
      final locale = DateTime.now().copyWith(hour: 9, minute: 30, second: 0);

      expect(daQuando(locale.toUtc()), 'oggi alle 09:30');
    });

    /// ⚠️ Su un fuso a est di Greenwich, un backup di mezzanotte e mezza letto
    /// in UTC cade **il giorno prima**: sbagliava l'ora e anche il giorno.
    test('a mezzanotte e mezza resta «oggi», non diventa «ieri»', () {
      final locale = DateTime.now().copyWith(hour: 0, minute: 30, second: 0);

      expect(daQuando(locale.toUtc()), 'oggi alle 00:30');
    });
  });

  group('📅 i giorni si contano per data, non a blocchi di 24 ore', () {
    /// ⛔ `difference().inDays` su un backup delle 23:00 di ieri risponde `0`
    /// fino alle 23:00 di oggi: scriveva **«oggi»** per una cosa di ieri, in una
    /// riga che serve a decidere se ripristinare.
    test('le 23:00 di ieri sono «ieri» anche alle 8 del mattino', () {
      final adesso = DateTime.now();
      final ieriSera = DateTime(
        adesso.year,
        adesso.month,
        adesso.day,
      ).subtract(const Duration(hours: 1));

      expect(daQuando(ieriSera), 'ieri alle 23:00');
    });

    test('e le 00:10 di stanotte sono «oggi»', () {
      final adesso = DateTime.now();
      final stanotte = DateTime(adesso.year, adesso.month, adesso.day, 0, 10);

      expect(daQuando(stanotte), 'oggi alle 00:10');
    });

    /// 💡 Da tre giorni in poi l'ora non aggiunge niente e allunga una riga che
    /// sta già stretta.
    test('da tre giorni in poi si contano e basta', () {
      final treGiorniFa = DateTime.now().subtract(const Duration(days: 3));

      expect(daQuando(treGiorniFa), '3 giorni fa');
    });
  });
}
