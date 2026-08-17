import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/diary/data/alimento_catalogo.dart';

/// Il catalogo alimenti lato app — Parte L, 17/08/2026.
///
/// 🚨 **La moltiplicazione per la quantità la fa l'app.** Il catalogo tiene i
/// valori per 100 g perché è condiviso: se ognuno ci mettesse quelli della
/// propria porzione, lo stesso nome avrebbe verità diverse a seconda di chi
/// l'ha scritto per primo.
void main() {
  const pollo = AlimentoCatalogo(
    id: 1,
    nome: 'Petto di pollo',
    marca: 'Aia',
    kcal100: 100,
    proteine100: 23.3,
    carboidrati100: 0,
    grassi100: 0.8,
  );

  group('i valori per la quantità scritta', () {
    test('150 g sono una volta e mezza i valori per 100', () {
      final v = pollo.per(150);

      expect(v.kcal, 150);
      expect(v.proteine, closeTo(34.95, 0.01));
      expect(v.grassi, closeTo(1.2, 0.01));
    });

    /// 💡 **Uno zero è un'affermazione, `null` è un «non lo so».**
    ///
    /// ⚠️ Scrivere `0` dove il catalogo non sa direbbe nel diario che quel
    /// cibo non ha proteine, ed è una cosa diversa dal non saperlo.
    test('quello che il catalogo non sa resta nullo, non diventa zero', () {
      const senzaProteine = AlimentoCatalogo(id: 2, nome: 'Misterioso', kcal100: 100);

      final v = senzaProteine.per(200);

      expect(v.kcal, 200);
      expect(v.proteine, isNull);
      expect(v.carboidrati, isNull);
    });

    /// ⚠️ Zero grammi non è un errore da far esplodere: è un campo non ancora
    /// compilato, e succede a ogni tasto premuto mentre si scrive la quantità.
    test('quantità zero dà zero e non un errore', () {
      expect(pollo.per(0).kcal, 0);
    });
  });

  group('come si presenta in un elenco', () {
    test('col marchio si vede il marchio', () {
      expect(pollo.titolo, 'Petto di pollo · Aia');
    });

    test('senza marchio resta solo il nome', () {
      const senzaMarca = AlimentoCatalogo(id: 3, nome: 'Mela');

      expect(senzaMarca.titolo, 'Mela');
    });

    /// 🚨 Il marchio vuoto arriva davvero da Open Food Facts: il campo c'è ma
    /// è una stringa vuota, e senza questo controllo il titolo finirebbe con
    /// un « · » appeso.
    test('un marchio vuoto non lascia il separatore appeso', () {
      const marcaVuota = AlimentoCatalogo(id: 4, nome: 'Mela', marca: '');

      expect(marcaVuota.titolo, 'Mela');
    });
  });

  group('la lettura della risposta del server', () {
    test('legge tutto quello che serve, note comprese', () {
      final a = AlimentoCatalogo.fromJson(const {
        'id': 7,
        'nome': 'Pane bianco',
        'marca': null,
        'kcal_100': 268,
        'protein_100': 8.1,
        'carbs_100': 59.5,
        'fat_100': 0.5,
        'basis': 'g',
        'codice_a_barre': null,
        'immagine_url': 'https://images.openfoodfacts.org/x.jpg',
        'note': 'Fonte: CREA Centro di ricerca Alimenti e Nutrizione',
      });

      expect(a.nome, 'Pane bianco');
      expect(a.kcal100, 268);
      expect(a.immagineUrl, isNotNull);

      // 🚨 La nota è l'attribuzione, ed è la condizione delle licenze: deve
      // arrivare fino a chi guarda lo schermo.
      expect(a.note, contains('CREA'));
    });

    /// ⚠️ La maggior parte degli alimenti non ha immagine né codice a barre, e
    /// mezzo catalogo non ha marca: la lettura deve reggere l'assenza, che qui
    /// è il caso normale e non l'eccezione.
    test('regge un alimento senza immagine, senza marca e senza codice', () {
      final a = AlimentoCatalogo.fromJson(const {'id': 9, 'nome': 'Roba'});

      expect(a.immagineUrl, isNull);
      expect(a.codiceABarre, isNull);
      expect(a.marca, isNull);
      expect(a.basis, 'g');
      expect(a.per(100).kcal, isNull);
    });
  });
}
