/// La stima del modello, **prima** che diventi diario — A4.8.
///
/// ── 🚨 Perché questi modelli sono nati il 12/08/2026 ──────────────────────
///
/// Il committente ha chiesto perché il modello non avesse capito che una
/// cotoletta di pollo è impanata. La risposta è che **non lo aveva capito e lo
/// aveva scritto**: nella sua `note` c'era *«non è stato specificato se sono
/// panate, il grado di cottura o il metodo di preparazione»*.
///
/// ⚠️ Quel testo viaggiava sul filo — il backend lo rimanda in `estimate.note`
/// in ogni risposta, salvata o no — arrivava sul telefono e **veniva buttato**:
/// prima di oggi la parola `confidence` non compariva in nessun file dell'app.
///
/// 🚨 E la regola esisteva già, scritta in `FoodEstimate` lato server dal primo
/// giorno: *«`confidence` non è decorazione: sotto una soglia l'app deve
/// chiedere conferma invece di scrivere nel diario»*. È **la dodicesima** regola
/// scritta da qualche parte e mai eseguita da una riga di codice.
library;

double? _num(Object? v) => v == null ? null : (v as num).toDouble();

/// Quanto il modello dice di fidarsi di sé.
///
/// 🚨 **La confidenza da sola non basta e non va usata come cancello.** Sulla
/// cotoletta il modello ha risposto **0.85** — cioè «alta» — *mentre* scriveva
/// nella nota di non sapere se fosse impanata. La regola 8 del prompt dice che
/// un'ambiguità vale meno di 0.6, e il modello non l'ha rispettata.
///
/// 💡 Per questo il foglio di conferma **mostra sempre la nota** e usa la
/// confidenza solo per decidere quanto insistere. Il segnale affidabile è il
/// testo, non il numero.
enum LivelloConfidenza {
  /// Alimenti e quantità precisi: si può confermare a colpo d'occhio.
  alta('Stima sicura'),

  /// Alimenti chiari, quantità stimate dal modello.
  media('Quantità stimate'),

  /// Descrizione ambigua o piatto composito: qui si guarda davvero.
  bassa('Stima incerta');

  const LivelloConfidenza(this.etichetta);

  final String etichetta;

  /// Le soglie sono quelle del prompt (`Prompts::FOOD_SYSTEM`, regola 8).
  ///
  /// ⚠️ Se cambiano di là devono cambiare di qua: due scale diverse per lo
  /// stesso numero producono un'etichetta che contraddice le istruzioni con cui
  /// il numero è stato prodotto.
  static LivelloConfidenza da(double confidenza) => switch (confidenza) {
    >= 0.85 => LivelloConfidenza.alta,
    >= 0.6 => LivelloConfidenza.media,
    _ => LivelloConfidenza.bassa,
  };

  /// Se il foglio deve aprire i dettagli da solo.
  ///
  /// 💡 Sotto 0.6 il modello sta dichiarando di non essere sicuro: costringere
  /// a un tocco in più per vedere *cosa* ha calcolato sarebbe nascondere proprio
  /// il caso in cui bisogna guardare.
  bool get apriDaSola => this == LivelloConfidenza.bassa;
}

/// Come è stato interpretato lo stato di cottura.
///
/// 🚨 **E' la singola fonte di errore piu' grande del dominio**: 100 g di
/// pasta valgono ~350 kcal da cruda e ~150 da cotta. Prima l'interpretazione
/// restava implicita nei numeri e non era ne' visibile ne' contestabile.
enum StatoCottura {
  crudo('crudo', 'pesata cruda'),
  cotto('cotto', 'gia\' cotta'),
  nonApplicabile('non_applicabile', ''),

  /// ⚠️ Non e' un ripiego: e' il segnale con cui l'app **chiede**.
  ambiguo('ambiguo', 'cruda o cotta?');

  const StatoCottura(this.chiave, this.etichetta);

  final String chiave;
  final String etichetta;

  static StatoCottura? da(String? valore) {
    for (final s in StatoCottura.values) {
      if (s.chiave == valore) return s;
    }

    return null;
  }
}

