import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

/// Le sedute di allenamento nell'archivio locale — FASE 11.1, 21/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// 📌 Il committente: *«Nessun allenamento deve risiedere sul server, devono
/// stare tutti nell'app»*.
///
/// ⚠️ Questa è la **prima metà** del trasloco: le tabelle ci sono, ma nessuno
/// ci scrive ancora — il player continua a parlare col server finché la
/// migrazione (11.3) non ha girato. 🚨 Creare le tabelle e spostare il player
/// nello stesso passo vorrebbe dire perdere le sedute di chi aggiorna prima
/// che la migrazione sia passata.
///
/// 💡 Quindi qui si prova **l'archivio**, non l'interfaccia: che sappia aprire
/// una seduta, tenerla aperta, chiuderla, e che le sue righe finiscano nel
/// backup — che è la regola non negoziabile del committente.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  test('una seduta aperta resta aperta, e si ritrova', () async {
    final id = await archivio.apriSeduta(nomeScheda: 'Full body A');

    /*
     * 🚨 È il caso che conta più di tutti: chi si allena mette giù il telefono,
     * e il sistema può uccidere l'app in qualunque momento. ⚠️ Se la seduta
     * aperta non sopravvivesse, si perderebbero le serie già fatte — e sono
     * l'unica cosa che nessuno può ricostruire a memoria.
     */
    final aperta = await archivio.sedutaAperta();

    expect(aperta, isNotNull);
    expect(aperta!.id, id);
    expect(aperta.finitaIl, isNull);
    expect(aperta.nomeScheda, 'Full body A');
  });

  test('chiusa, non è più «aperta»', () async {
    final id = await archivio.apriSeduta();
    await archivio.chiudiSeduta(id, kcal: 320);

    expect(await archivio.sedutaAperta(), isNull);

    final tutte = await archivio.sedute();
    expect(tutte, hasLength(1));
    expect(tutte.first.finitaIl, isNotNull);
    expect(tutte.first.kcal, 320);
    expect(tutte.first.kcalAMano, isFalse);
  });

  test('la più recente, se per errore ne restassero due aperte', () async {
    /*
     * ⚠️ Non dovrebbe succedere, ma se succede riprendere la **più vecchia**
     * sarebbe la scelta peggiore: si scriverebbero le serie di oggi dentro la
     * seduta di ieri, e nessuno se ne accorgerebbe fino allo storico.
     */
    await archivio.apriSeduta(quando: DateTime(2026, 8, 20, 18));
    final recente = await archivio.apriSeduta(
      quando: DateTime(2026, 8, 21, 18),
    );

    expect((await archivio.sedutaAperta())!.id, recente);
  });

  test('le calorie a mano si segnano COME a mano', () async {
    /*
     * 🚨 Le due scritture non si separano mai. ⚠️ `kcal` senza `kcalAMano` fa
     * credere a un ricalcolo automatico di poter sovrascrivere una correzione
     * della persona — ed è esattamente il difetto che `kcal_source` evitava
     * sul server.
     */
    final id = await archivio.apriSeduta();
    await archivio.correggiKcalSeduta(id, 800);

    final seduta = (await archivio.sedute()).first;
    expect(seduta.kcal, 800);
    expect(seduta.kcalAMano, isTrue);
  });

  test('chiudere senza kcal NON azzera un numero già scritto', () async {
    // ⚠️ La differenza fra «non lo so» e «zero» vale anche qui.
    final id = await archivio.apriSeduta();
    await archivio.correggiKcalSeduta(id, 800);
    await archivio.chiudiSeduta(id);

    final seduta = (await archivio.sedute()).first;
    expect(seduta.kcal, 800);
    expect(seduta.kcalAMano, isTrue);
  });

  test('riscrivere la stessa serie la sostituisce, non la duplica', () async {
    final id = await archivio.apriSeduta();

    Future<void> panca(int ripetizioni, double peso) =>
        archivio.registraSerie(
          SerieDelleSeduteCompanion.insert(
            sedutaId: id,
            esercizioId: 7,
            nomeEsercizio: 'Panca piana',
            numero: 3,
            ripetizioni: Value(ripetizioni),
            pesoKg: Value(peso),
          ),
        );

    await panca(8, 60);
    // 💡 Correggere un numero sbagliato **è** quello che si vuole qui: al
    // contrario degli allenamenti dell'orologio, non c'è nessuna scelta della
    // persona da difendere da una risincronizzazione.
    await panca(10, 62.5);

    final serie = await archivio.serieDi(id);
    expect(serie, hasLength(1));
    expect(serie.first.ripetizioni, 10);
    expect(serie.first.pesoKg, 62.5);
  });

  test('i mezzi chili si conservano', () async {
    // 🚨 I manubri da 7.5 kg esistono, e arrotondarli falserebbe il volume
    // settimanale di chi li usa.
    final id = await archivio.apriSeduta();
    await archivio.registraSerie(
      SerieDelleSeduteCompanion.insert(
        sedutaId: id,
        esercizioId: 1,
        nomeEsercizio: 'Curl',
        numero: 1,
        pesoKg: const Value(7.5),
      ),
    );

    expect((await archivio.serieDi(id)).first.pesoKg, 7.5);
  });

  test('le serie di più sedute arrivano in una query sola', () async {
    final a = await archivio.apriSeduta();
    final b = await archivio.apriSeduta();

    for (final (seduta, nome) in [(a, 'Squat'), (b, 'Stacco')]) {
      await archivio.registraSerie(
        SerieDelleSeduteCompanion.insert(
          sedutaId: seduta,
          esercizioId: 2,
          nomeEsercizio: nome,
          numero: 1,
        ),
      );
    }

    final per = await archivio.serieDiPiuSedute([a, b]);

    expect(per[a]!.single.nomeEsercizio, 'Squat');
    expect(per[b]!.single.nomeEsercizio, 'Stacco');

    // ⚠️ Con una lista vuota non si interroga il database a vuoto.
    expect(await archivio.serieDiPiuSedute([]), isEmpty);
  });

  test('cancellare la seduta si porta via le sue serie', () async {
    /*
     * 🚨 **Il `cascade` dichiarato NON basta**, e questo test è il motivo per
     * cui si sa: SQLite non applica le chiavi esterne senza
     * `PRAGMA foreign_keys = ON`, e questo archivio non lo accende — perché
     * accenderlo romperebbe `ripristinaDaBackup()`, che riscrive le tabelle in
     * ordine di enumerazione.
     *
     * ⛔ Le serie si cancellano a mano. Senza, resterebbero righe orfane che
     * nessuna schermata mostra e che il backup porta in giro per sempre.
     */
    final id = await archivio.apriSeduta();
    await archivio.registraSerie(
      SerieDelleSeduteCompanion.insert(
        sedutaId: id,
        esercizioId: 3,
        nomeEsercizio: 'Rematore',
        numero: 1,
      ),
    );

    await archivio.cancellaSeduta(id);

    expect(await archivio.serieDi(id), isEmpty);
  });

  test('le bruciate a mano sono UNA per giorno', () async {
    /*
     * 🚨 È una dichiarazione complessiva («oggi ho bruciato 800»), non un
     * contributo. ⚠️ Permetterne due vorrebbe dire sommarle, e chi corregge il
     * numero si ritroverebbe il doppio.
     */
    final oggi = DateTime(2026, 8, 21);

    await archivio.dichiaraBruciate(oggi, 800);
    await archivio.dichiaraBruciate(oggi, 650);

    expect(await archivio.bruciateAManoDel(oggi), 650);

    // 💡 L'ora non conta: si normalizza a mezzanotte.
    expect(await archivio.bruciateAManoDel(DateTime(2026, 8, 21, 19, 30)), 650);

    await archivio.togliBruciateAMano(oggi);
    expect(await archivio.bruciateAManoDel(oggi), isNull);
  });

  test('le bruciate a mano si leggono per intervallo', () async {
    await archivio.dichiaraBruciate(DateTime(2026, 8, 19), 500);
    await archivio.dichiaraBruciate(DateTime(2026, 8, 21), 700);

    final per = await archivio.bruciateAManoFra(
      DateTime(2026, 8, 20),
      DateTime(2026, 8, 22),
    );

    expect(per, hasLength(1));
    expect(per[DateTime(2026, 8, 21)], 700);
  });

  test('🚨 le tabelle nuove finiscono NEL BACKUP', () async {
    /*
     * ══ 🚨 LA REGOLA NON NEGOZIABILE ═══════════════════════════════════════
     *
     * 📌 Il committente: *«da adesso in poi ricordati che ogni volta che
     * abbiamo un nuovo dato o un nuovo file o qualsiasi altra cosa, questo deve
     * comunque finire in qualche modo nel backup»*.
     *
     * ⚠️ E dopo la FASE 11 il backup è **l'unica copia** di questi dati: il
     * server non li avrà più. 🚨 Una tabella fuori dall'esportazione non
     * darebbe nessun errore — darebbe un ripristino che riporta indietro tutto
     * tranne gli allenamenti, e lo si scoprirebbe il giorno che serve.
     *
     * 💡 Ci finiscono da sole perché `esportaPerBackup()` enumera `allTables`.
     * Questo test esiste perché quel «da sole» smetta di essere una speranza.
     */
    final id = await archivio.apriSeduta(nomeScheda: 'Full body A');
    await archivio.registraSerie(
      SerieDelleSeduteCompanion.insert(
        sedutaId: id,
        esercizioId: 9,
        nomeEsercizio: 'Leg press',
        numero: 1,
        ripetizioni: const Value(12),
        pesoKg: const Value(120),
      ),
    );
    await archivio.dichiaraBruciate(DateTime(2026, 8, 21), 800);

    final dati = await archivio.esportaPerBackup();

    expect(dati['sedute_allenamento'], hasLength(1));
    expect(dati['serie_delle_sedute'], hasLength(1));
    expect(dati['bruciate_dichiarate'], hasLength(1));

    // ── E si ritrovano ripristinando ─────────────────────────────────────
    final secondo = ArchivioSalute.inMemoria();
    addTearDown(secondo.close);

    await secondo.ripristinaDaBackup(dati);

    final sedute = await secondo.sedute();
    expect(sedute, hasLength(1));
    expect(sedute.first.nomeScheda, 'Full body A');
    expect((await secondo.serieDi(sedute.first.id)).first.pesoKg, 120);
    expect(await secondo.bruciateAManoDel(DateTime(2026, 8, 21)), 800);
  });
}
