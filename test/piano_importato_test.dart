import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/media/tipo_foto.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/nutrition/data/importazione_piano.dart';

/// Il piano importato da PDF — N20.
///
/// ── 🚨 Cosa difendono questi test ──────────────────────────────────────────
///
/// Che un piano importato **arrivi in fondo**: dentro l'archivio locale, dentro
/// il backup, e con l'originale ancora consultabile.
///
/// ⚠️ Il rischio dell'importazione non è che l'AI fallisca — un fallimento si
/// vede e si rifà. È che il piano si perda **a valle**, in silenzio: salvato in
/// una tabella che il backup non guarda, o con l'originale finito in cache e
/// quindi cancellato dal sistema. In entrambi i casi tutto sembra funzionare
/// finché non serve davvero.
void main() {
  group('la busta che arriva dal server', () {
    test('i dubbi del modello arrivano fino all\'app', () {
      final importazione = ImportazionePiano.fromJson(const {
        'id': 7,
        'stato': 'pronta',
        'nome_file': 'dieta.pdf',
        'righe': 34,
        'bozza': {
          'nome': 'Definizione',
          'confidenza': 0.82,
          'dubbi': <String>['Il pranzo del giorno 2 è poco leggibile.'],
          'giorni': <dynamic>[],
        },
      });

      expect(importazione.stato, StatoImportazione.pronta);
      expect(importazione.righe, 34);
      expect(importazione.nome, 'Definizione');

      /*
       * 🚨 I dubbi sono la parte più utile della risposta: portano chi controlla
       * dritto sulle righe che contano. Se si perdessero nella traduzione, la
       * revisione diventerebbe un elenco di trenta voci tutte uguali.
       */
      expect(importazione.dubbi, hasLength(1));
    });

    test('una bozza che non c\'è ancora non fa esplodere niente', () {
      final importazione = ImportazionePiano.fromJson(const {
        'id': 1,
        'stato': 'in_coda',
        'nome_file': 'dieta.pdf',
        'righe': 0,
      });

      expect(importazione.inLavorazione, isTrue);
      expect(importazione.dubbi, isEmpty);
      expect(importazione.nome, 'Piano importato');
    });

    test('uno stato che non conosciamo non diventa «pronta»', () {
      /*
       * ⚠️ Il default deve essere lo stato **che non mostra niente**. Cadere su
       * «pronta» vorrebbe dire aprire la revisione su una bozza vuota, e dare a
       * qualcuno un piano di zero righe da confermare.
       */
      final importazione = ImportazionePiano.fromJson(const {
        'id': 1,
        'stato': 'qualcosa_di_nuovo',
        'nome_file': 'x.pdf',
        'righe': 0,
      });

      expect(importazione.stato, StatoImportazione.inCoda);
    });
  });

  group('l\'archivio locale', () {
    late ArchivioSalute archivio;

    setUp(() => archivio = ArchivioSalute.inMemoria());
    tearDown(() => archivio.close());

    test('un piano importato sta con i piani ricevuti, non altrove', () async {
      await archivio.salvaPianoImportato(
        importazioneId: 12,
        nome: 'Definizione',
        piano: json.encode({'name': 'Definizione', 'days': <dynamic>[]}),
        pdfOriginale: 'piani/1787-0.jpg',
      );

      final piani = await archivio.piani();

      expect(piani, hasLength(1));
      expect(piani.first.nome, 'Definizione');
      expect(piani.first.importato, isTrue);
      expect(piani.first.pdfOriginale, 'piani/1787-0.jpg');

      /*
       * 🚨 `messaggioId` negativo: un'importazione non ha un messaggio, e quel
       * campo è `unique`. L'id dell'importazione col segno meno non può
       * collidere con nessun id di messaggio, che sono positivi.
       */
      expect(piani.first.messaggioId, -12);
      expect(piani.first.mittenteId, 0);
    });

    test('reimportare la stessa non produce due piani', () async {
      for (var i = 0; i < 2; i++) {
        await archivio.salvaPianoImportato(
          importazioneId: 12,
          nome: 'Definizione',
          piano: json.encode({'name': 'Definizione', 'days': <dynamic>[]}),
        );
      }

      expect(await archivio.piani(), hasLength(1));
    });

    test('un piano importato e uno ricevuto convivono', () async {
      await archivio.salvaPiano(
        messaggioId: 12,
        mittenteId: 3,
        nome: 'Dal trainer',
        piano: '{}',
      );

      await archivio.salvaPianoImportato(
        importazioneId: 12,
        nome: 'Importato',
        piano: '{}',
      );

      /*
       * ⚠️ Lo stesso numero, 12: uno è un id di messaggio e l'altro un id di
       * importazione. Senza il segno meno si sarebbero sovrascritti a vicenda —
       * e il sintomo sarebbe stato «a volte il piano del trainer sparisce».
       */
      expect(await archivio.piani(), hasLength(2));
    });
  });

  /// 🚨 **La regola che vale per ogni cosa nuova**: se esiste un dato, deve
  /// finire nel backup. L'originale di un piano importato non fa eccezione.
  test('l\'originale di un piano importato è nel backup', () {
    expect(TipoFoto.piani.nelBackup, isTrue);
    expect(TipoFoto.piani.permanente, isTrue);

    // ⚠️ Un PDF, non solo immagini: senza questo, l'originale verrebbe
    // scritto sul telefono e poi saltato dal caricamento.
    expect(TipoFoto.piani.estensioni, contains('.pdf'));
  });
}
