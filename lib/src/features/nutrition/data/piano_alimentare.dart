/// Il piano alimentare come lo compone un trainer — G7 della Parte G.
///
/// ── 🚨 Perché queste classi sono MUTABILI, contro lo stile del resto ──────
///
/// Quasi tutti i modelli di quest'app sono `const` e immutabili, ed è giusto:
/// rappresentano qualcosa che il server ha già deciso. Questi no. Sono lo
/// **stato di un modulo che si sta compilando**: il trainer aggiunge un pasto,
/// scrive un alimento, chiede la stima all'AI, corregge un numero.
///
/// ⚠️ Ricostruire l'albero intero a ogni carattere digitato vorrebbe dire
/// ricreare decine di oggetti per ogni tasto — e su un telefono si sente.
///
/// 💡 L'immutabilità torna al confine: `toJson()` produce esattamente la forma
/// che `NutritionPlanRequest` accetta, e da lì in poi decide il server.
library;

/// Un alimento, o **l'alternativa a un alimento** — D2.
///
/// 🚨 Sono la stessa classe **di proposito**: un'alternativa ha gli stessi
/// campi di ciò che sostituisce, ed è l'unico modo perché sceglierla dica al
/// diario cosa scrivere. Se fossero due classi, la prima a perdere un campo
/// sarebbe l'alternativa.
class AlimentoDelPiano {
  AlimentoDelPiano({
    this.id,
    this.descrizione = '',
    this.qty,
    this.unita,
    this.grammi,
    this.kcal,
    this.proteine,
    this.carboidrati,
    this.grassi,
    this.origineValori = 'manual',
    List<AlimentoDelPiano>? alternative,
  }) : alternative = alternative ?? [];

  factory AlimentoDelPiano.fromJson(Map<String, dynamic> json) =>
      AlimentoDelPiano(
        id: (json['id'] as num?)?.toInt(),
        descrizione: json['description']?.toString() ?? '',
        qty: (json['qty'] as num?)?.toDouble(),
        unita: json['unit']?.toString(),
        grammi: (json['grams'] as num?)?.toDouble(),
        kcal: (json['kcal'] as num?)?.toDouble(),
        proteine: (json['protein'] as num?)?.toDouble(),
        carboidrati: (json['carbs'] as num?)?.toDouble(),
        grassi: (json['fat'] as num?)?.toDouble(),
        origineValori: json['origine_valori']?.toString() ?? 'manual',
        alternative: ((json['alternatives'] as List?) ?? const [])
            .map(
              (e) =>
                  AlimentoDelPiano.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
      );

  final int? id;
  String descrizione;
  double? qty;
  String? unita;
  double? grammi;
  double? kcal;
  double? proteine;
  double? carboidrati;
  double? grassi;

  /// Chi ha scritto questi valori: `ai` o `manual` — D13.
  ///
  /// 💡 Serve **al trainer**, per vedere a colpo d'occhio cosa ha già
  /// controllato. ⚠️ Non è un giudizio: la sua correzione vince sempre, ed è
  /// proprio correggendo che questo campo torna a `manual`.
  String origineValori;

  /// Al massimo tre — D2. Il limite lo applica anche il server.
  final List<AlimentoDelPiano> alternative;

  bool get vuoto => descrizione.trim().isEmpty;

  /// I valori li ha proposti l'AI e nessuno li ha ancora toccati.
  bool get dallAi => origineValori == 'ai';

  /// Copia i valori proposti dall'AI dentro questo alimento.
  ///
  /// ⚠️ **Sovrascrive solo ciò che la stima dichiara.** Una stima che torna
  /// senza proteine non deve azzerare quelle che il trainer aveva già scritto:
  /// è lo stesso principio delle alternative lato server, e lo stesso errore
  /// che si farebbe assegnando alla cieca.
  void adottaStima(AlimentoDelPiano stima) {
    if (stima.descrizione.trim().isNotEmpty) descrizione = stima.descrizione;
    qty = stima.qty ?? qty;
    unita = stima.unita ?? unita;
    grammi = stima.grammi ?? grammi;
    kcal = stima.kcal ?? kcal;
    proteine = stima.proteine ?? proteine;
    carboidrati = stima.carboidrati ?? carboidrati;
    grassi = stima.grassi ?? grassi;
    origineValori = 'ai';
  }

  Map<String, dynamic> toJson() => {
    'description': descrizione,
    if (qty != null) 'qty': qty,
    if (unita != null) 'unit': unita,
    if (grammi != null) 'grams': grammi,
    if (kcal != null) 'kcal': kcal,
    if (proteine != null) 'protein': proteine,
    if (carboidrati != null) 'carbs': carboidrati,
    if (grassi != null) 'fat': grassi,
    'origine_valori': origineValori,
    if (alternative.isNotEmpty)
      'alternatives': alternative
          .where((a) => !a.vuoto)
          .map((a) => a.toJson())
          .toList(),
  };
}

/// Un pasto, o **l'alternativa a un pasto** — D2.
class PastoDelPiano {
  PastoDelPiano({
    this.id,
    this.pasto = 'lunch',
    this.titolo,
    this.note,
    List<AlimentoDelPiano>? alimenti,
    List<PastoDelPiano>? alternative,
  }) : alimenti = alimenti ?? [],
       alternative = alternative ?? [];

