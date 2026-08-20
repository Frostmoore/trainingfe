import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/providers.dart';
import 'package:training_companion/src/core/storage/local_cache.dart';
import 'package:training_companion/src/features/dashboard/consiglio_da_mostrare.dart';
import 'package:training_companion/src/features/dashboard/dashboard_controller.dart';
import 'package:training_companion/src/features/privacy/consensi_controller.dart';

/// La card del consiglio non sparisce mai — 20/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// 📌 Il committente: *«la card del consiglio del giorno si deve sempre vedere
/// (a meno che io non l'abbia disabilitato), al limite si mostra il consiglio
/// del giorno precedente, se ancora non è pronto quello nuovo»*.
///
/// ⚠️ Spariva in **quattro** modi, e tre erano difetti. Il più frequente non è
/// quello che verrebbe in mente: il server tiene il consiglio in cache su una
/// chiave che comprende il **contesto**, quindi basta segnare un pasto perché si
/// rifaccia — e per i secondi che ci mette la card spariva. **Puniva l'uso
/// dell'app.**
void main() {
  late LocalCache cache;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cache = LocalCache(await SharedPreferences.getInstance());
  });

  /// 💡 Un contenitore con il consiglio e i consensi che decidiamo noi.
  ProviderContainer conta({
    required AsyncValue<Consiglio> consiglio,
    bool automatico = true,
  }) {
    final c = ProviderContainer(
      overrides: [
        localCacheProvider.overrideWithValue(cache),
        adviceProvider.overrideWith((ref) => switch (consiglio) {
              AsyncData(:final value) => Future.value(value),
              AsyncError(:final error) => Future<Consiglio>.error(error),
              // Un future che non si risolve mai: è «sta ancora caricando».
              _ => Completer<Consiglio>().future,
            }),
        consensiProvider.overrideWith(
          (ref) async => Consensi(consiglioAutomatico: automatico),
        ),
      ],
    );

    addTearDown(c.dispose);

    /*
     * ⚠️ **Serve un ascoltatore, o il provider muore prima di rispondere.**
     *
     * `consiglioDaMostrareProvider` è `autoDispose`: senza nessuno in ascolto,
     * `read(...future)` lo crea e lo butta nello stesso giro, e il future
     * fallisce con *«disposed during loading state»* invece di dare un valore.
     *
     * 💡 Nell'app l'ascoltatore è la schermata. Qui va messo a mano.
     */
    c.listen(consiglioDaMostrareProvider, (_, _) {}, fireImmediately: true);

    return c;
  }

  void ricorda(String testo, DateTime quando) => cache.setString(
        'consiglio.ultimo',
        jsonEncode({'testo': testo, 'generato_il': quando.toIso8601String()}),
      );

  test('un consiglio fresco si mostra, e si ricorda', () async {
    final c = conta(consiglio: const AsyncData(Consiglio(testo: 'Bevi di più')));

    final v = await c.read(consiglioDaMostrareProvider.future);

    expect(v.stato, StatoConsiglio.fresco);
    expect(v.testo, 'Bevi di più');

    /*
     * 🚨 Il ricordo si scrive **appena arriva**, non quando serve: il momento in
     * cui servirà è precisamente quello in cui non ce l'abbiamo.
     */
    expect(cache.getString('consiglio.ultimo'), contains('Bevi di più'));
  });

  group('Quando quello di oggi non c è ancora', () {
    /// ══ 🚨 Il caso più frequente ═════════════════════════════════════════
    ///
    /// Risposta vuota con l'interruttore acceso = il server lo sta rifacendo
    /// perché il contesto è cambiato. ⚠️ Prima qui la card spariva, e spariva a
    /// chi aveva appena segnato un pasto.
    test('mentre si rigenera si mostra quello di ieri', () async {
      ricorda('Il consiglio di ieri', DateTime(2026, 8, 19));

      final c = conta(consiglio: const AsyncData(Consiglio()));
      final v = await c.read(consiglioDaMostrareProvider.future);

      expect(v.stato, StatoConsiglio.vecchio);
      expect(v.testo, 'Il consiglio di ieri');
    });

    test('e anche mentre carica', () async {
      ricorda('Il consiglio di ieri', DateTime(2026, 8, 19));

      final c = conta(consiglio: const AsyncLoading());
      final v = await c.read(consiglioDaMostrareProvider.future);

      expect(v.stato, StatoConsiglio.vecchio);
    });

    /// ⚠️ **E anche se l'AI non risponde.** Il consiglio è un di più: che il
    /// modello sia irraggiungibile non è una buona ragione per far sparire un
    /// testo che abbiamo già in mano.
    test('e anche se l AI non risponde', () async {
      ricorda('Il consiglio di ieri', DateTime(2026, 8, 19));

      final c = conta(consiglio: AsyncError(Exception('giù'), StackTrace.empty));
      final v = await c.read(consiglioDaMostrareProvider.future);

      expect(v.stato, StatoConsiglio.vecchio);
    });

    /// 💡 La data si conserva, perché la card scrive «Consiglio del 19 agosto»
    /// e non un generico «vecchio»: una data dice **quanto** fidarsi.
    test('e si sa di quando è', () async {
      ricorda('Il consiglio di ieri', DateTime(2026, 8, 19));

      final c = conta(consiglio: const AsyncLoading());
      final v = await c.read(consiglioDaMostrareProvider.future);

      expect(v.generatoIl, DateTime(2026, 8, 19));
    });

    /// 🚨 Alla **primissima** apertura non c'è nessun ricordo: lì si dice che
    /// sta arrivando invece di lasciare un buco. ⚠️ Una card che compare e
    /// scompare fa saltare le tre card sotto, e chi stava per toccarne una tocca
    /// quella sbagliata.
    test('senza nessun ricordo si dice che sta arrivando', () async {
      final c = conta(consiglio: const AsyncLoading());
      final v = await c.read(consiglioDaMostrareProvider.future);

      expect(v.stato, StatoConsiglio.inArrivo);
    });
  });

  group('L eccezione del committente', () {
    /// 📌 *«a meno che io non l'abbia disabilitato»*. ⚠️ Mostrargli il consiglio
    /// di ieri sarebbe insistere dopo un no.
    test('con l interruttore spento non si mostra niente', () async {
      ricorda('Il consiglio di ieri', DateTime(2026, 8, 19));

      final c = conta(consiglio: const AsyncData(Consiglio()), automatico: false);
      final v = await c.read(consiglioDaMostrareProvider.future);

      expect(v.stato, StatoConsiglio.spento);
      expect(v.haTesto, isFalse);
    });

    /// 🚨 **Ma il consenso mancante vince su tutto**: non è qualcosa da
    /// aspettare, è qualcosa da **fare**, e l'unico posto in cui si fa è la
    /// schermata dei consensi.
    test('ma il consenso mancante si mostra comunque', () async {
      ricorda('Il consiglio di ieri', DateTime(2026, 8, 19));

      final c = conta(consiglio: const AsyncData(Consiglio(serveConsenso: true)));
      final v = await c.read(consiglioDaMostrareProvider.future);

      expect(v.stato, StatoConsiglio.serveConsenso);
    });
  });

  /// ⚠️ Un ricordo illeggibile si **butta**, non fa cadere la schermata: è una
  /// comodità, e il prezzo di perderla è rivedere il consiglio un istante dopo.
  test('un ricordo rotto non rompe niente', () async {
    await cache.setString('consiglio.ultimo', 'non e json');

    final c = conta(consiglio: const AsyncLoading());
    final v = await c.read(consiglioDaMostrareProvider.future);

    expect(v.stato, StatoConsiglio.inArrivo);
  });
}
