import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/nutrition/data/piano_alimentare.dart';

/// Il compositore dei piani alimentari — G7 (D2, D13, D14).
///
/// 🚨 **Cosa prova questa classe.** Non che i campi si copino: prova le tre cose
/// che, sbagliate, **non danno errore** — un piano più lungo di quello scritto,
/// un totale gonfiato, e una stima AI che azzera quello che il trainer aveva
/// già messo a mano.
void main() {
  group('la forma che il server accetta', () {
    test('le alternative escono dentro il loro alimento, non accanto', () {
      final pollo = AlimentoDelPiano(descrizione: '120 g di pollo', kcal: 198);
      pollo.alternative.add(AlimentoDelPiano(descrizione: '150 g di merluzzo', kcal: 123));

      final json = pollo.toJson();

      expect(json['description'], '120 g di pollo');
      expect((json['alternatives'] as List).length, 1);
      final prima = (json['alternatives'] as List).first as Map<String, dynamic>;

      expect(prima['kcal'], 123);
    });

    test('un alimento vuoto non viene mandato', () {
      final pasto = PastoDelPiano(
        alimenti: [
          AlimentoDelPiano(descrizione: 'Riso', kcal: 280),
          // 🚨 L'editor tiene volentieri una riga vuota in fondo, pronta da
          // compilare: mandarla farebbe fallire la validazione del server su
          // `description.required` — cioè un errore su una riga che nessuno
          // voleva scrivere.
          AlimentoDelPiano(),
        ],
      );

      expect((pasto.toJson()['items'] as List).length, 1);
    });

    test('i campi non valorizzati non escono affatto', () {
      final json = AlimentoDelPiano(descrizione: 'Mela').toJson();

      /*
       * ⚠️ `null` e «assente» sono cose diverse verso il server: mandare
       * `'kcal': null` è dire «azzera», non mandarlo è dire «non lo so». Su un
       * aggiornamento la differenza cancella dei dati.
       */
      expect(json.containsKey('kcal'), isFalse);
      expect(json.containsKey('grams'), isFalse);
    });
  });

  group('i totali', () {
    test('un pasto non conta le proprie alternative', () {
      final pollo = AlimentoDelPiano(descrizione: 'Pollo', kcal: 198);
      pollo.alternative.add(AlimentoDelPiano(descrizione: 'Merluzzo', kcal: 123));

      final pasto = PastoDelPiano(alimenti: [pollo]);

      // 🚨 198, non 321. Contarle gonfierebbe ogni pasto: un pranzo con due
      // alternative varrebbe tre pranzi.
      expect(pasto.kcal, 198);
    });

    test('il piano è la MEDIA dei giorni, non la somma', () {
      final piano = PianoAlimentare(
        giorni: [
          GiornoDelPiano(pasti: [
            PastoDelPiano(alimenti: [AlimentoDelPiano(descrizione: 'a', kcal: 200)]),
          ]),
          GiornoDelPiano(pasti: [
            PastoDelPiano(alimenti: [AlimentoDelPiano(descrizione: 'b', kcal: 400)]),
          ]),
        ],
      );

      /*
       * ⚠️ 300, non 600. La somma di due giorni non vuol dire niente per chi
       * legge: nessuno mangia due giorni in una volta.
       *
       * 💡 Con **un** giorno i due modi danno lo stesso numero — ed è il caso
       * più comune, cioè quello in cui la differenza passa inosservata.
       */
      expect(piano.kcalMedie, 300);
    });

    test('un piano senza giorni non divide per zero', () {
      expect(PianoAlimentare().kcalMedie, 0);
    });
  });

  group('la stima AI', () {
    test('non azzera quello che il trainer aveva già scritto', () {
      final mio = AlimentoDelPiano(descrizione: 'Pollo', kcal: 200, proteine: 37);

      // La stima torna senza proteine.
      mio.adottaStima(AlimentoDelPiano(descrizione: '120 g di petto di pollo', kcal: 198));

      expect(mio.descrizione, '120 g di petto di pollo');
      expect(mio.kcal, 198);

      /*
       * 🚨 **Le proteine restano.** Una stima che torna senza un macro non deve
       * azzerarlo: è lo stesso principio delle alternative lato server, e lo
       * stesso errore che si farebbe assegnando alla cieca — con la differenza
       * che qui il dato perso l'aveva scritto una persona.
       */
      expect(mio.proteine, 37);
    });

    test('adottare una stima marca i valori come proposti dall\'AI', () {
      final a = AlimentoDelPiano(descrizione: 'x');

      expect(a.dallAi, isFalse);

      a.adottaStima(AlimentoDelPiano(descrizione: 'Pollo', kcal: 198));

      // 💡 Serve al trainer per vedere a colpo d'occhio cosa non ha ancora
      // controllato. Toccare un campo lo riporta a «a mano».
      expect(a.dallAi, isTrue);
    });
  });

  group('il Rif. Allievo', () {
    test('assente non vuol dire vuoto', () {
      /*
       * 🚨 R4 — la chiave **manca del tutto** se chi guarda non è chi l'ha
       * scritto. `null` qui vuol dire «non è mio», non «non l'ha compilato»: se
       * l'app lo trattasse come vuoto, un salvataggio lo **cancellerebbe** al
       * legittimo proprietario.
       */
      final altrui = PianoAlimentare.fromJson({'id': 1, 'name': 'Piano'});

      expect(altrui.rifAllievo, isNull);
      expect(altrui.toJson().containsKey('rif_allievo'), isFalse);
    });

    test('valorizzato viaggia', () {
      final mio = PianoAlimentare.fromJson({
        'id': 1,
        'name': 'Piano',
        'rif_allievo': 'M.R. spalla dx',
      });

      expect(mio.toJson()['rif_allievo'], 'M.R. spalla dx');
    });
  });

  test('l\'albero completo torna dal server e ci ritorna uguale', () {
    final piano = PianoAlimentare.fromJson({
      'id': 7,
      'origine_id': '01JXYZ',
      'name': 'Definizione',
      'days': [
        {
          'name': 'Giorno 1',
          'meals': [
            {
              'meal': 'lunch',
              'items': [
                {
                  'description': 'Pollo',
                  'kcal': 198,
                  'alternatives': [
                    {'description': 'Merluzzo', 'kcal': 123},
                  ],
                },
              ],
              'alternatives': [
                {
                  'meal': 'lunch',
                  'items': [
                    {'description': 'Salmone', 'kcal': 400},
                  ],
                },
              ],
            },
          ],
          'alternatives': [
            {'name': 'Giorno 1-bis', 'meals': []},
          ],
        },
      ],
    });

    expect(piano.origineId, '01JXYZ');
    expect(piano.giorni.length, 1);
    expect(piano.giorni.first.alternative.length, 1);
    expect(piano.giorni.first.pasti.first.alternative.length, 1);
    expect(piano.giorni.first.pasti.first.alimenti.first.alternative.length, 1);

    // ⚠️ E il totale del giorno conta **solo** il pasto principale: 198.
    expect(piano.giorni.first.kcal, 198);

    final json = piano.toJson();

    expect((json['days'] as List).length, 1);
    final primoGiorno = (json['days'] as List).first as Map<String, dynamic>;

    expect((primoGiorno['alternatives'] as List).length, 1);
  });
}
