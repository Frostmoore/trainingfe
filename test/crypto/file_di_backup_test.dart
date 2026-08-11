import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:training_companion/src/core/crypto/cassaforte.dart';
import 'package:training_companion/src/core/crypto/file_di_backup.dart';

import '../aiuto/libsodium.dart';

/// S6.6 — il file di backup.
///
/// 🎯 **È l'ultima via d'uscita.** *«Se si dimenticano la password di recupero
/// DEVONO poterla rigenerare: non è accettabile che dei dati vengano persi del
/// tutto perché uno stronzo si scorda la password.»* — il committente.
///
/// Un file che non si riapre è peggio di nessun file, perché fa credere di avere
/// una rete di sicurezza che non c'è.
void main() {
  late SodiumSumo sodium;
  late FileDiBackup backup;
  late Cassaforte cassaforte;

  setUpAll(() async {
    sodium = await libsodiumPerTest();
    backup = FileDiBackup(sodium);
    cassaforte = Cassaforte(sodium);
  });

  Uint8List maestraFinta() =>
      cassaforte.generaChiaveMaestra().extractBytes();

  group('il codice di ripristino', () {
    test('sono sei gruppi da quattro, leggibili su un foglio', () {
      final codice = backup.generaCodice();

      expect(codice.split('-'), hasLength(6));
      expect(codice.split('-').every((g) => g.length == 4), isTrue);
    });

    /// ⚠️ Chi ricopia a mano confonde proprio questi caratteri, e un codice
    /// ricopiato male dà lo stesso errore di un codice sbagliato — cioè
    /// nessuna indicazione utile su cosa è successo.
    test('non contiene caratteri che si confondono a mano', () {
      for (var i = 0; i < 50; i++) {
        expect(RegExp(r'[01OIl]').hasMatch(backup.generaCodice()), isFalse);
      }
    });

    test('due codici non sono mai lo stesso codice', () {
      final visti = {for (var i = 0; i < 200; i++) backup.generaCodice()};

      expect(visti, hasLength(200));
    });
  });

  group('esportazione e reimportazione', () {
    test('quello che entra è esattamente quello che esce', () {
      final maestra = maestraFinta();
      final codice = backup.generaCodice();

      final file = backup.esporta(
        chiaveMaestra: maestra,
        archivio: {
          'misure': [
            {'giorno': '2026-08-01', 'peso_kg': 81.4},
            {'giorno': '2026-08-08', 'peso_kg': 80.9},
          ],
        },
        codice: codice,
      );

      final dentro = backup.importa(file: file, codice: codice);

      expect(dentro.chiaveMaestra, equals(maestra));
      final misure = (dentro.archivio['misure'] as List)
          .cast<Map<String, dynamic>>();

      expect(misure, hasLength(2));
      expect(misure.first['peso_kg'], 81.4);
    });

    /// 🚨 **Il test che dice a cosa serve davvero questo file.**
    ///
    /// La chiave maestra che ne esce è la stessa che c'era: con quella si
    /// riscrive un pacchetto nuovo con una password nuova, e si rientra in un
    /// account la cui password era stata dimenticata **senza perdere niente**.
    test('la chiave che esce riapre l identita di prima', () {
      final maestra = cassaforte.generaChiaveMaestra();
      final identitaPrima = cassaforte.identitaChat(maestra);
      final codice = backup.generaCodice();

      final file = backup.esporta(
        chiaveMaestra: maestra.extractBytes(),
        archivio: const {},
        codice: codice,
      );

      final dentro = backup.importa(file: file, codice: codice);
      final identitaDopo = cassaforte.identitaChat(
        SecureKey.fromList(sodium, dentro.chiaveMaestra),
      );

      expect(identitaDopo.publicKey, equals(identitaPrima.publicKey));
    });

    test('un codice sbagliato non apre niente', () {
      final file = backup.esporta(
        chiaveMaestra: maestraFinta(),
        archivio: const {'misure': []},
        codice: backup.generaCodice(),
      );

      expect(
        () => backup.importa(file: file, codice: backup.generaCodice()),
        throwsA(isA<CodiceDiRipristinoSbagliato>()),
      );
    });

    /// ⚠️ Senza normalizzazione, un codice **giusto** ricopiato in minuscolo
    /// darebbe «codice sbagliato» — il modo peggiore di fallire, perché fa
    /// credere di aver perso tutto quando non è vero.
    test('il codice si accetta comunque sia stato ricopiato', () {
      final maestra = maestraFinta();
      final codice = backup.generaCodice();

      final file = backup.esporta(
        chiaveMaestra: maestra,
        archivio: const {},
        codice: codice,
      );

      for (final variante in [
        codice.toLowerCase(),
        codice.replaceAll('-', ''),
        codice.replaceAll('-', ' '),
        '  ${codice.toLowerCase()}  ',
      ]) {
        expect(
          backup.importa(file: file, codice: variante).chiaveMaestra,
          equals(maestra),
          reason: 'La variante "$variante" non è stata accettata.',
        );
      }
    });

    /// 🚨 Il file finisce su Drive, in una mail, in una cartella condivisa.
    /// Quello che ci si legge dentro senza il codice deve essere niente.
    test('senza il codice il file non dice niente', () {
      final file = backup.esporta(
        chiaveMaestra: maestraFinta(),
        archivio: const {
          'misure': [
            {'giorno': '2026-08-01', 'peso_kg': 81.4},
          ],
        },
        codice: backup.generaCodice(),
      );

      final testo = utf8.decode(file);

      expect(testo, isNot(contains('81.4')));
      expect(testo, isNot(contains('peso_kg')));
      expect(testo, isNot(contains('master_key')));

      // L'intestazione invece si legge, ed è giusto: senza, chi apre il file non
      // saprebbe nemmeno con quali parametri provare.
      expect(testo, contains('training-companion-backup'));
    });

    test('un file rovinato lo dice invece di esplodere', () {
      expect(
        () => backup.importa(
          file: Uint8List.fromList(utf8.encode('non sono un backup')),
          codice: backup.generaCodice(),
        ),
        throwsA(isA<CodiceDiRipristinoSbagliato>()),
      );
    });

    /// ⚠️ Un byte cambiato nel payload deve dare errore, non dati storti: un
    /// backup mezzo corrotto che si apre a metà è peggio di uno che si rifiuta.
    test('un file manomesso non si apre a meta', () {
      final codice = backup.generaCodice();
      final file = backup.esporta(
        chiaveMaestra: maestraFinta(),
        archivio: const {'misure': []},
        codice: codice,
      );

      final testa = json.decode(utf8.decode(file)) as Map<String, dynamic>;
      final byte = base64Decode(testa['payload'] as String);
      byte[0] = byte[0] ^ 0x01;
      testa['payload'] = base64Encode(byte);

      expect(
        () => backup.importa(
          file: Uint8List.fromList(utf8.encode(json.encode(testa))),
          codice: codice,
        ),
        throwsA(isA<CodiceDiRipristinoSbagliato>()),
      );
    });

    test('una versione futura lo dice chiaramente', () {
      final codice = backup.generaCodice();
      final file = backup.esporta(
        chiaveMaestra: maestraFinta(),
        archivio: const {},
        codice: codice,
      );

      final testa = json.decode(utf8.decode(file)) as Map<String, dynamic>;
      testa['version'] = 99;

      expect(
        () => backup.importa(
          file: Uint8List.fromList(utf8.encode(json.encode(testa))),
          codice: codice,
        ),
        throwsA(
          isA<CodiceDiRipristinoSbagliato>().having(
            (e) => e.motivo,
            'motivo',
            contains('versione'),
          ),
        ),
      );
    });
  });
}
