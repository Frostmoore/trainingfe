import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

/// La cassaforte: la chiave maestra dell'account e il suo incarto — S6.
///
/// ── Perché esiste ──────────────────────────────────────────────────────────
///
/// 🚨 Oggi *«le palestre non leggono le chat dei loro trainer»* è garantito da
/// policy e gate, cioè da **codice che può avere un bug**. Dopo questa fase è
/// impossibile per costruzione: il server instrada byte che non sa leggere.
///
/// ── Lo schema ──────────────────────────────────────────────────────────────
///
/// ```
/// password di recupero ──Argon2id──► chiave di incarto
///                                          │
///                                          ▼
///                                 [ chiave maestra ]  ← casuale, una volta sola
///                                          │
///                         ┌────────────────┴────────────────┐
///                         ▼                                 ▼
///               identità X25519 della chat            chiave dei backup
/// ```
///
/// 🚨 **La chiave maestra è INCARTATA dalla password, non derivata da essa.**
/// È l'unica differenza che rende possibile *«può cambiarla quando vuole»*:
/// cambiare la password re-incarta **solo la chiave maestra**, poche decine di
/// byte. Se fosse derivata, cambiare la password vorrebbe dire **ricifrare ogni
/// messaggio e ogni backup mai fatti** — cioè non poterla cambiare affatto.
///
/// 🚨 **La derivazione avviene qui, sul telefono.** Il server riceve solo il
/// pacchetto già chiuso. Se la password di recupero toccasse il server anche per
/// un istante, tutto questo non servirebbe a niente.
class Cassaforte {
  Cassaforte(this._sodium);

  final SodiumSumo _sodium;

  /// La versione dello schema che scriviamo oggi.
  ///
  /// ⚠️ Sta **dentro ogni pacchetto e ogni busta**, e non è burocrazia: il
  /// giorno in cui il cifrario cambia, i dati vecchi vanno ancora letti. Senza
  /// un numero scritto accanto ai byte, l'unico modo per capire come sono stati
  /// prodotti è indovinare.
  static const int versione = 1;

  /// Argon2id, `opslimit` — il numero di passate.
  static const int opsPredefinito = 3;

  /// Argon2id, `memlimit` — 64 MiB.
  ///
  /// 🚨 **Non è il preset `moderate` di libsodium (256 MiB), ed è una scelta.**
  /// Un Android di fascia bassa con 2 GB di RAM va in *out of memory* e l'app
  /// non parte affatto: un'app che non si apre è un guasto peggiore di un KDF
  /// un po' più leggero. 64 MiB con 3 passate sta **sopra** il preset
  /// `interactive` (64 MiB, 2 passate) e resta dentro ciò che un telefono
  /// qualsiasi regge.
  ///
  /// ⚠️ I parametri viaggiano **dentro il pacchetto**: alzarli domani non rompe
  /// i pacchetti prodotti oggi, che continuano a dichiarare i propri.
  static const int memPredefinito = 64 * 1024 * 1024;

  /// I contesti di `crypto_kdf`: **8 caratteri esatti**, lo impone libsodium.
  ///
  /// Servono a garantire che due sottochiavi della stessa maestra non coincidano
  /// mai: la chiave della chat e quella dei backup partono dallo stesso segreto
  /// e devono restare **scorrelate**, o compromettere l'una direbbe qualcosa
  /// sull'altra.
  static const String contestoChat = 'tcaichat';
  static const String contestoBackup = 'tcaibkup';

  /// La chiave maestra: 32 byte casuali, generati **una volta nella vita
  /// dell'account**.
  ///
  /// Non deriva da niente — né dalla password, né dall'email, né dall'id utente.
  /// È il solo segreto che, perso, perde tutto: ogni altra chiave si ricalcola
  /// da questa.
  SecureKey generaChiaveMaestra() => _sodium.crypto.kdf.keygen();

  /// Chiude la chiave maestra dentro un pacchetto che solo la password apre.
  ///
  /// 🚨 Il `salt` è **nuovo a ogni incarto**, anche quando la password non
  /// cambia. Riusarlo permetterebbe di riconoscere due account con la stessa
  /// password guardando i pacchetti, e renderebbe utile una tabella precalcolata
  /// contro tutti gli utenti insieme invece che contro uno solo.
  PacchettoIncartato incarta({
    required SecureKey chiaveMaestra,
    required String password,
    int opsLimit = opsPredefinito,
    int memLimit = memPredefinito,
  }) {
    final salt = _sodium.randombytes.buf(_sodium.crypto.pwhash.saltBytes);
    final nonce = _sodium.randombytes.buf(_sodium.crypto.secretBox.nonceBytes);

    final chiaveDiIncarto = _derivaDallaPassword(
      password: password,
      salt: salt,
      opsLimit: opsLimit,
      memLimit: memLimit,
    );

    try {
      final cifrato = _sodium.crypto.secretBox.easy(
        message: chiaveMaestra.extractBytes(),
        nonce: nonce,
        key: chiaveDiIncarto,
      );

      return PacchettoIncartato(
        versione: versione,
        salt: salt,
        nonce: nonce,
        cifrato: cifrato,
        opsLimit: opsLimit,
        memLimit: memLimit,
      );
    } finally {
      // La chiave di incarto non serve oltre: si ricalcola dalla password ogni
      // volta che serve, e tenerla in memoria è solo superficie in più.
      chiaveDiIncarto.dispose();
    }
  }

