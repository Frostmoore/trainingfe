import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import 'cassaforte.dart';

/// Il file di backup esportabile — S6.6.
///
/// ── 🚨 A quale guasto risponde, e perché non poteva bastare la password ────
///
/// I tre meccanismi di recupero servono guasti diversi:
///
/// | | Porta | Copre |
/// |---|---|---|
/// | Portachiavi di sistema | il segreto | «non voglio ridigitare la password» |
/// | Ripristino di sistema | l'archivio locale | il **caso normale** |
/// | **Questo file** | archivio **+ chiave maestra** | «ho scordato la password **e** non avevo il backup» |
///
/// 🚨 **Quindi questo file NON può essere protetto dalla password di recupero.**
/// Se lo fosse, non servirebbe a niente proprio nel caso per cui esiste: chi ha
/// scordato la password si troverebbe davanti la stessa porta chiusa.
///
/// ── Il codice di ripristino ────────────────────────────────────────────────
///
/// 💡 Per questo il file è chiuso da un **codice generato dall'app** — sei
/// gruppi di quattro caratteri, mostrati una volta sola al momento
/// dell'esportazione — e non da qualcosa che l'utente sceglie.
///
/// Non è un capriccio: cambia la natura del segreto. Una password si **ricorda**
/// (e si dimentica, ed è il guasto da cui stiamo scappando); un codice si
/// **conserva** insieme al file, in un gestore di password o su un foglio.
/// ⚠️ E ha entropia vera — 120 bit — quindi qui il KDF non è l'unica difesa come
/// invece è per il pacchetto sul server.
///
/// ⚠️ **Le foto entrano solo se spuntate.** Sono l'unica cosa che il committente
/// ha detto di poter perdere, e con dentro le immagini un file di backup passa
/// da qualche centinaio di kilobyte a centinaia di megabyte.
class FileDiBackup {
  FileDiBackup(this._sodium);

  final SodiumSumo _sodium;

  static const int versione = 1;

  /// L'alfabeto del codice: niente `0`/`O`, `1`/`I`/`l`.
  ///
  /// ⚠️ Chi ricopia a mano un codice da un foglio confonde proprio quelli, e un
  /// codice ricopiato male dà lo stesso errore di un codice sbagliato — cioè
  /// nessuna indicazione utile su cosa è successo.
  static const String _alfabeto = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Genera un codice di ripristino: 6 gruppi da 4, ~120 bit.
  String generaCodice() {
    final byte = _sodium.randombytes.buf(24);

    final caratteri = byte
        .map((b) => _alfabeto[b % _alfabeto.length])
        .join();

    final gruppi = <String>[];
    for (var i = 0; i < 24; i += 4) {
      gruppi.add(caratteri.substring(i, i + 4));
    }

    return gruppi.join('-');
  }

  /// Chiude il contenuto dentro il file.
  ///
  /// 🚨 Dentro c'è **la chiave maestra**: è l'unica ragione per cui il file
  /// permette di rientrare in un account senza la password di recupero. Ed è
  /// anche il motivo per cui un file di backup finito nelle mani sbagliate vale
  /// esattamente quanto l'account.
  Uint8List esporta({
    required Uint8List chiaveMaestra,
    required Map<String, dynamic> archivio,
    required String codice,
  }) {
    final salt = _sodium.randombytes.buf(_sodium.crypto.pwhash.saltBytes);
    final nonce = _sodium.randombytes.buf(_sodium.crypto.secretBox.nonceBytes);
    final chiave = _derivaDalCodice(codice: codice, salt: salt);

    try {
      final contenuto = utf8.encode(json.encode({
        'version': versione,
        'master_key': base64Encode(chiaveMaestra),
        'archivio': archivio,
      }));

      final cifrato = _sodium.crypto.secretBox.easy(
        message: Uint8List.fromList(contenuto),
        nonce: nonce,
        key: chiave,
      );

      // L'intestazione resta in chiaro: senza, chi apre il file non saprebbe
      // nemmeno con quali parametri provare ad aprirlo. Non rivela niente —
      // sono gli stessi parametri per tutti.
      return Uint8List.fromList(utf8.encode(json.encode({
        'format': 'training-companion-backup',
        'version': versione,
        'kdf': 'argon2id13',
        'ops_limit': Cassaforte.opsPredefinito,
        'mem_limit': Cassaforte.memPredefinito,
        'salt': base64Encode(salt),
        'nonce': base64Encode(nonce),
        'payload': base64Encode(cifrato),
      })));
    } finally {
      chiave.dispose();
    }
  }

