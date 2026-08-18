import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/media/archivio_foto.dart';
import 'package:training_companion/src/core/media/tipo_foto.dart';

import '../aiuto/cartelle_finte.dart';

/// Dove finiscono le foto, e chi le butta — N9.5.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory radice;
  const archivio = ArchivioFoto();

  setUp(() => radice = CartelleFinte.installa(aFine: addTearDown));

  Uint8List byte(int quanti) =>
      Uint8List.fromList(List.generate(quanti, (i) => i % 256));

  group('dove vive ogni tipo', () {
    test('🚨 i tipi permanenti nei documenti, gli altri nella cache', () async {
      /*
       * È la regola su cui poggia tutto: quello che non deve finire in nessun
       * backup ci finisce **per costruzione**, perché la cartella di cache è
       * già esclusa da ogni backup di sistema.
       *
       * ⚠️ Se un giorno qualcuno spostasse `ai` o `effimere` nei documenti,
       * quelle foto comincerebbero a essere salvate **senza che niente lo
       * dica**. Questo test è la sveglia.
       */
      for (final tipo in TipoFoto.values) {
        final dove = (await archivio.cartellaDi(tipo)).path;

        expect(
          dove.contains('documenti'),
          tipo.permanente,
          reason: '${tipo.name} sta nel posto sbagliato: $dove',
        );
      }
    });

    test('ogni tipo ha una cartella sua', () async {
      final cartelle = <String>{};

      for (final tipo in TipoFoto.values) {
        cartelle.add((await archivio.cartellaDi(tipo)).path);
      }

      expect(cartelle.length, TipoFoto.values.length);
    });

    test('la cartella si crea da sola', () async {
      expect((await archivio.cartellaDi(TipoFoto.progressi)).existsSync(), isTrue);
    });

    test('🚨 la cartella madre resta `foto`', () async {
      /*
       * Le regole di N0 in `data_extraction_rules.xml` escludono `root/foto`
       * dal backup di sistema. È un **prefisso**: cambiando questo nome quelle
       * regole smetterebbero di valere in silenzio, e le foto tornerebbero a
       * sfondare il tetto dei 25 MB facendo fallire il backup di tutto il resto.
       */
      expect(ArchivioFoto.madre, 'foto');
      expect(
        (await archivio.cartellaDi(TipoFoto.progressi)).path,
        contains('foto'),
      );
    });
  });

  group('salvare e ritrovare', () {
    test('il percorso salvato è relativo, non assoluto', () async {
      final relativo = await archivio.salva(
        tipo: TipoFoto.progressi,
        byte: byte(50),
      );

      /*
       * 🚨 Su iOS il contenitore dell'app **cambia percorso a ogni
       * aggiornamento**: un assoluto scritto oggi domani punta al nulla, e la
       * galleria di qualcuno si svuoterebbe da sola senza che nessuno abbia
       * cancellato niente.
       */
      expect(relativo.startsWith('foto/progressi/'), isTrue);
      expect(relativo.contains(radice.path), isFalse, reason: 'è assoluto!');
    });

    test('il giro completo: salva, ritrova, rileggi', () async {
      final contenuto = byte(120);
      final relativo = await archivio.salva(
        tipo: TipoFoto.chat,
        byte: contenuto,
      );

      expect((await archivio.fileDi(relativo)).readAsBytesSync(), contenuto);
    });

    test('due foto nello stesso istante non si sovrascrivono', () async {
      // 💡 È il caso dello scatto rapido: con i millisecondi la seconda avrebbe
      // preso il posto della prima, senza nessun errore.
      final a = await archivio.salva(tipo: TipoFoto.ai, byte: byte(10));
      final b = await archivio.salva(tipo: TipoFoto.ai, byte: byte(20));

      expect(a, isNot(b));
    });

    test('un percorso malfatto si fa riconoscere subito', () async {
      // ⚠️ Meglio scoprirlo qui che ritrovarsi un File che punta altrove.
      for (final brutto in ['pippo', 'foto/pluto/x.jpg', 'altro/chat/x.jpg']) {
        expect(
          () => archivio.fileDi(brutto),
          throwsA(isA<ArgumentError>()),
          reason: '"$brutto" è passato',
        );
      }
    });

    test('cancellare qualcosa che non c\'è non è un errore', () async {
      final relativo = await archivio.salva(
        tipo: TipoFoto.progressi,
        byte: byte(10),
      );

      await archivio.cancella(relativo);
      await archivio.cancella(relativo);

      expect((await archivio.fileDi(relativo)).existsSync(), isFalse);
    });
  });

  group('la spazzata degli orfani', () {
    /// Invecchia un file di [ore], come se fosse stato scritto allora.
    Future<void> invecchia(String relativo, int ore) async {
      final f = await archivio.fileDi(relativo);

      f.setLastModifiedSync(DateTime.now().subtract(Duration(hours: ore)));
    }

    test('butta quello che è scaduto e tiene il resto', () async {
      final vecchia = await archivio.salva(tipo: TipoFoto.ai, byte: byte(10));
      final fresca = await archivio.salva(tipo: TipoFoto.ai, byte: byte(10));

      await invecchia(vecchia, 25);
      await invecchia(fresca, 2);

      expect(await archivio.spazzaGliOrfani(), 1);
      expect((await archivio.fileDi(vecchia)).existsSync(), isFalse);
      expect((await archivio.fileDi(fresca)).existsSync(), isTrue);
    });

    test('🚨 non tocca quello che non scade', () async {
      /*
       * ⚠️ La spazzata gira all'avvio dell'app. Se prendesse anche i progressi,
       * cancellerebbe la storia di qualcuno **a ogni apertura** — il guasto
       * peggiore immaginabile, e silenzioso.
       */
      final progresso = await archivio.salva(
        tipo: TipoFoto.progressi,
        byte: byte(10),
      );
      final chat = await archivio.salva(tipo: TipoFoto.chat, byte: byte(10));

      await invecchia(progresso, 24 * 365);
      await invecchia(chat, 24 * 365);

      expect(await archivio.spazzaGliOrfani(), 0);
      expect((await archivio.fileDi(progresso)).existsSync(), isTrue);
      expect((await archivio.fileDi(chat)).existsSync(), isTrue);
    });

    test('prende anche le effimere scadute', () async {
      final e = await archivio.salva(tipo: TipoFoto.effimere, byte: byte(10));

      await invecchia(e, 30);

      expect(await archivio.spazzaGliOrfani(), 1);
    });

    test('su cartelle vuote non si lamenta', () async {
      expect(await archivio.spazzaGliOrfani(), 0);
    });
  });

  group('le decisioni sul tipo', () {
    test('🚨 solo progressi e chat entrano nel backup', () async {
      expect(
        TipoFoto.daSalvare.map((t) => t.name).toSet(),
        {'progressi', 'chat'},
      );
    });

    test('🚨 ai ed effimere non ci entrano MAI', () async {
      /*
       * Una foto effimera finita nel backup sopravviverebbe **per sempre su
       * Drive** — l'esatto contrario di quello che voleva chi l'ha mandata. E
       * una foto per il modello serve a una cosa sola, poi è peso morto che
       * cresce di qualche unità al giorno per anni.
       */
      expect(TipoFoto.ai.nelBackup, isFalse);
      expect(TipoFoto.effimere.nelBackup, isFalse);
      expect(TipoFoto.alimenti.nelBackup, isFalse);
    });

    test('dalla cartella si risale al tipo', () {
      for (final t in TipoFoto.values) {
        expect(TipoFoto.dallaCartella(t.cartella), t);
      }

      expect(TipoFoto.dallaCartella('inventata'), isNull);
    });
  });
}
