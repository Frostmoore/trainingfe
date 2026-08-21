import '../../core/storage/archivio_salute.dart';
import 'dati_salute.dart';

/// Una lettura **con il suo metro di paragone**.
///
/// 🚨 **Il valore da solo non dice niente.** Un HRV di 42 ms è ottimo per
/// qualcuno e allarmante per qualcun altro: conta lo **scostamento dalla media
/// di quella persona**. Tenerli insieme in un unico oggetto è ciò che impedisce
/// a chi legge — l'interfaccia, o una futura funzione — di interpretare un
/// numero assoluto come se fosse un voto.
class LetturaConMedia {
  const LetturaConMedia({
    required this.metrica,
    required this.valore,
    required this.giorno,
    this.media,
    this.scostamentoPct,
  });

  final MetricaSalute metrica;
  final double valore;
  final DateTime giorno;

  /// `null` quando non ci sono abbastanza giorni precedenti.
  final double? media;

  /// Quanto ci si discosta, in percentuale. `null` se non c'è media.
  final double? scostamentoPct;

  /// 🚨 **Solo uno scostamento sotto la media conta come anomalia**, e solo per
  /// l'HRV. Un HRV **sopra** la propria media è una buona notizia, non un
  /// allarme; un battito a riposo sopra la media invece sì.
  ///
  /// ⚠️ La soglia del 15% è la stessa che usava il prompt del consiglio del
  /// giorno prima di S1: *«un HRV sotto la media di più del 15% con poco sonno
  /// indica che il corpo non ha recuperato»*.
  bool get anomalo {
    final s = scostamentoPct;

    if (s == null) return false;

    return switch (metrica) {
      MetricaSalute.hrv => s <= -15,
      MetricaSalute.battitoARiposo || MetricaSalute.battitoMedio => s >= 15,

      /*
       * 🚨 **Le calorie attive non sono mai un'anomalia** — FASE 1.
       *
       * ⚠️ Non e' una dimenticanza: e' una decisione, e lo switch esaustivo ha
       * fatto il suo mestiere costringendo a prenderla invece di lasciarla
       * cadere in un `default`.
       *
       * Bruciare piu' del solito e' un allenamento, non un segnale di
       * recupero; bruciarne meno e' un giorno di riposo. 💡 Portarlo nel
       * giudizio del recupero direbbe «attenzione» a chi si e' allenato bene e
       * a chi si e' riposato apposta — cioe' a tutti, nel verso sbagliato.
       */
      MetricaSalute.calorieAttive => false,
    };
  }
}

/// Il ritratto in Dart di `HealthReading::latestWithBaseline()` — S4.1.
///
/// 🚨 **È una traduzione, non una riscrittura.** Il metodo PHP è stato
/// cancellato in S1 insieme alla tabella; la regola che portava vive qui,
/// **identica**. La regola §2.3 del piano — *spostare non è migliorare* —
/// esiste perché altrimenti non si distingue più un difetto del trasloco da uno
/// introdotto per strada.
class MediaDiRiferimento {
  const MediaDiRiferimento._();

  /// L'ultima lettura di una metrica, con la media dei giorni precedenti.
  ///
  /// Restituisce `null` quando non c'è **nessuna** lettura: non uno zero.
  /// Uno zero verrebbe disegnato come un valore pessimo invece che come un dato
  /// mai arrivato.
  static Future<LetturaConMedia?> perMetrica(
    ArchivioSalute archivio,
    MetricaSalute metrica, {
    int giorniBase = 7,
  }) async {
    final ultima = await archivio.ultimaLettura(metrica);

    if (ultima == null) return null;

    /*
     * 🚨 **La media ESCLUDE il giorno dell'ultima misura.**
     *
     * Confrontare un valore con una media che lo contiene lo avvicina
     * artificialmente: uno scostamento vero sembrerebbe piu' piccolo di quanto
     * e', ed e' proprio nel giorno storto che serve vederlo intero.
     *
     * ⚠️ E la finestra parte dal giorno DELL'ULTIMA MISURA, non da oggi. Con
     * una misura vecchia di tre giorni, «gli ultimi sette da adesso» darebbe
     * una finestra quasi vuota e la media sparirebbe senza motivo.
     */
    final fine = ultima.giorno.subtract(const Duration(days: 1));
    final inizio = ultima.giorno.subtract(Duration(days: giorniBase));

    final precedenti = await archivio.lettureFraGiorni(
      metrica,
      da: inizio,
      a: fine,
    );

    if (precedenti.isEmpty) {
      return LetturaConMedia(
        metrica: metrica,
        valore: ultima.valore,
        giorno: ultima.giorno,
      );
    }

    final somma = precedenti.fold<double>(0, (acc, l) => acc + l.valore);
    final media = somma / precedenti.length;

    return LetturaConMedia(
      metrica: metrica,
      valore: ultima.valore,
      giorno: ultima.giorno,
      media: _arrotonda(media, 1),
      // ⚠️ Una media <= 0 non produce uno scostamento: dividerci sarebbe una
      // divisione per zero travestita, e con valori negativi il segno del
      // risultato sarebbe pure invertito.
      scostamentoPct: media <= 0
          ? null
          : _arrotonda((ultima.valore - media) / media * 100, 1),
    );
  }

