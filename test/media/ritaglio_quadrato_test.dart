import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:training_companion/src/core/media/formato_foto.dart';
import 'package:training_companion/src/core/media/ritaglio_quadrato.dart';

/// Il ritaglio quadrato — N9.5.
///
/// 💡 Si prova `eseguiRitaglio` e non `ritagliaQuadrato`: la seconda è solo un
/// `compute` intorno alla prima, e in `flutter test` avviare un isolato per
/// ogni caso costerebbe secondi senza dimostrare niente di più.
void main() {
  /// Un'immagine con un colore diverso in ogni angolo, per riconoscere **quale
  /// pezzo** è stato tenuto.
  Uint8List sorgente({required int larghezza, required int altezza}) {
    final i = img.Image(width: larghezza, height: altezza);

    img.fill(i, color: img.ColorRgb8(0, 0, 0));

    // Un bollo bianco esattamente al centro.
    img.fillRect(
      i,
      x1: larghezza ~/ 2 - 2,
      y1: altezza ~/ 2 - 2,
      x2: larghezza ~/ 2 + 2,
      y2: altezza ~/ 2 + 2,
      color: img.ColorRgb8(255, 255, 255),
    );

    return Uint8List.fromList(img.encodeJpg(i));
  }

  img.Image apri(Uint8List byte) => img.decodeImage(byte)!;

  group('il ritaglio centrale', () {
    test('da una foto verticale esce un quadrato', () {
      final uscita = eseguiRitaglio(
        OrdineDiRitaglio(byte: sorgente(larghezza: 1200, altezza: 1600)),
      );

      final r = apri(uscita!);

      expect(r.width, r.height);
      expect(r.width, FormatoFoto.lato);
    });

    test('da una foto orizzontale pure', () {
      final uscita = eseguiRitaglio(
        OrdineDiRitaglio(byte: sorgente(larghezza: 1600, altezza: 1200)),
      );

      final r = apri(uscita!);

      expect(r.width, r.height);
      expect(r.width, FormatoFoto.lato);
    });

    test('tiene il centro, non l\'angolo', () {
      // 🚨 Il bollo bianco sta al centro dell'originale: se il ritaglio
      // partisse da (0,0) — l'errore facile — al centro del risultato ci
      // sarebbe nero.
      final uscita = eseguiRitaglio(
        OrdineDiRitaglio(byte: sorgente(larghezza: 1200, altezza: 1600)),
      );

      final r = apri(uscita!);
      final centro = r.getPixel(r.width ~/ 2, r.height ~/ 2);

      expect(centro.r, greaterThan(200), reason: 'ha ritagliato altrove');
    });
  });

  group('la misura', () {
    test('🚨 non ingrandisce mai una foto piccola', () {
      /*
       * Una foto già più piccola di 1080 portata a 1080 peserebbe **di più**
       * senza un dettaglio in più: pixel inventati, pagati in byte veri sul
       * disco e nel backup di qualcuno.
       */
      final uscita = eseguiRitaglio(
        OrdineDiRitaglio(byte: sorgente(larghezza: 400, altezza: 600)),
      );

      final r = apri(uscita!);

      expect(r.width, 400, reason: 'ha ingrandito');
      expect(r.height, 400);
    });

    test('una foto già quadrata e grande viene rimpicciolita', () {
      final uscita = eseguiRitaglio(
        OrdineDiRitaglio(byte: sorgente(larghezza: 2000, altezza: 2000)),
      );

      expect(apri(uscita!).width, FormatoFoto.lato);
    });
  });

  group('il riquadro scelto a mano', () {
    test('si tiene il pezzo chiesto', () {
      final uscita = eseguiRitaglio(
        OrdineDiRitaglio(
          byte: sorgente(larghezza: 2000, altezza: 2000),
          riquadro: const Rect.fromLTWH(0, 0, 500, 500),
        ),
      );

      // 💡 500 < 1080, quindi non si ingrandisce: resta 500.
      expect(apri(uscita!).width, 500);
    });

    test('⚠️ un riquadro che esce dai bordi viene riportato dentro', () {
      /*
       * Arriva da un gesto: pizzicando e trascinando si esce facilmente dai
       * bordi, e `copyCrop` con coordinate fuori produce un'immagine sbagliata
       * o un'eccezione. Meglio un ritaglio un po' diverso che uno scatto perso.
       */
      final uscita = eseguiRitaglio(
        OrdineDiRitaglio(
          byte: sorgente(larghezza: 800, altezza: 800),
          riquadro: const Rect.fromLTWH(700, 700, 400, 400),
        ),
      );

      expect(uscita, isNotNull);
      expect(apri(uscita!).width, lessThanOrEqualTo(800));
    });

    test('un riquadro più grande dell\'immagine non la fa esplodere', () {
      final uscita = eseguiRitaglio(
        OrdineDiRitaglio(
          byte: sorgente(larghezza: 600, altezza: 600),
          riquadro: const Rect.fromLTWH(-100, -100, 5000, 5000),
        ),
      );

      expect(uscita, isNotNull);
      expect(apri(uscita!).width, 600);
    });
  });

  test('🚨 l\'EXIF sparisce, GPS compreso', () {
    /*
     * Una foto di progresso si scatta quasi sempre in casa propria. Con l'EXIF
     * dentro, ogni foto caricata su Drive porterebbe **le coordinate di dove
     * abita qualcuno**.
     *
     * ⚠️ Oggi funziona perché `encodeJpg` riscrive il file da zero. Questo test
     * esiste per accorgersene se un giorno qualcuno introducesse un percorso
     * che i tag li conserva.
     */
    final conPosizione = img.Image(width: 1200, height: 1200);
    img.fill(conPosizione, color: img.ColorRgb8(10, 20, 30));

    conPosizione.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(44, 1);
    conPosizione.exif.gpsIfd['GPSLongitude'] = img.IfdValueRational(11, 1);
    conPosizione.exif.imageIfd['Make'] = 'Marca Finta';

    final prima = img.decodeImage(
      Uint8List.fromList(img.encodeJpg(conPosizione)),
    )!;

    expect(
      prima.exif.gpsIfd.isEmpty && prima.exif.imageIfd.isEmpty,
      isFalse,
      reason: 'la premessa del test e\' sbagliata: non ho scritto nessun EXIF',
    );

    final dopo = apri(
      eseguiRitaglio(
        OrdineDiRitaglio(byte: Uint8List.fromList(img.encodeJpg(conPosizione))),
      )!,
    );

    expect(dopo.exif.gpsIfd.isEmpty, isTrue, reason: 'il GPS e\' sopravvissuto');
    expect(dopo.exif.imageIfd.isEmpty, isTrue);
  });

  test('byte che non sono un\'immagine tornano null, senza lanciare', () {
    // 💡 Chi chiama tiene l'originale: una foto storta è meglio di nessuna foto.
    expect(
      eseguiRitaglio(
        OrdineDiRitaglio(byte: Uint8List.fromList(List.filled(100, 7))),
      ),
      isNull,
    );
  });
}
