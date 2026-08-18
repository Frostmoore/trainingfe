import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'formato_foto.dart';

/// Porta una foto al quadrato di [FormatoFoto.lato] — N9.4.
///
/// ── ⚠️ Fuori dal thread della grafica, e non è pignoleria ──────────────────
///
/// Decodificare un JPEG grande in Dart puro sono **centinaia di millisecondi**.
/// Farlo in linea bloccherebbe l'interfaccia proprio **dopo lo scatto**, che è
/// l'istante in cui si sta guardando lo schermo: l'app sembrerebbe piantata nel
/// momento peggiore.
Future<Uint8List?> ritagliaQuadrato({
  required Uint8List byte,
  Rect? riquadro,
}) => compute(
  eseguiRitaglio,
  OrdineDiRitaglio(byte: byte, riquadro: riquadro),
);

/// L'ordine che attraversa il confine dell'isolato: solo dati, niente oggetti.
class OrdineDiRitaglio {
  const OrdineDiRitaglio({required this.byte, this.riquadro});

  final Uint8List byte;

  /// Il pezzo da tenere, in **pixel dell'immagine originale**.
  ///
  /// 💡 `null` = si prende il quadrato più grande **al centro**. È il caso
  /// della fotocamera, dove l'inquadratura l'ha già decisa la maschera; quando
  /// è valorizzato arriva dalla schermata di ingrandimento, dove il riquadro
  /// l'ha scelto la persona.
  final Rect? riquadro;
}

/// 🚨 **Di primo livello, e deve restarlo.**
///
/// `compute` avvia un isolato, e a un isolato si può passare solo una funzione
/// che non si porta dietro un contesto. ⚠️ Trasformarla in un metodo di una
/// classe la farebbe fallire a **tempo di esecuzione**, non di compilazione:
/// il difetto comparirebbe sul telefono di qualcuno, non qui.
@visibleForTesting
Uint8List? eseguiRitaglio(OrdineDiRitaglio ordine) {
  final immagine = img.decodeImage(ordine.byte);

  if (immagine == null) return null;

  final quadrata = _ritaglia(immagine, ordine.riquadro);

  /*
   * ── ⚠️ Si rimpicciolisce, non si ingrandisce MAI ─────────────────────────
   *
   * Una foto già più piccola di 1080 portata a 1080 peserebbe **di più** senza
   * avere un dettaglio in più: sarebbero pixel inventati dall'interpolazione,
   * pagati in byte veri sul disco e nel backup di qualcuno.
   */
  final finale = quadrata.width > FormatoFoto.lato
      ? img.copyResize(
          quadrata,
          width: FormatoFoto.lato,
          height: FormatoFoto.lato,
          interpolation: img.Interpolation.average,
        )
      : quadrata;

  /*
   * ── 🚨 L'EXIF si butta A MANO, e il test lo ha dimostrato ────────────
   *
   * Qui c'era scritto che `encodeJpg` riscrive il file da zero e i tag non
   * passano. ⚠️ **È falso**: il pacchetto `image` decodifica l'EXIF dentro
   * `Image.exif` e se lo porta dietro attraverso `copyCrop` e `copyResize`, e
   * lo riscrive nel JPEG in uscita.
   *
   * Il percorso vecchio non ne soffriva perché la compressione la faceva
   * `flutter_image_compress` con `keepExif: false`, cioè codice nativo che
   * i tag li scarta davvero. Passando al ritaglio in Dart quella protezione
   * sarebbe sparita **senza che niente lo dicesse**.
   *
   * 🚨 Una foto di progresso si scatta quasi sempre in casa propria: con
   * l'EXIF dentro, ogni foto caricata su Drive porterebbe **le coordinate di
   * dove abita qualcuno**. Vedi `test/media/ritaglio_quadrato_test.dart`.
   */
  finale.exif = img.ExifData();

  return img.encodeJpg(finale, quality: FormatoFoto.qualita);
}

/// Il pezzo quadrato da tenere.
img.Image _ritaglia(img.Image immagine, Rect? riquadro) {
  if (riquadro == null) {
    /*
     * Il quadrato più grande che ci sta, preso **al centro**.
     *
     * 💡 Al centro e non in alto: in una foto di progresso il soggetto sta in
     * mezzo, e ritagliare dall'alto taglierebbe le gambe a tutti.
     */
    final lato = immagine.width < immagine.height
        ? immagine.width
        : immagine.height;

    return img.copyCrop(
      immagine,
      x: (immagine.width - lato) ~/ 2,
      y: (immagine.height - lato) ~/ 2,
      width: lato,
      height: lato,
    );
  }

  /*
   * ⚠️ **Il riquadro va riportato dentro l'immagine.**
   *
   * Arriva da un gesto: pizzicando e trascinando si può facilmente uscire dai
   * bordi, e `copyCrop` con coordinate fuori produce un'immagine sbagliata o
   * un'eccezione. 💡 Meglio un ritaglio leggermente diverso da quello chiesto
   * che uno scatto perso.
   */
  final lato = _fraDueEstremi(
    riquadro.width < riquadro.height ? riquadro.width : riquadro.height,
    1,
    (immagine.width < immagine.height ? immagine.width : immagine.height)
        .toDouble(),
  ).round();

  final x = _fraDueEstremi(riquadro.left, 0, (immagine.width - lato).toDouble());
  final y = _fraDueEstremi(riquadro.top, 0, (immagine.height - lato).toDouble());

  return img.copyCrop(
    immagine,
    x: x.round(),
    y: y.round(),
    width: lato,
    height: lato,
  );
}

double _fraDueEstremi(double valore, double minimo, double massimo) {
  if (massimo < minimo) return minimo;

  return valore < minimo ? minimo : (valore > massimo ? massimo : valore);
}
