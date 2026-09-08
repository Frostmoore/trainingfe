import 'dati_salute.dart';

/// Un pezzo di notte, in una fase sola.
///
/// 💡 A differenza di un campione grezzo, due segmenti **non si sovrappongono
/// mai**: è l'invariante che [TimelineSonno.appiattisci] stabilisce.
class SegmentoSonno {
  const SegmentoSonno({required this.da, required this.a, required this.fase});

  final DateTime da;
  final DateTime a;
  final FaseSonno fase;

  int get minuti {
    final s = a.difference(da).inSeconds;

    return s <= 0 ? 0 : (s / 60).round();
  }

  @override
  String toString() => '$fase ${da.toIso8601String()} → ${a.toIso8601String()}';
}

/// La notte come **linea del tempo**, senza sovrapposizioni — 23/08/2026.
///
/// ══ 🚨 IL DIFETTO CHE QUESTA CLASSE ESISTE PER CHIUDERE ═══════════════════
///
/// 📌 Il committente, guardando la schermata del sonno: *«dimmi che porcoddio
/// di calcolo ha fatto?»*.
///
/// ⚠️ **Diceva 11h 29 di sonno dentro una finestra di 8h 49.** Health Connect
/// aveva **una sola** sessione — `03:02 → 11:51`, scritta da Zepp, 529 minuti —
/// e l'app ne sommava 728.
///
/// ── 🚨 Da dove venivano i minuti in più — VERIFICATO SUI DATI ───────────
///
/// ⛔ **Le prime due spiegazioni erano sbagliate**, e sono scritte qui perché
/// sbagliare due volte di seguito sullo stesso difetto è la cosa da ricordare.
///
/// 1. *«È `SLEEP_ASLEEP`, la fase generica, che si somma alle dettagliate»* —
///    plausibile, e falsa. `PonteSalute` la chiede davvero, ma su questa notte
///    non c'era nemmeno un campione generico.
/// 2. *«I 199 minuti stanno tutti sul leggero, perché
///    `191 + 127 + 172 + 39 = 529` torna al minuto»* — una somma che torna non
///    è una prova: di scomposizioni compatibili ce n'erano molte.
///
/// 💡 **La causa vera, letta dai campioni grezzi del 23/08/2026**: l'orologio
/// scrive la stessa notte **due volte**, con i confini spostati di un minuto o
/// due. Una sola fonte — `com.huami.watch.hmwatchmanager` — e coppie come
/// queste:
///
/// ```
/// Profondo 03:19 → 04:09 = 50      Profondo 03:25 → 04:09 = 44
/// Profondo 04:30 → 04:57 = 27      Profondo 04:31 → 04:57 = 26
/// REM      05:05 → 05:17 = 12      REM      05:07 → 05:17 = 10
/// Leggero  07:48 → 08:41 = 53      Leggero  07:49 → 08:41 = 52
/// Sveglio  09:52 → 10:01 =  9      Sveglio  09:53 → 10:01 =  8
/// ```
///
/// 🚨 **Nove coppie, su tutte e quattro le fasi.** 48 campioni grezzi per 728
/// minuti, in una finestra di 529: i 199 di troppo sono i doppioni.
///
/// ⛔ **E `insertOrIgnore` non poteva vederli**: la chiave unica dell'archivio è
/// `(fonte, iniziatoIl)`, e questi hanno inizi **diversi**. Due righe legittime
/// per lo scrittore, lo stesso minuto di sonno per chi legge.
///
/// ── 💡 Perché si corregge QUI e non all'ingresso ─────────────────────────
///
/// Scartare il generico al momento della lettura sarebbe stato più semplice, e
/// **sbagliato per due ragioni**:
///
/// 1. ⛔ **Non aggiusterebbe le notti già in archivio.** Il gonfiaggio è dentro
///    i dati salvati, e quei numeri sono finiti nel giudizio sul recupero e nel
///    consiglio del giorno. Correggere il calcolo li rimette a posto **tutti**,
///    senza risincronizzare niente.
/// 2. ⚠️ **La causa non era quella che sembrava, e la correzione ha retto lo
///    stesso.** È l'argomento più forte per questo approccio: appiattire la
///    linea del tempo chiude **qualunque** sovrapposizione — il generico, il
///    doppione dell'orologio, due app che scrivono la stessa notte — senza
///    dover indovinare quale sia. Una correzione mirata alla causa immaginata
///    avrebbe sistemato un terzo del problema.
///
/// 💡 L'archivio resta la **registrazione fedele** di quello che Health Connect
/// ha detto, sovrapposizioni comprese. È il posto giusto per la verità grezza;
/// questo è il posto giusto per leggerla.
class TimelineSonno {
  const TimelineSonno._();

