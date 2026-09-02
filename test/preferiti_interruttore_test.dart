import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/diary/data/diary_models.dart';
import 'package:training_companion/src/features/diary/preferiti_gia_salvati.dart';

/// La stella e il segnalibro sono interruttori — 3b-D.5, 22/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// 📌 Il committente: *«Quando clicco sulla stella per rendere un cibo
/// preferito, la stella si deve riempire, e se ci clicco di nuovo, si deve
/// togliere dai preferiti»*.
///
/// ⚠️ **Il server non lega un preferito alla voce da cui è nato**, e non è una
/// dimenticanza: un preferito sopravvive alla voce che l'ha generato, ed è
/// tutto il suo senso. 🚨 Quindi «è già salvato?» si risponde **per contenuto**,
/// ed è quella risposta che questo file prova.
///
/// ⛔ Una stella piena su una cosa che non è salvata è peggio di una stella
/// sempre vuota: la seconda non promette niente.
void main() {
  FoodFavorite alimento(String nome, {int id = 1}) => FoodFavorite(
    id: id,
    description: nome,
    isMeal: false,
    itemsCount: 1,
    timesUsed: 0,
  );

  FoodFavorite pasto(int voci, double kcal, {int id = 9}) => FoodFavorite(
    id: id,
    description: 'La mia colazione',
    isMeal: true,
    itemsCount: voci,
    timesUsed: 0,
    kcal: kcal,
  );

  group('un alimento', () {
    test('si riconosce senza badare a maiuscole e spazi', () {
      final indice = PreferitiGiaSalvati([alimento('Croissant')]);

      // 💡 Chi ne salva uno si aspetta la stella piena sull'altro.
      expect(indice.perAlimento('croissant')?.id, 1);
      expect(indice.perAlimento('  CROISSANT '), isNotNull);
    });

    test('un nome diverso non è lo stesso alimento', () {
      final indice = PreferitiGiaSalvati([alimento('Croissant')]);

      expect(indice.perAlimento('Cornetto'), isNull);
    });

    test('un nome vuoto non trova niente', () {
      // ⛔ Senza questo, una voce senza descrizione si accoppierebbe al primo
      // preferito senza nome e mostrerebbe la stella piena a caso.
      final indice = PreferitiGiaSalvati([alimento('')]);

      expect(indice.perAlimento('   '), isNull);
    });

    test('🚨 un PASTO non è un alimento, anche se si chiama uguale', () {
      // ⚠️ Aggiungere un pasto intero dove ci si aspettava un alimento
      // rimetterebbe cinque voci nel diario invece di una.
      const indice = PreferitiGiaSalvati([
        FoodFavorite(
          id: 5,
          description: 'Croissant',
          isMeal: true,
          itemsCount: 3,
          timesUsed: 0,
        ),
      ]);

      expect(indice.perAlimento('Croissant'), isNull);
    });
  });

  group('un pasto', () {
    test('si riconosce dal CONTENUTO, non dal nome', () {
      /*
       * 🚨 È il punto della sezione. Il nome lo sceglie chi salva: un pasto
       * salvato come «la mia colazione» resterebbe senza segnalibro per sempre
       * se lo cercassimo per nome.
       */
      final indice = PreferitiGiaSalvati([pasto(3, 420)]);

      expect(indice.perPasto(voci: 3, kcal: 420)?.id, 9);
    });

    test('le calorie si confrontano arrotondate', () {
      // ⚠️ Sono `double` che hanno attraversato JSON e una somma: un confronto
      // esatto fallirebbe per mezzo decimale, e il segnalibro resterebbe vuoto
      // senza che nessuno capisca perché.
      final indice = PreferitiGiaSalvati([pasto(3, 420.4)]);

      expect(indice.perPasto(voci: 3, kcal: 419.7), isNotNull);
    });

    test('cambiando il pasto il segnalibro si svuota', () {
      /*
       * 💡 **E deve svuotarsi.** Aggiungendo una voce, quel pasto non è più
       * quello che era stato salvato: un segnalibro pieno direbbe che lo è.
       */
      final indice = PreferitiGiaSalvati([pasto(3, 420)]);

      expect(indice.perPasto(voci: 4, kcal: 420), isNull);
      expect(indice.perPasto(voci: 3, kcal: 500), isNull);
    });

    test('un pasto vuoto non è mai un preferito', () {
      // ⛔ Senza, ogni sezione vuota della giornata mostrerebbe il segnalibro
      // pieno se per caso esistesse un preferito da zero voci.
      final indice = PreferitiGiaSalvati([pasto(0, 0)]);

      expect(indice.perPasto(voci: 0, kcal: 0), isNull);
    });

    test('un alimento non è un pasto', () {
      const indice = PreferitiGiaSalvati([
        FoodFavorite(
          id: 3,
          description: 'Croissant',
          isMeal: false,
          itemsCount: 1,
          timesUsed: 0,
          kcal: 420,
        ),
      ]);

      expect(indice.perPasto(voci: 1, kcal: 420), isNull);
    });
  });

  test('senza preferiti non si riempie niente', () {
    // 💡 È lo stato mentre l'elenco arriva: stelle vuote, e mezzo secondo dopo
    // si riempiono da sole. Una rotellina per stella sarebbe molto peggio.
    const indice = PreferitiGiaSalvati([]);

    expect(indice.perAlimento('Croissant'), isNull);
    expect(indice.perPasto(voci: 3, kcal: 420), isNull);
  });
}
