import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/health/health_controller.dart';
import 'package:training_companion/src/features/training/porta_giu_le_schede.dart';
import 'package:training_companion/src/features/training/training_controller.dart';

/// Le schede stanno in **un archivio solo** — 3b-B.17.6, 25/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// 📌 *«Che vuol dire stanno in una seconda tabella locale? Uniamole»*.
///
/// ⛔ Fino al 25/08 le schede arrivate in chat vivevano in `SchedeRicevute` e
/// quelle scese dal server in `SchedeSulTelefono`, ma l'elenco delle schede ne
/// leggeva **una sola**: una scheda mandata dal trainer via chat non compariva
/// fra le proprie, e non ci si poteva né allenare né assegnarla a un
/// allenamento del polso.
///
/// ⚠️ **Il primo test è quello che conta**: gli altri difendono le tre
/// protezioni che la fusione doveva portarsi dietro, e che erano la ragione per
/// cui la seconda tabella sembrava servire.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  /// Un contenitore in cui l'importazione dal server è **già stata fatta**.
  ///
  /// ⚠️ Senza questo `override`, `schedeUniteProvider` aspetterebbe una
  /// chiamata di rete che in un test non arriva mai.
  ProviderContainer contenitore() {
    final c = ProviderContainer(
      overrides: [
        archivioSaluteProvider.overrideWithValue(archivio),
        schedePortateGiuProvider.overrideWith((ref) async => null),
      ],
    );

    addTearDown(c.dispose);

    return c;
  }

  /// ⚠️ Torna `null` quando la scheda **non** è stata salvata: rifiutata, o
  /// più vecchia di quella che c'è. Un aiutante che desse per scontato il
  /// salvataggio esploderebbe proprio nei test che servono a provarlo.
  Future<int?> schedaDallaChat({
    int messaggioId = 1,
    String nome = 'Full body',
    String? origineId,
  }) async {
    await archivio.salvaSchedaDallaChat(
      messaggioId: messaggioId,
      nome: nome,
      scheda: jsonEncode({'name': nome, 'exercises': <dynamic>[]}),
      origineId: origineId,
    );

    final righe = await archivio.tutteLeSchede();

    return righe.isEmpty ? null : righe.first.id;
  }

  group('🗃️ un archivio solo', () {
    /// ⛔ **È il difetto vero.** Tutto il resto di questo file difende
    /// dettagli; questo difende il motivo per cui la fusione è stata fatta.
    test('una scheda arrivata in chat compare fra le proprie', () async {
      await schedaDallaChat(nome: 'Giorno 1');

      final schede = await contenitore().read(schedeUniteProvider.future);

      expect(schede.single.name, 'Giorno 1');
    });

    /// ⚠️ Chat e server hanno **due numerazioni diverse**, e prima stavano in
    /// due tabelle che non potevano confonderle. Adesso convivono: il messaggio
    /// 8 e la scheda 8 del server devono restare due righe distinte.
    test(
      'il messaggio 8 e la scheda 8 del server non si accavallano',
      () async {
        await schedaDallaChat(messaggioId: 8, nome: 'Dalla chat');

        await archivio.aggiungiScheda(
          nome: 'Dal server',
          scheda: '{}',
          mia: false,
          origine: 'server',
          idOrigine: 8,
        );

        final nomi = (await archivio.tutteLeSchede())
            .map((s) => s.nome)
            .toSet();

        expect(nomi, {'Dalla chat', 'Dal server'});
      },
    );

    /// 💡 `laScheda()` vuole l'id di **qui**, `laSchedaDalServer()` quello di
    /// **là**: confonderli farebbe saltare l'importazione, che scarterebbe una
    /// scheda mai scesa credendo di averla già.
    test('la scheda del server si ritrova col suo id di là', () async {
      final idLocale = await archivio.aggiungiScheda(
        nome: 'Dal server',
        scheda: '{}',
        mia: false,
        origine: 'server',
        idOrigine: 42,
      );

      expect((await archivio.laSchedaDalServer(42))?.id, idLocale);
      expect(await archivio.laSchedaDalServer(idLocale), isNull);
    });
  });

  group('🚨 le tre protezioni della chat', () {
    /// ⚠️ Toccare due volte «aggiungi» è la cosa più naturale del mondo.
    test('la stessa scheda arrivata due volte non si duplica', () async {
      await schedaDallaChat(messaggioId: 7);
      await schedaDallaChat(messaggioId: 7);

      expect((await archivio.tutteLeSchede()).length, 1);
    });

    /// ⛔ Una versione **più vecchia** che arriva per seconda non deve
    /// sovrascrivere quella corretta: il confronto è sull'id del messaggio, non
    /// sulla data, che la mette chi manda.
    test('una versione vecchia non sovrascrive quella nuova', () async {
      await schedaDallaChat(
        messaggioId: 20,
        nome: 'Full body corretto',
        origineId: 'XYZ',
      );

      await schedaDallaChat(
        messaggioId: 10,
        nome: 'Full body sbagliato',
        origineId: 'XYZ',
      );

      final schede = await archivio.tutteLeSchede();

      expect(schede.single.nome, 'Full body corretto');
    });

    /// 💡 E una **più recente** invece deve sostituirla, non affiancarla: sono
    /// la stessa scheda corretta dal trainer, non due schede.
    test('una versione nuova sostituisce quella vecchia', () async {
      await schedaDallaChat(messaggioId: 10, nome: 'Prima', origineId: 'XYZ');
      await schedaDallaChat(messaggioId: 20, nome: 'Dopo', origineId: 'XYZ');

      final schede = await archivio.tutteLeSchede();

      expect(schede.single.nome, 'Dopo');
      expect(schede.single.idOrigine, 20);
    });

    /// 🚨 Senza il ricordo, il salvataggio automatico della chat la rimette in
    /// archivio al messaggio successivo e chi l'aveva buttata la ributta. Per
    /// sempre.
    test('una scheda buttata non torna da sola', () async {
      final id = await schedaDallaChat(messaggioId: 1, origineId: 'XYZ');

      await archivio.cancellaScheda(id!);

      await schedaDallaChat(messaggioId: 2, origineId: 'XYZ');

      expect(await archivio.tutteLeSchede(), isEmpty);
    });

    /// ⚠️ Ma **solo quella**: buttare una scheda non deve rifiutare le altre.
    test('e le altre continuano ad arrivare', () async {
      final id = await schedaDallaChat(messaggioId: 1, origineId: 'XYZ');

      await archivio.cancellaScheda(id!);

      await schedaDallaChat(
        messaggioId: 2,
        nome: 'Un\'altra',
        origineId: 'QWE',
      );

      expect((await archivio.tutteLeSchede()).single.nome, 'Un\'altra');
    });

    /// 💡 Una scheda scritta qui non viene da nessuna parte, e cancellarla non
    /// deve lasciare nessun ricordo: i `NULL` non si rifiutano.
    test('cancellare una scheda propria non rifiuta niente', () async {
      final id = await archivio.aggiungiScheda(
        nome: 'La mia',
        scheda: '{}',
        mia: true,
        origine: 'mia',
      );

      await archivio.cancellaScheda(id);

      expect(await archivio.tutteLeSchede(), isEmpty);
    });
  });

  group('⚠️ e la chat sa cosa ha già aggiunto', () {
    test('«aggiunta» invece di «aggiungi»', () async {
      await schedaDallaChat(messaggioId: 5);

      expect(await archivio.schedaGiaSalvata(5), isTrue);
      expect(await archivio.schedaGiaSalvata(6), isFalse);
    });

    /// ⛔ **E non si confonde con una del server** che ha lo stesso numero: il
    /// pulsante direbbe «aggiunta» su una scheda mai aggiunta.
    test('e non la confonde con la scheda del server di pari numero', () async {
      await archivio.aggiungiScheda(
        nome: 'Dal server',
        scheda: '{}',
        mia: false,
        origine: 'server',
        idOrigine: 5,
      );

      expect(await archivio.schedaGiaSalvata(5), isFalse);
    });
  });

  /// 🚨 `svuota()` gira quando entra **un'altra persona** su questo telefono.
  /// Le schede sono sue: non devono restare.
  test('svuotare l\'archivio porta via anche le schede', () async {
    await schedaDallaChat();

    await archivio.svuota();

    expect(await archivio.tutteLeSchede(), isEmpty);
  });
}
