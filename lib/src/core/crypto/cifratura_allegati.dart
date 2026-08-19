import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

/// Un allegato cifrato con una chiave **a caso, sua e di nessun altro** — N13.1.
///
/// 📌 **Si chiamava `FotoCifrata` fino alla `v7.11.0`**, ed era un nome giusto
/// finché passavano solo foto. ⚠️ Da N21 passano anche i PDF, e un nome che dice
/// «foto» su una classe che cifra qualunque cosa è il tipo di deriva che, fra
/// sei mesi, fa cercare a qualcuno una seconda classe per i documenti — e
/// trovarne due che fanno la stessa cosa in modi leggermente diversi.
///
/// ── 🚨 Perché una chiave nuova per ogni foto ───────────────────────────────
///
/// Il backup usa una chiave **derivata dalla chiave maestra**: là le foto sono
/// tue e restano tue, e una chiave sola va benissimo. Qui no. Una foto in chat
/// deve poterla aprire **l'altra persona**, e la chiave le va consegnata —
/// dentro il messaggio, che è già una busta `crypto_box` fra i due.
///
/// ⚠️ Con una chiave derivata dalla maestra bisognerebbe consegnare **quella**,
/// e chi la riceve potrebbe aprire ogni foto mai cifrata con essa: il backup
/// compreso. Una chiave per foto limita il danno a quella foto.
///
/// 💡 Il server riceve byte cifrati con una chiave che non ha mai visto, e
/// consegna un messaggio cifrato che non sa aprire. Non è una promessa
/// organizzativa: non ha nessuno dei due pezzi.
class CifraturaAllegati {
  const CifraturaAllegati(this._sodium);

  final SodiumSumo _sodium;

  /// ⚠️ Un megabyte per blocco, come il file di backup: dev'essere lo stesso da
  /// una parte e dall'altra, o il flusso non si riapre.
  static const int byteDelBlocco = 1024 * 1024;

  /// Una chiave nuova, per una foto sola.
  SecureKey generaChiave() => _sodium.crypto.secretStream.keygen();

  /// Cifra i byte con [chiave]. 💡 Non guarda cosa sono: foto, PDF, o altro.
  Future<Uint8List> cifra({
    required SecureKey chiave,
    required Uint8List contenuto,
  }) async {
    final blocchi = await _sodium.crypto.secretStream
        .pushChunked(
          messageStream: Stream.value(contenuto),
          key: chiave,
          chunkSize: byteDelBlocco,
        )
        .expand((b) => b)
        .toList();

    return Uint8List.fromList(blocchi);
  }

  /// Riapre i byte cifrati.
  ///
  /// ⚠️ Lancia [AllegatoNonSiApre] se la chiave è sbagliata **o** se i byte sono
  /// rovinati: da fuori sono indistinguibili, e va detta la cosa vera.
  Future<Uint8List> decifra({
    required SecureKey chiave,
    required Uint8List contenuto,
  }) async {
    try {
      final blocchi = await _sodium.crypto.secretStream
          .pullChunked(
            cipherStream: Stream.value(contenuto),
            key: chiave,
            chunkSize: byteDelBlocco,
          )
          .expand((b) => b)
          .toList();

      return Uint8List.fromList(blocchi);
    } on Object {
      throw const AllegatoNonSiApre();
    }
  }

  /// La chiave da mettere dentro il messaggio, e quella che ne esce.
  ///
  /// 💡 `extractBytes` copia: la [SecureKey] resta di chi l'ha creata e va
  /// liberata da lui. ⚠️ Restituire la chiave stessa vorrebbe dire due
  /// proprietari per la stessa memoria protetta, e un `dispose` di troppo
  /// farebbe fallire l'altro in un punto lontanissimo.
  Uint8List byteDi(SecureKey chiave) => chiave.extractBytes();

  SecureKey chiaveDa(Uint8List byte) => SecureKey.fromList(_sodium, byte);
}

/// Questi byte non si aprono con questa chiave.
class AllegatoNonSiApre implements Exception {
  const AllegatoNonSiApre();

  @override
  String toString() => 'Non riesco ad aprire questa foto.';
}
