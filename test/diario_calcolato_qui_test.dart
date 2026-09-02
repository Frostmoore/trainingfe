import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/diary/data/diario_locale.dart';
import 'package:training_companion/src/features/diary/data/unita_di_misura.dart';

/// Il calcolo del diario, in Dart — Parte I, I2.
///
/// ══ 📌 LA REGOLA ══════════════════════════════════════════════════════════
///
/// 📌 R2 della Parte I: *«la formula si **trasporta**, non si reinventa»* e *«i
/// test del server che coprivano quei calcoli diventano test Dart, **con gli
/// stessi numeri**. Se un numero cambia, è un difetto — non un arrotondamento
/// diverso»*.
///
/// 🚨 **I numeri di questo file vengono da `FoodUnitTest` del server**, riga per
/// riga. Non sono stati ricalcolati: sono stati **copiati**, ed è tutto il
/// punto. ⛔ Un test scritto guardando il codice nuovo prova che il codice nuovo
/// fa quello che fa, non che fa quello che faceva l'altro.
void main() {
  group('le unità, con i numeri del server', () {
    /// 💡 Le stesse coppie di `FoodUnitTest::conversioni()`.
    const conversioni = <String, (double, String, double)>{
      'grammi restano grammi': (150, 'g', 150),
      'chili': (1.5, 'kg', 1500),
      'ettogrammi': (2, 'hg', 200),
      'milligrammi': (500, 'mg', 0.5),
      'millilitri 1:1': (200, 'ml', 200),
      'litri': (1, 'l', 1000),
      'decilitri': (2.5, 'dl', 250),
      'centilitri': (33, 'cl', 330),
      'un bicchiere': (1, 'bicchiere', 200),
      'due cucchiai': (2, 'cucchiaio', 30),
      'un cucchiaino': (1, 'cucchiaino', 5),
      'una tazza': (1, 'tazza', 240),
      'uno scoop': (1, 'scoop', 30),
    };

    conversioni.forEach((nome, caso) {
      test(nome, () {
        final (quantita, unita, atteso) = caso;

        expect(inGrammi(quantita, unita), atteso);
      });
    });

    const sinonimi = <String, (String, String)>{
      'maiuscole': ('G', 'g'),
      'spazi': ('  kg  ', 'kg'),
      'punto finale': ('gr.', 'g'),
      'italiano esteso': ('grammi', 'g'),
      'plurale': ('cucchiai', 'cucchiaio'),
      'misurino': ('misurino', 'scoop'),
      'inglese tbsp': ('tbsp', 'cucchiaio'),
      'inglese cup': ('cup', 'tazza'),
      'etti': ('etti', 'hg'),
    };

    sinonimi.forEach((nome, caso) {
      test('sinonimi · $nome', () {
        final (scritto, atteso) = caso;

        expect(unitaValida(scritto), atteso);
      });
    });

    test('🚨 un\'unità sconosciuta NON diventa grammi', () {
      /*
       * Indovinare produrrebbe un numero plausibile e sbagliato, che entra nei
       * totali e non lo controlla più nessuno. ⛔ Meglio `null`, che costringe
       * chi chiama a decidere.
       */
      expect(unitaValida('manciata'), isNull);
      expect(inGrammi(2, 'manciata'), isNull);
      expect(inGrammi(2, null), isNull);
      expect(inGrammi(null, 'g'), isNull);
    });

    test('andata e ritorno', () {
      for (final u in ['g', 'kg', 'ml', 'cucchiaio', 'tazza']) {
        final grammi = inGrammi(3, u);

        expect(grammi, isNotNull);
        expect(daGrammi(grammi, u), 3, reason: 'Andata e ritorno rotto su «$u».');
      }
    });

    test('la tendina comincia dalle unità che si usano davvero', () {
      expect(ordineDelleUnita.take(3).toList(), ['g', 'kg', 'ml']);

      // ⛔ Un'unità nell'ordine senza fattore darebbe un menu con una voce che
      // poi non converte.
      for (final u in ordineDelleUnita) {
        expect(
          fattoriDelleUnita.containsKey(u),
          isTrue,
          reason: '«$u» sta nell\'ordine ma non ha un fattore.',
        );
      }

      expect(
        ordineDelleUnita.length,
        fattoriDelleUnita.length,
        reason: 'Un\'unità convertibile non compare nel menu.',
      );
    });
  });

  group('la giornata, letta dal telefono', () {
    late ArchivioSalute archivio;
    late DiarioLocale diario;

    setUp(() {
      archivio = ArchivioSalute.inMemoria();
      diario = DiarioLocale(archivio);
    });

    tearDown(() => archivio.close());

    Future<int> segna(
      String pasto,
      double kcal, {
      DateTime? giorno,
      double proteine = 0,
    }) => diario.aggiungi(
      giorno: giorno ?? DateTime(2026, 9, 2),
      pasto: pasto,
      descrizione: 'Qualcosa',
      kcal: kcal,
      proteine: proteine,
    );

    test('i pasti ci sono tutti e sei, anche quelli vuoti', () async {
      /*
       * ⛔ Saltare i pasti vuoti farebbe sparire il posto in cui si scrive la
       * colazione a chi non l'ha ancora scritta.
       */
      final giornata = await diario.giornata(DateTime(2026, 9, 2));

      expect(giornata.meals, hasLength(6));
      expect(giornata.meals.first.meal, 'breakfast');
      expect(giornata.meals.last.meal, 'evening_snack');
    });

    test('le voci finiscono nel loro pasto, e i totali tornano', () async {
      await segna('breakfast', 300, proteine: 20);
      await segna('lunch', 700, proteine: 45);
      await segna('lunch', 150, proteine: 5);

      final giornata = await diario.giornata(DateTime(2026, 9, 2));

      final pranzo = giornata.meals.firstWhere((m) => m.meal == 'lunch');

      expect(pranzo.entries, hasLength(2));
      expect(pranzo.kcal, 850);

      expect(giornata.kcal, 1150);
      expect(giornata.protein, 70);
    });

    test('un altro giorno non entra nei totali', () async {
      await segna('lunch', 700);
      await segna('lunch', 999, giorno: DateTime(2026, 9, 1));

      expect((await diario.giornata(DateTime(2026, 9, 2))).kcal, 700);
    });

    test('⚠️ i decimali si sommano come sul server: due cifre', () async {
      /*
       * 🚨 `FoodEntry::totals()` arrotondava a due decimali. Un arrotondamento
       * diverso farebbe divergere i totali sull'ultima cifra — abbastanza da
       * far litigare i test, non abbastanza da spiegare perché.
       */
      await segna('lunch', 33.333);
      await segna('lunch', 33.333);
      await segna('lunch', 33.333);

      expect((await diario.giornata(DateTime(2026, 9, 2))).kcal, 100.0);
    });

    test('💡 i grammi si derivano da quantità e unità', () async {
      await diario.aggiungi(
        giorno: DateTime(2026, 9, 2),
        pasto: 'lunch',
        descrizione: 'Olio',
        quantita: 2,
        unita: 'cucchiaio',
      );

      final voce = (await diario.giornata(DateTime(2026, 9, 2)))
          .meals
          .firstWhere((m) => m.meal == 'lunch')
          .entries
          .single;

      expect(voce.grams, 30);
    });

    test('⛔ ma i grammi dichiarati vincono su qualunque conversione', () async {
      /*
       * 📌 Dal server: *«l'utente ha pesato la porzione, e nessuna tabella sa
       * più di una bilancia»*.
       */
      await diario.aggiungi(
        giorno: DateTime(2026, 9, 2),
        pasto: 'lunch',
        descrizione: 'Olio',
        grammi: 14,
        quantita: 1,
        unita: 'cucchiaio',
      );

      final voce = (await diario.giornata(DateTime(2026, 9, 2)))
          .meals
          .firstWhere((m) => m.meal == 'lunch')
          .entries
          .single;

      expect(voce.grams, 14, reason: 'La tabella direbbe 15: ha vinto la bilancia.');
    });

    test('i totali di più giorni si leggono in una volta', () async {
      await segna('lunch', 700, giorno: DateTime(2026, 9, 1));
      await segna('dinner', 300, giorno: DateTime(2026, 9, 1));
      await segna('lunch', 500, giorno: DateTime(2026, 9, 2));

      final perGiorno = await diario.totaliFra(
        DateTime(2026, 9, 1),
        DateTime(2026, 9, 2),
      );

      expect(perGiorno['2026-09-01']?.kcal, 1000);
      expect(perGiorno['2026-09-02']?.kcal, 500);
    });

    test('💡 la voce porta l\'id LOCALE, che è quello con cui si cancella', () async {
      final id = await segna('lunch', 700);

      final voce = (await diario.giornata(DateTime(2026, 9, 2)))
          .meals
          .firstWhere((m) => m.meal == 'lunch')
          .entries
          .single;

      expect(voce.id, id);

      await diario.cancella(voce.id);

      expect((await diario.giornata(DateTime(2026, 9, 2))).kcal, 0);
    });
  });
}
