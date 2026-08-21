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

  LetturaSalute lettura(MetricaSalute m, double valore, DateTime quando) =>
      LetturaSalute(
        id: 0,
        fonte: 'test',
        metrica: m.codice,
        misurataIl: quando,
        giorno: DateTime(quando.year, quando.month, quando.day),
        valore: valore,
      );

  CampioneSonno campione(DateTime da, DateTime a, FaseSonno fase) =>
      CampioneSonno(
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

      final letto = await archivio.lettureRecenti(
        MetricaSalute.hrv,
        giorni: 30,
      );

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

      expect(
        await archivio.lettureRecenti(MetricaSalute.hrv, giorni: 30),
        hasLength(1),
      );
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
      final letto = await archivio.lettureRecenti(
        MetricaSalute.hrv,
        giorni: 30,
      );
      expect(letto, hasLength(1));
      expect(letto.single.valore, 48);
    });

    test('le metriche non si mescolano fra loro', () async {
      final quando = DateTime(2026, 8, 11, 7);

      await archivio.scriviLetture([
        lettura(MetricaSalute.hrv, 48, quando),
        lettura(MetricaSalute.battitoARiposo, 52, quando),
      ]);

      expect(
        await archivio.lettureRecenti(MetricaSalute.hrv, giorni: 30),
        hasLength(1),
      );
      expect(
        (await archivio.lettureRecenti(
          MetricaSalute.battitoARiposo,
          giorni: 30,
        )).single.valore,
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
    /// 🚨 Il riposo si accredita **al giorno in cui ci si sveglia** — regola
    /// cambiata il 12/08/2026 dopo la prova su telefono.
    ///
    /// ⚠️ Questi test dicevano il contrario, e passavano: chi andava a letto il
    /// 10 alle 23:30 finiva accreditato al **10**, e il sintomo riferito era
    /// *«mi mostra il sonno di questa notte come attribuito a ieri»*. La
    /// convenzione è stata cambiata, non aggirata.
    test('una notte a cavallo di mezzanotte resta una notte sola', () async {
      await archivio.scriviCampioniSonno([
        campione(
          DateTime(2026, 8, 10, 23, 30),
          DateTime(2026, 8, 11, 0, 30),
          FaseSonno.leggero,
        ),
        campione(
          DateTime(2026, 8, 11, 0, 30),
          DateTime(2026, 8, 11, 2, 0),
          FaseSonno.profondo,
        ),
        campione(
          DateTime(2026, 8, 11, 2, 0),
          DateTime(2026, 8, 11, 6, 30),
          FaseSonno.rem,
        ),
      ]);

      final notte = await archivio.campioniDellaNotte(DateTime(2026, 8, 11));

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

      expect(
        await archivio.campioniDellaNotte(DateTime(2026, 8, 11)),
        hasLength(1),
      );
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
        campione(
          DateTime(2026, 8, 8, 23, 0),
          DateTime(2026, 8, 9, 6, 0),
          FaseSonno.leggero,
        ),
        campione(
          DateTime(2026, 8, 10, 23, 0),
          DateTime(2026, 8, 11, 6, 0),
          FaseSonno.leggero,
        ),
      ]);

      expect(await archivio.ultimaNotteConDati(), DateTime(2026, 8, 11));
    });
  });

  /// La regola dettata il 12/08/2026, provando l'app sul telefono:
  ///
  /// *«Il sonno deve cominciare quando mi sono addormentato e finire quando mi
  /// sono svegliato. Se vado a letto alle 21:00 e mi sveglio alle 08:00 me lo
  /// deve considerare tutto come questa notte; poi magari mi faccio una pennica
  /// dalle 15:00 alle 16:30, si deve aggiungere alla giornata di oggi.»*
  group('a quale giornata si accredita il riposo', () {
    test('chi va a letto la sera dorme per il giorno DOPO', () {
      expect(notteDi(DateTime(2026, 8, 12, 21, 0)), DateTime(2026, 8, 13));
      expect(notteDi(DateTime(2026, 8, 12, 23, 30)), DateTime(2026, 8, 13));
    });

    test('le ore piccole sono la stessa dormita, non un\'altra', () {
      expect(notteDi(DateTime(2026, 8, 13, 2, 0)), DateTime(2026, 8, 13));
      expect(notteDi(DateTime(2026, 8, 13, 7, 59)), DateTime(2026, 8, 13));
    });

    /// 🚨 **Il caso che boccia la correzione ovvia.**
    ///
    /// Tenere lo spartiacque a mezzogiorno e spostare l'etichetta di un giorno
    /// sistemerebbe la notte e manderebbe la pennica delle 15:00 a **domani**.
    /// Servono due soglie diverse perché sono due cose diverse.
    test('la pennica del pomeriggio si somma a OGGI', () {
      expect(notteDi(DateTime(2026, 8, 13, 15, 0)), DateTime(2026, 8, 13));
      expect(notteDi(DateTime(2026, 8, 13, 16, 30)), DateTime(2026, 8, 13));
    });

    test(
      'la notte e la pennica dello stesso giorno finiscono insieme',
      () async {
        // Dorme dalle 21:00 del 12 alle 08:00 del 13.
        await archivio.scriviCampioniSonno([
          campione(
            DateTime(2026, 8, 12, 21, 0),
            DateTime(2026, 8, 13, 8, 0),
            FaseSonno.leggero,
          ),
          // E si fa una pennica il pomeriggio del 13.
          campione(
            DateTime(2026, 8, 13, 15, 0),
            DateTime(2026, 8, 13, 16, 30),
            FaseSonno.leggero,
          ),
        ]);

        expect(
          await archivio.campioniDellaNotte(DateTime(2026, 8, 13)),
          hasLength(2),
        );
        expect(
          await archivio.campioniDellaNotte(DateTime(2026, 8, 12)),
          isEmpty,
        );
      },
    );

    /// ⚠️ `DateTime(y, m, d + 1)` e non `add(Duration(days: 1))`.
    ///
    /// Il 25 ottobre 2026 a Roma dura **25 ore**: sommare 86.400 secondi a
    /// mezzanotte cade alle 23:00 dello stesso giorno, e il riposo di quella
    /// notte finirebbe nel giorno sbagliato — una volta l'anno, senza che
    /// nessuno colleghi le due cose.
    test('la sera del cambio d\'ora accredita comunque al giorno dopo', () {
      expect(notteDi(DateTime(2026, 10, 24, 23, 0)), DateTime(2026, 10, 25));
      expect(notteDi(DateTime(2026, 10, 25, 23, 0)), DateTime(2026, 10, 26));
    });

    test('la mezzanotte esatta appartiene al giorno che comincia', () {
      expect(notteDi(DateTime(2026, 8, 13, 0, 0)), DateTime(2026, 8, 13));
    });
  });

  /// 🚨 Con i dati sul telefono, «cancella il mio account» **deve** arrivare
  /// fin qui: il server non può cancellare ciò che non ha mai avuto.
  test('svuota() non lascia niente dietro', () async {
    await archivio.scriviLetture([
      lettura(MetricaSalute.hrv, 48, DateTime(2026, 8, 11, 7)),
    ]);
    await archivio.scriviCampioniSonno([
      campione(
        DateTime(2026, 8, 10, 23, 0),
        DateTime(2026, 8, 11, 6, 0),
        FaseSonno.leggero,
      ),
    ]);

    await archivio.svuota();

    expect(
      await archivio.lettureRecenti(MetricaSalute.hrv, giorni: 3650),
      isEmpty,
    );
    expect(await archivio.campioniDellaNotte(DateTime(2026, 8, 11)), isEmpty);
  });

  group('il corpo — S5.2', () {
    Future<void> pesa(double kg, DateTime giorno) =>
        archivio.registraMisura(MisuraCorpo(id: 0, giorno: giorno, pesoKg: kg));

    /// 🚨 Pesarsi due volte lo stesso giorno è una **correzione**, non un
    /// secondo punto sul grafico: la bilancia si guarda spesso due volte di
    /// seguito, e due punti a un minuto di distanza lo renderebbero illeggibile.
    ///
    /// Era `UNIQUE(user_id, date)` sul server. La regola non cambia perché
    /// cambia casa.
    test('due pesate nello stesso giorno sono una correzione', () async {
      await pesa(84.5, DateTime(2026, 8, 11));
      await pesa(84.2, DateTime(2026, 8, 11));

      final storico = await archivio.storicoMisure();

      expect(storico, hasLength(1));
      expect(storico.single.pesoKg, 84.2);
    });

    test('lo storico torna dalla più recente', () async {
      await pesa(85.0, DateTime(2026, 8, 4));
      await pesa(84.2, DateTime(2026, 8, 11));

      final storico = await archivio.storicoMisure();

      expect(storico.first.pesoKg, 84.2);
      expect(storico.last.pesoKg, 85.0);
    });

    /// ⚠️ **L'ultimo con un peso**, non l'ultima riga: una misura può portare
    /// solo la circonferenza della vita, e in quel caso il peso non è
    /// cambiato — è solo assente da quella riga.
    test('l\'ultimo peso salta le misure che non ne hanno', () async {
      await pesa(84.2, DateTime(2026, 8, 10));

      await archivio.registraMisura(
        MisuraCorpo(id: 0, giorno: DateTime(2026, 8, 11), vitaCm: 88),
      );

      final ultimo = await archivio.ultimoPeso();

      expect(ultimo!.pesoKg, 84.2);
      expect(ultimo.giorno, DateTime(2026, 8, 10));
    });

    test('svuota() porta via anche il corpo', () async {
      await pesa(84.2, DateTime(2026, 8, 11));

      await archivio.svuota();

      expect(await archivio.storicoMisure(), isEmpty);
    });
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
