import '../../../core/storage/archivio_salute.dart';
import 'session_models.dart';

/// Una riga dello storico: **tutto quello che appartiene allo stesso
/// allenamento**, da qualunque fonte venga — FASE 1-bis.
///
/// ── 🚨 Perché una riga può contenerne molte ───────────────────────────────
///
/// Fino al 20/08 una riga era *una seduta più al massimo un allenamento del
/// polso*. Le decisioni del committente hanno rotto quella forma:
///
/// > *«se i timeframes si sovrappongono allora è lo stesso allenamento […]
/// > esiste anche la possibilità che io fermi per sbaglio un allenamento sul
/// > telefono e lo faccia ripartire, anche in tal caso è lo stesso
/// > allenamento»*.
///
/// ⚠️ Se A tocca B e B tocca C, allora **A, B e C sono lo stesso allenamento**
/// anche quando A e C non si sfiorano affatto. Con le coppie quella catena non
/// si può rappresentare: servono liste.
class VoceStorico {
  const VoceStorico({
    required this.sedute,
    required this.dalPolso,
    this.nomeScheda,
    this.schedaId,
  });

  /// Le sedute registrate **nell'app**, in ordine di tempo.
  ///
  /// 💡 Più di una quando qualcuno ha fermato per sbaglio e ripreso.
  final List<WorkoutSession> sedute;

  /// Gli allenamenti registrati **dall'orologio**, in ordine di tempo.
  final List<AllenamentoDaOrologio> dalPolso;

  /// Il nome della scheda che la persona ha detto di aver fatto.
  ///
  /// ══ 🚨 IL NOME E NON IL MODELLO — 3b-A.2, 23/08/2026 ═══════════════════
  ///
  /// ⛔ Prima era una `SchedaRicevuta`, cioè **solo** una scheda arrivata in
  /// chat. Le schede assegnate dal trainer stanno sul server, e non c'era modo
  /// di rappresentarle: chi ha solo quelle non poteva assegnarne nessuna.
  ///
  /// 💡 Di quel modello si usava **una cosa sola, il nome** — lo si vede in
  /// `history_screen`. Tenerlo come stringa toglie l'accoppiamento e fa entrare
  /// tutte e due le provenienze senza inventare un tipo comune.
  final String? nomeScheda;

  /// L'**id firmato** della stessa scheda — negativo se arrivata in chat,
  /// positivo se dal server.
  ///
  /// ══ 🚨 IL NOME NON BASTA PIÙ — B.9, 24/08/2026 ═════════════════════════
  ///
  /// 📌 *«I gruppi muscolari NON arrivano dall'orologio. Al massimo possono
  /// arrivare dalla scheda che ho associato»*.
  ///
  /// ⛔ Per **mostrare** una scheda basta il nome, e per questo `nomeScheda`
  /// esisteva da solo. Per **sapere che muscoli allena** serve andarsela a
  /// prendere, e per andarsela a prendere serve l'id.
  ///
  /// ⚠️ Cercarla per nome sarebbe stato l'errore facile: due schede possono
  /// chiamarsi uguale — «Giorno 1» è il nome più probabile del mondo — e una
  /// omonimia colorerebbe i muscoli **di un'altra scheda** senza dare nessun
  /// errore. È lo stesso difetto del «Rematore corda» sul server, visto da qui.
  final int? schedaId;

  /// La seduta principale: la **prima**, quando c'è.
  ///
  /// 🚨 È quella che si apre toccando la riga, e quella che dà il titolo. ⚠️ La
  /// prima e non la più lunga: è quella che la persona ha cominciato, e le altre
  /// del gruppo sono riprese *di quella*.
  WorkoutSession? get seduta => sedute.isEmpty ? null : sedute.first;

  /// Se questa riga esiste **solo** grazie all'orologio.
  ///
  /// 💡 È il caso per cui la FASE 1.8 esiste: *«molta gente probabilmente o non
  /// userà l'app quando si allena o non userà l'orologio»*.
  bool get soloDalPolso => sedute.isEmpty;

  /// Quando è cominciato. È la chiave con cui si ordina tutto.
  DateTime get quando => _estremi.$1;

  DateTime get fine => _estremi.$2;

  /// Quanto è durato **il gruppo intero**, buchi compresi.
  ///
  /// ⚠️ Buchi compresi di proposito: una seduta fermata alle 18:30 e ripresa
  /// alle 18:35 è durata **dalle 18:00 alle 19:00**, non cinquantacinque
  /// minuti. Chi guarda vuole sapere quanto tempo ci ha messo, non quanto ne ha
  /// passato con il cronometro acceso.
  Duration get durata => fine.difference(quando);