  /// 🚨 Le metriche che **non** si possono trattare come misure puntuali.
  ///
  /// ══ IL DIFETTO DEL 21/08/2026 ═══════════════════════════════════════════
  ///
  /// 📌 Il committente: *«le calorie attive sono sbagliate, non so perché ma mi
  /// prende quelle dell'altro ieri»*.
  ///
  /// ⚠️ **Aveva ragione, e la causa è che erano nel posto sbagliato.** Questa
  /// classe risponde alla domanda *«qual è l'ultima misura, e come sta rispetto
  /// alla tua media?»* — che ha senso per HRV e battito a riposo: sono
  /// **istantanee**, e l'ultima è l'ultima.
  ///
  /// 🚨 Le calorie attive non sono un'istantanea: sono un **totale che cresce
  /// durante la giornata**. Trattarle come le altre produceva due errori
  /// insieme, e nessuno dei due dava errore:
  ///
  /// 1. **Il giorno sbagliato.** `ultima` è l'ultima riga *che esiste*, non
  ///    quella di oggi: senza sincronizzazione di oggi si mostrava tranquillamente
  ///    l'altro ieri, con la sua data accanto — che nessuno legge.
  /// 2. **Il numero sbagliato.** `ultima.valore` è **un campione**, non la somma
  ///    del giorno. Health Connect ne scrive decine: quello mostrato era uno a
  ///    caso fra quelli.
  ///
  /// 💡 La somma vera la fa già `ArchivioSalute.kcalAttiveDi()`, che raggruppa
  /// per sorgente e prende la maggiore — perché due app che scrivono lo stesso
  /// giorno non si sommano, si sceglie la più completa.
  ///
  /// ⛔ **Chi aggiunge una metrica cumulativa la deve mettere qui.** Il segno per
  /// riconoscerla: se la domanda giusta è «quanto in tutto oggi» invece di
  /// «quanto adesso», non è una misura puntuale.
  static const cumulative = {MetricaSalute.calorieAttive};

  /// Tutte le metriche in un colpo solo, per la dashboard.
  ///
  /// Le metriche senza dati **non compaiono**: la mappa vuota è ciò che dice
  /// all'interfaccia «non mostrare la sezione», e sostituisce l'`has_any` che
  /// il backend mandava prima di S1.
  static Future<Map<MetricaSalute, LetturaConMedia>> tutte(
    ArchivioSalute archivio, {
    int giorniBase = 7,
  }) async {
    final out = <MetricaSalute, LetturaConMedia>{};

    for (final m in MetricaSalute.values) {
      // 🚨 Le cumulative non passano di qui: vedi `cumulative`.
      if (cumulative.contains(m)) continue;

      final lettura = await perMetrica(archivio, m, giorniBase: giorniBase);

      if (lettura != null) out[m] = lettura;
    }

    return out;
  }

  /// L'arrotondamento di PHP `round($v, 1)`.
  static double _arrotonda(double v, int decimali) {
    final f = <int, double>{0: 1, 1: 10, 2: 100}[decimali] ?? 10;

    return (v * f).roundToDouble() / f;
  }
}
