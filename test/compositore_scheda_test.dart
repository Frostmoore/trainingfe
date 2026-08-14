import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/scheda_allenamento.dart';

/// I modelli del compositore delle schede — G7.1.
///
/// 🚨 **Il round-trip è la cosa che questi test difendono.** Il compositore
/// legge una scheda, la modifica e la rimanda: se qualcosa si perde nel giro,
/// salvare **cancella** invece di aggiornare. È il difetto peggiore possibile
/// qui, perché somiglia a «ha funzionato».
void main() {
  group('l\'esercizio', () {
    test('le ripetizioni restano una stringa, sempre', () {
      final e = EsercizioDellaScheda(nome: 'Curl', ripetizioni: 'cedimento');

      /*
       * 🚨 «8-12», «cedimento», «max», «10+10» sono prescrizioni legittime e
       * frequentissime. ⚠️ Chi le converte in intero credendo di correggere una
       * svista rompe metà delle schede vere — e la stessa nota sta in
       * `WorkoutPlanRequest` e nel prompt di importazione dai PDF.
       */
      expect(e.toJson()['reps'], 'cedimento');
      expect(e.toJson()['reps'], isA<String>());
    });

    test('un esercizio senza nome è vuoto e non parte', () {
      final giorno = GiornoDellaScheda(
        esercizi: [
          EsercizioDellaScheda(nome: 'Panca'),
          EsercizioDellaScheda(),
        ],
      );

      // 💡 L'editor tiene volentieri una riga vuota pronta da compilare, e il
      // server la rifiuterebbe: `name` è `required`.
      expect(giorno.quantiEsercizi, 1);
      expect((giorno.toJson()['exercises'] as List).length, 1);
    });

    test('i campi vuoti non finiscono nel JSON', () {
      final json = EsercizioDellaScheda(nome: 'Squat').toJson();

      // ⚠️ `if (x != null)` e non `'sets': null`: mandare le chiavi a null
      // vorrebbe dire chiedere al server di **azzerare** quei campi.
      expect(json.containsKey('sets'), isFalse);
      expect(json.containsKey('notes'), isFalse);
      expect(json['name'], 'Squat');
    });

    test('la prescrizione si legge mentre si scrive', () {
      final e = EsercizioDellaScheda(nome: 'Panca', serie: 4, ripetizioni: '8-12');

      // 💡 Calcolata nell'app: il server non ha ancora visto niente, e una riga
      // che resta muta finché non si salva non aiuta a scrivere.
      expect(e.prescrizione, '4 × 8-12');
      expect(EsercizioDellaScheda(nome: 'Plank', serie: 3).prescrizione, '3');
    });
  });

  group('le alternative', () {
    test('sono la stessa classe, quindi hanno serie e ripetizioni', () {
      final e = EsercizioDellaScheda(
        nome: 'Panca piana',
        alternative: [EsercizioDellaScheda(nome: 'Panca manubri', serie: 4, ripetizioni: '10')],
      );

      final alt = (e.toJson()['alternatives'] as List).first as Map<String, dynamic>;

      /*
       * 🚨 Chi sceglie l'alternativa deve trovarci cosa fare. Se fossero due
       * classi diverse, la prima a perdere un campo sarebbe l'alternativa —
       * cioè quella che nessuno prova.
       */
      expect(alt['name'], 'Panca manubri');
      expect(alt['sets'], 4);
      expect(alt['reps'], '10');
    });

    test('non contano fra gli esercizi da fare', () {
      final giorno = GiornoDellaScheda(
        esercizi: [
          EsercizioDellaScheda(
            nome: 'Panca',
            alternative: [EsercizioDellaScheda(nome: 'Manubri')],
          ),
        ],
      );

      // ⚠️ Un giorno con un esercizio e una sua alternativa è un giorno da **un**
      // esercizio: contarle direbbe «2» a chi ne fa uno.
      expect(giorno.quantiEsercizi, 1);
    });

    test('la chiave sparisce se sono tutte vuote', () {
      final e = EsercizioDellaScheda(
        nome: 'Panca',
        alternative: [EsercizioDellaScheda()],
      );

      expect(e.toJson().containsKey('alternatives'), isFalse);
    });
  });

  group('il round-trip', () {
    /// La forma che `WorkoutPlanController::dettaglio()` produce da G7.
    Map<String, dynamic> dalServer() => {
      'id': 7,
      'origine_id': '01JXYZ',
      'name': 'Split',
      'rif_allievo': 'M.R. spalla dx',
      'days': [
        {
          'id': 1,
          'name': 'Giorno A',
          'exercises': [
            {
              'id': 10,
              'name': 'Panca piana',
              'exercise': {'id': 3, 'name': 'Panca piana'},
              'sets': 4,
              'reps': '8-10',
              'notes': 'fermo un secondo al petto',
              'alternatives': [
                {'id': 11, 'name': 'Panca manubri', 'sets': 4, 'reps': '10', 'alternatives': []},
              ],
            },
          ],
          'alternatives': [],
        },
        {
          'id': 2,
          'name': 'Giorno B',
          'exercises': [
            {'id': 12, 'name': 'Trazioni', 'sets': 4, 'alternatives': []},
          ],
          'alternatives': [],
        },
      ],
    };

    test('quello che si legge si può rimandare identico', () {
      final scheda = SchedaAllenamento.fromJson(dalServer());

      expect(scheda.giorni.length, 2);
      expect(scheda.quantiEsercizi, 2);

      final json = scheda.toJson();
      final giorni = json['days'] as List;

      expect(giorni.length, 2);

      final primo = giorni.first as Map<String, dynamic>;
      final esercizio = (primo['exercises'] as List).first as Map<String, dynamic>;

      expect(primo['name'], 'Giorno A');
      expect(esercizio['name'], 'Panca piana');
      expect(esercizio['notes'], 'fermo un secondo al petto');
      expect((esercizio['alternatives'] as List).length, 1);

      // 🚨 **Il secondo giorno c'è ancora.** È esattamente quello che si
      // perdeva prima di G7, quando l'API tornava solo la lista piatta:
      // riaprire e salvare avrebbe cancellato tutti i giorni tranne uno.
      expect((giorni.last as Map<String, dynamic>)['name'], 'Giorno B');
    });

    test('il nome dell esercizio si legge anche solo da exercise.name', () {
      // ⚠️ La forma vecchia non aveva `name` in cima. Senza il ripiego, una
      // scheda scritta prima di G7 si riaprirebbe con gli esercizi senza nome —
      // cioè vuoti, cioè da buttare al salvataggio.
      final e = EsercizioDellaScheda.fromJson({
        'exercise': {'id': 3, 'name': 'Panca piana'},
      });

      expect(e.nome, 'Panca piana');
      expect(e.vuoto, isFalse);
    });

    test('una scheda senza giorni ricade sulla lista piatta', () {
      final scheda = SchedaAllenamento.fromJson({
        'id': 4,
        'name': 'Alla vecchia maniera',
        'exercises': [
          {'name': 'Squat', 'sets': 5, 'reps': '5'},
        ],
      });

      /*
       * 🚨 Una scheda scritta prima di G4 non ha `days`. Senza questo ripiego il
       * compositore la mostrerebbe **vuota**, e il primo salvataggio la
       * cancellerebbe.
       */
      expect(scheda.giorni.length, 1);
      expect(scheda.giorni.first.esercizi.first.nome, 'Squat');

      // 💡 E il giorno inventato non prende un nome: inventarne uno scriverebbe
      // nella scheda del trainer una parola che lui non ha mai scritto.
      expect(scheda.giorni.first.nome, isNull);
    });

    test('una scheda davvero vuota resta senza giorni', () {
      final scheda = SchedaAllenamento.fromJson({'id': 5, 'name': 'Vuota'});

      expect(scheda.giorni, isEmpty);
      expect(scheda.quantiEsercizi, 0);
    });
  });

  group('il Rif. Allievo', () {
    test('la chiave assente vuol dire «non è mia», non «vuoto»', () {
      final altrui = SchedaAllenamento.fromJson({'id': 9, 'name': 'Di un collega'});

      // 🚨 R4 — il server **toglie la chiave** a chi non l'ha scritta. `null`
      // qui non è un campo non compilato: è un campo che non ci compete.
      expect(altrui.rifAllievo, isNull);
    });

    test('parte nel salvataggio, perché lì serve', () {
      final mia = SchedaAllenamento(nome: 'X', rifAllievo: 'M.R.');

      // ⚠️ Nel **salvataggio** ci va: è il trainer che scrive il proprio
      // promemoria. Quello che non deve partire è la busta per l'allievo, e
      // quello spoglio si fa altrove — vedi `rif_allievo_non_parte_test.dart`.
      expect(mia.toJson()['rif_allievo'], 'M.R.');
    });
  });
}
