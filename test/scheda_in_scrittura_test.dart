import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/scheda_in_scrittura.dart';
import 'package:training_companion/src/features/training/data/serie_prevista.dart';

/// L'editor delle schede, dalla parte che si può provare — 3b-D.5.
void main() {
  test('🆕 un esercizio nuovo nasce con tre serie', () {
    /// 📌 *«ogni esercizio deve partire di base con 3 serie»*.
    ///
    /// 💡 Tre e non una: chi apre l'editor si trova davanti **la forma** di
    /// quello che sta per scrivere, invece di doverla costruire.
    expect(EsercizioInScrittura().serie.length, 3);
  });

  group('🖊️ l\'autocompilazione', () {
    /// 📌 *«Quando compilo la prima si devono autocompilare anche le altre
    /// sotto»*.
    test('copia la prima riga su quelle ancora vuote', () {
      final e = EsercizioInScrittura();

      e.serie.first.ripetizioni.text = '12';
      e.serie.first.carico.text = '40';
      e.serie.first.recupero.text = '90';

      e.autocompila();

      expect(e.serie[1].ripetizioni.text, '12');
      expect(e.serie[2].carico.text, '40');
      expect(e.serie[2].recupero.text, '90');
    });

    /// 🚨 **La parentesi del committente era la specifica vera**: *«(ovviamente
    /// devo poterle modificare)»* vuol dire che una riga già toccata **non si
    /// tocca più**.
    ///
    /// ⛔ Senza questa guardia, scrivere il peso della terza serie e poi
    /// correggere la prima cancellerebbe la correzione appena fatta — e chi
    /// sta compilando se ne accorgerebbe solo dopo aver salvato.
    test('⛔ ma non tocca quelle che qualcuno ha già scritto', () {
      final e = EsercizioInScrittura();

      e.serie[2].carico.text = '50';

      e.serie.first.ripetizioni.text = '12';
      e.serie.first.carico.text = '40';

      e.autocompila();

      expect(e.serie[1].carico.text, '40', reason: 'questa era intatta');
      expect(e.serie[2].carico.text, '50', reason: 'questa no');

      expect(
        e.serie[2].ripetizioni.text,
        isEmpty,
        reason: 'la riga toccata si salta INTERA, non campo per campo',
      );
    });
  });

  /// 🚨 È il *«le schede già esistenti ricalchino questa nuova impostazione»*
  /// visto dall'editor: una scheda scritta prima si apre **già in righe**.
  test('⏪ una scheda vecchia si apre in righe, non in un campo «serie»', () {
    final e = EsercizioInScrittura.da({
      'name': 'Panca piana',
      'sets': 4,
      'reps': '12',
      'rest_sec': 90,
      'target_weight': 40.0,
    });

    expect(e.nome.text, 'Panca piana');
    expect(e.serie.length, 4);
    expect(e.serie.first.ripetizioni.text, '12');

    /// ⚠️ **`40` e non `40.0`**: il campo lo legge una persona, e un peso
    /// intero scritto con lo zero dietro sembra una precisione che non c'è.
    expect(e.serie.first.carico.text, '40');
  });

  group('🏋️ il carico', () {
    test('con l\'isometria i secondi finiscono al posto dei chili', () {
      final e = EsercizioInScrittura(carico: CaricoDellEsercizio.iso);

      e.serie.first.ripetizioni.text = '1';
      e.serie.first.carico.text = '45';

      final json = e.versoIlDato();
      final riletto = serieDellEsercizio(json).first;

      expect(riletto.isoSec, 45);
      expect(riletto.peso, isNull);
    });

    /// ⚠️ *«Il campo peso (se attivo) può essere lasciato vuoto»* — e vuoto
    /// vuol dire **`null`**, non zero: uno zero direbbe «a corpo libero», che è
    /// un'altra cosa e ha già la sua voce.
    test('e lasciato vuoto resta vuoto, non diventa zero', () {
      final e = EsercizioInScrittura();

      e.serie.first.ripetizioni.text = '10';

      final riletto = serieDellEsercizio(e.versoIlDato()).first;

      expect(riletto.ripetizioni, 10);
      expect(riletto.peso, isNull);
    });
  });
}
