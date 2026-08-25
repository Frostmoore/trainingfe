/// Cosa dice una prescrizione della scheda — 3b-C.5, 25/08/2026.
///
/// ══ 📌 PERCHÉ SERVE LEGGERLA ══════════════════════════════════════════════
///
/// *«se gli ho assegnato una scheda, vuol dire che in quell'allenamento ho usato
/// la scheda. Quindi va usata quella, anche per i pesi e per i muscoli
/// coinvolti»*.
///
/// ⚠️ Un allenamento visto solo dall'orologio non ha serie registrate, ma se ci
/// hai attaccato una scheda **si sa cosa hai fatto**: quattro serie da dodici a
/// quaranta chili sono novecentosessanta chili sollevati, e quel numero è molto
/// più vicino alla verità di un trattino.
///
/// ⛔ **La prescrizione è una stringa** — `'4 × 12'` — e arriva già formattata
/// dal server: `PlanExercise` non ha `sets` e `reps` separati. Rileggerla è
/// l'unico modo, e questo file è l'unico posto in cui si fa.
library;

/// Le serie e le ripetizioni lette da una prescrizione.
class Prescrizione {
  const Prescrizione({this.serie, this.ripetizioni});

  /// Legge `'4 × 12'`, `'3x8-12'`, `'4 × cedimento'`, `'3'`.
  ///
  /// ⚠️ **Il separatore può essere `×` o `x`**: il primo lo scrive il server, il
  /// secondo lo scrive chi digita a mano su una tastiera che il `×` non ce
  /// l'ha.
  ///
  /// 🚨 **Di un intervallo si prende il numero PIÙ BASSO.** `'8-12'` diventa 8:
  /// è la stessa prudenza dei MET — sovrastimare il lavoro fatto porta a
  /// credersi più avanti di dove si è.
  factory Prescrizione.leggi(String? testo) {
    if (testo == null || testo.trim().isEmpty) return const Prescrizione();

    final pezzi = testo.toLowerCase().split(RegExp('[×x]'));

    int? primoNumero(String s) {
      final m = RegExp(r'\d+').firstMatch(s);

      return m == null ? null : int.tryParse(m.group(0)!);
    }

    final serie = primoNumero(pezzi.first);

    // 💡 `'4 × cedimento'` ha le serie e non le ripetizioni, ed è un caso vero:
    // il numero di serie resta utile anche senza.
    final ripetizioni = pezzi.length > 1 ? primoNumero(pezzi[1]) : null;

    return Prescrizione(serie: serie, ripetizioni: ripetizioni);
  }

  final int? serie;
  final int? ripetizioni;

  /// I chili che quell'esercizio vale, con il carico previsto.
  ///
  /// ⚠️ `null` quando manca un pezzo: senza serie, senza ripetizioni o senza
  /// carico non c'è un volume da dichiarare, e **zero sarebbe una bugia
  /// precisa**. È la stessa regola di `EsercizioFatto.volume`.
  double? volumeCon(double? carico) {
    final s = serie;
    final r = ripetizioni;

    if (s == null || r == null || carico == null || carico <= 0) return null;

    return s * r * carico;
  }
}
