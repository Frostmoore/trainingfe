import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/diary/data/cibo_per_il_consiglio.dart';
import 'package:training_companion/src/features/diary/data/diario_locale.dart';
import 'package:training_companion/src/features/health/health_controller.dart';

/// Il cibo che viaggia col consiglio — Parte I, I5.2.
///
/// ══ 📌 GLI STESSI NUMERI DI `ContestoDelConsiglioTest` ═══════════════════
///
/// 📌 Regola R2 della Parte I: *«i test del server che coprivano quei calcoli
/// diventano test Dart, **con gli stessi numeri**»*. Questi venivano da
/// `laSettimanaDelCibo()`, e sono stati **copiati**:
///
/// | Caso | Numeri |
/// |---|---|
/// | La cena scritta al mattino | 700 kcal / 50 p, `scritto_alle` **10:05** |
/// | Il pasto scritto a pezzi | 600 + 150 = **750**, `scritto_alle` **21:40** |
/// | La settimana | **2200** e **1800**, oggi **700** e fuori dalla settimana |
/// | Oltre la finestra | il 10 agosto non si guarda |
///
/// ⛔ Un test scritto guardando il codice nuovo prova che il codice nuovo fa
/// quello che fa, non che fa quello che faceva l'altro.
void main() {
  late ArchivioSalute archivio;
  late DiarioLocale diario;

  setUp(() {
    archivio = ArchivioSalute.inMemoria();
    diario = DiarioLocale(archivio);
  });

  tearDown(() => archivio.close());

  /// ⚠️ Si scrive **dall'archivio e non da `aggiungi()`**, perché `scrittaIl`
  /// vale `currentDateAndTime` e qui l'ora è proprio la cosa da provare.
  Future<void> segna(
    DateTime giorno,
    String pasto,
    double kcal, {
    double proteine = 0,
    DateTime? scrittaIl,
  }) => archivio.scriviVoceDiario(
    VociDiarioCompanion.insert(
      mangiatoIl: DateTime(giorno.year, giorno.month, giorno.day),
      pasto: pasto,
      descrizione: 'Qualcosa',
      kcal: Value(kcal),
      proteine: Value(proteine),
      scrittaIl: Value(scrittaIl ?? giorno),
    ),
  );

  group('🕘 i pasti, con l\'ora in cui sono stati scritti', () {
    test('🎯 il caso del committente: alle 10:20 la cena è già scritta', () async {
      /*
       * 📌 *«se oggi ho già segnato tutto quello che mangerò alle 10 di mattina
       * il consiglio del giorno mi dice che ho già assunto 1800 kcal e sono solo
       * le 10... è ovvio che non può essere così»*.
       *
       * 🚨 Senza `scritto_alle`, una cena scritta alle 10 del mattino è identica
       * a una cena mangiata: il consiglio non è generico, è **falso**.
       */
      final oggi = DateTime(2026, 8, 31);
      final alle1005 = DateTime(2026, 8, 31, 10, 5);

      await segna(oggi, 'breakfast', 400, proteine: 20, scrittaIl: alle1005);
      await segna(oggi, 'lunch', 700, proteine: 45, scrittaIl: alle1005);
      await segna(oggi, 'dinner', 700, proteine: 50, scrittaIl: alle1005);

      final pasti = {
        for (final p in await diario.pastiScrittiDel(oggi)) p.pasto: p,
      };

      expect(pasti['dinner']!.kcal, 700);
      expect(pasti['dinner']!.proteine, 50);
      expect(pasti['dinner']!.scrittaIl, alle1005);
      expect(pasti['breakfast']!.scrittaIl, alle1005);
    });

    test('⚠️ di un pasto scritto a pezzi vale l\'ora dell\'ULTIMO', () async {
      /*
       * 💡 Chi aggiunge il pane alla cena alle 21:40 sta ancora cenando:
       * prendere la prima voce direbbe che quella cena è vecchia di un'ora.
       */
      final oggi = DateTime(2026, 8, 31);

      await segna(oggi, 'dinner', 600, scrittaIl: DateTime(2026, 8, 31, 20, 30));
      await segna(oggi, 'dinner', 150, scrittaIl: DateTime(2026, 8, 31, 21, 40));

      final cena = (await diario.pastiScrittiDel(oggi)).single;

      expect(cena.kcal, 750);
      expect(cena.scrittaIl, DateTime(2026, 8, 31, 21, 40));
    });

    test('⛔ i pasti vuoti non entrano: una riga a zero non è informazione', () async {
      final oggi = DateTime(2026, 8, 31);

      await segna(oggi, 'lunch', 700);

      final pasti = await diario.pastiScrittiDel(oggi);

      expect(pasti, hasLength(1));
      expect(pasti.single.pasto, 'lunch');
    });

    test('💡 e restano nell\'ordine della giornata', () async {
      final oggi = DateTime(2026, 8, 31);

      // ⚠️ Scritti al contrario di proposito: l'ordine deve venire dai pasti,
      // non da quando sono stati registrati.
      await segna(oggi, 'dinner', 700);
      await segna(oggi, 'breakfast', 400);

      final pasti = await diario.pastiScrittiDel(oggi);

      expect(pasti.map((p) => p.pasto).toList(), ['breakfast', 'dinner']);
    });
  });

  group('📅 la settimana, e cosa NON ci finisce', () {
    /*
     * 🚨 Il payload si costruisce su «oggi» vero, quindi le date sono relative:
     * fissarle renderebbe il test verde oggi e rosso domani.
     */
    final adesso = DateTime.now();
    final oggi = DateTime(adesso.year, adesso.month, adesso.day);

    DateTime giorniFa(int n) => DateTime(oggi.year, oggi.month, oggi.day - n);

    Future<CiboPerIlConsiglio> costruisci() {
      final contenitore = ProviderContainer(
        overrides: [archivioSaluteProvider.overrideWithValue(archivio)],
      );

      addTearDown(contenitore.dispose);

      return contenitore.read(ciboPerIlConsiglioProvider.future);
    }

    test('⛔ oggi NON entra nella settimana: è già in totals e in meals', () async {
      /*
       * Ripeterlo darebbe al modello due versioni della stessa giornata — una
       * completa e una da confrontare con le altre — e il confronto «oggi contro
       * la settimana» perderebbe senso perché oggi starebbe da tutt'e due le
       * parti.
       */
      await segna(giorniFa(2), 'lunch', 1800, proteine: 90);
      await segna(giorniFa(1), 'lunch', 2200, proteine: 110);
      await segna(oggi, 'lunch', 700, proteine: 45);

      final cibo = await costruisci();

      expect(
        cibo.settimana.map((g) => g['kcal']).toList(),
        [2200, 1800],
        reason: 'La settimana deve escludere oggi ed essere dal più recente.',
      );

      // 💡 E oggi resta dov'era.
      expect(cibo.totali.kcal, 700);
      expect(cibo.pasti.single['kcal'], 700);
    });

    test('⛔ più indietro della finestra non si guarda', () async {
      await segna(giorniFa(21), 'lunch', 3000);
      await segna(giorniFa(1), 'lunch', 2200);

      final cibo = await costruisci();

      expect(cibo.settimana, hasLength(1));
      expect(cibo.settimana.single['kcal'], 2200);
    });

    test('💡 un giorno senza voci non si manda, invece di valere zero', () async {
      /*
       * ⛔ Uno zero direbbe «a digiuno» a chi ha solo saltato il diario, ed è la
       * stessa ragione per cui le medie di `SerieDelCibo` saltano i giorni
       * vuoti.
       */
      await segna(giorniFa(3), 'lunch', 2000);

      final cibo = await costruisci();

      expect(cibo.settimana, hasLength(1));
    });
  });

  group('📦 il payload, con i nomi della lista bianca del server', () {
    final adesso = DateTime.now();
    final oggi = DateTime(adesso.year, adesso.month, adesso.day);

    Future<Map<String, Object>> payload() async {
      final contenitore = ProviderContainer(
        overrides: [archivioSaluteProvider.overrideWithValue(archivio)],
      );

      addTearDown(contenitore.dispose);

      return (await contenitore.read(ciboPerIlConsiglioProvider.future)).payload;
    }

    test('🚨 i totali si mandano SEMPRE, anche a zero', () async {
      /*
       * ⛔ `totals` è dentro l'hash della cache: ometterlo a zero vorrebbe dire
       * che la **prima** registrazione della giornata non cambia l'hash, e il
       * consiglio delle 9 resterebbe identico dopo colazione.
       */
      final vuoto = await payload();

      expect(vuoto['eaten_kcal'], 0.0);
      expect(vuoto.containsKey('meals'), isFalse);
      expect(vuoto.containsKey('week_food'), isFalse);
    });

    test('e con del cibo dentro portano i nomi giusti', () async {
      await segna(oggi, 'lunch', 700, proteine: 45);

      final p = await payload();

      expect(p['eaten_kcal'], 700);
      expect(p['eaten_protein_g'], 45);
      expect(p.containsKey('eaten_carbs_g'), isTrue);
      expect(p.containsKey('eaten_fat_g'), isTrue);

      final pasti = p['meals']! as List<Map<String, Object>>;

      expect(pasti.single.keys, containsAll(['meal', 'kcal', 'p', 'c', 'f', 'scritto_alle']));
    });

    test('⚠️ i numeri partono interi, arrotondati e non troncati', () async {
      // 💡 279,6 kcal sono 280, non 279: un decimale nel prompt è un carattere
      // pagato per una precisione che nessuno usa, ma il troncamento è un errore.
      await segna(oggi, 'lunch', 279.6);

      final pasti = (await payload())['meals']! as List<Map<String, Object>>;

      expect(pasti.single['kcal'], 280);
    });

    test('🕘 e `scritto_alle` è l\'ora locale, con lo zero davanti', () async {
      await segna(oggi, 'breakfast', 400, scrittaIl: DateTime(
        oggi.year,
        oggi.month,
        oggi.day,
        8,
        5,
      ));

      final pasti = (await payload())['meals']! as List<Map<String, Object>>;

      expect(pasti.single['scritto_alle'], '08:05');
    });
  });
}