  factory PastoDelPiano.fromJson(Map<String, dynamic> json) => PastoDelPiano(
    id: (json['id'] as num?)?.toInt(),
    pasto: json['meal']?.toString() ?? 'lunch',
    titolo: json['title']?.toString(),
    note: json['notes']?.toString(),
    alimenti: ((json['items'] as List?) ?? const [])
        .map(
          (e) => AlimentoDelPiano.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
    alternative: ((json['alternatives'] as List?) ?? const [])
        .map((e) => PastoDelPiano.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  final int? id;
  String pasto;
  String? titolo;
  String? note;
  final List<AlimentoDelPiano> alimenti;
  final List<PastoDelPiano> alternative;

  /// 🚨 Somma **solo** gli alimenti principali, mai le alternative.
  ///
  /// Contarle gonfierebbe ogni pasto: un pranzo con due alternative varrebbe
  /// tre pranzi. Il server fa lo stesso calcolo (`TotaliDelPiano`), e i due
  /// devono restare d'accordo — 💡 questo qui serve a mostrarlo **mentre si
  /// scrive**, prima che il server risponda.
  double get kcal => alimenti.fold(0, (t, a) => t + (a.kcal ?? 0));

  Map<String, dynamic> toJson() => {
    'meal': pasto,
    if (titolo != null && titolo!.trim().isNotEmpty) 'title': titolo,
    if (note != null && note!.trim().isNotEmpty) 'notes': note,
    'items': alimenti.where((a) => !a.vuoto).map((a) => a.toJson()).toList(),
    if (alternative.isNotEmpty)
      'alternatives': alternative.map((p) => p.toJson()).toList(),
  };
}

/// Un giorno, o **l'alternativa a un giorno** — D2.
class GiornoDelPiano {
  GiornoDelPiano({
    this.id,
    this.nome,
    this.note,
    List<PastoDelPiano>? pasti,
    List<GiornoDelPiano>? alternative,
  }) : pasti = pasti ?? [],
       alternative = alternative ?? [];

  factory GiornoDelPiano.fromJson(Map<String, dynamic> json) => GiornoDelPiano(
    id: (json['id'] as num?)?.toInt(),
    nome: json['name']?.toString(),
    note: json['notes']?.toString(),
    pasti: ((json['meals'] as List?) ?? const [])
        .map((e) => PastoDelPiano.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    alternative: ((json['alternatives'] as List?) ?? const [])
        .map((e) => GiornoDelPiano.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  final int? id;

  /// ⚠️ `null` è legittimo: un piano a un giorno solo non deve mostrare
  /// un'intestazione che il trainer non ha scritto.
  String? nome;
  String? note;
  final List<PastoDelPiano> pasti;
  final List<GiornoDelPiano> alternative;

  double get kcal => pasti.fold(0, (t, p) => t + p.kcal);

  Map<String, dynamic> toJson() => {
    if (nome != null && nome!.trim().isNotEmpty) 'name': nome,
    if (note != null && note!.trim().isNotEmpty) 'notes': note,
    'meals': pasti.map((p) => p.toJson()).toList(),
    if (alternative.isNotEmpty)
      'alternatives': alternative.map((g) => g.toJson()).toList(),
  };
}

/// Il piano intero.
class PianoAlimentare {
  PianoAlimentare({
    this.id,
    this.origineId,
    this.nome = '',
    this.tipo = TipoPiano.consigli,
    this.rifAllievo,
    this.note,
    this.targetKcal,
    List<GiornoDelPiano>? giorni,
  }) : giorni = giorni ?? [];

  factory PianoAlimentare.fromJson(Map<String, dynamic> json) =>
      PianoAlimentare(
        id: (json['id'] as num?)?.toInt(),
        origineId: json['origine_id']?.toString(),
        nome: json['name']?.toString() ?? '',
        tipo: TipoPiano.da(json['tipo']?.toString()),
        // 🚨 La chiave **manca del tutto** se chi guarda non è chi l'ha scritto
        // (R4): `null` qui vuol dire «non è mio», non «non l'ha compilato».
        rifAllievo: json['rif_allievo']?.toString(),
        note: json['notes']?.toString(),
        targetKcal: (json['target_kcal'] as num?)?.toInt(),
        giorni: ((json['days'] as List?) ?? const [])
            .map(
              (e) =>
                  GiornoDelPiano.fromJson((e as Map).cast<String, dynamic>()),
            )
            .toList(),
      );

  final int? id;

  /// L'identità stabile del piano — D15.
  ///
  /// 💡 Serve alla consegna: è ciò che permette al telefono dell'allievo di
  /// riconoscere una versione nuova e **sostituirla** invece di affiancarla.
  final String? origineId;

  String nome;

  /// Consigli o piano vero — N19.
  ///
  /// 🚨 **Non è un'etichetta: decide cosa si può scriverci dentro.** Un trainer
  /// compone `consigli` — un elenco di alimenti — e il server rifiuta con 422
  /// una richiesta che porti giorni o grammi. La regola vera vive lì; qui c'è
  /// solo quanto basta a non mandarla.
  TipoPiano tipo;

  /// Il promemoria privato — D3.
  ///
  /// ⚠️ **Non entra mai nella busta cifrata** (R4): è l'etichetta del trainer,
  /// e mandarla vorrebbe dire mostrare all'allievo come lo si chiama negli
  /// appunti. Lo spoglio si fa al momento dell'invio, in `G8.3`.
  String? rifAllievo;

  String? note;
  int? targetKcal;
  final List<GiornoDelPiano> giorni;

  bool get nuovo => id == null;

  /// La **media** dei giorni, non la somma — D14.
  ///
  /// ⚠️ La somma di sette giorni non vuol dire niente per chi legge: nessuno
  /// mangia una settimana in una volta. 💡 Con un piano a un giorno i due modi
  /// danno lo stesso numero, ed è il caso in cui la differenza passa
  /// inosservata.
  double get kcalMedie {
    if (giorni.isEmpty) return 0;

    return giorni.fold<double>(0, (t, g) => t + g.kcal) / giorni.length;
  }

  Map<String, dynamic> toJson() => {
    'name': nome,
    'tipo': tipo.name,
    if (rifAllievo != null) 'rif_allievo': rifAllievo,
    if (note != null && note!.trim().isNotEmpty) 'notes': note,
    if (targetKcal != null) 'target_kcal': targetKcal,
    'days': giorni.map((g) => g.toJson()).toList(),
  };
}

/// Consigli o piano vero — N19.
///
/// ── 🚨 La differenza non è di nome, è di forma ─────────────────────────────
///
/// «Mangia pollo, riso e broccoli» è un **consiglio**; «200 g di pollo alle
/// 13:00, giorno 3» è una **dieta**, comunque la si chiami — e l'elaborazione
/// di una dieta è riservata a medici, biologi nutrizionisti e dietisti.
///
/// ⚠️ **Il vincolo vero sta sul server**, che rifiuta una richiesta di tipo
/// `consigli` con dentro dei giorni. Qui c'è solo quanto basta a non mandarla:
/// un client non è un posto dove far vivere una regola del genere.
enum TipoPiano {
  consigli,
  piano;

  /// 💡 Sconosciuto o mancante → `consigli`, cioè il tipo **più povero**. Un
  /// campo che manca non deve promuovere un documento a qualcosa che chi l'ha
  /// scritto non aveva il titolo di scrivere.
  static TipoPiano da(String? valore) =>
      valore == 'piano' ? TipoPiano.piano : TipoPiano.consigli;
}
