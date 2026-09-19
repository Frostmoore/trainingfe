import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

/// 🔁 **La v32 trasforma gli id provvisori in esercizi suoi** — D6, 19/09/2026.
///
/// ⚠️ È lo scenario di chi **aggiorna** l'app con serie salvate senza rete prima
/// di D6: quelle serie hanno un id negativo e nessun esercizio dietro. 🚨
/// `inMemoria()` parte sempre da vuoto, cioè dall'unico caso in cui la
/// migrazione non gira mai: per provarla serve un database alla v31.
void main() {
  late Directory cartella;

  setUp(() async {
    cartella = await Directory.systemTemp.createTemp('v31_');
  });

  tearDown(() async {
    if (await cartella.exists()) await cartella.delete(recursive: true);
  });

  /// Un archivio com'era alla v31: con una serie provvisoria, e senza la
  /// tabella nuova.
  Future<File> databaseAllaV31() async {
    final file = File('${cartella.path}/salute.sqlite');

    final oggi = ArchivioSalute.su(NativeDatabase(file));
    final seduta = await oggi.apriSeduta();

    await oggi.registraSerie(
      SerieDelleSeduteCompanion.insert(
        sedutaId: seduta,
        esercizioId: -12345,
        nomeEsercizio: 'Macchina di prima',
        numero: 1,
      ),
    );

    await oggi.customStatement('DROP TABLE esercizi_sul_telefono');
    await oggi.customStatement('PRAGMA user_version = 31');
    await oggi.close();

    return file;
  }

  test('una serie provvisoria di prima trova il suo esercizio', () async {
    final archivio = ArchivioSalute.su(NativeDatabase(await databaseAllaV31()));
    addTearDown(archivio.close);

    final suoi = await archivio.leggiEserciziSulTelefono();

    expect(suoi.single.id, -12345);
    expect(suoi.single.nome, 'Macchina di prima');
    expect(suoi.single.origine, 'mio');

    // ⚠️ I muscoli non si sanno: restano da indicare, non inventati.
    expect(suoi.single.primario, isNull);
  });

  /// 💡 E alla prima occasione i muscoli si danno: riscriverlo nel player lo
  /// completa invece di crearne un secondo.
  test('riscriverlo con i muscoli lo completa', () async {
    final archivio = ArchivioSalute.su(NativeDatabase(await databaseAllaV31()));
    addTearDown(archivio.close);

    final id = await archivio.salvaEsercizioMio(
      nome: 'macchina di prima',
      primario: 'chest',
    );

    expect(id, -12345);
    expect(
      (await archivio.leggiEserciziSulTelefono()).single.primario,
      'chest',
    );
  });
}
