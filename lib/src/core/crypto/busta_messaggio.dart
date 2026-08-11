import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

/// La cifratura dei messaggi di chat — S6.5.
///
/// ── La scelta del cifrario ─────────────────────────────────────────────────
///
/// `crypto_box_easy`: X25519 per accordarsi su un segreto, XSalsa20-Poly1305
/// per cifrare e autenticare.
///
/// 🎯 **Un solo testo cifrato serve entrambe le parti.** Il segreto condiviso
/// che nasce da (mia chiave privata, sua chiave pubblica) è **identico** a
/// quello che nasce da (sua privata, mia pubblica). Quindi chi scrive rilegge i
/// propri messaggi senza che il server debba conservarne una seconda copia
/// cifrata per lui — che è la complicazione in cui finiscono quasi tutte le
/// implementazioni ingenue.
///
/// 🚨 **Perché non `crypto_box_seal`** (la busta anonima): non autentica il
/// mittente. Chiunque possa scrivere sulla tabella `messages` — cioè il nostro
/// server — potrebbe fabbricare un messaggio **a nome del trainer**. Con
/// `crypto_box_easy` il MAC dipende dalla chiave privata di chi scrive: il
/// server può cancellare o non consegnare, ma non può **inventare**.
///
/// ⚠️ Quello che questo schema **non** dà è la *forward secrecy*: chi ottenesse
/// oggi la chiave maestra leggerebbe anche i messaggi vecchi. Il Double Ratchet
/// di Signal esiste per questo, ma richiede stato per conversazione e sincronia
/// fra dispositivi — e va in rotta di collisione con il requisito del
/// committente, che è **potersi ripristinare da zero con una password**. Fra le
/// due si è scelta la seconda, consapevolmente.
class CifraturaChat {
  CifraturaChat(this._sodium);

  final SodiumSumo _sodium;

  static const int versione = 1;

  /// Cifra il testo verso l'altra parte.
  ///
  /// Il `nonce` è casuale a ogni messaggio: 24 byte sono abbastanza perché
  /// l'estrazione a caso non collida mai in pratica, e evitano di dover tenere
  /// un contatore sincronizzato fra i due telefoni.
  BustaMessaggio cifra({
    required String testo,
    required SecureKey mieSegrete,
    required Uint8List suaPubblica,
  }) {
    final nonce = _sodium.randombytes.buf(_sodium.crypto.box.nonceBytes);

    final cifrato = _sodium.crypto.box.easy(
      message: Uint8List.fromList(utf8.encode(testo)),
      nonce: nonce,
      publicKey: suaPubblica,
      secretKey: mieSegrete,
    );

    return BustaMessaggio(
      versione: versione,
      nonce: nonce,
      cifrato: cifrato,
    );
  }

  /// Riapre la busta. Lancia [BustaIllegibile] se il MAC non torna.
  ///
  /// ⚠️ Il MAC che non torna **non è sempre un attacco**: il caso di gran lunga
  /// più comune è un messaggio scritto verso una chiave che non c'è più, perché
  /// l'altra persona ha perso la chiave maestra e ne ha generata una nuova.
  /// L'app deve dirlo così — *«questo messaggio non è più leggibile»* — e non
  /// gridare alla manomissione.
  String decifra({
    required BustaMessaggio busta,
    required SecureKey mieSegrete,
    required Uint8List suaPubblica,
  }) {
    if (busta.versione != versione) {
      throw BustaIllegibile('Versione ${busta.versione} non conosciuta.');
    }

    try {
      final chiaro = _sodium.crypto.box.openEasy(
        cipherText: busta.cifrato,
        nonce: busta.nonce,
        publicKey: suaPubblica,
        secretKey: mieSegrete,
      );

      return utf8.decode(chiaro);
    } on SodiumException {
      throw const BustaIllegibile('Il messaggio non si apre con questa chiave.');
    }
  }

  /// L'impronta di sicurezza della coppia — da confrontare a voce.
  ///
  /// 🚨 **Serve contro l'unico attacco che questo schema non impedisce da solo.**
  /// Le chiavi pubbliche le distribuisce il nostro server: un server malevolo
  /// potrebbe darne una propria a entrambi e mettersi in mezzo. La crittografia
  /// non se ne accorgerebbe — i conti tornano, sono solo le chiavi sbagliate.
  ///
  /// 💡 L'impronta è la stessa da entrambe le parti **solo se le chiavi sono
  /// davvero quelle**: leggersela a voce in palestra costa dieci secondi e
  /// chiude il buco. Le chiavi si ordinano prima di digerirle, altrimenti i due
  /// telefoni calcolerebbero due numeri diversi.
  String improntaDiSicurezza(Uint8List una, Uint8List altra) {
    final ordinate = _ordina(una, altra);

    final digerito = _sodium.crypto.genericHash(
      message: Uint8List.fromList([...ordinate.$1, ...ordinate.$2]),
      outLen: 30,
    );

    // Cinque gruppi di cinque cifre: si leggono a voce senza perdere il segno,
    // ed è la stessa forma che usano Signal e WhatsApp per lo stesso motivo.
    final cifre = digerito
        .map((b) => b.toRadixString(10).padLeft(3, '0'))
        .join();

    final gruppi = <String>[];
    for (var i = 0; i + 5 <= cifre.length && gruppi.length < 5; i += 5) {
      gruppi.add(cifre.substring(i, i + 5));
    }

    return gruppi.join(' ');
  }

  (Uint8List, Uint8List) _ordina(Uint8List a, Uint8List b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) {
        return a[i] < b[i] ? (a, b) : (b, a);
      }
    }

    return (a, b);
  }
}

/// La busta che viaggia: il server la conserva e non la capisce.
class BustaMessaggio {
  const BustaMessaggio({
    required this.versione,
    required this.nonce,
    required this.cifrato,
  });

  final int versione;
  final Uint8List nonce;
  final Uint8List cifrato;

  /// Come arriva e riparte dall'API.
  ///
  /// `body` resta il nome della colonna che c'era già, ma non contiene più
  /// testo: contiene base64 di byte cifrati. ⚠️ Chi legge il database non deve
  /// poter confondere le due cose — è per questo che accanto c'è sempre
  /// `envelope_version`, che nei messaggi in chiaro non esisteva.
  factory BustaMessaggio.daApi(Map<String, dynamic> json) => BustaMessaggio(
        versione: json['envelope_version'] as int,
        nonce: base64Decode(json['nonce'] as String),
        cifrato: base64Decode(json['body'] as String),
      );

  Map<String, dynamic> perApi() => {
        'envelope_version': versione,
        'nonce': base64Encode(nonce),
        'body': base64Encode(cifrato),
      };
}

/// La busta non si apre.
class BustaIllegibile implements Exception {
  const BustaIllegibile(this.motivo);

  final String motivo;

  @override
  String toString() => motivo;
}
