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

  HealthController conConsenso(bool dato) =>
      HealthController(ponte, archivio, () async => dato);

  // ⚠️ `DateFormat(…, 'it')` lancia se i dati della lingua non sono stati
  // caricati. Nell'app lo fa `main()`; qui va rifatto, o l'etichetta
  // dell'ultima sincronizzazione fa fallire test che con le date non c'entrano.
  setUpAll(() => initializeDateFormatting('it'));

  setUp(() {
    ponte = _PonteFinto();
    archivio = _ArchivioFinto();
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
