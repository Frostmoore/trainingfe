import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/sleep/sleep_controller.dart';

/// 🌙 **Lo stesso numero deve essere scritto allo stesso modo** — 23/09/2026.
///
/// ⛔ Sul telefono del committente la dashboard scriveva **`5h 35m`** — nella
/// testata e nella card «Recupero» — si toccava quella card, si arrivava su
/// `/sonno`, e lo stesso identico numero diventava **`5h 35`**.
///
/// 🚨 **Un'unità che compare e sparisce fa dubitare del numero, non del
/// carattere**: chi legge `5h 35` dopo aver letto `5h 35m` si ferma un istante
/// a chiedersi se sta guardando la stessa cosa. Su una schermata che parla di
/// quanto hai dormito, quell'istante è tutto quello che c'è da perdere.
///
/// 💡 Il test guarda `SleepNight.durata` perché è **l'unico posto** da cui esce
/// quella stringa: le altre tre (`today_cards.dart`, `_Pisolini._durata`, la
/// legenda delle fasi) hanno già la forma giusta, e la quarta era questa.
SleepNight _notteDi(int minuti) => SleepNight(
  night: DateTime(2026, 9, 23),
  from: DateTime(2026, 9, 23, 2, 2),
  to: DateTime(2026, 9, 23, 7, 40),
  asleepMinutes: minuti,
  awakeMinutes: 3,
  lightMinutes: 201,
  deepMinutes: 44,
  remMinutes: 90,
  deepPct: 13,
  remPct: 27,
  ratings: const {},
  overall: 'ok',
  hypnogram: const [],
);

void main() {
  group('la durata di una notte', () {
    test('porta la «m», come la dashboard', () {
      // La notte vera del 23/09 sul telefono del committente.
      expect(_notteDi(335).durata, '5h 35m');
    });

    test('sotto l\'ora si scrive da sola', () {
      // 💡 `0h 54` è un modo complicato di dire poco meno di un'ora: è la
      // stessa scelta già fatta per i pisolini in `sleep_screen.dart`.
      expect(_notteDi(54).durata, '54m');
    });

    test('i minuti tondi non diventano «5h 0m» per caso', () {
      expect(_notteDi(300).durata, '5h 0m');
    });

    test(
      '⛔ non torna mai alla forma vecchia, senza unità',
      () {
        for (final minuti in [335, 54, 300, 1, 599]) {
          expect(
            _notteDi(minuti).durata,
            endsWith('m'),
            reason:
                'Con $minuti minuti la durata finisce senza unità: è il '
                'difetto del 23/09 tornato.',
          );
        }
      },
    );
  });
}