  /// Riapre il file. Lancia [CodiceDiRipristinoSbagliato] se il codice non è
  /// quello, o se il file è rovinato.
  ContenutoDelBackup importa({
    required Uint8List file,
    required String codice,
  }) {
    final Map<String, dynamic> testa;

    try {
      testa = json.decode(utf8.decode(file)) as Map<String, dynamic>;
    } on Object {
      throw const CodiceDiRipristinoSbagliato('Questo file non è un backup.');
    }

    if (testa['format'] != 'training-companion-backup') {
      throw const CodiceDiRipristinoSbagliato('Questo file non è un backup.');
    }

    if (testa['version'] != versione) {
      throw CodiceDiRipristinoSbagliato(
        'Questo backup è stato fatto con una versione '
        '(${testa['version']}) che questa app non conosce.',
      );
    }

    final chiave = _derivaDalCodice(
      codice: codice,
      salt: base64Decode(testa['salt'] as String),
      opsLimit: testa['ops_limit'] as int,
      memLimit: testa['mem_limit'] as int,
    );

    try {
      final chiaro = _sodium.crypto.secretBox.openEasy(
        cipherText: base64Decode(testa['payload'] as String),
        nonce: base64Decode(testa['nonce'] as String),
        key: chiave,
      );

      final dentro = json.decode(utf8.decode(chiaro)) as Map<String, dynamic>;

      return ContenutoDelBackup(
        chiaveMaestra: base64Decode(dentro['master_key'] as String),
        archivio: (dentro['archivio'] as Map).cast<String, dynamic>(),
      );
    } on SodiumException {
      throw const CodiceDiRipristinoSbagliato(
        'Questo codice non apre il file di backup.',
      );
    } finally {
      chiave.dispose();
    }
  }

  /// ⚠️ **Il codice si normalizza prima di derivare**: chi lo ricopia lo scrive
  /// minuscolo, con o senza trattini, magari con uno spazio in mezzo. Senza
  /// normalizzazione quel file darebbe «codice sbagliato» a chi ha il codice
  /// giusto — il modo peggiore di fallire, perché fa credere di aver perso tutto.
  SecureKey _derivaDalCodice({
    required String codice,
    required Uint8List salt,
    int opsLimit = Cassaforte.opsPredefinito,
    int memLimit = Cassaforte.memPredefinito,
  }) =>
      _sodium.crypto.pwhash(
        outLen: _sodium.crypto.secretBox.keyBytes,
        password: normalizza(codice).toCharArray(),
        salt: salt,
        opsLimit: opsLimit,
        memLimit: memLimit,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );

  /// Tutto maiuscolo, senza niente che non sia dell'alfabeto.
  static String normalizza(String codice) => codice
      .toUpperCase()
      .split('')
      .where(_alfabeto.contains)
      .join();
}

/// Quello che c'era dentro il file.
class ContenutoDelBackup {
  const ContenutoDelBackup({
    required this.chiaveMaestra,
    required this.archivio,
  });

  final Uint8List chiaveMaestra;
  final Map<String, dynamic> archivio;
}

/// Il file non si apre con questo codice.
class CodiceDiRipristinoSbagliato implements Exception {
  const CodiceDiRipristinoSbagliato(this.motivo);

  final String motivo;

  @override
  String toString() => motivo;
}
