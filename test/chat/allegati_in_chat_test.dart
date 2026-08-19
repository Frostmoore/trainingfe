import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/crypto/cifratura_allegati.dart';
import 'package:training_companion/src/core/crypto/contenuto_messaggio.dart';

import '../aiuto/libsodium.dart';

/// Le foto in chat — N13.
///
/// 🚨 **Quello che questi test difendono** è che i due pezzi restino separati:
/// i byte cifrati vanno su una strada, la chiave sull'altra, e il server non
/// tiene nessuno dei due in chiaro.
void main() {
  late CifraturaAllegati cripto;

  setUpAll(() async => cripto = CifraturaAllegati(await libsodiumPerTest()));

  Uint8List foto(int quanti) =>
      Uint8List.fromList(List.generate(quanti, (i) => (i * 7) % 256));

  group('la cifratura', () {
    test('il giro completo torna gli stessi byte', () async {
      final chiara = foto(5000);
      final chiave = cripto.generaChiave();
      addTearDown(chiave.dispose);

      final cifrata = await cripto.cifra(chiave: chiave, contenuto: chiara);

      expect(cifrata, isNot(equals(chiara)));
      expect(
        await cripto.decifra(chiave: chiave, contenuto: cifrata),
        chiara,
      );
    });

    test('🚨 ogni foto ha una chiave DIVERSA', () async {
      /*
       * ⚠️ È la differenza con il backup, dove la chiave è derivata da quella
       * maestra. Qui la chiave va **consegnata all'altra persona**: se fosse
       * sempre la stessa, consegnarne una vorrebbe dire consegnare ogni foto
       * mai cifrata con essa. Una chiave per foto limita il danno a quella.
       */
      final a = cripto.generaChiave();
      final b = cripto.generaChiave();
      addTearDown(a.dispose);
      addTearDown(b.dispose);

      expect(cripto.byteDi(a), isNot(equals(cripto.byteDi(b))));
    });

    test('la chiave sbagliata non apre niente', () async {
      final chiave = cripto.generaChiave();
      final altra = cripto.generaChiave();
      addTearDown(chiave.dispose);
      addTearDown(altra.dispose);

      final cifrata = await cripto.cifra(chiave: chiave, contenuto: foto(500));

      await expectLater(
        cripto.decifra(chiave: altra, contenuto: cifrata),
        throwsA(isA<AllegatoNonSiApre>()),
      );
    });

    test('byte rovinati si fanno riconoscere', () async {
      final chiave = cripto.generaChiave();
      addTearDown(chiave.dispose);

      await expectLater(
        cripto.decifra(
          chiave: chiave,
          contenuto: Uint8List.fromList(List.filled(300, 0)),
        ),
        throwsA(isA<AllegatoNonSiApre>()),
      );
    });

    test('la chiave sopravvive al giro per base64', () async {
      // 💡 È il viaggio vero: la chiave entra nel messaggio come testo.
      final chiara = foto(800);
      final chiave = cripto.generaChiave();
      addTearDown(chiave.dispose);

      final cifrata = await cripto.cifra(chiave: chiave, contenuto: chiara);
      final scritta = base64Encode(cripto.byteDi(chiave));

      final riletta = cripto.chiaveDa(base64Decode(scritta));
      addTearDown(riletta.dispose);

      expect(
        await cripto.decifra(chiave: riletta, contenuto: cifrata),
        chiara,
      );
    });
  });

  group('la busta', () {
    test('porta il riferimento e la chiave, non i byte', () {
      const busta = ContenutoFoto(
        token: 'abc123',
        chiaveBase64: 'a2lhdmU=',
        byteTotali: 4321,
      );

      final scritta = busta.perLaBusta();
      final dentro = json.decode(scritta) as Map<String, dynamic>;

      expect(dentro['t'], 'photo');
      expect((dentro['data'] as Map)['token'], 'abc123');

      /*
       * 🚨 L'asserzione che conta: nella busta **non ci sono i byte**. Una
       * conversazione si carica tutta insieme, e con le foto dentro aprirla
       * vorrebbe dire scaricare megabyte ogni volta, anche solo per rileggere
       * una riga di testo.
       */
      expect(scritta.length, lessThan(200));
    });

    test('si rilegge da sola', () {
      const originale = ContenutoFoto(
        token: 'tok',
        chiaveBase64: 'a2s=',
        byteTotali: 10,
      );

      final riletta = ContenutoMessaggio.daChiaro(originale.perLaBusta());

      expect(riletta, isA<ContenutoFoto>());
      expect((riletta as ContenutoFoto).token, 'tok');
      expect(riletta.chiaveBase64, 'a2s=');
      expect(riletta.byteTotali, 10);
    });

    test('⚠️ una busta a metà si dichiara incompleta invece di provarci', () {
      expect(
        const ContenutoFoto(token: '', chiaveBase64: 'a2s=').completa,
        isFalse,
      );
      expect(
        const ContenutoFoto(token: 'tok', chiaveBase64: '').completa,
        isFalse,
      );
      expect(
        const ContenutoFoto(token: 'tok', chiaveBase64: 'a2s=').completa,
        isTrue,
      );
    });

    test('una busta malformata non fa esplodere il filo', () {
      // 🚨 La promessa di `ContenutoMessaggio`: non lancia mai. Una singola
      // busta illeggibile è un caso normale; una schermata che esplode no.
      final letta = ContenutoMessaggio.daChiaro(
        json.encode({'t': 'photo', 'v': 2}),
      );

      expect(letta, isA<ContenutoSconosciuto>());
    });

    test('senza dimensione la busta resta valida', () {
      const senza = ContenutoFoto(token: 'tok', chiaveBase64: 'a2s=');

      final riletta =
          ContenutoMessaggio.daChiaro(senza.perLaBusta()) as ContenutoFoto;

      expect(riletta.byteTotali, isNull);
      expect(riletta.completa, isTrue);
    });
  });
}
