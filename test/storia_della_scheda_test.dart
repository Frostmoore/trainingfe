import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/data/storia_della_scheda.dart';

/// Come cambia una scheda nel tempo — 3b-I.E, 27/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// 📌 *«devi fare in modo che siamo sicuri che le modifiche il programma le
/// veda: cioè deve vedere com'era prima e com'era dopo»*.
///
/// Tre cose che, sbagliate, **non danno nessun errore**:
///
/// 1. **Un rinominare che sembra un cambio di programma.** Se il nome entrasse
///    nell'impronta, correggere un refuso genererebbe una versione — e più
///    avanti l'analisi direbbe «la scheda è cambiata» davanti a una virgola.
/// 2. **Una serata di composizione che diventa venti versioni**, seppellendo il
///    «com'era prima» vero.
/// 3. **Il primo cambio senza un prima**: senza la versione scritta alla
///    nascita, il confronto che serve la prima volta non esisterebbe.
void main() {
  /// Una scheda con un esercizio e le sue serie.
  String scheda(
    List<Map<String, Object?>> serie, {
    String nome = 'Panca piana',
    int? id = 7,
    String? note,
  }) => jsonEncode({
    'name': 'Scheda',
    'notes': ?note,
    'exercises': [
      {'name': nome, 'exercise_id': id, 'serie': serie},
    ],
  });

  Map<String, Object?> s({int? reps, double? peso, int? rec}) => {
    'reps': reps,
    'weight': peso,
    'rest_sec': rec,
  };

  group('l\'impronta della scheda', () {
    test('non cambia se cambia il nome o una nota', () {
      /*
       * ⛔ **Rinominare non è un cambio di programma.** Se lo fosse, la storia
       * si riempirebbe di versioni identiche e l'analisi direbbe «la scheda è
       * cambiata» davanti a un refuso corretto.
       */
      final a = scheda([s(reps: 8)], nome: 'Panca piana');
      final b = scheda([s(reps: 8)], nome: 'Panca piana', note: 'con calma');

      expect(improntaDellaScheda(a), improntaDellaScheda(b));
    });

    test('cambia se cambiano le ripetizioni', () {
      expect(
        improntaDellaScheda(scheda([s(reps: 8)])),
        isNot(improntaDellaScheda(scheda([s(reps: 10)]))),
      );
    });

    test('cambia se si aggiunge una serie', () {
      expect(
        improntaDellaScheda(scheda([s(reps: 8), s(reps: 8)])),
        isNot(improntaDellaScheda(scheda([s(reps: 8)]))),
      );
    });

    test('un JSON illeggibile non fa esplodere niente', () {
      // 🚨 La chiama la **scrittura di una scheda**: farla esplodere vorrebbe
      // dire non poter più salvare per un difetto in una funzione accessoria.
      expect(improntaDellaScheda('{rotto'), '');
    });
  });

  group('le differenze fra due versioni', () {
    test('una serie in più si vede come «serie: 3 → 4»', () {
      final cambi = differenzeFraSchede(
        scheda([s(reps: 8), s(reps: 8), s(reps: 8)]),
        scheda([s(reps: 8), s(reps: 8), s(reps: 8), s(reps: 8)]),
      );

      expect(cambi, hasLength(1));
      expect(cambi.single.cosa, 'serie');
      expect(cambi.single.prima, '3');
      expect(cambi.single.dopo, '4');
      expect(cambi.single.esercizioId, 7);
    });

    test('le ripetizioni uguali su tutte le serie si scrivono una volta', () {
      final cambi = differenzeFraSchede(
        scheda([s(reps: 12), s(reps: 12), s(reps: 12)]),
        scheda([s(reps: 15), s(reps: 15), s(reps: 15)]),
      );

      /*
       * 💡 **Un cambio per campo, non uno per serie.** ⛔ Tre righe che dicono
       * la stessa cosa riempirebbero di rumore il contesto dell'AI, e il
       * modello scriverebbe la frase guardando il rumore.
       */
      expect(cambi, hasLength(1));
      expect(cambi.single.cosa, 'ripetizioni');
      expect(cambi.single.prima, '12');
      expect(cambi.single.dopo, '15');
    });

    test('una piramide si scrive per intero', () {
      final cambi = differenzeFraSchede(
        scheda([s(reps: 10), s(reps: 10)]),
        scheda([s(reps: 12), s(reps: 10)]),
      );

      expect(cambi.single.dopo, '12-10');
    });

    test('lo zero dietro la virgola non compare', () {
      final cambi = differenzeFraSchede(
        scheda([s(reps: 8, peso: 60)]),
        scheda([s(reps: 8, peso: 62.5)]),
      );

      // ⛔ «60.0» sembra una precisione: dice che qualcuno ha misurato il
      // decimo di chilo.
      expect(cambi.single.prima, '60');
      expect(cambi.single.dopo, '62.5');
    });

    test('un esercizio aggiunto non ha un «da → a»', () {
      final prima = jsonEncode({
        'exercises': [
          {'name': 'Panca', 'exercise_id': 7, 'serie': [
            {'reps': 8},
          ]},
        ],
      });

      final dopo = jsonEncode({
        'exercises': [
          {'name': 'Panca', 'exercise_id': 7, 'serie': [
            {'reps': 8},
          ]},
          {'name': 'Lat machine', 'exercise_id': 9, 'serie': [
            {'reps': 10},
          ]},
        ],
      });

      final cambi = differenzeFraSchede(prima, dopo);

      expect(cambi, hasLength(1));
      expect(cambi.single.cosa, 'aggiunto');
      expect(cambi.single.esercizio, 'Lat machine');

      // ⛔ Inventare un «prima» qui direbbe una cosa falsa.
      expect(cambi.single.prima, isNull);
      expect(cambi.single.dopo, isNull);
    });

    test('due versioni identiche non producono niente', () {
      expect(
        differenzeFraSchede(scheda([s(reps: 8)]), scheda([s(reps: 8)])),
        isEmpty,
      );
    });

    test('i cambi di UN esercizio si estraggono in ordine di tempo', () {
      final versioni = [
        VersioneDellaScheda(
          quando: DateTime(2026, 8, 1),
          contenuto: scheda([s(reps: 8), s(reps: 8), s(reps: 8)]),
        ),
        VersioneDellaScheda(
          quando: DateTime(2026, 8, 10),
          contenuto: scheda([
            s(reps: 8),
            s(reps: 8),
            s(reps: 8),
            s(reps: 8),
          ]),
        ),
        VersioneDellaScheda(
          quando: DateTime(2026, 8, 20),
          contenuto: scheda([
            s(reps: 10),
            s(reps: 10),
            s(reps: 10),
            s(reps: 10),
          ]),
        ),
      ];

      final cambi = cambiDellEsercizio(versioni, 7);

      expect(cambi.map((c) => c.cosa), ['serie', 'ripetizioni']);

      // 💡 È quello che permette all'AI di dire «le ripetizioni sono scese da
      // quando la scheda è passata a quattro serie», invece di rileggere i
      // numeri che la persona ha già davanti.
      expect(cambi.first.dopo, '4');
      expect(cambi.last.dopo, '10');
    });

    test('di un altro esercizio non torna niente', () {
      final versioni = [
        VersioneDellaScheda(
          quando: DateTime(2026, 8, 1),
          contenuto: scheda([s(reps: 8)]),
        ),
        VersioneDellaScheda(
          quando: DateTime(2026, 8, 10),
          contenuto: scheda([s(reps: 10)]),
        ),
      ];

      expect(cambiDellEsercizio(versioni, 999), isEmpty);
    });
  });

  group('le versioni nell\'archivio', () {
    late ArchivioSalute archivio;

    setUp(() => archivio = ArchivioSalute.inMemoria());
    tearDown(() => archivio.close());

    Future<int> nuova(String contenuto) => archivio.aggiungiScheda(
      nome: 'Scheda',
      scheda: contenuto,
      mia: true,
      origine: 'app',
    );

    test('nasce già con la sua versione zero', () async {
      final id = await nuova(scheda([s(reps: 8)]));

      /*
       * 🚨 **Alla nascita e non alla prima modifica.** Registrandola solo
       * quando si cambia qualcosa, il «com'era prima» del primo cambio sarebbe
       * già perduto — cioè mancherebbe proprio il confronto che serve la prima
       * volta.
       */
      expect(await archivio.versioniDellaScheda(id), hasLength(1));
    });

    test('un cambio vero aggiunge una versione', () async {
      final id = await nuova(scheda([s(reps: 8)]));

      await archivio.aggiornaScheda(
        id: id,
        nome: 'Scheda',
        scheda: scheda([s(reps: 12)]),

        // ⚠️ Fuori dalla finestra di modifica, o si sostituirebbe.
        quando: DateTime.now().add(finestraDiModifica * 2),
      );

      final versioni = await archivio.versioniDellaScheda(id);

      expect(versioni, hasLength(2));

      final cambi = differenzeFraSchede(
        versioni.first.contenuto,
        versioni.last.contenuto,
      );

      expect(cambi.single.cosa, 'ripetizioni');
      expect(cambi.single.dopo, '12');
    });

    test('rinominare non aggiunge niente', () async {
      final id = await nuova(scheda([s(reps: 8)]));

      await archivio.aggiornaScheda(
        id: id,
        nome: 'Un altro nome',
        scheda: scheda([s(reps: 8)]),
      );

      // ⛔ Il contenuto allenante è lo stesso: non è un cambio di programma.
      expect(await archivio.versioniDellaScheda(id), hasLength(1));
    });

    test('una serata di modifiche resta una versione sola', () async {
      final id = await nuova(scheda([s(reps: 8)]));

      /*
       * 🚨 `aggiornaScheda` si chiama a **ogni** modifica: chi compone una
       * scheda salva venti volte in cinque minuti. ⛔ Senza la finestra, una
       * serata di lavoro seppellirebbe il «com'era prima» vero in fondo a venti
       * righe.
       */
      for (var i = 9; i <= 14; i++) {
        await archivio.aggiornaScheda(
          id: id,
          nome: 'Scheda',
          scheda: scheda([s(reps: i)]),
        );
      }

      final versioni = await archivio.versioniDellaScheda(id);

      expect(versioni, hasLength(2));

      // 💡 E quella che resta è **l'ultima**, non la prima della serie.
      expect(differenzeFraSchede(
        versioni.first.contenuto,
        versioni.last.contenuto,
      ).single.dopo, '14');
    });

    test('la prima versione non si perde mai', () async {
      final id = await nuova(scheda([s(reps: 8)]));

      // ⚠️ Dopo la nascita, come nella vita vera: una modifica datata **prima**
      // della creazione esiste solo nei ripristini, ed è il caso che
      // `_potaLeVersioni` gestisce guardando l'`id`.
      var quando = DateTime.now();

      for (var i = 0; i < quanteVersioni + 8; i++) {
        quando = quando.add(const Duration(days: 1));

        await archivio.aggiornaScheda(
          id: id,
          nome: 'Scheda',
          scheda: scheda([s(reps: 10 + i)]),
          quando: quando,
        );
      }

      final versioni = await archivio.versioniDellaScheda(
        id,
        quante: quanteVersioni + 10,
      );

      // ⛔ «Com'era all'inizio» è l'unico confronto che vale ancora fra sei
      // mesi: le versioni in mezzo invecchiano, quella no.
      expect(differenzeFraSchede(
        versioni.first.contenuto,
        versioni.last.contenuto,
      ).single.prima, '8');

      expect(versioni.length, lessThanOrEqualTo(quanteVersioni + 1));
    });

    test('una scheda che esisteva prima della v23 recupera il suo «prima»', () async {
      final id = await nuova(scheda([s(reps: 8)]));

      // 🚨 Si simula la riga vecchia: la scheda c'è, la sua storia no.
      await archivio.dimenticaLeVersioni(id);

      expect(await archivio.versioniDellaScheda(id), isEmpty);

      await archivio.aggiornaScheda(
        id: id,
        nome: 'Scheda',
        scheda: scheda([s(reps: 12)]),
        quando: DateTime.now().add(finestraDiModifica * 2),
      );

      final versioni = await archivio.versioniDellaScheda(id);

      /*
       * ⛔ Senza il recupero, la storia di queste schede comincerebbe dal
       * **secondo** cambio: la versione che sta per essere sovrascritta è
       * l'unica copia del «prima» che esista.
       */
      expect(versioni, hasLength(2));
      expect(differenzeFraSchede(
        versioni.first.contenuto,
        versioni.last.contenuto,
      ).single.prima, '8');
    });
  });
}
