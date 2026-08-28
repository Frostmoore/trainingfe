import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/forma/carica_batteria.dart';

/// La Carica — 3b-K, 28/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Una formula di diciassette passaggi in cui **ogni errore produce un numero
/// plausibile**. Non esiste un modo di accorgersene guardando lo schermo: `72`
/// sembra giusto quanto `61`.
///
/// Le tre cose che, sbagliate, non danno nessun errore:
///
/// 1. **Il verso del battito.** Invertirlo fa salire il recupero proprio quando
///    dovrebbe calare — ed è lo stesso errore già documentato in
///    `IndiciDiForma.carica`.
/// 2. **Le calorie dell'allenamento contate due volte.** Sono un sottoinsieme
///    delle attive: sommarle farebbe crollare la batteria nei giorni di
///    allenamento, cioè sempre nel verso sbagliato.
/// 3. **La persistenza.** Se la Carica si ricalcolasse da zero ogni mattina,
///    tutto continuerebbe a funzionare — e sparirebbe l'unica proprietà per cui
///    esiste.
///
/// 💡 I numeri attesi vengono dall'esempio completo della specifica: è
/// l'ancora che dice se l'implementazione è **quella chiesta**, non solo una
/// che gira.
void main() {
  DateTime giorno(int g) => DateTime(2026, 8, g);

  group('il sonno', () {
    test('otto ore su otto fanno 1', () {
      expect(CaricaBatteria.rapportoDiSonno(minutiDormiti: 480), 1.0);
    });

    test('si ferma a 1.20 anche dormendo quattordici ore', () {
      // 💡 Dormire il doppio non recupera il doppio, e senza tetto una notte
      // anomala falserebbe la settimana.
      expect(CaricaBatteria.rapportoDiSonno(minutiDormiti: 840), 1.20);
    });

    test('senza sonno è null, non zero', () {
      /*
       * 🚨 **Zero vorrebbe dire «non ha dormito»**, che è una conclusione.
       * `null` vuol dire «non lo sappiamo», ed è l'unica cosa vera.
       */
      expect(CaricaBatteria.rapportoDiSonno(minutiDormiti: null), isNull);
    });

    test('un obiettivo a zero non è un obiettivo', () {
      expect(
        CaricaBatteria.rapportoDiSonno(minutiDormiti: 480, obiettivo: 0),
        isNull,
      );
    });
  });

  group('il primo giorno', () {
    test('con otto ore si parte da 90', () {
      // 📌 L'esempio della specifica: `55 + 35 × 1 = 90`.
      expect(CaricaBatteria.caricaIniziale(rapportoDiSonno: 1), 90);
    });

    test('senza sonno si parte da 75', () {
      expect(CaricaBatteria.caricaIniziale(), 75);
    });

    test('non si parte mai da 100', () {
      /*
       * ⚠️ Partire pieni direbbe che sappiamo qualcosa che non sappiamo, e il
       * primo calo sembrerebbe un crollo.
       */
      expect(
        CaricaBatteria.caricaIniziale(rapportoDiSonno: 1.20),
        lessThanOrEqualTo(95),
      );
    });
  });

  group('i riferimenti', () {
    test('senza storico sono le quote del TDEE', () {
      final r = CaricaBatteria.riferimenti(tdeeDiBase: 2100, giorniValidi: 0);

      expect(r.allenamento, 630);
      expect(r.attivita, 420);
    });

    test('a 28 giorni sono del tutto personali', () {
      final r = CaricaBatteria.riferimenti(
        tdeeDiBase: 2100,
        giorniValidi: 28,
        allenamentoPersonale: 800,
        attivitaPersonale: 300,
      );

      expect(r.allenamento, 800);
      expect(r.attivita, 300);
    });

    test('a metà strada sono a metà', () {
      final r = CaricaBatteria.riferimenti(
        tdeeDiBase: 2100,
        giorniValidi: 14,
        allenamentoPersonale: 830,
      );

      // 💡 `lambda = 0.5`: metà di 630 e metà di 830.
      expect(r.allenamento, closeTo(730, 0.01));
    });

    test('un riferimento personale a zero non si usa', () {
      /*
       * ⛔ Chi non si è mai allenato ha una mediana di zero: dividerci sopra
       * darebbe una scarica infinita al primo allenamento.
       */
      final r = CaricaBatteria.riferimenti(
        tdeeDiBase: 2100,
        giorniValidi: 28,
        allenamentoPersonale: 0,
      );

      expect(r.allenamento, 630);
    });
  });

  group('la scarica', () {
    test('l\'esempio della specifica, passo per passo', () {
      /*
       * 📌 600 kcal di allenamento su 900 attive, TDEE 2100:
       * allenamento 25 × (600/630) ≈ 23.8, attività 10 × (300/420) ≈ 7.1.
       */
      final d = CaricaBatteria.scarica(
        calorieAttive: 900,
        calorieAllenamento: 600,
        riferimentoAllenamento: 630,
        riferimentoAttivita: 420,
      );

      expect(d, closeTo(30.9, 0.1));
    });

    test('l\'allenamento non si conta due volte', () {
      /*
       * 🚨 **Sono un sottoinsieme delle attive.** Se si sommassero, questa
       * giornata scaricherebbe come se avesse bruciato 1500 kcal invece di 900
       * — e la batteria crollerebbe **nei giorni di allenamento**, cioè sempre
       * nel verso sbagliato.
       */
      final conAllenamento = CaricaBatteria.scarica(
        calorieAttive: 900,
        calorieAllenamento: 600,
        riferimentoAllenamento: 630,
        riferimentoAttivita: 420,
      );

      final tuttoQuotidiano = CaricaBatteria.scarica(
        calorieAttive: 900,
        calorieAllenamento: 0,
        riferimentoAllenamento: 630,
        riferimentoAttivita: 420,
      );

      // 💡 A parità di calorie, l'allenamento pesa **di più**.
      expect(conAllenamento, greaterThan(tuttoQuotidiano));
    });

    test('non supera mai il tetto giornaliero', () {
      /*
       * ⚠️ È una difesa, non un'estetica: un orologio che sbaglia una volta non
       * deve poter azzerare una batteria che si trascina per giorni.
       */
      final d = CaricaBatteria.scarica(
        calorieAttive: 99999,
        calorieAllenamento: 99999,
        riferimentoAllenamento: 630,
        riferimentoAttivita: 420,
      );

      expect(d, CaricaBatteria.scaricaMassimaAlGiorno);
    });

    test('senza calorie la batteria NON scende', () {
      /*
       * ⛔ Inventare una scarica media farebbe calare la carica a chi ha
       * lasciato l'orologio nel cassetto: gli si direbbe che è stanco perché
       * non lo stiamo guardando.
       */
      expect(
        CaricaBatteria.scarica(
          calorieAttive: null,
          calorieAllenamento: null,
          riferimentoAllenamento: 630,
          riferimentoAttivita: 420,
        ),
        0,
      );
    });

    test('senza le calorie dell\'allenamento diventa tutto quotidiano', () {
      final d = CaricaBatteria.scarica(
        calorieAttive: 420,
        calorieAllenamento: null,
        riferimentoAllenamento: 630,
        riferimentoAttivita: 420,
      );

      // 💡 420 su un riferimento di 420 = 10 punti pieni di attività.
      expect(d, closeTo(10, 0.01));
    });
  });

  group('la fisiologia', () {
    test('il battito va INVERTITO', () {
      /*
       * 🚨 **L'errore di segno più facile di tutto il file.** Un battito sopra
       * la propria media è un segnale di stanchezza: se non si invertisse, il
       * recupero salirebbe proprio quando dovrebbe calare.
       */
      expect(CaricaBatteria.punteggioFisiologico(zBattito: 1), -1);
      expect(CaricaBatteria.punteggioFisiologico(zBattito: -1), 1);
    });

    test('HRV alto è positivo', () {
      expect(CaricaBatteria.punteggioFisiologico(zHrv: 1.5), 1.5);
    });

    test('i due si mediano', () {
      // HRV +2, battito +1 (che invertito è −1): media 0.5.
      expect(
        CaricaBatteria.punteggioFisiologico(zHrv: 2, zBattito: 1),
        closeTo(0.5, 0.001),
      );
    });

    test('si ferma a ±2', () {
      expect(CaricaBatteria.punteggioFisiologico(zHrv: 9), 2);
      expect(CaricaBatteria.punteggioFisiologico(zHrv: -9), -2);
    });

    test('senza niente è zero, e zero non è un giudizio', () {
      // ⛔ Non vuol dire «sta nella media»: vuol dire «non c'è correzione».
      expect(CaricaBatteria.punteggioFisiologico(), 0);
    });
  });

  group('il recupero', () {
    test('sonno normale e fisiologia normale danno 0.70', () {
      // 📌 `0.15 + 0.55 × 1 = 0.70` — l'esempio della specifica.
      expect(
        CaricaBatteria.frazioneDiRecupero(rapportoDiSonno: 1),
        closeTo(0.70, 0.0001),
      );
    });

    test('l\'esempio della seconda notte', () {
      // 📌 7.5 ore su 8: `0.15 + 0.55 × 0.9375 = 0.666`.
      expect(
        CaricaBatteria.frazioneDiRecupero(rapportoDiSonno: 450 / 480),
        closeTo(0.666, 0.001),
      );
    });

    test('senza sonno è 0.55', () {
      expect(CaricaBatteria.frazioneDiRecupero(rapportoDiSonno: null), 0.55);
    });

    test('non scende mai sotto 0.15 né sale sopra 0.90', () {
      expect(
        CaricaBatteria.frazioneDiRecupero(
          rapportoDiSonno: 0,
          punteggioFisiologico: -2,
        ),
        0.15,
      );

      expect(
        CaricaBatteria.frazioneDiRecupero(
          rapportoDiSonno: 1.20,
          punteggioFisiologico: 2,
        ),
        lessThanOrEqualTo(0.90),
      );
    });

    test('recupera una FRAZIONE del mancante, non punti fissi', () {
      /*
       * 🚨 È la proprietà che fa sopravvivere la fatica da un giorno all'altro:
       * chi è molto scarico recupera **molto** in valore assoluto ma non torna
       * mai pieno.
       */
      final daBasso = CaricaBatteria.mattinoDopo(
        caricaDellaSera: 40,
        frazioneDiRecupero: 0.70,
      );

      final daAlto = CaricaBatteria.mattinoDopo(
        caricaDellaSera: 90,
        frazioneDiRecupero: 0.70,
      );

      expect(daBasso, closeTo(82, 0.01));
      expect(daAlto, closeTo(97, 0.01));

      // ⛔ E non si arriva **mai** a 100 con una notte sola.
      expect(daBasso, lessThan(100));
      expect(daAlto, lessThan(100));
    });
  });

  group('la catena, che è il motivo per cui la Carica esiste', () {
    test('l\'esempio completo della specifica, dal primo giorno', () {
      final c = CaricaBatteria.catena(
        tdeeDiBase: 2100,
        giorni: [
          GiornataPerLaCarica(
            giorno: giorno(1),
            calorieAttive: 900,
            calorieAllenamento: 600,
            minutiDormiti: 480,
          ),
          GiornataPerLaCarica(giorno: giorno(2), minutiDormiti: 450),
        ],
      );

      // 📌 Mattina 90, scarica 30.9, sera 59.1.
      expect(c.first.mattina, 90);
      expect(c.first.sera, closeTo(59.1, 0.1));

      // 📌 Recupero 0.666 su 40.9 mancanti ≈ 27.2 → 86.3.
      expect(c.last.mattina, closeTo(86.3, 0.2));
    });

    test('la fatica non recuperata si trascina', () {
      /*
       * 🚨 **È l'unica proprietà per cui la Carica esiste**, ed è quella che
       * sparirebbe se qualcuno la ricalcolasse da zero ogni mattina: tutto
       * continuerebbe a funzionare, e nessun test se ne accorgerebbe — tranne
       * questo.
       */
      final giorni = [
        for (var i = 1; i <= 5; i++)
          GiornataPerLaCarica(
            giorno: giorno(i),
            calorieAttive: 1200,
            calorieAllenamento: 900,

            // ⚠️ Poco sonno: si recupera meno di quel che si consuma.
            minutiDormiti: 300,
          ),
      ];

      final c = CaricaBatteria.catena(tdeeDiBase: 2100, giorni: giorni);

      // 💡 Ogni mattina si parte più bassi della precedente.
      for (var i = 1; i < c.length; i++) {
        expect(
          c[i].mattina,
          lessThan(c[i - 1].mattina),
          reason: 'il giorno $i non ha trascinato la fatica del giorno ${i - 1}',
        );
      }
    });

    test('e con poco carico e tanto sonno risale', () {
      final giorni = [
        GiornataPerLaCarica(
          giorno: giorno(1),
          calorieAttive: 1500,
          calorieAllenamento: 1200,
          minutiDormiti: 480,
        ),
        for (var i = 2; i <= 4; i++)
          GiornataPerLaCarica(
            giorno: giorno(i),
            calorieAttive: 100,
            calorieAllenamento: 0,
            minutiDormiti: 480,
          ),
      ];

      final c = CaricaBatteria.catena(tdeeDiBase: 2100, giorni: giorni);

      expect(c.last.mattina, greaterThan(c[1].mattina));
    });

    test('un giorno senza orologio non scarica, ma recupera', () {
      /*
       * ⛔ Chi lascia l'orologio a casa non deve trovarsi la batteria scesa: non
       * si sa cosa ha fatto, e inventarlo sarebbe peggio che ammetterlo.
       */
      final c = CaricaBatteria.catena(
        tdeeDiBase: 2100,
        daCapo: 50,
        giorni: [
          GiornataPerLaCarica(giorno: giorno(1), minutiDormiti: 480),
          GiornataPerLaCarica(giorno: giorno(2), minutiDormiti: 480),
        ],
      );

      expect(c.first.sera, 50);
      expect(c.last.mattina, greaterThan(50));
    });

    test('si può ripartire da una carica già nota', () {
      // 💡 Serve a non ricalcolare mesi di storico a ogni apertura dell'app.
      final c = CaricaBatteria.catena(
        tdeeDiBase: 2100,
        daCapo: 42,
        giorni: [GiornataPerLaCarica(giorno: giorno(1))],
      );

      expect(c.single.mattina, 42);
    });

    test('la fisiologia del giorno DOPO decide il recupero di questa notte', () {
      /*
       * ⚠️ Si dorme **fra** i due giorni, e HRV e battito si misurano al
       * risveglio: usare quelli di oggi vorrebbe dire far decidere a ieri come
       * si è dormito stanotte.
       */
      List<GiornoDiCarica> con({required double zHrvDomani}) =>
          CaricaBatteria.catena(
            tdeeDiBase: 2100,
            daCapo: 50,
            giorni: [
              GiornataPerLaCarica(giorno: giorno(1), minutiDormiti: 480),
              GiornataPerLaCarica(
                giorno: giorno(2),
                minutiDormiti: 480,
                zHrv: zHrvDomani,
              ),
            ],
          );

      expect(
        con(zHrvDomani: 2).last.mattina,
        greaterThan(con(zHrvDomani: -2).last.mattina),
      );
    });
  });

  group('l\'affidabilità', () {
    test('cresce coi giorni', () {
      Affidabilita a(int giorni) => Affidabilita.da(
        giorniValidi: giorni,
        senzaSonno: false,
        senzaFisiologia: false,
        senzaAttivita: false,
      );

      expect(a(3), Affidabilita.bassa);
      expect(a(10), Affidabilita.media);
      expect(a(40), Affidabilita.alta);
    });

    test('ma i dati mancanti la abbassano', () {
      expect(
        Affidabilita.da(
          giorniValidi: 40,
          senzaSonno: true,
          senzaFisiologia: false,
          senzaAttivita: false,
        ),
        Affidabilita.media,
      );
    });

    test('senza calorie è sempre bassa, per quanti giorni ci siano', () {
      /*
       * 🚨 Senza quelle non si sa nemmeno quanto si è consumato: manca il
       * numeratore di tutta la scarica, e sei mesi di storico non lo rimpiazzano.
       */
      expect(
        Affidabilita.da(
          giorniValidi: 400,
          senzaSonno: false,
          senzaFisiologia: false,
          senzaAttivita: true,
        ),
        Affidabilita.bassa,
      );
    });
  });

  group('la carica adesso', () {
    test('cala durante la giornata', () {
      expect(
        CaricaBatteria.adesso(caricaDelMattino: 90, scaricaFinora: 12),
        78,
      );
    });

    test('non scende sotto zero', () {
      expect(
        CaricaBatteria.adesso(caricaDelMattino: 10, scaricaFinora: 99),
        0,
      );
    });
  });
}
