import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/health/dati_salute.dart';

/// 🚨 **L'archivio locale dei dati del corpo — S3.5.**
///
/// Questi test valgono più di quanto sembri: dopo S1 **non esiste nessun altro
/// posto** dove quei dati vivano. Prima un difetto qui si sarebbe visto come una
/// discrepanza con il server; adesso il server non ha niente con cui
/// discordare, e un archivio che duplica o perde righe sbaglia **in silenzio**.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  LetturaSalute lettura(MetricaSalute m, double valore, DateTime quando) => LetturaSalute(
    id: 0,
    fonte: 'test',
    metrica: m.codice,
    misurataIl: quando,
    giorno: DateTime(quando.year, quando.month, quando.day),
    valore: valore,
  );

  CampioneSonno campione(DateTime da, DateTime a, FaseSonno fase) => CampioneSonno(
    id: 0,
    fonte: 'test',
    notte: notteDi(da),
    iniziatoIl: da,
    finitoIl: a,
    fase: fase.codice,
  );

  group('le letture', () {
    test('si scrivono e si rileggono dalla più recente', () async {
      final oggi = DateTime(2026, 8, 11, 7);

      await archivio.scriviLetture([
        lettura(MetricaSalute.hrv, 48, oggi.subtract(const Duration(days: 2))),
        lettura(MetricaSalute.hrv, 52, oggi),
      ]);

      final letto = await archivio.lettureRecenti(MetricaSalute.hrv, giorni: 30);

      expect(letto, hasLength(2));
      expect(letto.first.valore, 52);
    });

    /// 🚨 La ragione per cui l'indice univoco esiste.
    ///
    /// Il ponte **rilegge sempre una finestra**, non solo il nuovo: senza
    /// questa regola ogni sincronizzazione raddoppierebbe i campioni già
    /// presenti. E non sarebbe un fastidio estetico — la media di riferimento è
    /// una media, e contare tre volte lo stesso valore la sposta.
    test('la stessa lettura scritta due volte non si duplica', () async {
      final quando = DateTime(2026, 8, 11, 7);

      await archivio.scriviLetture([lettura(MetricaSalute.hrv, 48, quando)]);
      await archivio.scriviLetture([lettura(MetricaSalute.hrv, 48, quando)]);
      await archivio.scriviLetture([lettura(MetricaSalute.hrv, 48, quando)]);

      expect(await archivio.lettureRecenti(MetricaSalute.hrv, giorni: 30), hasLength(1));
    });

    /// 🚨 Un valore fuori scala **non entra**.
    ///
    /// Un HRV di 4000 ms è rumore del sensore, e basta una lettura del genere
    /// per spostare la media di giorni. Siccome tutto ragiona sullo scostamento
    /// dalla media, un solo valore assurdo non sbaglia un numero: rende inutile
    /// la funzione.
    test('un valore implausibile viene scartato, non salvato', () async {
      final quando = DateTime(2026, 8, 11, 7);

      final scritte = await archivio.scriviLetture([
        lettura(MetricaSalute.hrv, 4000, quando),
        lettura(MetricaSalute.hrv, 48, quando.add(const Duration(minutes: 1))),
      ]);

      expect(scritte, 1);
      final letto = await archivio.lettureRecenti(MetricaSalute.hrv, giorni: 30);
      expect(letto, hasLength(1));
      expect(letto.single.valore, 48);
    });

    test('le metriche non si mescolano fra loro', () async {
      final quando = DateTime(2026, 8, 11, 7);

      await archivio.scriviLetture([
        lettura(MetricaSalute.hrv, 48, quando),
        lettura(MetricaSalute.battitoARiposo, 52, quando),
      ]);

      expect(await archivio.lettureRecenti(MetricaSalute.hrv, giorni: 30), hasLength(1));
      expect(
        (await archivio.lettureRecenti(MetricaSalute.battitoARiposo, giorni: 30)).single.valore,
        52,
      );
    });

    /// ⚠️ La finestra per giorni serve alla media di riferimento, che deve poter
    /// dire «i sette giorni **prima** di quello dell'ultima misura» — non «gli
    /// ultimi sette da adesso», che con una misura vecchia darebbe vuoto.
    test('la finestra per giorni prende gli estremi inclusi', () async {
      for (var g = 1; g <= 5; g++) {
        await archivio.scriviLetture([
          lettura(MetricaSalute.hrv, 50, DateTime(2026, 8, 11 - g, 7)),
        ]);
      }

      final finestra = await archivio.lettureFraGiorni(
        MetricaSalute.hrv,
        da: DateTime(2026, 8, 8),
        a: DateTime(2026, 8, 10),
      );

      expect(finestra, hasLength(3));
    });
  });

  group('i campioni del sonno', () {
    /// 🚨 Un campione delle 02:00 appartiene alla notte del giorno **prima**.
    ///
    /// Senza questa regola chi va a letto alle 23:30 avrebbe il sonno spezzato
    /// su due giorni e nessuna delle due notti risulterebbe sufficiente.
    test('una notte a cavallo di mezzanotte resta una notte sola', () async {
      await archivio.scriviCampioniSonno([
        campione(DateTime(2026, 8, 10, 23, 30), DateTime(2026, 8, 11, 0, 30), FaseSonno.leggero),
        campione(DateTime(2026, 8, 11, 0, 30), DateTime(2026, 8, 11, 2, 0), FaseSonno.profondo),
        campione(DateTime(2026, 8, 11, 2, 0), DateTime(2026, 8, 11, 6, 30), FaseSonno.rem),
      ]);

      final notte = await archivio.campioniDellaNotte(DateTime(2026, 8, 10));

      expect(notte, hasLength(3));
      expect(notte.first.iniziatoIl.hour, 23);
    });

    test('lo stesso campione scritto due volte non si duplica', () async {
      final c = campione(
        DateTime(2026, 8, 10, 23, 30),
        DateTime(2026, 8, 11, 0, 30),
        FaseSonno.leggero,
      );

      await archivio.scriviCampioniSonno([c]);
      await archivio.scriviCampioniSonno([c]);

      expect(await archivio.campioniDellaNotte(DateTime(2026, 8, 10)), hasLength(1));
    });

    test('i minuti si contano dagli estremi, e non vanno mai sotto zero', () {
      final c = campione(
        DateTime(2026, 8, 10, 23, 0),
        DateTime(2026, 8, 10, 23, 45),
        FaseSonno.profondo,
      );

      expect(c.minuti, 45);

      final storto = campione(
        DateTime(2026, 8, 10, 23, 45),
        DateTime(2026, 8, 10, 23, 0),
        FaseSonno.profondo,
      );

      // Un campione con gli estremi invertiti è un dato sbagliato del sensore:
      // deve valere zero, non un numero negativo che poi accorcia la notte.
      expect(storto.minuti, 0);
    });

    test('l\'ultima notte con dati è quella giusta', () async {
      await archivio.scriviCampioniSonno([
        campione(DateTime(2026, 8, 8, 23, 0), DateTime(2026, 8, 9, 6, 0), FaseSonno.leggero),
        campione(DateTime(2026, 8, 10, 23, 0), DateTime(2026, 8, 11, 6, 0), FaseSonno.leggero),
      ]);

      expect(await archivio.ultimaNotteConDati(), DateTime(2026, 8, 10));
    });
  });

  /// 🚨 Con i dati sul telefono, «cancella il mio account» **deve** arrivare
  /// fin qui: il server non può cancellare ciò che non ha mai avuto.
  test('svuota() non lascia niente dietro', () async {
    await archivio.scriviLetture([lettura(MetricaSalute.hrv, 48, DateTime(2026, 8, 11, 7))]);
    await archivio.scriviCampioniSonno([
      campione(DateTime(2026, 8, 10, 23, 0), DateTime(2026, 8, 11, 6, 0), FaseSonno.leggero),
    ]);

    await archivio.svuota();

    expect(await archivio.lettureRecenti(MetricaSalute.hrv, giorni: 3650), isEmpty);
    expect(await archivio.campioniDellaNotte(DateTime(2026, 8, 10)), isEmpty);
  });

  group('la traduzione dalle scale di Health Connect', () {
    test('le fasi note si mappano sulla nostra numerazione', () {
      expect(FaseSonno.daHealthConnect(5), FaseSonno.profondo);
      expect(FaseSonno.daHealthConnect(6), FaseSonno.rem);
      expect(FaseSonno.daHealthConnect(4), FaseSonno.leggero);
    });

    /// ⚠️ Tutto ciò che non si riconosce diventa **sveglio**, non «leggero».
    /// Contare come sonno una fase che non si sa interpretare gonfia i minuti
    /// dormiti — l'errore che rende il giudizio troppo generoso proprio con chi
    /// ha dormito male.
    test('una fase sconosciuta conta come sveglio, non come sonno', () {
      expect(FaseSonno.daHealthConnect(99), FaseSonno.sveglio);
      expect(FaseSonno.daHealthConnect(0), FaseSonno.sveglio);
    });
  });
}
