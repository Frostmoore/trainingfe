import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

/// Il trasloco degli allenamenti — FASE 11.3, 21/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Non la chiamata HTTP — quella la prova `MigrazioneAllenamentiTest` di là.
/// **Le due proprietà dell'archivio da cui dipende che nessuno perda dati:**
///
/// | | |
/// |---|---|
/// | **non duplica** | `idServer` riconosce una seduta già importata |
/// | **conta il vero** | i conteggi si leggono dall'archivio, non dal pacchetto |
///
/// ⚠️ Il primo serve perché il trasloco può girare **due volte**: fra la
/// scrittura e la conferma l'app può morire, e il server segna «fatto» solo
/// dopo. 🚨 Senza, il secondo tentativo raddoppierebbe lo storico — e con esso
/// il volume settimanale e le calorie, che sono numeri credibili anche quando
/// sono il doppio del vero.
///
/// Il secondo è la differenza fra un controllo e un rito: contare quello che si
/// è **ricevuto** proverebbe che il server ha mandato qualcosa, non che il
/// telefono l'abbia scritto.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  Future<int> importa(int idServer, {int? kcal, String? scheda}) =>
      archivio.importaSeduta(
        idServer: idServer,
        iniziataIl: DateTime(2026, 8, 20, 18),
        finitaIl: DateTime(2026, 8, 20, 19),
        nomeScheda: scheda,
        kcal: kcal,
      );

  test('🚨 rifare il trasloco NON duplica le sedute', () async {
    final primo = await importa(42, kcal: 400);
    final secondo = await importa(42, kcal: 400);

    // È la stessa riga, non una seconda.
    expect(secondo, primo);
    expect(await archivio.sedute(), hasLength(1));
  });

  test('una seconda passata AGGIORNA quello che è cambiato', () async {
    /*
     * 💡 Non è solo «non duplicare»: fra il primo trasloco e il secondo, chi ha
     * corretto le calorie a mano sul server deve ritrovare il numero nuovo.
     * ⚠️ Ignorare la riga esistente lascerebbe per sempre il valore vecchio.
     */
    final id = await importa(42, kcal: 400, scheda: 'Full body A');
    await importa(42, kcal: 800, scheda: 'Full body B');

    final seduta = (await archivio.sedute()).single;
    expect(seduta.id, id);
    expect(seduta.kcal, 800);
    expect(seduta.nomeScheda, 'Full body B');
  });

  test('sedute diverse restano diverse', () async {
    await importa(42);
    await importa(43);

    expect(await archivio.sedute(), hasLength(2));
  });

  test('le serie si legano all\'id LOCALE, non a quello del server', () async {
    /*
     * 🚨 È il punto in cui si sbaglia: `idServer` è 42, ma la riga locale ha un
     * `id` suo — quasi sempre 1. ⚠️ Legare le serie a 42 vorrebbe dire serie
     * orfane, cioè uno storico con sedute senza esercizi e un volume a zero.
     */
    final locale = await importa(42);
    expect(locale, isNot(42));

    await archivio.registraSerie(
      SerieDelleSeduteCompanion.insert(
        sedutaId: locale,
        esercizioId: 7,
        nomeEsercizio: 'Panca piana',
        met: const Value(6),
        numero: 1,
        ripetizioni: const Value(10),
        pesoKg: const Value(60),
      ),
    );

    final serie = await archivio.serieDi(locale);
    expect(serie, hasLength(1));
    expect(serie.first.met, 6.0);
  });

  test('i conteggi si leggono DALL\'archivio', () async {
    final id = await importa(42);

    await archivio.registraSerie(
      SerieDelleSeduteCompanion.insert(
        sedutaId: id,
        esercizioId: 1,
        nomeEsercizio: 'Squat',
        numero: 1,
      ),
    );
    await archivio.registraSerie(
      SerieDelleSeduteCompanion.insert(
        sedutaId: id,
        esercizioId: 1,
        nomeEsercizio: 'Squat',
        numero: 2,
      ),
    );

    await archivio.dichiaraBruciate(DateTime(2026, 8, 20), 700);

    final conteggi = await archivio.conteggiDelTrasloco();

    /*
     * 🚨 Le chiavi sono **quelle che il server si aspetta**. ⚠️ Se qui
     * comparisse `sedute` invece di `sessions`, il server rifiuterebbe con
     * `conteggi_diversi` e il trasloco non finirebbe mai — senza che nessuno
     * capisca perché, perché i numeri sarebbero giusti.
     */
    expect(conteggi, {'sessions': 1, 'sets': 2, 'daily_burns': 1});
  });

  test('un archivio vuoto conta zero, non niente', () async {
    // 💡 Serve a chi non ha mai registrato un allenamento: deve poter
    // dichiarare «fatto, zero righe» e uscire dai non migrati.
    expect(await archivio.conteggiDelTrasloco(), {
      'sessions': 0,
      'sets': 0,
      'daily_burns': 0,
    });
  });

  test('le sedute importate finiscono nel backup', () async {
    // 🚨 Dopo la FASE 11 il backup è l'unica copia: il server non le avrà più.
    final id = await importa(42, kcal: 400, scheda: 'Full body A');
    await archivio.registraSerie(
      SerieDelleSeduteCompanion.insert(
        sedutaId: id,
        esercizioId: 1,
        nomeEsercizio: 'Squat',
        numero: 1,
      ),
    );

    final dati = await archivio.esportaPerBackup();

    expect(dati['sedute_allenamento'], hasLength(1));
    expect(dati['serie_delle_sedute'], hasLength(1));
  });
}
