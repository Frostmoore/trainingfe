/// La progressione di un esercizio — 3b-I.A, 27/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// 📌 *«nella pagina della scheda possiamo mettere un grafico che indica i
/// progressi solo a chi è abbonato, con sotto un'analisi da parte dell'ai …
/// facciamoglielo fare una sola volta per scheda con tutti gli esercizi insieme
/// poi li dividiamo noi»*.
///
/// ══ ⚖️ IL CONFINE LEGALE, CHE DECIDE LA FORMA DI TUTTO ════════════════════
///
/// 📌 *«legalmente 1 e 3 non si possono fare, serve un medico»* — la
/// progressione automatica dei carichi e le alternative agli esercizi.
///
/// ⛔ Quindi qui non esiste **nessun** tipo che rappresenti un consiglio: non
/// c'è un «carico suggerito», non c'è un «prossimo obiettivo». C'è
/// [Andamento] — cosa è successo — e una frase che lo racconta. 🚨 Un campo in
/// più in questo file sarebbe il primo passo per riempirlo.
///
/// ══ 🚨 QUESTO FILE NON PARLA CON NESSUNO ══════════════════════════════════
///
/// Niente rete, niente database, niente widget: solo tipi e funzioni pure. 💡 È
/// il motivo per cui [improntaDelloStorico] si può provare con un test invece
/// che con un telefono.
library;

/// Cosa è successo a un esercizio.
///
/// 🚨 **Un enum e non la frase.** Il colore della sparkline si decide da qui: se
/// dipendesse dal testo italiano cambierebbe ogni volta che il modello sceglie
/// un sinonimo, e nessuno capirebbe perché.
enum Andamento {
  inSalita('in_salita'),
  fermo('fermo'),
  inCalo('in_calo'),

  /// ⚠️ **Non è un errore, è una risposta.** Con meno di due sedute non c'è
  /// niente da dire, e dirlo è meglio che mostrare una sparkline di un punto —
  /// che sembrerebbe una linea piatta, cioè «sei fermo».
  pocoStorico('poco_storico');

  const Andamento(this.chiave);

  /// Il valore che viaggia sulla rete, uguale all'`enum` dello schema JSON.
  final String chiave;

  /// ⛔ Nessun ripiego silenzioso su [inSalita] o [fermo]: una chiave che non
  /// conosciamo diventa «non lo so», che è l'unica cosa vera.
  static Andamento da(String? chiave) {
    for (final a in Andamento.values) {
      if (a.chiave == chiave) return a;
    }

    return Andamento.pocoStorico;
  }
}

/// Un punto della storia di un esercizio: la **serie migliore** di una seduta.
class PuntoDiProgressione {
  const PuntoDiProgressione({
    required this.data,
    this.carico,
    this.ripetizioni,
  });

  final DateTime data;

  /// In kg. `null` per gli esercizi a corpo libero.
  final double? carico;

  final int? ripetizioni;

  /// Questo punto è «migliore» dell'altro?
  ///
  /// 🚨 **Prima il carico, poi le ripetizioni**, e non una formula che li
  /// mescola: un volume calcolato (`kg × reps`) direbbe che 40 kg × 12 batte
  /// 60 kg × 6, il che è vero per il volume e falso per come le persone
  /// leggono i propri progressi. ⛔ Un numero che nessuno riconosce è peggio di
  /// un numero grezzo.
  bool batte(PuntoDiProgressione altro) {
    final mio = carico ?? -1;
    final suo = altro.carico ?? -1;

    if (mio != suo) return mio > suo;

    return (ripetizioni ?? -1) > (altro.ripetizioni ?? -1);
  }

  /// Il valore da disegnare sulla sparkline.
  ///
  /// 💡 Il carico se c'è, altrimenti le ripetizioni: a corpo libero la
  /// progressione **sono** le ripetizioni, e una sparkline vuota direbbe che
  /// non è successo niente.
  double? get valore => carico ?? ripetizioni?.toDouble();

