import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/diary/data/diary_models.dart';

/// Il ricalcolo in anteprima di una voce già in diario — C15 / 12/08/2026.
///
/// 🚨 **Perché l'app calcola qualcosa che calcola il server.**
///
/// Il committente: *«quando modifico i grammi nella pagina di modifica alimento,
/// i calcoli li deve fare in tempo reale mentre scrivo»*. Prima i campi restavano
/// fermi e sotto c'era scritto che il ricalcolo sarebbe avvenuto al salvataggio.
/// Vero — ma vuol dire premere «Salva» su una schermata che mostra i numeri di
/// prima, cioè confermare un valore che si sa sbagliato fidandosi.
///
/// ⚠️ **Non è una seconda formula da tenere allineata.** È la stessa proporzione
/// sui valori per 100 g, e il server la rifà comunque: i macro riscritti in
/// anteprima **non** entrano in `_toccati` e quindi non viaggiano nella
/// richiesta. Il numero che si vede è un'anteprima, non una decisione.
void main() {
  FoodEntry voce({
    double? kcal100 = 165,
    double? protein100 = 24,
    double? carbs100 = 0,
    double? fat100 = 7.5,
  }) => FoodEntry(
    id: 1,
    description: 'Cotoletta di pollo',
    meal: 'lunch',
    grams: 200,
    qty: 200,
    unit: 'g',
    kcal: 330,
    protein: 48,
    carbs: 0,
    fat: 15,
    kcal100: kcal100,
    protein100: protein100,
    carbs100: carbs100,
    fat100: fat100,
  );

  group('i valori per 100 g arrivano dal server', () {
    /// 🚨 Prima di oggi il modello Dart leggeva **solo** `kcal_100`, mentre il
    /// backend manda anche `protein_100`, `carbs_100` e `fat_100` da sempre. Tre
    /// numeri che arrivavano e nessuno prendeva.
    test('si leggono tutti e quattro', () {
      final v = FoodEntry.fromJson(const {
        'id': 1,
        'description': 'x',
        'meal': 'lunch',
        'kcal_100': 165.0,
        'protein_100': 24.0,
        'carbs_100': 0.0,
        'fat_100': 7.5,
      });

      expect(v.kcal100, 165);
      expect(v.protein100, 24);
      expect(v.carbs100, 0);
      expect(v.fat100, 7.5);
    });
  });

  group('l\'anteprima del ricalcolo', () {
    test('a 250 g i valori salgono in proporzione', () {
      final r = voce().riscalataA(250);

      expect(r.kcal, 412.5);
      expect(r.proteine, 60);
      expect(r.carboidrati, 0);
      expect(r.grassi, 18.8);
    });

    test('a 100 g valgono esattamente i valori per 100 g', () {
      final r = voce().riscalataA(100);

      expect(r.kcal, 165);
      expect(r.proteine, 24);
      expect(r.grassi, 7.5);
    });

    /// ⚠️ Un valore senza riferimento per 100 g non si riscala: si restituisce
    /// `null` e il campo resta com'è. Inventare un macro che il server non
    /// conosce sarebbe peggio che lasciarlo fermo.
    test('quello che non ha un riferimento resta nullo', () {
      final r = voce(protein100: null, fat100: null).riscalataA(250);

      expect(r.kcal, 412.5);
      expect(r.proteine, isNull);
      expect(r.grassi, isNull);
    });

    /// 💡 `siRicalcola` è il cancello: senza `kcal_100` la schermata dice che
    /// bisognerà correggere a mano, invece di lasciar credere a un ricalcolo che
    /// non avverrà.
    test('senza kcal per 100 g la voce dichiara di non ricalcolarsi', () {
      expect(voce().siRicalcola, isTrue);
      expect(voce(kcal100: null).siRicalcola, isFalse);
    });

    /// 🚨 **Gli arrotondamenti si fermano a un decimale.** Senza, 7,5 g su 250 g
    /// diventerebbe `18.749999999999996` dentro un campo di testo — un numero
    /// che nessuno vuole vedere e che nessuno correggerebbe volentieri.
    test('i numeri restano leggibili', () {
      final r = voce().riscalataA(237);

      expect(r.grassi, 17.8);
      expect(r.kcal, 391.1);
    });
  });
}
