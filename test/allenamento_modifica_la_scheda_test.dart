import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/allenamento_in_corso.dart';
import 'package:training_companion/src/features/training/data/scheda_in_scrittura.dart';
import 'package:training_companion/src/features/training/data/serie_prevista.dart';
import 'package:training_companion/src/features/training/data/session_models.dart';

/// L'allenamento che modifica la scheda — 3b-E, 25/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// 📌 *«ricordati che TUTTE LE MODIFICHE fatte durante l'allenamento devono
/// modificare la scheda»* · *«Tutto deve funzionare bene (adesso funziona bene,
/// quindi fai in modo che non si rompa)»*.
///
/// ⚠️ **La seconda frase è la specifica vera.** Riscrivere il player vuol dire
/// toccare la sola schermata che era già usata in palestra, e i modi di
/// romperla sono tutti silenziosi: una spunta che non torna, un muscolo che
/// sparisce dalla scheda, un giorno che si sovrascrive con un altro. Nessuno di
/// questi dà un errore.
void main() {
  /// Una scheda nel formato **vecchio**: quattro serie riassunte in due campi.
  ///
  /// 🚨 È il caso che conta di più: le schede che il committente ha già in
  /// tasca sono tutte così, e quelle del trainer continuano ad arrivare così.
  Map<String, dynamic> schedaVecchia() => {
    'name': 'Full body A',
    'notes': 'la scheda di agosto',
    'image_url': 'https://example.test/copertina.png',
    'exercises': [
      {
        'name': 'Panca piana',
        'exercise_id': 12,
        'muscle_group': 'chest',
        'secondary_muscles': ['triceps'],
        'immagine': 'foto/esercizi/panca.jpg',
        'notes': 'gomiti stretti',
        'sets': 4,
        'reps': '12',
        'rest_sec': 90,
        'target_weight': 40,
      },
      {
        'name': 'Plank',
        'carico': 'iso',
        'sets': 2,
        'reps': '30',
        'rest_sec': 60,
      },
    ],
  };

  LoggedSet fatta({
    required String nome,
    required int numero,
    int? reps,
    double? peso,
    int? recupero,
    int esercizioId = 12,
  }) => LoggedSet(
    id: numero,
    exerciseId: esercizioId,
    exerciseName: nome,
    setNumber: numero,
    reps: reps,
    weight: peso,
    restSec: recupero,
  );

  group('📖 la scheda si apre già in righe', () {
    test('una scheda vecchia si espande, e i campi sono compilati', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: const [],
      );

      expect(esercizi, hasLength(2));

      final panca = esercizi.first;

      expect(panca.nome.text, 'Panca piana');
      expect(panca.righe, hasLength(4), reason: '«sets: 4» sono quattro righe');
      expect(panca.righe.first.ripetizioni.text, '12');
      expect(
        panca.righe.first.carico.text,
        '40',
        reason: '⚠️ «40» e non «40.0»: il campo lo legge una persona',
      );
      expect(panca.righe.first.recupero.text, '90');
    });

    /// 🚨 È il difetto di D.17, nella sua forma peggiore: si legge tutto giusto
    /// e si **riscrive** senza metà dei campi. Nessun errore, e la figura si
    /// spegne giorni dopo.
    test('e niente si perde riscrivendola: muscoli, foto, note, carico', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: const [],
      );

      final rifatta = schedaConGliEsercizi(schedaVecchia(), [
        for (final e in esercizi) e.versoIlDato(),
      ]);

      final panca = (rifatta['exercises'] as List).first as Map;

      expect(panca['muscle_group'], 'chest');
      expect(panca['secondary_muscles'], ['triceps']);
      expect(panca['immagine'], 'foto/esercizi/panca.jpg');
      expect(panca['notes'], 'gomiti stretti');
      expect(panca['exercise_id'], 12);

      final plank = (rifatta['exercises'] as List)[1] as Map;

      expect(
        plank['carico'],
        'iso',
        reason: 'l\'isometria non deve tornare un peso',
      );
    });

    /// ⚠️ Le chiavi che il player non conosce **non si toccano**: è la lezione
    /// del 24/08, quando ricostruire la scheda da capo fece sparire due
    /// esercizi.
    test('e le chiavi che il player non conosce restano dov\'erano', () {
      final rifatta = schedaConGliEsercizi(schedaVecchia(), const []);

      expect(rifatta['notes'], 'la scheda di agosto');
      expect(rifatta['image_url'], 'https://example.test/copertina.png');
      expect(rifatta['name'], 'Full body A');
    });
  });

  group('✅ riaprendo una seduta interrotta', () {
    test('le serie già fatte tornano spuntate', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: [
          fatta(nome: 'Panca piana', numero: 1, reps: 12, peso: 40),
          fatta(nome: 'Panca piana', numero: 2, reps: 10, peso: 45),
        ],
      );

      final panca = esercizi.first;

      expect(panca.serieFatte[0].fatta, isTrue);
      expect(panca.serieFatte[1].fatta, isTrue);
      expect(panca.serieFatte[2].fatta, isFalse);
      expect(panca.quanteFatte, 2);
      expect(panca.tuttoFatto, isFalse);
    });

    /// 💡 Quello che è stato **fatto** vince su quello che era prescritto: la
    /// riga mostra il peso vero, non quello scritto prima di alzarlo.
    test('e mostrano i numeri veri, non quelli prescritti', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: [fatta(nome: 'Panca piana', numero: 2, reps: 8, peso: 47.5)],
      );

      final riga = esercizi.first.serieFatte[1];

      expect(riga.ripetizioni.text, '8');
      expect(riga.carico.text, '47.5');
    });

    /// ⚠️ Chi ne fa cinque quando la scheda ne diceva quattro non deve
    /// ritrovarsi la quinta sparita: era registrata, esiste.
    test('una serie oltre le previste si aggiunge come riga', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: [fatta(nome: 'Panca piana', numero: 6, reps: 6, peso: 50)],
      );

      expect(esercizi.first.righe, hasLength(6));
      expect(esercizi.first.serieFatte[5].fatta, isTrue);
      expect(esercizi.first.serieFatte[4].fatta, isFalse);
    });

    test('un esercizio fatto fuori scheda compare in fondo', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: [
          fatta(nome: 'Pulley', numero: 1, reps: 10, peso: 55, esercizioId: 99),
        ],
      );

      expect(esercizi, hasLength(3));
      expect(esercizi.last.nome.text, 'Pulley');
      expect(esercizi.last.exerciseId, 99);
      expect(
        esercizi.last.righe,
        hasLength(1),
        reason: 'niente prescrizione da cui partire: una riga, quella fatta',
      );
    });

    /// 🚨 Gli id delle serie salvate senza rete sono **negativi** di proposito
    /// (B.16.10): presi per buoni, l'esercizio risulterebbe già in catalogo e
    /// la prima serie si prenderebbe un 422 per i muscoli mancanti.
    test('un id provvisorio non passa per un id di catalogo', () {
      final esercizi = eserciziDellAllenamento(
        scheda: const {},
        fatte: [
          fatta(nome: 'Rematore', numero: 1, esercizioId: -4211, reps: 10),
        ],
      );

      expect(esercizi.single.exerciseId, isNull);
    });
  });

  group('➕ le righe nuove sono del tipo giusto', () {
    /// ⛔ Il difetto si vedrebbe **solo premendo «Aggiungi serie»**, cioè nel
    /// caso che si prova meno: una serie che non si può spuntare, a metà
    /// allenamento.
    test('rigaNuova() dà una riga che si può spuntare', () {
      final e = EsercizioInAllenamento(nome: 'Squat');
      final nuova = e.rigaNuova();

      expect(nuova, isA<SerieInAllenamento>());
    });

    test('e la lista regge il cast anche dopo averne aggiunta una', () {
      final e = EsercizioInAllenamento(nome: 'Squat');

      e.righe.add(e.rigaNuova());

      expect(e.serieFatte, hasLength(EsercizioInScrittura.seriePredefinite + 1));
    });

    test('un esercizio nuovo nasce con tre serie, come nell\'editor', () {
      expect(
        EsercizioInAllenamento().righe,
        hasLength(EsercizioInScrittura.seriePredefinite),
      );
    });
  });

  group('📅 le schede a più giorni', () {
    Map<String, dynamic> multi() => {
      'name': 'Split',
      'exercises': [
        {'name': 'Panca', 'serie': <dynamic>[]},
      ],
      'days': [
        {
          'exercises': [
            {'name': 'Panca', 'serie': <dynamic>[]},
          ],
        },
        {
          'exercises': [
            {'name': 'Squat', 'serie': <dynamic>[]},
          ],
        },
      ],
    };

    /// 🚨 Gli esercizi del giorno 1 stanno **in due posti**: `exercises` (per
    /// le versioni dell'app che i giorni non li conoscono) e `days[0]`.
    /// ⛔ Scriverne uno solo vuol dire una scheda che dice due cose diverse a
    /// seconda di chi la legge, e il difetto comparirebbe giorni dopo.
    test('il giorno 1 si scrive in tutti e due i posti', () {
      final rifatta = schedaConGliEsercizi(multi(), [
        {'name': 'Panca inclinata'},
      ]);

      expect(
        ((rifatta['days'] as List).first as Map)['exercises'],
        [
          {'name': 'Panca inclinata'},
        ],
      );
      expect(rifatta['exercises'], [
        {'name': 'Panca inclinata'},
      ]);
    });

    test('e gli altri giorni non si toccano', () {
      final rifatta = schedaConGliEsercizi(multi(), const []);
      final secondo = (rifatta['days'] as List)[1] as Map;

      expect((secondo['exercises'] as List).single, {
        'name': 'Squat',
        'serie': <dynamic>[],
      });
    });

    /// ⚠️ La scheda di partenza non si modifica: il chiamante tiene la sua
    /// copia, e mutargliela sotto sarebbe il modo più rapido per far divergere
    /// quello che è a schermo da quello che è su disco.
    test('e la scheda di partenza resta com\'era', () {
      final originale = multi();

      schedaConGliEsercizi(originale, const []);

      expect((originale['exercises'] as List), hasLength(1));
      expect(
        ((originale['days'] as List).first as Map)['exercises'],
        hasLength(1),
      );
    });
  });

  group('🔁 il giro completo', () {
    /// ══ 🚨 È LA FORMA DI TEST CHE HA PRESO D.17 ═══════════════════════════
    ///
    /// ⛔ Provare la lettura e la scrittura **separatamente** non basta:
    /// guardate da sole erano tutte e due giuste, e la scheda salvata era
    /// comunque illeggibile. Qui si scrive come scrive l'allenamento e si
    /// rilegge come rilegge l'allenamento.
    test('cambiare un peso in palestra lo lascia scritto nella scheda', () {
      final primaVolta = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: const [],
      );

      // In sala si scarica: 40 diventano 35 sulla prima serie.
      primaVolta.first.righe.first.carico.text = '35';

      final rifatta = schedaConGliEsercizi(schedaVecchia(), [
        for (final e in primaVolta) e.versoIlDato(),
      ]);

      final domani = eserciziDellAllenamento(scheda: rifatta, fatte: const []);

      expect(domani.first.righe.first.carico.text, '35');
      expect(
        domani.first.righe[1].carico.text,
        '40',
        reason: 'solo la prima serie è stata toccata',
      );
      expect(
        domani.first.righe,
        hasLength(4),
        reason: 'le quattro serie restano quattro',
      );
    });

    /// ⚠️ Il riassunto del formato vecchio va tenuto d'accordo, o una versione
    /// precedente dell'app — o un backup ripristinato — leggerebbe i numeri di
    /// ieri.
    test('e il riassunto del formato vecchio segue', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: const [],
      );

      esercizi.first.righe.first.carico.text = '35';

      final panca = esercizi.first.versoIlDato();

      expect(panca['target_weight'], 35);
      expect(panca['sets'], 4);
    });

    test('togliere una serie la toglie dalla scheda', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: const [],
      );

      esercizi.first.righe.removeAt(3).dispose();

      final panca = esercizi.first.versoIlDato();

      expect((panca['serie'] as List), hasLength(3));
      expect(panca['sets'], 3);
    });

    test('un esercizio senza nome non finisce nella scheda', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: const [],
      )..add(EsercizioInAllenamento());

      final rifatta = schedaConGliEsercizi(schedaVecchia(), [
        for (final e in esercizi)
          if (e.nome.text.trim().isNotEmpty) e.versoIlDato(),
      ]);

      expect((rifatta['exercises'] as List), hasLength(2));
    });
  });

  group('🏷️ il carico', () {
    /// 🚨 Con `Iso.` in quella colonna ci sono i **secondi**, non i chili: un
    /// peso registrato lì sarebbe un dato sbagliato che sembra dichiarato.
    ///
    /// ⚠️ E il peso in archivio ci può essere davvero: la stessa riga può
    /// essere stata registrata quando l'esercizio era ancora a peso, e poi
    /// spostata su `Iso.`.
    test('una serie iso già fatta non si riempie col peso', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: [fatta(nome: 'Plank', numero: 1, reps: 30, peso: 12)],
      );

      final plank = esercizi[1];

      expect(plank.carico, CaricoDellEsercizio.iso);
      expect(plank.serieFatte.first.ripetizioni.text, '30');
      expect(
        plank.serieFatte.first.carico.text,
        isNot('12'),
        reason: 'dodici chili scritti nella colonna dei secondi',
      );
    });

    /// ⏳ **Debito dichiarato, e trovato da questo test.**
    ///
    /// ⛔ Il formato vecchio **non sa dire i secondi di isometria**: aveva un
    /// numero solo (`reps`) e nessun posto per `iso_sec`. Una riga che arriva
    /// dal server con `carico: 'iso'` ma senza `serie` — il pannello del
    /// trainer può scriverla così — mostra la colonna dei secondi **vuota**.
    ///
    /// 💡 Ed è la cosa giusta da fare: nessuno ha detto quanti secondi, e
    /// riempirla con le ripetizioni vorrebbe dire inventarli. ⚠️ Basta scriverli
    /// una volta e la scheda passa al formato nuovo, dove il posto c'è.
    test('il formato vecchio non porta i secondi, e non se li inventa', () {
      final esercizi = eserciziDellAllenamento(
        scheda: schedaVecchia(),
        fatte: const [],
      );

      expect(esercizi[1].righe.first.carico.text, isEmpty);
      expect(esercizi[1].righe.first.recupero.text, '60');
    });
  });
}
