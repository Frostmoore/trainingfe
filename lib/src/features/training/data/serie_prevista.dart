/// Una serie prevista dalla scheda — 3b-D.1, 25/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«ogni esercizio deve partire di base con 3 serie … Ogni serie deve essere
/// una riga … ogni serie deve avere Ripetizioni, Peso (o niente o Iso.
/// abbreviazione di Isometria) e Recupero»*.
///
/// ══ 🚨 COSA CAMBIA DAVVERO ════════════════════════════════════════════════
///
/// ⛔ Fino a ieri un esercizio aveva **una** prescrizione (`'4 × 12'`), **un**
/// peso e **un** recupero, validi per tutte le serie. Era un modello che non
/// sa dire la cosa più normale di una scheda vera: *«12 a 40 kg, 10 a 45, 8 a
/// 50»*.
///
/// 💡 Da qui in poi **la serie è la riga**, e l'esercizio è l'elenco delle sue
/// righe.
///
/// ══ ⚠️ E IL FORMATO VECCHIO NON SI MIGRA: SI ADATTA IN LETTURA ════════════
///
/// 🚨 Una migrazione una-tantum **non basterebbe**, e il motivo è preciso: le
/// schede del trainer continuano ad arrivare dal server nel formato vecchio —
/// `plan_exercises` non ha le serie riga per riga — quindi una scheda ricevuta
/// domani nascerebbe già «vecchia», e la migrazione sarebbe passata ieri.
///
/// 💡 Per questo l'adattamento sta **nel punto in cui si legge**
/// ([serieDellEsercizio]): così *«le schede già esistenti ricalcano la nuova
/// impostazione»* **tutte** — quelle locali, quelle arrivate in chat e quelle
/// che arriveranno.
library;

import 'prescrizione.dart';

/// Con che cosa si carica un esercizio.
///
/// ══ ⚠️ PERCHE' STA SULL'ESERCIZIO E NON SULLA SINGOLA SERIE ═══════════════
///
/// 📌 *«Il campo peso deve poter essere rimosso o sostituito con Iso
/// (isometria, in secondi)»*.
///
/// 💡 Nessuno fa la prima serie con i manubri e la seconda in isometria: la
/// scelta descrive **il movimento**, non l'esecuzione di una riga. Metterla per
/// riga vorrebbe dire quattro menù invece di uno, e quattro modi di sbagliare.
///
/// ⚠️ **Il dato regge già il caso opposto**: i secondi e i chili stanno sulla
/// riga ([SeriePrevista.isoSec] e [SeriePrevista.peso]). Se un giorno servisse
/// per riga, a cambiare sarebbe solo **dove si sceglie**, non come si salva.
enum CaricoDellEsercizio {
  /// I chili.
  peso('Peso'),

  /// Niente: il corpo, e basta.
  niente('Nessuno'),

  /// Isometria: si tiene la posizione, e si contano i **secondi**.
  iso('Iso.');

  const CaricoDellEsercizio(this.etichetta);

  /// 💡 *«Iso. abbreviazione di Isometria»* — l'abbreviazione l'ha scelta il
  /// committente, e in una riga stretta fra ripetizioni e recupero è l'unica
  /// che ci sta.
  final String etichetta;

  static CaricoDellEsercizio da(String? codice) => switch (codice) {
    'niente' => CaricoDellEsercizio.niente,
    'iso' => CaricoDellEsercizio.iso,
    _ => CaricoDellEsercizio.peso,
  };

  String get codice => switch (this) {
    CaricoDellEsercizio.peso => 'peso',
    CaricoDellEsercizio.niente => 'niente',
    CaricoDellEsercizio.iso => 'iso',
  };
}

