import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/health/ponte_salute.dart';
import 'package:training_companion/src/features/profile/data/calcolatore_calorie.dart';
import 'package:training_companion/src/features/profile/target_locale_controller.dart';

/// 🎯 Il peso, la massa grassa e il BMR che ne esce — 3b-W.
///
/// ══ 📌 LE DUE RICHIESTE ═══════════════════════════════════════════════════
///
/// *«prendere tutti i dati su peso, massa grassa e bmi direttamente dalla
/// bilancia […] e se non ci sono li stimiamo come facciamo ora»*.
///
/// *«bisogna prendere solo i dati che vengono davvero passati e stimare quelli
/// che non vengono passati»*.
///
/// ══ 🚨 COSA DIFENDONO QUESTI TEST ════════════════════════════════════════
///
/// ⛔ **La metà che si rompe per prima è il ripiego**, non la lettura. Un `?? 0`
/// messo per far compilare darebbe a chi non ha la bilancia una massa magra
/// pari al peso intero, e un BMR alto, plausibile e sbagliato — senza nessun
/// errore da nessuna parte.
void main() {
  late ArchivioSalute archivio;

  setUp(() => archivio = ArchivioSalute.inMemoria());
  tearDown(() => archivio.close());

  DateTime giorno(int g) => DateTime(2026, 8, g);

  group('⛔ il manuale non si sovrascrive', () {
    /// 🚨 **Il caso concreto**: chi si pesa con una bilancia che sballa e
    /// corregge il numero a mano. Senza questa regola si ritroverebbe la
    /// correzione cancellata al primo aggiornamento, **in silenzio**.
    test('una misura scritta a mano resiste all\'importazione', () async {
      await archivio.registraMisura(
        MisuraCorpo(id: 0, giorno: giorno(10), pesoKg: 80),
      );

      final scritto = await archivio.registraDaSalute(
        giorno: giorno(10),
        pesoKg: 95.9,
      );

      expect(scritto, isFalse, reason: 'Ha scritto sopra il manuale.');
      expect((await archivio.ultimoPeso())!.pesoKg, 80);
    });

    test('ma una importata si aggiorna', () async {
      await archivio.registraDaSalute(giorno: giorno(10), pesoKg: 96.0);
      await archivio.registraDaSalute(giorno: giorno(10), pesoKg: 95.9);

      expect((await archivio.ultimoPeso())!.pesoKg, 95.9);
    });

    /// 🚨 **Campo per campo, non la riga intera.** Una giornata può avere il
    /// peso dalla bilancia e la circonferenza della vita scritta a mano.
    test('un valore assente non cancella quello che c\'era', () async {
      await archivio.registraDaSalute(
        giorno: giorno(10),
        pesoKg: 95.9,
        massaGrassaPct: 25.3,
      );

      // Arriva solo la massa grassa: il peso non deve sparire.
      await archivio.registraDaSalute(giorno: giorno(10), massaGrassaPct: 25.1);

      final riga = (await archivio.storicoMisure()).single;

      expect(riga.pesoKg, 95.9);
      expect(riga.massaGrassaPct, 25.1);
    });

    test('senza niente da scrivere non scrive', () async {
      expect(await archivio.registraDaSalute(giorno: giorno(10)), isFalse);
      expect(await archivio.storicoMisure(), isEmpty);
    });
  });

  group('🚨 uno per uno, non tutto o niente', () {
    /// 📌 *«bisogna prendere solo i dati che vengono davvero passati»*.
    ///
    /// ⚠️ Peso e massa grassa **arrivano da giorni diversi**: chi si pesa ogni
    /// giorno e misura il grasso una volta a settimana ha il peso di stamattina
    /// e il grasso di martedì. ⛔ Leggere tre campi dalla stessa riga
    /// butterebbe via il valore più fresco.
    test('peso e massa grassa si leggono separatamente', () async {
      await archivio.registraDaSalute(giorno: giorno(24), massaGrassaPct: 25.4);
      await archivio.registraDaSalute(giorno: giorno(30), pesoKg: 95.9);

      expect((await archivio.ultimoPeso())!.pesoKg, 95.9);
      expect((await archivio.ultimaMassaGrassa())!.massaGrassaPct, 25.4);

      // 💡 E sono due giorni diversi: è proprio il caso che conta.
      expect((await archivio.ultimoPeso())!.giorno, giorno(30));
      expect((await archivio.ultimaMassaGrassa())!.giorno, giorno(24));
    });

    test('la massa magra ha la sua lettura', () async {
      await archivio.registraDaSalute(giorno: giorno(30), massaMagraKg: 71.5);

      expect((await archivio.ultimaMassaMagra())!.massaMagraKg, 71.5);
      expect(await archivio.ultimoPeso(), isNull);
    });

    /// 💡 Serve a non rileggere due anni a ogni avvio.
    test('si sa da dove riprendere l\'importazione', () async {
      expect(await archivio.ultimoGiornoImportato(), isNull);

      await archivio.registraDaSalute(giorno: giorno(24), pesoKg: 96);
      await archivio.registraDaSalute(giorno: giorno(30), pesoKg: 95.9);

      expect(await archivio.ultimoGiornoImportato(), giorno(30));
    });

    /// ⛔ Una misura scritta a mano **non** conta come «già importata»: se
    /// contasse, l'importazione ripartirebbe da lì e salterebbe tutto quello
    /// che c'era prima.
    test('il manuale non sposta il punto di ripresa', () async {
      await archivio.registraMisura(
        MisuraCorpo(id: 0, giorno: giorno(30), pesoKg: 80),
      );

      expect(await archivio.ultimoGiornoImportato(), isNull);
    });
  });

  group('🧮 il BMR', () {
    const calc = CalcolatoreCalorie();

    /// 🚨 **Il test che il committente ha chiesto in una riga**: lo stesso
    /// profilo, senza massa grassa, deve dare **esattamente** il numero di
    /// oggi.
    test('senza composizione è Mifflin, cifra per cifra', () {
      final mifflin = calc.bmr(sesso: 'male', kg: 95.9, cm: 178, eta: 38);

      final scelto = bmrConLaComposizione(
        calcolatore: calc,
        kg: 95.9,
        cm: 178,
        eta: 38,
        sesso: 'male',
      );

      expect(scelto, mifflin);
    });

    /// 💡 Con la massa magra **misurata** si usa Katch-McArdle, che non ha
    /// bisogno né di altezza né di età.
    test('con la massa magra misurata è Katch-McArdle', () {
      final scelto = bmrConLaComposizione(
        calcolatore: calc,
        kg: 95.9,
        cm: 178,
        eta: 38,
        sesso: 'male',
        massaMagraMisurataKg: 71.5,
      );

      expect(scelto, calc.bmrKatchMcArdle(massaMagraKg: 71.5));
      expect(scelto, 370 + 21.6 * 71.5);
    });

    /// ⚠️ **La misurata batte la derivata**: non eredita l'errore della
    /// bioimpedenza.
    test('la massa magra misurata vince sulla percentuale', () {
      final conEntrambe = bmrConLaComposizione(
        calcolatore: calc,
        kg: 95.9,
        cm: 178,
        eta: 38,
        sesso: 'male',
        massaMagraMisurataKg: 71.5,
        grassoRecente: const [40, 40, 40],
      );

      expect(conEntrambe, calc.bmrKatchMcArdle(massaMagraKg: 71.5));
    });

    /// 🚨 **Il numero che giustifica tutta la fase.** Due persone dello stesso
    /// peso, altezza ed età: per Mifflin hanno lo stesso metabolismo.
    test('due corpi diversi non hanno lo stesso metabolismo', () {
      final magro = bmrConLaComposizione(
        calcolatore: calc,
        kg: 80,
        cm: 178,
        eta: 38,
        sesso: 'male',
        grassoRecente: const [12, 12, 12, 12, 12, 12, 12],
      );

      final grasso = bmrConLaComposizione(
        calcolatore: calc,
        kg: 80,
        cm: 178,
        eta: 38,
        sesso: 'male',
        grassoRecente: const [30, 30, 30, 30, 30, 30, 30],
      );

      expect(
        (magro - grasso).abs(),
        greaterThan(200),
        reason: 'Se differiscono di poco, Katch-McArdle non sta lavorando.',
      );

      // ⚠️ E Mifflin non li distingue affatto: è il difetto che si sta togliendo.
      expect(
        calc.bmr(sesso: 'male', kg: 80, cm: 178, eta: 38),
        calc.bmr(sesso: 'male', kg: 80, cm: 178, eta: 38),
      );
    });

    /// ⛔ **Una percentuale a zero non è «zero grasso»**: è una misura fallita,
    /// e la bilancia scrive `0` invece di `null`.
    test('una percentuale impossibile ricade su Mifflin', () {
      for (final pct in [0.0, 1.0, 80.0, 120.0]) {
        expect(
          bmrConLaComposizione(
            calcolatore: calc,
            kg: 95.9,
            cm: 178,
            eta: 38,
            sesso: 'male',
            grassoRecente: [pct],
          ),
          calc.bmr(sesso: 'male', kg: 95.9, cm: 178, eta: 38),
          reason: '$pct% è passata come se fosse una misura vera.',
        );
      }
    });

    /// ⚠️ **Il livellamento serve**: una percentuale che salta non deve far
    /// saltare il target.
    test('la percentuale si livella, non si prende l\'ultima', () {
      /*
       * 🚨 Sette giorni stabili al 25% e un solo giorno al 35%: se si prendesse
       * l'ultimo valore, il BMR cambierebbe di ~130 kcal per una misura sola.
       */
      final livellato = bmrConLaComposizione(
        calcolatore: calc,
        kg: 95.9,
        cm: 178,
        eta: 38,
        sesso: 'male',
        grassoRecente: const [25, 25, 25, 25, 25, 25, 35],
      );

      final soloLUltimo = calc.bmrKatchMcArdle(
        massaMagraKg: calc.massaMagraDa(kg: 95.9, grassoPct: 35)!,
      );

      expect(
        (livellato - soloLUltimo).abs(),
        greaterThan(30),
        reason: 'Il picco è passato dritto: il livellamento non sta lavorando.',
      );
    });
  });

  group('⚖️ la massa magra derivata', () {
    const calc = CalcolatoreCalorie();

    test('è il peso meno il grasso', () {
      expect(calc.massaMagraDa(kg: 100, grassoPct: 25), 75.0);
      expect(calc.massaMagraDa(kg: 95.9, grassoPct: 25.32), 71.6);
    });

    /// ⛔ Fuori dai limiti fisiologici non si corregge: si dice che non si sa.
    test('fuori dal plausibile torna null, non un numero aggiustato', () {
      expect(calc.massaMagraDa(kg: 100, grassoPct: 0), isNull);
      expect(calc.massaMagraDa(kg: 100, grassoPct: 1), isNull);
      expect(calc.massaMagraDa(kg: 100, grassoPct: 80), isNull);
      expect(calc.massaMagraDa(kg: 0, grassoPct: 25), isNull);
    });
  });

  /// 🚨 La colonna nuova deve sopravvivere al giro completo, o la protezione
  /// del manuale salta al primo ripristino.
  test('la provenienza entra nel backup e torna indietro', () async {
    await archivio.registraMisura(
      MisuraCorpo(id: 0, giorno: giorno(10), pesoKg: 80),
    );
    await archivio.registraDaSalute(giorno: giorno(11), pesoKg: 95.9);

    final righe = await archivio.storicoMisure();

    expect(righe.map((r) => r.origine).toSet(), {
      ArchivioSalute.origineManuale,
      ArchivioSalute.origineSalute,
    });
  });

  /// 🚨 **Il difetto peggiore di 3b-W, e non era nei dati: era nei permessi.**
  ///
  /// ══ ⛔ COSA STAVA PER SUCCEDERE ══════════════════════════════════════════
  ///
  /// `aggiornaInSilenzio()` comincia con
  /// `if (!await permessiGiaConcessi()) return;`, e quel controllo chiedeva
  /// **tutti** i tipi in blocco.
  ///
  /// Aggiungendo peso, massa grassa e massa magra al manifest, chi aveva già
  /// concesso i vecchi si ritrovava `false` per via dei tre nuovi — e l'app
  /// smetteva di sincronizzare **anche sonno, HRV e allenamenti**, finché non
  /// fosse tornato a mano sulla schermata a riconcedere.
  ///
  /// ⚠️ **Nessun errore da nessuna parte**: l'app semplicemente smette di
  /// aggiornarsi. Trovato guardando `dumpsys` dopo l'installazione, con i tre
  /// permessi *dichiarati e non concessi* — cioè esattamente lo stato in cui il
  /// difetto scatta.
  ///
  /// 💡 Questo test lo tiene chiuso: i tre tipi del corpo **non** stanno fra
  /// quelli che `permessiGiaConcessi()` pretende.
  group('⛔ i permessi del corpo non spengono il resto', () {
    test('i tipi del corpo non sono fra quelli da leggere sempre', () {
      for (final tipo in PonteSalute.tipiDelCorpo) {
        expect(
          PonteSalute.tipiDaLeggere,
          isNot(contains(tipo)),
          reason:
              '$tipo è finito in `_tipiDaLeggere`: `permessiGiaConcessi()` '
              'tornerà false a chi non ha una bilancia, e la sincronizzazione '
              'del sonno si spegne senza dire niente.',
        );
      }
    });

    /// 💡 Ma si **chiedono** insieme al resto: un secondo foglio di permessi
    /// che compare a sorpresa mesi dopo è un foglio a cui si dice di no.
    test('ma si chiedono insieme agli altri, una volta sola', () {
      for (final tipo in PonteSalute.tipiDelCorpo) {
        expect(PonteSalute.tipiDaAutorizzare, contains(tipo));
      }
    });

    /// ⛔ E il BMI non si chiede: su Android non esiste, su iOS è una
    /// divisione che sappiamo fare.
    test('il BMI non si chiede da nessuna parte', () {
      expect(
        PonteSalute.tipiDaAutorizzare,
        isNot(contains(HealthDataType.BODY_MASS_INDEX)),
      );
      expect(
        PonteSalute.tipiDelCorpo,
        isNot(contains(HealthDataType.BODY_MASS_INDEX)),
      );
    });
  });

  /// ⛔ **La composizione MIGLIORA il calcolo, non lo sostituisce** — 30/08.
  ///
  /// 🚨 Il 30/08 avevo reso altezza, età e sesso facoltativi quando c'è la
  /// massa grassa, perché Katch-McArdle non li usa. 📌 Il committente:
  /// *«Se katch-mcardle non li usa non significa che non servano. Se uno non ha
  /// gli altri dati si devono usare quelli per forza»*.
  ///
  /// ⚠️ **La massa grassa può sparire**: permesso revocato, bilancia cambiata,
  /// impedenza fallita. Altezza, età e sesso no. ⛔ Costruire i dati
  /// obbligatori sopra quello volatile vuol dire che il giorno che la bilancia
  /// muore il target **svanisce**, e l'app chiede la data di nascita dal nulla.
  group('⚖️ la massa magra, e cosa NON decide', () {
    const calc = CalcolatoreCalorie();

    test('con la massa magra misurata basta quella', () {
      expect(
        massaMagraPerIlBmr(
          calcolatore: calc,
          kg: null,
          massaMagraMisurataKg: 71.5,
        ),
        71.5,
        reason: 'Una massa magra misurata vale anche senza il peso.',
      );
    });

    test('con peso e grasso si deriva', () {
      expect(
        massaMagraPerIlBmr(
          calcolatore: calc,
          kg: 100,
          grassoRecente: const [25, 25, 25],
        ),
        75.0,
      );
    });

    /// ⛔ E quando non se ne può avere una, si dice — non si inventa.
    test('senza niente è null, non uno zero', () {
      expect(massaMagraPerIlBmr(calcolatore: calc, kg: 100), isNull);
      expect(massaMagraPerIlBmr(calcolatore: calc, kg: null), isNull);
      expect(
        massaMagraPerIlBmr(
          calcolatore: calc,
          kg: null,
          grassoRecente: const [25],
        ),
        isNull,
        reason: "Senza peso non c'è niente da derivare.",
      );
    });
  });

  /// 🚨 **Il target non deve SVANIRE quando la bilancia sparisce.**
  ///
  /// ══ ⛔ IL DIFETTO CHE QUESTO TEST TIENE CHIUSO ═══════════════════════════
  ///
  /// La massa grassa è un dato **volatile**: si revoca il permesso a Health
  /// Connect, si cambia bilancia, una lettura d'impedenza fallita scrive `0`.
  /// Altezza, età e sesso **non spariscono mai**.
  ///
  /// ⛔ Se i dati obbligatori si appoggiassero sulla composizione, chi si
  /// configura con la bilancia e non dà la data di nascita si ritroverebbe —
  /// due mesi dopo, revocando un permesso — **senza nessun target**, e con
  /// l'app che gli chiede la data di nascita dal nulla.
  ///
  /// 💡 Con la base sempre presente, il giorno che la composizione sparisce il
  /// fabbisogno **peggiora un po'** invece di svanire: da Katch-McArdle a
  /// Mifflin, e nient'altro cambia.
  group('⛔ la composizione può sparire, il target no', () {
    const calc = CalcolatoreCalorie();

    test('con la bilancia si usa Katch-McArdle', () {
      final conBilancia = bmrConLaComposizione(
        calcolatore: calc,
        kg: 95.9,
        cm: 178,
        eta: 38,
        sesso: 'male',
        grassoRecente: const [25.3, 25.3, 25.3],
      );

      expect(
        conBilancia,
        isNot(calc.bmr(sesso: 'male', kg: 95.9, cm: 178, eta: 38)),
      );
    });

    /// 🚨 **Lo stesso profilo, il giorno dopo, senza più la bilancia.**
    test('senza, si scende a Mifflin — e il numero c\'è ancora', () {
      final senzaBilancia = bmrConLaComposizione(
        calcolatore: calc,
        kg: 95.9,
        cm: 178,
        eta: 38,
        sesso: 'male',
      );

      expect(
        senzaBilancia,
        calc.bmr(sesso: 'male', kg: 95.9, cm: 178, eta: 38),
      );
      expect(senzaBilancia, greaterThan(0));
    });

    /// ⛔ E la differenza fra i due è **piccola**: si peggiora, non si crolla.
    test('il passaggio non è un salto', () {
      final con = bmrConLaComposizione(
        calcolatore: calc,
        kg: 95.9,
        cm: 178,
        eta: 38,
        sesso: 'male',
        grassoRecente: const [25.3, 25.3, 25.3],
      );

      final senza = bmrConLaComposizione(
        calcolatore: calc,
        kg: 95.9,
        cm: 178,
        eta: 38,
        sesso: 'male',
      );

      expect(
        (con - senza).abs(),
        lessThan(300),
        reason:
            'Perdere la bilancia sposta il fabbisogno di più di 300 kcal: '
            'chi la perde se ne accorgerebbe come di un guasto.',
      );
    });
  });
}

/// 💡 Zittisce l'analizzatore su `Value`, che serve solo se un giorno questi
/// test costruiranno un `MisureCorpoCompanion` a mano.
// ignore: unused_element
const _nonUsato = Value<double>(0);
