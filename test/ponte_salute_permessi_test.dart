import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:training_companion/src/features/health/ponte_salute.dart';

/// Quello che chiediamo e quello che leggiamo — FASE 1.8, 19/08/2026.
///
/// ── 🚨 Cosa difende questo file ────────────────────────────────────────────
///
/// `PonteSalute` tiene **due** elenchi di tipi, e la differenza fra i due non e'
/// una svista: e' la difesa contro il doppio conteggio del metabolismo basale.
///
/// | Elenco | A cosa serve |
/// |---|---|
/// | `tipiDaAutorizzare` | cosa compare nella schermata del consenso |
/// | `tipiDaLeggere` | cosa chiediamo davvero a Health Connect |
///
/// ⚠️ Il giorno in cui qualcuno «semplifica» unendo i due elenchi, questi test
/// diventano rossi. E' esattamente il loro mestiere: la semplificazione sembra
/// giusta, e costa +1.600 kcal al giorno con un numero che resta plausibile.
void main() {
  group('I permessi degli allenamenti', () {
    /// 🚨 Il difetto vero del 19/08: i tre permessi erano nel manifest ma
    /// **nessuno li chiedeva**, perche' il pacchetto costruisce l'elenco dai
    /// tipi e `WORKOUT` traduce nel solo `READ_EXERCISE`. Risultato:
    /// `granted=false` per sempre, e `SecurityException` a ogni lettura.
    test('si chiedono i tre tipi che il pacchetto pretende', () {
      expect(
        PonteSalute.tipiDaAutorizzare,
        contains(HealthDataType.DISTANCE_DELTA),
      );
      expect(PonteSalute.tipiDaAutorizzare, contains(HealthDataType.STEPS));
      expect(
        PonteSalute.tipiDaAutorizzare,
        contains(HealthDataType.TOTAL_CALORIES_BURNED),
      );
    });

    test('e ovviamente anche gli allenamenti', () {
      expect(PonteSalute.tipiDaAutorizzare, contains(HealthDataType.WORKOUT));
    });
  });

  group('La regola non negoziabile', () {
    /// ══ 🚨 Il test che conta piu' di tutti ═══════════════════════════════
    ///
    /// `TOTAL_CALORIES_BURNED` comprende il **metabolismo basale**. Lo chiediamo
    /// solo perche' il pacchetto lo legge da se', dentro l'intervallo di una
    /// singola sessione, per riempirne le calorie.
    ///
    /// ⚠️ Leggerlo per la **giornata** lo sommerebbe a un obiettivo che e' gia'
    /// un TDEE — il basale ce l'ha dentro — contandolo due volte.
    test('le calorie TOTALI non si leggono mai per la giornata', () {
      expect(
        PonteSalute.tipiDaLeggere,
        isNot(contains(HealthDataType.TOTAL_CALORIES_BURNED)),
        reason:
            'Comprende il metabolismo basale: per la giornata vale solo '
            'ACTIVE_ENERGY_BURNED, o si contano due volte ~1.600 kcal.',
      );
    });

    test('per la giornata vale ACTIVE_ENERGY_BURNED', () {
      expect(
        PonteSalute.tipiDaLeggere,
        contains(HealthDataType.ACTIVE_ENERGY_BURNED),
      );
    });

    /// 💡 Passi e distanza sono il dato buono **di una corsa**, non della
    /// giornata: li lascia il pacchetto dentro la sessione. Chiederli a parte
    /// vorrebbe dire tirarsi in casa migliaia di campioni che nessuno guarda.
    test('🆕 i passi si CHIEDONO ma non si leggono grezzi', () {
      /*
       * ══ 🚨 QUESTO TEST DICEVA IL CONTRARIO — cambiato il 06/09/2026 ═════
       *
       * Si chiamava *«passi e distanza si chiedono ma non si leggono a parte»*,
       * e per i passi era una decisione: il permesso se l'era portato dietro
       * l'import degli allenamenti, e li si leggeva **solo dentro una sessione**.
       *
       * 📌 Il committente: *«per il resto della giornata cammino lo stesso e gli
       * altri devono comunque essere conteggiati»*. ⛔ E senza, in un giorno
       * senza palestra non c'era **nessun** segnale del movimento quotidiano —
       * metà del motivo per cui la Carica non scendeva mai.
       *
       * ⚠️ **La distanza resta fuori**, e non per dimenticanza: dice quanto ti
       * sei spostato, che è un passo più vicino a dove sei stato. 🚨 Il giorno
       * che servisse, prima del codice si aggiornano il registro dei trattamenti
       * e l'informativa.
       */
      /*
       * ══ 🚨 E I PASSI NON PASSANO DA `tipiDaLeggere` — corretto il 07/09 ══
       *
       * ⛔ Il 06/09 avevo messo `STEPS` fra i tipi da leggere, e questo test
       * pretendeva che ci fosse.
       *
       * ⚠️ Il 07/09 il confronto con l'aggregato ha mostrato che la somma dei
       * record grezzi **diverge** — di poco, e in tutti e due i versi: 23.471
       * contro 22.470 un giorno, 7.533 contro 8.192 un altro.
       *
       * 🚨 **La deduplicazione non è un problema nostro.** Health Connect sa
       * quali record si sovrappongono, sorgente per sorgente; noi possiamo solo
       * indovinare, e ogni euristica sbaglia su un caso diverso.
       *
       * 💡 Quindi il permesso **serve** — resta fra quelli da autorizzare,
       * perché senza l'aggregato non risponde — ma il tipo **non** va nel giro
       * dei record grezzi.
       */
      expect(
        PonteSalute.tipiDaAutorizzare,
        contains(HealthDataType.STEPS),
        reason: "senza il permesso l'aggregato non risponde",
      );

      expect(
        PonteSalute.tipiDaLeggere,
        isNot(contains(HealthDataType.STEPS)),
        reason: "i record grezzi si sovrappongono: si usa l'aggregato",
      );

      // ⚠️ La distanza resta fuori da tutti e due i giri per la lettura: dice
      // quanto ti sei spostato, che è un passo più vicino a dove sei stato.
      expect(
        PonteSalute.tipiDaLeggere,
        isNot(contains(HealthDataType.DISTANCE_DELTA)),
      );
    });
  });

  /// 🚨 La traccia GPS: dove abiti e che giro fai la domenica. E' il dato piu'
  /// identificante che il telefono possieda, e non serve a niente di quello che
  /// facciamo.
  test('la traccia GPS non si chiede e non si legge', () {
    expect(
      PonteSalute.tipiDaAutorizzare,
      isNot(contains(HealthDataType.WORKOUT_ROUTE)),
    );
    expect(
      PonteSalute.tipiDaLeggere,
      isNot(contains(HealthDataType.WORKOUT_ROUTE)),
    );
  });

  /// ⚠️ Chi legge deve poter fidarsi che l'elenco lungo **contenga** quello
  /// corto: chiedere meno di quel che si legge e' il difetto opposto, e finisce
  /// nello stesso posto — lista vuota e nessun errore visibile.
  test('si chiede sempre almeno tutto quello che si legge', () {
    for (final tipo in PonteSalute.tipiDaLeggere) {
      expect(PonteSalute.tipiDaAutorizzare, contains(tipo));
    }
  });
}
