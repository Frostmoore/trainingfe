import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/api/api_client.dart';
import '../../../core/crypto/cifratura_allegati.dart';
import '../../../core/crypto/contenuto_messaggio.dart';
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
  final CifraturaAllegati cripto;
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
  /// ── 🚨 [dove] non e' una comodita': e' cio' che tiene le foto usa e
  /// getta FUORI dal backup — N16.6 ──────────────────────────────────────
  ///
  /// Una foto effimera va in `TipoFoto.effimere`, che vive nella **cache**.
  /// Android esclude sempre `getCacheDir()` dal backup e quell'esclusione non e'
  /// sovrascrivibile: quindi non ci finisce **per costruzione**, non perche'
  /// qualcuno si e' ricordato di scriverlo da qualche parte.
  ///
  /// ⚠️ Il caso contrario e' il guasto peggiore possibile: una foto mandata
  /// «una volta sola» che sopravvive per sempre su Drive, cioe' l'esatto
  /// contrario di quello che ha chiesto chi l'ha mandata — e nessuno se ne
  /// accorgerebbe.
  ///
  /// ── ⚠️ Si scarica UNA VOLTA SOLA ───────────────────────────────────────
  ///
  /// Il server cancella il blob appena lo consegna. 💡 Per questo il file viene
  /// scritto su disco **subito**: la seconda volta che si guarda quel messaggio
  /// non c'è più niente da scaricare, e la foto deve venire da lì.
  ///
  /// @return il percorso relativo, o `null` se sul server non c'è più.
  Future<String?> riprendi(ContenutoFoto busta, {TipoFoto dove = TipoFoto.chat}) async {
    if (!busta.completa) return null;

    final gia = await _giaScaricata(busta.token, dove);

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

      return _riponi(busta.token, chiara, dove);
    } finally {
      chiave.dispose();
    }
  }

  // ─────────────────────────── i documenti ───────────────────────────
  //
  // 💡 Stesso viaggio delle foto — cifrati con una chiave a caso, i byte da una
  // parte e la chiave dall'altra — e stesso codice. ⚠️ Cambia solo che un
  // documento porta con sé **un nome**: «piano-marzo.pdf» dice cosa si sta per
  // aprire, mentre una foto si riconosce guardandola.

  /// Cifra e carica un documento.
  Future<ContenutoDocumento> caricaDocumento({
    required int conversationId,
    required Uint8List byte,
    required String nome,
  }) async {
    final chiave = cripto.generaChiave();

    try {
      final cifrato = await cripto.cifra(chiave: chiave, contenuto: byte);

      final risposta = await api.upload<Map<String, dynamic>>(
        '/conversations/$conversationId/allegati',
        FormData.fromMap({
          'file': MultipartFile.fromBytes(cifrato, filename: 'a.bin'),
        }),
      );

      return ContenutoDocumento(
        token: risposta['token']?.toString() ?? '',
        chiaveBase64: base64Encode(cripto.byteDi(chiave)),
        // ⚠️ `basename` anche in salita: un nome con dentro un percorso
        // arriverebbe intatto all'altro telefono, e li' sarebbe un problema suo.
        nome: p.basename(nome),
        byteTotali: byte.length,
      );
    } finally {
      chiave.dispose();
    }
  }

  /// Scarica un documento e lo mette accanto alle foto della chat.
  ///
  /// @return il percorso relativo, o `null` se sul server non c'è più.
  Future<String?> riprendiDocumento(ContenutoDocumento busta) async {
    if (!busta.completa) return null;

    /*
     * 🚨 Il nome sul disco resta **il token**, non quello del documento.
     *
     * ⚠️ Due persone possono mandare due «piano.pdf» diversi, e il secondo
     * sovrascriverebbe il primo. Il token è già unico; il nome vero vive nella
     * busta, che è dove serve — cioè quando lo si mostra.
     */
    final estensione = p.extension(busta.nome);
    final relativo = p.url.join(
      ArchivioFoto.madre,
      TipoFoto.chat.cartella,
      '${busta.token}$estensione',
    );

    if ((await archivio.fileDi(relativo)).existsSync()) return relativo;

    final Uint8List cifrato;

    try {
      cifrato = await api.scaricaByte('/allegati/${busta.token}');
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;

      rethrow;
    }

    final chiave = cripto.chiaveDa(base64Decode(busta.chiaveBase64));

    try {
      final chiaro = await cripto.decifra(chiave: chiave, contenuto: cifrato);
      final cartella = await archivio.cartellaDi(TipoFoto.chat);

      await File(p.join(cartella.path, '${busta.token}$estensione'))
          .writeAsBytes(chiaro);

      return relativo;
    } finally {
      chiave.dispose();
    }
  }

  /// 🚨 Il nome sul disco **è il token**: è già casuale e unico, e permette di
  /// riconoscere una foto già scaricata senza tenere un secondo indice.
  /// Dove finisce sul telefono l'allegato di questo token.
  ///
  /// 🚨 **Sta qui e in nessun altro posto.** La convenzione
  /// `<token>.jpg` la conosce questa classe: chi la ricalcolasse altrove
  /// scriverebbe la stessa stringa una seconda volta, e il giorno che cambia —
  /// un'estensione, una sottocartella — una delle due copie resterebbe indietro
  /// e cercherebbe un file che non c'e' piu'.
  static String percorsoDi(String token, TipoFoto dove) =>
      p.url.join(ArchivioFoto.madre, dove.cartella, '$token.jpg');

  Future<String> _riponi(String token, Uint8List byte, TipoFoto dove) async {
    final cartella = await archivio.cartellaDi(dove);

    await File(p.join(cartella.path, '$token.jpg')).writeAsBytes(byte);

    return percorsoDi(token, dove);
  }

  Future<String?> _giaScaricata(String token, TipoFoto dove) async {
    final relativo = percorsoDi(token, dove);

    return (await archivio.fileDi(relativo)).existsSync() ? relativo : null;
  }
}
