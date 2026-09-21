import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/allenamento_in_corso.dart';
import 'package:training_companion/src/features/training/data/scheda_in_scrittura.dart';
import 'package:training_companion/src/features/training/training_controller.dart';

/// 🖼️ **La foto che il trainer mette sull'esercizio dal pannello** — F5.13 (A1).
///
/// 📌 Il committente: *«nel builder delle schede devo poter aggiungere
/// un'immagine a ogni esercizio»*, e quell'immagine *«deve essere mostrata
/// durante l'allenamento»*.
///
/// ══ 🚨 QUI SI ROMPE IN SILENZIO, ED È GIÀ SUCCESSO ═══════════════════════
///
/// ⛔ È esattamente la trappola di **3b-E.12**: un campo che manda il server e
/// che `esercizioInJson` non riscrive **sparisce al primo salvataggio locale**.
/// 🚨 E da 3b-E la scheda si risalva a **ogni allenamento**: la foto si
/// vedrebbe la prima volta e mai più, senza nessun errore da nessuna parte —
/// il trainer penserebbe di non averla caricata.
///
/// ⚠️ L'altra metà è la **tinta**: l'illustrazione del catalogo è un disegno al
/// tratto e va tinta, una fotografia no. Per questo il server manda `image_url`
/// sulla riga **solo quando c'è davvero**, e non ripiega sul catalogo: se
/// ripiegasse, l'app tratterebbe il disegno come una foto e su fondo chiaro
/// diventerebbe invisibile.
void main() {
  /// Un esercizio come lo manda il server, con la foto messa dal pannello.
  Map<String, dynamic> dalServer({
    String? foto = 'https://esempio/presa.jpg',
  }) => {
    'id': 1,
    'name': 'Lat machine',
    'sets': 3,
    'reps': '10',
    'image_url': ?foto,
    'exercise': {
      'id': 7,
      'name': 'Lat machine',
      'image_url': 'https://esempio/catalogo/lat.png',
    },
  };

  group('la foto della riga arriva dal server', () {
    test('si legge da image_url al primo livello', () {
      final e = PlanExercise.fromJson(dalServer());

      expect(e.immagineUrl, 'https://esempio/presa.jpg');
    });

    test('e non si confonde con quella del catalogo', () {
      final e = PlanExercise.fromJson(dalServer());

      expect(
        e.imageUrl,
        'https://esempio/catalogo/lat.png',
        reason:
            'exercise.image_url è l\'illustrazione condivisa: è quella che va '
            'tinta, e va tenuta distinta dalla fotografia.',
      );
    });

    test('è null quando il trainer non ne ha caricata nessuna', () {
      final e = PlanExercise.fromJson(dalServer(foto: null));

      expect(
        e.immagineUrl,
        isNull,
        reason:
            'Il ripiego sul catalogo lo fa l\'app, che sa quale delle due va '
            'tinta. Se lo facesse il server, il disegno arriverebbe qui '
            'travestito da fotografia e smetterebbe di essere tinto.',
      );
    });
  });

  group('🚨 e sopravvive al salvataggio locale', () {
    test('un giro completo: server → editor → JSON locale → riletta', () {
      // 1️⃣ Arriva dal server e si apre nell'editor.
      final scritto = EsercizioInScrittura.da(dalServer());

      expect(scritto.immagineUrl, 'https://esempio/presa.jpg');

      // 2️⃣ L'app la risalva in locale — succede a ogni allenamento.
      final locale = scritto.versoIlDato();

      expect(
        locale['image_url'],
        'https://esempio/presa.jpg',
        reason:
            'Se esercizioInJson non la riscrive, la foto sparisce al primo '
            'allenamento: è il difetto di 3b-E.12, in un altro campo.',
      );

      // 3️⃣ E rileggendo la copia locale c'è ancora.
      expect(
        PlanExercise.fromJson(locale).immagineUrl,
        'https://esempio/presa.jpg',
      );
    });

    test('e ci arriva anche il player', () {
      final inAllenamento = EsercizioInAllenamento.da(dalServer());

      expect(
        inAllenamento.immagineUrl,
        'https://esempio/presa.jpg',
        reason:
            'È la metà della richiesta: «la scheda ricevuta deve mostrare '
            'quell\'immagine durante l\'allenamento».',
      );
    });

    test('⛔ senza foto non si scrive un campo vuoto', () {
      final scritto = EsercizioInScrittura.da(dalServer(foto: null));

      expect(scritto.versoIlDato().containsKey('image_url'), isFalse);
    });
  });
}
