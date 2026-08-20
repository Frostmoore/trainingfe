import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/health/analizzatore_sonno.dart';
import 'package:training_companion/src/features/health/dati_salute.dart';
import 'package:training_companion/src/features/health/media_di_riferimento.dart';

/// 🚨 **I test cancellati in S1, riscritti in Dart — S4.4.**
///
/// Quando la fase S1 ha rimosso `HealthApiTest` (9 test) e otto test di
/// `DashboardApiTest`, non è stata «copertura persa»: quei test descrivevano
/// **decisioni**, non implementazioni, e perderne uno significava perdere la
/// decisione.
///
/// Ogni gruppo qui sotto porta il nome del caso PHP da cui viene, così che chi
/// confronta i due lati possa farlo riga per riga.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  Future<void> misura(MetricaSalute m, double valore, {required int giorniFa}) {
    final quando = DateTime(2026, 8, 11, 7).subtract(Duration(days: giorniFa));

    return archivio.scriviLetture([
      LetturaSalute(
        id: 0,
        fonte: 'test',
        metrica: m.codice,
        misurataIl: quando,
        giorno: DateTime(quando.year, quando.month, quando.day),
        valore: valore,
      ),
    ]);
  }

  Future<void> dormi(
    FaseSonno fase, {
    required DateTime da,
    required int minuti,
  }) {
    return archivio.scriviCampioniSonno([
      CampioneSonno(
        id: 0,
        fonte: 'test',
        notte: notteDi(da),
        iniziatoIl: da,
        finitoIl: da.add(Duration(minutes: minuti)),
        fase: fase.codice,
      ),
    ]);
  }

  group('la media di riferimento — da the_vitals_carry_the_persons_own_baseline', () {
    /// 🚨 Il valore assoluto non si può giudicare: 40 ms sono ottimi per
    /// qualcuno e pessimi per un altro. Conta lo scostamento dalla media **di
    /// questa persona**, ed è per questo che viaggia insieme al valore.
    test('la lettura porta con sé la media e lo scostamento', () async {
      for (var g = 1; g <= 7; g++) {
        await misura(MetricaSalute.hrv, 50, giorniFa: g);
      }

      await misura(MetricaSalute.hrv, 40, giorniFa: 0);

      final lettura = await MediaDiRiferimento.perMetrica(archivio, MetricaSalute.hrv);

      expect(lettura!.valore, 40.0);
      expect(lettura.media, 50.0);
      expect(lettura.scostamentoPct, -20.0);
    });

    /// ⚠️ Da `todays_reading_is_not_part_of_its_own_baseline`.
    ///
    /// Con la misura di oggi dentro, la media sarebbe 40 e lo scostamento
    /// -50%. Senza, la media è 60 e lo scostamento è -66,7%: è nel giorno
    /// storto che serve vedere lo scostamento intero.
    test('la misura di oggi non entra nella propria media', () async {
      await misura(MetricaSalute.hrv, 60, giorniFa: 1);
      await misura(MetricaSalute.hrv, 20, giorniFa: 0);

      final lettura = await MediaDiRiferimento.perMetrica(archivio, MetricaSalute.hrv);

      expect(lettura!.media, 60.0);
      expect(lettura.scostamentoPct, -66.7);
    });

    /// Da `without_any_watch_data_the_vitals_say_so_instead_of_showing_zeros`.
    test('senza nessuna lettura si torna null, non uno zero', () async {
      expect(await MediaDiRiferimento.perMetrica(archivio, MetricaSalute.hrv), isNull);
      expect(await MediaDiRiferimento.tutte(archivio), isEmpty);
    });

    test('con una lettura sola non c\'è media, e non si inventa', () async {
      await misura(MetricaSalute.hrv, 48, giorniFa: 0);

      final lettura = await MediaDiRiferimento.perMetrica(archivio, MetricaSalute.hrv);

      expect(lettura!.valore, 48.0);
      // 🚨 `null`, non «uguale a sé stessa»: una media di un solo valore
      // darebbe sempre scostamento zero, cioè «tutto normale» a chiunque.
      expect(lettura.media, isNull);
      expect(lettura.scostamentoPct, isNull);
      expect(lettura.anomalo, isFalse);
    });

    /// ⚠️ La finestra parte dal giorno **dell'ultima misura**, non da oggi:
    /// con una misura vecchia, «gli ultimi sette da adesso» darebbe vuoto e la
    /// media sparirebbe senza motivo.
    test('una misura vecchia conserva la sua media', () async {
      for (var g = 4; g <= 9; g++) {
        await misura(MetricaSalute.hrv, 50, giorniFa: g);
      }

      await misura(MetricaSalute.hrv, 44, giorniFa: 3);

      final lettura = await MediaDiRiferimento.perMetrica(archivio, MetricaSalute.hrv);

      expect(lettura!.valore, 44.0);
      expect(lettura.media, 50.0);
    });

    /// 🚨 Un HRV **sopra** la media è una buona notizia, non un allarme.
    /// Un battito a riposo sopra la media invece sì.
    test('l\'anomalia guarda la direzione giusta per ogni metrica', () async {
      for (var g = 1; g <= 7; g++) {
        await misura(MetricaSalute.hrv, 50, giorniFa: g);
        await misura(MetricaSalute.battitoARiposo, 50, giorniFa: g);
      }

      await misura(MetricaSalute.hrv, 70, giorniFa: 0);
      await misura(MetricaSalute.battitoARiposo, 70, giorniFa: 0);

      final hrv = await MediaDiRiferimento.perMetrica(archivio, MetricaSalute.hrv);
      final battito =
          await MediaDiRiferimento.perMetrica(archivio, MetricaSalute.battitoARiposo);

      expect(hrv!.scostamentoPct, 40.0);
      expect(hrv.anomalo, isFalse, reason: 'un HRV alto è un buon segno');

      expect(battito!.scostamentoPct, 40.0);
      expect(battito.anomalo, isTrue, reason: 'un battito a riposo alto no');
    });
  });

  group('il giudizio della notte — da HealthApiTest', () {
    /// 🚨 **Il complessivo è il PEGGIORE dei quattro, non la media.**
    ///
    /// Otto ore di sonno con pochissimo profondo non sono «buone in media»:
    /// sono una notte lunga e poco riposante, e mediarle la farebbe passare
    /// per normale.
    test('una notte lunga ma senza profondo non è una notte buona', () async {
      final sera = DateTime(2026, 8, 10, 23);

      // 8 ore: 7h40 leggero + 20 min REM, niente profondo.
      await dormi(FaseSonno.leggero, da: sera, minuti: 460);
      await dormi(FaseSonno.rem, da: sera.add(const Duration(minutes: 460)), minuti: 20);

      final g = await AnalizzatoreSonno.notte(archivio, DateTime(2026, 8, 11));

      expect(g!.minutiDormiti, 480);
      // I minuti dormiti da soli direbbero «ok»…
      expect(g.valutazioni['asleep_minutes'], Giudizio.ok);
      // …ma il profondo è a zero, e il voto complessivo lo segue.
      expect(g.valutazioni['deep_pct'], Giudizio.bad);
      expect(g.complessivo, Giudizio.bad);
    });

    test('una notte piena in tutte e quattro le voci è ok', () async {
      final sera = DateTime(2026, 8, 10, 23);

      // 8 ore: 60% leggero, 20% profondo, 20% REM, 15 min svegli.
      await dormi(FaseSonno.leggero, da: sera, minuti: 288);
      await dormi(FaseSonno.profondo, da: sera.add(const Duration(minutes: 288)), minuti: 96);
      await dormi(FaseSonno.rem, da: sera.add(const Duration(minutes: 384)), minuti: 96);
      await dormi(FaseSonno.sveglio, da: sera.add(const Duration(minutes: 480)), minuti: 15);

      final g = await AnalizzatoreSonno.notte(archivio, DateTime(2026, 8, 11));

      expect(g!.minutiDormiti, 480);
      expect(g.minutiSvegli, 15);
      expect(g.profondoPct, 20.0);
      expect(g.remPct, 20.0);
      expect(g.complessivo, Giudizio.ok);
    });

    /// ══ 🚨 IL PISOLINO NON È NOTTE — difetto del 20/08/2026 ═══════════════
    ///
    /// 📌 Il committente, leggendo il consiglio del giorno: *«ho dormito sì
    /// 8:55h ma 2 di queste sono state un pisolino»*.
    ///
    /// ⚠️ Si sommavano **tutti** i campioni della giornata di riposo, e una
    /// pennichella pomeridiana finiva dentro il totale della notte. 🚨 Non è un
    /// arrotondamento: due ore di pisolino fanno sembrare riposante una notte da
    /// sei ore e mezza, e quel numero falso entrava nel consiglio.
    ///
    /// 💡 `SessioniDiSonno` sapeva già distinguerle (`eNotte`): quello che
    /// mancava era **usarlo qui**.
    test('una pennichella non entra nel totale della notte', () async {
      final sera = DateTime(2026, 8, 10, 23);

      // La notte vera: 6h30.
      await dormi(FaseSonno.leggero, da: sera, minuti: 390);

      // E un pisolino di due ore il pomeriggio dopo, stessa giornata di riposo.
      await dormi(
        FaseSonno.leggero,
        da: DateTime(2026, 8, 11, 15),
        minuti: 120,
      );

      final g = await AnalizzatoreSonno.notte(archivio, DateTime(2026, 8, 11));

      expect(
        g!.minutiDormiti,
        390,
        reason: 'La notte è 6h30, non 8h30: il pisolino sta fuori.',
      );
    });

    /// ⚠️ **E l'errore opposto non deve succedere**: se per quella giornata ci
    /// sono **solo** pennichelle, non si dice che ha dormito due ore. Si dice
    /// che non c'è una notte — sommare i pisolini e chiamarli notte sarebbe lo
    /// stesso difetto al contrario.
    test('una giornata di soli pisolini non è una notte', () async {
      await dormi(
        FaseSonno.leggero,
        da: DateTime(2026, 8, 11, 15),
        minuti: 100,
      );

      expect(await AnalizzatoreSonno.notte(archivio, DateTime(2026, 8, 11)), isNull);
    });

    /// ⚠️ I minuti da svegli **non** contano come sonno, anche se il sensore li
    /// ha registrati dentro la finestra della notte: sono esattamente ciò che
    /// rende una notte lunga poco riposante.
    test('i minuti da svegli non gonfiano il sonno', () async {
      final sera = DateTime(2026, 8, 10, 23);

      await dormi(FaseSonno.leggero, da: sera, minuti: 300);
      await dormi(FaseSonno.sveglio, da: sera.add(const Duration(minutes: 300)), minuti: 90);

      final g = await AnalizzatoreSonno.notte(archivio, DateTime(2026, 8, 11));

      expect(g!.minutiDormiti, 300);
      expect(g.minutiSvegli, 90);
      // 90 minuti svegli superano anche la soglia di attenzione (60).
      expect(g.valutazioni['awake_minutes'], Giudizio.bad);
    });

    /// Da `the_night_belongs_to_the_previous_day`.
    test('la notte a cavallo di mezzanotte resta una notte sola', () async {
      await dormi(FaseSonno.leggero, da: DateTime(2026, 8, 10, 23, 30), minuti: 60);
      await dormi(FaseSonno.profondo, da: DateTime(2026, 8, 11, 0, 30), minuti: 120);

      final g = await AnalizzatoreSonno.notte(archivio, DateTime(2026, 8, 11));

      expect(g, isNotNull);
      expect(g!.minutiDormiti, 180);
      expect(g.ipnogramma, hasLength(2));
    });

    test('senza campioni si torna null, non una notte di zeri', () async {
      expect(await AnalizzatoreSonno.notte(archivio, DateTime(2026, 8, 11)), isNull);
    });

    test('la durata si legge in ore e minuti', () async {
      await dormi(FaseSonno.leggero, da: DateTime(2026, 8, 10, 23), minuti: 425);

      final g = await AnalizzatoreSonno.notte(archivio, DateTime(2026, 8, 11));

      expect(g!.durata, '7h 05m');
    });
  });
}
