import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/diary/data/target_del_giorno.dart';

/// L'obiettivo calorico del giorno — N23.B1.
///
/// ── 🚨 Il difetto che questi test chiudono ────────────────────────────────
///
/// *«se aggiungo quante calorie ho bruciato nella scheda cibo, queste non
/// appaiono da nessuna parte»* — il committente, 19/08/2026. Misurato ed era
/// vero: la somma esisteva **solo sul server**, che dopo D9-bis non conosce il
/// peso e restituisce `null` a chiunque non abbia un piano del trainer.
///
/// ⚠️ Il difetto opposto è altrettanto facile e più grave: **sommare due volte**
/// a chi il piano ce l'ha, perché il numero del server le bruciate le contiene
/// già. Il primo test qui sotto è quello.
void main() {
  group('quando il target arriva dal piano del trainer', () {
    /// 🚨 Il server manda già `kcal_base + bruciate`: risommare darebbe il
    /// doppio del margine, con un numero che resta plausibile.
    test('le bruciate NON si risommano', () {
      final t = TargetDelGiorno.scegli(
        dalServer: 2450,
        locale: 2000,
        bruciate: 450,
      );

      expect(t.kcal, 2450);
      expect(t.esiste, isTrue);
    });

    test('e il calcolo locale non lo tocca nemmeno', () {
      final t = TargetDelGiorno.scegli(
        dalServer: 2450,
        locale: 9999,
        bruciate: 0,
      );

      expect(t.kcal, 2450);
    });
  });

  group('quando il target è quello calcolato sul telefono', () {
    /// 🚨 **Il test centrale**: è ciò che il 19/08 non succedeva.
    test('le bruciate si sommano', () {
      final t = TargetDelGiorno.scegli(
        dalServer: null,
        locale: 2000,
        bruciate: 450,
      );

      expect(t.kcal, 2450);
      expect(t.bruciateIncluse, isTrue);
    });

    test('senza bruciate resta il numero calcolato', () {
      final t = TargetDelGiorno.scegli(
        dalServer: null,
        locale: 2000,
        bruciate: 0,
      );

      expect(t.kcal, 2000);

      // 💡 Falso: non c'è niente da spiegare, e l'interfaccia non deve dire
      // «di cui 0 bruciate».
      expect(t.bruciateIncluse, isFalse);
    });
  });

  group('quando non c\'è nessun obiettivo', () {
    /// ⚠️ **Non si inventa.** Un numero finto qui è un numero su cui qualcuno
    /// costruisce una dieta.
    test('resta null anche se ci sono bruciate', () {
      final t = TargetDelGiorno.scegli(
        dalServer: null,
        locale: null,
        bruciate: 600,
      );

      expect(t.kcal, isNull);
      expect(t.esiste, isFalse);
    });

    /// 💡 Uno zero dal server o dal calcolo vale «non c'è», non «obiettivo zero».
    test('uno zero non è un obiettivo', () {
      expect(
        TargetDelGiorno.scegli(dalServer: 0, locale: 0, bruciate: 300).esiste,
        isFalse,
      );
    });
  });
}
