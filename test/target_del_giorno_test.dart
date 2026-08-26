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
/// ══ 🚨 E IL 21/08 SI È ROVESCIATO — FASE 11.5 ════════════════════════════
///
/// ⚠️ Fino a `v8.4.1` il difetto opposto era il più grave: **sommare due volte**
/// a chi il piano ce l'ha, perché il numero del server le bruciate le conteneva
/// già.
///
/// 🚨 **Adesso non le contiene più**: dopo il trasloco degli allenamenti il
/// server le sedute non ce le ha, quindi manda il target del piano e basta. Non
/// sommarle qui vorrebbe dire che chi ha un trainer **perde il margine
/// dell'allenamento** — un numero più basso, plausibile, e nessun errore.
///
/// 💡 Il risultato è più semplice: la somma si fa **sempre qui**, e il doppio
/// conteggio non è più possibile perché non c'è più nessun altro che sommi.
void main() {
  group('quando il target arriva dal piano del trainer', () {
    /// 🚨 **Da FASE 11.5 le bruciate SI sommano anche qui**: il server manda il
    /// target del piano e basta, perché gli allenamenti non li ha più.
    test('le bruciate si sommano al target del piano', () {
      final t = TargetDelGiorno.scegli(
        sommaLeBruciate: true,
        bruciateExtra: 0,
        dalServer: 2000,
        locale: 1800,
        bruciate: 450,
      );

      // 💡 2.000 dal trainer + 450 bruciate oggi.
      expect(t.kcal, 2450);
      expect(t.bruciateIncluse, isTrue);
      expect(t.esiste, isTrue);
    });

    test('e il calcolo locale non lo tocca nemmeno', () {
      final t = TargetDelGiorno.scegli(
        sommaLeBruciate: true,
        bruciateExtra: 0,
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
        sommaLeBruciate: true,
        bruciateExtra: 0,
        dalServer: null,
        locale: 2000,
        bruciate: 450,
      );

      expect(t.kcal, 2450);
      expect(t.bruciateIncluse, isTrue);
    });

    test('senza bruciate resta il numero calcolato', () {
      final t = TargetDelGiorno.scegli(
        sommaLeBruciate: true,
        bruciateExtra: 0,
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
        sommaLeBruciate: true,
        bruciateExtra: 0,
        dalServer: null,
        locale: null,
        bruciate: 600,
      );

      expect(t.kcal, isNull);
      expect(t.esiste, isFalse);
    });

    /*
     * ══ 🚨 L'INTERRUTTORE DELLE BRUCIATE — 3b-P.2.2, 22/08/2026 ═══════════
     *
     * 📌 *«Ci voglio un toggle per decidere se le calorie bruciate si sommano
     * all'obbiettivo calorico o no (default sì)»*.
     *
     * ⚠️ **Va provato su tutti e due i rami**, non solo su uno: il piano del
     * trainer e il calcolo locale sommano in due punti diversi della stessa
     * funzione, e correggerne uno solo darebbe un'app che rispetta la scelta
     * per metà degli utenti — quella metà che non se ne accorgerebbe mai.
     */
    test('spento, le bruciate non si sommano al piano del trainer', () {
      final t = TargetDelGiorno.scegli(
        dalServer: 2000,
        locale: null,
        bruciate: 400,
        sommaLeBruciate: false,
        bruciateExtra: 0,
      );

      expect(t.kcal, 2000);
      expect(
        t.bruciateIncluse,
        isFalse,
        reason: 'senza somma non ci sono bruciate da spiegare in etichetta',
      );
    });

    test('spento, le bruciate non si sommano nemmeno al calcolo locale', () {
      final t = TargetDelGiorno.scegli(
        dalServer: null,
        locale: 1800,
        bruciate: 400,
        sommaLeBruciate: false,
        bruciateExtra: 0,
      );

      expect(t.kcal, 1800);
      expect(t.bruciateIncluse, isFalse);
    });

    test('acceso, si sommano — ed è il comportamento predefinito', () {
      expect(
        TargetDelGiorno.scegli(
          dalServer: null,
          locale: 1800,
          bruciate: 400,
          sommaLeBruciate: true,
          bruciateExtra: 0,
        ).kcal,
        2200,
      );
    });

    /// 💡 Uno zero dal server o dal calcolo vale «non c'è», non «obiettivo zero».
    test('uno zero non è un obiettivo', () {
      expect(
        TargetDelGiorno.scegli(
          dalServer: 0,
          locale: 0,
          bruciate: 300,
          sommaLeBruciate: true,
          bruciateExtra: 0,
        ).esiste,
        isFalse,
      );
    });
  });
  group('🔥 il margine dell\'allenamento si sa quanto vale', () {
    /// 🚨 **Serve a disegnarlo separato dal target.** Il committente:
    /// *«il mio obbiettivo e' l'obbiettivo. L'allenamento e' oltre»* - e per
    /// spezzare il fondo della barra serve il numero, non un booleano.
    test('e l\'obiettivo senza margine si ricava', () {
      final t = TargetDelGiorno.scegli(
        dalServer: null,
        locale: 1880,
        bruciate: 580,
        sommaLeBruciate: true,
        bruciateExtra: 0,
      );

      expect(t.kcal, 2460);
      expect(t.margine, 580);
      expect(t.kcalBase, 1880);
    });

    /// ⚠️ Con la somma spenta il margine e' **zero**, non 580: la barra
    /// disegnerebbe una zona arancione che non corrisponde a niente.
    test('con la somma spenta il margine e zero', () {
      final t = TargetDelGiorno.scegli(
        dalServer: null,
        locale: 1880,
        bruciate: 580,
        sommaLeBruciate: false,
        bruciateExtra: 0,
      );

      expect(t.kcal, 1880);
      expect(t.margine, 0);
      expect(t.kcalBase, 1880);
    });

    /// 🏃 E le sedute «fuori dal solito» sono margine come le altre.
    test('gli extra contano nel margine', () {
      final t = TargetDelGiorno.scegli(
        dalServer: null,
        locale: 1880,
        bruciate: 580,
        sommaLeBruciate: false,
        bruciateExtra: 300,
      );

      expect(t.kcal, 2180);
      expect(t.margine, 300);
      expect(t.kcalBase, 1880);
    });
  });
}
