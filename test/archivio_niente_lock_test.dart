/// 🔒 **«database is locked» non deve più succedere** — 19/11/2026.
///
/// ══ 📌 IL FATTO DA CUI NASCE ══════════════════════════════════════════════
///
/// Sul telefono del committente, schermata «Backup e dati»:
/// `SqliteException(5): database is locked, causing statement: PRAGMA
/// user_version`.
///
/// ⚠️ `PRAGMA user_version` è la **prima** query che drift fa aprendo il file:
/// l'errore diceva «non sono riuscito ad aprire il database», non «il ripristino
/// è fallito».
///
/// 🔑 Questi test lavorano su `sqlite3` **diretto**, non su drift, perché la
/// cosa da dimostrare è precisamente quella che succede **prima** che drift
/// esista: una connessione che trova il file occupato da un'altra.
///
/// ══ 🚨 PERCHE' SI MISURA IL TEMPO, INVECE DI LIBERARE IL LOCK CON UN TIMER ═
///
/// ⛔ La prima stesura di questo file liberava il lock dopo 300 ms con un
/// `Future.delayed`, e **non poteva funzionare**: il `busy_timeout` di SQLite
/// blocca il **thread**, quindi l'event loop di Dart è fermo e quel timer non
/// scatta mai. Il test falliva dopo cinque secondi dando la colpa al codice.
///
/// 💡 Si misura invece **quanto aspetta** prima di arrendersi: senza
/// `busy_timeout` si arrende subito, con lui aspetta. È la stessa proprietà,
/// osservata da fuori e senza bisogno che qualcuno liberi niente.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

void main() {
  late Directory cartella;
  late String percorso;
  late Database occupante;

  setUp(() {
    cartella = Directory.systemTemp.createTempSync('niente-lock');
    percorso = '${cartella.path}/salute.sqlite';

    // 🔒 Chi tiene il file occupato per tutta la durata del test.
    occupante = sqlite3.open(percorso)
      ..execute('CREATE TABLE se_serve (x INTEGER);')
      ..execute('BEGIN EXCLUSIVE;');
  });

  tearDown(() {
    occupante
      ..execute('ROLLBACK;')
      ..close();

    cartella.deleteSync(recursive: true);
  });

  group('preparaLaConnessione', () {
    test('senza di lei, PRAGMA user_version si arrende subito', () {
      /*
       * 🚨 **È la controprova.** Se un giorno questo test smettesse di fallire
       * da solo, vorrebbe dire che il difetto non era quello che crediamo — e
       * che la correzione non sta correggendo niente.
       */
      final nuda = sqlite3.open(percorso);
      final cronometro = Stopwatch()..start();

      expect(
        () => nuda.select('PRAGMA user_version;'),
        throwsA(
          isA<SqliteException>().having(
            (e) => e.extendedResultCode,
            'codice',
            5,
          ),
        ),
      );

      cronometro.stop();

      expect(
        cronometro.elapsedMilliseconds,
        lessThan(500),
        reason: 'il default di busy_timeout è zero: non aspetta nulla',
      );

      nuda.close();
    });

    test('con lei, la stessa query aspetta invece di arrendersi', () {
      final mia = sqlite3.open(percorso);

      preparaLaConnessione(mia);

      final cronometro = Stopwatch()..start();

      // ⚠️ Qui il lock non viene liberato da nessuno, quindi alla fine fallisce
      // lo stesso: 🔑 quello che si dimostra è che **ha aspettato**. Nel caso
      // vero — la connessione di prima che sta chiudendo — la contesa dura
      // millisecondi, e in quei cinque secondi ci sta mille volte.
      expect(() => mia.select('PRAGMA user_version;'), throwsA(anything));

      cronometro.stop();

      expect(
        cronometro.elapsedMilliseconds,
        greaterThan(4000),
        reason: 'con busy_timeout = 5000 deve aver aspettato i cinque secondi',
      );

      mia.close();
    });

    test('non lancia mai, nemmeno con il file occupato', () {
      /*
       * 🚨 Difetto della **prima stesura**, trovato da questo test: il
       * `PRAGMA journal_mode = WAL` pretende il lock esclusivo e sotto contesa
       * lanciava. ⛔ Un'eccezione qui dentro impedisce al database di aprirsi:
       * sarebbe stato peggio del difetto di partenza.
       */
      final mia = sqlite3.open(percorso);

      expect(() => preparaLaConnessione(mia), returnsNormally);

      expect(
        mia.select('PRAGMA busy_timeout;').first.values.first,
        5000,
        reason: 'il busy_timeout va messo comunque: è lui la correzione',
      );

      mia.close();
    });
  });

  group('preparaLaConnessione, a campo libero', () {
    test('mette davvero il WAL quando nessuno tiene il file', () {
      final libero = Directory.systemTemp.createTempSync('wal');
      final db = sqlite3.open('${libero.path}/salute.sqlite');

      preparaLaConnessione(db);

      expect(
        db.select('PRAGMA journal_mode;').first.values.first,
        'wal',
        reason: 'col journal classico uno che scrive blocca anche chi legge',
      );

      db.close();
      libero.deleteSync(recursive: true);
    });
  });

  group('chiudere due volte', () {
    test('non lancia: dopo il ripristino close() arriva due volte', () async {
      /*
       * 🔑 `BackupAutomatico.riprendi()` ora fa `await close()` **prima** di
       * `ref.invalidate`, e subito dopo l'`onDispose` del provider chiama
       * `close()` una seconda volta. ⛔ Se la seconda lanciasse, avremmo
       * scambiato un errore con un altro.
       */
      final archivio = ArchivioSalute.inMemoria();

      await archivio.close();

      await expectLater(archivio.close(), completes);
    });
  });
}
