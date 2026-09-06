/// Quanto sei **reattivo adesso** — il modello a tre processi, 06/09/2026.
///
/// ══ 📌 DA DOVE VIENE ══════════════════════════════════════════════════════
///
/// Il committente, il 06/09/2026: *«subito dopo aver mangiato sono meno
/// "reattivo" che dopo un paio d'ore che sto in piedi, e dopo che ho fatto un
/// bel pisolino di due ore sono molto più reattivo di quanto io lo sia a fine
/// serata in un giorno che non ho riposato. Deve essere un valore che cambia
/// durante la giornata, in base proprio a quanto sono reattivi gli esseri umani
/// di media»*. E: *«cerca anche su internet come si fa a calcolare questa cosa,
/// e usa quello»*.
///
/// 💡 Quella cosa esiste, si studia da quarant'anni e si chiama **modello a tre
/// processi della regolazione dell'allerta** (Åkerstedt & Folkard). È lo stesso
/// impianto che usano i sistemi di gestione del rischio-fatica di aviazione e
/// trasporti.
///
/// I parametri qui sotto sono quelli **pubblicati e validati** in Ingre, Van
/// Leeuwen et al., *Validating and Extending the Three Process Model of
/// Alertness in Airline Operations*, PLOS ONE 2014 — non numeri inventati da
/// noi. 🚨 Dove abbiamo aggiunto qualcosa di nostro è **detto riga per riga**.
///
/// ══ 🚨 NON E' UNA BATTERIA, ED E' IL PUNTO ════════════════════════════════
///
/// 📌 *«non ha molto senso mostrare entrambi i valori perché non è una
/// "batteria", è più un tachimetro che mostra quanto sono reattivo in quel
/// momento»*.
///
/// ⛔ Quindi **non ha un "mattina" e un "adesso"** come [CaricaBatteria]: ha un
/// valore solo, quello di adesso. La Carica dice *quanta capacità ti resta*
/// nella giornata; questa dice *quanto sei sveglio in questo istante*, e le due
/// cose vanno in direzioni diverse — alle sette del mattino la Carica è piena e
/// la reattività è bassa, perché ti sei appena alzato.
///
/// ══ ⚠️ E NON E' UNA MISURA MEDICA ═════════════════════════════════════════
///
/// Il modello predice l'allerta **media di una popolazione**, con un errore
/// residuo dichiarato di 1,42 punti sulla scala KSS. 🚨 Non sa niente di
/// caffeina, di farmaci, di quanto è interessante quello che stai facendo. È una
/// stima, e l'interfaccia deve dirlo.
library;

import 'dart:math' as math;

/// I quattro processi, e quello che ne esce.
///
/// 💡 Si tengono separati invece di restituire un numero solo perché la
/// schermata deve poter dire **perché**: «sei basso perché ti sei appena
/// svegliato» è un'informazione, «sei a 34» non lo è.
class Reattivita {
  const Reattivita({
    required this.valore,
    required this.omeostatico,
    required this.circadiano,
    required this.ultradiano,
    required this.inerzia,
    required this.modificatori,
    required this.motivo,
  });

  /// `0–100`. 🚨 La scala è **nostra**: il modello lavora su 1–16 e da lì si
  /// passa alla KSS. Vedi [_suCento].
  final double valore;

  final double omeostatico;
  final double circadiano;
  final double ultradiano;
  final double inerzia;

  /// Quanto hanno spostato HRV, battito e carico rispetto al modello medio.
  final double modificatori;

  /// La ragione principale, se ce n'è una che spicca.
  final MotivoDellaReattivita? motivo;
}

/// Perché sei così adesso — serve alla schermata, non al calcolo.
enum MotivoDellaReattivita {
  appenaSvegliato,
  dopoIlPasto,
  notteCorta,
  troppeOreInPiedi,
  cadutaCircadiana,
  caricoAllenamento,
}

abstract final class ModelloDellaReattivita {
  // ───────────────────────── i parametri pubblicati ────────────────────────
  //
  // 🚨 **Non si toccano a occhio.** Vengono da un modello validato contro
  // misure vere (r² > 0.70 su sonnolenza soggettiva e alfa-EEG). ⚠️ Cambiarne
  // uno per far tornare un numero che «sembra giusto» vuol dire buttare via la
  // validazione e tenersi la formula.