/// Un alimento come lo ha stimato il modello, non ancora in diario.
///
/// 🚨 **È modificabile**: `copyCon()` esiste perché il foglio di conferma deve
/// poter correggere un numero prima di salvarlo. Un foglio che sa solo dire sì o
/// no costringe a salvare e poi rientrare a correggere — cioè a passare per il
/// diario sbagliato.
class VoceStimata {
  const VoceStimata({
    required this.nome,
    this.qty,
    this.unita,
    this.grammi,
    this.kcal,
    this.proteine,
    this.carboidrati,
    this.grassi,
    this.ml,
    this.basis,
    this.stato,
    this.dichiarata,
    this.marca,
    this.gradi,
    this.confidenza,
  });

  factory VoceStimata.fromJson(Map<String, dynamic> j) => VoceStimata(
    nome: j['name']?.toString() ?? 'Alimento',
    qty: _num(j['qty']),
    unita: j['unit']?.toString(),
    grammi: _num(j['grams']),
    kcal: _num(j['kcal']),
    proteine: _num(j['protein']),
    carboidrati: _num(j['carbs']),
    grassi: _num(j['fat']),
    ml: _num(j['ml']),
    basis: j['basis']?.toString(),
    stato: StatoCottura.da(j['state']?.toString()),
    dichiarata: j['declared'] as bool?,
    marca: (j['brand']?.toString().trim().isEmpty ?? true)
        ? null
        : j['brand'].toString().trim(),
    gradi: _num(j['abv_pct']),
    confidenza: _num(j['confidence']),
  );

  final String nome;
  final double? qty, grammi, kcal, proteine, carboidrati, grassi;
  final String? unita;

  /// Il volume, per i liquidi.
  ///
  /// 🚨 Insieme a [basis] chiude un errore del **5% su ogni bevanda**: le
  /// tabelle dei liquidi sono per 100 **ml**, e il modello applicava quel valore
  /// ai grammi. La prova stava nel diario del committente: 521 ml di succo,
  /// 547 g, 245,9 kcal — cioe' 45 kcal/100 ml moltiplicate per il peso.
  final double? ml;

  /// `per_100g` oppure `per_100ml`.
  final String? basis;

  final StatoCottura? stato;

  /// 💡 La quantita' l'ha detta la persona? Allora **non si rimette in
  /// discussione**: chiedere «sei sicuro che fossero 100 g?» a chi ha appena
  /// scritto «100 g» e' il modo piu' rapido per farlo smettere di scriverle.
  final bool? dichiarata;

  final String? marca;
  final double? gradi;

  /// 🚨 La confidenza di **questa** voce: «il pasto e' incerto» non serve a
  /// nessuno, serve sapere quale ingrediente lo e'.
  final double? confidenza;

  Map<String, dynamic> toJson() => {
    'name': nome,
    'qty': qty,
    'unit': unita,
    'grams': grammi,
    'kcal': kcal,
    'protein': proteine,
    'carbs': carboidrati,
    'fat': grassi,
    'ml': ml,
    'basis': basis,
    'state': stato?.chiave,
    'declared': dichiarata,
    'brand': marca,
    'abv_pct': gradi,
    'confidence': confidenza,
  };

  /// Va guardata: il modello dichiara di non essere sicuro, oppure non sa se
  /// l'alimento fosse crudo o cotto.
  bool get daGuardare =>
      (confidenza != null && confidenza! < 0.7) || stato == StatoCottura.ambiguo;

  VoceStimata copyCon({
    double? qty,
    String? unita,
    double? grammi,
    double? kcal,
    double? proteine,
    double? carboidrati,
    double? grassi,
  }) => VoceStimata(
    nome: nome,
    qty: qty ?? this.qty,
    unita: unita ?? this.unita,
    grammi: grammi ?? this.grammi,
    kcal: kcal ?? this.kcal,
    proteine: proteine ?? this.proteine,
    carboidrati: carboidrati ?? this.carboidrati,
    grassi: grassi ?? this.grassi,
    ml: ml,
    basis: basis,
    stato: stato,
    dichiarata: dichiarata,
    marca: marca,
    gradi: gradi,
    confidenza: confidenza,
  );

