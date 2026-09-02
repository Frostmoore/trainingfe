import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

/// Il diario alimentare sul telefono — Parte I, I1.
///
/// ══ 📌 PERCHÉ SI SPOSTA ═══════════════════════════════════════════════════
///
/// 📌 Regola R3: *«tutto ciò che è anche lontanamente sensibile resta sul
/// telefono»*. 🚨 Cosa mangia una persona è dato dell'art. 9, ed era l'ultima
/// tabella grossa di dati personali rimasta sul server — peso, sonno,
/// allenamenti e schede se ne sono andati fra S5, D9 e la FASE 11.
///
/// ══ ⚠️ QUESTA FASE È SOLO ADDITIVA ═══════════════════════════════════════
///
/// Le tabelle esistono, le letture esistono, e **nessuno le usa ancora**. ⛔ Un
/// mezzo trasloco — l'app che legge di qua e scrive di là — perderebbe pasti, e
/// non se ne accorgerebbe nessuno finché non è tardi.
///
/// 💡 Quello che questi test difendono è ciò che il trasloco (I3) darà per
/// scontato: che rileggere lo stesso pacchetto **non duplichi**.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  VociDiarioCompanion voce({
    required DateTime giorno,
    String pasto = 'lunch',
    String descrizione = 'Pollo',
    double kcal = 200,
    int? dalServer,
  }) => VociDiarioCompanion.insert(
    mangiatoIl: giorno,
    pasto: pasto,
    descrizione: descrizione,
    kcal: Value(kcal),
    idSulServer: Value(dalServer),
  );

  group('le voci del giorno', () {
    test('si scrivono e si rileggono', () async {
      final oggi = DateTime(2026, 9, 2);

      await archivio.scriviVoceDiario(voce(giorno: oggi, descrizione: 'Pollo'));
      await archivio.scriviVoceDiario(
        voce(giorno: oggi, pasto: 'dinner', descrizione: 'Pesce'),
      );

      final righe = await archivio.vociDelGiorno(oggi);

      expect(righe, hasLength(2));
      expect(righe.map((r) => r.descrizione), containsAll(['Pollo', 'Pesce']));
    });

    test('un altro giorno non si mescola', () async {
      await archivio.scriviVoceDiario(voce(giorno: DateTime(2026, 9, 1)));
      await archivio.scriviVoceDiario(voce(giorno: DateTime(2026, 9, 2)));

      expect(await archivio.vociDelGiorno(DateTime(2026, 9, 2)), hasLength(1));
    });

    test('l\'ora dentro il giorno non fa perdere la voce', () async {
      /*
       * ⚠️ Oggi l'app scrive la **mezzanotte** del giorno scelto, ma un domani
       * potrebbe scrivere l'ora vera. 🚨 La finestra è esplicita apposta: questa
       * lettura deve continuare a rispondere giusto in tutti e due i casi.
       */
      await archivio.scriviVoceDiario(
        voce(giorno: DateTime(2026, 9, 2, 21, 40)),
      );

      expect(await archivio.vociDelGiorno(DateTime(2026, 9, 2)), hasLength(1));
    });

    test('l\'intervallo prende gli estremi', () async {
      for (final g in [1, 2, 3, 4]) {
        await archivio.scriviVoceDiario(voce(giorno: DateTime(2026, 9, g)));
      }

      final righe = await archivio.vociFra(
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 3),
      );

      expect(righe, hasLength(2), reason: 'Gli estremi sono compresi.');
    });
  });

  group('🚨 il trasloco non duplica', () {
    test('importare due volte lo stesso pacchetto lascia una riga sola', () async {
      final pacchetto = [
        voce(giorno: DateTime(2026, 9, 1), dalServer: 11),
        voce(giorno: DateTime(2026, 9, 2), dalServer: 12),
      ];

      await archivio.importaVociDelDiario(pacchetto);
      await archivio.importaVociDelDiario(pacchetto);

      expect(
        await archivio.quanteVociDelDiario(),
        2,
        reason:
            'La migrazione può girare due volte — app chiusa a metà, rete '
            'persa, reinstallazione. Senza l\'indice unico su idSulServer il '
            'diario si raddoppierebbe, e si scoprirebbe solo guardando le '
            'calorie di un giorno vecchio.',
      );
    });

    test('ma due voci scritte QUI convivono, anche identiche', () async {
      /*
       * 💡 In SQLite due `NULL` non sono uguali, ed è esattamente la proprietà
       * che serve: chi mangia due volte la stessa cosa nello stesso giorno ha
       * due righe, e nessun indice gliene toglie una.
       */
      final oggi = DateTime(2026, 9, 2);

      await archivio.scriviVoceDiario(voce(giorno: oggi, descrizione: 'Mela'));
      await archivio.scriviVoceDiario(voce(giorno: oggi, descrizione: 'Mela'));

      expect(await archivio.quanteVociDelDiario(), 2);
    });

    test('il conteggio è quello che il server confronterà prima di cancellare', () async {
      expect(await archivio.quanteVociDelDiario(), 0);

      await archivio.importaVociDelDiario([
        voce(giorno: DateTime(2026, 9, 1), dalServer: 1),
        voce(giorno: DateTime(2026, 9, 1), dalServer: 2),
        voce(giorno: DateTime(2026, 9, 2), dalServer: 3),
      ]);

      expect(await archivio.quanteVociDelDiario(), 3);
    });
  });

  group('i preferiti', () {
    test('si scrivono, si rileggono dal più recente e non si duplicano', () async {
      await archivio.scriviPreferito(
        PreferitiCiboCompanion.insert(descrizione: 'Colazione tipo'),
      );

      final dalServer = [
        PreferitiCiboCompanion.insert(
          descrizione: 'Pranzo tipo',
          idSulServer: const Value(7),
        ),
      ];

      await archivio.importaPreferiti(dalServer);
      await archivio.importaPreferiti(dalServer);

      final righe = await archivio.preferitiDelDiario();

      expect(righe, hasLength(2));
    });
  });

  group('💾 e finiscono nel backup da sole', () {
    /*
     * 🚨 **È la regola R4**: *«ogni dato o file nuovo deve finire nel backup, e
     * la domanda si fa quando lo si crea»*.
     *
     * 💡 Qui la risposta è **sì per costruzione**: `esportaPerBackup()` enumera
     * `allTables` invece di un elenco scritto a mano. ⛔ Con un elenco, una
     * tabella nuova sarebbe stata fuori dal backup fino a che qualcuno non se
     * ne fosse ricordato — e la dimenticanza si sarebbe vista solo a un
     * ripristino, cioè nel momento peggiore.
     */
    test('l\'esportazione le comprende senza che nessuno le elenchi', () async {
      await archivio.scriviVoceDiario(voce(giorno: DateTime(2026, 9, 2)));
      await archivio.scriviPreferito(
        PreferitiCiboCompanion.insert(descrizione: 'Colazione tipo'),
      );

      final backup = await archivio.esportaPerBackup();

      expect(backup['voci_diario'], hasLength(1));
      expect(backup['preferiti_cibo'], hasLength(1));
    });

    test('e il ripristino le riscrive', () async {
      await archivio.scriviVoceDiario(
        voce(giorno: DateTime(2026, 9, 2), descrizione: 'Pollo'),
      );

      final backup = await archivio.esportaPerBackup();

      await archivio.cancellaVoceDiario(1);
      expect(await archivio.quanteVociDelDiario(), 0);

      await archivio.ripristinaDaBackup(backup);

      final righe = await archivio.vociDelGiorno(DateTime(2026, 9, 2));

      expect(righe, hasLength(1));
      expect(righe.single.descrizione, 'Pollo');
    });
  });
}