  /// L'asintoto alto del processo omeostatico.
  static const asintotoAlto = 14.3;

  /// L'asintoto basso: dove finisce l'allerta restando svegli all'infinito.
  static const asintotoBasso = 2.4;

  /// La costante di decadimento della veglia, per ora.
  static const decadimentoVeglia = 0.0353;

  /// La costante di recupero del sonno, per ora.
  ///
  /// 💡 **Dieci volte più rapida** del decadimento: si perde allerta piano
  /// stando svegli e la si riprende in fretta dormendo. È il motivo per cui un
  /// pisolino di due ore fa la differenza che fa.
  static const recuperoSonno = 0.3813;

  /// L'ampiezza del ritmo circadiano.
  static const ampiezzaCircadiana = 2.5;

  /// L'ora del **picco** circadiano di allerta: le 16:48.
  ///
  /// ⚠️ Non è un errore che sia di pomeriggio: il minimo circadiano cade nel
  /// cuore della notte, e il massimo dodici ore dopo.
  static const acrofase = 16.8;

  /// L'ampiezza dell'onda ultradiana (periodo 12 ore).
  static const ampiezzaUltradiana = 0.5;

  static const mesorUltradiano = -0.5;

  /// Quanto l'inerzia del risveglio toglie **nell'istante** in cui ci si sveglia.
  ///
  /// 🚨 È grossa: −5,72 su una scala che vale ~12 punti in tutto. 💡 È la
  /// ragione per cui appena svegli si è inutilizzabili anche dopo nove ore di
  /// sonno, ed è il terzo processo che il modello a due non spiegava.
  static const inerziaAlRisveglio = -5.72;

  /// Quanto in fretta l'inerzia svanisce, per ora.
  ///
  /// 💡 `1.51` vuol dire che dopo un'ora ne resta il 22%, dopo due il 5%.
  static const decadimentoInerzia = 1.51;

  // ───────────────────────── quello che ci mettiamo noi ────────────────────

  /// Quanto pesa il **pasto vero** sulla reattività.
  ///
  /// ══ 🚨 QUESTO NON E' NEL MODELLO, ED E' UN'AGGIUNTA NOSTRA ═════════════
  ///
  /// 📌 *«subito dopo aver mangiato sono meno reattivo»*. Il modello a tre
  /// processi la sonnolenza post-prandiale ce l'ha, ma dentro l'**onda
  /// ultradiana**: cioè come un avvallamento che cade sempre alla stessa ora,
  /// più o meno all'ora di pranzo.
  ///
  /// 💡 **Noi sappiamo di più**: il diario è sul telefono, e sappiamo *quando* e
  /// *quanto* ha mangiato davvero. Un pranzo alle 15:30 abbassa la reattività
  /// alle 16:30, non alle 14 — e una cena da 1.200 kcal pesa più di un'insalata.
  ///
  /// ⚠️ **Vale 2 punti al massimo**, meno dell'ampiezza circadiana: è un
  /// avvallamento, non un crollo.
  static const pesoDelPasto = 2.0;

  /// Le kcal oltre le quali il pasto pesa tutto il suo peso.
  ///
  /// 💡 Ottocento: un pasto abbondante. Sotto, il peso scala in proporzione.
  static const kcalDiUnPastoPieno = 800.0;

  /// Quanto dura la digestione «pesante», in ore.
  ///
  /// ⚠️ Il minimo è a **un'ora** dal pasto, e a tre è passata.
  static const oreDelPasto = 3.0;

  /// Quanto pesano HRV e battito, per punto di z-score.
  ///
  /// 🚨 **Poco, e di proposito.** Il modello descrive l'essere umano medio; HRV
  /// e battito dicono se **oggi** sei sopra o sotto il tuo normale. ⛔ Lasciarli
  /// dominare vorrebbe dire buttare la parte validata e tenersi il rumore di due
  /// sensori da polso.
  static const pesoFisiologia = 0.6;

  /// Quanto pesa il carico di allenamento recente.
  static const pesoDelCarico = 1.2;

  // ───────────────────────── i processi ────────────────────────────────────

