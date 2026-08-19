import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/api/api_client.dart';
import '../../../core/crypto/contenuto_messaggio.dart';
import '../../../core/crypto/foto_cifrata.dart';
import '../../../core/media/archivio_foto.dart';
import '../../../core/media/tipo_foto.dart';

/// Porta una foto da un telefono all'altro senza che il server la veda — N13.
///
/// ── 🚨 I due pezzi viaggiano su due strade ────────────────────────────────
///
/// ```
/// i byte  ──cifrati con una chiave a caso──▶  POST /conversations/N/allegati
///                                                      │ torna un token
/// la chiave + il token  ──dentro la busta crypto_box──▶ POST .../messages
/// ```
///
/// 💡 Il server tiene un blob cifrato con una chiave che non ha mai visto, e un
/// messaggio cifrato che non sa aprire. **Non ha nessuno dei due pezzi.**
class AllegatoDiChat {
  const AllegatoDiChat({
    required this.api,
    required this.cripto,
    this.archivio = const ArchivioFoto(),
  });

  final ApiClient api;
  final FotoCifrata cripto;
  final ArchivioFoto archivio;

  /// Cifra, carica, e torna la busta da mettere nel messaggio.
  ///
  /// [avanzamento] va da 0 a 1 mentre i byte salgono: una foto su rete mobile
  /// impiega qualche secondo, e senza una barra sembra che non stia succedendo
  /// niente.
  Future<ContenutoFoto> carica({
    required int conversationId,
    required Uint8List foto,
    void Function(double)? avanzamento,
  }) async {
    final chiave = cripto.generaChiave();

    try {
      final cifrata = await cripto.cifra(chiave: chiave, contenuto: foto);

      final modulo = FormData.fromMap({
        'file': MultipartFile.fromBytes(cifrata, filename: 'a.bin'),
      });

      final risposta = await api.upload<Map<String, dynamic>>(
        '/conversations/$conversationId/allegati',
        modulo,
      );

      return ContenutoFoto(
        token: risposta['token']?.toString() ?? '',
        chiaveBase64: base64Encode(cripto.byteDi(chiave)),
        byteTotali: foto.length,
      );
    } finally {
      /*
       * ⚠️ **La chiave si libera qui, non prima.** È memoria protetta: dopo
       * `dispose` leggerla darebbe byte a caso, e il messaggio partirebbe con
       * una chiave sbagliata — cioè una foto che nessuno riesce ad aprire, e
       * nessun errore da nessuna parte.
       */
      chiave.dispose();
    }
  }

  /// Scarica, decifra e mette la foto in `Documents/foto/chat/`.
  ///
  /// ── ⚠️ Si scarica UNA VOLTA SOLA ───────────────────────────────────────
  ///
  /// Il server cancella il blob appena lo consegna. 💡 Per questo il file viene
  /// scritto su disco **subito**: la seconda volta che si guarda quel messaggio
  /// non c'è più niente da scaricare, e la foto deve venire da lì.
  ///
  /// @return il percorso relativo, o `null` se sul server non c'è più.
  Future<String?> riprendi(ContenutoFoto busta) async {
    if (!busta.completa) return null;

    final gia = await _giaScaricata(busta.token);

    if (gia != null) return gia;

    final Uint8List cifrata;

    try {
      cifrata = await api.scaricaByte('/allegati/${busta.token}');
    } on DioException catch (e) {
      /*
       * 💡 **404 non è un guasto**: è una foto scaduta, o già scaricata da
       * questo stesso telefono prima di una reinstallazione. ⚠️ Mostrarla come
       * errore manderebbe qualcuno a cercare un difetto che non c'è.
       */
      if (e.response?.statusCode == 404) return null;

      rethrow;
    }

    final chiave = cripto.chiaveDa(base64Decode(busta.chiaveBase64));

    try {
      final chiara = await cripto.decifra(chiave: chiave, contenuto: cifrata);

      return _riponi(busta.token, chiara);
    } finally {
      chiave.dispose();
    }
  }

  /// 🚨 Il nome sul disco **è il token**: è già casuale e unico, e permette di
  /// riconoscere una foto già scaricata senza tenere un secondo indice.
  Future<String> _riponi(String token, Uint8List byte) async {
    final cartella = await archivio.cartellaDi(TipoFoto.chat);
    final nome = '$token.jpg';

    await File(p.join(cartella.path, nome)).writeAsBytes(byte);

    return p.url.join(ArchivioFoto.madre, TipoFoto.chat.cartella, nome);
  }

  Future<String?> _giaScaricata(String token) async {
    final relativo = p.url.join(
      ArchivioFoto.madre,
      TipoFoto.chat.cartella,
      '$token.jpg',
    );

    return (await archivio.fileDi(relativo)).existsSync() ? relativo : null;
  }
}