  /// I valori **per 100 g**, ricavati da quelli assoluti.
  ///
  /// 🚨 Servono al ricalcolo in tempo reale mentre si corregge la quantità:
  /// se 200 g valgono 330 kcal, 100 g ne valgono 165, e 250 g ne valgono 412.
  ///
  /// ⚠️ È **la stessa derivazione che fa il backend** in
  /// `FoodEntry::derivaValoriPer100()`. Non è una seconda formula da tenere
  /// allineata: è la stessa proporzione, e il server la rifà comunque al
  /// salvataggio — questi numeri servono solo a **mostrare** dove si sta
  /// andando mentre si digita.
  ///
  /// 💡 Restituisce `null` senza grammi: da «due cucchiai» senza peso non si
  /// ricava niente, e riscalare inventando sarebbe peggio che non riscalare.
  ({double? kcal, double? proteine, double? carboidrati, double? grassi})? get per100 {
    final g = grammi;

    if (g == null || g <= 0) return null;

    double? per(double? v) => v == null ? null : v / g * 100;

    return (
      kcal: per(kcal),
      proteine: per(proteine),
      carboidrati: per(carboidrati),
      grassi: per(grassi),
    );
  }

  /// La stessa voce **riscalata** a una quantità nuova, in grammi.
  ///
  /// ⚠️ I valori che chi legge ha già corretto a mano non passano di qui: chi
  /// chiama decide quali riscalare, perché un numero scritto da una persona non
  /// va sovrascritto da una proporzione.
  VoceStimata riscalataA(double nuoviGrammi, {required Set<String> intoccabili}) {
    final base = per100;

    if (base == null || nuoviGrammi <= 0) return this;

    double? scala(String chiave, double? valore100, double? attuale) =>
        intoccabili.contains(chiave) || valore100 == null
        ? attuale
        : double.parse((valore100 * nuoviGrammi / 100).toStringAsFixed(1));

    return VoceStimata(
      nome: nome,
      qty: (unita == null || unita == 'g') ? nuoviGrammi : qty,
      unita: unita,
      grammi: nuoviGrammi,
      kcal: scala('kcal', base.kcal, kcal),
      proteine: scala('protein', base.proteine, proteine),
      carboidrati: scala('carbs', base.carboidrati, carboidrati),
      grassi: scala('fat', base.grassi, grassi),
      ml: ml,
      basis: basis,
      stato: stato,
      dichiarata: dichiarata,
      marca: marca,
      gradi: gradi,
      confidenza: confidenza,
    );
  }

  /// «200 g» oppure «1 cucchiaio · 14 g»: come lo si legge, non come si salva.
  String get quantita {
    final g = grammi;

    if (qty != null && unita != null) {
      final base = '${_pulito(qty!)} $unita';

      return (unita != 'g' && g != null) ? '$base · ${_pulito(g)} g' : base;
    }

    return g == null ? '' : '${_pulito(g)} g';
  }

  /// 🚨 **La massa dei macronutrienti non può superare quella dell'alimento.**
  ///
  /// Il 12/08/2026 il modello ha prodotto delle coppiette di maiale con 56 g di
  /// proteine, 4 di carboidrati e 40 di grassi **per 100 g**: cento grammi di
  /// macro in cento grammi di prodotto, cioè acqua zero. 588 kcal sono un
  /// numero plausibile, ed è per questo che nessuno se ne sarebbe accorto.
  ///
  /// ── ⚠️ Perché le prove sono due e non una ────────────────────────────────
  ///
  /// La prima — «più macro della massa» — è il vincolo fisico puro, e da sola
  /// **non prendeva le coppiette**: stavano esattamente a 100 su 100, cioè al
  /// limite e non oltre. Il test lo ha fatto vedere subito.
  ///
  /// La seconda chiude il buco senza inventare niente: un alimento con **più di
  /// un macronutriente** contiene sempre acqua, e non arriva mai al 100%. Al
  /// 100% ci arrivano solo i grassi puri e gli zuccheri puri, che di
  /// macronutrienti ne hanno **uno solo** — 100 g d'olio sono 100 g di grassi, e
  /// vanno lasciati passare.
  ///
  /// 🚨 Non si corregge niente in automatico: è un segnale che **quella voce va
  /// guardata**. Aggiustarla vorrebbe dire inventare al posto del modello.
  ///
  /// 💡 Il 2% di tolleranza vale solo sulla prima prova, per gli arrotondamenti
  /// del modello, che manda numeri interi.
  bool get macroImpossibili {
    final g = grammi;

    if (g == null || g <= 0) return false;

    final p = proteine ?? 0;
    final c = carboidrati ?? 0;
    final f = grassi ?? 0;
    final somma = p + c + f;

    // 1. Oltre la massa dell'alimento: impossibile, punto.
    if (somma > g * 1.02) return true;

    // 2. Al limite, ma con più macronutrienti: vorrebbe dire acqua zero.
    final quantiMacro = [p, c, f].where((m) => m > 0.5).length;

    return quantiMacro > 1 && somma > g * 0.97;
  }

