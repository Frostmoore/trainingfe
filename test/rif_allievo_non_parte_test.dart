import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/crypto/contenuto_messaggio.dart';

/// Il terzo punto di R4: **il «Rif. Allievo» non entra nella busta** — G10.1.
///
/// ── 🚨 Perché questo test sta nell'app e non sul server ───────────────────
///
/// Gli altri due punti (l'API e il pannello) nascondono il campo **a chi non
/// l'ha scritto**. Ma chi manda il piano **è** chi l'ha scritto: il campo ce
/// l'ha, glielo serve legittimamente, ed è lui a spedire.
///
/// ⚠️ È il punto che si dimentica per primo, perché gli altri due sembrano già
/// bastare. Se salta, l'allievo riceve dentro il proprio piano l'etichetta con
/// cui il trainer lo chiama negli appunti.
void main() {
  test('lo spoglio toglie il rif_allievo e lascia tutto il resto', () {
    final dalServer = <String, dynamic>{
      'id': 7,
      'origine_id': '01JXYZ',
      'name': 'Definizione',
      'rif_allievo': 'M.R. spalla dx',
      'target_kcal': 1800,
      'days': [
        {'name': 'Giorno 1', 'meals': []},
      ],
    };

    // È lo stesso gesto di `_allegaPiano()` in `conversations_screen.dart`.
    final perLAllievo = Map<String, dynamic>.from(dalServer)
      ..remove('rif_allievo');

    expect(perLAllievo.containsKey('rif_allievo'), isFalse);

    // 💡 E **niente altro** è sparito: lo spoglio è chirurgico, non una
    // whitelist. Una whitelist perderebbe i campi che l'app non conosce ancora.
    expect(perLAllievo['name'], 'Definizione');
    expect(perLAllievo['origine_id'], '01JXYZ');
    expect(perLAllievo['target_kcal'], 1800);
    expect((perLAllievo['days'] as List).length, 1);
  });

  test('la busta cifrata non contiene il rif_allievo', () {
    final perLAllievo = <String, dynamic>{
      'name': 'Definizione',
      'origine_id': '01JXYZ',
    };

    final busta = ContenutoPianoAlimentare(perLAllievo).perLaBusta();

    /*
     * 🚨 Si guarda la **stringa che va cifrata**, non l'oggetto: è quella che
     * finisce sul server, e un test sull'oggetto direbbe che va tutto bene
     * anche se la serializzazione ci rimettesse dentro qualcosa.
     */
    expect(busta.contains('rif_allievo'), isFalse);
    expect(busta.contains('M.R.'), isFalse);

    final riletto = ContenutoMessaggio.daChiaro(busta);

    expect(riletto, isA<ContenutoPianoAlimentare>());
    expect((riletto as ContenutoPianoAlimentare).origineId, '01JXYZ');
  });

  test('lo spoglio non tocca l originale', () {
    final dalServer = <String, dynamic>{'name': 'X', 'rif_allievo': 'M.R.'};

    final copia = Map<String, dynamic>.from(dalServer)..remove('rif_allievo');

    expect(copia.containsKey('rif_allievo'), isFalse);

    /*
     * ⚠️ `Map.from()` copia, `..remove()` sul risultato non tocca l'originale —
     * ma è esattamente il tipo di cosa che si rompe «semplificando» in
     * `dalServer..remove(...)`. Il sintomo sarebbe che il trainer **perde il
     * proprio promemoria** ogni volta che manda un piano.
     */
    expect(dalServer['rif_allievo'], 'M.R.');
  });
}