  /// Come viaggia verso il server.
  ///
  /// ⚠️ **Solo data, carico e ripetizioni.** Non il nome dell'esercizio, non le
  /// note, non l'ora esatta: quello che non serve alla risposta non deve uscire
  /// dal telefono — *«tutti i dati che possono essere anche LONTANAMENTE
  /// sensibili devono restare solo on-device»*.
  Map<String, Object?> versoIlServer() => {
    'data': data.toIso8601String().substring(0, 10),
    'carico': carico,
    'ripetizioni': ripetizioni,
  };
}

/// La riga che l'AI ha scritto per un esercizio.
class ProgressoEsercizio {
  const ProgressoEsercizio({
    required this.esercizioId,
    required this.andamento,
    required this.riga,
  });

  factory ProgressoEsercizio.daJson(Map<String, Object?> j) =>
      ProgressoEsercizio(
        esercizioId: (j['id'] as num?)?.toInt() ?? 0,
        andamento: Andamento.da(j['andamento'] as String?),
        riga: (j['riga'] as String?) ?? '',
      );

  final int esercizioId;
  final Andamento andamento;

  /// ⚠️ Può essere **vuota**, e va gestito: il setaccio del server la svuota
  /// quando la frase prescriveva qualcosa. La sparkline resta, la frase no.
  final String riga;

  Map<String, Object?> aJson() => {
    'id': esercizioId,
    'andamento': andamento.chiave,
    'riga': riga,
  };
}

/// L'impronta dello storico su cui un'analisi è stata scritta — 3b-I.A.
///
/// ══ 🚨 A COSA SERVE ═══════════════════════════════════════════════════════
///
/// A rispondere a *«è ancora attuale?»* senza chiedere niente a nessuno. ⚠️ Con
/// la sola data non si distinguerebbe **«vecchia di un mese ma ancora vera»**
/// (non ti sei allenato) da **«di ieri e già superata»** (ti sei allenato due
/// volte): la prima non va rigenerata, la seconda sì.
///
/// ── 💡 Perché conta i punti e l'ultima data, e non i valori ──────────────
///
/// Perché quello che rende un'analisi vecchia è **una seduta nuova**, non un
/// numero corretto a mano. ⛔ Includere i carichi vorrebbe dire invalidare
/// l'analisi perché qualcuno ha sistemato un refuso su una serie di marzo — e
/// far ripagare un gettone per una cosa che non cambia una parola.
///
/// ⚠️ **Nessun `hashCode`**: `Object.hashAll` non è stabile fra esecuzioni
/// diverse su tutte le piattaforme, e un'impronta che cambia da sola farebbe
/// rigenerare l'analisi a ogni avvio — cioè spendere un gettone a ogni avvio.
/// Questa è una stringa, e resta uguale a se stessa per sempre.
String improntaDelloStorico(Map<int, List<PuntoDiProgressione>> storia) {
  final pezzi = <String>[];

  // 🚨 Ordinata: una mappa non promette l'ordine, e due impronte diverse per lo
  // stesso storico sono esattamente il difetto che questa funzione previene.
  final ids = storia.keys.toList()..sort();

  for (final id in ids) {
    final punti = storia[id]!;

    if (punti.isEmpty) continue;

    final ultimo = punti.last.data.millisecondsSinceEpoch;

    pezzi.add('$id:${punti.length}:$ultimo');
  }

  return pezzi.join('|');
}

/// Ci sono abbastanza sedute per avere qualcosa da dire?
///
/// ⛔ **Due, non una.** Con una seduta sola non esiste nessuna progressione: si
/// pagherebbe un gettone per far scrivere «hai fatto un allenamento», che chi
/// guarda sa già.
bool valeLaPenaAnalizzare(Map<int, List<PuntoDiProgressione>> storia) =>
    storia.values.any((punti) => punti.length >= 2);
