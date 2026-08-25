import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/features/training/data/prescrizione.dart';

/// I numeri vengono dalla scheda — 3b-C.5, 25/08/2026.
///
/// 📌 *«se gli ho assegnato una scheda, vuol dire che in quell'allenamento ho
/// usato la scheda. Quindi va usata quella, anche per i pesi e per i muscoli
/// coinvolti»*.
///
/// ⛔ Un allenamento visto solo dall'orologio non ha serie registrate — ma se ci
/// hai attaccato una scheda **si sa cosa hai fatto**, e quattro serie da dodici
/// a quaranta chili sono novecentosessanta chili sollevati.
void main() {
  group('📖 leggere una prescrizione', () {
    test('il formato del server: «4 × 12»', () {
      final p = Prescrizione.leggi('4 × 12');

      expect(p.serie, 4);
      expect(p.ripetizioni, 12);
    });

    /// ⚠️ Il separatore può essere `×` o `x`: il primo lo scrive il server, il
    /// secondo chi digita su una tastiera che il `×` non ce l'ha.
    test('e anche «3x8»', () {
      final p = Prescrizione.leggi('3x8');

      expect(p.serie, 3);
      expect(p.ripetizioni, 8);
    });

    /// 🚨 **Di un intervallo si prende il più basso.** È la stessa prudenza dei
    /// MET: sovrastimare il lavoro fatto porta a credersi più avanti di dove si
    /// è.
    test('di «8-12» si prende 8', () {
      expect(Prescrizione.leggi('4 × 8-12').ripetizioni, 8);
    });

    /// 💡 Caso vero: le serie ci sono anche quando le ripetizioni non sono un
    /// numero.
    test('«4 × cedimento» ha le serie e non le ripetizioni', () {
      final p = Prescrizione.leggi('4 × cedimento');

      expect(p.serie, 4);
      expect(p.ripetizioni, isNull);
    });

    test('e un numero solo sono le serie', () {
      final p = Prescrizione.leggi('3');

      expect(p.serie, 3);
      expect(p.ripetizioni, isNull);
    });

    test('il vuoto non dice niente, e non esplode', () {
      expect(Prescrizione.leggi(null).serie, isNull);
      expect(Prescrizione.leggi('').serie, isNull);
      expect(Prescrizione.leggi('a piacere').serie, isNull);
    });
  });

  group('🏋️ e i chili che ne escono', () {
    test('quattro per dodici a quaranta fanno 1920', () {
      expect(Prescrizione.leggi('4 × 12').volumeCon(40), 1920);
    });

    /// 🚨 **`null`, non `0`.** Senza carico previsto non c'è un volume da
    /// dichiarare, e uno zero sarebbe una bugia precisa: sembra un dato.
    test('senza carico previsto non c\'è nessun volume', () {
      expect(Prescrizione.leggi('4 × 12').volumeCon(null), isNull);
      expect(Prescrizione.leggi('4 × 12').volumeCon(0), isNull);
    });

    test('e nemmeno senza ripetizioni', () {
      expect(Prescrizione.leggi('4 × cedimento').volumeCon(40), isNull);
    });
  });
}
