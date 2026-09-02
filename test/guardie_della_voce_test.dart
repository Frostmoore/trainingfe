import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/errors/api_exception.dart';
import 'package:training_companion/src/features/diary/data/guardie_della_voce.dart';

/// Le cinque cose che faceva `FoodEntry::saving()` — Parte I, I2.5.
///
/// ══ 📌 LA REGOLA, E DA DOVE VENGONO I NUMERI ═════════════════════════════
///
/// 📌 R2 della Parte I: *«i test del server che coprivano quei calcoli
/// diventano test Dart, **con gli stessi numeri**. Se un numero cambia, è un
/// difetto — non un arrotondamento diverso»*.
///
/// 🚨 Le cifre di questo file sono **copiate**, non ricalcolate:
///
/// | Numero | Da dove |
/// |---|---|
/// | 250 g / 475 kcal → **190** per 100 g | `AiApiTest::the_numbers_edited_by_hand_are_the_ones_that_get_saved`, ritirato con I2.5 |
/// | 100 g con 56 P + 4 C + 40 G | Le coppiette del 12/08/2026, `NutritionApiTest` |
/// | 100 g d'olio = 100 g di grassi | Il caso che la seconda prova **deve** lasciar passare |
///
/// ⛔ Un test scritto guardando il codice nuovo prova che il codice nuovo fa
/// quello che fa, non che fa quello che faceva l'altro.
void main() {
  group('1. i grammi mancanti si derivano', () {
    test('da quantità × unità', () {
      final v = normalizzaLaVoce(
        descrizione: 'Olio',
        quantita: 2,
        unita: 'cucchiaio',
      );

      expect(v.grammi, 30);
    });

    test('⛔ ma i grammi dichiarati vincono', () {
      // 📌 *«L'utente ha pesato la porzione, e nessuna tabella sa più di una
      // bilancia»*.
      final v = normalizzaLaVoce(
        descrizione: 'Olio',
        grammi: 28,
        quantita: 2,
        unita: 'cucchiaio',
      );

      expect(v.grammi, 28);
    });

    test('💡 e senza niente da cui derivarli restano nulli', () {
      final v = normalizzaLaVoce(descrizione: 'Boh', quantita: 2, unita: 'manciata');

      expect(v.grammi, isNull);
      // ⚠️ E l'unità non si tocca: senza peso non c'è niente da convertire.
      expect(v.unita, 'manciata');
    });
  });

  group('2. un\'unità sconosciuta diventa grammi', () {
    /*
     * 📌 Il difetto del 12/08/2026: *«Ho scritto "Due cotolette di pollo" e me
     * le segna come 2 pezzi. Ma pezzi non è un'unità di misura, e quando vado a
     * modificarle a mano non mi ricalcola nulla»*.
     */
    test('quando i grammi ci sono', () {
      final v = normalizzaLaVoce(
        descrizione: 'Due cotolette di pollo',
        grammi: 220,
        quantita: 2,
        unita: 'pezzi',
      );

      expect(v.unita, 'g');
      expect(v.quantita, 220);
      expect(v.grammi, 220);
    });

    test('⚠️ e un\'unità che conosciamo non si tocca', () {
      final v = normalizzaLaVoce(
        descrizione: 'Olio',
        grammi: 28,
        quantita: 2,
        unita: 'cucchiaio',
      );

      expect(v.unita, 'cucchiaio');
      expect(v.quantita, 2);
    });
  });

  group('3. i valori per 100 g si derivano dagli assoluti', () {
    test('🚨 250 g / 475 kcal fanno 190 per 100 g', () {
      /*
       * ⛔ È **la riga per cui la modifica a mano ricalcola qualcosa**: lo schema
       * dell'AI non ha nessun campo per 100 g, quindi senza questa derivazione
       * ogni voce dell'AI nasce senza riferimento e cambiarne la quantità lascia
       * i macro fermi. Era il difetto #9 del 12/08.
       */
      final v = normalizzaLaVoce(
        descrizione: 'Cotoletta di pollo',
        grammi: 250,
        quantita: 250,
        unita: 'g',
        kcal: 475,
        proteine: 40,
        carboidrati: 15,
        grassi: 20,
      );

      expect(v.kcal100, 190);
      expect(v.proteine100, 16);
      expect(v.carboidrati100, 6);
      expect(v.grassi100, 8);
    });

    test('⚠️ non sovrascrive quelli che arrivano', () {
      // 💡 Chi manda già i per-100 — l'inserimento da un'etichetta — li ha più
      // precisi di qualunque divisione.
      final v = normalizzaLaVoce(
        descrizione: 'Yogurt',
        grammi: 125,
        kcal: 80,
        kcal100: 61,
      );

      expect(v.kcal100, 61);
    });

    test('💡 e senza peso non si deriva niente', () {
      final v = normalizzaLaVoce(descrizione: 'Boh', kcal: 200);

      expect(v.kcal100, isNull);
    });
  });

  group('4. e il verso opposto', () {
    test('dai per 100 g si ricavano gli assoluti', () {
      final v = normalizzaLaVoce(
        descrizione: 'Fette biscottate',
        grammi: 30,
        kcal100: 400,
        proteine100: 12,
      );

      expect(v.kcal, 120);
      expect(v.proteine, 3.6);
    });

    test('⛔ ma solo quando gli assoluti non ci sono', () {
      final v = normalizzaLaVoce(
        descrizione: 'Fette biscottate',
        grammi: 30,
        kcal: 111,
        kcal100: 400,
      );

      expect(v.kcal, 111);
    });
  });

  group('5. la massa impossibile blocca', () {
    test('🚨 le coppiette del 12/08: 56 + 4 + 40 in 100 g', () {
      /*
       * 📌 Il committente: *«la guardia sull'impossibilità della massa è
       * hard-blocking perché non è possibile che un alimento abbia più macro che
       * peso»*. ⚠️ 588 kcal sono un numero perfettamente plausibile, ed è per
       * questo che sarebbe passato.
       *
       * 💡 Fa **esattamente 100 su 100**: la prima prova da sola — «oltre la
       * massa» — non le prendeva.
       */
      expect(
        () => normalizzaLaVoce(
          descrizione: 'Coppiette di maiale',
          grammi: 100,
          kcal: 588,
          proteine: 56,
          carboidrati: 4,
          grassi: 40,
        ),
        throwsA(isA<MassaImpossibileException>()),
      );
    });

    test('💡 100 g d\'olio sono 100 g di grassi, e si salvano', () {
      // ⚠️ Un alimento con **un solo** macronutriente può arrivare al 100%: al
      // 100% ci arrivano i grassi puri e gli zuccheri puri.
      final v = normalizzaLaVoce(
        descrizione: 'Olio EVO',
        grammi: 100,
        kcal: 900,
        proteine: 0,
        carboidrati: 0,
        grassi: 100,
      );

      expect(v.grassi, 100);
    });

    test('⚠️ il messaggio nomina l\'alimento e i due numeri', () {
      /*
       * ⛔ Un generico «non ha funzionato» su un pasto da otto voci non dice
       * quale riga correggere. 📌 È lo stesso testo di
       * `MassaIncoerenteException::render()`.
       */
      try {
        normalizzaLaVoce(
          descrizione: 'Coppiette',
          grammi: 100,
          proteine: 60,
          carboidrati: 40,
          grassi: 30,
        );
        fail('Doveva rifiutare.');
      } on MassaImpossibileException catch (e) {
        expect(e.message, contains('Coppiette'));
        expect(e.message, contains('130'));
        expect(e.message, contains('100'));
      }
    });

    test('🚨 si controlla per ULTIMA, sui valori definitivi', () {
      /*
       * ⛔ Controllarla prima delle derivazioni vorrebbe dire bocciare voci sane,
       * i cui numeri erano solo ancora incompleti: qui i macro nascono dai
       * per-100, e prima del passo 4 non esistevano affatto.
       */
      final v = normalizzaLaVoce(
        descrizione: 'Petto di pollo',
        grammi: 100,
        kcal100: 165,
        proteine100: 31,
        carboidrati100: 0,
        grassi100: 3.6,
      );

      expect(v.proteine, 31);
    });

    test('💡 e senza peso non si giudica niente', () {
      final v = normalizzaLaVoce(descrizione: 'Boh', proteine: 900);

      expect(v.proteine, 900);
    });
  });
}
