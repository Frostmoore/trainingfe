import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:training_companion/src/core/crypto/cassaforte.dart';

import '../aiuto/libsodium.dart';

/// S6 — la chiave maestra e il suo incarto.
///
/// 🚨 **Questi test sono l'unico posto in cui un errore di crittografia si
/// vede.** Un messaggio cifrato male sembra esattamente come uno cifrato bene:
/// non c'è schermata storta, non c'è eccezione, non c'è utente che si lamenta.
/// Se questi test non ci fossero, l'unica prova che il sistema funziona sarebbe
/// che *sembra* funzionare.
void main() {
  late SodiumSumo sodium;
  late Cassaforte cassaforte;

  // ⚠️ Parametri **volutamente ridicoli** per i test: Argon2id con i valori veri
  // (64 MiB, 3 passate) costa quasi mezzo secondo a chiamata, e questi test lo
  // chiamano decine di volte. I valori veri sono provati una volta sola, in
  // fondo al file, che è dove serve.
  const opsVeloce = 1;
  const memVeloce = 8192;

  setUpAll(() async {
    sodium = await libsodiumPerTest();
    cassaforte = Cassaforte(sodium);
  });

  group('incarto e riapertura', () {
    test('la chiave maestra torna identica dopo il giro', () {
      final maestra = cassaforte.generaChiaveMaestra();

      final pacchetto = cassaforte.incarta(
        chiaveMaestra: maestra,
        password: 'cavallo-batteria-graffetta',
        opsLimit: opsVeloce,
        memLimit: memVeloce,
      );

      final riaperta = cassaforte.scarta(
        pacchetto: pacchetto,
        password: 'cavallo-batteria-graffetta',
      );

      expect(riaperta.extractBytes(), equals(maestra.extractBytes()));
    });

    test('una password sbagliata non apre niente', () {
      final pacchetto = cassaforte.incarta(
        chiaveMaestra: cassaforte.generaChiaveMaestra(),
        password: 'quella-giusta',
        opsLimit: opsVeloce,
        memLimit: memVeloce,
      );

      expect(
        () => cassaforte.scarta(pacchetto: pacchetto, password: 'quella-quasi'),
        throwsA(isA<PasswordDiRecuperoSbagliata>()),
      );
    });

    /// 🚨 Il salt nuovo a ogni incarto non è pignoleria.
    ///
    /// Con un salt fisso, due pacchetti identici direbbero a chi guarda il
    /// database che due persone hanno scelto **la stessa password** — e
    /// renderebbero conveniente attaccare tutti gli utenti in una volta invece
    /// che uno per uno.
    test('due incarti della stessa chiave non si somigliano', () {
      final maestra = cassaforte.generaChiaveMaestra();

      final primo = cassaforte.incarta(
        chiaveMaestra: maestra,
        password: 'stessa',
        opsLimit: opsVeloce,
        memLimit: memVeloce,
      );
      final secondo = cassaforte.incarta(
        chiaveMaestra: maestra,
        password: 'stessa',
        opsLimit: opsVeloce,
        memLimit: memVeloce,
      );

      expect(primo.salt, isNot(equals(secondo.salt)));
      expect(primo.cifrato, isNot(equals(secondo.cifrato)));
    });
  });

  /// 🚨 **Il test che presidia la decisione S6.1.**
  ///
  /// Cambiare la password di recupero deve re-incartare **solo la chiave
  /// maestra**, lasciandola la stessa. Se qualcuno un giorno "semplificasse"
  /// derivando la chiave maestra dalla password, questo test fallirebbe — ed è
  /// l'unico modo di accorgersene, perché nell'app tutto continuerebbe a
  /// sembrare a posto **fino al primo cambio password**, dopo il quale ogni
  /// messaggio e ogni backup precedente diventerebbero illeggibili.
  test('cambiare password lascia la chiave maestra dov era', () {
    final maestra = cassaforte.generaChiaveMaestra();

    final vecchio = cassaforte.incarta(
      chiaveMaestra: maestra,
      password: 'vecchia',
      opsLimit: opsVeloce,
      memLimit: memVeloce,
    );

    // Il cambio password nella vita reale: si riapre con la vecchia, si
    // richiude con la nuova. Niente tocca i messaggi.
    final tiraFuori = cassaforte.scarta(
      pacchetto: vecchio,
      password: 'vecchia',
    );
    final nuovo = cassaforte.incarta(
      chiaveMaestra: tiraFuori,
      password: 'nuova',
      opsLimit: opsVeloce,
      memLimit: memVeloce,
    );

    final dopo = cassaforte.scarta(pacchetto: nuovo, password: 'nuova');

    expect(dopo.extractBytes(), equals(maestra.extractBytes()));
    expect(
      () => cassaforte.scarta(pacchetto: nuovo, password: 'vecchia'),
      throwsA(isA<PasswordDiRecuperoSbagliata>()),
    );
  });

  group('le sottochiavi', () {
    test('l identita della chat e la stessa a ogni ricalcolo', () {
      final maestra = cassaforte.generaChiaveMaestra();

      final prima = cassaforte.identitaChat(maestra);
      final seconda = cassaforte.identitaChat(maestra);

      expect(prima.publicKey, equals(seconda.publicKey));
      expect(
        prima.secretKey.extractBytes(),
        equals(seconda.secretKey.extractBytes()),
      );
    });

    test('chiavi maestre diverse danno identita diverse', () {
      final una = cassaforte.identitaChat(cassaforte.generaChiaveMaestra());
      final altra = cassaforte.identitaChat(cassaforte.generaChiaveMaestra());

      expect(una.publicKey, isNot(equals(altra.publicKey)));
    });

    /// Le due sottochiavi nascono dalla stessa maestra e devono restare
    /// scorrelate: un file di backup finito nelle mani sbagliate non deve dire
    /// niente sulle conversazioni.
    test('chat e backup non condividono byte', () {
      final maestra = cassaforte.generaChiaveMaestra();

      final chat = cassaforte.identitaChat(maestra).secretKey.extractBytes();
      final backup = cassaforte.chiaveBackup(maestra).extractBytes();

      expect(chat, isNot(equals(backup)));
    });
  });

  group('il pacchetto che viaggia verso il server', () {
    test('va e torna dal JSON senza perdere niente', () {
      final originale = cassaforte.incarta(
        chiaveMaestra: cassaforte.generaChiaveMaestra(),
        password: 'segreta',
        opsLimit: opsVeloce,
        memLimit: memVeloce,
      );

      final tornato = PacchettoIncartato.fromJson(originale.toJson());

      expect(tornato.salt, equals(originale.salt));
      expect(tornato.nonce, equals(originale.nonce));
      expect(tornato.cifrato, equals(originale.cifrato));
      expect(tornato.versione, equals(originale.versione));
    });

    /// ⚠️ **I parametri del KDF viaggiano col pacchetto, non stanno nel codice.**
    ///
    /// Il giorno in cui il costo verrà alzato — e verrà alzato, perché i
    /// telefoni diventano più veloci e con loro chi attacca — i pacchetti
    /// prodotti oggi devono restare apribili. Se i parametri fossero costanti
    /// dell'app, alzarli chiuderebbe fuori dal proprio account **ogni utente
    /// già registrato**, e nessuno se ne accorgerebbe prima del primo recupero.
    test('i parametri del KDF sopravvivono al viaggio', () {
      final pacchetto = cassaforte.incarta(
        chiaveMaestra: cassaforte.generaChiaveMaestra(),
        password: 'segreta',
        opsLimit: 2,
        memLimit: 16384,
      );

      final tornato = PacchettoIncartato.fromJson(pacchetto.toJson());

      expect(tornato.opsLimit, 2);
      expect(tornato.memLimit, 16384);

      // E con quei parametri si riapre davvero, non solo si rileggono.
      final maestra = cassaforte.scarta(
        pacchetto: tornato,
        password: 'segreta',
      );
      expect(maestra.extractBytes().length, 32);
    });

    test('il JSON non contiene la password ne la chiave in chiaro', () {
      final maestra = cassaforte.generaChiaveMaestra();
      final json = cassaforte
          .incarta(
            chiaveMaestra: maestra,
            password: 'password-riconoscibile',
            opsLimit: opsVeloce,
            memLimit: memVeloce,
          )
          .toJson()
          .toString();

      expect(json, isNot(contains('password-riconoscibile')));
      expect(json, isNot(contains(maestra.extractBytes().toString())));
    });
  });

  /// 🚨 I parametri **veri** — 64 MiB e 3 passate — provati una volta.
  ///
  /// Non è un doppione dei test sopra: quelli girano con valori giocattolo per
  /// non durare un minuto, e non direbbero niente se i valori veri fossero
  /// fuori dai limiti che libsodium accetta o se la memoria non bastasse.
  test('i parametri predefiniti sono accettati e funzionano', () {
    final maestra = cassaforte.generaChiaveMaestra();

    final pacchetto = cassaforte.incarta(
      chiaveMaestra: maestra,
      password: 'la-mia-password-di-recupero',
    );

    expect(pacchetto.opsLimit, Cassaforte.opsPredefinito);
    expect(pacchetto.memLimit, Cassaforte.memPredefinito);
    expect(
      cassaforte
          .scarta(pacchetto: pacchetto, password: 'la-mia-password-di-recupero')
          .extractBytes(),
      equals(maestra.extractBytes()),
    );
  });
}
