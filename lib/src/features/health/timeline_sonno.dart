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
/// ── 🚨 Da dove venivano i minuti in più ──────────────────────────────────
///
/// `PonteSalute` chiede a Health Connect **sia** le fasi dettagliate
/// (`SLEEP_DEEP`, `SLEEP_REM`, `SLEEP_LIGHT`, `SLEEP_AWAKE`) **sia** quella
/// generica `SLEEP_ASLEEP` — «dorme, ma non sappiamo come» — e la mappa su
/// *leggero*.
///
/// ⛔ **Ma `SLEEP_ASLEEP` non è una fase in più: è la stessa notte descritta a
/// grana grossa.** Si sovrappone alle altre, e sommarla è contare due volte lo
/// stesso tempo.
///
/// ── ⛔ La ricostruzione fatta a tavolino era SBAGLIATA ──────────────────
///
/// 🚨 Prima di scrivere questa classe avevo dedotto che i 199 minuti di troppo
/// stessero **tutti sul leggero**, perché `191 + 127 + 172 + 39 = 529` torna al
/// minuto — e l'avevo chiamata *«l'unica scomposizione che torna»*.
///
/// ⛔ **Non lo era.** Con la correzione accesa, i numeri veri sono
/// `107 + 107 + 285 + 30 = 529`: la sovrapposizione era sparsa su **tutte e
/// quattro** le fasi — profondo −84, REM −20, leggero −86, sveglio −9 — non
/// concentrata su una. Anche i campioni della **stessa** fase si accavallavano
/// fra loro.
///
/// ⚠️ **Vale la pena tenerlo scritto**: una somma che torna non è una prova.
/// C'erano molte scomposizioni compatibili con «728 in 529», e ne avevo presa
/// una sola scambiandola per l'unica. 💡 La diagnosi — *tempo contato due
/// volte* — era giusta; la storia su **dove** fosse, no. È la stessa distanza
/// che passa fra un numero plausibile e un numero vero.
///
/// 🚨 Il commento accanto alla mappatura si chiedeva *quale fase* chiamarla
/// («leggero e non profondo, che sarebbe la lettura più generosa») e ragionava
/// bene. ⛔ Non si chiedeva mai **se quel tempo fosse già contato altrove**:
/// nessun errore, nessun avviso, un numero plausibile — la stessa famiglia di
/// O.D.20.
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
/// 2. ⚠️ **La sovrapposizione non è solo colpa di `SLEEP_ASLEEP`.** Due app che
///    scrivono la stessa notte, o un orologio che ricarica una notte corretta
///    con inizi spostati di qualche secondo, producono lo stesso difetto.
///    Appiattire la linea del tempo li chiude tutti insieme.
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