  /// Riapre il pacchetto. Lancia [PasswordDiRecuperoSbagliata] se non è quella.
  ///
  /// ⚠️ **Non c'è modo di distinguere «password sbagliata» da «pacchetto
  /// corrotto»**, ed è corretto così: il MAC di `secretbox` fallisce
  /// identicamente nei due casi. All'utente si dice la cosa vera e utile —
  /// *«questa password non apre il tuo account»*.
  SecureKey scarta({
    required PacchettoIncartato pacchetto,
    required String password,
  }) {
    final chiaveDiIncarto = _derivaDallaPassword(
      password: password,
      salt: pacchetto.salt,
      opsLimit: pacchetto.opsLimit,
      memLimit: pacchetto.memLimit,
    );

    try {
      final byte = _sodium.crypto.secretBox.openEasy(
        cipherText: pacchetto.cifrato,
        nonce: pacchetto.nonce,
        key: chiaveDiIncarto,
      );

      return SecureKey.fromList(_sodium, byte);
    } on SodiumException {
      throw const PasswordDiRecuperoSbagliata();
    } finally {
      chiaveDiIncarto.dispose();
    }
  }

  /// L'identità X25519 della chat, **derivata** dalla chiave maestra.
  ///
  /// 💡 Deterministica di proposito: stessa chiave maestra, stessa identità, su
  /// qualunque telefono e senza portarsi dietro un secondo segreto. È il motivo
  /// per cui il ripristino non deve trasferire nessuna chiave privata — basta
  /// la maestra e tutto il resto si ricalcola.
  ///
  /// ⚠️ **Chi perde la chiave maestra perde anche l'identità**, quindi i
  /// messaggi vecchi: sono cifrati verso una chiave pubblica che non tornerà.
  /// È la definizione di end-to-end, e va detto all'utente quando crea la
  /// password, non in un sottomenu.
  KeyPair identitaChat(SecureKey chiaveMaestra) {
    final seme = _sodium.crypto.kdf.deriveFromKey(
      masterKey: chiaveMaestra,
      context: contestoChat,
      subkeyId: BigInt.one,
      subkeyLen: _sodium.crypto.box.seedBytes,
    );

    try {
      return _sodium.crypto.box.seedKeyPair(seme);
    } finally {
      seme.dispose();
    }
  }

  /// La chiave con cui si cifra il file di backup esportabile (S6.6).
  ///
  /// Sottochiave distinta da quella della chat: un file di backup che finisse
  /// nelle mani sbagliate non deve dire **niente** sulle conversazioni.
  SecureKey chiaveBackup(SecureKey chiaveMaestra) =>
      _sodium.crypto.kdf.deriveFromKey(
        masterKey: chiaveMaestra,
        context: contestoBackup,
        subkeyId: BigInt.one,
        subkeyLen: _sodium.crypto.secretBox.keyBytes,
      );

  SecureKey _derivaDallaPassword({
    required String password,
    required Uint8List salt,
    required int opsLimit,
    required int memLimit,
  }) => _sodium.crypto.pwhash(
    outLen: _sodium.crypto.secretBox.keyBytes,
    password: password.toCharArray(),
    salt: salt,
    opsLimit: opsLimit,
    memLimit: memLimit,
    // Argon2id e non Argon2i: resiste sia agli attacchi con hardware
    // dedicato sia a quelli che sfruttano i tempi di accesso alla memoria.
    // È la scelta predefinita di libsodium da 1.0.13 e non c'è motivo di
    // discostarsene.
    alg: CryptoPwhashAlgorithm.argon2id13,
  );
}

/// Il pacchetto incartato — **quello che sta sul nostro server**.
///
/// 🚨 Che stia da noi è il motivo per cui il KDF non è un parametro da lasciare
/// al default: se il database uscisse, un attaccante potrebbe provare le
/// password **offline**, senza il limite di tentativi che protegge un login.
/// Il costo di Argon2id è l'unica difesa che resta in quello scenario.
class PacchettoIncartato {
  const PacchettoIncartato({
    required this.versione,
    required this.salt,
    required this.nonce,
    required this.cifrato,
    required this.opsLimit,
    required this.memLimit,
  });

  final int versione;
  final Uint8List salt;
  final Uint8List nonce;
  final Uint8List cifrato;
  final int opsLimit;
  final int memLimit;

  /// I parametri viaggiano **insieme** al pacchetto, non nel codice.
  ///
  /// ⚠️ Se stessero solo qui dentro come costanti, alzare il costo del KDF
  /// domani renderebbe illeggibili tutti i pacchetti di ieri — e nessuno se ne
  /// accorgerebbe fino al primo utente che prova a recuperare l'account.
  Map<String, dynamic> toJson() => {
    'version': versione,
    'kdf': 'argon2id13',
    'ops_limit': opsLimit,
    'mem_limit': memLimit,
    'salt': base64Encode(salt),
    'nonce': base64Encode(nonce),
    'wrapped_key': base64Encode(cifrato),
  };

  factory PacchettoIncartato.fromJson(Map<String, dynamic> json) =>
      PacchettoIncartato(
        versione: json['version'] as int,
        salt: base64Decode(json['salt'] as String),
        nonce: base64Decode(json['nonce'] as String),
        cifrato: base64Decode(json['wrapped_key'] as String),
        opsLimit: json['ops_limit'] as int,
        memLimit: json['mem_limit'] as int,
      );
}

/// La password non apre il pacchetto.
class PasswordDiRecuperoSbagliata implements Exception {
  const PasswordDiRecuperoSbagliata();

  @override
  String toString() => 'Questa password non apre il tuo account.';
}
