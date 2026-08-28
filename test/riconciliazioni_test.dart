import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

/// Lo storico segue l'esercizio quando viene fuso — 3b-O, 28/08/2026.
///
/// ══ 🚨 QUI SI PERDE TUTTO, IN SILENZIO ═══════════════════════════════════
///
/// 📌 *«Senza farmi perdere nulla, naturalmente»*.
///
/// ⛔ Il server può far puntare le schede a un altro esercizio, ma le serie
/// già registrate stanno **qui**, con l'id vecchio. Senza la riscrittura non
/// vengono cancellate: diventano **orfane**. E la differenza conta, perché una
/// riga cancellata la si nota e una riga orfana no — la progressione riparte
/// da zero e sembra solo che quell'esercizio non sia mai stato fatto.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  /// Una serie registrata per quell'esercizio, nella seduta indicata.
  Future<void> serie({
    required int seduta,
    required int esercizio,
    int numero = 1,
    double peso = 60,
  }) => archivio
      .into(archivio.serieDelleSedute)
      .insert(
        SerieDelleSeduteCompanion.insert(
          sedutaId: seduta,
          esercizioId: esercizio,
          nomeEsercizio: 'Esercizio $esercizio',
          numero: numero,
          ripetizioni: const Value(10),
          pesoKg: Value(peso),
        ),
      );

  Future<List<int>> esercizidelleSerie() async {
    final righe = await archivio.select(archivio.serieDelleSedute).get();

    return righe.map((r) => r.esercizioId).toList()..sort();
  }

  test('le serie passano al nuovo esercizio', () async {
    await serie(seduta: 1, esercizio: 900);
    await serie(seduta: 1, esercizio: 900, numero: 2);
    await serie(seduta: 2, esercizio: 901);

    final spostate = await archivio.applicaLeRiconciliazioni({900: 17});

    expect(spostate, 2);
    expect(await esercizidelleSerie(), [17, 17, 901]);
  });

  test('non tocca gli esercizi che nessuno ha fuso', () async {
    await serie(seduta: 1, esercizio: 901);

    await archivio.applicaLeRiconciliazioni({900: 17});

    expect(await esercizidelleSerie(), [901]);
  });

  /// ⚠️ Gira a **ogni** lettura del catalogo: la seconda volta non deve
  /// trovare più niente. 💡 Un'esecuzione «una sola volta» avrebbe avuto
  /// bisogno di ricordarsi di averla fatta — cioè di un flag che, perdendosi,
  /// si porta dietro lo storico.
  test('rilanciarla non fa niente', () async {
    await serie(seduta: 1, esercizio: 900);

    expect(await archivio.applicaLeRiconciliazioni({900: 17}), 1);
    expect(await archivio.applicaLeRiconciliazioni({900: 17}), 0);
    expect(await esercizidelleSerie(), [17]);
  });

  test('un rinvio su sé stesso non gira a vuoto', () async {
    await serie(seduta: 1, esercizio: 900);

    expect(await archivio.applicaLeRiconciliazioni({900: 900}), 0);
    expect(await esercizidelleSerie(), [900]);
  });

  test('senza rinvii non fa niente', () async {
    await serie(seduta: 1, esercizio: 900);

    expect(await archivio.applicaLeRiconciliazioni({}), 0);
  });

  /// 🚨 `SerieDelleSedute` è unica su `{seduta, esercizio, numero}`.
  ///
  /// ⛔ Se due esercizi vecchi finissero sullo **stesso** nuovo, nella stessa
  /// seduta e con lo stesso numero di serie, la riscrittura sbatterebbe contro
  /// il vincolo. Con una transazione sola, quel caso farebbe fallire **anche
  /// gli spostamenti giusti** — cioè un solo scontro perderebbe tutto il resto.
  test('uno scontro non porta giù gli altri spostamenti', () async {
    // Le due che si scontrano: stessa seduta, stesso numero, stesso arrivo.
    await serie(seduta: 1, esercizio: 900);
    await serie(seduta: 1, esercizio: 17);

    // E una che non c'entra niente, che deve spostarsi lo stesso.
    await serie(seduta: 2, esercizio: 901);

    await archivio.applicaLeRiconciliazioni({900: 17, 901: 42});

    expect(
      await esercizidelleSerie(),
      containsAll(<int>[17, 42]),
      reason: 'Lo scontro sulla prima ha impedito la seconda.',
    );
  });
}
