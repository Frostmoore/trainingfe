import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/fotocamera/ui/schermata_ingrandimento.dart';

/// Dal gesto ai pixel — N11.2.
///
/// 🚨 È la stessa promessa della fotocamera — **quello che vedi è quello che
/// salvi** — ma per le foto della galleria. Qui la traduzione è aritmetica, e
/// quindi si può provare: dentro la schermata non si sarebbe potuto.
void main() {
  /// La finestra quadrata, in pixel logici.
  const lato = 300.0;

  group('senza gesti, con l\'immagine centrata', () {
    test('da una foto orizzontale si prende il quadrato centrale', () {
      /*
       * Foto 2000×1000. Disegnata «a copertura»: alta quanto la finestra (300)
       * e larga 600. Centrata, la finestra vede i 300 px di mezzo.
       *
       * In pixel originali: scala = 2000/600 = 3,333… → il quadrato è alto
       * 1000 (tutta l'altezza) e largo 1000, centrato in orizzontale: da 500 a
       * 1500.
       */
      final centrata = Matrix4.identity()
        ..translateByDouble(-(600.0 - lato) / 2, 0, 0, 1);

      final r = riquadroInPixel(
        trasformazione: centrata,
        lato: lato,
        disegnata: const Size(600, 300),
        larghezzaOriginale: 2000,
      );

      expect(r.left, closeTo(500, 0.5));
      expect(r.right, closeTo(1500, 0.5));
      expect(r.top, closeTo(0, 0.5));
      expect(r.bottom, closeTo(1000, 0.5));
      expect(r.width, closeTo(r.height, 0.5), reason: 'non è un quadrato');
    });

    test('da una foto verticale idem, ma tagliando sopra e sotto', () {
      // Foto 1000×2000 → disegnata 300×600, centrata in verticale.
      final centrata = Matrix4.identity()
        ..translateByDouble(0, -(600.0 - lato) / 2, 0, 1);

      final r = riquadroInPixel(
        trasformazione: centrata,
        lato: lato,
        disegnata: const Size(300, 600),
        larghezzaOriginale: 1000,
      );

      expect(r.left, closeTo(0, 0.5));
      expect(r.right, closeTo(1000, 0.5));
      expect(r.top, closeTo(500, 0.5));
      expect(r.bottom, closeTo(1500, 0.5));
    });

    test('una foto già quadrata si prende tutta', () {
      final r = riquadroInPixel(
        trasformazione: Matrix4.identity(),
        lato: lato,
        disegnata: const Size(lato, lato),
        larghezzaOriginale: 1500,
      );

      expect(r.left, closeTo(0, 0.5));
      expect(r.top, closeTo(0, 0.5));
      expect(r.width, closeTo(1500, 0.5));
    });
  });

  group('con i gesti', () {
    test('trascinando si sposta il pezzo preso, non la sua misura', () {
      // Si sposta di 60 px disegnati verso sinistra: l'immagine scorre, e il
      // pezzo visibile si sposta a destra di 60 × scala.
      final spostata = Matrix4.identity()
        ..translateByDouble(-(600.0 - lato) / 2 - 60, 0, 0, 1);

      final r = riquadroInPixel(
        trasformazione: spostata,
        lato: lato,
        disegnata: const Size(600, 300),
        larghezzaOriginale: 2000,
      );

      // scala = 2000/600 → 60 disegnati sono 200 originali.
      expect(r.left, closeTo(700, 0.5));
      expect(r.width, closeTo(1000, 0.5), reason: 'la misura non doveva cambiare');
    });

    test('🚨 ingrandendo si prende MENO immagine, non di più', () {
      /*
       * ⚠️ È il segno che si sbaglia. Zoom ×2 vuol dire che nella stessa
       * finestra ci sta **metà** dell'immagine: se il riquadro tornasse più
       * grande, il ritaglio uscirebbe rimpicciolito invece che ingrandito, e
       * nessuno capirebbe perché la foto è «venuta larga».
       */
      final ingrandita = Matrix4.identity()
        ..scaleByDouble(2, 2, 1, 1)
        ..translateByDouble(-(600.0 - lato) / 2, 0, 0, 1);

      final r = riquadroInPixel(
        trasformazione: ingrandita,
        lato: lato,
        disegnata: const Size(600, 300),
        larghezzaOriginale: 2000,
      );

      expect(r.width, closeTo(500, 1), reason: 'lo zoom va al contrario');
      expect(r.height, closeTo(500, 1));
    });
  });

  test('⚠️ la scala dai pixel disegnati agli originali non si dimentica', () {
    /*
     * È il passaggio che salta: senza, una foto da 4000 px mostrata larga 300
     * darebbe un riquadro di 300 px in alto a sinistra — un francobollo — e il
     * risultato sembrerebbe «uno zoom pazzesco» invece di un errore di scala.
     */
    final r = riquadroInPixel(
      trasformazione: Matrix4.identity(),
      lato: lato,
      disegnata: const Size(lato, lato),
      larghezzaOriginale: 4000,
    );

    expect(r.width, closeTo(4000, 1), reason: 'ha lavorato in pixel disegnati');
  });
}
