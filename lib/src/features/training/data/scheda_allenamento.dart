/// La scheda come la compone un trainer — G7.1 della Parte G.
///
/// ── 🚨 Perché queste classi sono MUTABILI ────────────────────────────────
///
/// Stessa ragione di `piano_alimentare.dart`, e la nota va ripetuta perché chi
/// apre questo file non ha letto quello: sono lo **stato di un modulo che si sta
/// compilando**, non qualcosa che il server ha già deciso. Ricostruire l'albero
/// a ogni carattere digitato si sente sul telefono.
///
/// 💡 L'immutabilità torna al confine: `toJson()` produce esattamente la forma
/// che `WorkoutPlanRequest` accetta.
///
/// ── ⚠️ Non è `session_models.dart`, e non va unita a quello ──────────────
///
/// `session_models.dart` descrive un allenamento **eseguito**: serie fatte,
/// carichi usati, quando. Questo descrive un allenamento **prescritto**. Sono
/// due cose che si somigliano solo finché non si prova a unirle: la prescrizione
/// dice «8-12», l'esecuzione dice «10». La prima è una stringa, la seconda un
/// numero, e nessuna delle due può diventare l'altra.
library;

import 'gruppo_muscolare.dart';
import 'scheda_in_scrittura.dart';
import 'serie_prevista.dart';

/// Un esercizio, o **l'alternativa a un esercizio** — D10.
///
/// 🚨 Sono la stessa classe **di proposito**, come `AlimentoDelPiano`: chi
/// sceglie l'alternativa deve trovarci serie, ripetizioni e recupero, o non
/// saprebbe cosa fare. Se fossero due classi, la prima a perdere un campo
/// sarebbe l'alternativa — cioè quella che nessuno prova.
class EsercizioDellaScheda with ConLeSerie {
  EsercizioDellaScheda({
    this.id,
    this.nome = '',
    this.serie,
    this.ripetizioni,
    this.recuperoSec,
    this.durataSec,
    this.pesoTarget,
    this.note,
    this.muscoli,
    this.carico = CaricoDellEsercizio.peso,
    List<SerieInScrittura>? righe,
    List<EsercizioDellaScheda>? alternative,
  }) : righe =
           righe ??
           List.generate(
             EsercizioInScrittura.seriePredefinite,
             (_) => SerieInScrittura(),
           ),
       alternative = alternative ?? [];

