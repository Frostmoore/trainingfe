import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/health/tipo_allenamento.dart';
import 'package:training_companion/src/features/training/statistiche_allenamento.dart';

/// I numeri di un allenamento — 08/09/2026.
///
/// ══ 🚨 COSA DIFENDONO ════════════════════════════════════════════════════
///
/// Questi numeri non entrano in nessun calcolo: si **leggono**. ⛔ Ed è proprio
/// per questo che sbagliarli è insidioso — nessuna somma va storta, nessun test
/// diventa rosso. Semplicemente qualcuno guarda «4:30 /km» dopo una passeggiata
/// e si convince di essere in forma, o vede «passo 1,8 m» e smette di fidarsi
/// della pagina.
void main() {
  StatisticheAllenamento con({
    required String tipo,
    Duration durata = const Duration(minutes: 60),
    int? metri,
    int? passi,
    int? kcal,
    int? battitoMedio,
    int? battitoMassimo,
    double? velocitaMisurataMs,
    double? dislivelloMetri,
  }) => StatisticheAllenamento(
    tipo: tipo,
    durata: durata,
    distanzaMetri: metri,
    passi: passi,
    kcal: kcal,
    battitoMedio: battitoMedio,
    battitoMassimo: battitoMassimo,
    velocitaMisurataMs: velocitaMisurataMs,
    dislivelloMetri: dislivelloMetri,
  );

  group('🚶 una camminata', () {
    // Un'ora, 5 km, 6.500 passi: una passeggiata vera.
    final passeggiata = con(
      tipo: 'WALKING',
      metri: 5000,
      passi: 6500,
      kcal: 240,
    );

    test('📏 la distanza è in km', () {
      expect(passeggiata.km, 5.0);
    });

    test('⚡ la velocità si CALCOLA, perché `SPEED` non arriva', () {
      /*
       * 🚨 La sonda dell'08/09 su novanta giorni: `SPEED nessun campione`,
       * benché l'app dell'orologio abbia `WRITE_SPEED` concesso. 💡 Distanza
       * diviso tempo è l'unica strada, ed è anche quella giusta per una media.
       */
      expect(passeggiata.velocitaKmH, 5.0);
    });

    test('⏱️ il passo è 12:00 al km', () {
      expect(passeggiata.passoAlKm, const Duration(minutes: 12));
    });

    test('👣 la cadenza è poco più di cento passi al minuto', () {
      /*
       * 💡 Una camminata sta fra 100 e 120, una corsa fra 160 e 180: se un
       * giorno questo numero uscisse a 20 o a 400, la formula ha perso un
       * fattore sessanta — ed è l'errore più facile da fare qui.
       */
      expect(passeggiata.cadenzaAlMinuto, closeTo(108.3, 0.1));
    });

    test('📐 e il passo è lungo 77 cm, misurato e non stimato', () {
      /*
       * ⚠️ **Misurato**: distanza e passi vengono tutti e due dall'orologio. 🚨 È
       * un numero diverso da quello di `CalorieDalCammino`, che usa
       * `0.415 × altezza` — una media di popolazione. Che i due si somiglino è
       * un buon segno; che qualcuno un giorno li «unifichi» sarebbe un errore.
       */
      expect(passeggiata.lunghezzaDelPasso, closeTo(0.77, 0.01));
    });
  });

  group('🚴 una pedalata', () {
    final giro = con(
      tipo: 'BIKING',
      durata: const Duration(minutes: 90),
      metri: 30000,
      passi: 400,
    );

    test('⚡ la velocità c\'è', () {
      expect(giro.velocitaKmH, closeTo(20.0, 0.01));
    });

    test('⛔ ma il passo al km NO, e non è pignoleria', () {
      /*
       * 🚨 «3:00 al km» su una pedalata è un numero **vero** e senza senso: in
       * bici quell'andatura non si legge così. ⛔ E accanto alla velocità
       * direbbe due volte la stessa cosa, facendo cercare a chi legge una
       * differenza che non c'è.
       */
      expect(giro.passoAlKm, isNull);
    });

    test('⛔ e nemmeno la cadenza o la lunghezza del passo', () {
      /*
       * ⚠️ I 400 «passi» di una pedalata sono l'oscillazione del polso sul
       * manubrio. 💡 Contarli come falcate darebbe un passo da 75 metri.
       */
      expect(giro.cadenzaAlMinuto, isNull);
      expect(giro.lunghezzaDelPasso, isNull);
    });
  });

  group('🏋️ una seduta di pesi', () {
    final pesi = con(
      tipo: 'STRENGTH_TRAINING',
      durata: const Duration(minutes: 45),
      metri: 320,
      passi: 480,
      kcal: 300,
    );

    test('⛔ i 320 metri fra un attrezzo e l\'altro NON sono una distanza', () {
      /*
       * 🚨 **È il difetto che questo test esiste per fermare.** L'orologio quei
       * metri li scrive davvero, e mostrarli come «distanza dell'allenamento»
       * sarebbe una cosa falsa detta con un numero vero — la categoria di
       * difetto che in questo progetto è costata di più.
       */
      expect(pesi.km, isNull);
      expect(pesi.velocitaKmH, isNull);
    });

    test('✅ ma tempo e intensità restano, e bastano a mostrare la card', () {
      expect(pesi.kcalAlMinuto, closeTo(6.67, 0.01));
    });

    test('⛔ senza battito e senza distanza la card non si disegna', () {
      final nuda = con(
        tipo: 'STRENGTH_TRAINING',
        durata: const Duration(minutes: 45),
      );

      expect(nuda.qualcosaDaDire, isFalse);
    });

    test('✅ con il battito sì: è quello che di una seduta si sa', () {
      expect(
        con(tipo: 'STRENGTH_TRAINING', battitoMedio: 118).qualcosaDaDire,
        isTrue,
      );
    });
  });

  group('⛔ quello che non si mostra mai', () {
    test('una distanza a zero non è una distanza', () {
      expect(con(tipo: 'RUNNING', metri: 0).km, isNull);
    });

    test('un allenamento di durata nulla non ha una velocità', () {
      /*
       * ⚠️ Non è teorico: una sessione interrotta sul nascere ha inizio e fine
       * identici, e senza questa guardia sarebbe una divisione per zero — cioè
       * `Infinity` scritto a schermo.
       */
      expect(
        con(tipo: 'RUNNING', durata: Duration.zero, metri: 1000).velocitaKmH,
        isNull,
      );
    });

    test('🚨 e un passo da 3,4 metri non è un passo', () {
      /*
       * 💡 Succede quando l'orologio attribuisce a una sessione una distanza
       * che con quei passi non c'entra — tipico di una pedalata registrata col
       * telefono in tasca. ⛔ Un numero assurdo in mezzo a numeri giusti rende
       * sospetti anche quelli giusti.
       */
      expect(
        con(tipo: 'WALKING', metri: 10000, passi: 2900).lunghezzaDelPasso,
        isNull,
      );
    });
  });

  group('🗺️ la classificazione dei tipi', () {
    test('✅ gli aperti hanno un percorso da chiedere', () {
      for (final tipo in ['WALKING', 'RUNNING', 'BIKING', 'HIKING']) {
        expect(TipoAllenamento.conPercorso(tipo), isTrue, reason: tipo);
      }
    });

    test('⛔ i chiusi che ci somigliano NO', () {
      /*
       * 🚨 **Sono quelli che si fanno includere da chiunque copi la lista senza
       * leggerla**: il nome è lo stesso più un suffisso, e l'attività è la
       * stessa — ma dentro una palestra il GPS non scrive niente, e chiedere il
       * percorso costa una richiesta a schermo acceso per avere un vuoto.
       */
      for (final tipo in [
        'RUNNING_TREADMILL',
        'WALKING_TREADMILL',
        'BIKING_STATIONARY',
        'ROWING_MACHINE',
        'SWIMMING_POOL',
        'ELLIPTICAL',
      ]) {
        expect(TipoAllenamento.conPercorso(tipo), isFalse, reason: tipo);
      }
    });

    test('💡 il tapis roulant però un passo al km ce l\'ha', () {
      /*
       * ⚠️ Percorso no, andatura sì — ed è esattamente il numero che si guarda
       * correndo su un tapis roulant. 🚨 Le due domande sono diverse, ed è per
       * questo che gli elenchi sono due.
       */
      expect(TipoAllenamento.conPercorso('RUNNING_TREADMILL'), isFalse);
      expect(TipoAllenamento.aPiedi('RUNNING_TREADMILL'), isTrue);
    });

    test('⚠️ `OTHER` si chiede, perché è dove finiscono le uscite vere', () {
      expect(TipoAllenamento.conPercorso('OTHER'), isTrue);
    });

    test('⛔ i pesi non sono niente di tutto questo', () {
      expect(TipoAllenamento.conPercorso('STRENGTH_TRAINING'), isFalse);
      expect(TipoAllenamento.aPiedi('STRENGTH_TRAINING'), isFalse);
      expect(TipoAllenamento.conDistanza('STRENGTH_TRAINING'), isFalse);
    });
  });

  group('⌚ la velocità la dice l’orologio', () {
    /*
     * ══ 🚨 LA CAMMINATA VERA DELL'08/09 ═══════════════════════════════════
     *
     * 📌 Il committente: *«dovremo usare i dati dell'orologio, perché
     * presumibilmente tiene da conto il fatto che mi sono fermato 10 minuti al
     * bar e la discrepanza arriva da quello»*.
     *
     * I numeri sono quelli misurati: 27 minuti, 1.270 m di GPS, 3.523 passi, e
     * l'orologio che dichiara 3,792 km/h — cioè 1,053 m/s.
     */
    final camminata = con(
      tipo: 'WALKING',
      durata: const Duration(minutes: 27),
      metri: 1270,
      passi: 3523,
      velocitaMisurataMs: 1.053,
      dislivelloMetri: 27,
    );

    test('✅ vince quella misurata, non quella calcolata', () {
      // 💡 Il calcolo darebbe 2,82 km/h: il 34% più bassa.
      expect(camminata.velocitaKmH, closeTo(3.79, 0.02));
      expect(camminata.velocitaDallOrologio, isTrue);
    });

    test('⚠️ e il passo viene dalla STESSA fonte', () {
      /*
       * 🚨 Questo è il difetto che il test esiste per fermare: velocità
       * dall'orologio e passo dal calcolo darebbero «3,79 km/h» accanto a
       * «21:15 /km», che è il passo di 2,8 km/h. Due numeri che si smentiscono
       * a vicenda nella stessa card.
       */
      expect(camminata.passoAlKm!.inSeconds, closeTo(950, 10));
    });

    test('⛔ senza orologio si ricade sul calcolo, e si dichiara', () {
      final stimata = con(
        tipo: 'WALKING',
        durata: const Duration(minutes: 27),
        metri: 1270,
      );

      expect(stimata.velocitaKmH, closeTo(2.82, 0.02));
      expect(stimata.velocitaDallOrologio, isFalse);
    });

    test('🚨 e la falcata da 36 cm NON si mostra', () {
      /*
       * ⛔ 1.270 m contro 3.523 passi fanno 36 cm. Non è un passo corto: è la
       * prova che GPS e contapassi non sono d'accordo. 🚨 La banda era `0.3` e
       * questo numero ci passava: è stata alzata a mezzo metro **dopo** averlo
       * visto.
       */
      expect(camminata.lunghezzaDelPasso, isNull);
    });

    test('⛰️ il dislivello arriva, e non dipende dal percorso', () {
      expect(camminata.dislivelloMetri, 27);
    });
  });

  group('⛰️ il dislivello da solo', () {
    test('✅ basta a far comparire la card', () {
      /*
       * 💡 Una salita in palestra non esiste, ma un'escursione senza distanza
       * registrata sì — e 300 metri di dislivello sono la cosa più importante
       * che le è successa.
       */
      expect(con(tipo: 'HIKING', dislivelloMetri: 300).qualcosaDaDire, isTrue);
    });

    test('⛔ e zero metri non è «non lo sappiamo»', () {
      // 🚨 Zero è una pianura, ed è un dato. `null` è l'assenza.
      expect(con(tipo: 'WALKING', dislivelloMetri: 0).dislivelloMetri, 0);
      expect(con(tipo: 'WALKING').dislivelloMetri, isNull);
    });
  });

  group('✍️ come si scrivono', () {
    /*
     * ⛔ **I due test sulla durata sono spariti con il formattatore.**
     *
     * Scriveva `47m` e `1h 24m`, e viveva in `NumeriDellAllenamento` — la card
     * che l'08/09 è stata assorbita dal carosello. 🚨 Lì la durata si scrive
     * come numero e basta («27» sopra «minuti»), quindi quel formattatore non
     * lo chiamava più nessuno.
     *
     * ⚠️ **Un test su codice morto è peggio di nessun test**: resta verde per
     * sempre e fa credere che qualcosa sia protetto. 💡 La regola che difendeva
     * — mai «0h 47m» — vale ancora, e tornerà scritta il giorno che una durata
     * tornerà a essere formattata.
     */
    test('⏱️ il passo si scrive «5:42», non «5,7»', () {
      expect(
        StatisticheAllenamento.passoScritto(
          const Duration(minutes: 5, seconds: 42),
        ),
        '5:42',
      );
    });

    test('⚠️ e i secondi hanno sempre due cifre', () {
      // 🚨 `6:5` si legge come sei minuti e cinque decimi.
      expect(
        StatisticheAllenamento.passoScritto(
          const Duration(minutes: 6, seconds: 5),
        ),
        '6:05',
      );
    });

    test(
      '🚨 e il passo scritto viene dalla stessa fonte del passo calcolato',
      () {
        /*
       * ⛔ **Questo test nasce da un difetto vero, visto a schermo l'08/09**:
       * il carosello diceva «21:16 al chilometro» e la card «15:43», nella
       * stessa pagina. Il primo divideva distanza per durata, il secondo usava
       * la velocità dell'orologio.
       *
       * 💡 Adesso il numero lo produce `StatisticheAllenamento` e lo scrive
       * `StatisticheAllenamento`: un posto solo.
       */
        final camminata = con(
          tipo: 'WALKING',
          durata: const Duration(minutes: 27),
          metri: 1270,
          velocitaMisurataMs: 1.053,
        );

        expect(
          StatisticheAllenamento.passoScritto(camminata.passoAlKm!),
          // 💡 3,79 km/h → 15 minuti e 50 secondi per chilometro.
          '15:50',
        );
      },
    );
  });
}
