import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';

/// Gli allenamenti dell'orologio nell'archivio — FASE 1.9, 20/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// Tre cose, e tutte e tre hanno un modo di rompersi che **non dà errori**:
///
/// | | Se si rompe |
/// |---|---|
/// | La chiave unica | ogni avvio dell'app riaggiunge gli stessi allenamenti |
/// | `insertOrIgnore` | la scheda assegnata sparisce «ogni tanto» |
/// | Il backup | ci si accorge che mancano il giorno che si cambia telefono |
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  AllenamentoDaOrologio corsa({
    DateTime? quando,
    String fonte = 'com.huami.watch.hmwatchmanager',
    int kcal = 400,
  }) =>
      AllenamentoDaOrologio(
        id: 0,
        fonte: fonte,
        tipo: 'RUNNING',
        iniziatoIl: quando ?? DateTime(2026, 8, 19, 7),
        finitoIl: (quando ?? DateTime(2026, 8, 19, 7)).add(const Duration(minutes: 40)),
        kcal: kcal,
        nascosto: false,
        staccato: false,
      );

  group('La rilettura non duplica', () {
    /// 🚨 Si rileggono **sempre** gli ultimi sette giorni: senza la chiave
    /// unica su `(fonte, iniziatoIl)` ogni avvio dell'app aggiungerebbe di
    /// nuovo tutto, e lo storico crescerebbe da solo.
    test('lo stesso allenamento scritto due volte resta uno', () async {
      await archivio.scriviAllenamenti([corsa()]);
      await archivio.scriviAllenamenti([corsa()]);

      expect(await archivio.allenamentiDellOrologio(), hasLength(1));
    });

    /// ⚠️ Due app diverse che scrivono la **stessa** ora sono due record veri:
    /// Zepp e Google Fit possono entrambe registrare la stessa corsa. Non è
    /// questo test a dire come si sceglie, dice solo che non si perdono.
    test('due fonti diverse alla stessa ora restano due', () async {
      await archivio.scriviAllenamenti([
        corsa(),
        corsa(fonte: 'com.google.android.apps.fitness'),
      ]);

      expect(await archivio.allenamentiDellOrologio(), hasLength(2));
    });
  });

  group('Quello che sceglie la persona non si perde', () {
    /// ══ 🚨 Il test che conta di più ═══════════════════════════════════════
    ///
    /// `schedaAssegnata` è l'unico campo che non viene dall'orologio. Con
    /// `insertOrReplace` una risincronizzazione la sovrascriverebbe con il
    /// record originale — cioè con `null`.
    ///
    /// ⚠️ Il sintomo sarebbe «ogni tanto si dimentica la scheda che gli ho
    /// detto», che è la specie di difetto che nessuno riesce a riprodurre.
    test('una risincronizzazione non cancella la scheda assegnata', () async {
      await archivio.scriviAllenamenti([corsa()]);

      final salvato = (await archivio.allenamentiDellOrologio()).single;
      await archivio.assegnaSchedaAllenamento(salvato.id, 77);

      // L'orologio ripassa e riconsegna lo stesso allenamento.
      await archivio.scriviAllenamenti([corsa()]);

      final dopo = (await archivio.allenamentiDellOrologio()).single;

      expect(dopo.schedaAssegnata, 77);
    });

    /// 💡 Una scelta che non si disfa è una trappola: le corse di due giorni
    /// diversi si somigliano molto, ed è facilissimo toccare la riga sbagliata.
    test('l assegnazione si può togliere', () async {
      await archivio.scriviAllenamenti([corsa()]);

      final salvato = (await archivio.allenamentiDellOrologio()).single;
      await archivio.assegnaSchedaAllenamento(salvato.id, 77);
      await archivio.assegnaSchedaAllenamento(salvato.id, null);

      expect((await archivio.allenamentiDellOrologio()).single.schedaAssegnata, isNull);
    });

    /// ══ 🚨 E però i dati del SENSORE si correggono ═══════════════════════
    ///
    /// Il 20/08 gli allenamenti già salvati portavano le calorie **sbagliate**
    /// — quelle col metabolismo basale dentro, 835 al posto di 680 — e con il
    /// solo `insertOrIgnore` nessuna risincronizzazione le avrebbe mai
    /// corrette, perché la riga c'era già.
    ///
    /// 💡 La regola non è «non toccare niente», è **chi possiede cosa**.
    test('una rilettura corregge le calorie sbagliate', () async {
      await archivio.scriviAllenamenti([corsa(kcal: 835)]);

      await archivio.scriviAllenamenti([corsa(kcal: 680)]);

      expect((await archivio.allenamentiDellOrologio()).single.kcal, 680);
      expect(await archivio.allenamentiDellOrologio(), hasLength(1));
    });

    /// 🚨 **Le due cose insieme**, che è il punto: il numero si corregge **e**
    /// la scheda resta. Separati, i due test passerebbero anche con
    /// un'implementazione che sbaglia.
    test('corregge il sensore SENZA perdere la scheda assegnata', () async {
      await archivio.scriviAllenamenti([corsa(kcal: 835)]);

      final salvato = (await archivio.allenamentiDellOrologio()).single;
      await archivio.assegnaSchedaAllenamento(salvato.id, 77);

      await archivio.scriviAllenamenti([corsa(kcal: 680)]);

      final dopo = (await archivio.allenamentiDellOrologio()).single;

      expect(dopo.kcal, 680);
      expect(dopo.schedaAssegnata, 77);
    });

    test('e nemmeno il nascondi si perde', () async {
      await archivio.scriviAllenamenti([corsa()]);

      final salvato = (await archivio.allenamentiDellOrologio()).single;
      await archivio.nascondiAllenamento(salvato.id, nascosto: true);
      await archivio.scriviAllenamenti([corsa()]);

      expect((await archivio.allenamentiDellOrologio()).single.nascosto, isTrue);
    });

    /// 🚨 **Nemmeno lo scollegamento** — FASE 1-bis. È la contropartita della
    /// regola larga: se una risincronizzazione lo cancellasse, un
    /// raggruppamento corretto a mano si rifarebbe da solo al prossimo avvio, e
    /// l'allenamento tornerebbe a sparire.
    test('e nemmeno lo staccato si perde', () async {
      await archivio.scriviAllenamenti([corsa()]);

      final salvato = (await archivio.allenamentiDellOrologio()).single;
      await archivio.staccaAllenamento(salvato.id, staccato: true);
      await archivio.scriviAllenamenti([corsa(kcal: 680)]);

      final dopo = (await archivio.allenamentiDellOrologio()).single;

      expect(dopo.staccato, isTrue, reason: 'La correzione a mano resta.');
      expect(dopo.kcal, 680, reason: 'Ma il dato del sensore si aggiorna comunque.');
    });

    /// 💡 E si può rimettere insieme: *«Puoi rimetterlo insieme quando vuoi»* è
    /// scritto nel dialogo, quindi deve essere vero.
    test('e si può riattaccare', () async {
      await archivio.scriviAllenamenti([corsa()]);

      final salvato = (await archivio.allenamentiDellOrologio()).single;
      await archivio.staccaAllenamento(salvato.id, staccato: true);
      await archivio.staccaAllenamento(salvato.id, staccato: false);

      expect((await archivio.allenamentiDellOrologio()).single.staccato, isFalse);
    });
  });

  group('Il backup', () {
    /// 🚨 La regola del committente, senza eccezioni: *«ogni volta che abbiamo
    /// un nuovo dato o un nuovo file o qualsiasi altra cosa, questo deve
    /// comunque finire in qualche modo nel backup»*.
    ///
    /// 💡 Ci finisce **da solo** perché `esportaPerBackup()` enumera
    /// `allTables`. Questo test verifica che quel meccanismo abbia davvero
    /// pescato la tabella nuova, invece di fidarsi che lo faccia.
    test('gli allenamenti ci finiscono dentro', () async {
      await archivio.scriviAllenamenti([corsa()]);

      final dati = await archivio.esportaPerBackup();

      expect(dati.keys, contains('allenamenti_da_orologio'));
      expect(dati['allenamenti_da_orologio'], hasLength(1));
    });

    test('e tornano indietro con la scheda assegnata', () async {
      await archivio.scriviAllenamenti([corsa()]);

      final salvato = (await archivio.allenamentiDellOrologio()).single;
      await archivio.assegnaSchedaAllenamento(salvato.id, 77);

      final dati = await archivio.esportaPerBackup();

      final altro = ArchivioSalute.inMemoria();
      addTearDown(altro.close);

      await altro.ripristinaDaBackup(dati);

      final ripreso = (await altro.allenamentiDellOrologio()).single;

      expect(ripreso.tipo, 'RUNNING');
      expect(ripreso.kcal, 400);
      expect(ripreso.schedaAssegnata, 77);
    });

    /// ══ 🚨 Il caso vero del 20/08 ════════════════════════════════════════
    ///
    /// Chi aggiorna l'app ha in mano un backup fatto allo **schema 8**, dove
    /// questa tabella non esisteva. Ripristinarlo dentro l'app allo schema 9
    /// deve funzionare, e deve **saltare** la tabella assente invece di
    /// svuotarla.
    ///
    /// ⚠️ Se la svuotasse, il ripristino cancellerebbe allenamenti che il file
    /// non poteva contenere — cioè distruggerebbe qualcosa che non stava
    /// nemmeno ripristinando.
    test('un backup vecchio non cancella gli allenamenti già letti', () async {
      await archivio.scriviAllenamenti([corsa()]);

      // Un backup com'era prima della FASE 1.9: senza quella chiave.
      final vecchio = await archivio.esportaPerBackup()
        ..remove('allenamenti_da_orologio');

      await archivio.ripristinaDaBackup(vecchio);

      expect(
        await archivio.allenamentiDellOrologio(),
        hasLength(1),
        reason: 'Una tabella assente dal backup si salta, non si svuota.',
      );
    });
  });
}
