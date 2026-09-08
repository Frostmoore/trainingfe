import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/local_cache.dart';
import 'package:training_companion/src/features/acquisti/data/spia_dell_abbonamento.dart';

/// 👁️ La spia dell'abbonamento — 08/09/2026.
///
/// ══ 🚨 IL DIFETTO CHE QUESTO FILE DIFENDE ═════════════════════════════════
///
/// 📌 Il committente: *«mi sono tolto l'abbonamento, ho chiuso l'app e l'ho
/// riaperta, poi ho di nuovo chiuso l'app, mi sono dato l'abbonamento e ho
/// riaperto l'app, e non mi è apparsa nessuna modale»*.
///
/// ⛔ **Due difetti sommati, e nessuno dei due dava un errore.**
///
/// 1. il confronto stava **in memoria**, e chiudendo l'app il valore
///    precedente moriva con il processo;
/// 2. si guardava `abbonatoProvider`, che vale `true` quando il profilo non è
///    ancora arrivato: ogni avvio partiva da `true`, quindi il passaggio
///    `false → true` non poteva verificarsi **mai**.
///
/// 🚨 L'ultimo test di questo file riproduce **esattamente** la sequenza
/// riferita, contenitore per contenitore: è quello che va guardato se un
/// giorno la modale smettesse di comparire.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Un contenitore nuovo con la **stessa** memoria del telefono.
  ///
  /// 💡 È il modo di simulare «ho chiuso e riaperto l'app»: il processo cambia,
  /// le preferenze no.
  Future<ProviderContainer> app() async {
    final c = ProviderContainer(
      overrides: [
        localCacheProvider.overrideWithValue(await LocalCache.open()),
      ],
    );

    addTearDown(c.dispose);

    return c;
  }

  test('🤷 non sapere non è un cambiamento', () async {
    final c = await app();

    expect(
      await c.read(spiaDellAbbonamentoProvider).confronta(null),
      CambioDellAbbonamento.nessuno,
    );

    /*
     * 🚨 **E non deve nemmeno scrivere niente.** Se un profilo non ancora
     * arrivato scrivesse `false`, al primo giro con la rete lenta la persona si
     * vedrebbe «il tuo abbonamento è scaduto» — che è il difetto opposto, e
     * peggiore.
     */
    final cache = c.read(localCacheProvider);

    expect(cache.getBool(SpiaDellAbbonamento.chiave), isNull);
  });

  test('🆕 la prima volta in assoluto si registra e basta', () async {
    final c = await app();

    /*
     * ⛔ Chi installa l'app **già abbonato** non deve trovarsi una festa per
     * qualcosa che ha comprato tre mesi fa: non è un cambiamento, è il primo
     * dato che vediamo.
     */
    expect(
      await c.read(spiaDellAbbonamentoProvider).confronta(true),
      CambioDellAbbonamento.nessuno,
    );

    expect(
      c.read(localCacheProvider).getBool(SpiaDellAbbonamento.chiave),
      isTrue,
    );
  });

  test('🛑 e quando scade lo dice', () async {
    final c = await app();
    final spia = c.read(spiaDellAbbonamentoProvider);

    await spia.confronta(true);

    expect(await spia.confronta(false), CambioDellAbbonamento.appenaScaduto);
  });

  test('🔁 una volta sola: al secondo giro non è più un cambiamento', () async {
    final c = await app();
    final spia = c.read(spiaDellAbbonamentoProvider);

    await spia.confronta(false);
    await spia.confronta(true);

    /*
     * ⚠️ **Senza questo, la modale tornerebbe a ogni rientro nell'app.** La
     * spia si aggiorna al primo confronto proprio per questo.
     */
    expect(await spia.confronta(true), CambioDellAbbonamento.nessuno);
  });

  test('🚨 LA SEQUENZA RIFERITA: chiudo, mi abbono, riapro', () async {
    /*
     * 📌 *«mi sono tolto l'abbonamento, ho chiuso l'app e l'ho riaperta, poi ho
     * di nuovo chiuso l'app, mi sono dato l'abbonamento e ho riaperto l'app»*.
     *
     * 🚨 Ogni `app()` è un **processo nuovo**: quello che sopravvive sono solo
     * le preferenze. ⛔ Con il confronto in memoria, qui non usciva niente.
     */

    // ── Primo avvio: non abbonato ──────────────────────────────────────
    final primo = await app();
    await primo.read(spiaDellAbbonamentoProvider).confronta(false);

    // ── Secondo avvio: sempre non abbonato, e infatti tace ─────────────
    final secondo = await app();

    expect(
      await secondo.read(spiaDellAbbonamentoProvider).confronta(false),
      CambioDellAbbonamento.nessuno,
    );

    // ── Terzo avvio, dopo essersi abbonato ─────────────────────────────
    final terzo = await app();

    expect(
      await terzo.read(spiaDellAbbonamentoProvider).confronta(true),
      CambioDellAbbonamento.appenaAbbonato,
      reason: 'è il caso riferito: qui la modale non compariva',
    );
  });
}
