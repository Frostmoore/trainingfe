import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/health/sessioni_di_sonno.dart';

/// Notti e pennichelle — 18/08/2026.
///
/// 🚨 **Il difetto che ha fatto nascere questo file.**
///
/// La regola precedente decideva la giornata guardando l'ora d'inizio del
/// **singolo segmento di fase**: dopo le 18 apparteneva al giorno dopo. Una
/// pennichella cominciata alle **18:09** finiva quindi accreditata all'indomani,
/// e la giornata risultava sfasata di mezza giornata.
///
/// ⚠️ Con un segmento di venti minuti in mano quella domanda **non ha
/// risposta**: bisogna prima ricomporre la dormita intera.
void main() {
  ({DateTime inizio, DateTime fine}) seg(DateTime a, DateTime b) => (inizio: a, fine: b);

  group('i numeri veri del telefono, 17-18/08/2026', () {
    // Riferiti dal committente:
    //   ieri 18:09 → 19:30   (seconda pennichella di ieri)
    //   oggi 05:10 → 09:22   (la notte)
    //   oggi 15:16 → 16:37   (pennichella di oggi)
    final pennicaDiIeri = seg(DateTime(2026, 8, 17, 18, 9), DateTime(2026, 8, 17, 19, 30));
    final laNotte = seg(DateTime(2026, 8, 18, 5, 10), DateTime(2026, 8, 18, 9, 22));
    final pennicaDiOggi = seg(DateTime(2026, 8, 18, 15, 16), DateTime(2026, 8, 18, 16, 37));

    test('sono tre dormite distinte, non una', () {
      final sessioni = SessioniDiSonno.da([pennicaDiIeri, laNotte, pennicaDiOggi]);

      expect(sessioni, hasLength(3));
    });

    test('solo quella delle 5:10 è una notte', () {
      final sessioni = SessioniDiSonno.da([pennicaDiIeri, laNotte, pennicaDiOggi]);

      expect(sessioni.map((s) => s.eNotte), [false, true, false]);
    });

    /// 🚨 **Il difetto riferito, in un test.**
    ///
    /// *«è assurdo che mi prenda la pennica di ieri come parte del sonno di
    /// oggi»* — con la regola vecchia le 18:09 finivano sul 18, perché 18 ≥ 18.
    test('la pennica di ieri resta su ieri', () {
      final sessioni = SessioniDiSonno.da([pennicaDiIeri, laNotte, pennicaDiOggi]);

      expect(sessioni[0].giornata, DateTime(2026, 8, 17));
    });

    test('la notte e la pennica di oggi stanno su oggi', () {
      final sessioni = SessioniDiSonno.da([pennicaDiIeri, laNotte, pennicaDiOggi]);

      expect(sessioni[1].giornata, DateTime(2026, 8, 18));
      expect(sessioni[2].giornata, DateTime(2026, 8, 18));
    });
  });

  group('come si riconosce una notte', () {
    /// 💡 La dormita principale è tale **a qualunque ora**: chi lavora di notte
    /// e dorme dalle 9 alle 16 non sta facendo una pennichella di sette ore.
    test('una dormita lunga è una notte anche in pieno giorno', () {
      final s = SessioniDiSonno.da([
        seg(DateTime(2026, 8, 18, 9), DateTime(2026, 8, 18, 16)),
      ]).single;

      expect(s.eNotte, isTrue);
      // ⚠️ E si accredita al giorno del risveglio, come ogni notte.
      expect(s.giornata, DateTime(2026, 8, 18));
    });

    /// ⚠️ Un colpo di sonno resta un colpo di sonno anche a notte fonda.
    test('mezz ora alle tre di mattina non è una notte', () {
      final s = SessioniDiSonno.da([
        seg(DateTime(2026, 8, 18, 3), DateTime(2026, 8, 18, 3, 30)),
      ]).single;

      expect(s.eNotte, isFalse);
      expect(s.giornata, DateTime(2026, 8, 18));
    });

    test('una notte corta ma dentro il cuore della notte conta come notte', () {
      final s = SessioniDiSonno.da([
        seg(DateTime(2026, 8, 17, 23, 30), DateTime(2026, 8, 18, 2, 30)),
      ]).single;

      expect(s.eNotte, isTrue);
      // Il giorno del risveglio.
      expect(s.giornata, DateTime(2026, 8, 18));
    });

    /// 🚨 Il caso che distingue questa regola da «guarda solo l'ora»: due ore e
    /// mezza di pomeriggio sono una pennichella lunga, non una notte.
    test('due ore e mezza di pomeriggio restano una pennichella', () {
      final s = SessioniDiSonno.da([
        seg(DateTime(2026, 8, 18, 14), DateTime(2026, 8, 18, 16, 30)),
      ]).single;

      expect(s.eNotte, isFalse);
      expect(s.giornata, DateTime(2026, 8, 18));
    });

    /// ⚠️ La notte classica, quella che non deve rompersi mai.
    test('dalle 23 alle 7 è una notte, accreditata al risveglio', () {
      final s = SessioniDiSonno.da([
        seg(DateTime(2026, 8, 17, 23), DateTime(2026, 8, 18, 7)),
      ]).single;

      expect(s.eNotte, isTrue);
      expect(s.giornata, DateTime(2026, 8, 18));
    });
  });

  group('come si ricompongono i segmenti', () {
    /// 🚨 È il caso vero: Health Connect non manda dormite, manda **fasi**.
    /// Una notte sola sono decine di righe contigue.
    test('le fasi contigue di una notte sono una dormita sola', () {
      final s = SessioniDiSonno.da([
        seg(DateTime(2026, 8, 17, 23), DateTime(2026, 8, 17, 23, 40)),
        seg(DateTime(2026, 8, 17, 23, 40), DateTime(2026, 8, 18, 1)),
        seg(DateTime(2026, 8, 18, 1), DateTime(2026, 8, 18, 2, 20)),
        seg(DateTime(2026, 8, 18, 2, 20), DateTime(2026, 8, 18, 7)),
      ]);

      expect(s, hasLength(1));
      expect(s.single.eNotte, isTrue);
      expect(s.single.giornata, DateTime(2026, 8, 18));
    });

    /// 💡 Chi si sveglia e si rigira per un'ora sta ancora facendo la stessa
    /// notte — e alcuni orologi quel pezzo non lo registrano affatto.
    test('un buco di un ora dentro la notte non la spezza', () {
      final s = SessioniDiSonno.da([
        seg(DateTime(2026, 8, 17, 23), DateTime(2026, 8, 18, 3)),
        seg(DateTime(2026, 8, 18, 4), DateTime(2026, 8, 18, 7, 30)),
      ]);

      expect(s, hasLength(1));
      expect(s.single.eNotte, isTrue);
    });

    /// ⚠️ Ma sei ore di distanza sono due dormite diverse, sempre.
    test('la notte e la pennica del pomeriggio restano separate', () {
      final s = SessioniDiSonno.da([
        seg(DateTime(2026, 8, 18, 0), DateTime(2026, 8, 18, 7)),
        seg(DateTime(2026, 8, 18, 15), DateTime(2026, 8, 18, 16)),
      ]);

      expect(s, hasLength(2));
      expect(s.map((x) => x.eNotte), [true, false]);
    });

    /// ⚠️ Due sorgenti (orologio e telefono) possono descrivere lo stesso pezzo
    /// di notte: i segmenti si sovrappongono e non devono generare due dormite.
    test('segmenti sovrapposti non diventano due dormite', () {
      final s = SessioniDiSonno.da([
        seg(DateTime(2026, 8, 17, 23), DateTime(2026, 8, 18, 4)),
        seg(DateTime(2026, 8, 18, 2), DateTime(2026, 8, 18, 7)),
      ]);

      expect(s, hasLength(1));
      expect(s.single.inizio, DateTime(2026, 8, 17, 23));
      expect(s.single.fine, DateTime(2026, 8, 18, 7));
    });

    test('i segmenti in disordine vengono rimessi in fila', () {
      final s = SessioniDiSonno.da([
        seg(DateTime(2026, 8, 18, 15), DateTime(2026, 8, 18, 16)),
        seg(DateTime(2026, 8, 18, 0), DateTime(2026, 8, 18, 7)),
      ]);

      expect(s.first.inizio, DateTime(2026, 8, 18, 0));
    });

    test('nessun segmento, nessuna dormita', () {
      expect(SessioniDiSonno.da(const []), isEmpty);
    });
  });

  group('la giornata di ogni segmento', () {
    /// 💡 È la forma che serve a chi scrive in banca dati: per ogni segmento,
    /// il giorno da mettere in colonna.
    test('ogni fase eredita la giornata della sua dormita', () {
      final segmenti = [
        // Pennica di ieri sera.
        seg(DateTime(2026, 8, 17, 18, 9), DateTime(2026, 8, 17, 19, 30)),
        // La notte, in due fasi.
        seg(DateTime(2026, 8, 18, 5, 10), DateTime(2026, 8, 18, 7)),
        seg(DateTime(2026, 8, 18, 7), DateTime(2026, 8, 18, 9, 22)),
      ];

      final giornate = SessioniDiSonno.giornatePerSegmento(segmenti);

      expect(giornate[DateTime(2026, 8, 17, 18, 9)], DateTime(2026, 8, 17));
      expect(giornate[DateTime(2026, 8, 18, 5, 10)], DateTime(2026, 8, 18));
      expect(giornate[DateTime(2026, 8, 18, 7)], DateTime(2026, 8, 18));
    });
  });
}
