import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:training_companion/src/core/crypto/busta_messaggio.dart';
import 'package:training_companion/src/core/crypto/cassaforte.dart';

import '../aiuto/libsodium.dart';

/// S6 — la cifratura della chat.
///
/// 🎯 **Quello che questi test dimostrano è la prima regola non negoziabile del
/// progetto**: che una palestra non possa leggere le conversazioni fra i suoi
/// trainer e i suoi iscritti. Finora era garantito da policy e gate; qui
/// diventa una proprietà dei byte.
void main() {
  late SodiumSumo sodium;
  late Cassaforte cassaforte;
  late CifraturaChat cifratura;

  late KeyPair trainer;
  late KeyPair iscritto;

  setUpAll(() async {
    sodium = await libsodiumPerTest();
    cassaforte = Cassaforte(sodium);
    cifratura = CifraturaChat(sodium);
  });

  setUp(() {
    trainer = cassaforte.identitaChat(cassaforte.generaChiaveMaestra());
    iscritto = cassaforte.identitaChat(cassaforte.generaChiaveMaestra());
  });

  test('chi riceve legge quello che e stato scritto', () {
    final busta = cifratura.cifra(
      testo: 'Domani panca piana, 4 serie da 8.',
      mieSegrete: trainer.secretKey,
      suaPubblica: iscritto.publicKey,
    );

    final letto = cifratura.decifra(
      busta: busta,
      mieSegrete: iscritto.secretKey,
      suaPubblica: trainer.publicKey,
    );

    expect(letto, 'Domani panca piana, 4 serie da 8.');
  });

  /// 🎯 **Il motivo per cui il cifrario è `crypto_box` e non una busta anonima.**
  ///
  /// Il segreto condiviso è lo stesso calcolato da una parte o dall'altra:
  /// quindi chi scrive rilegge il proprio messaggio **dallo stesso identico
  /// testo cifrato**. Senza questa proprietà il server dovrebbe conservare una
  /// seconda copia cifrata per il mittente — il doppio dello spazio, il doppio
  /// dei modi di sbagliare, e una copia in più da tenere allineata a ogni
  /// cambio di chiave.
  test('chi scrive rilegge se stesso dallo stesso testo cifrato', () {
    final busta = cifratura.cifra(
      testo: 'Come e andata la seduta?',
      mieSegrete: trainer.secretKey,
      suaPubblica: iscritto.publicKey,
    );

    final riletto = cifratura.decifra(
      busta: busta,
      mieSegrete: trainer.secretKey,
      suaPubblica: iscritto.publicKey,
    );

    expect(riletto, 'Come e andata la seduta?');
  });

  /// 🚨 La regola non negoziabile, messa alla prova.
  ///
  /// Il titolare della palestra — o chiunque abbia accesso al database — ha
  /// tutto tranne le due chiavi private. E con tutto il resto non ottiene
  /// niente.
  test('la palestra ha il database e non legge un accidente', () {
    final palestra = cassaforte.identitaChat(cassaforte.generaChiaveMaestra());

    final busta = cifratura.cifra(
      testo: 'Ho di nuovo male alla spalla destra.',
      mieSegrete: iscritto.secretKey,
      suaPubblica: trainer.publicKey,
    );

    // Quello che il server conserva davvero, per intero.
    final riga = busta.perApi();

    expect(riga['body'], isNot(contains('spalla')));
    expect(utf8.decode(base64Decode(riga['body'] as String), allowMalformed: true),
        isNot(contains('spalla')));

    expect(
      () => cifratura.decifra(
        busta: BustaMessaggio.daApi(riga),
        mieSegrete: palestra.secretKey,
        suaPubblica: trainer.publicKey,
      ),
      throwsA(isA<BustaIllegibile>()),
    );
  });

  test('lo stesso testo cifrato due volte non produce gli stessi byte', () {
    Uint8List cifra() => cifratura
        .cifra(
          testo: 'ok',
          mieSegrete: trainer.secretKey,
          suaPubblica: iscritto.publicKey,
        )
        .cifrato;

    expect(cifra(), isNot(equals(cifra())));
  });

  /// ⚠️ `crypto_box` **autentica**, non solo cifra: il server può cancellare un
  /// messaggio o non consegnarlo, ma non può cambiarlo di una virgola né
  /// fabbricarne uno a nome del trainer.
  test('un byte cambiato fa fallire l apertura', () {
    final busta = cifratura.cifra(
      testo: 'Aumenta di 5 kg.',
      mieSegrete: trainer.secretKey,
      suaPubblica: iscritto.publicKey,
    );

    final manomesso = Uint8List.fromList(busta.cifrato);
    manomesso[0] = manomesso[0] ^ 0x01;

    expect(
      () => cifratura.decifra(
        busta: BustaMessaggio(
          versione: busta.versione,
          nonce: busta.nonce,
          cifrato: manomesso,
        ),
        mieSegrete: iscritto.secretKey,
        suaPubblica: trainer.publicKey,
      ),
      throwsA(isA<BustaIllegibile>()),
    );
  });

  test('una versione sconosciuta non si prova nemmeno ad aprire', () {
    final busta = cifratura.cifra(
      testo: 'ciao',
      mieSegrete: trainer.secretKey,
      suaPubblica: iscritto.publicKey,
    );

    expect(
      () => cifratura.decifra(
        busta: BustaMessaggio(
          versione: 99,
          nonce: busta.nonce,
          cifrato: busta.cifrato,
        ),
        mieSegrete: iscritto.secretKey,
        suaPubblica: trainer.publicKey,
      ),
      throwsA(isA<BustaIllegibile>()),
    );
  });

  test('la busta va e torna dall API senza perdere niente', () {
    final busta = cifratura.cifra(
      testo: 'Riposo attivo domani.',
      mieSegrete: trainer.secretKey,
      suaPubblica: iscritto.publicKey,
    );

    final tornata = BustaMessaggio.daApi(busta.perApi());

    expect(
      cifratura.decifra(
        busta: tornata,
        mieSegrete: iscritto.secretKey,
        suaPubblica: trainer.publicKey,
      ),
      'Riposo attivo domani.',
    );
  });

  group('l impronta di sicurezza', () {
    /// 🚨 Serve contro l'unico attacco che lo schema non ferma da solo: le
    /// chiavi pubbliche le distribuisce il **nostro** server, che potrebbe
    /// darne una propria a entrambi e mettersi in mezzo. I conti tornerebbero
    /// lo stesso — sarebbero solo le chiavi sbagliate.
    test('e la stessa dalle due parti, in qualunque ordine', () {
      final da = cifratura.improntaDiSicurezza(
        trainer.publicKey,
        iscritto.publicKey,
      );
      final versoDi = cifratura.improntaDiSicurezza(
        iscritto.publicKey,
        trainer.publicKey,
      );

      expect(da, equals(versoDi));
    });

    test('cambia se una delle due chiavi non e quella vera', () {
      final vera = cifratura.improntaDiSicurezza(
        trainer.publicKey,
        iscritto.publicKey,
      );

      final intruso = cassaforte.identitaChat(cassaforte.generaChiaveMaestra());
      final falsa = cifratura.improntaDiSicurezza(
        trainer.publicKey,
        intruso.publicKey,
      );

      expect(falsa, isNot(equals(vera)));
    });

    test('si legge a voce: cinque gruppi da cinque cifre', () {
      final impronta = cifratura.improntaDiSicurezza(
        trainer.publicKey,
        iscritto.publicKey,
      );

      final gruppi = impronta.split(' ');
      expect(gruppi, hasLength(5));
      expect(gruppi.every((g) => g.length == 5), isTrue);
      expect(RegExp(r'^[0-9 ]+$').hasMatch(impronta), isTrue);
    });
  });
}
