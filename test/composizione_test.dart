import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/dashboard/composizione.dart';

/// 🎯 Cosa si può concludere dalla composizione — 3b-Y.
///
/// ══ 🚨 LA CONCLUSIONE CHE VALE ═══════════════════════════════════════════
///
/// Non «quanto peso», che lo dice già la scheda del peso: **cosa** ho perso.
/// ⛔ Due chili di grasso e due chili di muscolo pesano uguale sulla bilancia e
/// sono l'opposto l'uno dell'altro.
///
/// ══ ⛔ E QUANDO NON SI PUO' CONCLUDERE, NON SI CONCLUDE ══════════════════
///
/// Una bilancia a bioimpedenza sbaglia di qualche punto, e su 95 kg **un punto
/// è quasi un chilo**. ⚠️ Un confronto fra ieri e oggi non misura il corpo:
/// misura l'idratazione.
void main() {
  final oggi = DateTime(2026, 8, 30);

  MisuraCorpo m(int giorniFa, {double? kg, double? pct, double? magra}) =>
      MisuraCorpo(
        id: 0,
        giorno: oggi.subtract(Duration(days: giorniFa)),
        pesoKg: kg,
        massaGrassaPct: pct,
        massaMagraKg: magra,
      );

  /// Uno storico con peso e grasso costanti in una finestra.
  List<MisuraCorpo> finestra(int centro, double kg, double pct) => [
    for (var i = centro - 2; i <= centro + 2; i++)
      if (i >= 0) m(i, kg: kg, pct: pct),
  ];

  group('⛔ quando non si dice niente', () {
    test('senza storico', () {
      expect(leggiLaComposizione(storico: const [], adesso: oggi), isNull);
    });

    /// 🚨 Il peso da solo non basta: senza la percentuale non c'è nessuna
    /// composizione da mostrare, e la card sparisce.
    test('con il peso ma senza massa grassa', () {
      expect(
        leggiLaComposizione(storico: [m(0, kg: 95.9)], adesso: oggi),
        isNull,
      );
    });

    /// ⛔ Una percentuale a zero è una misura fallita, non «zero grasso».
    test('con una percentuale impossibile', () {
      for (final pct in [0.0, 1.0, 80.0]) {
        expect(
          leggiLaComposizione(
            storico: [m(0, kg: 95.9, pct: pct)],
            adesso: oggi,
          ),
          isNull,
          reason: '$pct% è passata come se fosse una misura vera.',
        );
      }
    });
  });

  group('📸 la fotografia di adesso', () {
    test('grasso e magra in chili', () {
      final l = leggiLaComposizione(
        storico: [m(0, kg: 100, pct: 25)],
        adesso: oggi,
      )!;

      expect(l.adesso.grassoKg, 25.0);
      expect(l.adesso.magraKg, 75.0);
      expect(l.adesso.grassoPct, 25.0);
    });

    /// 💡 **La massa magra misurata batte quella derivata**, come nel BMR: non
    /// eredita l'errore della bioimpedenza.
    test('la massa magra misurata vince sulla percentuale', () {
      final l = leggiLaComposizione(
        storico: [m(0, kg: 100, pct: 40, magra: 75)],
        adesso: oggi,
      )!;

      expect(l.adesso.magraKg, 75.0);
      expect(l.adesso.grassoKg, 25.0);
    });

    /// 🚨 **Peso e grasso si mediano separatamente.** Chi si pesa ogni giorno e
    /// misura il grasso una volta a settimana non ha righe con tutti e due i
    /// valori: pretenderle butterebbe via quasi tutto lo storico.
    test('peso e grasso possono venire da giorni diversi', () {
      final l = leggiLaComposizione(
        storico: [m(0, kg: 100), m(3, pct: 25)],
        adesso: oggi,
      );

      expect(l, isNotNull);
      expect(l!.adesso.pesoKg, 100.0);
      expect(l.adesso.grassoKg, 25.0);
    });

    /// ⚠️ Il rumore della singola pesata si media: 96,15 alle 17:48 e 95,85
    /// alle 18:08 dello stesso giorno sono trecento grammi che non sono grasso.
    test('più pesate nella finestra si mediano', () {
      final l = leggiLaComposizione(
        storico: [m(0, kg: 96), m(1, kg: 94), m(2, pct: 25)],
        adesso: oggi,
      )!;

      expect(l.adesso.pesoKg, 95.0);
    });
  });

  group('⏳ senza abbastanza storia non si conclude', () {
    /// 🚨 **Ventuno giorni, e non sette.** Il grasso si muove di poche
    /// centinaia di grammi a settimana: su una settimana la differenza vera è
    /// più piccola dell'errore della bilancia.
    test('due settimane non bastano', () {
      final l = leggiLaComposizione(
        storico: [...finestra(0, 95, 25), ...finestra(14, 97, 27)],
        adesso: oggi,
      )!;

      expect(l.prima, isNull);
      expect(l.verdetto, isNull);

      // 💡 Ma la fotografia di adesso c'è: è già un dato vero.
      expect(l.adesso.pesoKg, 95.0);
    });

    test('tre settimane sì', () {
      final l = leggiLaComposizione(
        storico: [...finestra(0, 95, 25), ...finestra(21, 97, 27)],
        adesso: oggi,
      )!;

      expect(l.prima, isNotNull);
      expect(l.verdetto, isNotNull);
      expect(l.giorni, 21);
    });
  });

  group('🎯 il verdetto', () {
    LetturaDellaComposizione fra({
      required double kgPrima,
      required double pctPrima,
      required double kgOra,
      required double pctOra,
    }) => leggiLaComposizione(
      storico: [
        ...finestra(0, kgOra, pctOra),
        ...finestra(21, kgPrima, pctPrima),
      ],
      adesso: oggi,
    )!;

    /// 🎯 Il risultato che si cerca: −2,5 kg, quasi tutto grasso.
    test('grasso giù e muscolo tenuto', () {
      final l = fra(kgPrima: 100, pctPrima: 28, kgOra: 97.5, pctOra: 25.6);

      expect(l.verdetto, Verdetto.grassoGiuMuscoloTenuto);
      expect(l.deltaGrassoKg!, lessThan(-1));
      expect(l.deltaMagraKg!.abs(), lessThan(sogliaKg));
    });

    /// ⚠️ Lo stesso calo di peso, ma se ne va anche il muscolo. 🚨 **Sulla
    /// bilancia è identico al caso di sopra**: è l'unica cosa che questa card
    /// aggiunge, ed è il motivo per cui esiste.
    test('giù anche il muscolo', () {
      final l = fra(kgPrima: 100, pctPrima: 28, kgOra: 97.5, pctOra: 27.4);

      expect(l.verdetto, Verdetto.giuAncheIlMuscolo);
      expect(l.deltaMagraKg!, lessThan(-sogliaKg));
    });

    test('su, e soprattutto muscolo', () {
      final l = fra(kgPrima: 90, pctPrima: 20, kgOra: 93, pctOra: 19.5);

      expect(l.verdetto, Verdetto.suSoprattuttoMuscolo);
    });

    test('su, e soprattutto grasso', () {
      final l = fra(kgPrima: 90, pctPrima: 20, kgOra: 93, pctOra: 24);

      expect(l.verdetto, Verdetto.suSoprattuttoGrasso);
    });

    /// 💡 **Il caso più interessante, e sulla bilancia non si vede affatto**:
    /// peso identico, grasso giù e muscolo su.
    test('peso fermo, ma il corpo è cambiato', () {
      final l = fra(kgPrima: 95, pctPrima: 27, kgOra: 95, pctOra: 24.5);

      expect(l.deltaPesoKg!.abs(), lessThan(0.01));
      expect(
        l.verdetto,
        Verdetto.grassoGiuMuscoloTenuto,
        reason:
            'Il peso non si è mosso e la composizione sì: è la conclusione '
            'che il peso da solo non può dare.',
      );
    });

    /// ⛔ Sotto la soglia del rumore non si conclude niente — e «fermo» vuol
    /// dire «non lo so ancora», non «non stai facendo niente».
    test('un cambiamento più piccolo del rumore è «fermo»', () {
      final l = fra(kgPrima: 95, pctPrima: 25, kgOra: 94.8, pctOra: 24.9);

      expect(l.verdetto, Verdetto.fermo);
      expect(l.deltaGrassoKg!.abs(), lessThan(sogliaKg));
    });
  });
}
