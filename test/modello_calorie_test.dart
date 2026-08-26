import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/diary/data/target_del_giorno.dart';
import 'package:training_companion/src/features/profile/data/calcolatore_calorie.dart';
import 'package:training_companion/src/features/profile/data/modello_calorie.dart';

/// I due modelli di calcolo del fabbisogno — 3b-G, 26/08/2026.
///
/// ══ 📌 DA DOVE NASCE ══════════════════════════════════════════════════════
///
/// *«Il tdee è il consumo ad attività praticamente 0 (1.2) … non ha nulla a che
/// vedere con gli allenamenti»* → *«noi non dobbiamo decidere se usare il PAL
/// occupazionale o i moltiplicatori normali. Lo chiediamo all'utente»*.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// ⛔ Il difetto che la 3b-G chiude non produceva **nessun errore**: il livello
/// di attività dichiarava gli allenamenti e l'app ci sommava sopra quelli
/// misurati. Un obiettivo più alto del dovuto, plausibile, che nessuno controlla
/// più. 💡 Qui si prova che non può più succedere.
void main() {
  group('🔑 le chiavi portano il modello', () {
    /// 🚨 **È la proprietà su cui poggia tutto il resto.** Se una chiave stesse
    /// in tutti e due i modelli, `modelloDelLivello` non potrebbe rispondere, e
    /// servirebbe un secondo campo «modalità» da tenere allineato a mano — cioè
    /// da sbagliare.
    test('nessuna chiave sta in tutti e due i modelli', () {
      final stima = ModelloCalorie.stima.livelli.map((l) => l.chiave).toSet();
      final misurata = ModelloCalorie.misurata.livelli
          .map((l) => l.chiave)
          .toSet();

      expect(stima.intersection(misurata), isEmpty);
    });

    test('e da una chiave si risale al modello', () {
      expect(modelloDelLivello('moderate'), ModelloCalorie.stima);
      expect(modelloDelLivello('desk'), ModelloCalorie.misurata);
    });

    /// ⛔ `null` non è un caso da riempire: vuol dire «non ha ancora scelto».
    test('e una chiave che non conosciamo non ne ha uno', () {
      expect(modelloDelLivello('pilates'), isNull);
      expect(modelloDelLivello(null), isNull);
    });
  });

  group('⚖️ i fattori', () {
    test('il modello misurato ha i quattro gradini decisi il 26/08', () {
      expect(CalcolatoreCalorie.fattoreDi('desk'), 1.25);
      expect(CalcolatoreCalorie.fattoreDi('standing'), 1.45);
      expect(CalcolatoreCalorie.fattoreDi('on_feet'), 1.65);
      expect(CalcolatoreCalorie.fattoreDi('labour'), 1.9);
    });

    /// 🚨 **Il pavimento è la cosa che è stata misurata**, e non va alzato senza
    /// rifare la misura. La proposta iniziale era 1,50 — la fascia FAO per la
    /// vita sedentaria — e i dati veri l'hanno esclusa: a 96,6 kg quel fattore
    /// vuole ~761 kcal di movimento al giorno, cioè circa 28.000 passi, e la
    /// persona su cui è stato misurato ne fa 2.492.
    test('e il gradino più basso è 1,25, non 1,50', () {
      expect(
        ModelloCalorie.misurata.livelli.first.fattore,
        1.25,
        reason:
            'chi lo alza deve prima rifare la misura, non citare una '
            'tabella di popolazione',
      );
    });

    test('il modello a stima usa i valori standard di Harris-Benedict', () {
      expect(CalcolatoreCalorie.fattoreDi('sedentary'), 1.2);
      expect(CalcolatoreCalorie.fattoreDi('light'), 1.375);
      expect(CalcolatoreCalorie.fattoreDi('moderate'), 1.55);
      expect(CalcolatoreCalorie.fattoreDi('active'), 1.725);
      expect(CalcolatoreCalorie.fattoreDi('very_active'), 1.9);
    });

    /// ⛔ Il difetto del 12/08: `very_active` non era una chiave del calcolatore
    /// (che lo chiama `athlete`) e ripiegava su 1,2 — **1.300 kcal in meno** a
    /// chi si allena ogni giorno, senza nessun errore.
    test('e i due nomi dello stesso gradino valgono uguale', () {
      expect(
        CalcolatoreCalorie.fattoreDi('very_active'),
        CalcolatoreCalorie.fattoreDi('athlete'),
      );
    });

    /// 🚨 **Ogni gradino deve avere il suo fattore**, o `LivelloAttivita.fattore`
    /// esplode al primo che apre la pagina: usa `fattoreDi(chiave)!`.
    test('ogni gradino di ogni modello ha un fattore', () {
      for (final m in ModelloCalorie.values) {
        for (final l in m.livelli) {
          expect(
            CalcolatoreCalorie.fattoreDi(l.chiave),
            isNotNull,
            reason: '${l.chiave} non ha un fattore',
          );
        }
      }
    });
  });

  group('⛔ niente ripieghi plausibili', () {
    /// ══ 🚨 IL TEST PIU' IMPORTANTE DELLA FASE ═══════════════════════════
    ///
    /// Il ripiego naturale sarebbe `?? 1.2`. ⛔ Darebbe a chiunque abbia una
    /// chiave sconosciuta un fabbisogno **più basso del vero**, plausibile, e
    /// senza nessun errore da nessuna parte — che è esattamente il tipo di
    /// numero che nessuno controlla più.
    test('un livello sconosciuto non ha un fattore', () {
      expect(CalcolatoreCalorie.fattoreDi('quello_di_prima'), isNull);
      expect(CalcolatoreCalorie.fattoreDi(null), isNull);
    });

    test('e non ha nemmeno un TDEE', () {
      const c = CalcolatoreCalorie();

      expect(c.tdeeSeNoto(1880, 'quello_di_prima'), isNull);
      expect(c.tdeeSeNoto(1880, null), isNull);
    });

    test('mentre un livello noto ce l\'ha', () {
      const c = CalcolatoreCalorie();

      expect(c.tdeeSeNoto(1880, 'desk'), closeTo(2350, 1));
    });
  });

  group('🏷️ le etichette', () {
    /// 🚨 **È l'unica cosa che impedisce di ridichiarare gli allenamenti.** Se
    /// un gradino del modello misurato dicesse «3-4 allenamenti a settimana»,
    /// la persona li conterebbe lì **e** l'orologio li conterebbe di nuovo.
    test('nel modello misurato nessuna nomina gli allenamenti', () {
      const vietate = ['allenament', 'palestra', 'sedut', 'sport'];

      for (final l in ModelloCalorie.misurata.livelli) {
        final testo = '${l.etichetta} ${l.dettaglio}'.toLowerCase();

        for (final parola in vietate) {
          expect(
            testo,
            isNot(contains(parola)),
            reason: '«${l.etichetta}» nomina «$parola»',
          );
        }
      }
    });

    test('e nel modello a stima invece li nominano, perché li contengono', () {
      final testo = ModelloCalorie.stima.livelli
          .map((l) => l.dettaglio.toLowerCase())
          .join(' ');

      expect(testo, contains('allenament'));
    });

    /// 📌 *«dovrà essere accuratamente dettagliato anche con la formula usata»*.
    test('e tutti e due i modelli dicono la loro formula', () {
      for (final m in ModelloCalorie.values) {
        expect(m.formula, contains('metabolismo basale'));
        expect(m.formula, contains('fattore'));
      }

      // ⚠️ La differenza fra i due modelli È questo addendo: se sparisce dalla
      // formula scritta, la pagina spiega una cosa e l'app ne fa un'altra.
      expect(ModelloCalorie.misurata.formula, contains('allenamenti'));
      expect(ModelloCalorie.stima.formula, isNot(contains('allenamenti')));
    });
  });

  group('🔥 la somma degli allenamenti è una conseguenza', () {
    test('si sommano solo nel modello misurato', () {
      expect(ModelloCalorie.misurata.sommaGliAllenamenti, isTrue);
      expect(ModelloCalorie.stima.sommaGliAllenamenti, isFalse);
    });
  });

  group('👣 il gradino suggerito dai passi', () {
    /// 💡 2.492 passi al giorno: la misura vera di agosto 2026, quella da cui
    /// sono usciti i fattori.
    test('2.492 passi al giorno sono «scrivania»', () {
      expect(livelloSuggeritoDaiPassi(2492)?.chiave, 'desk');
    });

    test('e la scala sale come ci si aspetta', () {
      expect(livelloSuggeritoDaiPassi(6000)?.chiave, 'standing');
      expect(livelloSuggeritoDaiPassi(10000)?.chiave, 'on_feet');
      expect(livelloSuggeritoDaiPassi(20000)?.chiave, 'labour');
    });

    /// ⛔ Zero passi non vuol dire «sta fermo»: vuol dire che non lo sappiamo —
    /// l'orologio scarico, il permesso mai dato, il telefono sul comodino.
    /// 🚨 Suggerire il gradino più basso lì sarebbe inventare, su una dieta.
    test('e senza passi non si suggerisce niente', () {
      expect(livelloSuggeritoDaiPassi(0), isNull);
      expect(livelloSuggeritoDaiPassi(-1), isNull);
    });
  });

  group('📉 come si applica il deficit — 3b-G.5', () {
    /*
     * ══ 🚨 QUESTO TEST DIFENDE UNA DECISIONE, NON UN CALCOLO ═══════════════
     *
     * 📌 Il committente, 26/08/2026: *«TDEE x 0.8 + allenamento. Il deficit non
     * deve essere complessivo, ma basato sul TDEE e basta, l'allenamento è un
     * deficit ADDIZIONALE al massimo. Dividere anche l'allenamento per il
     * fattore di attività non ha logicamente senso e potrebbe far mangiare
     * TROPPO POCO gli utenti»*.
     *
     * ⚠️ L'alternativa — `(TDEE + allenamento) × 0,8` — sembra più pulita, e
     * qualcuno prima o poi proverà a «correggere» la formula in quel verso: il
     * taglio resterebbe il 20% anche nei giorni di palestra. ⛔ Ma dà **meno
     * cibo**: 2.240 invece di 2.380 nell'esempio qui sotto, cioè fa pagare due
     * volte lo stesso sforzo.
     *
     * 💡 Il test esiste perché la scelta sia leggibile fra sei mesi. Oggi l'app
     * faceva già così, ma **per inerzia**: nessuno l'aveva decisa.
     */
    test('il taglio è sul TDEE, e l\'allenamento si somma per intero', () {
      const c = CalcolatoreCalorie();

      final tdee = c.tdeeSeNoto(1750, 'standing')!; // 1750 × 1,45 ≈ 2537,5
      final base = c.targetCalorico(tdee, 'lose_fast'); // −20%

      final conAllenamento = TargetDelGiorno.scegli(
        dalServer: null,
        locale: base.toDouble(),
        bruciate: 700,
        sommaLeBruciate: true,
      );

      expect(base, closeTo(2030, 1));
      expect(conAllenamento.kcal, closeTo(2730, 1));

      // ⛔ La strada scartata: `(2537,5 + 700) × 0,8` = 2590. Meno cibo, e il
      // committente ha detto esplicitamente perché non la vuole.
      expect(
        conAllenamento.kcal,
        greaterThan(2590),
        reason:
            'moltiplicare anche l\'allenamento per 0,8 farebbe mangiare '
            'meno di quanto è stato deciso',
      );
    });
  });

  group('⚖️ Dart e PHP non devono divergere — 3b-G.6.4', () {
    /*
     * 🚨 La tabella del modello «stima» vive in DUE posti: qui e in
     * `CalorieCalculator::ACTIVITY`, che sul server continua a calcolare i
     * **modelli** del pannello del trainer.
     *
     * ⚠️ Fino a oggi c'era solo un commento — *«chi cambia un numero di là deve
     * cambiarlo qui»* — e un commento non ha mai fermato nessuno. Adesso è un
     * test.
     *
     * ⛔ I quattro fattori del modello **misurato** NON stanno sul server, ed è
     * voluto: il livello di attività è un dato del telefono (3b-G.1). Una
     * seconda copia inerte sarebbe una trappola — qualcuno la troverebbe e
     * «allineerebbe» l'app a lei.
     */
    test('i fattori del modello a stima sono gli stessi', () {
      final php = File(
        '../trainingbe/app/Services/Nutrition/CalorieCalculator.php',
      );

      if (!php.existsSync()) {
        markTestSkipped(
          'trainingbe non è accanto a questo repo: la guardia sui due '
          'vocabolari non ha potuto girare',
        );

        return;
      }

      final blocco = RegExp(
        r'const ACTIVITY = \[(.*?)\];',
        dotAll: true,
      ).firstMatch(php.readAsStringSync());

      expect(blocco, isNotNull, reason: 'ACTIVITY non trovata nel PHP');

      final daPhp = <String, double>{};

      for (final m in RegExp(
        r"'(\w+)'\s*=>\s*([\d.]+)",
      ).allMatches(blocco!.group(1)!)) {
        daPhp[m.group(1)!] = double.parse(m.group(2)!);
      }

      for (final voce in daPhp.entries) {
        expect(
          CalcolatoreCalorie.fattoreDi(voce.key),
          voce.value,
          reason: '${voce.key} vale ${voce.value} sul server',
        );
      }
    });
  });
}
