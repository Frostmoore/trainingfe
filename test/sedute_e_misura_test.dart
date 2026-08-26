import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/health/bruciate_dalle_sedute.dart';
import 'package:training_companion/src/features/health/netto_o_lordo.dart';
import 'package:training_companion/src/features/profile/data/tdee_misurato.dart';

/// Le bruciate dalle sedute, il netto/lordo e il TDEE misurato — 3b-G.3/G.4/G.8.
void main() {
  AllenamentoDaOrologio seduta({
    int id = 1,
    String fonte = 'zepp',
    DateTime? inizio,
    int minuti = 60,
    int? kcal = 500,
    int? corrette,
    bool nascosto = false,
    bool staccato = false,
    bool extra = false,
  }) {
    final da = inizio ?? DateTime(2026, 8, 25, 17, 30);

    return AllenamentoDaOrologio(
      id: id,
      fonte: fonte,
      tipo: 'STRENGTH_TRAINING',
      iniziatoIl: da,
      finitoIl: da.add(Duration(minutes: minuti)),
      kcal: kcal,
      kcalCorrette: corrette,
      nascosto: nascosto,
      staccato: staccato,
      contaComeExtra: extra,
    );
  }

  group('⌚ le bruciate vengono dalle sedute — 3b-G.3', () {
    test('una seduta sola vale le sue calorie', () {
      expect(kcalDelleSedute([seduta(kcal: 580)]), 580);
    });

    test('due sedute diverse si sommano', () {
      expect(
        kcalDelleSedute([
          seduta(id: 1, inizio: DateTime(2026, 8, 25, 8), kcal: 300),
          seduta(id: 2, inizio: DateTime(2026, 8, 25, 18), kcal: 580),
        ]),
        880,
      );
    });

    /// 🚨 **Il difetto che questa regola chiude.** Chi si allena col telefono e
    /// l'orologio produce due registrazioni della stessa ora: sommarle
    /// raddoppierebbe la seduta, e il numero resterebbe plausibile.
    test(
      'ma due sorgenti sulla stessa ora NON si sommano: vince la più alta',
      () {
        final ora = DateTime(2026, 8, 25, 17, 30);

        expect(
          kcalDelleSedute([
            seduta(id: 1, fonte: 'zepp', inizio: ora, kcal: 580),
            seduta(id: 2, fonte: 'fit', inizio: ora, kcal: 520),
          ]),
          580,
        );
      },
    );

    test('e basta un istante di sovrapposizione', () {
      expect(
        kcalDelleSedute([
          seduta(
            id: 1,
            fonte: 'zepp',
            inizio: DateTime(2026, 8, 25, 17),
            minuti: 60,
            kcal: 500,
          ),
          seduta(
            id: 2,
            fonte: 'fit',
            inizio: DateTime(2026, 8, 25, 17, 59),
            minuti: 60,
            kcal: 400,
          ),
        ]),
        500,
      );
    });

    /// ⛔ `staccato` è il gesto con cui qualcuno ha detto «questo non si unisce
    /// a nessuno»: ignorarlo qui vorrebbe dire che funziona nello storico e non
    /// nel conto delle calorie.
    test('a meno che uno sia stato staccato a mano', () {
      final ora = DateTime(2026, 8, 25, 17, 30);

      expect(
        kcalDelleSedute([
          seduta(id: 1, fonte: 'zepp', inizio: ora, kcal: 580),
          seduta(id: 2, fonte: 'fit', inizio: ora, kcal: 520, staccato: true),
        ]),
        1100,
      );
    });

    test('le nascoste non contano: sono doppioni di sedute dell\'app', () {
      expect(kcalDelleSedute([seduta(kcal: 580, nascosto: true)]), 0);
    });

    test('la correzione a mano batte la misura', () {
      expect(kcalDelleSedute([seduta(kcal: 580, corrette: 400)]), 400);
    });

    /// ⚠️ Una seduta senza numero **non vale zero**: ha la sua strada, la stima
    /// dai MET. Contarla zero qui la farebbe sparire da tutte e due.
    test('e una seduta senza calorie non vale zero: esce e basta', () {
      expect(kcalDelleSedute([seduta(kcal: null)]), 0);
    });
  });

  group('🔬 netto o lordo — 3b-G.4', () {
    const bmr = 1880.0;

    /// ✅ **La certezza logica.** È il record vero dello Zepp del committente:
    /// 6 Cal in 11 minuti, dove il solo basale ne farebbe ~14.
    test('una finestra sotto il basale della sua durata è NETTA', () {
      final v = giudicaLaSorgente(
        finestre: [
          FinestraMisurata(
            inizio: DateTime(2026, 8, 25, 12),
            durata: const Duration(minutes: 11),
            kcal: 6,
          ),
        ],
        bmr: bmr,
      );

      expect(v.lettura, LetturaCalorie.netta);
      expect(v.motivo, contains('non può starci sotto'));
    });

    /// ✅ Il contrario: dormendo il netto è ~0, quindi un'ora che vale il basale
    /// di quell'ora è lorda. Rapporto 20 a 1: non è un indizio, è un urlo.
    test('una finestra notturna a ritmo basale è LORDA', () {
      final v = giudicaLaSorgente(
        finestre: [
          FinestraMisurata(
            inizio: DateTime(2026, 8, 25, 3),
            durata: const Duration(hours: 1),
            kcal: 78,
          ),
        ],
        bmr: bmr,
      );

      expect(v.lettura, LetturaCalorie.lorda);
    });

    /// ✅ I numeri veri: 2.290 − 580 = 1.710, cioè circa il basale.
    test('totale meno attive ≈ basale ⇒ le attive sono nette', () {
      final v = giudicaLaSorgente(
        finestre: const [],
        bmr: bmr,
        totaleDelGiorno: 2290,
        attiveDelGiorno: 580,
      );

      expect(v.lettura, LetturaCalorie.netta);
    });

    /// 🚨 **Il caso indecidibile esiste e va rappresentato.** Una sorgente che
    /// scrive un numero per allenamento e nient'altro non dà nessun appiglio.
    test('e senza prove si dice «non lo so», non si tira a indovinare', () {
      final v = giudicaLaSorgente(
        finestre: [
          FinestraMisurata(
            inizio: DateTime(2026, 8, 25, 18),
            durata: const Duration(hours: 1),
            kcal: 500,
          ),
        ],
        bmr: bmr,
      );

      expect(v.lettura, LetturaCalorie.nonSiSa);
    });

    test('una lorda si porta al netto togliendo il basale', () {
      expect(
        kcalNetteDellaSeduta(
          kcal: 600,
          durata: const Duration(hours: 1),
          bmr: bmr,
          lettura: LetturaCalorie.lorda,
        ),
        600 - (bmr / 24).round(),
      );
    });

    /// ⛔ Sottrarre «per sicurezza» vorrebbe dire togliere cibo a chi non ha
    /// fatto niente di sbagliato, sulla base di un sospetto.
    test('ma senza certezza non si tocca niente', () {
      for (final l in [LetturaCalorie.netta, LetturaCalorie.nonSiSa]) {
        expect(
          kcalNetteDellaSeduta(
            kcal: 600,
            durata: const Duration(hours: 1),
            bmr: bmr,
            lettura: l,
          ),
          600,
        );
      }
    });
  });

  group('📏 il TDEE misurato — 3b-G.8', () {
    List<DateTime> giorniDa(DateTime primo, int quanti) => [
      for (var i = 0; i < quanti; i++) primo.add(Duration(days: i)),
    ];

    test('è le assunte più il peso perso, spalmato sui giorni', () {
      final primo = DateTime(2026, 7, 1);

      final m = misuraIlTdee(
        giorni: giorniDa(primo, 31),
        assunte: List.filled(31, 1800),
        pesate: [
          Pesata(giorno: primo, kg: 98),
          Pesata(giorno: primo.add(const Duration(days: 30)), kg: 96),
        ],
      );

      expect(m.riuscita, isTrue);
      expect(m.giorni, 30);

      // 1.800 + 2 × 7.700 / 30 = 2.313
      expect(m.kcal, closeTo(2313, 1));
    });

    /// 🚨 Il ± si calcola, non si inventa: mezzo chilo di rumore su trenta
    /// giorni vale ~103 kcal al giorno.
    test('e dichiara la sua incertezza', () {
      final primo = DateTime(2026, 7, 1);

      final m = misuraIlTdee(
        giorni: giorniDa(primo, 31),
        assunte: List.filled(31, 1800),
        pesate: [
          Pesata(giorno: primo, kg: 98),
          Pesata(giorno: primo.add(const Duration(days: 30)), kg: 96),
        ],
      );

      expect(m.incertezza, closeTo(0.4 * 7700 / 30, 1));
    });

    /// ⛔ Sotto le quattro settimane il numero misurato è **peggio** della
    /// tabella: sembra preciso perché è specifico.
    test('sotto le quattro settimane non si misura', () {
      final primo = DateTime(2026, 8, 1);

      final m = misuraIlTdee(
        giorni: giorniDa(primo, 11),
        assunte: List.filled(11, 1800),
        pesate: [
          Pesata(giorno: primo, kg: 97.5),
          Pesata(giorno: primo.add(const Duration(days: 10)), kg: 96.6),
        ],
      );

      expect(m.riuscita, isFalse);
      expect(m.motivo, contains('rumore della bilancia'));
    });

    /// 🚨 Chi non segna non segna a caso: smette nei giorni in cui ha mangiato
    /// di più, quindi la media è più bassa del vero e la misura pure.
    test('e con troppi buchi nel diario nemmeno', () {
      final primo = DateTime(2026, 7, 1);

      final m = misuraIlTdee(
        giorni: giorniDa(primo, 31),
        assunte: [for (var i = 0; i < 31; i++) i.isEven ? 1800.0 : 0.0],
        pesate: [
          Pesata(giorno: primo, kg: 98),
          Pesata(giorno: primo.add(const Duration(days: 30)), kg: 96),
        ],
      );

      expect(m.riuscita, isFalse);
      expect(m.motivo, contains('buchi'));
    });

    test('senza due pesate non c\'è niente da misurare', () {
      final m = misuraIlTdee(
        giorni: giorniDa(DateTime(2026, 7, 1), 31),
        assunte: List.filled(31, 1800),
        pesate: [Pesata(giorno: DateTime(2026, 7, 1), kg: 98)],
      );

      expect(m.riuscita, isFalse);
      expect(m.motivo, contains('due pesate'));
    });

    /// ⚠️ Se il peso sale, il TDEE misurato scende sotto le assunte: hai
    /// mangiato più di quanto hai speso, ed è giusto che si veda.
    test(
      'e se il peso sale il numero scende sotto quello che hai mangiato',
      () {
        final primo = DateTime(2026, 7, 1);

        final m = misuraIlTdee(
          giorni: giorniDa(primo, 31),
          assunte: List.filled(31, 2500),
          pesate: [
            Pesata(giorno: primo, kg: 96),
            Pesata(giorno: primo.add(const Duration(days: 30)), kg: 97),
          ],
        );

        expect(m.kcal, lessThan(2500));
      },
    );
  });
}