  factory EsercizioDellaScheda.fromJson(
    Map<String, dynamic> json,
  ) => EsercizioDellaScheda(
    id: (json['id'] as num?)?.toInt(),
    // ⚠️ `name` in cima, con `exercise.name` come ripiego: il primo è quello
    // che il server rimanda in scrittura, il secondo è il nome del catalogo.
    // Prima di G7 esisteva **solo** il secondo.
    nome:
        json['name']?.toString() ??
        (json['exercise'] as Map?)?['name']?.toString() ??
        '',
    serie: (json['sets'] as num?)?.toInt(),
    ripetizioni: json['reps']?.toString(),
    recuperoSec: (json['rest_sec'] as num?)?.toInt(),
    durataSec: (json['duration_sec'] as num?)?.toInt(),
    pesoTarget: (json['target_weight'] as num?)?.toDouble(),
    note: json['notes']?.toString(),
    muscoli: _muscoliDa(json),

    /*
     * 🆕 3b-D.11 — le serie riga per riga, anche qui.
     *
     * 🚨 Passa dallo stesso adattatore dell'editor dell'iscritto, quindi un
     * modello scritto prima del 25/08 si apre **gia' in righe**: e' il
     * *«le schede gia' esistenti ricalchino questa nuova impostazione»*
     * applicato al compositore del trainer.
     */
    carico: CaricoDellEsercizio.da(json['carico']?.toString()),
    righe: [for (final s in serieDellEsercizio(json)) SerieInScrittura.da(s)],
    alternative: ((json['alternatives'] as List?) ?? const [])
        .map(
          (e) =>
              EsercizioDellaScheda.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
  );

  final int? id;
  String nome;

  /// ⚠️ **Quante** serie: il campo vecchio, che resta perche' e' il riassunto
  /// che il server rimanda e che il pannello mostra. 🚨 Quando ci sono le
  /// [righe], comandano loro — e il riassunto lo ricalcola il server.
  int? serie;

  @override
  final List<SerieInScrittura> righe;

  @override
  CaricoDellEsercizio carico;

  /// 🚨 **Una STRINGA, e deve restarlo.**
  ///
  /// «8-12», «cedimento», «max», «10+10» sono prescrizioni legittime e
  /// frequentissime. ⚠️ Chi la converte in intero credendo di correggere una
  /// svista rompe metà delle schede vere — la stessa nota sta in
  /// `WorkoutPlanRequest` e nel prompt di importazione dai PDF, e ci sta tre
  /// volte perché è stata sbagliata almeno una.
  String? ripetizioni;

  int? recuperoSec;
  int? durataSec;
  double? pesoTarget;

  /// Le note per **questo** esercizio — richiesta esplicita del committente.
  ///
  /// 💡 Non sono le note della scheda: «fermo un secondo al petto» riguarda la
  /// panca, non l'allenamento intero. Metterle in fondo alla scheda vorrebbe
  /// dire che si leggono quando l'esercizio è già finito.
  String? note;

  /// Che muscoli allena, quando qualcuno l'ha detto — 3b-A.3.4, 23/08/2026.
  ///
  /// ══ 🚨 TRE STATI, NON DUE ══════════════════════════════════════════════
  ///
  /// - `null` → **nessuno l'ha deciso**. Non si manda niente al server, e
  ///   l'esercizio resta da completare.
  /// - `secondari` vuoto → **«questo esercizio isola davvero»**. È una
  ///   risposta, e va mandata.
  /// - `secondari` pieno → i muscoli che aiutano.
  ///
  /// ⛔ Ridurli a due stati mandando sempre un elenco vuoto sarebbe il difetto
  /// peggiore possibile qui: la libreria si riempirebbe di esercizi che
  /// *dichiarano* di non avere secondari, e la guardia che cerca i buchi non ne
  /// troverebbe più nessuno. Il catalogo marcirebbe **in silenzio**.
  MuscoliScelti? muscoli;

  /// Al massimo tre — D2. Il limite lo applica anche il server.
  final List<EsercizioDellaScheda> alternative;

  bool get vuoto => nome.trim().isEmpty;

  /// Come si legge la prescrizione: «4 × 8-12».
  ///
  /// ⚠️ Calcolata **qui** e non presa da `prescription` del server: mentre si
  /// scrive il server non ha ancora visto niente, e una riga che resta muta
  /// finché non si salva non aiuta a scrivere.
  String get prescrizione {
    final parti = <String>[
      if (serie != null) '$serie',
      if (ripetizioni != null && ripetizioni!.trim().isNotEmpty)
        ripetizioni!.trim(),
    ];

    return parti.join(' × ');
  }

  Map<String, dynamic> toJson() => {
    'name': nome.trim(),

    /*
     * ══ 🆕 LE RIGHE, E POI IL RIASSUNTO — 3b-D.11 ═══════════════════════════
     *
     * 🚨 **Il riassunto lo ricalcola il server** (`PlanExercise::booted()`)
     * quando le righe ci sono: qui si mandano lo stesso, perche' servono a un
     * server non ancora aggiornato e non fanno male a uno aggiornato — li
     * sovrascrive con quelli veri.
     *
     * ⚠️ Le righe **tutte vuote non si mandano**: un esercizio appena
     * aggiunto ne ha tre intatte, e mandarle vorrebbe dire dire al server
     * «tre serie da niente» invece di «non l'ho ancora compilato».
     */
    if (righe.any((r) => !r.intatta))
      'serie': [for (final r in righe) r.versoIlDato(carico).toJson()],

    'carico': carico.codice,

    if (serie != null) 'sets': serie,
    if (ripetizioni != null && ripetizioni!.trim().isNotEmpty)
      'reps': ripetizioni!.trim(),
    if (recuperoSec != null) 'rest_sec': recuperoSec,
    if (durataSec != null) 'duration_sec': durataSec,
    if (pesoTarget != null) 'target_weight': pesoTarget,
    if (note != null && note!.trim().isNotEmpty) 'notes': note!.trim(),

    // 🚨 Solo se qualcuno ha risposto: la regola dei tre stati sta in
    // `muscoliInJson`, in un posto solo.
    ...muscoliInJson(muscoli),
    // ⚠️ Le alternative senza nome si scartano qui: l'editor ne tiene volentieri
    // una vuota, e il server la rifiuterebbe (`name` è `required`).
    if (alternative.any((a) => !a.vuoto))
      'alternatives': alternative
          .where((a) => !a.vuoto)
          .map((a) => a.toJson())
          .toList(),
  };
}

/// I muscoli letti da una riga del server, se ci sono.
///
/// ⚠️ Si guarda **prima** la riga e poi l'esercizio del catalogo: in scrittura
/// il server rimanda quello che ha scritto lui, in lettura di una scheda la
/// riga annidata `exercise` porta il dato della libreria. È la stessa forma di
/// ripiego che usa `name` qui sopra, e per lo stesso motivo.
MuscoliScelti? _muscoliDa(Map<String, dynamic> json) {
  final esercizio = (json['exercise'] as Map?)?.cast<String, dynamic>();

  final primario = GruppoMuscolare.da(
    json['muscle_group'] ?? esercizio?['muscle_group'],
  );

  final secondari =
      json['secondary_muscles'] ?? esercizio?['secondary_muscles'];

  // 💡 Niente di niente resta `null`: «non lo so» non è «non ne ha».
  if (primario == null && secondari == null) return null;

  return (
    primario: primario,
    secondari: ((secondari as List?) ?? const [])
        .map(GruppoMuscolare.da)
        .nonNulls
        .toList(growable: false),
  );
}

/// Un giorno, o **l'alternativa a un giorno** — D2.
class GiornoDellaScheda {
  GiornoDellaScheda({
    this.id,
    this.nome,
    this.note,
    List<EsercizioDellaScheda>? esercizi,
    List<GiornoDellaScheda>? alternative,
  }) : esercizi = esercizi ?? [],
       alternative = alternative ?? [];

