import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/diary/data/stima_ai.dart';

/// 🚨 La stima del modello, e quello che diceva di sé — A4.8.
///
/// ── Il difetto, trovato il 12/08/2026 ────────────────────────────────────
///
/// Il committente ha chiesto perché il modello non avesse capito che una
/// cotoletta di pollo è impanata. Non lo aveva capito, **e lo aveva scritto**:
/// nella `note` c'era *«non è stato specificato se sono panate, il grado di
/// cottura o il metodo di preparazione»*.
///
/// ⚠️ Quel testo arrivava sul telefono e veniva buttato: prima di oggi la
/// parola `confidence` non compariva in nessun file dell'app.
void main() {
  Map<String, dynamic> risposta({
    List<Map<String, dynamic>>? voci,
    double confidenza = 0.8,
    String? nota,
  }) => {
    'estimate': {
      'items': voci ?? const [],
      'confidence': confidenza,
      'note': nota,
    },
  };

  group('la stima si legge dalla risposta del server', () {
    test('la nota e la confidenza sopravvivono', () {
      final s = StimaAi.fromJson(
        risposta(confidenza: 0.65, nota: 'Non è specificato se sono panate.'),
      );

      expect(s.confidenza, 0.65);
      expect(s.nota, 'Non è specificato se sono panate.');
    });

    /// ⚠️ Una nota vuota **non è una nota**: mostrarla come tale disegnerebbe
    /// un riquadro d'avviso con dentro il nulla, che è peggio di non averlo.
    test('una nota vuota vale come assente', () {
      expect(StimaAi.fromJson(risposta(nota: '   ')).nota, isNull);
      expect(StimaAi.fromJson(risposta()).nota, isNull);
    });

    test('i totali si sommano dalle voci', () {
      final s = StimaAi.fromJson(
        risposta(
          voci: [
            {'name': 'Pasta', 'grams': 80, 'kcal': 280, 'protein': 10, 'carbs': 56, 'fat': 1},
            {'name': 'Sugo', 'grams': 100, 'kcal': 60, 'protein': 2, 'carbs': 8, 'fat': 3},
          ],
        ),
      );

      expect(s.kcal, 340);
      expect(s.proteine, 12);
      expect(s.carboidrati, 64);
      expect(s.grassi, 4);
    });

    /// 💡 Il server manda la stima dentro `estimate`, ma la stessa classe deve
    /// saper leggere anche l'oggetto nudo: è quello che arriva quando la si
    /// ricostruisce da una risposta di conferma.
    test('legge anche l\'oggetto senza involucro', () {
      final s = StimaAi.fromJson({
        'items': [
          {'name': 'Mela', 'grams': 150, 'kcal': 78},
        ],
        'confidence': 0.9,
        'note': null,
      });

      expect(s.voci.single.nome, 'Mela');
      expect(s.confidenza, 0.9);
    });
  });

  /// 🚨 Le soglie sono quelle della regola 8 del prompt lato server. Se
  /// cambiano di là devono cambiare di qua.
  group('il livello di confidenza', () {
    test('segue le soglie del prompt', () {
      expect(LivelloConfidenza.da(0.95), LivelloConfidenza.alta);
      expect(LivelloConfidenza.da(0.85), LivelloConfidenza.alta);
      expect(LivelloConfidenza.da(0.7), LivelloConfidenza.media);
      expect(LivelloConfidenza.da(0.6), LivelloConfidenza.media);
      expect(LivelloConfidenza.da(0.4), LivelloConfidenza.bassa);
      expect(LivelloConfidenza.da(0), LivelloConfidenza.bassa);
    });

    test('solo la confidenza bassa apre i dettagli da sola', () {
      expect(LivelloConfidenza.bassa.apriDaSola, isTrue);
      expect(LivelloConfidenza.media.apriDaSola, isFalse);
      expect(LivelloConfidenza.alta.apriDaSola, isFalse);
    });
  });

  /// 🚨 **Il caso vero che ha fatto nascere tutto questo.**
  ///
  /// Il modello ha risposto **0.85** — cioè «stima sicura» — *mentre* scriveva
  /// nella nota di non sapere se le cotolette fossero panate. La regola 8 del
  /// prompt dice che un'ambiguità vale meno di 0.6: non l'ha rispettata.
  ///
  /// ⚠️ È il motivo per cui la confidenza **non** è il cancello. Se il foglio
  /// decidesse solo in base al numero, questa stima passerebbe liscia — e
  /// passava, infatti, per settimane.
  test('una confidenza alta con una nota resta da guardare', () {
    final cotoletta = StimaAi.fromJson(
      risposta(
        confidenza: 0.85,
        nota: 'Se cucinate diversamente (fritte, panate) i valori cambiano.',
        voci: [
          {'name': 'cotolette di pollo', 'grams': 200, 'kcal': 380, 'protein': 52, 'carbs': 0, 'fat': 18},
        ],
      ),
    );

    expect(cotoletta.livello, LivelloConfidenza.alta);
    expect(
      cotoletta.daGuardare,
      isTrue,
      reason: 'una nota del modello basta da sola: la confidenza non è affidabile',
    );
  });

  /// 🚨 **La massa dei macronutrienti non può superare quella dell'alimento.**
  ///
  /// Il 12/08/2026 il modello ha prodotto delle coppiette di maiale con 56 g di
  /// proteine, 4 di carboidrati e 40 di grassi **per 100 g**: acqua zero.
  /// Fisicamente impossibile, e invisibile — 588 kcal sono un numero plausibile.
  group('i macro impossibili', () {
    VoceStimata voce({
      required double grammi,
      required double p,
      required double c,
      required double f,
    }) => VoceStimata(
      nome: 'x',
      grammi: grammi,
      proteine: p,
      carboidrati: c,
      grassi: f,
    );

    /// 🚨 **Il caso vero.** Ed è anche quello che ha fatto scrivere la seconda
    /// prova: 56 + 4 + 40 fa **esattamente 100**, cioè al limite e non oltre.
    /// Il solo vincolo «più macro della massa» non lo prendeva.
    test('cento grammi di macro in cento grammi di prodotto', () {
      expect(voce(grammi: 100, p: 56, c: 4, f: 40).macroImpossibili, isTrue);
    });

    test('un alimento normale passa', () {
      // Salsiccia secca: 76 g di macro su 100, cioè il 24% d'acqua.
      expect(voce(grammi: 100, p: 27, c: 2, f: 47).macroImpossibili, isFalse);
      // Focaccia: 58 g su 100.
      expect(voce(grammi: 100, p: 8, c: 36, f: 14).macroImpossibili, isFalse);
    });

    /// 🚨 **L'eccezione che rende la regola scrivibile.** Cento grammi d'olio
    /// sono cento grammi di grassi, e non c'è niente di sbagliato: i grassi puri
    /// e gli zuccheri puri sono gli unici alimenti senza acqua, e hanno **un
    /// solo** macronutriente. È il motivo per cui la seconda prova conta quanti
    /// ce ne sono invece di guardare solo la somma.
    test('l\'olio arriva al 100% ed è giusto così', () {
      expect(voce(grammi: 100, p: 0, c: 0, f: 100).macroImpossibili, isFalse);
      // Zucchero: stessa forma, altro macronutriente.
      expect(voce(grammi: 50, p: 0, c: 50, f: 0).macroImpossibili, isFalse);
    });

    /// 💡 Il 2% di tolleranza esiste per gli arrotondamenti: il modello manda
    /// numeri interi. Ma vale sulla **prima** prova — un alimento composito che
    /// sfora resta impossibile comunque.
    test('un arrotondamento su un alimento puro non è un errore', () {
      expect(voce(grammi: 100, p: 0, c: 0, f: 101).macroImpossibili, isFalse);
      expect(voce(grammi: 100, p: 0, c: 0, f: 110).macroImpossibili, isTrue);
    });

    /// ⚠️ Senza grammi non c'è niente con cui confrontare: si tace, non si
    /// inventa un allarme.
    test('senza grammi non si dice niente', () {
      expect(
        const VoceStimata(nome: 'x', proteine: 90, carboidrati: 90, grassi: 90).macroImpossibili,
        isFalse,
      );
    });

    test('la stima intera lo segnala se anche una sola voce lo è', () {
      final s = StimaAi.fromJson(
        risposta(
          voci: [
            {'name': 'Focaccia', 'grams': 100, 'kcal': 297, 'protein': 8, 'carbs': 36, 'fat': 14},
            {'name': 'Coppiette', 'grams': 100, 'kcal': 588, 'protein': 56, 'carbs': 4, 'fat': 40},
          ],
        ),
      );

      expect(s.haMacroImpossibili, isTrue);
      expect(s.daGuardare, isTrue);
    });
  });

  /// La correzione a mano: è il senso stesso del foglio di conferma.
  group('correggere una voce', () {
    test('cambiare la quantità non tocca i macro', () {
      const v = VoceStimata(
        nome: 'Pollo',
        qty: 200,
        unita: 'g',
        grammi: 200,
        kcal: 330,
        proteine: 48,
      );

      final corretta = v.copyCon(qty: 250, grammi: 250);

      expect(corretta.grammi, 250);
      expect(corretta.nome, 'Pollo');
      expect(
        corretta.proteine,
        48,
        reason: 'il ricalcolo lo fa il server, che ha i valori per 100 g',
      );
    });

    test('la quantità si legge come la si scrive', () {
      expect(const VoceStimata(nome: 'x', qty: 200, unita: 'g', grammi: 200).quantita, '200 g');
      expect(
        const VoceStimata(nome: 'x', qty: 1, unita: 'cucchiaio', grammi: 14).quantita,
        '1 cucchiaio · 14 g',
      );
      expect(const VoceStimata(nome: 'x', grammi: 80).quantita, '80 g');
      expect(const VoceStimata(nome: 'x').quantita, '');
    });

    test('togliere una voce non tocca le altre', () {
      final s = StimaAi.fromJson(
        risposta(
          voci: [
            {'name': 'Pasta', 'grams': 80, 'kcal': 280},
            {'name': 'Sugo', 'grams': 100, 'kcal': 60},
          ],
        ),
      );

      final senzaSugo = s.conVoci([s.voci.first]);

      expect(senzaSugo.kcal, 280);
      expect(senzaSugo.nota, s.nota);
      expect(senzaSugo.confidenza, s.confidenza);
    });
  });

  /// 💡 La frase serve al pulsante «Precisa»: si riapre il campo **con dentro**
  /// quello che si era scritto, così si aggiunge «impanate» invece di
  /// ridigitare tutto. Chi deve riscrivere da capo non precisa: conferma.
  test('la frase originale viaggia con la stima', () {
    final s = StimaAi.fromJson(risposta()).conFrase('due cotolette di pollo');

    expect(s.frase, 'due cotolette di pollo');
    expect(s.conVoci(const []).frase, 'due cotolette di pollo');
  });
}
