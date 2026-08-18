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
  // ═══════════════════════════ il formato v2 ═══════════════════════════
  //
  // 🚨 **Perché un formato nuovo** — N1.3, 18/08/2026.
  //
  // Il `v1` mette tutto in un JSON con il payload in base64: per cifrarlo
  // bisogna avere l'intero contenuto in memoria, e con le foto dentro si va in
  // `OutOfMemory` su un telefono normale ben prima di finire.
  //
  // Il `v2` scrive un'intestazione in chiaro seguita da blocchi cifrati con
  // `crypto_secretstream_xchacha20poly1305`, che è fatto apposta per questo: un
  // blocco per volta, autenticato, e con l'ordine dei blocchi che fa parte di
  // ciò che si verifica — quindi nessuno può togliere, riordinare o troncare il
  // file senza che ce ne si accorga.
  //
  // ── 🚨 I DUE involucri, ed è la decisione che regge tutto ─────────────────
  //
  // Il contenuto è cifrato con una chiave **a caso**, generata a ogni backup.
  // Quella chiave sta nell'intestazione, avvolta due volte:
  //
  // | Involucro | Si apre con | Serve a |
  // |---|---|---|
  // | `wrap_password` | la password di recupero | «ho cambiato telefono» |
  // | `wrap_codice` | il codice generato | «ho scordato la password» |
  //
  // ⚠️ Senza il primo, un backup automatico sarebbe cifrato con un codice che
  // la persona non ha mai scritto da nessuna parte: **un backup che non si apre
  // è peggio di nessun backup**, perché fa perdere il telefono tranquilli.
  //
  // 💡 Senza il secondo, il file non coprirebbe più il guasto per cui era nato.
  // Servono entrambi, e sono due righe nell'intestazione.

  /// 🚨 **Un solo messaggio** per «codice sbagliato», «password sbagliata» e
  /// «file rovinato».
  ///
  /// ⚠️ Distinguerli direbbe a chi prova quale delle due strade e la piu'
  /// promettente da forzare, e a chi ha sbagliato davvero non servirebbe a
  /// niente: le tre cose si correggono tutte allo stesso modo — riprovando con
  /// il segreto giusto o con un altro file.
  static const String _nonSiApre =
      'Non riesco ad aprire il file: controlla il codice o la password, '
      'oppure il file e rovinato.';

  static const int versione2 = 2;

  /// 💡 1 MB per blocco: abbastanza grande da non pagare l'intestazione di ogni
  /// blocco, abbastanza piccolo da non tenere mai molto in memoria.
  static const int _byteDelBlocco = 1024 * 1024;

  /// Scrive un backup `v2`.
  ///
  /// [password] è quella di recupero: se manca, il file si potrà aprire **solo**
  /// col codice. ⚠️ Un backup automatico senza password è un backup che nessuno
  /// aprirà, e chi chiama deve saperlo.
  Future<Uint8List> esportaV2({
    required Uint8List chiaveMaestra,
    required Map<String, dynamic> archivio,
    required String codice,
    String? password,
    bool avvolgiConLaChiaveMaestra = false,
  }) async {
    /*
     * 🚨 La chiave del contenuto è **a caso e nuova ogni volta**.
     *
     * ⚠️ Derivarla dalla password vorrebbe dire che cambiando password tutti i
     * backup vecchi diventano illeggibili. Così invece cambia solo l'involucro,
     * e al backup successivo si riavvolge.
     */
    final chiaveContenuto = _sodium.crypto.secretStream.keygen();

    try {
      final corpo = utf8.encode(json.encode({
        'master_key': base64Encode(chiaveMaestra),
        'archivio': archivio,
      }));

      final saltCodice = _sodium.randombytes.buf(_sodium.crypto.pwhash.saltBytes);
      final involucri = <String, dynamic>{
        'salt_codice': base64Encode(saltCodice),
        'wrap_codice': _avvolgi(chiaveContenuto, codice, saltCodice),
      };

      /*
       * 🚨 **Il terzo involucro: la chiave maestra stessa** — N3.
       *
       * ⚠️ Serve al backup automatico, e senza non esisterebbe: un lavoro in
       * background non ha nessuno a cui chiedere la password di recupero, e
       * l'app non la conserva.
       *
       * 💡 **La catena regge lo stesso**: su un telefono nuovo si digita la
       * password, il server restituisce la chiave maestra (`ripristinaConPassword`),
       * e con quella si apre il file del cloud. Una porta in piu', non una
       * scorciatoia.
       *
       * ⚠️ Niente Argon2 qui: la chiave maestra ha gia' 256 bit di entropia
       * vera. Derivare da un segreto forte con un KDF lento e' tempo speso a
       * proteggersi da un attacco a dizionario che non ha nessun dizionario da
       * provare.
       */
      if (avvolgiConLaChiaveMaestra) {
        involucri['wrap_maestra'] =
            _avvolgiConChiave(chiaveContenuto, _daMaestra(chiaveMaestra));
      }

      if (password != null && password.isNotEmpty) {
        final saltPassword =
            _sodium.randombytes.buf(_sodium.crypto.pwhash.saltBytes);

        involucri['salt_password'] = base64Encode(saltPassword);
        involucri['wrap_password'] =
            _avvolgi(chiaveContenuto, password, saltPassword);
      }

      final intestazione = utf8.encode(json.encode({
        'format': 'training-companion-backup',
        'version': versione2,
        'kdf': 'argon2id13',
        'ops_limit': Cassaforte.opsPredefinito,
        'mem_limit': Cassaforte.memPredefinito,
        'chunk': _byteDelBlocco,
        ...involucri,
      }));

      final cifrato = await _sodium.crypto.secretStream
          .pushChunked(
            messageStream: Stream.value(corpo),
            key: chiaveContenuto,
            chunkSize: _byteDelBlocco,
          )
          .expand((b) => b)
          .toList();

      /*
       * 🚨 Il file è: 4 byte con la lunghezza dell'intestazione, poi
       * l'intestazione, poi i blocchi.
       *
       * ⚠️ Serve un separatore che non possa comparire dentro il JSON, e la
       * lunghezza in testa è l'unico che non può essere confuso con niente: un
       * delimitatore di testo sarebbe stato indovinabile e falsificabile.
       */
      final lunghezza = ByteData(4)..setUint32(0, intestazione.length);

      return Uint8List.fromList([
        ...lunghezza.buffer.asUint8List(),
        ...intestazione,
        ...cifrato,
      ]);
    } finally {
      chiaveContenuto.dispose();
    }
  }

  /// Riapre un backup `v2`, con la password **oppure** con il codice.
  ///
  /// 🚨 Si prova prima la password e poi il codice: chi ripristina da un backup
  /// automatico ha la password, e provare prima il codice gli farebbe pagare
  /// una derivazione Argon2 inutile — che su un telefono lento sono secondi.
  Future<ContenutoDelBackup> importaV2({
    required Uint8List file,
    String? codice,
    String? password,
  }) async {
    final intestazione = _intestazioneDi(file);

    return _leggiIlCorpo(
      file: file,
      intestazione: intestazione,
      chiaveContenuto: _scartaLInvolucro(
        intestazione: intestazione,
        codice: codice,
        password: password,
      ),
    );
  }

  /// L'intestazione in chiaro: 4 byte di lunghezza, poi il JSON.
  ///
  /// 🚨 Estratta perché la usano **due** strade — il codice/password e la
  /// chiave maestra. ⚠️ Duplicarla vorrebbe dire due letture dello stesso
  /// formato che un giorno divergono, e la seconda sbaglierebbe in silenzio.
  Map<String, dynamic> _intestazioneDi(Uint8List file) {
    if (file.length < 4) throw const CodiceDiRipristinoSbagliato(_nonSiApre);

    final lunghezza = ByteData.sublistView(file, 0, 4).getUint32(0);

    if (lunghezza <= 0 || 4 + lunghezza > file.length) {
      throw const CodiceDiRipristinoSbagliato(_nonSiApre);
    }

    try {
      return json.decode(utf8.decode(file.sublist(4, 4 + lunghezza)))
          as Map<String, dynamic>;
    } on Object {
      throw const CodiceDiRipristinoSbagliato(_nonSiApre);
    }
  }

  /// Decifra i blocchi e ne ricava il contenuto.
  ///
  /// ⚠️ Consuma [chiaveContenuto]: la libera in ogni caso, anche fallendo. Una
  /// chiave che resta in memoria dopo l'uso è esattamente ciò che `SecureKey`
  /// esiste per evitare.
  Future<ContenutoDelBackup> _leggiIlCorpo({
    required Uint8List file,
    required Map<String, dynamic> intestazione,
    required SecureKey chiaveContenuto,
  }) async {
    final lunghezza = ByteData.sublistView(file, 0, 4).getUint32(0);

    try {
      final blocchi = await _sodium.crypto.secretStream
          .pullChunked(
            cipherStream: Stream.value(file.sublist(4 + lunghezza)),
            key: chiaveContenuto,
            chunkSize:
                (intestazione['chunk'] as num?)?.toInt() ?? _byteDelBlocco,
          )
          .expand((b) => b)
          .toList();

      final corpo = json.decode(utf8.decode(blocchi)) as Map<String, dynamic>;

      return ContenutoDelBackup(
        chiaveMaestra: base64Decode(corpo['master_key'] as String),
        archivio: (corpo['archivio'] as Map?)?.cast<String, dynamic>() ?? {},
      );
    } on CodiceDiRipristinoSbagliato {
      rethrow;
    } on Object {
      // ⚠️ Un blocco che non si autentica vuol dire file rovinato **o**
      // manomesso: da fuori sono indistinguibili, e va detta la cosa vera.
      throw const CodiceDiRipristinoSbagliato(_nonSiApre);
    } finally {
      chiaveContenuto.dispose();
    }
  }

  /// Avvolge la chiave del contenuto con un segreto (password o codice).
  ///
  /// @return `{nonce, cifrato}` in base64.
  Map<String, String> _avvolgi(
    SecureKey chiaveContenuto,
    String segreto,
    Uint8List salt,
  ) {
    final chiave = _derivaDalCodice(codice: segreto, salt: salt);
    final nonce = _sodium.randombytes.buf(_sodium.crypto.secretBox.nonceBytes);

    try {
      final cifrato = _sodium.crypto.secretBox.easy(
        message: chiaveContenuto.extractBytes(),
        nonce: nonce,
        key: chiave,
      );

      return {'nonce': base64Encode(nonce), 'dato': base64Encode(cifrato)};
    } finally {
      chiave.dispose();
    }
  }

  /// Ricava la chiave del contenuto da uno dei due involucri.
  ///
  /// 🚨 **Un solo messaggio d'errore** per «codice sbagliato», «password
  /// sbagliata» e «file rovinato»: distinguerli direbbe a chi prova quale delle
  /// due strade è quella giusta da forzare.
  SecureKey _scartaLInvolucro({
    required Map<String, dynamic> intestazione,
    String? codice,
    String? password,
  }) {
    // 💡 Prima la password: chi ripristina da un backup automatico ce l'ha, e
    // provare prima il codice gli costerebbe un Argon2 per niente.
    final tentativi = <(String?, String, String)>[
      (password, 'salt_password', 'wrap_password'),
      (codice, 'salt_codice', 'wrap_codice'),
    ];

    for (final (segreto, campoSalt, campoWrap) in tentativi) {
      if (segreto == null || segreto.isEmpty) continue;

      final salt = intestazione[campoSalt];
      final wrap = intestazione[campoWrap];

      if (salt is! String || wrap is! Map) continue;

      final derivata = _derivaDalCodice(
        codice: segreto,
        salt: base64Decode(salt),
      );

      try {
        final byte = _sodium.crypto.secretBox.openEasy(
          cipherText: base64Decode(wrap['dato'] as String),
          nonce: base64Decode(wrap['nonce'] as String),
          key: derivata,
        );

        return SecureKey.fromList(_sodium, byte);
      } on Object {
        // ⚠️ Si prova l'altro involucro: questo segreto non era il suo.
        continue;
      } finally {
        derivata.dispose();
      }
    }

    throw const CodiceDiRipristinoSbagliato(_nonSiApre);
  }

  /// 🚨 Legge un backup di **qualunque** versione — N1.4.
  ///
  /// ⚠️ Chi ha esportato un file con la versione di stamattina deve poterlo
  /// usare domani. Questa è l'unica regola non negoziabile del formato, e vive
  /// qui: si guarda `version` e si smista.
  ///
  /// 💡 Il `v1` non ha un'intestazione a lunghezza: è un JSON puro. Si
  /// riconosce dal primo byte — `{` — che nel `v2` è impossibile, perché lì i
  /// primi quattro byte sono una lunghezza binaria.
  Future<ContenutoDelBackup> importaQualsiasi({
    required Uint8List file,
    String? codice,
    String? password,
  }) async {
    final eV1 = file.isNotEmpty && file.first == 0x7B; // '{'

    if (eV1) {
      if (codice == null || codice.isEmpty) {
        throw const CodiceDiRipristinoSbagliato(_nonSiApre);
      }

      return importa(file: file, codice: codice);
    }

    return importaV2(file: file, codice: codice, password: password);
  }

  /// La chiave con cui si avvolge usando la **chiave maestra** — N3.
  ///
  /// 🚨 Non è la chiave maestra nuda: è una sua derivazione con un'etichetta.
  ///
  /// ⚠️ Riusare la stessa chiave per due scopi diversi — cifrare i messaggi e
  /// avvolgere i backup — è il modo classico in cui una debolezza in uno dei due
  /// usi diventa una debolezza nell'altro. La derivazione con etichetta separa
  /// i domini, e costa un hash.
  SecureKey _daMaestra(Uint8List chiaveMaestra) => SecureKey.fromList(
    _sodium,
    _sodium.crypto.genericHash(
      message: Uint8List.fromList(utf8.encode('training-companion/backup-wrap')),
      key: SecureKey.fromList(_sodium, chiaveMaestra),
      outLen: _sodium.crypto.secretBox.keyBytes,
    ),
  );

  /// Avvolge con una chiave già pronta, senza passare da un KDF.
  ///
  /// 💡 Distinto da `_avvolgi`, che parte da un segreto **debole** (una
  /// password, un codice) e deve rinforzarlo con Argon2. Qui il segreto è già
  /// forte: un KDF lento non aggiungerebbe niente e costerebbe secondi a ogni
  /// backup automatico.
  Map<String, String> _avvolgiConChiave(
    SecureKey chiaveContenuto,
    SecureKey chiave,
  ) {
    final nonce = _sodium.randombytes.buf(_sodium.crypto.secretBox.nonceBytes);

    try {
      final cifrato = _sodium.crypto.secretBox.easy(
        message: chiaveContenuto.extractBytes(),
        nonce: nonce,
        key: chiave,
      );

      return {'nonce': base64Encode(nonce), 'dato': base64Encode(cifrato)};
    } finally {
      chiave.dispose();
    }
  }

  /// Riapre un backup del cloud con la **chiave maestra** — N3.
  ///
  /// 🚨 È la strada del telefono nuovo: si digita la password di recupero, il
  /// server restituisce la chiave maestra, e con quella si apre questo file.
  Future<ContenutoDelBackup> importaConChiaveMaestra({
    required Uint8List file,
    required Uint8List chiaveMaestra,
  }) async {
    final intestazione = _intestazioneDi(file);
    final wrap = intestazione['wrap_maestra'];

    if (wrap is! Map) {
      throw const CodiceDiRipristinoSbagliato(
        'Questo backup non si apre con la chiave dell\'account: serve il codice.',
      );
    }

    final derivata = _daMaestra(chiaveMaestra);
    final SecureKey chiaveContenuto;

    try {
      chiaveContenuto = SecureKey.fromList(
        _sodium,
        _sodium.crypto.secretBox.openEasy(
          cipherText: base64Decode(wrap['dato'] as String),
          nonce: base64Decode(wrap['nonce'] as String),
          key: derivata,
        ),
      );
    } on Object {
      throw const CodiceDiRipristinoSbagliato(_nonSiApre);
    } finally {
      derivata.dispose();
    }

    return _leggiIlCorpo(
      file: file,
      intestazione: intestazione,
      chiaveContenuto: chiaveContenuto,
    );
  }

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
