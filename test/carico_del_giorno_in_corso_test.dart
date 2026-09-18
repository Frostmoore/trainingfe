import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/forma/carica_batteria.dart';
import 'package:training_companion/src/features/forma/forma_controller.dart';

/// 🌙 **Il Carico e la Prontezza dell'header** — 3b-AD.5, 18/09/2026.
///
/// 📌 *«Prontezza e carico nell'header di «Oggi»: nascono dagli stessi giorni, e
/// vanno guardati»*. Guardati, avevano due difetti:
///
/// 1. ⛔ lo z del carico leggeva il giorno di **27 giorni fa** (`carico.first`
///    su una lista che va dal più vecchio al più recente);
/// 2. ⛔ il carico cambiava giorno **a mezzanotte**, la Carica al risveglio.
void main() {
  group('lo z del carico guarda il giorno in corso', () {
    /// 🚨 **Il caso vero**: un allenamento pesante quattro settimane fa, e oggi
    /// niente. Prima la prontezza pagava quello di quattro settimane fa.
    test('un allenamento di 27 giorni fa non pesa su oggi', () {
      final carico = List<double>.filled(28, 300);
      carico[0] = 3000; // 27 giorni fa
      carico[27] = 0; // oggi, riposo

      final z = zDelCarico(carico)!;

      expect(z, lessThan(0), reason: 'oggi è riposo: sotto la propria media');
    });

    test("l'allenamento pesante di oggi alza lo z", () {
      final carico = List<double>.filled(28, 300);
      carico[27] = 3000;

      expect(zDelCarico(carico)!, greaterThan(1));
    });

    test('con meno di due giorni visti non c\'è z', () {
      final carico = List<double>.filled(28, 0);
      carico[27] = 500;

      expect(zDelCarico(carico), isNull);
    });
  });

  group('il giorno del carico comincia al risveglio', () {
    final alle0030 = DateTime(2026, 9, 18, 0, 30);
    final ieriAlle23 = DateTime(2026, 9, 17, 23);

    /// 🚨 **Il difetto**: alle 00:30, senza aver dormito, l'allenamento delle
    /// 23 passava a «ieri» e oggi valeva zero — il carico acuto calava di un
    /// quarto a mezzanotte.
    test("prima di dormire l'allenamento di ieri sera è ancora oggi", () {
      final carico = caricoDeiGiorni(
        [(quando: ieriAlle23, kcal: 600)],
        oggi: alle0030,
        ancoraIeri: true,
        finestra: 7,
      );

      expect(carico.last, 600);
    });

    test('e quello che si fa dopo la mezzanotte si somma lì', () {
      final carico = caricoDeiGiorni(
        [
          (quando: ieriAlle23, kcal: 600),
          (quando: DateTime(2026, 9, 18, 0, 10), kcal: 100),
        ],
        oggi: alle0030,
        ancoraIeri: true,
        finestra: 7,
      );

      expect(carico.last, 700);
    });

    test('dopo la notte, il giorno è quello di calendario', () {
      final carico = caricoDeiGiorni(
        [(quando: ieriAlle23, kcal: 600)],
        oggi: DateTime(2026, 9, 18, 8),
        ancoraIeri: false,
        finestra: 7,
      );

      expect(carico.last, 0);
      expect(carico[5], 600);
    });

    test('senza calorie la voce non conta, e fuori finestra nemmeno', () {
      final carico = caricoDeiGiorni(
        [
          (quando: DateTime(2026, 9, 18, 9), kcal: null),
          (quando: DateTime(2026, 9, 1), kcal: 900),
        ],
        oggi: DateTime(2026, 9, 18, 10),
        ancoraIeri: false,
        finestra: 7,
      );

      expect(carico.every((c) => c == 0), isTrue);
    });

    /// ⚠️ **Il cambio d'ora**: il 29/03 dura 23 ore, e `inDays` fra le due
    /// mezzanotti dava zero — l'allenamento di ieri finiva dentro oggi.
    test("il giorno del cambio d'ora non sposta niente", () {
      final carico = caricoDeiGiorni(
        [(quando: DateTime(2026, 3, 29, 18), kcal: 400)],
        oggi: DateTime(2026, 3, 30, 12),
        ancoraIeri: false,
        finestra: 7,
      );

      expect(carico.last, 0);
      expect(carico[5], 400);
    });
  });

  group('la regola del risveglio è una sola', () {
    test('con la notte di oggi la giornata è cominciata', () {
      expect(
        CaricaBatteria.siViveAncoraIeri(
          notteDiOggi: true,
          notteDiIeri: true,
          oraLocale: 3,
        ),
        isFalse,
      );
    });

    test('presto, senza la notte di oggi, si vive ancora ieri', () {
      expect(
        CaricaBatteria.siViveAncoraIeri(
          notteDiOggi: false,
          notteDiIeri: true,
          oraLocale: 0,
        ),
        isTrue,
      );
    });

    test('oltre le 11 la giornata è cominciata comunque', () {
      expect(
        CaricaBatteria.siViveAncoraIeri(
          notteDiOggi: false,
          notteDiIeri: true,
          oraLocale: CaricaBatteria.oraOltreLaQualeIlGiornoEComunqueCominciato,
        ),
        isFalse,
      );
    });

    test('senza nemmeno la notte di ieri non si torna indietro', () {
      expect(
        CaricaBatteria.siViveAncoraIeri(
          notteDiOggi: false,
          notteDiIeri: false,
          oraLocale: 1,
        ),
        isFalse,
      );
    });
  });
}
