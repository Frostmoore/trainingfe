import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Sceglie una foto e **la comprime prima di restituirla** — A4.3.
///
/// 🚨 **La compressione non è un'ottimizzazione: è ciò che fa funzionare la
/// funzione.** Una foto da fotocamera moderna sono 8-12 MB. Su rete mobile
/// l'upload impiega mezzo minuto o fallisce, e il backend la ridimensiona
/// comunque a 1568 px per mandarla al modello: mandare l'originale è banda
/// sprecata due volte, una dell'utente e una nostra.
///
/// 1600 px sul lato lungo e non 1568: qualche pixel di margine evita che una
/// seconda riduzione lato server tocchi un'immagine già al limite.
class PhotoPicker {
  const PhotoPicker._();

  static const _latoMassimo = 1600;
  static const _qualita = 85;

  static final _picker = ImagePicker();

  static Future<String?> dallaFotocamera() => _scegli(ImageSource.camera);

  static Future<String?> dallaGalleria() => _scegli(ImageSource.gallery);

  static Future<String?> _scegli(ImageSource sorgente) async {
    final scatto = await _picker.pickImage(
      source: sorgente,
      // `image_picker` sa già ridimensionare: si parte da qui perché è più
      // veloce (lo fa la piattaforma) e riduce il picco di memoria.
      maxWidth: _latoMassimo.toDouble(),
      maxHeight: _latoMassimo.toDouble(),
      imageQuality: _qualita,
    );

    if (scatto == null) return null;

    return _comprimi(scatto.path);
  }

  /// Seconda passata: `image_picker` su alcune versioni di Android ignora
  /// `imageQuality`, e senza questa il file resta grande.
  static Future<String> _comprimi(String origine) async {
    final cartella = await getTemporaryDirectory();
    final destinazione =
        '${cartella.path}/tc_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final risultato = await FlutterImageCompress.compressAndGetFile(
      origine,
      destinazione,
      quality: _qualita,
      minWidth: _latoMassimo,
      minHeight: _latoMassimo,
      format: CompressFormat.jpeg,
    );

    // Se la compressione fallisce si manda l'originale: una funzione che non
    // parte è peggio di un upload lento.
    return risultato?.path ?? origine;
  }

  /// Quanto pesa un file, per mostrarlo o per decidere.
  static Future<int> dimensione(String path) => File(path).length();
}
