/// Come cambia una scheda nel tempo — 3b-I.E, 27/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// 📌 *«devi fare in modo che siamo sicuri che le modifiche il programma le
/// veda: cioè deve vedere com'era prima e com'era dopo … ci deve essere
/// qualcosa che tiene traccia del modo in cui cambia la scheda nel corso del
/// tempo»*.
///
/// ══ 🚨 PERCHÉ NON BASTAVA LO STORICO DELLE SERIE ══════════════════════════
///
/// `SerieDelleSedute` registra **quello che hai fatto**. La scheda invece è
/// **quello che ti eri prescritto**, e le due cose cambiano per ragioni
/// diverse: le ripetizioni che scendono possono essere una brutta giornata
/// oppure una serie in più aggiunta alla scheda una settimana fa.
///
/// ⛔ Senza questo file l'app non può distinguerle, e l'analisi finisce per
/// raccontare un calo dove c'è un cambio di programma — che è **una frase
/// sbagliata detta con sicurezza**.
///
/// ══ 💡 SOLO TIPI E FUNZIONI PURE ══════════════════════════════════════════
///
/// Niente database, niente rete: si può provare con un test. La scrittura la fa
/// `ArchivioSalute`, la lettura il controller.
library;

import 'dart:convert';

/// Cosa è cambiato, in un esercizio, fra due versioni di una scheda.
class CambioDellaScheda {
  const CambioDellaScheda({
    required this.esercizio,
    required this.cosa,
    this.esercizioId,
    this.prima,
    this.dopo,
  });

  /// Il nome dell'esercizio, come si chiamava **dopo** il cambio.
  final String esercizio;

  /// L'id del catalogo, quando c'è: è la chiave con cui questo cambio si lega
  /// allo storico delle serie.
  final int? esercizioId;

  /// `serie` · `ripetizioni` · `peso` · `recupero` · `aggiunto` · `tolto`.
  final String cosa;

  /// ⚠️ `null` su `aggiunto`, e su `tolto` è l'altro a essere `null`: sono i
  /// due casi in cui un «da → a» non esiste, e inventarlo direbbe una cosa
  /// falsa.
  final String? prima;
  final String? dopo;

  /// Come viaggia verso il server, dentro il contesto dell'analisi.
  Map<String, Object?> versoIlServer() => {
    'cosa': cosa,
    'prima': prima,
    'dopo': dopo,
  };

  /// Come si legge in italiano. 💡 Usata dall'app, non dal modello.
  String get frase => switch (cosa) {
    'aggiunto' => 'aggiunto',
    'tolto' => 'tolto',
    _ => '$cosa: ${prima ?? '—'} → ${dopo ?? '—'}',
  };
}

/// Una versione della scheda, con quando è stata scattata.
class VersioneDellaScheda {
  const VersioneDellaScheda({required this.quando, required this.contenuto});

  final DateTime quando;

  /// Il JSON della scheda com'era.
  final String contenuto;
}

/// L'impronta di **cosa c'è da allenare**, non della scheda intera.
///
/// ══ 🚨 IL NOME E LE NOTE NON CI SONO DENTRO, DI PROPOSITO ═════════════════
///
/// ⛔ Rinominare una scheda, o correggere un refuso in una nota, **non è un
/// cambio di programma**: se entrasse nell'impronta genererebbe una versione
/// nuova, e più avanti l'analisi direbbe «la scheda è cambiata» davanti a una
/// virgola spostata.
///
/// 💡 Dentro ci sono, per ogni esercizio in ordine: il nome, e per ogni serie
/// ripetizioni, peso, isometria e recupero. Cioè **tutto quello che si esegue**.
String improntaDellaScheda(String schedaJson) {
  final pezzi = <String>[];

  for (final e in _eserciziDi(schedaJson)) {
    final serie = <String>[];

    for (final s in _serieDi(e)) {
      serie.add(
        '${s['reps'] ?? ''},${s['weight'] ?? ''},'
        '${s['iso_sec'] ?? ''},${s['rest_sec'] ?? ''}',
      );
    }

    pezzi.add('${e['name'] ?? ''}[${serie.join(';')}]');
  }

  return pezzi.join('|');
}

/// Cosa è cambiato fra due versioni della stessa scheda.
///
/// ══ ⚠️ GLI ESERCIZI SI CONFRONTANO PER **POSTO**, NON PER ID ══════════════
///
/// 🚨 Perché l'id del catalogo **manca su tutti gli esercizi scritti a mano**, e
/// due esercizi senza id sarebbero indistinguibili. 💡 È anche la convenzione
/// che il resto dell'app usa già: *«l'identità di un esercizio dentro una scheda
/// è il suo posto»* — sta scritto in `training_controller.dart`.
///
/// ⛔ **Il prezzo, e va saputo**: spostare il terzo esercizio al primo posto si
/// legge come «tre esercizi cambiati» invece che come un riordino. Riconoscere
/// gli spostamenti vorrebbe dire indovinare quale esercizio è «lo stesso», e
/// indovinare male qui produce una frase falsa detta con sicurezza — che è
/// peggio di una frase goffa.
List<CambioDellaScheda> differenzeFraSchede(String prima, String dopo) {
  final vecchi = _eserciziDi(prima);
  final nuovi = _eserciziDi(dopo);
  final fuori = <CambioDellaScheda>[];

  for (var i = 0; i < nuovi.length; i++) {
    final n = nuovi[i];
    final nome = n['name']?.toString() ?? 'Esercizio';
    final id = (n['exercise_id'] as num?)?.toInt();

    if (i >= vecchi.length) {
      fuori.add(
        CambioDellaScheda(esercizio: nome, esercizioId: id, cosa: 'aggiunto'),
      );

      continue;
    }

    fuori.addAll(_differenzeDellEsercizio(vecchi[i], n, nome, id));
  }

  for (var i = nuovi.length; i < vecchi.length; i++) {
    fuori.add(
      CambioDellaScheda(
        esercizio: vecchi[i]['name']?.toString() ?? 'Esercizio',
        esercizioId: (vecchi[i]['exercise_id'] as num?)?.toInt(),
        cosa: 'tolto',
      ),
    );
  }

  return fuori;
}

