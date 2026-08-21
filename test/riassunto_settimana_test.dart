import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/dashboard/riassunto_settimana.dart';

/// La stima del peso dai sette giorni — 3b-O.7.4, 21/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// Non la formula — quella è una divisione. **La regola che le sta attorno**:
/// *un giorno senza diario non è un giorno a digiuno*.
///
/// ⚠️ È esattamente il difetto che questa funzione può avere e che nessuno
/// vedrebbe: con `assunte = 0` il saldo di quel giorno varrebbe `−consumo`,
/// cioè −2.400 kcal. Su tre giorni saltati fa quasi **un chilo di dimagrimento
/// che non è successo** — e il numero resta credibile, quindi non si scopre
/// guardando l'app.
///
/// 🚨 È la stessa specie di difetto di §56.3 n° 3 dell'atlante: un risultato
/// plausibile e sbagliato, senza nessun errore a schermo.
void main() {
  const consumo = 2000.0;

  test('un giorno senza diario NON conta come digiuno', () {
    // Tre giorni in pari, quattro non registrati.
    final stima = pesoDalSaldo(
      assunte: const [2000, 2000, 2000, 0, 0, 0, 0],
      consumo: consumo,
    );

    /*
     * 🚨 Se i giorni vuoti contassero, il saldo sarebbe −8.000 kcal, cioè più
     * di un chilo. ⚠️ Il valore giusto è **zero**: i tre giorni registrati sono
     * in pari, e degli altri quattro non si sa niente.
     */
    expect(stima, isNotNull);
    expect(stima!, closeTo(0, 0.0001));
  });

  test('nessun giorno registrato non è zero chili: è nessuna stima', () {
    // ⛔ `null` e non `0`: chi disegna deve poter **non mostrare** la voce.
    // Uno zero direbbe «sei in pari», che è un'affermazione, non un'assenza.
    expect(pesoDalSaldo(assunte: const [0, 0, 0], consumo: consumo), isNull);
    expect(pesoDalSaldo(assunte: const [], consumo: consumo), isNull);
  });

  test('un surplus fa salire, un deficit fa scendere', () {
    // +500 kcal al giorno per 7 giorni = 3.500 kcal = 3500/7700 kg.
    final su = pesoDalSaldo(assunte: List.filled(7, 2500), consumo: consumo);

    expect(su, isNotNull);
    expect(su!, closeTo(3500 / 7700, 0.0001));

    final giu = pesoDalSaldo(assunte: List.filled(7, 1500), consumo: consumo);

    expect(giu, isNotNull);
    expect(giu!, closeTo(-3500 / 7700, 0.0001));
  });

  test('le bruciate si tolgono in PROPORZIONE ai giorni registrati', () {
    /*
     * 🚨 È l'altra trappola: `bruciate` è la somma di **tutta** la settimana,
     * mentre il saldo può essere calcolato su meno giorni.
     *
     * ⚠️ Sottraendola intera a un saldo di tre giorni, quei tre si porterebbero
     * addosso anche l'attività dei quattro di cui non si sa cosa si è mangiato:
     * il dimagrimento risulterebbe più del doppio.
     */
    final stima = pesoDalSaldo(
      assunte: const [2000, 2000, 2000, 0, 0, 0, 0],
      consumo: consumo,
      bruciate: 700,
    );

    // 3 giorni su 7 → si tolgono 300 kcal, non 700.
    expect(stima, isNotNull);
    expect(stima!, closeTo(-300 / 7700, 0.0001));
  });

  test('la costante è quella scritta nella documentazione', () {
    // 💡 Il numero compare anche nel testo che l'app mostra all'utente: se
    // cambia qui e non là, l'avvertenza spiega una formula che non giriamo.
    expect(RiassuntoSettimana.kcalPerChilo, 7700.0);
  });

  test('un riassunto senza niente si riconosce da solo', () {
    // ⛔ Serve a far sparire la sezione invece di disegnare cinque assenze.
    expect(const RiassuntoSettimana().vuoto, isTrue);
    expect(const RiassuntoSettimana(sedute: 1).vuoto, isFalse);
    expect(const RiassuntoSettimana(minutiDormiti: 420).vuoto, isFalse);
  });

  test('i tipi con distanza escludono la palestra', () {
    /*
     * ⚠️ `distanzaMetri` esiste anche su un allenamento di forza, e lì vuol
     * dire un'altra cosa (o niente). 🚨 Sommarla ai chilometri corsi darebbe
     * «12 km percorsi» a chi ha fatto panca.
     */
    expect(tipiConDistanza.contains('RUNNING'), isTrue);
    expect(tipiConDistanza.contains('BIKING'), isTrue);
    expect(tipiConDistanza.contains('WALKING'), isTrue);
    expect(tipiConDistanza.contains('STRENGTH_TRAINING'), isFalse);
    expect(tipiConDistanza.contains('SWIMMING_POOL'), isFalse);
  });
}
