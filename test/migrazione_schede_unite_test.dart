import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:training_companion/src/core/storage/archivio_salute.dart';

/// La migrazione v14 → v15: le due tabelle diventano una — 3b-B.17.6.
///
/// ══ 🚨 PERCHÉ QUESTO TEST ESISTE ══════════════════════════════════════════
///
/// ⛔ **La tentazione era droppare e ricreare.** Con un utente solo e in
/// sviluppo sembra la scelta ovvia, e sarebbe stata sbagliata: le schede scese
/// dal server **non tornerebbero da sole**. L'importazione gira una volta per
/// telefono e il suo segno sta in `LocalCache`, che una migrazione del database
/// non vede — Giorno 1, 2 e 3 sarebbero spariti per sempre, il giorno prima di
/// un allenamento vero.
///
/// ⚠️ **Una migrazione non si può provare con un archivio vuoto**: è l'unico
/// caso in cui `onUpgrade` non gira. Qui il database v14 si costruisce a mano,
/// con dentro i dati, e poi si apre con l'app di oggi.
void main() {
  /// Un database **come lo aveva chi è alla v14**, con le due tabelle piene.
  ///
  /// 💡 Bastano le due tabelle coinvolte: `onUpgrade` parte da 14, quindi
  /// esegue **solo** il passo che fonde, e gli altri passi non si guardano
  /// nemmeno le tabelle che non toccano.
  ///
  /// ⚠️ **Su file e non in memoria, e chiuso prima di riaprirlo.** Un database
  /// già aperto non fa girare nessuna migrazione — `ensureOpen` esce subito — e
  /// il test passerebbe senza aver provato niente: è il modo più facile di
  /// scrivere cinque prove verdi di una migrazione mai eseguita.
  Future<File> databaseAllaV14() async {
    final file = File(
      p.join(Directory.systemTemp.createTempSync('v14').path, 'archivio.db'),
    );

    addTearDown(() => file.parent.deleteSync(recursive: true));

    final db = NativeDatabase(file);

    Future<void> esegui(String sql) => db.runCustom(sql, const []);

    await db.ensureOpen(_NessunUtente());

    await esegui(
      'CREATE TABLE schede_sul_telefono ('
      'id INTEGER NOT NULL PRIMARY KEY, '
      'nome TEXT NOT NULL, '
      'scheda TEXT NOT NULL, '
      'aggiornata_il INTEGER NOT NULL, '
      'mia INTEGER NOT NULL DEFAULT 0)',
    );

    await esegui(
      'CREATE TABLE schede_ricevute ('
      'id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, '
      'messaggio_id INTEGER NOT NULL UNIQUE, '
      'mittente_id INTEGER NOT NULL, '
      'nome TEXT NOT NULL, '
      'scheda TEXT NOT NULL, '
      'ricevuta_il INTEGER NOT NULL, '
      'origine_id TEXT, '
      'aggiornato_il INTEGER)',
    );

    // La scheda scesa dal server: id positivo, non è mia.
    await esegui(
      "INSERT INTO schede_sul_telefono VALUES (8, 'Giorno 1', '{}', 1000, 0)",
    );

    // Quella che mi sono scritto io: id negativo, mia.
    await esegui(
      "INSERT INTO schede_sul_telefono VALUES (-1, 'La mia', '{}', 2000, 1)",
    );

    // E quella arrivata in chat, che stava nell'altra tabella.
    await esegui(
      'INSERT INTO schede_ricevute '
      '(messaggio_id, mittente_id, nome, scheda, ricevuta_il, origine_id) '
      "VALUES (77, 9, 'Dal trainer', '{}', 3000, 'XYZ')",
    );

    await esegui('PRAGMA user_version = 14');

    await db.close();

    return file;
  }

  test('le schede della v14 arrivano tutte e tre nella v15', () async {
    final archivio = ArchivioSalute.su(NativeDatabase(await databaseAllaV14()));

    addTearDown(archivio.close);

    final schede = await archivio.tutteLeSchede();

    expect(
      schede.map((s) => s.nome).toSet(),
      {'Giorno 1', 'La mia', 'Dal trainer'},
      reason: 'nessuna delle tre si perde per strada',
    );
  });

  /// 🚨 **Gli id non si rinumerano**, e non è un vezzo:
  /// `AllenamentiDaOrologio.schedaAssegnata` punta qui. Cambiarli vorrebbe dire
  /// spostare in silenzio gli allenamenti già fatti su schede diverse da quelle
  /// vere — un danno che non si vede e non si corregge.
  test('e si tengono l\'id che avevano', () async {
    final archivio = ArchivioSalute.su(NativeDatabase(await databaseAllaV14()));

    addTearDown(archivio.close);

    expect((await archivio.laScheda(8))?.nome, 'Giorno 1');
    expect((await archivio.laScheda(-1))?.nome, 'La mia');
  });

  /// 💡 Il segno dell'id diceva già da dove veniva una scheda: la migrazione
  /// traduce quella convenzione in un dato, che è quello che ci si legge.
  test('la provenienza si legge dal segno che avevano', () async {
    final archivio = ArchivioSalute.su(NativeDatabase(await databaseAllaV14()));

    addTearDown(archivio.close);

    final dalServer = await archivio.laScheda(8);
    final mia = await archivio.laScheda(-1);

    expect(dalServer?.origine, 'server');
    expect(dalServer?.idOrigine, 8, reason: 'l\'id di là era il suo id');
    expect(mia?.origine, 'mia');
    expect(mia?.idOrigine, isNull, reason: 'non viene da nessuna parte');
  });

  /// ⚠️ E quella della chat si porta dietro **l'id del messaggio e l'identità
  /// stabile**, che sono le due cose senza cui non si riconoscerebbe più né una
  /// versione nuova né una già aggiunta.
  test('quella della chat non perde da dove veniva', () async {
    final archivio = ArchivioSalute.su(NativeDatabase(await databaseAllaV14()));

    addTearDown(archivio.close);

    final dallaChat = (await archivio.tutteLeSchede()).firstWhere(
      (s) => s.nome == 'Dal trainer',
    );

    expect(dallaChat.origine, 'chat');
    expect(dallaChat.idOrigine, 77);
    expect(dallaChat.origineIdStabile, 'XYZ');
    expect(await archivio.schedaGiaSalvata(77), isTrue);
  });

  /// ⛔ **E la seconda tabella non c'è più.** Restare a metà — le righe copiate
  /// ma la tabella viva — è lo stato peggiore: due posti per la stessa cosa,
  /// che è come è cominciato tutto.
  test('la vecchia tabella sparisce', () async {
    final archivio = ArchivioSalute.su(NativeDatabase(await databaseAllaV14()));

    addTearDown(archivio.close);

    final rimaste = await archivio
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'schede_ricevute'",
        )
        .get();

    expect(rimaste, isEmpty);
  });
}

/// Un `QueryExecutorUser` che non fa niente: serve solo ad aprire il database
/// grezzo prima che ci sia un `ArchivioSalute` a farlo.
class _NessunUtente extends QueryExecutorUser {
  @override
  int get schemaVersion => 14;

  @override
  Future<void> beforeOpen(
    QueryExecutor executor,
    OpeningDetails details,
  ) async {}
}
