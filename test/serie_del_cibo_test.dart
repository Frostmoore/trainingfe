import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/diary/data/diario_locale.dart';
import 'package:training_companion/src/features/diary/data/serie_del_cibo.dart';

/// La serie delle calorie, costruita qui — Parte I, I2.5.
///
/// ══ 📌 GLI STESSI NUMERI DI `SeriesService::calories()` ══════════════════
///
/// 📌 Regola R2 della Parte I. ⛔ Un numero diverso qui non sarebbe un
/// dettaglio: il grafico e il diario mostrerebbero due totali per lo stesso
/// giorno, ed è già successo nell'app storica — è il motivo per cui quel
/// servizio esisteva.
///
/// ══ ⚠️ LE DATE SONO RELATIVE A OGGI, E DEVONO ═══════════════════════════
///
/// La finestra parte da «oggi» di chi guarda: fissare le date renderebbe il test
/// verde oggi e rosso domani. 💡 Si scrive rispetto a `DateTime.now()`, che è
/// esattamente il riferimento che usa il codice.
void main() {
  late ArchivioSalute archivio;
  late DiarioLocale diario;
  late SerieDelCibo serie;

  final adesso = DateTime.now();
  final oggi = DateTime(adesso.year, adesso.month, adesso.day);

  DateTime giorniFa(int n) => DateTime(oggi.year, oggi.month, oggi.day - n);

  setUp(() {
    archivio = ArchivioSalute.inMemoria();
    diario = DiarioLocale(archivio);
    serie = SerieDelCibo(archivio);
  });

  tearDown(() => archivio.close());

  Future<void> segna(DateTime giorno, double kcal, {double proteine = 0}) =>
      diario.aggiungi(
        giorno: giorno,
        pasto: 'lunch',
        descrizione: 'Qualcosa',
        kcal: kcal,
        proteine: proteine,
      );

  group('la finestra', () {
    test('sette giorni sono sette colonne, e l\'ultima è oggi', () async {
      final s = await serie.calorie(giorni: 7);

      expect(s.labels, hasLength(7));
      expect(s.dates.last, etichettaDelGiorno(oggi));
      expect(s.dates.first, etichettaDelGiorno(giorniFa(6)));
      expect(s.granularity, 'day');
    });

    test('🚨 l\'offset scorre di finestre INTERE, non di un giorno', () async {
      /*
       * 📌 Dal server: *«con 7 giorni, offset 1 è la settimana prima, non "un
       * giorno prima"»*. ⛔ Scorrere di un giorno alla volta farebbe ballare le
       * etichette a ogni tocco.
       */
      final s = await serie.calorie(giorni: 7, offset: 1);

      expect(s.dates.last, etichettaDelGiorno(giorniFa(7)));
      expect(s.dates.first, etichettaDelGiorno(giorniFa(13)));
    });

    test('⚠️ oltre i 92 giorni si aggrega per mese', () async {
      // 💡 Non è un limite tecnico: 400 barre su uno schermo di telefono sono
      // larghe mezzo pixel. Sopra i tre mesi la domanda cambia.
      expect((await serie.calorie(giorni: 90)).granularity, 'day');
      expect((await serie.calorie(giorni: 365)).granularity, 'month');
    });

    test('💡 `0` è tutto lo storico, e non si scorre indietro', () async {
      final s = await serie.calorie(giorni: 0);

      expect(s.granularity, 'month');
      expect(s.canGoBack, isFalse);
      expect(s.period, contains('tutto lo storico'));
    });
  });

  group('i numeri', () {
    test('le calorie di un giorno si sommano e si arrotondano', () async {
      await segna(oggi, 300.4);
      await segna(oggi, 300.4);

      final s = await serie.calorie(giorni: 7);

      // 🚨 Si somma e **poi** si arrotonda, come `sum()` seguito da `round()`:
      // 600,8 → 601. ⛔ Arrotondando voce per voce verrebbe 600.
      expect(s.consumed.last, 601);
    });

    test('un giorno senza voci vale zero, non sparisce', () async {
      await segna(oggi, 500);

      final s = await serie.calorie(giorni: 7);

      expect(s.consumed, hasLength(7));
      expect(s.consumed.first, 0);
      expect(s.consumed.last, 500);
    });

    test('🚨 le medie si fanno solo sui giorni CON dati', () async {
      /*
       * 📌 Dal server: *«dividere per 7 quando si è registrato 3 giorni su 7 non
       * dà "la media della settimana": dà un numero più basso, che fa credere di
       * essere in deficit»*.
       */
      await segna(oggi, 2000);
      await segna(giorniFa(1), 2200);

      final s = await serie.calorie(giorni: 7);

      expect(s.daysWithData, 2);
      expect(s.avgConsumed, 2100);
    });

    test('le proteine viaggiano, ma solo per giorno', () async {
      await segna(oggi, 500, proteine: 42);

      expect((await serie.calorie(giorni: 7)).protein.last, 42);

      // ⛔ Una media mensile di grammi non risponde a nessuna domanda.
      expect((await serie.calorie(giorni: 365)).protein, isEmpty);
    });

    test('⚠️ e le bruciate non ci sono: le sa solo il telefono', () async {
      // 🚨 Dalla FASE 11 il campo esce dalla risposta invece di valere zero: uno
      // zero afferma qualcosa di falso, l'assenza no.
      expect((await serie.calorie(giorni: 7)).burned, isEmpty);
      expect((await serie.calorie(giorni: 7)).avgBurned, 0);
    });
  });

  group('l\'aggregazione mensile', () {
    test('🚨 è una MEDIA giornaliera, non una somma', () async {
      /*
       * ⛔ Una somma mensile accanto a barre giornaliere sembra un'esplosione di
       * calorie, e confrontata con un target giornaliero non vuol dire niente.
       */
      await segna(oggi, 2000);
      await segna(giorniFa(1), 2400);

      final s = await serie.calorie(giorni: 365);

      // 💡 L'ultimo mese è quello in corso: 2000 e 2400 fanno 2200 di media,
      // **sui due giorni registrati** — non sui trenta del mese.
      expect(s.consumed.last, 2200);
    });

    test('e le colonne arrivano fino a oggi', () async {
      final s = await serie.calorie(giorni: 365);

      expect(s.dates.last, etichettaDelGiorno(DateTime(oggi.year, oggi.month)));
    });
  });
}
