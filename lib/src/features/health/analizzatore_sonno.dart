import '../../core/storage/archivio_salute.dart';
import 'dati_salute.dart';
import 'sessioni_di_sonno.dart';

/// Il giudizio di una notte.
class GiudizioNotte {
  const GiudizioNotte({
    required this.notte,
    required this.da,
    required this.a,
    required this.minutiDormiti,
    required this.minutiSvegli,
    required this.minutiLeggero,
    required this.minutiProfondo,
    required this.minutiRem,
    required this.profondoPct,
    required this.remPct,
    required this.valutazioni,
    required this.complessivo,
    required this.ipnogramma,
  });

  final DateTime notte;
  final DateTime da;
  final DateTime a;

  final int minutiDormiti;
  final int minutiSvegli;
  final int minutiLeggero;
  final int minutiProfondo;
  final int minutiRem;

  final double profondoPct;
  final double remPct;

  /// Il voto di ciascun indicatore.
  final Map<String, Giudizio> valutazioni;

  /// 🚨 **Il peggiore dei quattro, non la media.** Vedi `AnalizzatoreSonno`.
  final Giudizio complessivo;

  final List<CampioneSonno> ipnogramma;

  /// ⚠️ **Non è una valutazione medica**, e l'interfaccia deve dirlo. Era il
  /// campo `disclaimer` che il backend mandava con ogni risposta: qui è una
  /// costante, ma il dovere di mostrarla è lo stesso.
  static const avvertenza =
      'Indicazioni orientative, non una valutazione medica.';

  String get durata {
    final ore = minutiDormiti ~/ 60;
    final minuti = minutiDormiti % 60;

    return '${ore}h ${minuti.toString().padLeft(2, '0')}m';
  }
}

/// Il ritratto in Dart di `SleepAnalyzer` — S4.2.
///
/// 🚨 **È una traduzione fedele, non una riscrittura.** Le quattro soglie e la
/// regola del peggiore sono copiate dal file PHP cancellato in S1, non
/// ricordate: la regola §2.3 del piano dice che spostare non è migliorare,
/// perché altrimenti un difetto del trasloco e uno introdotto per strada
/// diventano indistinguibili.
///
/// | Indicatore | ok | attenzione |
/// |---|---|---|
/// | minuti dormiti | ≥ 420 | ≥ 360 |
/// | % profondo | ≥ 15 | ≥ 10 |
/// | % REM | ≥ 20 | ≥ 15 |
/// | minuti svegli | ≤ 30 | ≤ 60 |
class AnalizzatoreSonno {
  const AnalizzatoreSonno._();

  static const _minutiDormitiOk = 420;
  static const _minutiDormitiWarn = 360;
  static const _profondoPctOk = 15.0;
  static const _profondoPctWarn = 10.0;
  static const _remPctOk = 20.0;
  static const _remPctWarn = 15.0;
  static const _minutiSvegliOk = 30;
  static const _minutiSvegliWarn = 60;

  /// Il riepilogo di una notte. `null` se per quella notte non c'è nessun
  /// campione — **non** un oggetto con tutti zeri.
  /// Le **pennichelle** di una giornata — 21/08/2026.
  ///
  /// ══ 🚨 PERCHÉ ESISTE, E PERCHÉ NON TOCCA IL CONTO DELLA NOTTE ═══════════
  ///
  /// 📌 Il committente: *«la notte ho dormito 5:16 ma poi ho fatto due pisolini,
  /// vedi se ti risultano perché sull'app non si vedono»*.
  ///
  /// ⚠️ Le pennichelle **erano già lette e già salvate** — `_assegnaLeGiornate`
  /// dà a ognuna la sua giornata — e già classificate (`eNotte: false`). 🚨 Il
  /// difetto era che **nessuno le chiedeva**: `notte()` teneva solo le notti e
  /// buttava il resto, quindi un'ora e mezza di sonno vera spariva dall'app
  /// senza lasciare traccia.
  ///
  /// 💡 È lo specchio del difetto del 20/08. Allora i pisolini finivano **dentro**
  /// il totale della notte e lo gonfiavano; la correzione li ha tolti — e li ha
  /// tolti **anche dalla vista**. Una cosa contata male è peggio di una non
  /// contata, ma «non contata» non deve voler dire «invisibile».
  ///
  /// ⛔ **E restano fuori dal conto della notte, dal recupero e dal consiglio.**
  /// Questo metodo serve a **mostrarle**, non a rimetterle nella somma: due ore
  /// di pennichella non rendono riposante una notte da cinque.
  static Future<List<SessioneSonno>> pisolini(
    ArchivioSalute archivio,
    DateTime quale,
  ) async {
    final tutti = await archivio.campioniDellaNotte(quale);

    if (tutti.isEmpty) return const [];

    return SessioniDiSonno.da(
      tutti.map((c) => (inizio: c.iniziatoIl, fine: c.finitoIl)),
    ).where((s) => !s.eNotte).toList();
  }

