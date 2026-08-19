import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/crypto/contenuto_messaggio.dart';
import 'package:training_companion/src/features/nutrition/data/piano_alimentare.dart';

/// Consigli, non diete — N19, lato app.
///
/// ⚠️ **Il vincolo vero sta sul server** (`ConsigliAlimentariTest` nel
/// backend): l'API è pubblica, e una regola che vive solo nel client non è una
/// regola. Qui si prova che l'app non ci provi nemmeno, e che la busta dica
/// chiaramente cosa sta trasportando.
void main() {
  group('il tipo del piano', () {
    test('🚨 di serie è «consigli», cioè il più povero', () {
      /*
       * Un campo che manca non deve **promuovere** un documento a qualcosa che
       * chi l'ha scritto non aveva il titolo di scrivere. ⚠️ Il default opposto
       * avrebbe fatto passare per piani veri tutte le risposte scritte prima di
       * questa versione.
       */
      expect(PianoAlimentare().tipo, TipoPiano.consigli);
      expect(TipoPiano.da(null), TipoPiano.consigli);
      expect(TipoPiano.da(''), TipoPiano.consigli);
      expect(TipoPiano.da('inventato'), TipoPiano.consigli);
      expect(TipoPiano.da('piano'), TipoPiano.piano);
    });

    test('il tipo viaggia nel JSON, in tutte e due le direzioni', () {
      final letto = PianoAlimentare.fromJson({
        'name': 'Dieta',
        'tipo': 'piano',
      });

      expect(letto.tipo, TipoPiano.piano);
      expect(letto.toJson()['tipo'], 'piano');

      expect(
        PianoAlimentare(nome: 'Spesa').toJson()['tipo'],
        'consigli',
      );
    });

    test('una risposta senza il campo resta consigli', () {
      // 💡 È il caso di un server più vecchio dell'app: non deve produrre un
      // piano vero per omissione.
      expect(
        PianoAlimentare.fromJson({'name': 'Vecchio'}).tipo,
        TipoPiano.consigli,
      );
    });
  });

  group('la busta dei consigli', () {
    test('porta un elenco di alimenti, e si rilegge', () {
      const busta = ContenutoConsigliAlimentari({
        'name': 'Cosa tenere in dispensa',
        'foods': ['Pollo', 'Riso', 'Broccoli'],
        'notes': 'Varia le verdure.',
      });

      final riletta =
          ContenutoMessaggio.daChiaro(busta.perLaBusta())
              as ContenutoConsigliAlimentari;

      expect(riletta.titolo, 'Cosa tenere in dispensa');
      expect(riletta.alimenti, ['Pollo', 'Riso', 'Broccoli']);
      expect(riletta.note, 'Varia le verdure.');
    });

    test('🚨 è un tipo SUO, non un piano con i giorni vuoti', () {
      /*
       * ⚠️ Un `meal_plan` senza giorni sarebbe stato più rapido e sbagliato:
       * chi lo riceve non saprebbe se è un elenco di consigli o un piano
       * arrivato monco. E il giorno che un nutrizionista manderà un piano vero,
       * i due devono disegnarsi in modo diverso — perché sono due cose diverse,
       * e una delle due è un atto riservato.
       */
      const busta = ContenutoConsigliAlimentari({'name': 'X', 'foods': ['Pane']});

      final dentro = json.decode(busta.perLaBusta()) as Map<String, dynamic>;

      expect(dentro['t'], 'food_advice');

      final riletta = ContenutoMessaggio.daChiaro(busta.perLaBusta());

      expect(riletta, isA<ContenutoConsigliAlimentari>());
      expect(riletta, isNot(isA<ContenutoPianoAlimentare>()));
    });

    test('alimenti vuoti o di soli spazi non contano', () {
      const busta = ContenutoConsigliAlimentari({
        'foods': ['Pollo', '', '   ', 'Riso'],
      });

      expect(busta.alimenti, ['Pollo', 'Riso']);
    });

    test('senza niente dentro non esplode', () {
      // 🚨 La promessa di `ContenutoMessaggio`: non lancia mai.
      const vuota = ContenutoConsigliAlimentari({});

      expect(vuota.titolo, 'Consigli alimentari');
      expect(vuota.alimenti, isEmpty);
      expect(vuota.note, isNull);
    });

    test('una busta di un tipo sconosciuto resta gestibile', () {
      final letta = ContenutoMessaggio.daChiaro(
        json.encode({'t': 'food_advice', 'v': 2}),
      );

      expect(letta, isA<ContenutoSconosciuto>());
    });
  });
}