  /// Chi vince quando due campioni coprono lo stesso istante.
  ///
  /// ══ ⚠️ NON È UNA PREFERENZA ESTETICA ══════════════════════════════════
  ///
  /// 🚨 **Il generico è indistinguibile dal leggero una volta in archivio**:
  /// `_faseDi` mappa `SLEEP_ASLEEP` su `FaseSonno.leggero` *prima* di salvare,
  /// e quel dettaglio è perso per sempre nelle righe già scritte.
  ///
  /// 💡 Ma non serve saperlo: **il leggero è la fase generica**, quella su cui
  /// finisce tutto ciò che non è stato classificato. Quindi quando si
  /// sovrappone a una fase specifica, è lei che deve cedere — è l'unico verso
  /// che non inventa informazione.
  ///
  /// ⛔ **`sveglio` batte `leggero` ma perde contro profondo e REM.** Uno
  /// «sveglio» sovrapposto a un «profondo» è una contraddizione del sensore, e
  /// in quel caso vince la lettura più specifica; sovrapposto al generico,
  /// invece, è lui la lettura più precisa.
  static const _priorita = {
    FaseSonno.profondo: 3,
    FaseSonno.rem: 3,
    FaseSonno.sveglio: 2,
    FaseSonno.leggero: 1,
  };

  /// Trasforma campioni che si sovrappongono in segmenti che non lo fanno.
  ///
  /// 🚨 **L'invariante che stabilisce**: la somma dei minuti dei segmenti non
  /// può superare la distanza fra il primo inizio e l'ultima fine. È esattamente
  /// la cosa che prima non valeva, ed è verificata da un test.
  ///
  /// 💡 Segmenti adiacenti della stessa fase vengono **riuniti**: senza, un
  /// blocco di sonno profondo attraversato dal confine di un campione generico
  /// si spezzerebbe in due, e l'ipnogramma mostrerebbe una discontinuità che nel
  /// sonno non c'è stata.
  static List<SegmentoSonno> appiattisci(
    Iterable<({DateTime da, DateTime a, FaseSonno fase})> campioni,
  ) {
    final validi = campioni.where((c) => c.a.isAfter(c.da)).toList();

    if (validi.isEmpty) return const [];

    /*
     * 💡 Tutti gli istanti in cui *qualcosa* cambia: un campione comincia o
     * finisce. Fra due confini consecutivi la situazione è ferma, quindi basta
     * chiedersi una volta sola chi vince.
     */
    final confini = <DateTime>{
      for (final c in validi) ...[c.da, c.a],
    }.toList()..sort();

    final segmenti = <SegmentoSonno>[];

    for (var i = 0; i < confini.length - 1; i++) {
      final da = confini[i];
      final a = confini[i + 1];

      FaseSonno? vincitrice;

      for (final c in validi) {
        // Copre l'intervallo se comincia non dopo e finisce non prima.
        if (c.da.isAfter(da) || c.a.isBefore(a)) continue;

        final attuale = vincitrice;

        if (attuale == null || _priorita[c.fase]! > _priorita[attuale]!) {
          vincitrice = c.fase;
        }
      }

      // ⛔ Un buco fra due campioni non si riempie: è tempo di cui il sensore
      // non ha detto niente, e inventarlo sarebbe l'errore opposto.
      if (vincitrice == null) continue;

      final ultimo = segmenti.isEmpty ? null : segmenti.last;

      if (ultimo != null &&
          ultimo.fase == vincitrice &&
          !ultimo.a.isBefore(da)) {
        segmenti[segmenti.length - 1] = SegmentoSonno(
          da: ultimo.da,
          a: a,
          fase: vincitrice,
        );
      } else {
        segmenti.add(SegmentoSonno(da: da, a: a, fase: vincitrice));
      }
    }

    return segmenti;
  }
}