/// Un numero come lo legge una persona: `40` e non `40.0`.
///
/// ⚠️ Uno zero dietro la virgola sembra una **precisione**: «11.0 kg» dice che
/// qualcuno ha misurato il decimo di chilo, e nessuno l'ha fatto.
String numeroPulito(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toString();

/// Una riga: quante ripetizioni, con che carico, e quanto si riposa dopo.
class SeriePrevista {
  const SeriePrevista({
    this.ripetizioni,
    this.peso,
    this.isoSec,
    this.recuperoSec,
  });

  factory SeriePrevista.fromJson(Map<String, dynamic> j) => SeriePrevista(
    ripetizioni: (j['reps'] as num?)?.toInt(),
    peso: (j['weight'] as num?)?.toDouble(),
    isoSec: (j['iso_sec'] as num?)?.toInt(),
    recuperoSec: (j['rest_sec'] as num?)?.toInt(),
  );

  /// Quante ripetizioni. `null` = non dichiarate (es. «a cedimento»).
  final int? ripetizioni;

  /// I chili previsti.
  ///
  /// ⚠️ **`null` non è zero.** Il committente: *«Il campo peso (se attivo) può
  /// essere lasciato vuoto»* — e un peso vuoto vuol dire «lo decidi lì», mentre
  /// uno zero vorrebbe dire «a corpo libero», che è un'altra cosa e ha già la
  /// sua voce ([CaricoDellEsercizio.niente]).
  final double? peso;

  /// I secondi di tenuta, quando il carico è [CaricoDellEsercizio.iso].
  final int? isoSec;

  /// Quanto si riposa **dopo questa serie**.
  ///
  /// 💡 Sta sulla riga e non sull'esercizio perché è la cosa che cambia più
  /// spesso fra una serie e l'altra: novanta secondi fra le prime, due minuti
  /// prima dell'ultima.
  final int? recuperoSec;

  /// ⚠️ Una riga «intatta» è una che non è mai stata compilata.
  ///
  /// 🚨 Serve all'autocompilazione (3b-D.5.4): compilando la prima riga si
  /// riempiono le altre **solo se sono ancora intatte**. Sovrascrivere quello
  /// che qualcuno ha già scritto è il modo più veloce di far perdere un numero
  /// appena messo.
  bool get intatta =>
      ripetizioni == null && peso == null && isoSec == null && recuperoSec == null;

  SeriePrevista copyWith({
    int? ripetizioni,
    double? peso,
    int? isoSec,
    int? recuperoSec,
  }) => SeriePrevista(
    ripetizioni: ripetizioni ?? this.ripetizioni,
    peso: peso ?? this.peso,
    isoSec: isoSec ?? this.isoSec,
    recuperoSec: recuperoSec ?? this.recuperoSec,
  );

  /// ⚠️ **Le chiavi nulle non si scrivono.** Un `null` esplicito nel JSON non
  /// aggiunge niente e allunga ogni scheda nel backup.
  Map<String, dynamic> toJson() => {
    if (ripetizioni != null) 'reps': ripetizioni,
    if (peso != null) 'weight': peso,
    if (isoSec != null) 'iso_sec': isoSec,
    if (recuperoSec != null) 'rest_sec': recuperoSec,
  };
}

/// Le serie di un esercizio, **da qualunque formato arrivi**.
///
/// ══ 🚨 L'UNICO POSTO CHE SA CHE ESISTONO DUE FORMATI ══════════════════════
///
/// ⛔ Se questa conoscenza si sparpaglia, ogni schermata cresce il suo ramo
/// «se è vecchia» — ed è il posto in cui i difetti si nascondono, perché il
/// ramo che non si prende mai in prova è quello che si rompe in produzione.
///
/// 💡 Chi legge una scheda chiama questa funzione e non sa niente del resto.
List<SeriePrevista> serieDellEsercizio(Map<String, dynamic> esercizio) {
  final scritte = esercizio['serie'] as List?;

  if (scritte != null && scritte.isNotEmpty) {
    return [
      for (final s in scritte)
        SeriePrevista.fromJson((s as Map).cast<String, dynamic>()),
    ];
  }

  /*
   * ══ ⏪ L'ESPANSIONE DEL FORMATO VECCHIO ═════════════════════════════════
   *
   * `{sets: 4, reps: '12', rest_sec: 90, target_weight: 40}` diventa quattro
   * righe uguali. ⚠️ Non e' un'invenzione: e' esattamente quello che quella
   * scheda **voleva dire**, scritto nel modo in cui adesso si scrive.
   */
  /*
   * ══ 🚨 `prescription` E `reps` NON SONO LA STESSA COSA ═════════════════
   *
   * ⛔ Si somigliano abbastanza da ingannare, e mi hanno ingannato: il server
   * manda `prescription` **intera** (`'4 × 12'`), il formato locale tiene
   * `sets` in un campo e `reps` nell'altro — e li' `'12'` sono **le
   * ripetizioni**.
   *
   * ⚠️ Leggere `'12'` come una prescrizione risponde «dodici serie», che e' il
   * contrario di quello che c'e' scritto. L'ha trovato il test al primo colpo.
   */
  final dalServer = esercizio['prescription']?.toString();
  final prescrizione = Prescrizione.leggi(dalServer);

  final quante =
      (esercizio['sets'] as num?)?.toInt() ?? prescrizione.serie ?? 1;

  final riga = SeriePrevista(
    ripetizioni: dalServer != null
        ? prescrizione.ripetizioni
        : Prescrizione.primoNumero(esercizio['reps']?.toString()),
    peso: (esercizio['target_weight'] as num?)?.toDouble(),
    recuperoSec: (esercizio['rest_sec'] as num?)?.toInt(),
  );

  /*
   * ⛔ **Mai zero righe.** Un esercizio senza serie non e' mostrabile, e una
   * lista vuota diventerebbe una card muta in mezzo alla scheda. 💡 Il minimo
   * e' una: chi ha scritto solo il nome dell'esercizio ha comunque detto che
   * quel movimento lo fa.
   */
  return List<SeriePrevista>.filled(quante < 1 ? 1 : quante, riga);
}

/// Il JSON di un esercizio: il formato nuovo **e** il riassunto del vecchio.
///
/// ══ ⚠️ PERCHE' SI SCRIVONO TUTTI E DUE ════════════════════════════════════
///
/// ⛔ Non e' ridondanza per pigrizia. Senza il riassunto:
///
/// 1. 🚨 **un backup ripristinato su una versione precedente dell'app** aprirebbe
///    schede con gli esercizi vuoti — e il ripristino e' proprio la cosa che
///    deve funzionare quando tutto il resto e' andato storto;
/// 2. `Prescrizione.leggi` (3b-C.5), che alimenta i chili della card dei numeri
///    per gli allenamenti del polso, non troverebbe piu' niente da leggere.
///
/// 💡 La regola e': **il formato nuovo comanda, il vecchio e' il riassunto**.
/// Chi legge preferisce `serie` se c'e' — vedi [serieDellEsercizio].
Map<String, dynamic> esercizioInJson({
  required String nome,
  required List<SeriePrevista> serie,
  required CaricoDellEsercizio carico,
  int? exerciseId,
  String? note,
  String? immagine,
  Map<String, dynamic> muscoli = const {},
}) {
  final conRipetizioni = serie
      .map((s) => s.ripetizioni)
      .whereType<int>()
      .toList();

  /*
   * ⚠️ **Il riassunto perde le differenze fra le serie, e va detto.** Dodici,
   * dieci e otto diventano `'12-8'`: chi legge il formato vecchio sa il campo
   * e il verso, non i gradini. E' il prezzo dichiarato della compatibilita'.
   */
  final reps = switch (conRipetizioni.length) {
    0 => null,
    1 => '${conRipetizioni.first}',
    _ =>
      conRipetizioni.first == conRipetizioni.last
          ? '${conRipetizioni.first}'
          : '${conRipetizioni.first}-${conRipetizioni.last}',
  };

  return {
    'name': nome,
    'serie': [for (final s in serie) s.toJson()],
    'carico': carico.codice,

    'exercise_id': ?exerciseId,
    if (note != null && note.isNotEmpty) 'notes': note,
    if (immagine != null && immagine.isNotEmpty) 'immagine': immagine,

    // ── ⏪ Il riassunto, per chi legge il formato vecchio ────────────────
    'sets': serie.length,
    'reps': ?reps,
    if (serie.any((s) => s.recuperoSec != null))
      'rest_sec': serie.firstWhere((s) => s.recuperoSec != null).recuperoSec,
    if (carico == CaricoDellEsercizio.peso &&
        serie.any((s) => s.peso != null))
      'target_weight': serie.firstWhere((s) => s.peso != null).peso,

    ...muscoli,
  };
}
