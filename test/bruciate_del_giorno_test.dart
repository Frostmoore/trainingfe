import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/diary/data/bruciate_del_giorno.dart';
import 'package:training_companion/src/features/diary/data/target_del_giorno.dart';
import 'package:training_companion/src/features/health/dati_salute.dart';

/// La catena delle calorie bruciate — FASE 1.
///
/// ── 🚨 Cosa difendono questi test ──────────────────────────────────────────
///
/// Che le tre fonti **si sostituiscano invece di sommarsi**. È il tranello
/// centrale: l'orologio ha già misurato l'allenamento che la nostra formula sta
/// stimando, e sommarli darebbe a chi si allena il **doppio** del margine
/// calorico — con un numero che resta plausibile e che nessuno verificherebbe.
void main() {
  group('la catena: manuale → orologio → stima', () {
    /// 🚨 Il manuale vince su tutto, ed è la richiesta esplicita del
    /// committente: *«devono overriddare le calorie totali ricevute da google
    /// health»*.
    test('il manuale batte l\'orologio e la stima', () {
      final b = BruciateDelGiorno.scegli(manuale: 700, daHealth: 450, stimate: 300);

      expect(b.kcal, 700);
      expect(b.fonte, FonteBruciate.manuale);
    });

    /// 🚨 *«Se cancello le calorie bruciate dalla scheda cibo deve tornare a
    /// considerare quelle ricevute da google health»*.
    test('senza manuale vince l\'orologio', () {
      final b = BruciateDelGiorno.scegli(manuale: null, daHealth: 450, stimate: 300);

      expect(b.kcal, 450);
      expect(b.fonte, FonteBruciate.orologio);
    });

    test('senza orologio resta la stima', () {
      final b = BruciateDelGiorno.scegli(manuale: null, daHealth: 0, stimate: 300);

      expect(b.kcal, 300);
      expect(b.fonte, FonteBruciate.stima);
    });

    test('senza niente, niente', () {
      final b = BruciateDelGiorno.scegli(manuale: null, daHealth: 0, stimate: 0);

      expect(b.kcal, 0);
      expect(b.esistono, isFalse);
      expect(b.fonte, FonteBruciate.nessuna);
    });

    /*
     * 🚨 **Il test che giustifica `int?` invece di `int`.**
     *
     * «0 dichiarato» — *oggi non ho bruciato niente* — deve vincere
     * sull'orologio. «non l'ho scritto» deve lasciarlo passare. Guardando solo
     * il numero i due casi sono identici, e chi scrive zero si vedrebbe
     * comparire il numero dell'orologio al posto suo.
     */
    test('zero dichiarato a mano batte l\'orologio', () {
      final b = BruciateDelGiorno.scegli(manuale: 0, daHealth: 450, stimate: 300);

      expect(b.kcal, 0);
      expect(b.fonte, FonteBruciate.manuale);
    });

    /// ⚠️ **Non si sommano.** 450 + 300 farebbe 750, e sarebbe il doppio
    /// conteggio dello stesso allenamento.
    test('le fonti non si sommano mai fra loro', () {
      expect(
        BruciateDelGiorno.scegli(manuale: null, daHealth: 450, stimate: 300).kcal,
        450,
      );
    });
  });

  group('l\'obiettivo del giorno le comprende', () {
    test('le bruciate risolte entrano nel target calcolato in locale', () {
      final b = BruciateDelGiorno.scegli(manuale: null, daHealth: 450, stimate: 300);
      final t = TargetDelGiorno.scegli(dalServer: null, locale: 2000, bruciate: b.kcal);

      expect(t.kcal, 2450);
      expect(t.bruciateIncluse, isTrue);
    });
  });

  group('le calorie attive nell\'archivio', () {
    late ArchivioSalute archivio;

    setUp(() => archivio = ArchivioSalute.inMemoria());
    tearDown(() => archivio.close());

    LetturaSalute campione(String fonte, double kcal, DateTime quando) => LetturaSalute(
      id: 0,
      fonte: fonte,
      metrica: MetricaSalute.calorieAttive.codice,
      misurataIl: quando,
      giorno: DateTime(quando.year, quando.month, quando.day),
      valore: kcal,
    );

    test('i campioni di una sorgente si sommano', () async {
      final oggi = DateTime(2026, 8, 19, 10);

      await archivio.scriviLetture([
        campione('watch', 120, oggi),
        campione('watch', 80, oggi.add(const Duration(hours: 1))),
        campione('watch', 50, oggi.add(const Duration(hours: 2))),
      ]);

      expect(await archivio.kcalAttiveDi(oggi), 250);
    });

    /*
     * 🚨 **Il test che conta: due sorgenti non si sommano.**
     *
     * Health Connect può ricevere le calorie attive dall'orologio **e** dalla
     * stima sui passi del telefono. Sommandole, una camminata verrebbe contata
     * due volte — e il numero resterebbe plausibile.
     *
     * 💡 Si tiene la più alta: chi ha misurato di più è quasi sempre il
     * dispositivo indossato.
     */
    test('due sorgenti non si sommano: vince la più alta', () async {
      final oggi = DateTime(2026, 8, 19, 10);

      await archivio.scriviLetture([
        campione('watch', 300, oggi),
        campione('watch', 100, oggi.add(const Duration(hours: 1))),
        campione('telefono', 150, oggi),
      ]);

      expect(await archivio.kcalAttiveDi(oggi), 400);
    });

    test('un giorno senza campioni vale zero, non null', () async {
      expect(await archivio.kcalAttiveDi(DateTime(2026, 8, 19)), 0);
    });

    test('i campioni di ieri non finiscono in oggi', () async {
      await archivio.scriviLetture([
        campione('watch', 500, DateTime(2026, 8, 18, 12)),
      ]);

      expect(await archivio.kcalAttiveDi(DateTime(2026, 8, 19)), 0);
      expect(await archivio.kcalAttiveDi(DateTime(2026, 8, 18)), 500);
    });

    /// ⚠️ Rileggere la stessa finestra da Health Connect non deve raddoppiare
    /// niente: l'indice unico è `(fonte, metrica, misurataIl)`.
    test('rileggere la stessa finestra non raddoppia il totale', () async {
      final oggi = DateTime(2026, 8, 19, 10);

      for (var i = 0; i < 2; i++) {
        await archivio.scriviLetture([campione('watch', 200, oggi)]);
      }

      expect(await archivio.kcalAttiveDi(oggi), 200);
    });

    /// 🚨 Un valore assurdo si **scarta**: qui non sposta una media, sposta
    /// quanto qualcuno può mangiare.
    test('un campione implausibile non entra', () async {
      final oggi = DateTime(2026, 8, 19, 10);

      await archivio.scriviLetture([
        campione('watch', 200, oggi),
        campione('watch', 99999, oggi.add(const Duration(hours: 1))),
      ]);

      expect(await archivio.kcalAttiveDi(oggi), 200);
    });
  });
}