  static Future<GiudizioNotte?> notte(
    ArchivioSalute archivio,
    DateTime quale,
  ) async {
    final tutti = await archivio.campioniDellaNotte(quale);

    if (tutti.isEmpty) return null;

    /*
     * ══ 🚨 IL PISOLINO NON È NOTTE — difetto del 20/08/2026 ═════════════════
     *
     * ⚠️ Qui si sommavano **tutti** i campioni della giornata di riposo, e una
     * pennichella pomeridiana finiva dentro il totale della notte. Il
     * committente l'ha visto subito: *«ho dormito sì 8:55h ma 2 di queste sono
     * state un pisolino»*.
     *
     * 🚨 **Non è un arrotondamento: è un numero falso** che poi entra nel
     * consiglio del giorno e nel giudizio sul recupero. Due ore di pennichella
     * fanno sembrare riposante una notte da sei ore e mezza.
     *
     * 💡 `SessioniDiSonno` sapeva già distinguerle (`eNotte`): quello che
     * mancava era **usarlo qui**. La classificazione c'era, il consumatore no.
     *
     * ⚠️ E se per quella giornata ci sono **solo** pennichelle, non si dice che
     * ha dormito due ore: si dice che non c'è una notte. Sommare i pisolini e
     * chiamarli notte sarebbe lo stesso difetto al contrario.
     */
    final notti = SessioniDiSonno.da(
      tutti.map((c) => (inizio: c.iniziatoIl, fine: c.finitoIl)),
    ).where((s) => s.eNotte).toList();

    if (notti.isEmpty) return null;

    final campioni = tutti.where((c) {
      for (final n in notti) {
        // 💡 Un campione appartiene alla notte se ci **comincia** dentro: gli
        // estremi coincidono per costruzione, e il confronto sull'inizio evita
        // di contare due volte un segmento a cavallo.
        if (!c.iniziatoIl.isBefore(n.inizio) && !c.iniziatoIl.isAfter(n.fine)) {
          return true;
        }
      }

      return false;
    }).toList();

    if (campioni.isEmpty) return null;

    var leggero = 0;
    var profondo = 0;
    var rem = 0;
    var sveglio = 0;

    for (final c in campioni) {
      switch (FaseSonno.daCodice(c.fase)) {
        case FaseSonno.leggero:
          leggero += c.minuti;
        case FaseSonno.profondo:
          profondo += c.minuti;
        case FaseSonno.rem:
          rem += c.minuti;
        case FaseSonno.sveglio:
          sveglio += c.minuti;
      }
    }

    // ⚠️ «Dormito» = leggero + profondo + REM. I minuti da svegli **non**
    // contano, anche se il sensore li ha registrati dentro la finestra del
    // sonno: sono esattamente ciò che rende una notte lunga poco riposante.
    final dormito = leggero + profondo + rem;

    final profondoPct = dormito > 0
        ? _arrotonda(profondo / dormito * 100, 1)
        : 0.0;
    final remPct = dormito > 0 ? _arrotonda(rem / dormito * 100, 1) : 0.0;

    final valutazioni = <String, Giudizio>{
      'asleep_minutes': _valuta(
        dormito,
        _minutiDormitiOk,
        _minutiDormitiWarn,
        piuEMeglio: true,
      ),
      'deep_pct': _valuta(
        profondoPct,
        _profondoPctOk,
        _profondoPctWarn,
        piuEMeglio: true,
      ),
      'rem_pct': _valuta(remPct, _remPctOk, _remPctWarn, piuEMeglio: true),
      'awake_minutes': _valuta(
        sveglio,
        _minutiSvegliOk,
        _minutiSvegliWarn,
        piuEMeglio: false,
      ),
    };

    return GiudizioNotte(
      notte: quale,
      da: campioni.first.iniziatoIl,
      a: campioni.last.finitoIl,
      minutiDormiti: dormito,
      minutiSvegli: sveglio,
      minutiLeggero: leggero,
      minutiProfondo: profondo,
      minutiRem: rem,
      profondoPct: profondoPct,
      remPct: remPct,
      valutazioni: valutazioni,
      complessivo: _peggiore(valutazioni.values),
      ipnogramma: campioni,
    );
  }

  static Giudizio _valuta(
    num valore,
    num ok,
    num warn, {
    required bool piuEMeglio,
  }) {
    if (piuEMeglio) {
      if (valore >= ok) return Giudizio.ok;
      if (valore >= warn) return Giudizio.warn;

      return Giudizio.bad;
    }

    if (valore <= ok) return Giudizio.ok;
    if (valore <= warn) return Giudizio.warn;

    return Giudizio.bad;
  }

  /// 🚨 **Il giudizio complessivo è il PEGGIORE dei quattro, non la media.**
  ///
  /// Una notte di otto ore con il 10% di sonno profondo non è «buona in media»:
  /// è **lunga e poco riposante**, e mediarla la farebbe passare per normale.
  /// In salute il valore che conta è quello che sta peggio.
  ///
  /// ⚠️ È la riga che si perde per prima quando si riscrive qualcosa «uguale ma
  /// in un'altra lingua», ed è il motivo per cui l'atlante backend ha tenuto le
  /// soglie anche dopo aver cancellato il file.
  static Giudizio _peggiore(Iterable<Giudizio> valutazioni) {
    if (valutazioni.contains(Giudizio.bad)) return Giudizio.bad;

    return valutazioni.contains(Giudizio.warn) ? Giudizio.warn : Giudizio.ok;
  }

  static double _arrotonda(double v, int decimali) {
    final f = <int, double>{0: 1, 1: 10, 2: 100}[decimali] ?? 10;

    return (v * f).roundToDouble() / f;
  }
}
