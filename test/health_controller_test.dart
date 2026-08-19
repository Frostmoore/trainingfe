import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/health/health_controller.dart';
import 'package:training_companion/src/features/health/ponte_salute.dart';

/// A5 — il collegamento con Health Connect.
///
/// ── 🚨 Il cancello che mancava ────────────────────────────────────────────
///
/// `ConsentController` dichiarava già, nel proprio dartdoc, che *«senza il
/// consenso sanitario non si collega Health Connect»*. ⚠️ **E nessuno lo
/// verificava**: la regola stava scritta lato server e il controllo non
/// esisteva da nessuna parte, quindi l'app leggeva battito e sonno senza che
/// il consenso fosse mai stato dato.
///
/// 💡 È la stessa forma dei quattro difetti trovati provando l'app: una cosa
/// **descritta** in un commento e mai **eseguita** da una riga di codice.
void main() {
  late _PonteFinto ponte;
  late _ArchivioFinto archivio;

  /// Quante volte il controller ha detto «gli allenamenti sono cambiati».
  ///
  /// 🚨 Serve al test del difetto del 20/08: il ponte scriveva l'allenamento e
  /// **non lo diceva a nessuno**, quindi lo storico restava su «Nessun
  /// allenamento» con la riga già nel database.
  late int avvisi;

  HealthController conConsenso(bool dato) =>
      HealthController(ponte, archivio, () async => dato, () => avvisi++);

  // ⚠️ `DateFormat(…, 'it')` lancia se i dati della lingua non sono stati
  // caricati. Nell'app lo fa `main()`; qui va rifatto, o l'etichetta
  // dell'ultima sincronizzazione fa fallire test che con le date non c'entrano.
  setUpAll(() => initializeDateFormatting('it'));

  setUp(() {
    ponte = _PonteFinto();
    archivio = _ArchivioFinto();
    avvisi = 0;
  });

  /// ══ 🚨 Il difetto del 20/08, guardando l'app ═════════════════════════════
  ///
  /// Il ponte scriveva l'allenamento nell'archivio e **non lo diceva a
  /// nessuno**. Sul telefono del committente la seduta di pesi è entrata nel
  /// database alle `00:18:29`, con lo storico già aperto davanti: la schermata
  /// è rimasta su «Nessun allenamento» mentre la riga c'era.
  ///
  /// ⚠️ **È invisibile a chi lo prova male**: cambiando scheda e tornando
  /// indietro il provider `autoDispose` si ricrea e il dato compare, quindi
  /// sembra funzionare. Non funziona **al primo avvio**, che è il momento in
  /// cui uno guarda.
  group('l avviso che l archivio è cambiato', () {
    test('parte dopo una sincronizzazione silenziosa', () async {
      final c = conConsenso(true);
      ponte.permessiGiaCe = true;

      await c.aggiornaInSilenzio();

      expect(avvisi, 1);
    });

    test('parte anche dopo un collegamento a mano', () async {
      ponte.concede = true;

      final c = conConsenso(true);

      await c.collega();

      expect(avvisi, 1);
    });

    /// ⚠️ E **non** se il permesso è stato negato: lì `collega()` esce prima di
    /// sincronizzare, quindi non c'è niente di nuovo nell'archivio.
    test('non parte se il permesso è stato negato', () async {
      ponte.concede = false;

      await conConsenso(true).collega();

      expect(avvisi, 0);
    });

    /// 💡 Anche a mani vuote: `quanti` conta pure letture e sonno, quindi non
    /// dice se gli **allenamenti** sono cambiati. Non avvisare quando il ponte
    /// non riporta niente vorrebbe dire indovinare.
    test('parte anche se non è arrivato niente', () async {
      final c = conConsenso(true);
      ponte.permessiGiaCe = true;
      ponte.campioni = 0;

      await c.aggiornaInSilenzio();

      expect(avvisi, 1);
    });

    /// 🚨 Ma **non** quando la sincronizzazione non è nemmeno partita: senza
    /// consenso non si legge niente, quindi non c'è niente di nuovo da dire.
    test('non parte se senza consenso non si è letto niente', () async {
      final c = conConsenso(false);

      await c.aggiornaInSilenzio();

      expect(avvisi, 0);
    });
  });

  group('collega()', () {
    test('senza consenso sanitario non chiede nemmeno il permesso', () async {
      final c = conConsenso(false);

      await c.collega();

      expect(
        ponte.permessiChiesti,
        0,
        reason: 'il dialogo di Android, se rifiutato due volte, non si '
            'ripropone piu\': non va bruciato per una verifica che si poteva '
            'fare prima',
      );
      expect(c.state.collegato, isFalse);
      expect(c.state.errore, contains('consenso'));
    });

    test('con il consenso si procede e si sincronizza', () async {
      ponte
        ..concede = true
        ..campioni = 42;

      final c = conConsenso(true);

      await c.collega();

      expect(ponte.permessiChiesti, 1);
      expect(c.state.collegato, isTrue);
      expect(c.state.ultimaSincronizzazione, isNotNull);
      expect(c.state.errore, isNull);
    });

    /// ⚠️ Collegato ma senza dati **non è un errore**: succede quando
    /// l'orologio non ha ancora sincronizzato col telefono. Va detto, o sembra
    /// che il collegamento non abbia funzionato.
    test('collegato ma senza dati lo dice, senza spegnersi', () async {
      ponte
        ..concede = true
        ..campioni = 0;

      final c = conConsenso(true);

      await c.collega();

      expect(c.state.collegato, isTrue);
      expect(c.state.errore, isNotNull);
    });

    test('permesso negato: non collegato, e si spiega come rimediare', () async {
      ponte.concede = false;

      final c = conConsenso(true);

      await c.collega();

      expect(c.state.collegato, isFalse);
      expect(c.state.errore, contains('impostazioni'));
    });
  });

  group('aggiornaInSilenzio()', () {
    /// 🚨 È il metodo che gira **all'avvio**: non deve poter aprire nessun
    /// dialogo di sistema, mai.
    test('non chiede mai il permesso, nemmeno quando manca', () async {
      ponte.permessiGiaCe = false;

      await conConsenso(true).aggiornaInSilenzio();

      expect(ponte.permessiChiesti, 0);
      expect(ponte.sincronizzazioni, 0);
    });

    test('con permesso gia\' concesso sincronizza da solo', () async {
      ponte
        ..permessiGiaCe = true
        ..campioni = 7;

      final c = conConsenso(true);

      await c.aggiornaInSilenzio();

      expect(ponte.sincronizzazioni, 1);
      expect(ponte.permessiChiesti, 0);
      expect(c.state.ultimaSincronizzazione, isNotNull);
    });

    /// 🚨 Revocare il consenso deve fermare la lettura **subito**, non alla
    /// prossima volta che qualcuno tocca «collega» — che potrebbe non
    /// succedere mai.
    test('consenso revocato: si smette di leggere', () async {
      ponte.permessiGiaCe = true;

      await conConsenso(false).aggiornaInSilenzio();

      expect(ponte.sincronizzazioni, 0);
    });

    /// ⚠️ Sette giorni e non trenta: è la finestra della media di riferimento,
    /// e rileggere un mese a ogni avvio costerebbe tempo per dati che
    /// l'archivio ha già.
    test('rilegge la finestra breve, non quella del primo collegamento', () async {
      ponte
        ..permessiGiaCe = true
        ..campioni = 3;

      await conConsenso(true).aggiornaInSilenzio();

      expect(ponte.ultimaFinestra, 7);
    });
  });
}

class _PonteFinto implements PonteSalute {
  bool concede = false;
  bool permessiGiaCe = false;
  int campioni = 0;

  int permessiChiesti = 0;
  int sincronizzazioni = 0;
  int? ultimaFinestra;

  @override
  Future<bool> chiediPermessi() async {
    permessiChiesti++;

    return concede;
  }

  @override
  Future<bool> permessiGiaConcessi() async => permessiGiaCe;

  @override
  Future<int> sincronizza({int giorniIndietro = 7}) async {
    sincronizzazioni++;
    ultimaFinestra = giorniIndietro;

    return campioni;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ArchivioFinto implements ArchivioSalute {
  bool svuotato = false;

  @override
  Future<void> svuota() async => svuotato = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