  /// Le calorie **attive** dell'orologio, sommate su tutto il gruppo.
  ///
  /// 🚨 `null` — e non `0` — quando l'orologio non c'era o non le sapeva:
  /// «non lo so» e «non hai bruciato niente» sono due cose diverse.
  ///
  /// ⚠️ **Attive, mai totali**: vedi la nota su `AllenamentiDaOrologio.kcal`. Il
  /// raggruppamento cambia *a quale riga appartengono* le calorie, non *quali
  /// sono*.
  int? get kcalDalPolso {
    var somma = 0;
    var trovato = false;

    for (final a in dalPolso) {
      final k = a.kcal;
      if (k == null) continue;

      somma += k;
      trovato = true;
    }

    return trovato ? somma : null;
  }

  /// Le calorie **delle sedute dell'app**, sommate su tutto il gruppo.
  ///
  /// ── 🚨 Perché sommate e non solo la prima ─────────────────────────────────
  ///
  /// Perché un gruppo può contenere più sedute — è il caso «fermo per sbaglio e
  /// riparto» — e quelle sono **pezzi dello stesso allenamento**. ⚠️ Fino al
  /// 20/08 qui si prendeva `sedute.first.kcal`: i tratti dell'orologio si
  /// sommavano e quelli dell'app no, e chi si fermava a metà si vedeva contare
  /// solo la prima parte.
  ///
  /// 💡 `WorkoutSession.kcal` è già il valore **che vale** per quella seduta: il
  /// server ci mette la correzione a mano se c'è, altrimenti la stima. Sommarlo
  /// è quindi giusto in entrambi i casi, e `kcalCorrettaAMano` dice quale delle
  /// due storie raccontare.
  int? get kcalDalleSedute {
    var somma = 0;
    var trovato = false;

    for (final s in sedute) {
      final k = s.kcal;
      if (k == null) continue;

      somma += k;
      trovato = true;
    }

    return trovato ? somma : null;
  }

  /// Se **almeno una** delle sedute del gruppo è stata corretta a mano.
  ///
  /// 🚨 Basta una: chi ha scritto un numero l'ha scritto apposta, e un sensore
  /// non lo sconfessa. ⚠️ Guardare solo la prima vorrebbe dire che una
  /// correzione fatta sul secondo tratto viene ignorata senza dirlo.
  bool get kcalCorrettaAMano => sedute.any((s) => s.kcalSource == 'manual');

  /// Le calorie **che valgono** per questa riga, con la catena di priorità.
  ///
  /// 🚨 **La correzione a mano vince sull'orologio, che vince sulla stima**, e
  /// le fonti **non si sommano**: due sorgenti darebbero il doppio su una seduta
  /// registrata due volte.
  ///
  /// ⚠️ Sta qui e non nei due posti che la usano — la card dei numeri e il conto
  /// di quanto sei allenato — perché due copie di una catena di priorità
  /// divergono alla prima modifica, e a quel punto la stessa seduta varrebbe
  /// due numeri diversi nella stessa schermata.
  int? get kcal =>
      kcalCorrettaAMano ? kcalDalleSedute : (kcalDalPolso ?? kcalDalleSedute);

  int? get distanzaMetri {
    var somma = 0;
    var trovato = false;

    for (final a in dalPolso) {
      final d = a.distanzaMetri;
      if (d == null) continue;

      somma += d;
      trovato = true;
    }

    return trovato ? somma : null;
  }

  (DateTime, DateTime) get _estremi {
    DateTime? da;
    DateTime? a;

    void allarga(DateTime inizio, DateTime fine) {
      if (da == null || inizio.isBefore(da!)) da = inizio;
      if (a == null || fine.isAfter(a!)) a = fine;
    }

    for (final s in sedute) {
      allarga(s.startedAt, StoricoUnificato.fineDi(s) ?? s.startedAt);
    }

    for (final w in dalPolso) {
      allarga(w.iniziatoIl, w.finitoIl);
    }

    return (da ?? DateTime(1970), a ?? DateTime(1970));
  }
}

