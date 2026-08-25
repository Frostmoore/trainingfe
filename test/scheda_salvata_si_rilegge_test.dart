import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/scheda_in_scrittura.dart';
import 'package:training_companion/src/features/training/training_controller.dart';

/// Una scheda salvata dall'editor si rilegge — 3b-D.17, 25/08/2026.
///
/// ══ 🚨 IL GUASTO ══════════════════════════════════════════════════════════
///
/// 📌 *«Se modifico una scheda, quando clicco salva mi dà errore dicendo che
/// qualcosa è andato storto. Adesso la pagina schede mi dice sempre "Qualcosa è
/// andato storto"»*.
///
/// ⛔ `PlanExercise.fromJson` leggeva l'id con un **cast duro**
/// (`(j['id'] as num).toInt()`), e un esercizio scritto dall'editor **non ha
/// nessun id**: gli id delle righe li dava il server, e da B.17 il server non
/// c'è più.
///
/// 🚨 **E non rompeva solo il salvataggio.** Quella scheda restava scritta
/// nell'archivio, e `schedeUniteProvider` la rilegge per **costruire l'elenco**:
/// da quel momento la pagina Schede intera non si apriva più. ⚠️ Un dato
/// scritto male avvelena tutte le letture, non solo quella che lo ha prodotto.
///
/// 💡 Questo test fa il **giro completo**: scrive come scrive l'editor, e
/// rilegge come rilegge l'elenco. È l'unica forma che avrebbe preso il difetto,
/// perché scrittura e lettura sono in due file diversi e ognuna delle due,
/// guardata da sola, era giusta.
void main() {
  /// Come `PlanActions.create` compone la busta, e come `schedeUniteProvider`
  /// la rilegge: l'id e il nome li mette la **riga** dell'archivio.
  WorkoutPlan giroCompleto(List<EsercizioInScrittura> esercizi) =>
      WorkoutPlan.fromJson({
        'name': 'La mia',
        'notes': null,
        'editable': true,
        'exercises': [for (final e in esercizi) e.versoIlDato()],
        'id': 7,
      });

  test('✍️ una scheda scritta a mano si rilegge senza esplodere', () {
    final esercizio = EsercizioInScrittura(nome: 'Panca piana');

    esercizio.serie.first.ripetizioni.text = '12';
    esercizio.serie.first.carico.text = '40';
    esercizio.autocompila();

    final scheda = giroCompleto([esercizio]);

    expect(scheda.exercises, hasLength(1));
    expect(scheda.exercises.first.name, 'Panca piana');

    /// 💡 E le serie arrivano fino in fondo: è il motivo per cui l'editor
    /// esiste.
    expect(scheda.exercises.first.serie, hasLength(3));
    expect(scheda.exercises.first.serie.first.ripetizioni, 12);
    expect(scheda.exercises.first.serie.first.peso, 40);
  });

  /// ⚠️ **L'id di una riga di scheda non serve a niente qui.** Lo dava il
  /// server quando le schede vivevano là; da B.17 vivono sul telefono, e
  /// l'identità di un esercizio è il suo **posto nella scheda**.
  ///
  /// 🚨 Il test lo fissa perché la tentazione, leggendo il codice, è di
  /// «rimettere a posto» quel cast — e il cast era il difetto.
  test('🔢 e l\'id di un esercizio senza id non fa saltare niente', () {
    final scheda = giroCompleto([
      EsercizioInScrittura(nome: 'Uno'),
      EsercizioInScrittura(nome: 'Due'),
    ]);

    expect(scheda.exercises.map((e) => e.name), ['Uno', 'Due']);
  });

  /// ⛔ E una scheda **con** gli id — quelle scese dal server prima di B.17 —
  /// continua a leggerli.
  test('📥 mentre una scheda che gli id ce li ha se li tiene', () {
    final scheda = WorkoutPlan.fromJson({
      'id': 3,
      'name': 'Dal server',
      'editable': false,
      'exercises': [
        {
          'id': 55,
          'exercise': {'id': 900, 'name': 'Squat'},
          'prescription': '4 × 12',
        },
      ],
    });

    expect(scheda.exercises.first.id, 55);
    expect(scheda.exercises.first.exerciseId, 900);
    expect(scheda.exercises.first.serie, hasLength(4));
  });

  /// 🚨 Il caso del committente: una scheda **modificata** e risalvata.
  ///
  /// ⚠️ `PlanActions.update` riscrive `exercises` dentro la busta che c'era, e
  /// quella busta viene dal server: se la rilettura non regge il misto — righe
  /// vecchie con id, righe nuove senza — l'elenco si rompe lo stesso.
  test('📝 e una scheda del server risalvata dall\'editor si rilegge', () {
    final esercizio = EsercizioInScrittura.da({
      'id': 55,
      'exercise': {'id': 900, 'name': 'Squat'},
      'prescription': '4 × 12',
    });

    esercizio.serie.first.carico.text = '50';

    final scheda = WorkoutPlan.fromJson({
      'id': 3,
      'name': 'Dal server, modificata',
      'editable': true,
      // Come la riscrive `update`: le righe nuove non hanno l'id.
      'exercises': [esercizio.versoIlDato()],
    });

    expect(scheda.exercises.first.name, 'Squat');
    expect(scheda.exercises.first.exerciseId, 900);
    expect(scheda.exercises.first.serie.first.peso, 50);
  });
}
