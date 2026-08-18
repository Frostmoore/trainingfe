import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:training_companion/src/core/crypto/file_di_backup.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

import '../aiuto/libsodium.dart';

/// La copia di sicurezza che si apre davvero — Parte N1, 18/08/2026.
///
/// 🚨 **Questo file prova il giro completo su dati veri**, non su una mappa
/// vuota. Un backup si prova esportando e riaprendo qualcosa che esiste: la
/// prima stesura della schermata esportava `archivio: const {}` e sembrava
/// funzionare benissimo.
void main() {
  late SodiumSumo sodium;

  setUpAll(() async {
    sodium = await libsodiumPerTest();
  });

  /// 💡 Un archivio con dentro qualcosa: una lettura, un campione di sonno e
  /// una misura del corpo. Bastano tre tabelle diverse per accorgersi se
  /// l'enumerazione salta qualcosa.
  Future<ArchivioSalute> archivioPieno() async {
    final db = ArchivioSalute.inMemoria();

    await db
        .into(db.lettureSalute)
        .insert(
          LettureSaluteCompanion.insert(
            fonte: 'prova',
            metrica: 'hrv',
            valore: 42.5,
            misurataIl: DateTime(2026, 8, 17, 7, 30),
            giorno: DateTime(2026, 8, 17),
          ),
        );

    await db
        .into(db.campioniSonno)
        .insert(
          CampioniSonnoCompanion.insert(
            fonte: 'prova',
            iniziatoIl: DateTime(2026, 8, 17, 23, 10),
            finitoIl: DateTime(2026, 8, 18, 6, 40),
            notte: DateTime(2026, 8, 18),
            fase: 3,
          ),
        );

    await db
        .into(db.misureCorpo)
        .insert(
          MisureCorpoCompanion.insert(
            giorno: DateTime(2026, 8, 18),
            pesoKg: const Value(78.4),
          ),
        );

    return db;
  }

  group('esportare e riaprire', () {
    test('il giro completo restituisce lo stesso archivio', () async {
      /*
       * 🚨 **Il test che giustifica tutta la fase N1.**
       *
       * Prima, `contenuto.archivio` non lo scriveva nessuno e non lo leggeva
       * nessuno: era uno slot vuoto nel formato. Questo verifica che quello che
       * esce sia quello che è entrato, riga per riga.
       */
      final db = await archivioPieno();
      final prima = await db.esportaPerBackup();

      final backup = FileDiBackup(sodium);
      final codice = backup.generaCodice();

      final file = await backup.esportaV2(
        chiaveMaestra: Uint8List.fromList(List.filled(32, 7)),
        archivio: prima,
        codice: codice,
      );

      final contenuto = await backup.importaV2(file: file, codice: codice);

      expect(contenuto.archivio, equals(prima));
      expect(contenuto.chiaveMaestra, equals(Uint8List.fromList(List.filled(32, 7))));

      await db.close();
    });

    test('ripristinare riscrive davvero le righe', () async {
      // ⚠️ Il giro vero: si esporta da un archivio, si ripristina in un altro,
      // e si confronta. Confrontare solo la mappa non direbbe se la scrittura
      // funziona.
      final origine = await archivioPieno();
      final dati = await origine.esportaPerBackup();

      final destinazione = ArchivioSalute.inMemoria();
      await destinazione.ripristinaDaBackup(dati);

      expect(await destinazione.esportaPerBackup(), equals(dati));

      await origine.close();
      await destinazione.close();
    });

    test('ripristinare CANCELLA quello che c\'era prima', () async {
      /*
       * 🚨 Un ripristino che si limita ad aggiungere lascerebbe un archivio
       * misto: le righe del backup **più** quelle già lì. ⚠️ Su un telefono
       * riusato darebbe pesi e notti di due persone diverse mescolati, senza
       * nessun modo di distinguerli.
       */
      final origine = await archivioPieno();
      final dati = await origine.esportaPerBackup();

      final destinazione = await archivioPieno();
      await destinazione
          .into(destinazione.misureCorpo)
          .insert(
            MisureCorpoCompanion.insert(
              giorno: DateTime(2020, 1, 1),
              pesoKg: const Value(999),
            ),
          );

      await destinazione.ripristinaDaBackup(dati);

      final misure = await destinazione.select(destinazione.misureCorpo).get();

      expect(misure.length, 1);
      expect(misure.first.pesoKg, 78.4);

      await origine.close();
      await destinazione.close();
    });
  });

  group('i due involucri', () {
    test('un backup con password si apre con la password', () async {
      /*
       * 🚨 **È la decisione che rende possibile il backup automatico.**
       *
       * ⚠️ Con il solo codice, un backup automatico sarebbe cifrato con un
       * segreto che la persona non ha mai scritto da nessuna parte.
       */
      final backup = FileDiBackup(sodium);

      final file = await backup.esportaV2(
        chiaveMaestra: Uint8List.fromList(List.filled(32, 1)),
        archivio: const {'x': []},
        codice: backup.generaCodice(),
        password: 'la-mia-password-di-recupero',
      );

      final contenuto = await backup.importaV2(
        file: file,
        password: 'la-mia-password-di-recupero',
      );

      expect(contenuto.chiaveMaestra.first, 1);
    });

    test('lo STESSO file si apre anche col codice', () async {
      // 💡 Due porte sulla stessa stanza: «ho cambiato telefono» e «ho scordato
      // la password» sono due guasti diversi.
      final backup = FileDiBackup(sodium);
      final codice = backup.generaCodice();

      final file = await backup.esportaV2(
        chiaveMaestra: Uint8List.fromList(List.filled(32, 2)),
        archivio: const {'x': []},
        codice: codice,
        password: 'una-password',
      );

      final contenuto = await backup.importaV2(file: file, codice: codice);

      expect(contenuto.chiaveMaestra.first, 2);
    });

    test('senza password il file si apre solo col codice', () async {
      final backup = FileDiBackup(sodium);
      final codice = backup.generaCodice();

      final file = await backup.esportaV2(
        chiaveMaestra: Uint8List.fromList(List.filled(32, 3)),
        archivio: const {},
        codice: codice,
      );

      await expectLater(
        backup.importaV2(file: file, password: 'qualunque'),
        throwsA(isA<CodiceDiRipristinoSbagliato>()),
      );

      expect((await backup.importaV2(file: file, codice: codice)).chiaveMaestra.first, 3);
    });

    test('un segreto sbagliato non apre niente', () async {
      final backup = FileDiBackup(sodium);

      final file = await backup.esportaV2(
        chiaveMaestra: Uint8List.fromList(List.filled(32, 4)),
        archivio: const {},
        codice: backup.generaCodice(),
        password: 'giusta',
      );

      await expectLater(
        backup.importaV2(file: file, password: 'sbagliata', codice: 'AAAA-BBBB'),
        throwsA(isA<CodiceDiRipristinoSbagliato>()),
      );
    });
  });

  group('il file manomesso', () {
    test('cambiare un byte del contenuto lo rende illeggibile', () async {
      /*
       * 🚨 `secretstream` autentica ogni blocco: un byte cambiato non passa.
       * ⚠️ Senza questa proprietà si potrebbe alterare l'archivio di qualcuno e
       * fargli ripristinare dati che non sono i suoi.
       */
      final backup = FileDiBackup(sodium);
      final codice = backup.generaCodice();

      final file = await backup.esportaV2(
        chiaveMaestra: Uint8List.fromList(List.filled(32, 5)),
        archivio: const {'x': []},
        codice: codice,
      );

      // Un byte in fondo: dentro i blocchi cifrati, non nell'intestazione.
      file[file.length - 5] = file[file.length - 5] ^ 0xFF;

      await expectLater(
        backup.importaV2(file: file, codice: codice),
        throwsA(isA<CodiceDiRipristinoSbagliato>()),
      );
    });

    test('un file troncato non fa esplodere niente', () async {
      final backup = FileDiBackup(sodium);
      final codice = backup.generaCodice();

      final file = await backup.esportaV2(
        chiaveMaestra: Uint8List.fromList(List.filled(32, 6)),
        archivio: const {},
        codice: codice,
      );

      await expectLater(
        backup.importaV2(file: file.sublist(0, 20), codice: codice),
        throwsA(isA<CodiceDiRipristinoSbagliato>()),
      );
    });

    test('spazzatura non fa esplodere niente', () async {
      final backup = FileDiBackup(sodium);

      await expectLater(
        backup.importaQualsiasi(
          file: Uint8List.fromList(utf8.encode('non sono un backup')),
          codice: 'AAAA-BBBB-CCCC-DDDD-EEEE-FFFF',
        ),
        throwsA(isA<CodiceDiRipristinoSbagliato>()),
      );
    });
  });

  group('la compatibilità col v1', () {
    test('un file scritto col v1 si apre ancora', () async {
      /*
       * 🚨 **L'unica regola non negoziabile del formato.**
       *
       * ⚠️ Chi ha esportato un file con la versione di stamattina deve poterlo
       * usare domani. Se questo test diventa rosso, qualcuno ha rotto la
       * promessa a chi quel file ce l'ha già in mano.
       */
      final backup = FileDiBackup(sodium);
      final codice = backup.generaCodice();

      final vecchio = backup.esporta(
        chiaveMaestra: Uint8List.fromList(List.filled(32, 9)),
        archivio: const {'tabella': []},
        codice: codice,
      );

      final contenuto = await backup.importaQualsiasi(
        file: vecchio,
        codice: codice,
      );

      expect(contenuto.chiaveMaestra.first, 9);
      expect(contenuto.archivio, equals({'tabella': []}));
    });

    test('importaQualsiasi riconosce il v2 senza che glielo si dica', () async {
      final backup = FileDiBackup(sodium);
      final codice = backup.generaCodice();

      final nuovo = await backup.esportaV2(
        chiaveMaestra: Uint8List.fromList(List.filled(32, 8)),
        archivio: const {'tabella': []},
        codice: codice,
      );

      final contenuto = await backup.importaQualsiasi(
        file: nuovo,
        codice: codice,
      );

      expect(contenuto.chiaveMaestra.first, 8);
    });
  });

  group('la regola sugli schemi', () {
    test('un backup di uno schema PIÙ NUOVO si rifiuta', () async {
      /*
       * 🚨 Contiene tabelle e colonne che questa versione non conosce.
       * Ignorarle in silenzio vorrebbe dire ripristinare **meno di quello che
       * c'era** facendo credere di aver ripristinato tutto — cioè perdere dati
       * con un messaggio verde davanti.
       */
      final db = ArchivioSalute.inMemoria();

      await expectLater(
        db.ripristinaDaBackup({ArchivioSalute.chiaveSchema: 9999}),
        throwsA(isA<BackupTroppoNuovo>()),
      );

      await db.close();
    });

    test('una tabella assente dal backup NON viene svuotata', () async {
      /*
       * ⚠️ È il caso di un backup vecchio: quella tabella non esisteva ancora.
       * Svuotarla cancellerebbe dati che il file non poteva contenere — cioè il
       * ripristino distruggerebbe qualcosa che non stava ripristinando.
       */
      final db = await archivioPieno();

      // Un backup che parla solo delle misure: sonno e letture non ci sono.
      final parziale = <String, dynamic>{
        ArchivioSalute.chiaveSchema: db.schemaVersion,
        'misure_corpo': [],
      };

      await db.ripristinaDaBackup(parziale);

      expect((await db.select(db.campioniSonno).get()).length, 1);
      expect((await db.select(db.misureCorpo).get()).length, 0);

      await db.close();
    });
  });
}