/// Come si mette insieme lo storico — FASE 1-bis, 20/08/2026.
///
/// ── 🚨 La regola, in due righe ────────────────────────────────────────────
///
/// Due registrazioni sono **lo stesso allenamento** se:
///
/// | | Condizione |
/// |---|---|
/// | **(a)** | si sovrappongono, anche solo di un istante |
/// | **(b)** | il buco fra loro è minore di [buchoAmmesso] **e** i tipi sono compatibili |
///
/// E la relazione è **transitiva**: se A tocca B e B tocca C, stanno tutti e
/// tre nella stessa riga.
///
/// ── ⚠️ Il costo, dichiarato e accettato ───────────────────────────────────
///
/// Pesi 17:00–18:01 e corsa 18:00–19:00 diventano **un solo allenamento** per un
/// minuto in comune. 🚨 Il committente l'ha valutato e ha deciso così: *«per i
/// falsi accoppiamenti io non vedo un problema vero […] poi ci mettiamo la
/// possibilità di splittarli e via»*.
///
/// 💡 Ed è una scelta difendibile: una regola che si spiega in una riga vale più
/// di una che indovina meglio ma nessuno sa prevedere — **a patto** che l'errore
/// sia riparabile, che è quello che fa `AllenamentiDaOrologio.staccato`.
abstract final class StoricoUnificato {
  /// Quanto può essere lungo il buco fra due registrazioni contigue.
  ///
  /// 📌 **Dieci minuti**, e il numero viene dal committente: *«dopo dieci minuti
  /// mi ricordo e fermo l'allenamento sull'orologio»*. È il tempo che ci si mette
  /// ad accorgersi di aver lasciato qualcosa acceso, o a rimettere in moto
  /// qualcosa che si era fermato per sbaglio.
  static const buchoAmmesso = Duration(minutes: 10);

  /// Raggruppa sedute e allenamenti in righe di storico, dalla più recente.
  ///
  /// ── 🚨 Chi resta fuori da ogni gruppo, e perché ───────────────────────────
  ///
  /// | Chi | Perché |
  /// |---|---|
  /// | `AllenamentoDaOrologio.nascosto` | non compare affatto |
  /// | `AllenamentoDaOrologio.staccato` | riga sua, **sempre** — è la correzione a mano |
  /// | `WorkoutSession.isOpen` | non è finita: la durata cresce a ogni secondo |
  ///
  /// ⚠️ Una seduta ancora aperta non si può raggruppare perché la decisione
  /// presa adesso potrebbe essere diversa fra un minuto — e nel frattempo
  /// avrebbe già inghiottito la riga di qualcun altro.
  static List<VoceStorico> fondi({
    required List<WorkoutSession> sessioni,
    required List<AllenamentoDaOrologio> dallOrologio,

    /// I nomi delle schede, per **id firmato**.
    ///
    /// 🚨 **Negativo = arrivata in chat, positivo = dal server.** È la stessa
    /// convenzione di `schedeUniteProvider`, e riusarla è quello che permette a
    /// una sola mappa di contenere tutte e due le provenienze.
    Map<int, String> nomiDelleSchede = const {},
  }) {
    final voci = <VoceStorico>[];

    // ── 1. Chi non si raggruppa esce subito, con la sua riga ────────────────
    final daRaggruppare = <_Registrazione>[];

    for (final s in sessioni) {
      if (s.isOpen || fineDi(s) == null) {
        voci.add(VoceStorico(sedute: [s], dalPolso: const []));

        continue;
      }

      daRaggruppare.add(_Registrazione.dallApp(s));
    }

    for (final a in dallOrologio) {
      if (a.nascosto) continue;

      if (a.staccato) {
        voci.add(
          VoceStorico(
            sedute: const [],
            dalPolso: [a],
            nomeScheda: nomiDelleSchede[a.schedaAssegnata],

            // ⚠️ Solo se la scheda **la conosciamo**: un id che non sta fra le
            // schede è un riferimento a qualcosa che non c'è più, e portarselo
            // dietro vorrebbe dire cercarlo invano a ogni ridisegno.
            schedaId: nomiDelleSchede.containsKey(a.schedaAssegnata)
                ? a.schedaAssegnata
                : null,
          ),
        );

        continue;
      }

      daRaggruppare.add(_Registrazione.dalPolso(a));
    }

    // ── 2. Le componenti connesse ───────────────────────────────────────────
    for (final gruppo in _componenti(daRaggruppare)) {
      final sedute =
          gruppo
              .where((r) => r.sessione != null)
              .map((r) => r.sessione!)
              .toList()
            ..sort((a, b) => a.startedAt.compareTo(b.startedAt));

      final polso =
          gruppo
              .where((r) => r.allenamento != null)
              .map((r) => r.allenamento!)
              .toList()
            ..sort((a, b) => a.iniziatoIl.compareTo(b.iniziatoIl));

      /*
       * 💡 La prima scheda assegnata del gruppo. ⚠️ Non si mostrano tutte: se
       * qualcuno ne ha assegnate due a pezzi dello stesso allenamento, mostrarne
       * due direbbe che sono due allenamenti — cioè il contrario di quello che
       * il raggruppamento ha appena stabilito.
       */
      String? nomeScheda;
      int? schedaId;

      for (final a in polso) {
        final nome = nomiDelleSchede[a.schedaAssegnata];

        if (nome == null || nomeScheda != null) continue;

        nomeScheda = nome;
        schedaId = a.schedaAssegnata;
      }

      voci.add(
        VoceStorico(
          sedute: sedute,
          dalPolso: polso,
          nomeScheda: nomeScheda,
          schedaId: schedaId,
        ),
      );
    }

    voci.sort((a, b) => b.quando.compareTo(a.quando));

    return voci;
  }

