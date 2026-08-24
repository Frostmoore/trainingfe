import 'package:flutter_test/flutter_test.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/features/training/costanza.dart';
import 'package:training_companion/src/features/training/data/storico_unificato.dart';

/// La costanza e «quanto sei allenato» — 3b-B.10, 24/08/2026.
///
/// ══ 🚨 COSA DIFENDE QUESTO FILE ═══════════════════════════════════════════
///
/// ⛔ Due formule che restituiscono **un numero solo**: se sbagliano, non danno
/// nessun errore — danno un numero diverso, e nessuno che lo guarda ha modo di
/// sapere che è sbagliato. ⚠️ È il caso peggiore fra quelli che questa
/// applicazione continua a incontrare, e l'unico modo di prenderlo è controllare
/// il conto contro casi di cui si sa già la risposta.
///
/// 💡 Il primo caso è **l'esempio del committente, parola per parola**: se la
/// formula non dà «alta costanza» lì, è sbagliata a prescindere da quanto sia
/// elegante.
void main() {
  /// Il lunedì di una settimana ben lontana da oggi, così tutte e quattro le
  /// settimane sono **finite** e nessun test dipende da che giorno è oggi.
  final primoLunedi = DateTime(2026, 6);
  final adesso = DateTime(2026, 7, 15);

  VoceStorico allenamento(DateTime quando, {int? kcal, int minuti = 60}) =>
      VoceStorico(
        sedute: const [],
        dalPolso: [
          AllenamentoDaOrologio(
            id: quando.millisecondsSinceEpoch ~/ 1000,
            fonte: 'test',
            tipo: 'STRENGTH_TRAINING',
            iniziatoIl: quando,
            finitoIl: quando.add(Duration(minutes: minuti)),
            kcal: kcal,
            distanzaMetri: null,
            nascosto: false,
            staccato: false,
          ),
        ],
      );

  /// Le sedute di [settimane] settimane, nei [giorni] indicati (1 = lunedì).
  List<VoceStorico> schema(int settimane, List<int> giorni, {int? kcal}) => [
    for (var w = 0; w < settimane; w++)
      for (final g in giorni)
        allenamento(
          primoLunedi.add(Duration(days: w * 7 + g - 1, hours: 18)),
          kcal: kcal,
        ),
  ];

  Costanza calcola(List<VoceStorico> voci) =>
      costanzaDelMese(voci: voci, mese: DateTime(2026, 6), adesso: adesso);

  group('La costanza', () {
    /// ══ 📌 L'ESEMPIO DEL COMMITTENTE, ALLA LETTERA ══════════════════════════
    ///
    /// *«tre allenamenti a settimana per 4 settimane, tutti di lunedì, mercoledì
    /// e venerdì = alta costanza»*.
    ///
    /// 🚨 **È il test che decide se la formula vale qualcosa.** Ed è anche
    /// quello che scarta la misura ovvia: «quanto le sedute si addensano su
    /// pochi giorni» direbbe *poco costante* proprio qui, perché lunedì,
    /// mercoledì e venerdì sono tre giorni sparsi.
    test('tre volte a settimana sempre negli stessi giorni è il massimo', () {
      final c = calcola(schema(4, [1, 3, 5]));

      expect(c.settimane, 4);
      expect(c.sedute, 12);
      expect(c.siPuoDire, isTrue);
      expect(c.percentuale, 100);
    });

    /// ⚠️ *«variazioni ampie dei giorni in cui mi sono allenato = bassa
    /// costanza»*: stesso numero di sedute, stessa frequenza, giorni sempre
    /// diversi.
    ///
    /// 💡 La frequenza resta piena e il numero pure: quello che crolla è **solo**
    /// il pezzo dei giorni — che è esattamente quello che deve succedere, o il
    /// punteggio non starebbe misurando quello che dice.
    test('stessa frequenza ma giorni sempre diversi vale meno', () {
      final sparso = [
        ...schema(1, [1, 3, 5]),
        ...[
          for (final g in [2, 4, 6])
            allenamento(primoLunedi.add(Duration(days: 7 + g - 1, hours: 18))),
        ],
        ...[
          for (final g in [1, 6, 7])
            allenamento(primoLunedi.add(Duration(days: 14 + g - 1, hours: 18))),
        ],
        ...[
          for (final g in [3, 4, 7])
            allenamento(primoLunedi.add(Duration(days: 21 + g - 1, hours: 18))),
        ],
      ];

      final c = calcola(sparso);

      expect(c.sedute, 12);
      expect(c.frequenza, 1.0, reason: 'La frequenza non c entra.');
      expect(c.regolaritaNumero, 1.0, reason: 'Il numero è sempre tre.');
      expect(c.regolaritaGiorni, lessThan(0.4));
      expect(
        c.percentuale,
        lessThan(calcola(schema(4, [1, 3, 5])).percentuale),
      );
    });

    /// ⚠️ *«differenze nel numero di sessioni tra una settimana e l'altra …
    /// = bassa costanza»*.
    test('settimane molto diverse fra loro valgono meno', () {
      final ballerino = [
        ...schema(1, [1, 3, 5]),
        ...schema(1, const []),
        ...[
          for (final g in [1, 2, 3, 4, 5])
            allenamento(primoLunedi.add(Duration(days: 14 + g - 1, hours: 18))),
        ],
        ...[allenamento(primoLunedi.add(const Duration(days: 21, hours: 18)))],
      ];

      final c = calcola(ballerino);

      expect(c.sedute, 9);
      expect(c.regolaritaNumero, lessThan(0.5));
    });

    /// ⛔ **Con meno di due settimane finite non si dice niente.**
    ///
    /// 🚨 Il coefficiente di variazione di **un** numero è zero, cioè
    /// «regolarità perfetta»: senza questa guardia il 2 del mese la card
    /// scriverebbe un punteggio altissimo basato su nulla. È il difetto di
    /// sempre — un numero che sembra informato.
    test('a inizio mese tace invece di inventare', () {
      final c = costanzaDelMese(
        voci: schema(1, [1, 3, 5]),
        mese: DateTime(2026, 6),
        adesso: DateTime(2026, 6, 9),
      );

      expect(c.siPuoDire, isFalse);
    });

    /// 💡 Chi non si allena non è costante — per quanto regolarmente non lo
    /// faccia. ⛔ Due settimane vuote di fila non devono valere «regolarità
    /// perfetta dei giorni»: sarebbe una presa in giro.
    test('non allenarsi con regolarità non è costanza', () {
      final c = calcola(const []);

      expect(c.percentuale, 0);
      expect(c.regolaritaGiorni, 0);
    });
  });

  group('Quanto sei allenato', () {
    /// 🚨 **Senza calorie non si inventa niente.** Non c'è nessun dato da cui
    /// dedurle senza sceglierne il valore noi, e un carico inventato falserebbe
    /// il numero per settimane — la media è a sei settimane, quindi un errore ci
    /// resta dentro a lungo.
    test('un allenamento senza calorie non conta', () {
      expect(
        quantoSeiAllenato(
          voci: [allenamento(adesso.subtract(const Duration(days: 1)))],
          adesso: adesso,
        ),
        0,
      );
    });

    test('senza niente è zero', () {
      expect(quantoSeiAllenato(voci: const [], adesso: adesso), 0);
    });

    /// ══ 💡 LA FORMULA, CONTROLLATA A MANO ═══════════════════════════════════
    ///
    /// `F = L · (1 − (1−α)^n)` per un carico costante `L` ripetuto `n` giorni.
    /// Con 500 kcal al giorno — cioè `L = 50` punti — per 42 giorni:
    /// `50 · (1 − 0,953488^42) ≈ 50 · 0,865 ≈ 43`.
    ///
    /// ⚠️ Il numero non è tondo di proposito: se qualcuno cambia `α` o il numero
    /// di giorni «per provare», questo test lo dice subito.
    test('sei settimane di 500 kcal al giorno danno 43', () {
      final voci = [
        for (var g = 0; g < giorniDellaForma; g++)
          allenamento(
            adesso.subtract(Duration(days: g)).copyWith(hour: 18),
            kcal: 500,
          ),
      ];

      expect(quantoSeiAllenato(voci: voci, adesso: adesso), 43);
    });

    /// ══ 🚨 IL TEST CHE DIMOSTRA CHE «DA QUANTO» CONTA DAVVERO ═══════════════
    ///
    /// 📌 *«da quanto mi alleno con una certa costanza e quanti allenamenti ho
    /// effettivamente fatto»*.
    ///
    /// 💡 Le stesse identiche calorie: una volta spalmate su sei settimane, una
    /// volta tutte in un giorno solo e sei settimane fa. ⛔ Un totale semplice
    /// darebbe lo stesso numero, ed è esattamente il motivo per cui non si usa
    /// un totale.
    test('le stesse calorie spalmate valgono più che in un giorno solo', () {
      final costante = [
        for (var g = 0; g < giorniDellaForma; g++)
          allenamento(
            adesso.subtract(Duration(days: g)).copyWith(hour: 18),
            kcal: 500,
          ),
      ];

      final tuttoSubito = [
        allenamento(
          adesso
              .subtract(const Duration(days: giorniDellaForma - 1))
              .copyWith(hour: 18),
          kcal: 500 * giorniDellaForma,
        ),
      ];

      expect(
        quantoSeiAllenato(voci: costante, adesso: adesso),
        greaterThan(quantoSeiAllenato(voci: tuttoSubito, adesso: adesso)),
      );
    });

    /// ⚠️ **E scende quando ti fermi.** Chi si è allenato per un mese e poi ha
    /// smesso da tre settimane deve valere meno di chi non ha smesso: è il
    /// senso stesso di una media *esponenziale*.
    test('e scende quando smetti', () {
      List<VoceStorico> da(int giorniFa, int quanti) => [
        for (var g = 0; g < quanti; g++)
          allenamento(
            adesso.subtract(Duration(days: giorniFa + g)).copyWith(hour: 18),
            kcal: 500,
          ),
      ];

      final ancoraInPista = da(0, 28);
      final fermoDaTreSettimane = da(21, 28);

      expect(
        quantoSeiAllenato(voci: ancoraInPista, adesso: adesso),
        greaterThan(
          quantoSeiAllenato(voci: fermoDaTreSettimane, adesso: adesso),
        ),
      );
    });

    /// ══ 🚨 UN NUMERO NUDO NON È UN'INFORMAZIONE — B.13 ═════════════════════
    ///
    /// 📌 Il committente, guardando «8» a schermo: *«8 non significa un cazzo …
    /// è come dire "di che colore è il cielo?" "42"»*.
    ///
    /// 💡 Il paragone è **quante sedute come le tue** tengono quel valore, ed è
    /// la formula rovesciata: `sedute = valore × 7 × 10 / kcal per seduta`.
    /// Sei settimane a 500 kcal al giorno danno 43, e 43 × 70 / 500 ≈ 6: cioè
    /// **sei sedute a settimana**, che è esattamente quello che si sta facendo.
    test('il paragone dice quante sedute a settimana valgono quel numero', () {
      final voci = [
        for (var g = 0; g < giorniDellaForma; g++)
          allenamento(
            adesso.subtract(Duration(days: g)).copyWith(hour: 18),
            kcal: 500,
          ),
      ];

      final f = laForma(voci: voci, adesso: adesso);

      expect(f.valore, 43);
      expect(f.kcalMediaPerSeduta, 500);
      expect(f.seduteASettimana, closeTo(6, 0.3));
    });

    /// ⛔ **Con le TUE calorie, non con una seduta tipo inventata.** Chi fa
    /// sedute da mille kcal si allena **la metà delle volte** di chi le fa da
    /// cinquecento, a parità di valore: un paragone su una media fissa gli
    /// direbbe il doppio, ed è proprio il numero che sta cercando di capire.
    test('e usa le calorie vere, non una seduta media inventata', () {
      List<VoceStorico> ogniDue(int kcal) => [
        for (var g = 0; g < giorniDellaForma; g += 2)
          allenamento(
            adesso.subtract(Duration(days: g)).copyWith(hour: 18),
            kcal: kcal,
          ),
      ];

      final leggere = laForma(voci: ogniDue(500), adesso: adesso);
      final pesanti = laForma(voci: ogniDue(1000), adesso: adesso);

      expect(pesanti.valore, greaterThan(leggere.valore));

      // 💡 Stesso numero di sedute: il paragone deve dire la stessa cosa.
      expect(pesanti.seduteASettimana, closeTo(leggere.seduteASettimana!, 0.2));
    });

    /// ⛔ **Senza calorie il paragone non si fa**, e non si inventa una seduta
    /// media per poter scrivere una frase: sarebbe un paragone con una persona
    /// che non esiste. La fascia resta, ed è vera lo stesso.
    test('senza calorie resta la fascia e sparisce il paragone', () {
      final f = laForma(
        voci: [allenamento(adesso.subtract(const Duration(days: 1)))],
        adesso: adesso,
      );

      expect(f.kcalMediaPerSeduta, isNull);
      expect(f.seduteASettimana, isNull);
      expect(f.fascia, FasciaDellaForma.poco);
    });

    /// ⚠️ Le fasce non si sovrappongono e non lasciano buchi: un valore
    /// qualunque cade in **una** sola.
    test('le fasce coprono tutto senza buchi', () {
      expect(FasciaDellaForma.di(0), FasciaDellaForma.poco);
      expect(FasciaDellaForma.di(9), FasciaDellaForma.poco);
      expect(FasciaDellaForma.di(10), FasciaDellaForma.costante);
      expect(FasciaDellaForma.di(24), FasciaDellaForma.costante);
      expect(FasciaDellaForma.di(25), FasciaDellaForma.allenato);
      expect(FasciaDellaForma.di(44), FasciaDellaForma.allenato);
      expect(FasciaDellaForma.di(45), FasciaDellaForma.atleta);
      expect(FasciaDellaForma.di(500), FasciaDellaForma.atleta);
    });

    /// ⛔ E la barra non esce mai dal suo binario, nemmeno per un maratoneta.
    test('la barra si ferma a piena', () {
      expect(const Forma(valore: 500, kcalMediaPerSeduta: 500).frazione, 1.0);
      expect(const Forma(valore: 0, kcalMediaPerSeduta: null).frazione, 0.0);
    });

    /// ⛔ Quello che è successo **prima** delle sei settimane non entra: è la
    /// finestra della formula, e allargarla di nascosto vorrebbe dire un numero
    /// che dice «allenato» a chi non tocca un bilanciere da mesi.
    test('quello di tre mesi fa non conta più', () {
      expect(
        quantoSeiAllenato(
          voci: [
            allenamento(adesso.subtract(const Duration(days: 90)), kcal: 5000),
          ],
          adesso: adesso,
        ),
        0,
      );
    });
  });
}
