import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/backup/raccolta_foto.dart';
import 'package:training_companion/src/core/backup/sincronizza_foto.dart';
import 'package:training_companion/src/core/crypto/file_di_backup.dart';
import 'package:training_companion/src/core/media/archivio_foto.dart';
import 'package:training_companion/src/core/media/tipo_foto.dart';

import '../aiuto/cartelle_finte.dart';
import '../aiuto/libsodium.dart';
import 'riaccensione_test.dart' show CloudFinto;

/// Le foto nel backup — N5, N12.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FileDiBackup backup;

  const archivio = ArchivioFoto();
  const raccolta = RaccoltaFoto();

  final maestra = Uint8List.fromList(List.generate(32, (i) => i));

  setUpAll(() async => backup = FileDiBackup(await libsodiumPerTest()));

  setUp(() => CartelleFinte.installa(aFine: addTearDown));

  Uint8List byte(int quanti) =>
      Uint8List.fromList(List.generate(quanti, (i) => i % 256));

  /// Mette un file dentro la cartella di un tipo, col nome che si vuole.
  Future<File> metti(TipoFoto tipo, String nome, [Uint8List? contenuto]) async {
    final cartella = await archivio.cartellaDi(tipo);
    final f = File('${cartella.path}${Platform.pathSeparator}$nome');

    await f.writeAsBytes(contenuto ?? byte(30));

    return f;
  }

  SincronizzaFoto sincronizzatore(CloudFinto cloud) => SincronizzaFoto(
    cloud: cloud,
    backup: backup,
    chiaveMaestra: maestra,
  );

  group('l\'inventario', () {
    test('🚨 guarda solo i tipi che vanno nel backup — N12.2', () async {
      /*
       * ⚠️ Una foto per il modello finita nel backup verrebbe salvata **per
       * sempre su Drive**, quando serviva a una cosa sola e per pochi secondi.
       * E una effimera sopravviverebbe a chi l'ha mandata, che è l'esatto
       * contrario di quello che voleva.
       */
      await metti(TipoFoto.progressi, 'a.jpg');
      await metti(TipoFoto.chat, 'b.jpg');
      await metti(TipoFoto.ai, 'piatto.jpg');
      await metti(TipoFoto.effimere, 'segreta.jpg');
      await metti(TipoFoto.alimenti, 'mela.jpg');

      final nomi = (await raccolta.elenca()).map((f) => f.nomeNelCloud).toSet();

      expect(nomi, {'progressi~a.jpg', 'chat~b.jpg'});
    });

    test('i video restano fuori — N5.3', () async {
      await metti(TipoFoto.progressi, 'a.jpg');
      await metti(TipoFoto.progressi, 'filmato.mp4', byte(9000));
      await metti(TipoFoto.progressi, 'altro.mov', byte(9000));

      expect((await raccolta.elenca()).map((f) => f.nome), ['a.jpg']);
      expect(await raccolta.byteTotali(), 30, reason: 'ha contato un video');
    });

    test('cartelle mai create non sono un guasto', () async {
      expect(await raccolta.elenca(), isEmpty);
      expect(await raccolta.byteTotali(), 0);
    });

    test('l\'elenco è ordinato, così due telefoni concordano', () async {
      await metti(TipoFoto.progressi, 'z.jpg');
      await metti(TipoFoto.chat, 'a.jpg');
      await metti(TipoFoto.progressi, 'b.jpg');

      expect((await raccolta.elenca()).map((f) => f.nomeNelCloud), [
        'chat~a.jpg',
        'progressi~b.jpg',
        'progressi~z.jpg',
      ]);
    });

    test('il peso si legge come lo scrive Android', () {
      expect(RaccoltaFoto.pesoLeggibile(0), '0 byte');
      expect(RaccoltaFoto.pesoLeggibile(999), '999 byte');
      expect(RaccoltaFoto.pesoLeggibile(1500), '1,5 kB');
      expect(RaccoltaFoto.pesoLeggibile(240 * 1000 * 1000), '240 MB');
      expect(RaccoltaFoto.pesoLeggibile(1400 * 1000 * 1000), '1,4 GB');
    });
  });

  group('il nome nel cloud', () {
    test('porta con sé il tipo, e si rilegge', () {
      final letto = FotoDaSalvare.leggi('progressi~123.jpg');

      expect(letto?.tipo, TipoFoto.progressi);
      expect(letto?.nome, '123.jpg');
    });

    test('🚨 un tipo che nel backup non va non si accetta', () async {
      // ⚠️ Se il cloud contiene un `ai~…` — per un residuo, o perché qualcuno
      // ce l'ha messo — non deve tornare sul telefono.
      expect(FotoDaSalvare.leggi('ai~123.jpg'), isNull);
      expect(FotoDaSalvare.leggi('effimere~123.jpg'), isNull);
    });

    test('🚨 un percorso dentro il nome viene ripulito', () {
      final letto = FotoDaSalvare.leggi('progressi~../../fuori.jpg');

      expect(letto?.nome, 'fuori.jpg');
    });

    test('nomi malfatti tornano null invece di rompere', () {
      for (final brutto in [
        'senzatilde.jpg',
        '~123.jpg',
        'progressi~',
        'inventato~123.jpg',
        'progressi~appunti.txt',
      ]) {
        expect(FotoDaSalvare.leggi(brutto), isNull, reason: '"$brutto" passa');
      }
    });
  });

  group('il caricamento', () {
    test('cifra le foto: nel cloud non finiscono i byte in chiaro', () async {
      final chiaro = byte(500);
      await metti(TipoFoto.progressi, 'a.jpg', chiaro);

      final cloud = CloudFinto();
      expect(await sincronizzatore(cloud).caricaLeNuove(), 1);

      final salvata = cloud.allegati['progressi~a.jpg']!;

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

    test('non ricarica quello che nel cloud c\'è già', () async {
      await metti(TipoFoto.progressi, 'a.jpg');
      await metti(TipoFoto.chat, 'b.jpg');

      final cloud = CloudFinto();
      expect(await sincronizzatore(cloud).caricaLeNuove(), 2);

      // 💡 È tutta la ragione per cui le foto stanno fuori dall'archivio: al
      // secondo giro non si carica niente.
      expect(await sincronizzatore(cloud).caricaLeNuove(), 0);

      await metti(TipoFoto.progressi, 'c.jpg');
      expect(await sincronizzatore(cloud).caricaLeNuove(), 1);
    });

    test('🚨 le foto per il modello non salgono mai', () async {
      await metti(TipoFoto.progressi, 'a.jpg');
      await metti(TipoFoto.ai, 'piatto.jpg');
      await metti(TipoFoto.effimere, 'segreta.jpg');

      final cloud = CloudFinto();
      await sincronizzatore(cloud).caricaLeNuove();

      expect(cloud.allegati.keys, ['progressi~a.jpg']);
    });
  });

  group('il ripristino', () {
    test('rimette ogni foto nella SUA cartella', () async {
      final progresso = byte(40);
      final messaggio = byte(50);

      await metti(TipoFoto.progressi, 'a.jpg', progresso);
      await metti(TipoFoto.chat, 'b.jpg', messaggio);

      final cloud = CloudFinto();
      await sincronizzatore(cloud).caricaLeNuove();

      // Il telefono nuovo: stesso cloud, cartelle vuote.
      CartelleFinte.installa(aFine: addTearDown);

      expect(await sincronizzatore(cloud).riprendiLeMancanti(), 2);

      final dove = <TipoFoto, List<String>>{};

      for (final f in await raccolta.elenca()) {
        (dove[f.tipo] ??= []).add(f.nome);
      }

      expect(dove[TipoFoto.progressi], ['a.jpg']);
      expect(dove[TipoFoto.chat], ['b.jpg']);

      final tornata = await File(
        '${(await archivio.cartellaDi(TipoFoto.progressi)).path}'
        '${Platform.pathSeparator}a.jpg',
      ).readAsBytes();

      expect(tornata, progresso);
    });

    test('non riscarica quello che sul telefono c\'è già', () async {
      await metti(TipoFoto.progressi, 'a.jpg');

      final cloud = CloudFinto();
      await sincronizzatore(cloud).caricaLeNuove();

      expect(await sincronizzatore(cloud).riprendiLeMancanti(), 0);
    });

    test('🚨 un allegato di un tipo non salvabile viene ignorato', () async {
      final cloud = CloudFinto()
        ..allegati['ai~123.jpg'] = await backup.cifraFoto(
          chiaveMaestra: maestra,
          contenuto: byte(10),
        );

      expect(await sincronizzatore(cloud).riprendiLeMancanti(), 0);
      expect(await raccolta.elenca(), isEmpty);
    });

    test('una foto rovinata nel cloud si fa riconoscere', () async {
      final cloud = CloudFinto()
        ..allegati['progressi~rotta.jpg'] = Uint8List.fromList(
          List.filled(200, 0),
        );

      await expectLater(
        sincronizzatore(cloud).riprendiLeMancanti(),
        throwsA(isA<CodiceDiRipristinoSbagliato>()),
      );
    });
  });

  test('una chiave maestra diversa non apre le foto', () async {
    final cifrata = await backup.cifraFoto(
      chiaveMaestra: maestra,
      contenuto: byte(20),
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
