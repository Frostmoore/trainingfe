/// Una palestra o un trainer nel catalogo pubblico — Parte M, 18/08/2026.
///
/// ── 🚨 Non c'è nessun `userId`, ed è voluto ────────────────────────────────
///
/// Per aprire una conversazione si manda **l'id della scheda**, e chi sia il
/// destinatario lo decide il server. ⚠️ Se il catalogo pubblicasse
/// l'identificativo del titolare, darebbe a chiunque — senza autenticazione —
/// l'elenco degli id di tutti i proprietari di palestra: un pezzo che all'app
/// non serve e che serve a chi vuole provare a indovinare qualcos'altro.
class SchedaCatalogo {
  const SchedaCatalogo({
    required this.id,
    required this.titolo,
    required this.tipo,
    required this.sponsorizzato,
    required this.contattabile,
    this.comune,
    this.distanzaKm,
    this.descrizione,
  });

  factory SchedaCatalogo.fromJson(Map<String, dynamic> j) => SchedaCatalogo(
    id: (j['id'] as num).toInt(),
    titolo: j['titolo'] as String? ?? '',
    tipo: j['tipo'] as String? ?? 'palestra',

    /*
     * 🚨 **`sponsorizzato` arriva sempre, anche quando è `false`.**
     *
     * ⚠️ Il `?? false` qui è una rete, non il comportamento normale: il server
     * lo manda sempre proprio perché un campo che compare solo quando vale
     * `true` è un campo che l'app può dimenticarsi di leggere — finché un
     * giorno qualcuno paga e nessuno lo etichetta. Presentare a pagamento
     * qualcosa che sembra un risultato di ricerca è pubblicità occulta.
     */
    sponsorizzato: j['sponsorizzato'] as bool? ?? false,

    /*
     * 💡 Se non è contattabile — una palestra senza proprietario attivo — l'app
     * lo deve dire **prima** che qualcuno scriva un messaggio che non
     * arriverebbe da nessuna parte.
     */
    contattabile: j['contattabile'] as bool? ?? true,
    comune: j['comune'] as String?,
    distanzaKm: (j['distanza_km'] as num?)?.toDouble(),
    descrizione: j['descrizione'] as String?,
  );

  final int id;
  final String titolo;

  /// `palestra` oppure `trainer`.
  final String tipo;

  final bool sponsorizzato;
  final bool contattabile;

  /// «Bologna (BO)», già pronto: la provincia c'è sempre perché ci sono otto
  /// comuni che si chiamano `Castro`.
  final String? comune;

  /// `null` per chi non ha detto in che città sta: la distanza non si sa, e
  /// **non è zero**.
  final double? distanzaKm;

  final String? descrizione;

  bool get ePalestra => tipo == 'palestra';

  /// Come si scrive la distanza. `null` quando non si sa: chi legge deve
  /// mostrare **niente**, non «0 km».
  String? get distanzaLeggibile {
    final d = distanzaKm;
    if (d == null) return null;
    if (d < 1) return 'qui vicino';
    return '${d.toStringAsFixed(d < 10 ? 1 : 0).replaceAll('.', ',')} km';
  }
}

/// Il permesso di scrivere, come lo racconta il server — M3.4.
///
/// ── 🚨 Perché non è un `bool` ──────────────────────────────────────────────
///
/// Perché i «no» non sono tutti uguali, e l'app deve trattarli in modo diverso:
/// *«hai finito i tre messaggi»* → si propone **l'abbonamento**; *«è un
/// dipendente»* → non c'è niente da comprare, si spiega e basta.
///
/// ⚠️ Con un `bool` l'app potrebbe solo scrivere «non puoi», e la persona
/// resterebbe a chiedersi cosa ha sbagliato.
class PermessoDiScrivere {
  const PermessoDiScrivere({
    required this.consentito,
    required this.proponiAbbonamento,
    this.codice,
    this.spiegazione,
    this.restanti,
  });

  factory PermessoDiScrivere.fromJson(Map<String, dynamic> j) =>
      PermessoDiScrivere(
        consentito: j['consentito'] as bool? ?? false,
        proponiAbbonamento: j['proponi_abbonamento'] as bool? ?? false,
        codice: j['codice'] as String?,
        spiegazione: j['spiegazione'] as String?,
        restanti: (j['restanti'] as num?)?.toInt(),
      );

  final bool consentito;

  /// 🚨 Vero **solo** quando i tre messaggi sono finiti. Fuori da quel caso non
  /// c'è niente da vendere: proporre l'abbonamento a chi non può scrivere a un
  /// trainer dipendente sarebbe vendergli una cosa che non risolve il suo
  /// problema.
  final bool proponiAbbonamento;

  final String? codice;
  final String? spiegazione;

  /// 🚨 `null` vuol dire **senza limite**, che è diverso da zero. Un `?? 0`
  /// scritto di fretta trasformerebbe un abbonato in uno bloccato.
  final int? restanti;

  bool get haUnLimite => restanti != null;
}
