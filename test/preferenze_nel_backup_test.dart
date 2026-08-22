import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:training_companion/src/core/backup/preferenze_nel_backup.dart';

/// Le preferenze finiscono nella copia di sicurezza — 22/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// 📌 Il committente: *«TUTTO deve finire nel backup diocane te l'avevo già
/// detto»*. E l'aveva detto: il 20/08.
///
/// ⚠️ Fino a oggi non era vero, **e i commenti dicevano che lo era**. È il
/// motivo per cui questo test esiste: una regola non negoziabile che vive solo
/// nei commenti è una regola che qualcuno violerà senza accorgersene.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('una preferenza qualunque viaggia, con il suo tipo', () async {
    /*
     * 🚨 I tipi si conservano. `SharedPreferences` distingue `int`, `bool`,
     * `String` e `List<String>`: riscrivere un `bool` come stringa vorrebbe
     * dire una preferenza che al ripristino **non si legge più** — e non
     * darebbe nessun errore, semplicemente il colore tornerebbe verde.
     */
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('aspetto.accento', 'indaco');
    await prefs.setString('consiglio.nascosto', '1');
    await prefs.setStringList('diario.pasti.chiusi', ['lunch', 'dinner']);
    await prefs.setInt('un.numero', 42);
    await prefs.setBool('un.booleano', true);

    final pacco = await PreferenzeNelBackup.esporta();

    // Su un telefono pulito, dove non c'è niente.
    SharedPreferences.setMockInitialValues({});
    await PreferenzeNelBackup.ripristina(pacco);

    final dopo = await SharedPreferences.getInstance();

    expect(dopo.getString('aspetto.accento'), 'indaco');
    expect(dopo.getString('consiglio.nascosto'), '1');
    expect(dopo.getStringList('diario.pasti.chiusi'), ['lunch', 'dinner']);
    expect(dopo.getInt('un.numero'), 42);
    expect(dopo.getBool('un.booleano'), isTrue);
  });

  test('🚨 una preferenza NUOVA ci finisce da sola', () async {
    /*
     * ⛔ È la proprietà che conta più di tutte. Un elenco «queste sì» avrebbe
     * funzionato oggi e sarebbe diventato falso alla prossima riga scritta da
     * qualcuno che non legge quel file.
     *
     * 💡 Si enumera, come `esportaPerBackup()` fa con le tabelle.
     */
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('qualcosa.che.non.esiste.ancora', 'ciao');

    final pacco = await PreferenzeNelBackup.esporta();

    expect(pacco['qualcosa.che.non.esiste.ancora'], 'ciao');
  });

  group('quello che resta su questo telefono', () {
    test('⛔ l\'id di chi c\'era prima NON viaggia', () async {
      /*
       * 🚨 È l'esclusione che evita un disastro: quell'id serve al controllo «è
       * entrato qualcun altro?», che quando scatta **svuota l'archivio**.
       * ⚠️ Ripristinandolo da un altro telefono, il controllo crederebbe di sì
       * e cancellerebbe l'archivio appena ripristinato.
       */
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('sessione.ultima_persona', 7);

      expect(
        (await PreferenzeNelBackup.esporta()).containsKey(
          'sessione.ultima_persona',
        ),
        isFalse,
      );
    });

    test('⛔ la bandierina del trasloco NON viaggia', () async {
      // 🚨 Ripristinarla su un'installazione pulita salterebbe il trasloco: gli
      // allenamenti resterebbero sul server e il telefono non li avrebbe.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('trasloco.allenamenti.fatto', '1');

      expect(
        (await PreferenzeNelBackup.esporta()).containsKey(
          'trasloco.allenamenti.fatto',
        ),
        isFalse,
      );
    });

    test('⛔ quando è stato fatto l\'ultimo backup NON viaggia', () async {
      /*
       * ⚠️ Il prefisso è `backup_automatico_` e non `backup.`: scritto a occhio
       * non avrebbe escluso niente, e l'esclusione che non esclude è peggio di
       * nessuna. 💡 Ripristinarlo comprerebbe ventiquattro ore di silenzio a un
       * telefono che un backup non l'ha mai fatto.
       */
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('backup_automatico_ultimo_riuscito', 1000);
      await prefs.setInt('backup_automatico_ultimo_errore', 2000);

      final pacco = await PreferenzeNelBackup.esporta();

      expect(pacco.keys.where((k) => k.startsWith('backup_')), isEmpty);
    });

    test('e non si cancellano ripristinando', () async {
      // ⛔ Il ripristino non svuota: le preferenze di questo telefono che il
      // backup non contiene restano dove sono.
      SharedPreferences.setMockInitialValues({'sessione.ultima_persona': 7});

      await PreferenzeNelBackup.ripristina({'aspetto.accento': 'viola'});

      final dopo = await SharedPreferences.getInstance();
      expect(dopo.getInt('sessione.ultima_persona'), 7);
      expect(dopo.getString('aspetto.accento'), 'viola');
    });
  });

  test('un backup senza preferenze non fa danni', () async {
    // 💡 È il caso dei file scritti prima del 22/08: la chiave non c'è, e il
    // ripristino deve passare oltre invece di lamentarsi.
    await PreferenzeNelBackup.ripristina(null);
    await PreferenzeNelBackup.ripristina('non una mappa');

    expect(true, isTrue);
  });
}
