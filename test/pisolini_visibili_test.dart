import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/health/sessioni_di_sonno.dart';

/// Le pennichelle si vedono, e restano fuori dal conto — 21/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// 📌 Il committente: *«la notte ho dormito 5:16 ma poi ho fatto due pisolini,
/// vedi se ti risultano perché sull'app non si vedono»*.
///
/// ⚠️ **È lo specchio del difetto del 20/08.** Allora le pennichelle finivano
/// **dentro** il totale della notte e la facevano sembrare riposante: *«ho
/// dormito sì 8:55h ma 2 di queste sono state un pisolino»*. La correzione le ha
/// tolte dal conto — giustamente — e le ha tolte **anche dalla vista**.
///
/// 🚨 Le due regole devono valere **insieme**, ed è quello che si prova qui:
/// **fuori dalla somma** e **dentro alla schermata**. Una sola delle due è un
/// difetto, in una direzione o nell'altra.
void main() {
  /// Una notte da 5:16 più due riposi, come la giornata raccontata dal
  /// committente.
  List<({DateTime inizio, DateTime fine})> laGiornata() => [
    // 23:44 → 05:00 = 5h16
    (inizio: DateTime(2026, 8, 20, 23, 44), fine: DateTime(2026, 8, 21, 5)),
    // pisolino di 50 minuti a metà mattina
    (
      inizio: DateTime(2026, 8, 21, 10, 20),
      fine: DateTime(2026, 8, 21, 11, 10),
    ),
    // pisolino di 35 minuti nel pomeriggio
    (inizio: DateTime(2026, 8, 21, 15, 5), fine: DateTime(2026, 8, 21, 15, 40)),
  ];

  test('la notte è una, e i pisolini sono due', () {
    final sessioni = SessioniDiSonno.da(laGiornata());

    expect(sessioni, hasLength(3));

    final notti = sessioni.where((s) => s.eNotte).toList();
    final pisolini = sessioni.where((s) => !s.eNotte).toList();

    expect(notti, hasLength(1));
    expect(pisolini, hasLength(2));
  });

  test('la notte vale 5h16, senza i pisolini dentro', () {
    /*
     * 🚨 Il numero che il committente si aspetta. ⚠️ Sommando anche i due
     * riposi verrebbe 6h41 — che è il difetto del 20/08 daccapo, e farebbe
     * sembrare riposante una notte che non lo è stata.
     */
    final notte = SessioniDiSonno.da(laGiornata()).firstWhere((s) => s.eNotte);

    expect(notte.durata, const Duration(hours: 5, minutes: 16));
  });

  test('i pisolini hanno le loro ore, che è ciò che si vuole vedere', () {
    final pisolini = SessioniDiSonno.da(
      laGiornata(),
    ).where((s) => !s.eNotte).toList();

    expect(pisolini[0].durata, const Duration(minutes: 50));
    expect(pisolini[1].durata, const Duration(minutes: 35));

    // 💡 Il totale che la scheda mostra accanto al titolo.
    final totale = pisolini.fold(Duration.zero, (somma, p) => somma + p.durata);

    expect(totale, const Duration(hours: 1, minutes: 25));
  });

  test('un pisolino non si sposta mai di giorno', () {
    /*
     * ⚠️ Regola già scritta il 18/08 e qui riprovata dal lato delle
     * pennichelle: la notte appartiene al giorno in cui **ti svegli**, la
     * pennichella al giorno in cui **comincia**. 🚨 Senza, una pennica delle
     * 18:09 di ieri finirebbe accreditata a oggi — ed era il difetto riferito
     * allora.
     */
    final sessioni = SessioniDiSonno.da(laGiornata());

    for (final s in sessioni) {
      expect(s.giornata, DateTime(2026, 8, 21), reason: '$s');
    }
  });

  test('una giornata di soli pisolini non produce nessuna notte', () {
    /*
     * 🚨 È il caso che rendeva la schermata bugiarda: `sleepProvider` torna
     * `null`, e prima la schermata diceva «Nessun dato sul sonno» **a chi aveva
     * dormito**. ⚠️ Dire «non ho dati» quando i dati ci sono è il modo più
     * rapido per far smettere di fidarsi di una schermata.
     */
    final sessioni = SessioniDiSonno.da([
      (inizio: DateTime(2026, 8, 21, 14), fine: DateTime(2026, 8, 21, 14, 40)),
      (inizio: DateTime(2026, 8, 21, 17), fine: DateTime(2026, 8, 21, 17, 30)),
    ]);

    expect(sessioni.where((s) => s.eNotte), isEmpty);
    expect(sessioni.where((s) => !s.eNotte), hasLength(2));
  });
}
