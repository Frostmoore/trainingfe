import 'dart:convert';

/// Cosa c'è dentro una busta — S7.
///
/// ── 🎯 L'idea, che è più semplice di quanto sembri ────────────────────────
///
/// Il corpo di un messaggio è già **byte opachi**: il server non li guarda e
/// non li capisce. Quindi non serve nessun canale nuovo per mandare una scheda:
/// basta che dentro la busta, invece di una frase, ci sia un oggetto con
/// scritto **che cosa è**.
///
/// ```
/// {"t":"text","v":1,"body":"Domani panca piana"}
/// {"t":"plan","v":1,"data":{ …la scheda… }}
/// ```
///
/// 🚨 **Il server non cambia di una riga.** Non sa distinguere un messaggio di
/// testo da una scheda, e non deve: continua a instradare buste. È la
/// dimostrazione che S6 non era un costo da pagare — era l'infrastruttura su
/// cui S7 si appoggia gratis.
///
/// ── ⚠️ La compatibilità con i messaggi già scritti ────────────────────────
///
/// I messaggi cifrati prima di S7 contengono testo **nudo**, non JSON. Chi
/// legge deve accorgersene e trattarli come testo, invece di mostrare un errore
/// su ogni messaggio precedente a questa versione.
sealed class ContenutoMessaggio {
  const ContenutoMessaggio();

  static const int versione = 1;

  /// Interpreta ciò che è uscito dalla busta.
  ///
  /// ⚠️ **Non lancia mai.** Qualunque cosa non si capisca diventa
  /// [ContenutoSconosciuto], che l'interfaccia mostra come «questo messaggio
  /// arriva da una versione più nuova dell'app». Una schermata che esplode per
  /// un messaggio su duecento è un guasto peggiore di un messaggio non letto.
  factory ContenutoMessaggio.daChiaro(String chiaro) {
    final Object? decodificato;

    try {
      decodificato = json.decode(chiaro);
    } on FormatException {
      // 💡 Non è un errore: è un messaggio scritto prima di S7, quando il corpo
      // era testo e basta.
      return ContenutoTesto(chiaro);
    }

    if (decodificato is! Map<String, dynamic>) {
      return ContenutoTesto(chiaro);
    }

    // ⚠️ **`data` può mancare o essere della forma sbagliata**, e non è un caso
    // teorico: basta una versione dell'app con un difetto, o un messaggio
    // troncato. Estrarlo qui una volta sola, con il tipo controllato, è ciò che
    // rende vera la promessa «non lancia mai» — che senza questo era solo
    // scritta nel dartdoc.
    final dentro = decodificato['data'];
    final dati = dentro is Map ? dentro.cast<String, dynamic>() : null;

    return switch (decodificato['t']) {
      'text' => ContenutoTesto(decodificato['body']?.toString() ?? ''),
      'plan' when dati != null => ContenutoScheda(dati),
      'meal_plan' when dati != null => ContenutoPianoAlimentare(dati),
      _ => ContenutoSconosciuto(decodificato['t']?.toString() ?? '?'),
    };
  }

  /// Cosa entra nella busta.
  String perLaBusta();
}

/// Una frase.
class ContenutoTesto extends ContenutoMessaggio {
  const ContenutoTesto(this.testo);

  final String testo;

  @override
  String perLaBusta() => json.encode({
    't': 'text',
    'v': ContenutoMessaggio.versione,
    'body': testo,
  });
}

/// Una scheda di allenamento, per intero.
///
/// 💡 **Dentro c'è tutto**, non un riferimento: nomi degli esercizi, serie,
/// ripetizioni, riposi. È il motivo per cui l'iscritto la conserva anche se
/// domani cambia palestra — e il motivo per cui il server, che pure ha il
/// modello da cui è nata, non sa a chi è stata mandata.
class ContenutoScheda extends ContenutoMessaggio {
  const ContenutoScheda(this.scheda);

  final Map<String, dynamic> scheda;

  String get titolo => scheda['title']?.toString() ?? 'Scheda';

  int get numeroEsercizi => (scheda['exercises'] as List?)?.length ?? 0;

  @override
  String perLaBusta() => json.encode({
    't': 'plan',
    'v': ContenutoMessaggio.versione,
    'data': scheda,
  });
}

/// Un piano alimentare.
class ContenutoPianoAlimentare extends ContenutoMessaggio {
  const ContenutoPianoAlimentare(this.piano);

  final Map<String, dynamic> piano;

  String get titolo => piano['title']?.toString() ?? 'Piano alimentare';

  @override
  String perLaBusta() => json.encode({
    't': 'meal_plan',
    'v': ContenutoMessaggio.versione,
    'data': piano,
  });
}

/// Qualcosa che questa versione dell'app non sa leggere.
///
/// 🚨 **Esiste perché il canale continui a funzionare quando il formato
/// cresce.** Il giorno in cui si manderà un tipo nuovo, i telefoni non ancora
/// aggiornati devono dire *«aggiorna l'app»* — non rompersi, e soprattutto non
/// far sparire il resto della conversazione.
class ContenutoSconosciuto extends ContenutoMessaggio {
  const ContenutoSconosciuto(this.tipo);

  final String tipo;

  @override
  String perLaBusta() => json.encode({
    't': tipo,
    'v': ContenutoMessaggio.versione,
  });
}
