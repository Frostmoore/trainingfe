import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/acquisti/data/gate_dell_abbonamento.dart';
import 'package:training_companion/src/features/health/health_controller.dart';
import 'package:training_companion/src/features/training/session_controller.dart';

/// 🔒 Un allenamento al giorno senza abbonamento — 08/09/2026.
///
/// ══ 📌 LA REGOLA ══════════════════════════════════════════════════════════
///
/// Il committente: *«un utente non abbonato può far partire dall'app un solo
/// allenamento al giorno»*.
///
/// ══ 🚨 COSA DIFENDE DAVVERO QUESTO FILE ═══════════════════════════════════
///
/// ⛔ **Non che il numero sia uno.** Quello si legge in una costante. 🚨 Difende
/// i **confini**, che sono le tre cose che si sbagliano davvero:
///
/// 1. il limite **non tocca gli abbonati** — il difetto che si nota subito;
/// 2. il limite **conta il giorno**, non la storia — quello di ieri non pesa;
/// 3. il limite **non conta gli allenamenti dell'orologio** — e questo è il
///    difetto che *non* si noterebbe: chi corre con l'orologio si troverebbe la
///    palestra chiusa senza aver premuto niente, e chiamerebbe «guasto» quello
///    che è un limite commerciale.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  /// Un contenitore che dice **solo** se è abbonato: il resto non serve.
  ///
  /// 💡 `abbonatoProvider` sovrascritto invece dell'utente intero — la regola
  /// vive dietro quel provider, e passare dall'autenticazione vorrebbe dire
  /// verificare tre cose per guardarne una.
  ProviderContainer conteiner({required bool abbonato}) {
    final c = ProviderContainer(
      overrides: [
        archivioSaluteProvider.overrideWithValue(archivio),
        abbonatoProvider.overrideWithValue(abbonato),
      ],
    );

    addTearDown(c.dispose);

    return c;
  }

  test(
    '⛔ il secondo allenamento di oggi non parte, senza abbonamento',
    () async {
      final c = conteiner(abbonato: false);
      final azioni = c.read(sessionActionsProvider);

      await azioni.start();

      /*
       * 🚨 **`await expectLater` e non `expect`**: `start()` e' asincrona, e un
       * `expect(() => future, throwsA(...))` senza attesa e' verde anche quando
       * l'eccezione non arriva mai — il test passerebbe **per il motivo
       * sbagliato**, che e' l'unica cosa peggiore di un test rosso.
       */
      await expectLater(
        azioni.start(),
        throwsA(isA<TroppiAllenamentiOggi>()),
        reason: 'il secondo del giorno deve fermarsi',
      );
    },
  );

  test('✅ e con l\'abbonamento ne partono quanti se ne vuole', () async {
    final c = conteiner(abbonato: true);
    final azioni = c.read(sessionActionsProvider);

    await azioni.start();
    await azioni.start();
    await azioni.start();

    expect(await archivio.quanteSeduteIl(DateTime.now()), 3);
  });

  test('🌅 quello di ieri non conta: il limite è del giorno', () async {
    /*
     * 🚨 **È la differenza fra un limite e una punizione.** Un contatore che
     * non si azzera trasformerebbe «uno al giorno» in «uno e basta», e nessuno
     * lo scoprirebbe finché non passa una notte.
     */
    await archivio.apriSeduta(
      quando: DateTime.now().subtract(const Duration(days: 1)),
    );

    final c = conteiner(abbonato: false);

    await c.read(sessionActionsProvider).start();

    expect(await archivio.quanteSeduteIl(DateTime.now()), 1);
  });

  test('⌚ gli allenamenti dell\'orologio non consumano il limite', () async {
    /*
     * ══ 🚨 IL CONFINE CHE CONTA ═══════════════════════════════════════════
     *
     * ⛔ Se `quanteSeduteIl` guardasse anche `AllenamentiDaOrologio`, chi esce
     * a correre col Zepp si troverebbe la palestra chiusa **senza aver premuto
     * niente**. 💡 Quel dato è suo e l'ha già prodotto: il limite riguarda una
     * funzione dell'app, non la sua giornata.
     */
    await archivio.scriviAllenamenti([
      AllenamentoDaOrologio(
        id: 0,
        fonte: 'com.huami.watch.hmwatchmanager',
        tipo: 'RUNNING',
        iniziatoIl: DateTime.now(),
        finitoIl: DateTime.now().add(const Duration(minutes: 40)),
        kcal: 400,
        nascosto: false,
        staccato: false,
        contaComeExtra: false,
      ),
    ]);

    final c = conteiner(abbonato: false);

    // ⛔ Non deve lanciare: l'orologio non ha consumato niente.
    await c.read(sessionActionsProvider).start();

    expect(await archivio.quanteSeduteIl(DateTime.now()), 1);
  });
}
