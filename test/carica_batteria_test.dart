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

        /*
         * ⚠️ **`oreSveglio: 0` per isolare le calorie.** L'esempio della
         * specifica è **anteriore** alla scarica da veglia (06/09/2026): i suoi
         * numeri descrivono solo la parte che dipende dai sensori.
         *
         * ⛔ Lasciare il valore di riferimento qui vorrebbe dire un test che
         * dice «la specifica» e verifica un'altra cosa — e il giorno che la
         * parte delle calorie si rompesse, questo resterebbe verde perché il
         * totale finisce comunque contro il tetto.
         */
        oreSveglio: 0,
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

    test('senza calorie scende SOLO per la veglia', () {
      /*
       * ══ 🚨 QUESTO TEST DICEVA IL CONTRARIO — cambiato il 06/09/2026 ═════
       *
       * ⛔ Si chiamava *«senza calorie la batteria NON scende»*, e difendeva una
       * cosa giusta a metà: inventare un'**attività** che non si è misurata
       * sarebbe dire a qualcuno che è stanco perché non lo stiamo guardando.
       *
       * 🚨 Ma portava via con sé anche la veglia, che con i sensori non c'entra
       * niente. 📌 Il committente: *«non posso avere la stessa carica se sto in
       * piedi da 18 ore o se sto in piedi da 3»*. E su un orologio che scrive le
       * calorie attive solo dentro un allenamento, quel `return 0` voleva dire
       * che **nei giorni senza palestra la batteria non scendeva mai**.
       *
       * 💡 Le due cose adesso sono separate: dell'attività non si inventa
       * niente, della veglia si sa tutto.
       */
      final senzaSensori = CaricaBatteria.scarica(
        calorieAttive: null,
        calorieAllenamento: null,
        riferimentoAllenamento: 630,
        riferimentoAttivita: 420,
        oreSveglio: 16,
      );

      // 💡 Sedici ore = la veglia di riferimento = i suoi punti pieni.
      expect(senzaSensori, closeTo(CaricaBatteria.scaricaDellaVeglia, 0.01));

      // ⛔ E appena sveglio non si è ancora consumato niente.
      expect(
        CaricaBatteria.scarica(
          calorieAttive: null,
          calorieAllenamento: null,
          riferimentoAllenamento: 630,
          riferimentoAttivita: 420,
          oreSveglio: 0,
        ),
        0,
      );
    });

    test('diciotto ore in piedi non sono come tre', () {
      /*
       * 📌 È **la frase del committente**, tradotta in numeri: *«non posso avere
       * la stessa carica o prontezza se sto in piedi da 18 ore o se sto in piedi
       * da 3»*.
       *
       * 🚨 Prima di oggi questi due erano **lo stesso numero**, e il numero era
       * zero.
       */
      double dopo(double ore) => CaricaBatteria.scarica(
            calorieAttive: null,
            calorieAllenamento: null,
            riferimentoAllenamento: 630,
            riferimentoAttivita: 420,
            oreSveglio: ore,
          );

      expect(dopo(18), greaterThan(dopo(3)));

      // 💡 1,25 punti all'ora: quindici ore di differenza fanno ~18,75 punti.
      expect(dopo(18) - dopo(3), closeTo(18.75, 0.01));
    });

    test('la veglia non può ricaricare', () {
      /*
       * ⚠️ Un orologio che scrive una notte finita «domani» — succede, con i
       * fusi e le sincronizzazioni tardive — darebbe ore negative. 🚨 Una
       * scarica negativa **aggiungerebbe** carica stando svegli, che è il verso
       * esattamente sbagliato.
       */
      expect(
        CaricaBatteria.scarica(
          calorieAttive: null,
          calorieAllenamento: null,
          riferimentoAllenamento: 630,
          riferimentoAttivita: 420,
          oreSveglio: -5,
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
        oreSveglio: 0,
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

  group('la giornata comincia al risveglio, non a mezzanotte', () {
    /*
     * ══ 📌 IL DIFETTO ═══════════════════════════════════════════════════
     *
     * 📌 Il committente, alle 00:50 del 31/08/2026: *«è mezzanotte e 50, non è
     * possibile che la carica mi dica che ho il 94% di carica... C'è qualcosa
     * che non torna nella formula»*.
     *
     * 🚨 **Non era una taratura: era il confine del giorno.** A mezzanotte si
     * accreditava il recupero di una notte non ancora avvenuta *e* la scarica
     * ripartiva da zero. Mezzo recupero regalato più tutto il consumo azzerato.
     *
     * 📌 La decisione: *«Ovviamente la giornata inizia al risveglio»*.
     */
    List<GiornataPerLaCarica> conNotte({required bool oggiHaDormito}) => [
          GiornataPerLaCarica(
            giorno: giorno(1),
            calorieAttive: 900,
            calorieAllenamento: 600,
            minutiDormiti: 480,
          ),
          GiornataPerLaCarica(
            giorno: giorno(2),
            calorieAttive: 15,
            minutiDormiti: oggiHaDormito ? 450 : null,
          ),
        ];

    test('alle 00:50, senza la notte di oggi, si sta ancora vivendo ieri', () {
      expect(
        CaricaBatteria.indiceDelGiornoInCorso(
          giorni: conNotte(oggiHaDormito: false),
          oraLocale: 0,
        ),
        0,
        reason:
            'A mezzanotte e cinquanta la giornata di oggi non è cominciata: '
            'nessuno si è svegliato.',
      );
    });

    test('con la notte di oggi registrata, la giornata è cominciata', () {
      expect(
        CaricaBatteria.indiceDelGiornoInCorso(
          giorni: conNotte(oggiHaDormito: true),
          oraLocale: 7,
        ),
        1,
      );
    });

    test('passata l\'ora limite si va avanti comunque', () {
      /*
       * ⛔ **Senza questa via d'uscita chi non registra il sonno resterebbe
       * incastrato per sempre nel giorno prima.** La notte che non compare a
       * mezzogiorno non vuol dire che sei ancora sveglio da ieri: vuol dire
       * che il sensore non l'ha vista.
       */
      expect(
        CaricaBatteria.indiceDelGiornoInCorso(
          giorni: conNotte(oggiHaDormito: false),
          oraLocale: CaricaBatteria.oraOltreLaQualeIlGiornoEComunqueCominciato,
        ),
        1,
      );
    });

    test('e non si torna mai indietro di più di un giorno', () {
      /*
       * 🚨 Due giorni senza notte non fanno quarantott'ore di veglia: fanno un
       * orologio spento. ⛔ Tornare indietro all'ultima notte vera direbbe che
       * quella persona è sveglia da due giorni, e le sommerebbe due giornate
       * di calorie in una scarica sola.
       */
      final giorni = [
        GiornataPerLaCarica(giorno: giorno(1), minutiDormiti: 480),
        GiornataPerLaCarica(giorno: giorno(2)),
        GiornataPerLaCarica(giorno: giorno(3)),
      ];

      expect(
        CaricaBatteria.indiceDelGiornoInCorso(giorni: giorni, oraLocale: 2),
        2,
      );
    });

    test('la mezzanotte non azzera la scarica', () {
      /*
       * 🎯 **È la seconda metà del difetto.** I quindici kcal dopo le 00:00
       * sono parte della stessa giornata sveglia, e si sommano a quelli di
       * ieri invece di aprire un conto nuovo.
       */
      final spese = CaricaBatteria.speseDalRisveglio(
        giorni: conNotte(oggiHaDormito: false),
        da: 0,
      );

      expect(spese.attive, 915);
      expect(spese.allenamento, 600);
    });

    test('senza nessuna caloria resta «non lo so», non zero', () {
      /*
       * ⛔ Uno zero direbbe «fermo». Chi ha lasciato l'orologio nel cassetto
       * non è fermo: non lo sappiamo, e `scarica()` non fa scendere niente.
       */
      final spese = CaricaBatteria.speseDalRisveglio(
        giorni: [
          GiornataPerLaCarica(giorno: giorno(1), minutiDormiti: 480),
          GiornataPerLaCarica(giorno: giorno(2)),
        ],
        da: 0,
      );

      expect(spese.attive, isNull);
      expect(spese.allenamento, isNull);
    });

    test('🚨 il caso vero: a mezzanotte la Carica NON risale', () {
      /*
       * 🎯 **La prova che chiude il difetto**, e mette insieme le due metà.
       *
       * Una giornata pesante, poi mezzanotte. ⛔ Prima: il mattino del giorno
       * nuovo veniva calcolato con `recuperoSenzaSonno` (0,55) e la scarica
       * ripartiva da zero — la batteria risaliva mentre la persona era ancora
       * sveglia.
       */
      final giorni = conNotte(oggiHaDormito: false);

      final catena = CaricaBatteria.catena(tdeeDiBase: 2100, giorni: giorni);

      final rif = CaricaBatteria.riferimenti(tdeeDiBase: 2100, giorniValidi: 1);

      final inCorso = CaricaBatteria.indiceDelGiornoInCorso(
        giorni: giorni,
        oraLocale: 0,
      );

      final spese =
          CaricaBatteria.speseDalRisveglio(giorni: giorni, da: inCorso);

      final adesso = CaricaBatteria.adesso(
        caricaDelMattino: catena[inCorso].mattina,
        scaricaFinora: CaricaBatteria.scarica(
          calorieAttive: spese.attive,
          calorieAllenamento: spese.allenamento,
          riferimentoAllenamento: rif.allenamento,
          riferimentoAttivita: rif.attivita,
        ),
      );

      // 💡 La sera di ieri era 59,1: dopo mezzanotte si scende ancora un po'.
      expect(adesso, lessThan(60));

      /*
       * ⛔ **E il numero sbagliato di prima non deve tornare.** Con il giorno
       * nuovo si sarebbe letto il mattino del secondo giorno — che è sopra 80 —
       * meno una scarica di quindici kcal, cioè quasi niente.
       */
      expect(
        adesso,
        lessThan(catena.last.mattina),
        reason:
            'Sta leggendo il mattino di un giorno che non è ancora cominciato: '
            'è il difetto delle 00:50.',
      );
    });
  });

  group('la catena, che è il motivo per cui la Carica esiste', () {
    test('l\'esempio completo della specifica, dal primo giorno', () {
      /*
       * ══ ⚠️ `oreSveglio: 0`, E VA SPIEGATO — 06/09/2026 ═══════════════════
       *
       * 🚨 **Questo e' l'ancora**: dice se l'implementazione e' quella
       * *chiesta*, non solo una che gira. I suoi numeri vengono dall'esempio
       * scritto nella specifica, che e' **anteriore** alla scarica da veglia.
       *
       * ⛔ Riscrivere i numeri attesi sarebbe stato il modo rapido e sbagliato:
       * l'ancora avrebbe smesso di ancorare a qualcosa, e la prossima volta che
       * la catena si rompe davvero nessuno lo saprebbe.
       *
       * 💡 Azzerando la veglia, l'esempio verifica ancora **esattamente** cio'
       * per cui e' stato scritto. Il comportamento nuovo ha il suo test, qui
       * sotto.
       */
      final c = CaricaBatteria.catena(
        tdeeDiBase: 2100,
        giorni: [
          GiornataPerLaCarica(
            giorno: giorno(1),
            calorieAttive: 900,
            calorieAllenamento: 600,
            minutiDormiti: 480,
            oreSveglio: 0,
          ),
          GiornataPerLaCarica(
            giorno: giorno(2),
            minutiDormiti: 450,
            oreSveglio: 0,
          ),
        ],
      );

      // 📌 Mattina 90, scarica 30.9, sera 59.1.
      expect(c.first.mattina, 90);
      expect(c.first.sera, closeTo(59.1, 0.1));

      // 📌 Recupero 0.666 su 40.9 mancanti ≈ 27.2 → 86.3.
      expect(c.last.mattina, closeTo(86.3, 0.2));
    });

    test('lo stesso giorno, con la veglia, costa di piu', () {
      /*
       * 💡 E' l'esempio della specifica con le sedici ore di veglia rimesse: la
       * scarica sale da 30,9 a 50,9, **contro il tetto di 50**.
       *
       * ⚠️ E dice una cosa da sorvegliare: una giornata con un allenamento vero
       * e una veglia normale **arriva al tetto**. 🚨 Quando il tetto si tocca, la
       * differenza fra un allenamento duro e uno durissimo sparisce — e' il
       * prezzo dichiarato di `scaricaMassimaAlGiorno`, e il giorno che desse
       * fastidio si alza quella, non si toglie la veglia.
       */
      final c = CaricaBatteria.catena(
        tdeeDiBase: 2100,
        giorni: [
          GiornataPerLaCarica(
            giorno: giorno(1),
            calorieAttive: 900,
            calorieAllenamento: 600,
            minutiDormiti: 480,
            oreSveglio: 16,
          ),
        ],
      );

      expect(c.first.mattina, 90);
      expect(
        c.first.sera,
        closeTo(90 - CaricaBatteria.scaricaMassimaAlGiorno, 0.1),
      );
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
          reason:
              'il giorno $i non ha trascinato la fatica del giorno ${i - 1}',
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

    test('un giorno senza orologio scarica solo la veglia, e recupera', () {
      /*
       * ⛔ Chi lascia l'orologio a casa non deve trovarsi addebitata
       * un'**attività** che non si è misurata: quella non si inventa.
       *
       * 🚨 Ma la giornata l'ha vissuta lo stesso, ed è cambiato il 06/09/2026:
       * prima `c.first.sera` era **esattamente 50**, cioè la batteria stava
       * ferma. Adesso scende dei punti della veglia — qui il valore di
       * riferimento, perché `oreSveglio` non è stato passato.
       */
      final c = CaricaBatteria.catena(
        tdeeDiBase: 2100,
        daCapo: 50,
        giorni: [
          GiornataPerLaCarica(giorno: giorno(1), minutiDormiti: 480),
          GiornataPerLaCarica(giorno: giorno(2), minutiDormiti: 480),
        ],
      );

      expect(
          c.first.sera, closeTo(50 - CaricaBatteria.scaricaDellaVeglia, 0.01));

      // 💡 E la notte recupera comunque: è il punto di tutta la catena.
      expect(c.last.mattina, greaterThan(c.first.sera));
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

    test('la fisiologia del giorno DOPO decide il recupero di questa notte',
        () {
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
