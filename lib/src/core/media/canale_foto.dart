import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/fotocamera/ui/schermata_fotocamera.dart';
import '../../features/fotocamera/ui/schermata_ingrandimento.dart';
import 'archivio_foto.dart';
import 'tipo_foto.dart';

/// **L'unica porta da cui entra una foto nell'app** — N11.3.
///
/// ── 🚨 Una sola, e questo è tutto il punto ─────────────────────────────────
///
/// Prima c'era `PhotoPicker`, che parlava direttamente con `image_picker` ed
/// era tarato su **un** uso: quello dell'AI, 1600 px sul lato lungo. ⚠️ Ne
/// pagava il pegno l'uso più frequente — le foto di progresso venivano salvate
/// a quattro volte i pixel che servono a guardarle, per sempre, sul disco e nel
/// backup di ogni persona. E nessuno l'aveva deciso: era solo successo.
///
/// 💡 Da qui in poi nessuna funzione parla con la fotocamera o con la galleria.
/// Si chiede una foto **di un tipo**, e tornano il percorso relativo e il file:
/// la misura, il ritaglio, la cartella e il destino li decide questo canale.
class CanaleFoto {
  const CanaleFoto._();

  static final _galleria = ImagePicker();

  /// Scatta con la fotocamera nostra.
  ///
  /// 💡 Il quadrato lo compone la persona guardando la maschera: quello che
  /// vede è quello che viene salvato, e non c'è niente da confermare dopo.
  static Future<FotoScelta?> scatta(
    BuildContext context, {
    required TipoFoto tipo,
    String? titolo,
  }) async {
    final byte = await SchermataFotocamera.apri(context, titolo: titolo);

    if (byte == null) return null;

    return _riponi(tipo: tipo, byte: byte);
  }

  /// Prende una foto già scattata e ne fa scegliere il quadrato.
  ///
  /// 🚨 **Passa sempre dall'ingrandimento, mai da un ritaglio in silenzio.**
  /// ⚠️ Una foto della galleria l'ha composta qualcun altro, mesi fa, con le
  /// proporzioni che aveva: ritagliarla al centro senza mostrarlo vorrebbe dire
  /// tagliare la testa a qualcuno e farglielo scoprire dopo.
  static Future<FotoScelta?> dallaGalleria(
    BuildContext context, {
    required TipoFoto tipo,
    String? titolo,
  }) async {
    final scelta = await _galleria.pickImage(source: ImageSource.gallery);

    if (scelta == null) return null;

    final grezza = await scelta.readAsBytes();

    if (!context.mounted) return null;

    final byte = await SchermataIngrandimento.apri(
      context,
      byte: grezza,
      titolo: titolo,
    );

    if (byte == null) return null;

    return _riponi(tipo: tipo, byte: byte);
  }

  static Future<FotoScelta> _riponi({
    required TipoFoto tipo,
    required Uint8List byte,
  }) async {
    const archivio = ArchivioFoto();

    final relativo = await archivio.salva(tipo: tipo, byte: byte);

    return FotoScelta(
      relativo: relativo,
      file: await archivio.fileDi(relativo),
    );
  }
}

/// Una foto entrata in casa.
///
/// 💡 Torna **tutti e due**: il [relativo] è quello che va a database e
/// sopravvive agli aggiornamenti di iOS, il [file] serve a chi deve caricarla
/// o mostrarla adesso. ⚠️ Dando solo il primo, ogni chiamante avrebbe dovuto
/// conoscere `ArchivioFoto` per riaprirlo — e il canale unico avrebbe smesso di
/// essere unico il giorno dopo.
class FotoScelta {
  const FotoScelta({required this.relativo, required this.file});

  /// `foto/<cartella>/<nome>` — 🚨 **relativo**, mai assoluto.
  final String relativo;

  final File file;
}