  /// La fine di una seduta, se si può sapere.
  ///
  /// ⚠️ `null` quando non c'è né `endedAt` né `durationMinutes`: senza un
  /// intervallo non si può dire se tocca qualcosa, e **inventarglielo sarebbe
  /// peggio che lasciarla sola** — si finirebbe ad attaccarle l'allenamento
  /// sbagliato.
  static DateTime? fineDi(WorkoutSession s) {
    if (s.endedAt != null) return s.endedAt;

    final minuti = s.durationMinutes;
    if (minuti == null) return null;

    return s.startedAt.add(Duration(minutes: minuti));
  }

  /// Se due registrazioni sono lo stesso allenamento.
  ///
  /// 🚨 **La compatibilità di tipo vale SOLO sul buco, non sulla
  /// sovrapposizione.** Se si sovrappongono è lo stesso allenamento e basta: è
  /// la decisione del committente, e metterci in mezzo il tipo la
  /// contraddirebbe.
  ///
  /// 💡 Sul buco invece il tipo serve: due sessioni consecutive di dieci minuti
  /// l'una — corsa e poi bici — sono due allenamenti, e senza il tipo
  /// diventerebbero uno.
  ///
  /// ⚠️ Una seduta dell'app **non ha un tipo** (`tipo == null`): l'orologio sa
  /// che stavi correndo, il player sa solo che stavi usando una scheda. Un
  /// `null` è compatibile con tutto, o una ripresa dell'app non si riattaccherebbe
  /// mai a niente.
  static bool _stessoAllenamento(_Registrazione a, _Registrazione b) {
    // Sovrapposizione: basta un istante.
    if (a.inizio.isBefore(b.fine) && b.inizio.isBefore(a.fine)) return true;

    final buco = a.fine.isBefore(b.inizio)
        ? b.inizio.difference(a.fine)
        : a.inizio.difference(b.fine);

    if (buco >= buchoAmmesso) return false;

    return a.tipo == null || b.tipo == null || a.tipo == b.tipo;
  }

  /// Le componenti connesse, con un union-find in piena regola.
  ///
  /// ── ⚠️ Perché non una passata sola ordinata per inizio ────────────────────
  ///
  /// Perché con la regola del buco **la catena si può riaprire**. Corsa
  /// 18:00–18:30, bici 18:32–18:35, corsa 18:36–19:00: la bici rompe la
  /// contiguità di tipo, ma le due corse distano sei minuti e vanno insieme. Una
  /// passata che chiude il gruppo appena qualcosa non combacia se la perde.
  ///
  /// 💡 `n²` su una lista che l'archivio limita a 200 righe è **quarantamila
  /// confronti di date**: non vale la pena essere furbi per risparmiarli.
  static List<List<_Registrazione>> _componenti(List<_Registrazione> tutte) {
    final padre = List<int>.generate(tutte.length, (i) => i);

    int radice(int i) {
      while (padre[i] != i) {
        padre[i] = padre[padre[i]];
        i = padre[i];
      }

      return i;
    }

    for (var i = 0; i < tutte.length; i++) {
      for (var j = i + 1; j < tutte.length; j++) {
        if (!_stessoAllenamento(tutte[i], tutte[j])) continue;

        padre[radice(i)] = radice(j);
      }
    }

    final gruppi = <int, List<_Registrazione>>{};

    for (var i = 0; i < tutte.length; i++) {
      gruppi.putIfAbsent(radice(i), () => []).add(tutte[i]);
    }

    return gruppi.values.toList();
  }
}

/// Una registrazione qualunque, ridotta a quello che serve per raggrupparla.
///
/// 💡 Esiste per non scrivere due volte la stessa regola: al raggruppamento non
/// importa da dove viene un intervallo, importa **dove comincia, dove finisce e
/// che tipo è**.
class _Registrazione {
  _Registrazione.dallApp(WorkoutSession s)
    : sessione = s,
      allenamento = null,
      inizio = s.startedAt,
      fine = StoricoUnificato.fineDi(s)!,
      // ⚠️ Il player non sa che tipo di attività stai facendo: sa che scheda
      // stai usando. Per il raggruppamento è come non avere un tipo.
      tipo = null;

  _Registrazione.dalPolso(AllenamentoDaOrologio a)
    : sessione = null,
      allenamento = a,
      inizio = a.iniziatoIl,
      fine = a.finitoIl,
      tipo = a.tipo;

  final WorkoutSession? sessione;
  final AllenamentoDaOrologio? allenamento;
  final DateTime inizio;
  final DateTime fine;
  final String? tipo;
}
