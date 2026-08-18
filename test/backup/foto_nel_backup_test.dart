import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/backup/raccolta_foto.dart';
import 'package:training_companion/src/core/backup/sincronizza_foto.dart';
import 'package:training_companion/src/core/crypto/file_di_backup.dart';

import '../aiuto/libsodium.dart';
import 'riaccensione_test.dart' show CloudFinto;

/// Le foto nel backup — N5.
void main() {
  late FileDiBackup backup;
  late Directory cartella;

  final maestra = Uint8List.fromList(List.generate(32, (i) => i));

  setUpAll(() async => backup = FileDiBackup(await libsodiumPerTest()));

  setUp(() {
    cartella = Directory.systemTemp.createTempSync('foto-test');
  });

  tearDown(() {
    if (cartella.existsSync()) cartella.deleteSync(recursive: true);
  });

  File scrivi(String nome, List<int> byte) =>
      File('${cartella.path}${Platform.pathSeparator}$nome')
        ..writeAsBytesSync(byte);

  SincronizzaFoto sincronizzatore(CloudFinto cloud) => SincronizzaFoto(
    cloud: cloud,
    backup: backup,
    raccolta: RaccoltaFoto(cartella),
    chiaveMaestra: maestra,
  );

  group('l\'inventario', () {
    test('conta solo le immagini, e i video restano fuori', () async {
      // 🚨 N5.3: i video non entrano MAI nel backup automatico. Qui si prova
      // che l'elenco di ammessi li lascia davvero fuori.
      scrivi('a.jpg', [1, 2, 3]);
      scrivi('b.PNG', [4, 5]);
      scrivi('filmato.mp4', List.filled(9000, 7));
      scrivi('altro.mov', List.filled(9000, 7));
      scrivi('appunti.txt', [9]);

      final raccolta = RaccoltaFoto(cartella);
      final elenco = await raccolta.elenca();

      expect(elenco.map((f) => f.uri.pathSegments.last), ['a.jpg', 'b.PNG']);
      expect(await raccolta.byteTotali(), 5, reason: 'ha contato un video');
    });

    test('una cartella che non esiste non e\' un guasto', () async {
      final raccolta = RaccoltaFoto(Directory('${cartella.path}/mai-creata'));

      expect(await raccolta.elenca(), isEmpty);
      expect(await raccolta.byteTotali(), 0);
    });

    test('il peso si legge come lo scrive Android', () {
      expect(RaccoltaFoto.pesoLeggibile(0), '0 byte');
      expect(RaccoltaFoto.pesoLeggibile(999), '999 byte');
      expect(RaccoltaFoto.pesoLeggibile(1500), '1,5 kB');
      expect(RaccoltaFoto.pesoLeggibile(240 * 1000 * 1000), '240 MB');
      expect(RaccoltaFoto.pesoLeggibile(1400 * 1000 * 1000), '1,4 GB');
    });
  });

  group('il caricamento', () {
    test('cifra le foto: nel cloud non finiscono i byte in chiaro', () async {
      final chiaro = Uint8List.fromList(List.generate(500, (i) => i % 251));
      scrivi('a.jpg', chiaro);

      final cloud = CloudFinto();
      expect(await sincronizzatore(cloud).caricaLeNuove(), 1);

      final salvata = cloud.allegati['a.jpg']!;

      /*
       * 🚨 L'asserzione che conta davvero. Un difetto in cui la cifratura non
       * parte non si **vede**: il backup funziona, il ripristino funziona, e
       * l'unica differenza è che le foto di qualcuno sono leggibili da chi
       * ospita il file.
       */
      expect(salvata, isNot(equals(chiaro)));
      expect(
        await backup.decifraFoto(chiaveMaestra: maestra, contenuto: salvata),
        chiaro,
      );
    });

    test('non ricarica quello che nel cloud c\'e\' gia\'', () async {
      scrivi('a.jpg', [1, 2, 3]);
      scrivi('b.jpg', [4, 5, 6]);

      final cloud = CloudFinto();
      expect(await sincronizzatore(cloud).caricaLeNuove(), 2);

      // 💡 È tutta la ragione per cui le foto stanno fuori dall'archivio: al
      // secondo giro non si ricarica niente. Un backup giornaliero che
      // rispedisse ogni volta centinaia di megabyte verrebbe spento.
      expect(await sincronizzatore(cloud).caricaLeNuove(), 0);

      scrivi('c.jpg', [7]);
      expect(await sincronizzatore(cloud).caricaLeNuove(), 1);
      expect(cloud.allegati.keys.toSet(), {'a.jpg', 'b.jpg', 'c.jpg'});
    });

    test('i video non salgono nemmeno passando di qui', () async {
      scrivi('a.jpg', [1]);
      scrivi('vacanza.mp4', List.filled(100, 3));

      final cloud = CloudFinto();
      await sincronizzatore(cloud).caricaLeNuove();

      expect(cloud.allegati.keys, ['a.jpg']);
    });
  });

  group('il ripristino', () {
    test('riscrive su disco le foto che mancano', () async {
      final chiaro = Uint8List.fromList([9, 8, 7, 6]);
      scrivi('a.jpg', chiaro);

      final cloud = CloudFinto();
      await sincronizzatore(cloud).caricaLeNuove();

      // Il telefono nuovo: stesso cloud, cartella vuota.
      final nuova = Directory.systemTemp.createTempSync('foto-nuove');
      addTearDown(() => nuova.deleteSync(recursive: true));

      final riprese = await SincronizzaFoto(
        cloud: cloud,
        backup: backup,
        raccolta: RaccoltaFoto(nuova),
        chiaveMaestra: maestra,
      ).riprendiLeMancanti();

      expect(riprese, 1);
      expect(
        File('${nuova.path}${Platform.pathSeparator}a.jpg').readAsBytesSync(),
        chiaro,
      );
    });

    test('non riscarica quello che sul telefono c\'e\' gia\'', () async {
      scrivi('a.jpg', [1, 2]);

      final cloud = CloudFinto();
      await sincronizzatore(cloud).caricaLeNuove();

      expect(await sincronizzatore(cloud).riprendiLeMancanti(), 0);
    });

    test('un nome con un percorso dentro non scrive fuori dalla cartella', () async {
      /*
       * 🚨 Il nome arriva dal cloud, e non ci si fida.
       *
       * ⚠️ Senza il `basename` in `riprendiLeMancanti`, un allegato chiamato
       * `../fuori.jpg` finirebbe **accanto** alla cartella delle foto. Non è
       * l'attacco più probabile del mondo — quel file lo abbiamo scritto noi —
       * ma la riga che lo impedisce costa nulla e questa prova la tiene ferma.
       */
      final cloud = CloudFinto()
        ..allegati['../fuori.jpg'] = await backup.cifraFoto(
          chiaveMaestra: maestra,
          contenuto: Uint8List.fromList([1]),
        );

      await sincronizzatore(cloud).riprendiLeMancanti();

      final fuori = File(
        '${cartella.parent.path}${Platform.pathSeparator}fuori.jpg',
      );

      expect(fuori.existsSync(), isFalse, reason: 'ha scritto fuori!');
      expect(
        File('${cartella.path}${Platform.pathSeparator}fuori.jpg').existsSync(),
        isTrue,
        reason: 'il nome andava ripulito, non scartato',
      );
    });

    test('una foto rovinata nel cloud si fa riconoscere', () async {
      final cloud = CloudFinto()
        ..allegati['rotta.jpg'] = Uint8List.fromList(List.filled(200, 0));

      await expectLater(
        sincronizzatore(cloud).riprendiLeMancanti(),
        throwsA(isA<CodiceDiRipristinoSbagliato>()),
      );
    });
  });

  test('una chiave maestra diversa non apre le foto', () async {
    final cifrata = await backup.cifraFoto(
      chiaveMaestra: maestra,
      contenuto: Uint8List.fromList([1, 2, 3]),
    );

    await expectLater(
      backup.decifraFoto(
        chiaveMaestra: Uint8List.fromList(List.filled(32, 99)),
        contenuto: cifrata,
      ),
      throwsA(isA<CodiceDiRipristinoSbagliato>()),
    );
  });
}