  static String _pulito(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
}

/// Quello che il modello ha capito, con **quanto dice di esserne sicuro**.
class StimaAi {
  const StimaAi({
    required this.voci,
    required this.confidenza,
    this.nota,
    this.frase,
    this.avvisi = const [],
  });

  factory StimaAi.fromJson(Map<String, dynamic> j) {
    final stima = (j['estimate'] as Map?)?.cast<String, dynamic>() ?? j;

    return StimaAi(
      voci: (stima['items'] as List? ?? const [])
          .map((e) => VoceStimata.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      confidenza: _num(stima['confidence']) ?? 0,
      nota: (stima['note']?.toString().trim().isEmpty ?? true)
          ? null
          : stima['note'].toString().trim(),
      avvisi: ((j['warnings'] ?? stima['warnings']) as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  final List<VoceStimata> voci;
  final double confidenza;

  /// 🚨 **Quello che il modello ha da dire su cosa non sa.** Si mostra sempre
  /// quando c'è, perché è il segnale affidabile — la confidenza non lo è.
  final String? nota;

  /// La frase da cui è nata, quando viene dal testo.
  ///
  /// 💡 Serve al pulsante «Precisa»: si riapre il campo **con la frase dentro**,
  /// così si aggiunge «impanate» invece di riscrivere tutto. Chi deve ridigitare
  /// da capo non precisa: conferma e basta.
  final String? frase;

  /// 🚨 Quello che il **backend** ha trovato o corretto: una densita'
  /// implausibile, dei grammi di alcol rifatti dalla gradazione, un valore fuori
  /// scala. Sono controlli deterministici — non opinioni del modello — e per
  /// questo si mostrano separati dalla sua nota.
  final List<String> avvisi;

  StimaAi conFrase(String? f) => StimaAi(
    voci: voci,
    confidenza: confidenza,
    nota: nota,
    frase: f,
    avvisi: avvisi,
  );

  bool get vuota => voci.isEmpty;

  LivelloConfidenza get livello => LivelloConfidenza.da(confidenza);

  double get kcal => voci.fold(0, (s, v) => s + (v.kcal ?? 0));

  double get proteine => voci.fold(0, (s, v) => s + (v.proteine ?? 0));

  double get carboidrati => voci.fold(0, (s, v) => s + (v.carboidrati ?? 0));

  double get grassi => voci.fold(0, (s, v) => s + (v.grassi ?? 0));

  /// C'è almeno una voce fisicamente impossibile.
  bool get haMacroImpossibili => voci.any((v) => v.macroImpossibili);

  /// Se il foglio deve mettere in evidenza che qui c'è da guardare.
  ///
  /// ⚠️ Basta **una** delle due cose: una nota del modello, oppure una voce
  /// impossibile. La confidenza da sola non entra — sulla cotoletta valeva 0.85
  /// e la stima era comunque da guardare.
  bool get daGuardare =>
      nota != null ||
      haMacroImpossibili ||
      livello.apriDaSola ||
      avvisi.isNotEmpty ||
      voci.any((v) => v.daGuardare);

  StimaAi conVoci(List<VoceStimata> nuove) => StimaAi(
    voci: nuove,
    confidenza: confidenza,
    nota: nota,
    frase: frase,
    avvisi: avvisi,
  );
}
