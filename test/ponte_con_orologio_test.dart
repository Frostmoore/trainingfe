import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/allenamento_in_corso.dart';
import 'package:training_companion/src/features/training/data/prescrizione.dart';
import 'package:training_companion/src/features/training/data/serie_prevista.dart';
import 'package:training_companion/src/features/training/training_controller.dart';

/// Il ponte con l'orologio non si rompe salvando una scheda — 3b-E.12.
///
/// ══ 📌 LA DOMANDA DEL COMMITTENTE ═════════════════════════════════════════
///
/// *«assicurati che questa cosa non abbia rotto l'accoppiamento degli
/// allenamenti con l'orologio»*.
///
/// ══ 🚨 ERA ROTTO, E LA DOMANDA ERA GIUSTA ═════════════════════════════════
///
/// Un allenamento letto dal polso non ha serie registrate: l'orologio misura
/// tempo, battito e calorie, non quanto hai caricato. 💡 Ma se ci hai attaccato
/// una scheda, **si sa cosa hai fatto** — e da lì il carosello prende i **chili
/// sollevati** e il **numero di serie**.
///
/// ⛔ Quei due numeri si ricavavano da `prescription`, un campo che manda il
/// **server** e che `esercizioInJson` non riscriveva. 🚨 Da 3b-E il player
/// risalva la scheda **a ogni allenamento**: bastava allenarsi una volta perché
/// una scheda perdesse la prescrizione per sempre, e con lei volume e serie.
///
/// ⚠️ **Non dava nessun errore.** Dava una card che diventa muta, e chi la
/// guarda pensa che l'orologio non abbia registrato niente.
void main() {
  /// Una scheda come la manda il server: con la prescrizione già composta.
  Map<String, dynamic> dalServer() => {
    'id': 8,
    'name': 'Full body A',
    'exercises': [
      {
        'id': 7,
        'exercise': {'id': 12, 'name': 'Panca piana', 'image_url': 'x.png'},
        'prescription': '4 × 12',
        'sets': 4,
        'reps': '12',
        'rest_sec': 90,
        'target_weight': 40,
      },
    ],
  };

  /// La stessa scheda **dopo un allenamento**: riscritta dal player.
  Map<String, dynamic> dopoUnAllenamento(Map<String, dynamic> scheda) =>
      schedaConGliEsercizi(scheda, [
        for (final e in eserciziDellAllenamento(scheda: scheda, fatte: const []))
          e.versoIlDato(),
      ]);

  group('🔗 la prescrizione sopravvive al salvataggio', () {
    test('prima: la scheda del server ce l\'ha', () {
      final piano = WorkoutPlan.fromJson(dalServer());

      expect(piano.exercises.single.prescription, '4 × 12');
    });

    /// 🚨 **Il caso che era rotto.**
    test('e dopo un allenamento c\'è ancora', () {
      final piano = WorkoutPlan.fromJson(dopoUnAllenamento(dalServer()));

      expect(piano.exercises.single.prescription, '4 × 12');
    });

    /// ⚠️ E si legge davvero: non basta che la stringa ci sia, deve dire le
    /// stesse cose a chi la interpreta.
    test('e dice ancora quattro serie da dodici', () {
      final piano = WorkoutPlan.fromJson(dopoUnAllenamento(dalServer()));
      final letta = Prescrizione.leggi(piano.exercises.single.prescription);

      expect(letta.serie, 4);
      expect(letta.ripetizioni, 12);
    });

    /// 💡 Una scheda **nata sul telefono** non è mai passata dal server, quindi
    /// una prescrizione non l'ha mai avuta: si ricostruisce lo stesso.
    test('e una scheda nata nell\'app se la costruisce da sola', () {
      final scheda = schedaConGliEsercizi(const {}, [
        EsercizioInAllenamento(
          nome: 'Squat',
          serie: [
            SerieInAllenamento(ripetizioni: '10', carico: '60'),
            SerieInAllenamento(ripetizioni: '10', carico: '60'),
            SerieInAllenamento(ripetizioni: '8', carico: '70'),
          ],
        ).versoIlDato(),
      ]);

      final piano = WorkoutPlan.fromJson(scheda);

      expect(piano.exercises.single.prescription, '3 × 10-8');
      expect(Prescrizione.leggi('3 × 10-8').serie, 3);
    });
  });

  group('🏋️ i chili sollevati, riga per riga', () {
    /// ══ 💡 E ADESSO SONO ANCHE GIUSTI ══════════════════════════════════════
    ///
    /// ⛔ Il volume si stimava rileggendo `'3 × 10'` e moltiplicando per **un**
    /// peso: una piramide diventava `serie × ripetizioni × peso più basso`.
    /// 🚨 Qui: 10×60 + 10×60 + 8×70 = **1760**, mentre la vecchia stima diceva
    /// 3 × 10 × 60 = 1800. Su schede più ripide lo scarto arriva al 45%.
    test('una piramide si conta esatta', () {
      final piano = WorkoutPlan.fromJson(
        schedaConGliEsercizi(const {}, [
          EsercizioInAllenamento(
            nome: 'Squat',
            serie: [
              SerieInAllenamento(ripetizioni: '10', carico: '60'),
              SerieInAllenamento(ripetizioni: '10', carico: '60'),
              SerieInAllenamento(ripetizioni: '8', carico: '70'),
            ],
          ).versoIlDato(),
        ]),
      );

      expect(piano.exercises.single.volume, 1760);
    });

    /// ⚠️ Su una scheda vecchia il peso sta **solo nel riassunto**: le righe
    /// espanse se lo portano dietro, e il ripiego copre il resto.
    test('e una scheda del server si conta lo stesso', () {
      final piano = WorkoutPlan.fromJson(dalServer());

      expect(piano.exercises.single.volume, 4 * 12 * 40);
    });

    /// ⛔ **A corpo libero e in isometria non ci sono chili da sommare**, e zero
    /// sarebbe una bugia precisa: `null` dice «non si sa», che è la verità.
    test('ma a corpo libero non si inventano chili', () {
      final piano = WorkoutPlan.fromJson(
        schedaConGliEsercizi(const {}, [
          EsercizioInAllenamento(
            nome: 'Piegamenti',
            carico: CaricoDellEsercizio.niente,
            serie: [SerieInAllenamento(ripetizioni: '20')],
          ).versoIlDato(),
        ]),
      );

      expect(piano.exercises.single.volume, isNull);
    });
  });

  /// ⛔ **«0 esercizi» su ogni scheda scritta nell'app.** `exercises_count` è un
  /// campo del server, e le schede locali non ce l'hanno: la pagina Schede
  /// mostrava uno zero, che sembra un conto e invece è un campo mancante.
  test('🔢 il conteggio degli esercizi non è più zero', () {
    final piano = WorkoutPlan.fromJson(dopoUnAllenamento(dalServer()));

    expect(piano.exercisesCount, 1);
  });

  /// ⚠️ E quello del server continua a comandare dove c'è: nell'**elenco** le
  /// schede scendono senza gli esercizi, e contarli darebbe zero.
  test('ma quello del server vince, dove c\'è', () {
    final piano = WorkoutPlan.fromJson({
      'id': 1,
      'name': 'Full body',
      'exercises_count': 9,
      'exercises': <dynamic>[],
    });

    expect(piano.exercisesCount, 9);
  });
}