  /// **S** — l'omeostatico: cala stando svegli, risale dormendo.
  ///
  /// Al risveglio vale [sveglioA], poi decade verso [asintotoBasso].
  ///
  /// 💡 È questo che distingue *«fine serata in un giorno che non ho riposato»*
  /// da *«due ore in piedi»*: sedici ore di veglia e cinque di sonno lasciano S
  /// molto più in basso.
  static double omeostatico({required double oreSveglio, double? sveglioA}) {
    final partenza = sveglioA ?? asintotoAlto;

    return asintotoBasso +
        (partenza - asintotoBasso) *
            math.exp(-decadimentoVeglia * math.max(oreSveglio, 0));
  }

  /// Quanto vale S **al risveglio**, dopo aver dormito [oreDormite].
  ///
  /// 🚨 Si riparte da dove si era arrivati la sera ([seraA]) e si risale verso
  /// [asintotoAlto]. ⛔ Ripartire sempre da 14,3 vorrebbe dire che dormire tre
  /// ore o nove è lo stesso — cioè togliere metà del senso al modello.
  static double alRisveglio({required double oreDormite, double? seraA}) {
    final partenza = seraA ?? asintotoBasso;

    return asintotoAlto -
        (asintotoAlto - partenza) *
            math.exp(-recuperoSonno * math.max(oreDormite, 0));
  }

  /// **C** — il circadiano: dipende **solo** dall'ora, non da come hai vissuto.
  ///
  /// ⚠️ È la parte che fa scendere la reattività alle tre di notte anche a chi
  /// ha dormito tutto il giorno, ed è giusto così.
  static double circadiano(double oraDecimale) =>
      ampiezzaCircadiana *
      math.cos(2 * math.pi * (oraDecimale - acrofase) / 24);

  /// **U** — l'ultradiano: il secondo avvallamento, periodo 12 ore.
  static double ultradiano(double oraDecimale) =>
      mesorUltradiano +
      ampiezzaUltradiana *
          math.cos(2 * math.pi * (oraDecimale - acrofase) / 12);

  /// **W** — l'inerzia del risveglio.
  ///
  /// 🚨 **È la ragione per cui il pisolino funziona come dice il committente**:
  /// appena sveglio sei peggio di prima, e dopo un'ora sei molto meglio. ⛔ Senza
  /// questo processo un sonnellino risulterebbe un guadagno immediato, e chi si
  /// alza intontito penserebbe che il numero è rotto.
  static double inerzia(double oreDaSveglio) =>
      inerziaAlRisveglio *
      math.exp(-decadimentoInerzia * math.max(oreDaSveglio, 0));

  /// L'avvallamento del pasto **vero**, non quello dell'orologio.
  ///
  /// ⚠️ `0` se non si sa quando si è mangiato: non si inventa una digestione.
  static double dopoIlPasto({
    required double? oreDalPasto,
    required double? kcalDelPasto,
  }) {
    if (oreDalPasto == null || oreDalPasto < 0 || oreDalPasto > oreDelPasto) {
      return 0;
    }

    /*
     * 💡 Una campana: zero all'istante del pasto, minimo dopo un'ora, di nuovo
     * zero a tre. ⛔ Un gradino direbbe che alle 2h59 sei intontito e alle 3h01
     * sei perfetto.
     */
    final forma = math.sin(math.pi * oreDalPasto / oreDelPasto);

    final quanto = kcalDelPasto == null
        ? 0.5
        : (kcalDelPasto / kcalDiUnPastoPieno).clamp(0.0, 1.0);

    return -pesoDelPasto * forma * quanto;
  }

  // ───────────────────────── il conto ──────────────────────────────────────

