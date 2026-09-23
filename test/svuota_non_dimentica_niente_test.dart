import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

/// 🚨 **`svuota()` non deve dimenticare nessuna tabella** — 23/09/2026.
///
/// ══ ⛔ IL DIFETTO, TROVATO NEL GIRO UX ═════════════════════════════════════
///
/// `svuota()` gira in due momenti soli, ed entrambi non ammettono residui:
/// quando **entra una persona diversa** su questo telefono, e quando si
/// **cancella l'account**.
///
/// ⛔ Era un **elenco scritto a mano**, e ne mancavano **undici su ventidue**:
/// il diario alimentare (che vive solo sul telefono dal 22/09), i preferiti, il
/// profilo, i documenti importati, i consigli, le foto degli alimenti e le
/// **tracce GPS delle uscite all'aperto** — il dato più sensibile che l'app
/// tenga.
///
/// 🚨 Verificato sull'emulatore, non dedotto: dopo che un secondo account era
/// entrato, `sqlite_sequence` diceva 16 sedute e 183 serie cancellate, e le
/// nove voci di diario della persona precedente erano ancora lì, leggibili da
/// chi era appena entrato.
///
/// ══ 💡 PERCHÉ QUESTO TEST ENUMERA ═════════════════════════════════════════
///
/// Un test che controllasse «il diario è vuoto? i percorsi sono vuoti?»
/// sarebbe **lo stesso elenco a mano**, spostato di un file: la tabella nuova
/// di domani non la guarderebbe nessuno, ed è esattamente così che il difetto è
/// nato due volte (25/08 e 23/09).
///
/// ⚠️ Qui si scorre `allTables`. Una tabella aggiunta domani entra in questo
/// controllo **da sola**, e se `svuota()` la dimentica il test diventa rosso
/// senza che nessuno debba ricordarsi di niente.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  test('dopo svuota() nessuna tabella ha più righe', () async {
    // ── Si riempiono le tabelle che l'elenco a mano dimenticava.
    await archivio.scriviVoceDiario(
      VociDiarioCompanion.insert(
        mangiatoIl: DateTime(2026, 9, 20, 8),
        pasto: 'breakfast',
        descrizione: 'Porridge di avena e mirtilli',
        scrittaIl: Value(DateTime(2026, 9, 20, 8)),
      ),
    );

    final primaDelloSvuoto = await _righePerTabella(archivio);

    expect(
      primaDelloSvuoto.values.where((q) => q > 0),
      isNotEmpty,
      reason: 'il test non prova niente se parte da un archivio vuoto',
    );

    await archivio.svuota();

    final dopo = await _righePerTabella(archivio);
    final rimaste = dopo.entries.where((e) => e.value > 0).toList();

    expect(
      rimaste,
      isEmpty,
      reason: 'tabelle non svuotate: ${rimaste.map((e) => e.key).join(', ')}',
    );
  });

  /// ⚠️ **L'altra metà, e tiene ferma una promessa diversa.**
  ///
  /// 📌 Il dialogo di «Cancellare i dati?» nomina *«sonno, HRV, battito,
  /// calorie e allenamenti»*: non il diario. ⛔ Quando `svuota()` è passata a
  /// enumerare tutte le tabelle, farla chiamare anche da lì avrebbe cancellato
  /// il diario dietro una frase che non lo nomina — un guasto **prodotto da una
  /// correzione**, che è il modo peggiore di introdurne uno.
  test('la cancellazione dei soli dati di salute non tocca il diario', () async {
    await archivio.scriviVoceDiario(
      VociDiarioCompanion.insert(
        mangiatoIl: DateTime(2026, 9, 20, 8),
        pasto: 'breakfast',
        descrizione: 'Porridge di avena e mirtilli',
        scrittaIl: Value(DateTime(2026, 9, 20, 8)),
      ),
    );

    await archivio.svuotaISoliDatiDiSalute();

    final dopo = await _righePerTabella(archivio);

    expect(dopo['voci_diario'], 1, reason: 'il diario non era fra i nominati');
    expect(dopo['campioni_sonno'], 0);
    expect(dopo['sedute_allenamento'], 0);
    expect(dopo['percorsi_degli_allenamenti'], 0);
  });
}

/// Quante righe ha ogni tabella, enumerandole dal database stesso.
Future<Map<String, int>> _righePerTabella(ArchivioSalute archivio) async {
  final conta = <String, int>{};

  for (final tabella in archivio.allTables) {
    final riga = await archivio
        .customSelect(
          'select count(*) as q from "${tabella.actualTableName}"',
          readsFrom: {tabella},
        )
        .getSingle();

    conta[tabella.actualTableName] = riga.read<int>('q');
  }

  return conta;
}
