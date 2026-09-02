import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/errors/api_exception.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/diary/data/diario_locale.dart';
import 'package:training_companion/src/features/diary/data/stima_ai.dart';

/// Correzioni, preferiti e stime confermate, **sul telefono** — Parte I, I2.5.
///
/// ══ 📌 COSA PROVA, E DA DOVE VIENE ═══════════════════════════════════════
///
/// 📌 Regola R2 della Parte I: *«la formula si trasporta, non si reinventa»*.
/// Qui ci sono le tre cose che il server faceva e che adesso fa `DiarioLocale`:
///
/// | | Era | Adesso |
/// |---|---|---|
/// | La correzione di una voce | `DiaryController::ricalcolaSeCambiaLaQuantita()` | [DiarioLocale.aggiorna] |
/// | I preferiti | `FoodFavoriteController` + `FoodFavorite::addToDiary()` | [DiarioLocale.usaPreferito] e compagni |
/// | La stima confermata | `AiController::scriviVoci()` | [DiarioLocale.scriviLaStima] |
void main() {
  late ArchivioSalute archivio;
  late DiarioLocale diario;

  final oggi = DateTime(2026, 9, 3);

  setUp(() {
    archivio = ArchivioSalute.inMemoria();
    diario = DiarioLocale(archivio);
  });

  tearDown(() => archivio.close());

  Future<int> olio() => diario.aggiungi(
    giorno: oggi,
    pasto: 'lunch',
    descrizione: 'Olio EVO',
    grammi: 14,
    quantita: 1,
    unita: 'cucchiaio',
    kcal: 124,
    grassi: 14,
  );

  Future<FoodEntryDiProva> leggi(int id) async {
    final giornata = await diario.giornata(oggi);
    final voce = giornata.meals
        .expand((m) => m.entries)
        .firstWhere((e) => e.id == id);

    return (
      grammi: voce.grams,
      quantita: voce.qty,
      unita: voce.unit,
      kcal: voce.kcal,
      grassi: voce.fat,
      kcal100: voce.kcal100,
    );
  }

  group('la correzione di una voce — le quattro parti della regola', () {
    test('1. senza toccare la quantità non si ricalcola niente', () async {
      final id = await olio();

      await diario.aggiorna(id, descrizione: 'Olio extravergine');

      final v = await leggi(id);

      expect(v.kcal, 124);
      expect(v.grammi, 14);
    });

    test('2. ⛔ i grammi espliciti vincono su qualunque conversione', () async {
      final id = await olio();

      await diario.aggiorna(id, quantita: 2, grammi: 25);

      expect((await leggi(id)).grammi, 25);
    });

    test('3. 🚨 il fattore viene dalla VOCE: 2 cucchiai fanno 28, non 30', () async {
      /*
       * ⛔ È il cuore della regola, e la parte più facile da perdere.
       *
       * 📌 Dal server: *«se l'AI ha detto che un cucchiaio di quell'olio pesa
       * 14 g, raddoppiando la quantità devono venire 28 g, non i 30 della
       * conversione generica»*. 💡 La tabella non è la verità nutrizionale:
       * serve a chi inserisce a mano senza sapere il peso, e cede il passo a chi
       * il peso lo sa.
       */
      final id = await olio();

      await diario.aggiorna(id, quantita: 2);

      final v = await leggi(id);

      expect(v.grammi, 28);
      // 💡 E i macro seguono i grammi: 124 kcal su 14 g fanno 885,71 per 100 g,
      // che su 28 g tornano 248.
      expect(v.kcal, 248);
    });

    test('3-bis. ⚠️ ma se cambia l\'unità si torna alla tabella', () async {
      // 🚨 Il fattore della voce parlava di *cucchiai*: su una tazza non dice
      // niente, e usarlo lo stesso darebbe un peso inventato.
      final id = await olio();

      await diario.aggiorna(id, quantita: 1, unita: 'tazza');

      expect((await leggi(id)).grammi, 240);
    });

    test('4. 🚨 i macro passati vincono sempre', () async {
      final id = await olio();

      await diario.aggiorna(id, quantita: 2, kcal: 200);

      final v = await leggi(id);

      expect(v.grammi, 28);
      expect(v.kcal, 200, reason: 'Il numero corretto a mano è stato sovrascritto.');
      // 💡 Quelli **non** passati si riscalano lo stesso: 14 g di grassi su 14 g
      // fanno 100 per 100 g, che su 28 g tornano 28.
      expect(v.grassi, 28);
    });

    test('4-bis. ⛔ e senza valori per 100 g non si inventa niente', () async {
      /*
       * 📌 Dal server: *«meglio un numero vecchio e visibile che uno nuovo e
       * sbagliato»*.
       *
       * ⚠️ Una voce senza peso non ha nemmeno i per-100 derivati, quindi non c'è
       * niente su cui riscalare: i macro restano dov'erano.
       */
      final id = await diario.aggiungi(
        giorno: oggi,
        pasto: 'lunch',
        descrizione: 'Boh',
        quantita: 1,
        unita: 'manciata',
        kcal: 200,
      );

      await diario.aggiorna(id, quantita: 3);

      final v = await leggi(id);

      expect(v.grammi, isNull);
      expect(v.kcal, 200);
    });

    test('⚠️ e i grammi si riscrivono anche a `null`', () async {
      /*
       * ⛔ Lasciarli fermi vorrebbe dire una voce da «2 tazze» che pesa ancora
       * quanto ne pesava un cucchiaio: un numero sbagliato che sembra giusto.
       */
      final id = await olio();

      await diario.aggiorna(id, quantita: 2, unita: 'manciata');

      expect((await leggi(id)).grammi, isNull);
    });

    test('🚨 correggere una voce in una impossibile non riesce', () async {
      // ⚠️ O la guardia sarebbe aggirabile con due scritture: una sana e una
      // correzione. È il test `an_edit_cannot_make_an_entry_impossible` del
      // server, con lo stesso senso.
      final id = await diario.aggiungi(
        giorno: oggi,
        pasto: 'lunch',
        descrizione: 'Petto di pollo',
        grammi: 100,
        kcal: 165,
        proteine: 31,
        carboidrati: 0,
        grassi: 3.6,
      );

      expect(
        () => diario.aggiorna(id, grammi: 100, proteine: 90, carboidrati: 40),
        throwsA(isA<MassaImpossibileException>()),
      );
    });

    test('⛔ e una voce sparita lo dice, invece di far finta', () async {
      expect(
        () => diario.aggiorna(999, descrizione: 'Niente'),
        throwsA(isA<DatoSparitoException>()),
      );
    });
  });

  group('i preferiti', () {
    test('una voce si salva, e torna nell\'elenco', () async {
      final id = await olio();

      await diario.salvaVoceComePreferito(id);

      final preferiti = await diario.preferiti();

      expect(preferiti, hasLength(1));
      expect(preferiti.single.description, 'Olio EVO');
      expect(preferiti.single.isMeal, isFalse);
      expect(preferiti.single.itemsCount, 1);
      expect(preferiti.single.kcal, 124);
    });

    test('un pasto intero si salva con dentro le sue voci', () async {
      await diario.aggiungi(
        giorno: oggi,
        pasto: 'breakfast',
        descrizione: 'Fette biscottate',
        grammi: 30,
        kcal: 120,
      );
      await diario.aggiungi(
        giorno: oggi,
        pasto: 'breakfast',
        descrizione: 'Marmellata',
        grammi: 20,
        kcal: 50,
      );

      await diario.salvaPasto(
        giorno: oggi,
        pasto: 'breakfast',
        descrizione: 'La mia colazione',
      );

      final p = (await diario.preferiti()).single;

      expect(p.isMeal, isTrue);
      expect(p.itemsCount, 2);
      expect(p.kcal, 170);
    });

    test('⚠️ un pasto vuoto non si salva, e lo dice', () async {
      expect(
        () => diario.salvaPasto(
          giorno: oggi,
          pasto: 'dinner',
          descrizione: 'Il nulla',
        ),
        throwsA(isA<PastoVuotoException>()),
      );
    });

    test('🚨 le chiavi del JSON restano quelle del server', () async {
      /*
       * ⛔ `description`, `grams`, `kcal_100`… sono i nomi che
       * `FoodFavoriteController::storeMeal()` ha scritto dentro i preferiti
       * **già traslocati su questo telefono**. Tradurli in italiano farebbe
       * tornare vuoti quei preferiti-pasto: nessun errore, un pasto che aggiunge
       * zero voci, e la scoperta solo riguardando il diario dopo.
       */
      await diario.aggiungi(
        giorno: oggi,
        pasto: 'breakfast',
        descrizione: 'Fette biscottate',
        grammi: 30,
        kcal: 120,
      );

      await diario.salvaPasto(
        giorno: oggi,
        pasto: 'breakfast',
        descrizione: 'Colazione',
      );

      final riga = (await archivio.preferitiDelDiario()).single;
      final voci = jsonDecode(riga.voci!) as List;

      expect((voci.single as Map).keys, contains('description'));
      expect((voci.single as Map).keys, contains('kcal_100'));
    });

    test('un pasto rimesso in diario produce tutte le sue voci', () async {
      await diario.aggiungi(
        giorno: oggi,
        pasto: 'breakfast',
        descrizione: 'Fette biscottate',
        grammi: 30,
        kcal: 120,
      );
      await diario.aggiungi(
        giorno: oggi,
        pasto: 'breakfast',
        descrizione: 'Marmellata',
        grammi: 20,
        kcal: 50,
      );

      final id = await diario.salvaPasto(
        giorno: oggi,
        pasto: 'breakfast',
        descrizione: 'Colazione',
      );

      final domani = DateTime(2026, 9, 4);

      await diario.usaPreferito(id, giorno: domani, pasto: 'breakfast');

      final giornata = await diario.giornata(domani);

      expect(giornata.meals.firstWhere((m) => m.meal == 'breakfast').entries, hasLength(2));
      expect(giornata.kcal, 170);

      // 🚨 E l'origine dice da dove vengono.
      expect(
        giornata.meals.firstWhere((m) => m.meal == 'breakfast').entries.first.source,
        'favorite',
      );
    });

    test('🚨 usarlo incrementa il contatore, che è metà dell\'ordinamento', () async {
      final id = await olio();
      final preferito = await diario.salvaVoceComePreferito(id);

      expect((await diario.preferiti()).single.timesUsed, 0);

      await diario.usaPreferito(preferito, giorno: oggi, pasto: 'dinner');
      await diario.usaPreferito(preferito, giorno: oggi, pasto: 'dinner');

      expect((await diario.preferiti()).single.timesUsed, 2);
    });

    test('⚠️ e l\'elenco mette i più usati per primi', () async {
      final a = await diario.aggiungi(
        giorno: oggi,
        pasto: 'lunch',
        descrizione: 'Mai usato',
        grammi: 10,
        kcal: 10,
      );
      final b = await diario.aggiungi(
        giorno: oggi,
        pasto: 'lunch',
        descrizione: 'Quello di ogni giorno',
        grammi: 10,
        kcal: 10,
      );

      await diario.salvaVoceComePreferito(a);
      final usato = await diario.salvaVoceComePreferito(b);

      await diario.usaPreferito(usato, giorno: oggi, pasto: 'lunch');

      expect((await diario.preferiti()).first.description, 'Quello di ogni giorno');
    });

    test('togliere un preferito non tocca il diario', () async {
      final id = await olio();
      final preferito = await diario.salvaVoceComePreferito(id);

      await diario.togliPreferito(preferito);

      expect(await diario.preferiti(), isEmpty);
      expect((await diario.giornata(oggi)).kcal, 124);
    });
  });

  group('la stima confermata', () {
    const cotoletta = VoceStimata(
      nome: 'Cotoletta di pollo impanata',
      qty: 200,
      unita: 'g',
      grammi: 200,
      kcal: 340,
      proteine: 32,
      carboidrati: 12,
      grassi: 16,
    );

    test('l\'origine e la risposta grezza sopravvivono', () async {
      /*
       * 📌 `FoodSource` lo dice dal primo giorno: *«quando un modello AI comincia
       * a sbagliare le stime, bisogna poter ritrovare TUTTE le voci che ha
       * prodotto»*. ⛔ Senza, ogni voce nascerebbe `manual`.
       */
      await diario.scriviLaStima(
        [cotoletta],
        giorno: oggi,
        pasto: 'lunch',
        fonte: 'ai_text',
      );

      final riga = (await archivio.vociDelGiorno(oggi)).single;

      expect(riga.fonte, 'ai_text');
      expect(riga.aiGrezzo, contains('Cotoletta di pollo impanata'));
    });

    test('🚨 e i valori per 100 g si derivano: senza, non si riscala', () async {
      // ⛔ Lo schema dell'AI non ha nessun campo per 100 g. Era il difetto #9 del
      // 12/08, e sul server lo chiudeva `FoodEntry::saving()`.
      await diario.scriviLaStima(
        [cotoletta],
        giorno: oggi,
        pasto: 'lunch',
        fonte: 'ai_text',
      );

      expect((await archivio.vociDelGiorno(oggi)).single.kcal100, 170);
    });

    test('🚨 un pasto si scrive tutto o niente', () async {
      /*
       * ⛔ Mezza cena in diario è un totale sbagliato che non dichiara di
       * esserlo. La seconda voce è impossibile: 100 g con 130 g di macro.
       */
      const impossibile = VoceStimata(
        nome: 'Coppiette',
        grammi: 100,
        kcal: 588,
        proteine: 60,
        carboidrati: 40,
        grassi: 30,
      );

      await expectLater(
        diario.scriviLaStima(
          [cotoletta, impossibile],
          giorno: oggi,
          pasto: 'dinner',
          fonte: 'ai_text',
        ),
        throwsA(isA<MassaImpossibileException>()),
      );

      expect(
        await archivio.vociDelGiorno(oggi),
        isEmpty,
        reason: 'È entrata mezza cena: la transazione non ha tenuto.',
      );
    });
  });
}

/// 💡 Un alias per non ripetere il record in ogni firma.
typedef FoodEntryDiProva = ({
  double? grammi,
  double? quantita,
  String? unita,
  double? kcal,
  double? grassi,
  double? kcal100,
});