  /// Tutto insieme, su `0–100`.
  ///
  /// [oreSveglio] e [oreDormite] vengono dal sonno registrato; [oraDecimale] è
  /// l'ora locale con i minuti (`14.5` = le 14:30).
  ///
  /// 🚨 `zHrv` e `zBattito` arrivano **già nel verso naturale** (positivo =
  /// valore alto): l'inversione del battito la fa questa funzione, in un posto
  /// solo. ⚠️ È lo stesso errore di segno che `IndiciDiForma` documenta, e
  /// darebbe una reattività che sale quando dovrebbe scendere.
  static Reattivita calcola({
    required double oraDecimale,
    required double oreSveglio,
    double? oreDormite,
    double? oreDalPasto,
    double? kcalDelPasto,
    double? zHrv,
    double? zBattito,
    double? zCarico,
  }) {
    final sveglioA = oreDormite == null
        ? null
        : alRisveglio(oreDormite: oreDormite);

    final s = omeostatico(oreSveglio: oreSveglio, sveglioA: sveglioA);
    final c = circadiano(oraDecimale);
    final u = ultradiano(oraDecimale);
    final w = inerzia(oreSveglio);
    final pasto = dopoIlPasto(
      oreDalPasto: oreDalPasto,
      kcalDelPasto: kcalDelPasto,
    );

    final fisiologia = <double>[
      ?zHrv,
      // 🚨 Invertito: battito sopra la media personale = peggio.
      if (zBattito != null) -zBattito,
    ];

    final daFisiologia = fisiologia.isEmpty
        ? 0.0
        : pesoFisiologia *
              (fisiologia.reduce((a, b) => a + b) / fisiologia.length).clamp(
                -2.0,
                2.0,
              );

    /*
     * ⚠️ **Il carico conta solo in negativo.** Allenarsi tanto stanca; non
     * allenarsi non rende più reattivi, rende solo meno allenati — che è
     * un'altra cosa e la dice la Stanchezza.
     */
    final daCarico = zCarico == null
        ? 0.0
        : -pesoDelCarico * math.max(zCarico, 0).clamp(0.0, 2.0);

    final modificatori = daFisiologia + daCarico + pasto;

    return Reattivita(
      valore: _suCento(s + c + u + w + modificatori),
      omeostatico: s,
      circadiano: c,
      ultradiano: u,
      inerzia: w,
      modificatori: modificatori,
      motivo: _motivo(
        inerzia: w,
        pasto: pasto,
        circadiano: c,
        oreSveglio: oreSveglio,
        oreDormite: oreDormite,
        daCarico: daCarico,
      ),
    );
  }

  /// Dalla scala del modello alla nostra.
  ///
  /// ══ ⚠️ QUESTA PARTE E' NOSTRA, E VA DETTO ═════════════════════════════
  ///
  /// Il modello produce un'allerta intorno a `1–16`, che la letteratura converte
  /// in KSS con `KSS = 9.68 − 0.46 × allerta`. 🚨 La KSS è una scala di
  /// **sonnolenza** da 1 a 9, dove **basso è meglio**: mostrarla così com'è
  /// vorrebbe dire un numero che scende quando le cose migliorano.
  ///
  /// 💡 Quindi si rovescia e si porta su cento, con `1` → 0 e `9` → 100
  /// **al contrario**. ⛔ I numeri in mezzo sono una scelta di presentazione,
  /// esattamente come la scala della Prontezza vecchia — e come quella, va
  /// dichiarato invece di far finta che sia una misura.
  static double _suCento(double allerta) {
    final kss = (9.68 - 0.46 * allerta).clamp(1.0, 9.0);

    // 💡 KSS 1 (sveglissimo) → 100; KSS 9 (lotta col sonno) → 0.
    return ((9 - kss) / 8 * 100).clamp(0.0, 100.0);
  }

  /// 🚨 **Si sceglie il più grosso, non il primo che capita.** Un motivo
  /// sbagliato è peggio di nessun motivo: manda a cercare la causa dalla parte
  /// opposta.
  static MotivoDellaReattivita? _motivo({
    required double inerzia,
    required double pasto,
    required double circadiano,
    required double oreSveglio,
    required double? oreDormite,
    required double daCarico,
  }) {
    final candidati = <MotivoDellaReattivita, double>{
      if (inerzia < -1) MotivoDellaReattivita.appenaSvegliato: -inerzia,
      if (pasto < -0.5) MotivoDellaReattivita.dopoIlPasto: -pasto,
      if (circadiano < -1) MotivoDellaReattivita.cadutaCircadiana: -circadiano,
      if (oreDormite != null && oreDormite < 6)
        MotivoDellaReattivita.notteCorta: (6 - oreDormite),
      if (oreSveglio > 14)
        MotivoDellaReattivita.troppeOreInPiedi: (oreSveglio - 14) / 2,
      if (daCarico < -0.5) MotivoDellaReattivita.caricoAllenamento: -daCarico,
    };

    if (candidati.isEmpty) return null;

    return candidati.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