  factory GiornoDellaScheda.fromJson(
    Map<String, dynamic> json,
  ) => GiornoDellaScheda(
    id: (json['id'] as num?)?.toInt(),
    nome: json['name']?.toString(),
    note: json['notes']?.toString(),
    esercizi: ((json['exercises'] as List?) ?? const [])
        .map(
          (e) =>
              EsercizioDellaScheda.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
    alternative: ((json['alternatives'] as List?) ?? const [])
        .map(
          (e) => GiornoDellaScheda.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(),
  );

  final int? id;

  /// ⚠️ `null` è legittimo: una scheda a un giorno solo non deve mostrare
  /// un'intestazione che il trainer non ha scritto.
  String? nome;
  String? note;
  final List<EsercizioDellaScheda> esercizi;
  final List<GiornoDellaScheda> alternative;

  /// 🚨 Conta **solo** gli esercizi principali, mai le alternative.
  ///
  /// Contarle direbbe «9 esercizi» a un giorno in cui se ne fanno 6, ed è lo
  /// stesso errore che sul lato alimentare gonfierebbe le calorie.
  int get quantiEsercizi => esercizi.where((e) => !e.vuoto).length;

  Map<String, dynamic> toJson() => {
    if (nome != null && nome!.trim().isNotEmpty) 'name': nome!.trim(),
    if (note != null && note!.trim().isNotEmpty) 'notes': note!.trim(),
    'exercises': esercizi
        .where((e) => !e.vuoto)
        .map((e) => e.toJson())
        .toList(),
    if (alternative.isNotEmpty)
      'alternatives': alternative.map((g) => g.toJson()).toList(),
  };
}

/// La scheda intera.
class SchedaAllenamento {
  SchedaAllenamento({
    this.id,
    this.origineId,
    this.nome = '',
    this.rifAllievo,
    this.note,
    List<GiornoDellaScheda>? giorni,
  }) : giorni = giorni ?? [];

  factory SchedaAllenamento.fromJson(Map<String, dynamic> json) {
    final giorni = ((json['days'] as List?) ?? const [])
        .map(
          (e) => GiornoDellaScheda.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList();

    /*
     * ⚠️ **Il ripiego sulla lista piatta**, e serve davvero.
     *
     * Una scheda scritta prima di G4 — o servita da un server non ancora
     * aggiornato — non ha `days`, ha `exercises`. Senza questo, aprirla nel
     * compositore mostrerebbe una scheda **vuota**, e salvarla la cancellerebbe.
     *
     * 💡 Il giorno inventato non prende nome: inventarne uno scriverebbe nella
     * scheda del trainer una parola che lui non ha mai scritto.
     */
    if (giorni.isEmpty && json['exercises'] is List) {
      final piatti = (json['exercises'] as List)
          .map(
            (e) => EsercizioDellaScheda.fromJson(
              (e as Map).cast<String, dynamic>(),
            ),
          )
          .toList();

      if (piatti.isNotEmpty) {
        giorni.add(GiornoDellaScheda(esercizi: piatti));
      }
    }

    return SchedaAllenamento(
      id: (json['id'] as num?)?.toInt(),
      origineId: json['origine_id']?.toString(),
      nome: json['name']?.toString() ?? '',
      // 🚨 La chiave **manca del tutto** se chi guarda non è chi l'ha scritta
      // (R4): `null` qui vuol dire «non è mia», non «non l'ha compilato».
      rifAllievo: json['rif_allievo']?.toString(),
      note: json['notes']?.toString(),
      giorni: giorni,
    );
  }

  final int? id;

  /// L'identità stabile — D15. È ciò che permette al telefono di chi riceve di
  /// riconoscere una versione nuova e **sostituirla** invece di affiancarla.
  final String? origineId;

  String nome;

  /// Il promemoria privato — D3.
  ///
  /// ⚠️ **Non entra mai nella busta cifrata** (R4): è l'etichetta del trainer, e
  /// mandarla vorrebbe dire mostrare all'allievo come lo si chiama negli
  /// appunti. Lo spoglio si fa al momento dell'invio.
  String? rifAllievo;

  String? note;
  final List<GiornoDellaScheda> giorni;

  bool get nuova => id == null;

  int get quantiEsercizi => giorni.fold(0, (t, g) => t + g.quantiEsercizi);

  Map<String, dynamic> toJson() => {
    'name': nome.trim(),
    if (rifAllievo != null) 'rif_allievo': rifAllievo,
    if (note != null && note!.trim().isNotEmpty) 'notes': note!.trim(),
    'days': giorni.map((g) => g.toJson()).toList(),
  };
}