/// I cambi che riguardano **un** esercizio, dal più vecchio al più recente.
///
/// 💡 Serve al contesto dell'analisi: là ogni esercizio porta la propria storia,
/// non quella della scheda intera.
List<CambioDellaScheda> cambiDellEsercizio(
  List<VersioneDellaScheda> versioni,
  int esercizioId,
) {
  final fuori = <CambioDellaScheda>[];

  for (var i = 1; i < versioni.length; i++) {
    for (final c in differenzeFraSchede(
      versioni[i - 1].contenuto,
      versioni[i].contenuto,
    )) {
      if (c.esercizioId == esercizioId) fuori.add(c);
    }
  }

  return fuori;
}

// ───────────────────────── il confronto, serie per serie ─────────────────

List<CambioDellaScheda> _differenzeDellEsercizio(
  Map<String, Object?> vecchio,
  Map<String, Object?> nuovo,
  String nome,
  int? id,
) {
  final a = _serieDi(vecchio);
  final b = _serieDi(nuovo);
  final fuori = <CambioDellaScheda>[];

  if (a.length != b.length) {
    fuori.add(
      CambioDellaScheda(
        esercizio: nome,
        esercizioId: id,
        cosa: 'serie',
        prima: '${a.length}',
        dopo: '${b.length}',
      ),
    );
  }

  /*
   * 💡 **Un cambio per campo, non uno per serie.** ⛔ «serie 1: 12→15, serie 2:
   * 12→15, serie 3: 12→15» sono tre righe che dicono la stessa cosa: quello che
   * conta è che le ripetizioni sono passate da 12 a 15. 🚨 Tre righe per un
   * cambio solo riempirebbero il contesto dell'AI di rumore, e il modello
   * scriverebbe la frase guardando il rumore.
   */
  for (final campo in const ['reps', 'weight', 'rest_sec', 'iso_sec']) {
    final da = _riassunto(a, campo);
    final ad = _riassunto(b, campo);

    if (da == ad) continue;

    fuori.add(
      CambioDellaScheda(
        esercizio: nome,
        esercizioId: id,
        cosa: switch (campo) {
          'reps' => 'ripetizioni',
          'weight' => 'peso',
          'rest_sec' => 'recupero',
          _ => 'isometria',
        },
        prima: da,
        dopo: ad,
      ),
    );
  }

  return fuori;
}

/// I valori di un campo su tutte le serie, come `12` oppure `15-12-10`.
///
/// ⚠️ **Vuoto se non lo dichiara nessuna serie**, e non `0`: un recupero non
/// dichiarato non è un recupero di zero secondi.
String _riassunto(List<Map<String, Object?>> serie, String campo) {
  final valori = <String>[];

  for (final s in serie) {
    final v = s[campo];

    if (v != null) valori.add(_numero(v));
  }

  if (valori.isEmpty) return '';

  // 💡 Tutte uguali: si scrive una volta sola. È come le persone leggono una
  // scheda — «4 serie da 8», non «8-8-8-8».
  return valori.toSet().length == 1 ? valori.first : valori.join('-');
}

/// `62.5` resta `62.5`, `60.0` diventa `60`.
///
/// ⛔ Uno zero dietro la virgola **sembra una precisione**: dice che qualcuno ha
/// misurato il decimo di chilo. È la stessa regola già scritta in
/// `EsercizioDellaScheda`.
String _numero(Object v) {
  if (v is num && v == v.roundToDouble()) return v.toInt().toString();

  return v.toString();
}

List<Map<String, Object?>> _eserciziDi(String schedaJson) {
  /*
   * ⚠️ **Un JSON illeggibile non è un errore da propagare.** Questa funzione la
   * chiama la scrittura di una scheda: farla esplodere vorrebbe dire non poter
   * più salvare, per un difetto in una funzione accessoria. ⛔ Senza versioni si
   * vive; senza poter salvare no.
   */
  try {
    final letto = jsonDecode(schedaJson);

    if (letto is! Map) return const [];

    final esercizi = letto['exercises'];

    if (esercizi is! List) return const [];

    return [
      for (final e in esercizi)
        if (e is Map) e.cast<String, Object?>(),
    ];
  } on Object {
    return const [];
  }
}

List<Map<String, Object?>> _serieDi(Map<String, Object?> esercizio) {
  final serie = esercizio['serie'];

  if (serie is! List) return const [];

  return [
    for (final s in serie)
      if (s is Map) s.cast<String, Object?>(),
  ];
}
