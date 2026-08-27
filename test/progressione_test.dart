import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/progressione.dart';

/// La progressione degli esercizi — 3b-I.A, 27/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Due cose che, sbagliate, **non danno nessun errore**:
///
/// 1. **La serie migliore di ogni seduta.** Un `GROUP BY` con `MAX(peso)` in
///    SQL avrebbe restituito le ripetizioni di una riga qualsiasi del gruppo:
///    numeri plausibili, attaccati al carico sbagliato. È il motivo per cui il
///    raggruppamento si fa in Dart — e quindi si può provare qui.
/// 2. **L'impronta dello storico.** Se cambiasse da sola, l'analisi
///    risulterebbe «superata» a ogni avvio e chi tocca il pulsante pagherebbe
///    un gettone per riscrivere la stessa cosa.
void main() {
  group('i tipi puri', () {
    test('la serie migliore è quella col carico più alto', () {
      final leggera = PuntoDiProgressione(
        data: DateTime(2026, 8, 1),
        carico: 40,
        ripetizioni: 12,
      );

      final pesante = PuntoDiProgressione(
        data: DateTime(2026, 8, 1),
        carico: 60,
        ripetizioni: 6,
      );

      /*
       * 🚨 **Il volume direbbe il contrario**: 40 × 12 = 480 batte 60 × 6 = 360.
       * ⛔ È vero per la fisica e falso per come le persone leggono i propri
       * progressi — «sono arrivato a sessanta» non «ho fatto 480».
       */
      expect(pesante.batte(leggera), isTrue);
      expect(leggera.batte(pesante), isFalse);
    });

    test('a pari carico vincono le ripetizioni', () {
      final poche = PuntoDiProgressione(
        data: DateTime(2026, 8, 1),
        carico: 50,
        ripetizioni: 8,
      );

      final tante = PuntoDiProgressione(
        data: DateTime(2026, 8, 1),
        carico: 50,
        ripetizioni: 10,
      );

      expect(tante.batte(poche), isTrue);
    });

    test('a corpo libero la progressione sono le ripetizioni', () {
      final p = PuntoDiProgressione(
        data: DateTime(2026, 8, 1),
        ripetizioni: 14,
      );

      // ⛔ Senza questo ripiego la sparkline degli esercizi senza carico
      // sarebbe vuota, cioè direbbe che non è successo niente.
      expect(p.valore, 14);
    });

    test('un andamento sconosciuto diventa «poco storico», non «fermo»', () {
      // 🚨 Un ripiego su `fermo` sarebbe un'affermazione: direbbe che non stai
      // progredendo quando in realtà non lo sappiamo.
      expect(Andamento.da('boh'), Andamento.pocoStorico);
      expect(Andamento.da(null), Andamento.pocoStorico);
      expect(Andamento.da('in_salita'), Andamento.inSalita);
    });

    test('con una sola seduta non vale la pena chiamare il modello', () {
      final una = {
        7: [PuntoDiProgressione(data: DateTime(2026, 8, 1), carico: 50)],
      };

      expect(valeLaPenaAnalizzare(una), isFalse);

      final due = {
        7: [
          PuntoDiProgressione(data: DateTime(2026, 8, 1), carico: 50),
          PuntoDiProgressione(data: DateTime(2026, 8, 8), carico: 52.5),
        ],
      };

      expect(valeLaPenaAnalizzare(due), isTrue);
    });
  });

  group('l\'andamento letto dai punti', () {
    PuntoDiProgressione p(int giorno, {double? kg, int? reps}) =>
        PuntoDiProgressione(
          data: DateTime(2026, 8, giorno),
          carico: kg,
          ripetizioni: reps,
        );

    test('a carico fermo, le ripetizioni che salgono sono una salita', () {
      /*
       * ⛔ **Il difetto riferito il 27/08/2026**: «oggi ho cambiato le rep di un
       * esercizio e mi scrive "Stabile"».
       *
       * 🚨 La prima versione guardava `valore`, cioè **il carico se c'era**: a
       * parità di bilanciere le ripetizioni non contavano niente. Il numero era
       * giusto e la risposta sbagliata — e a schermo sembrava che la funzione
       * non funzionasse affatto.
       */
      expect(
        andamentoDaiPunti([p(1, kg: 60, reps: 6), p(8, kg: 60, reps: 9)]),
        Andamento.inSalita,
      );
    });

    test('a carico fermo, le ripetizioni che scendono sono un calo', () {
      expect(
        andamentoDaiPunti([p(1, kg: 60, reps: 10), p(8, kg: 60, reps: 6)]),
        Andamento.inCalo,
      );
    });

    test('il carico batte le ripetizioni, come nella serie migliore', () {
      // 💡 Meno ripetizioni ma più carico è una salita: è così che le persone
      // leggono i propri progressi, e un volume calcolato direbbe il contrario.
      expect(
        andamentoDaiPunti([p(1, kg: 60, reps: 10), p(8, kg: 70, reps: 6)]),
        Andamento.inSalita,
      );
    });

    test('fermi tutti e due è «stabile» davvero', () {
      expect(
        andamentoDaiPunti([p(1, kg: 60, reps: 8), p(8, kg: 60, reps: 8)]),
        Andamento.fermo,
      );
    });

    test('a corpo libero contano solo le ripetizioni', () {
      expect(
        andamentoDaiPunti([p(1, reps: 8), p(8, reps: 12)]),
        Andamento.inSalita,
      );
    });

    test('senza carico e senza ripetizioni non si dice «stabile»', () {
      // ⛔ È l'esercizio a tempo: dire «stabile» sarebbe un'affermazione su un
      // dato che non abbiamo.
      expect(andamentoDaiPunti([p(1), p(8)]), Andamento.pocoStorico);
    });

    test('mezzo chilo su cento non è una tendenza', () {
      // 💡 La soglia dell'1%: una freccia che cambia verso a ogni seduta non la
      // guarda più nessuno.
      expect(
        andamentoDaiPunti([p(1, kg: 100, reps: 8), p(8, kg: 100.5, reps: 8)]),
        Andamento.fermo,
      );
    });

    test('con un punto solo non c\'è niente da dire', () {
      expect(andamentoDaiPunti([p(1, kg: 60, reps: 8)]), Andamento.pocoStorico);
    });
  });

  group('l\'impronta dello storico', () {
    Map<int, List<PuntoDiProgressione>> storia({double ultimo = 60}) => {
      7: [
        PuntoDiProgressione(data: DateTime(2026, 8, 1), carico: 55),
        PuntoDiProgressione(data: DateTime(2026, 8, 8), carico: ultimo),
      ],
    };

    test('è stabile: due letture dello stesso storico coincidono', () {
      expect(improntaDelloStorico(storia()), improntaDelloStorico(storia()));
    });

    test('non cambia se cambia un carico', () {
      /*
       * 💡 **È voluto.** Quello che rende vecchia un'analisi è una **seduta
       * nuova**, non un refuso corretto a mano su una serie di marzo. ⛔
       * Includere i valori vorrebbe dire far ripagare un gettone per una
       * correzione che non cambia una parola del testo.
       */
      expect(
        improntaDelloStorico(storia(ultimo: 62.5)),
        improntaDelloStorico(storia()),
      );
    });

    test('cambia quando arriva una seduta nuova', () {
      final dopo = {
        7: [
          ...storia()[7]!,
          PuntoDiProgressione(data: DateTime(2026, 8, 15), carico: 62.5),
        ],
      };

      expect(
        improntaDelloStorico(dopo),
        isNot(improntaDelloStorico(storia())),
      );
    });

    test('non dipende dall\'ordine delle chiavi della mappa', () {
      final a = <int, List<PuntoDiProgressione>>{
        7: storia()[7]!,
        9: storia()[7]!,
      };

      final b = <int, List<PuntoDiProgressione>>{
        9: storia()[7]!,
        7: storia()[7]!,
      };

      // 🚨 Una mappa non promette l'ordine: senza il `sort` questa coppia
      // darebbe due impronte diverse per lo stesso storico, e l'analisi
      // risulterebbe superata a caso.
      expect(improntaDelloStorico(a), improntaDelloStorico(b));
    });
  });

  group('lo storico letto dall\'archivio', () {
    late ArchivioSalute archivio;

    setUp(() => archivio = ArchivioSalute.inMemoria());
    tearDown(() => archivio.close());

    /// Una seduta chiusa, con le sue serie.
    Future<void> seduta({
      required int scheda,
      required DateTime quando,
      required List<(int esercizio, double? peso, int? reps)> serie,
      bool chiusa = true,
    }) async {
      final id = await archivio.apriSeduta(
        schedaServerId: scheda,
        quando: quando,
      );

      var numero = 0;

      for (final s in serie) {
        numero++;

        await archivio.registraSerie(
          SerieDelleSeduteCompanion.insert(
            sedutaId: id,
            esercizioId: s.$1,
            nomeEsercizio: 'Esercizio ${s.$1}',
            numero: numero,
            pesoKg: Value(s.$2),
            ripetizioni: Value(s.$3),
          ),
        );
      }

      if (chiusa) await archivio.chiudiSeduta(id, quando: quando);
    }

    test('di ogni seduta tiene la serie migliore, con le SUE ripetizioni', () async {
      await seduta(
        scheda: 3,
        quando: DateTime(2026, 8, 1, 18),
        serie: [(7, 40, 12), (7, 60, 6), (7, 50, 10)],
      );

      await seduta(
        scheda: 3,
        quando: DateTime(2026, 8, 8, 18),
        serie: [(7, 62.5, 8)],
      );

      final storia = await archivio.storiaDegliEsercizi(3);

      expect(storia[7], hasLength(2));

      /*
       * ⚠️ **Le ripetizioni devono essere 6, non 12 né 10.** Questa è
       * l'asserzione per cui il file esiste: 6 sono le ripetizioni *di quella
       * serie da 60 kg*. Un `GROUP BY` in SQL avrebbe potuto rispondere 12 —
       * un numero che nessun test generico troverebbe sbagliato.
       */
      expect(storia[7]![0].carico, 60);
      expect(storia[7]![0].ripetizioni, 6);

      expect(storia[7]![1].carico, 62.5);
    });

    test('i punti sono in ordine, dal più vecchio al più recente', () async {
      await seduta(
        scheda: 3,
        quando: DateTime(2026, 8, 15),
        serie: [(7, 65, 5)],
      );

      await seduta(scheda: 3, quando: DateTime(2026, 8, 1), serie: [(7, 55, 8)]);

      final storia = await archivio.storiaDegliEsercizi(3);

      // ⛔ Al contrario, la sparkline disegnerebbe un calo dove c'è una salita.
      expect(storia[7]!.first.carico, 55);
      expect(storia[7]!.last.carico, 65);
    });

    test('una seduta ancora aperta non entra', () async {
      await seduta(scheda: 3, quando: DateTime(2026, 8, 1), serie: [(7, 55, 8)]);
      await seduta(scheda: 3, quando: DateTime(2026, 8, 8), serie: [(7, 60, 8)]);

      await seduta(
        scheda: 3,
        quando: DateTime(2026, 8, 15),
        // 🚨 Il riscaldamento di una seduta in corso: entrerebbe come un calo
        // che non è mai successo.
        serie: [(7, 20, 10)],
        chiusa: false,
      );

      final storia = await archivio.storiaDegliEsercizi(3);

      expect(storia[7], hasLength(2));
      expect(storia[7]!.last.carico, 60);
    });

    test('le sedute di un\'altra scheda non si mescolano', () async {
      await seduta(scheda: 3, quando: DateTime(2026, 8, 1), serie: [(7, 55, 8)]);
      await seduta(scheda: 4, quando: DateTime(2026, 8, 2), serie: [(7, 90, 3)]);

      final storia = await archivio.storiaDegliEsercizi(3);

      expect(storia[7], hasLength(1));
      expect(storia[7]!.single.carico, 55);
    });

    test('si tengono le ULTIME sedute, non le prime', () async {
      for (var i = 1; i <= 10; i++) {
        await seduta(
          scheda: 3,
          quando: DateTime(2026, 8, i),
          serie: [(7, 50 + i.toDouble(), 8)],
        );
      }

      final storia = await archivio.storiaDegliEsercizi(3, quanteSedute: 4);

      expect(storia[7], hasLength(4));

      /*
       * 🚨 Con un `take()` invece di prendere dalla coda, l'analisi parlerebbe
       * di com'era **sei mesi fa** — e sarebbe una frase vera, su dati veri,
       * completamente inutile.
       */
      expect(storia[7]!.first.carico, 57);
      expect(storia[7]!.last.carico, 60);
    });

    test('una serie senza carico e senza ripetizioni non è un punto', () async {
      await seduta(
        scheda: 3,
        quando: DateTime(2026, 8, 1),
        serie: [(7, null, null)],
      );

      await seduta(
        scheda: 3,
        quando: DateTime(2026, 8, 8),
        serie: [(7, null, null)],
      );

      // 💡 È l'esercizio a tempo: non ha nessuna progressione da raccontare, e
      // due punti a zero disegnerebbero una linea piatta che sembra un dato.
      expect(await archivio.storiaDegliEsercizi(3), isEmpty);
    });

    test('l\'analisi si riscrive, non si affianca', () async {
      await archivio.scriviLAnalisi(
        AnalisiDelleSchedeCompanion.insert(
          schedaServerId: const Value(3),
          righe: '[]',
          impronta: 'prima',
          fattaIl: DateTime(2026, 8, 20),
        ),
      );

      await archivio.scriviLAnalisi(
        AnalisiDelleSchedeCompanion.insert(
          schedaServerId: const Value(3),
          righe: '[]',
          impronta: 'dopo',
          fattaIl: DateTime(2026, 8, 27),
        ),
      );

      // ⛔ Due righe vorrebbero dire che l'app ne mostrerebbe una a caso.
      final riga = await archivio.analisiDellaScheda(3);

      expect(riga, isNotNull);
      expect(riga!.impronta, 'dopo');
    });
  });
}
