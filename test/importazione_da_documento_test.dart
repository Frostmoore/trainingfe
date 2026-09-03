import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/media/tipo_foto.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/import/data/bozza_in_modulo.dart';
import 'package:training_companion/src/features/import/data/importazione_da_documento.dart';
import 'package:training_companion/src/features/import/data/origine_della_bozza.dart';
import 'package:training_companion/src/features/import/data/salva_la_bozza.dart';

/// L'importazione da documento — Parte K (era N20).
///
/// ══ 🚨 COSA DIFENDONO QUESTI TEST ═════════════════════════════════════════
///
/// Che quello che si è importato **arrivi in fondo**: dentro l'archivio locale,
/// dentro il backup, con l'originale ancora consultabile, e con i giorni al
/// posto giusto.
///
/// ⚠️ Il rischio dell'importazione non è che l'AI fallisca — un fallimento si
/// vede e si rifà. È che riesca **a metà**, o che il risultato si perda **a
/// valle** in silenzio: salvato in una tabella che il backup non guarda, o con
/// il terzo giorno finito al posto del secondo. In tutti questi casi tutto
/// sembra funzionare finché non serve davvero.
void main() {
  group('la busta che arriva dal server', () {
    test('i dubbi del modello arrivano fino all\'app', () {
      final importazione = ImportazioneDaDocumento.fromJson(const {
        'id': 7,
        'stato': 'pronta',
        'nome_file': 'dieta.pdf',
        'righe': 34,
        'tipo': 'pdf',
        'genere': 'piano',
        'quanti_documenti': 1,
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
      expect(importazione.tipo, TipoDiDocumento.pdf);

      /*
       * 🚨 I dubbi sono la parte più utile della risposta: portano chi controlla
       * dritto sulle righe che contano. Se si perdessero nella traduzione, la
       * revisione diventerebbe un elenco di trenta voci tutte uguali.
       */
      expect(importazione.dubbi, hasLength(1));
    });

    test('per una scheda i dubbi si ricavano dalla confidenza', () {
      /*
       * ⚠️ Il prompt delle schede non chiede un campo `dubbi`: chiede una
       * confidenza per riga, e dice al modello di scendere sotto 0.5 quando una
       * cifra è ambigua.
       *
       * 🚨 Quel numero, da solo, non lo legge nessuno: un segnale che esiste e
       * non si vede è un segnale che non esiste.
       */
      final importazione = ImportazioneDaDocumento.fromJson(const {
        'id': 9,
        'stato': 'pronta',
        'nome_file': 'scheda.jpg',
        'righe': 2,
        'tipo': 'immagini',
        'genere': 'scheda',
        'quanti_documenti': 3,
        'bozza': {
          'name': 'Push Pull Gambe',
          'notes': 'La quarta riga del secondo foglio è illeggibile.',
          'exercises': [
            {'name': 'Panca piana', 'confidence': 0.95, 'day': 1},
            {'name': 'Croci ai cavi', 'confidence': 0.3, 'day': 1},
          ],
        },
      });

      expect(importazione.tipo, TipoDiDocumento.immagini);
      expect(importazione.quantiDocumenti, 3);

      /*
       * 🚨 **Solo la riga incerta.** Le note del modello NON sono un dubbio, e
       * per un giorno lo sono state: su un documento vero (K7) il modello ci
       * mette la frequenza settimanale, la durata della seduta e le regole di
       * progressione — un paragrafo su ogni import, che finiva nel riquadro
       * rosso dei «punti da guardare».
       *
       * ⛔ Un allarme che compare sempre insegna a saltare gli allarmi, e il
       * giorno che ce n'è uno vero nessuno lo legge.
       */
      expect(importazione.dubbi, hasLength(1));
      expect(importazione.dubbi.single, contains('Croci ai cavi'));

      // 💡 Ma non si buttano: si mostrano in chiaro, fuori dal rosso.
      expect(importazione.noteDelDocumento, contains('illeggibile'));
    });

    test('una bozza che non c\'è ancora non fa esplodere niente', () {
      final importazione = ImportazioneDaDocumento.fromJson(const {
        'id': 1,
        'stato': 'in_coda',
        'nome_file': 'dieta.pdf',
        'righe': 0,
      });

      expect(importazione.inLavorazione, isTrue);
      expect(importazione.dubbi, isEmpty);
      expect(importazione.nome, 'Piano importato');
      expect(importazione.giorni, 1);
    });

    test('uno stato che non conosciamo non diventa «pronta»', () {
      /*
       * ⚠️ Il default deve essere lo stato **che non mostra niente**. Cadere su
       * «pronta» vorrebbe dire aprire la revisione su una bozza vuota, e dare a
       * qualcuno un piano di zero righe da confermare.
       */
      final importazione = ImportazioneDaDocumento.fromJson(const {
        'id': 1,
        'stato': 'qualcosa_di_nuovo',
        'nome_file': 'x.pdf',
        'righe': 0,
      });

      expect(importazione.stato, StatoImportazione.inCoda);
    });
  });

  group('dalla bozza al modulo', () {
    test('gli esercizi si raggruppano nei loro giorni', () {
      final scheda = schedaDallaBozza(const {
        'name': 'Split',
        'day_names': ['Push', 'Pull'],
        'exercises': [
          {'name': 'Panca piana', 'sets': 4, 'reps': '8-10', 'day': 1},
          {'name': 'Rematore', 'sets': 4, 'reps': '8', 'day': 2},
          {'name': 'Alzate laterali', 'sets': 3, 'reps': '15', 'day': 1},
        ],
      });

      expect(scheda.nome, 'Split');
      expect(scheda.giorni, hasLength(2));

      // ⚠️ L'ordine dentro il giorno è quello del documento, non quello in cui
      // capitano: l'ordine è parte della prescrizione.
      expect(scheda.giorni.first.nome, 'Push');
      expect(scheda.giorni.first.esercizi.map((e) => e.nome), [
        'Panca piana',
        'Alzate laterali',
      ]);
      expect(scheda.giorni.last.nome, 'Pull');
      expect(scheda.giorni.last.esercizi.single.nome, 'Rematore');
    });

    test('un giorno saltato resta un giorno, vuoto', () {
      /*
       * 🚨 È il caso che rovina tutto in silenzio. Se il modello marca 1 e 3 —
       * perché il giorno 2 era illeggibile — contando i valori **distinti** i
       * giorni sarebbero due, e il terzo diventerebbe il secondo: una scheda che
       * sembra completa e ha il mercoledì al posto del martedì.
       */
      final scheda = schedaDallaBozza(const {
        'name': 'Bucata',
        'exercises': [
          {'name': 'Squat', 'day': 1},
          {'name': 'Stacco', 'day': 3},
        ],
      });

      expect(scheda.giorni, hasLength(3));
      expect(scheda.giorni[1].esercizi, isEmpty);
      expect(scheda.giorni[2].esercizi.single.nome, 'Stacco');
    });

    test('senza `day` è tutto un giorno solo', () {
      final scheda = schedaDallaBozza(const {
        'name': 'Full body',
        'exercises': [
          {'name': 'Squat'},
          {'name': 'Panca'},
        ],
      });

      expect(scheda.giorni, hasLength(1));
      expect(scheda.giorni.single.esercizi, hasLength(2));

      // 💡 Nessun nome inventato: sul foglio non c'era scritto niente.
      expect(scheda.giorni.single.nome, isNull);
    });

    test('il piano tiene i grammi, e lascia vuoto quello che non c\'era', () {
      final piano = pianoDallaBozza(const {
        'nome': 'Definizione',
        'giorni': [
          {
            'nome': 'Lunedì',
            'pasti': [
              {
                'tipo': 'breakfast',
                'orario': '07:30',
                'alimenti': [
                  {'descrizione': 'Fiocchi d\'avena', 'grammi': 80},
                  {'descrizione': 'Un cucchiaio di miele'},
                ],
                'alternative': [
                  {
                    'tipo': 'Colazione alternativa',
                    'alimenti': [
                      {'descrizione': 'Pane tostato', 'grammi': 80},
                    ],
                  },
                ],
              },
            ],
          },
        ],
      });

      expect(piano.nome, 'Definizione');
      expect(piano.giorni.single.nome, 'Lunedì');

      final pasto = piano.giorni.single.pasti.single;

      expect(pasto.pasto, 'breakfast');

      // 💡 L'orario non si butta via: «Colazione · 07:30» non è «Colazione».
      expect(pasto.titolo, '07:30');
      expect(pasto.alimenti.first.grammi, 80);

      /*
       * ══ 🚨 LE ALTERNATIVE SONO ALTERNATIVE, NON PASTI IN PIU' ═══════════
       *
       * ⛔ Fino al 03/09/2026 lo schema del modello non aveva un posto dove
       * metterle, e su un documento vero le trascriveva come **pasti normali**:
       * una giornata da cinque pasti ne mostrava otto, e chi la legge crede di
       * doverli mangiare tutti.
       */
      expect(piano.giorni.single.pasti, hasLength(1), reason: 'un pasto solo');
      expect(pasto.alternative, hasLength(1));

      final variante = pasto.alternative.single;

      /*
       * 🚨 **Il tipo è quello del pasto che sostituisce**, non «Colazione
       * alternativa». I tipi sono quattro, e inventarne un quinto romperebbe il
       * diario, che sul tipo decide in quale pasto della giornata finisce quello
       * che si registra.
       */
      expect(variante.pasto, 'breakfast');

      // 💡 Il nome del documento resta, ed è l'unica cosa che la distingue.
      expect(variante.titolo, 'Colazione alternativa');
      expect(variante.alimenti.single.descrizione, 'Pane tostato');
      expect(variante.alimenti.single.grammi, 80);

      /*
       * 🚨 Il grammaggio che non c'era resta **vuoto**. Riempirlo con una
       * conversione inventata sarebbe esattamente il tipo di errore che questa
       * revisione esiste per intercettare: un numero plausibile che nessuno ha
       * scritto.
       */
      expect(pasto.alimenti.last.grammi, isNull);
    });
  });

  group('dove finisce la bozza', () {
    late ArchivioSalute archivio;
    late SalvaLaBozza salva;

    setUp(() {
      archivio = ArchivioSalute.inMemoria();
      salva = SalvaLaBozza(archivio);
    });

    tearDown(() => archivio.close());

    OrigineDellaBozza origine({int id = 12}) => OrigineDellaBozza(
          importazioneId: id,
          documenti: const ['foto/piani/1787-0.pdf'],
          tipo: TipoDiDocumento.pdf,
          righeDaControllare: 34,
        );

    test('chi non è abbonato riceve una scheda per giorno', () async {
      final scheda = schedaDallaBozza(const {
        'name': 'Split',
        'day_names': ['Push', 'Pull', 'Gambe', 'Braccia'],
        'exercises': [
          {'name': 'Panca', 'day': 1},
          {'name': 'Rematore', 'day': 2},
          {'name': 'Squat', 'day': 3},
          {'name': 'Curl', 'day': 4},
        ],
      });

      final esito = await salva.scheda(
        scheda,
        abbonato: false,
        origine: origine(),
      );

      expect(esito.divisa, isTrue);
      expect(esito.quante, 4);

      final salvate = await archivio.tutteLeSchede();

      /*
       * 🚨 **Quattro, anche se il limite di chi non è abbonato è tre.**
       * Rifiutare qui sarebbe l'esito peggiore possibile: l'import costa 50
       * gettoni, e il rifiuto arriverebbe dopo che la persona ha pagato *e*
       * confrontato quaranta righe. Le eccedenti risultano bloccate
       * nell'elenco, ed è la regola che esiste da 3b-D.
       */
      expect(salvate, hasLength(4));

      // 💡 Il nome del giorno se c'è: «Giorno 2» in un elenco non dice da dove
      // viene.
      expect(salvate.map((s) => s.nome), containsAll(['Push', 'Gambe']));

      /*
       * ⚠️ Origini **distinte**: senza l'indice, un salvataggio ripetuto ne
       * riscriverebbe una sola e le altre tre resterebbero quelle di prima.
       */
      expect(salvate.map((s) => s.origineIdStabile).toSet(), hasLength(4));
    });

    test('chi è abbonato tiene la sua scheda intera', () async {
      final scheda = schedaDallaBozza(const {
        'name': 'Split',
        'exercises': [
          {'name': 'Panca', 'day': 1},
          {'name': 'Rematore', 'day': 2},
        ],
      });

      final esito = await salva.scheda(
        scheda,
        abbonato: true,
        origine: origine(),
      );

      expect(esito.divisa, isFalse);
      expect(await archivio.tutteLeSchede(), hasLength(1));
    });

    test('salvare due volte non raddoppia le schede', () async {
      final scheda = schedaDallaBozza(const {
        'name': 'Split',
        'exercises': [
          {'name': 'Panca', 'day': 1},
          {'name': 'Rematore', 'day': 2},
        ],
      });

      for (var i = 0; i < 2; i++) {
        await salva.scheda(scheda, abbonato: false, origine: origine());
      }

      expect(await archivio.tutteLeSchede(), hasLength(2));
    });

    test('l\'originale si registra insieme a quello che ne è nato', () async {
      await salva.scheda(
        schedaDallaBozza(const {
          'name': 'Split',
          'exercises': [
            {'name': 'Panca', 'day': 1},
            {'name': 'Rematore', 'day': 2},
          ],
        }),
        abbonato: false,
        origine: origine(),
      );

      /*
       * 🚨 **Una riga sola per quattro schede**: le schede nate da una multiday
       * divisa vengono da **un** documento. L'indice del giorno sta nell'origine
       * della scheda, non qui.
       */
      final percorsi = await archivio.documentiDellOrigine('importazione:12');

      expect(percorsi, ['foto/piani/1787-0.pdf']);
    });

    test('un piano importato sta con i piani ricevuti, non altrove', () async {
      await salva.piano(
        pianoDallaBozza(const {'nome': 'Definizione', 'giorni': <dynamic>[]}),
        origine: origine(),
      );

      final piani = await archivio.piani();

      expect(piani, hasLength(1));
      expect(piani.first.nome, 'Definizione');
      expect(piani.first.importato, isTrue);

      /*
       * 🚨 `messaggioId` negativo: un'importazione non ha un messaggio, e quel
       * campo è `unique`. L'id dell'importazione col segno meno non può
       * collidere con nessun id di messaggio, che sono positivi.
       */
      expect(piani.first.messaggioId, -12);
      expect(piani.first.mittenteId, 0);

      // ⚠️ La forma è quella del compositore, non una forma dell'import: un
      // piano è un piano, e due forme vorrebbero dire due strade da mantenere.
      expect(
        (json.decode(piani.first.piano) as Map)['days'],
        isA<List<dynamic>>(),
      );
    });

    test('reimportare la stessa non produce due piani', () async {
      for (var i = 0; i < 2; i++) {
        await salva.piano(
          pianoDallaBozza(const {'nome': 'Definizione', 'giorni': <dynamic>[]}),
          origine: origine(),
        );
      }

      expect(await archivio.piani(), hasLength(1));
      expect(
        await archivio.documentiDellOrigine('importazione:12'),
        hasLength(1),
      );
    });

    test('un piano importato e uno ricevuto convivono', () async {
      await archivio.salvaPiano(
        messaggioId: 12,
        mittenteId: 3,
        nome: 'Dal trainer',
        piano: '{}',
      );

      await salva.piano(
        pianoDallaBozza(const {'nome': 'Importato', 'giorni': <dynamic>[]}),
        origine: origine(),
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
  /// finire nel backup. L'originale di un documento importato non fa eccezione.
  test('l\'originale di un documento importato è nel backup', () {
    expect(TipoFoto.piani.nelBackup, isTrue);
    expect(TipoFoto.piani.permanente, isTrue);

    // ⚠️ Un PDF, non solo immagini: senza questo, l'originale verrebbe
    // scritto sul telefono e poi saltato dal caricamento.
    expect(TipoFoto.piani.estensioni, contains('.pdf'));
  });

  /// ══ 🚨 NON ESISTONO DUE EDITOR DELLA STESSA COSA — K6.3 ═════════════════
  ///
  /// 📌 Il committente: *«si deve poter modificare tutto quello che è stato
  /// generato dall'ai **nello stesso modo** in cui si creerebbe una scheda o un
  /// piano alimentare»*.
  ///
  /// ⛔ Il modo di tradire questa richiesta non è scriverne uno sbagliato: è
  /// aggiungerne **un secondo** — una schermata di revisione «solo per
  /// l'import», che nasce identica e poi diverge. Si aggiunge un campo al
  /// compositore, e l'import continua a non averlo: nessun errore, nessun test
  /// rosso, solo una funzione che invecchia da sola.
  ///
  /// 💡 Questo test è l'unica cosa che se ne accorge.
  test('non esiste una seconda schermata di revisione', () {
    final sospetti = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('revisione_') && n.endsWith('.dart'))
        .toList();

    expect(
      sospetti,
      isEmpty,
      reason: 'La revisione è il compositore vero, aperto su una bozza '
          '(CompositoreScheda.bozza / CompositorePiano.bozza). Una schermata '
          'di revisione a parte diverge dal compositore senza che niente '
          'diventi rosso.',
    );
  });
}
