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

  /// 🆕 **2 da G8**: le buste portano l'`origine_id` e i totali.
  ///
  /// ⚠️ **Le buste `v1` restano leggibili**, ed è la promessa di questa classe:
  /// «non lancia mai». Un piano arrivato prima di G8 semplicemente non ha
  /// l'identità stabile, e cade sul comportamento vecchio — una riga per
  /// messaggio, che è corretto, solo meno furbo.
  static const int versione = 2;

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
      'food_advice' when dati != null => ContenutoConsigliAlimentari(dati),
      'photo' when dati != null => ContenutoFoto.daiDati(dati),
      'document' when dati != null => ContenutoDocumento.daiDati(dati),
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

  /// L'identità stabile — D15. `null` per le buste `v1`.
  String? get origineId => scheda['origine_id']?.toString();

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

  /// ⚠️ Il server manda `name`; `title` resta accettato perche' le buste
  /// scritte prima di G8 lo usavano.
  String get titolo =>
      piano['name']?.toString() ?? piano['title']?.toString() ?? 'Piano alimentare';

  /// L'identità stabile — D15. `null` per le buste `v1`.
  String? get origineId => piano['origine_id']?.toString();

  int get numeroGiorni => (piano['days'] as List?)?.length ?? 0;

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

/// Una foto: **il riferimento e la chiave, non i byte** — N13.2.
///
/// ── 🚨 Perche' i byte non stanno qui dentro ────────────────────────────
///
/// Una conversazione si carica tutta insieme. Con le foto dentro le buste,
/// aprire una chat con venti foto vorrebbe dire scaricare otto megabyte **ogni
/// volta**, anche solo per rileggere una riga di testo. E un invio interrotto
/// ricomincerebbe da capo invece di riprendere.
///
/// 💡 Quindi la busta porta due cose piccolissime: **dove** sono i byte
/// (`token`) e **come si aprono** (`chiave`). I byte viaggiano per conto loro,
/// gia' cifrati con quella chiave.
///
/// 🚨 **Il server non ha nessuno dei due pezzi in chiaro**: tiene un blob
/// cifrato con una chiave che non ha mai visto, e un messaggio cifrato che non
/// sa aprire.
///
/// ⚠️ **Vive 24 ore.** Passate quelle il server butta il blob, e questa busta
/// resta come una porta senza stanza dietro. Chi la mostra deve dirlo — non
/// lasciare un riquadro che gira all'infinito.
class ContenutoFoto extends ContenutoMessaggio {
  const ContenutoFoto({
    required this.token,
    required this.chiaveBase64,
    this.byteTotali,
  });

  factory ContenutoFoto.daiDati(Map<String, dynamic> dati) => ContenutoFoto(
    token: dati['token']?.toString() ?? '',
    chiaveBase64: dati['k']?.toString() ?? '',
    byteTotali: (dati['bytes'] as num?)?.toInt(),
  );

  /// Dove stanno i byte, sul server. 💡 Casuale: un id progressivo si indovina.
  final String token;

  /// La chiave che li apre, in base64.
  final String chiaveBase64;

  /// Quanto pesano, per poterlo dire prima di cominciare a scaricare.
  final int? byteTotali;

  /// ⚠️ Una busta senza uno dei due pezzi non e' apribile: meglio accorgersene
  /// mostrando «questa foto non c'e' piu'» che provare a scaricare `''`.
  bool get completa => token.isNotEmpty && chiaveBase64.isNotEmpty;

  @override
  String perLaBusta() => json.encode({
    't': 'photo',
    'v': ContenutoMessaggio.versione,
    'data': {
      'token': token,
      'k': chiaveBase64,
      if (byteTotali != null) 'bytes': byteTotali,
    },
  });
}

/// Consigli alimentari: un elenco di alimenti — N19.3.
///
/// ── 🚨 Perche' e' un tipo SUO e non un piano con meno campi ─────────────
///
/// Un `ContenutoPianoAlimentare` con i giorni vuoti sarebbe stato piu' rapido,
/// e sbagliato: chi lo riceve non saprebbe se e' un elenco di consigli o un
/// piano arrivato monco. ⚠️ E il giorno che un nutrizionista mandera' un piano
/// vero (N22), i due dovranno **disegnarsi in modo diverso** — perche' sono due
/// cose diverse, e una delle due e' un atto riservato.
///
/// 💡 Dentro c'e' quello che un trainer puo' dare: **nomi di alimenti**.
/// Niente grammi, niente orari, niente giorni.
class ContenutoConsigliAlimentari extends ContenutoMessaggio {
  const ContenutoConsigliAlimentari(this.consigli);

  final Map<String, dynamic> consigli;

  String get titolo => consigli['name']?.toString() ?? 'Consigli alimentari';

  /// Gli alimenti consigliati, in ordine.
  List<String> get alimenti => ((consigli['foods'] as List?) ?? const [])
      .map((e) => e.toString())
      .where((e) => e.trim().isNotEmpty)
      .toList(growable: false);

  String? get note => consigli['notes']?.toString();

  @override
  String perLaBusta() => json.encode({
    't': 'food_advice',
    'v': ContenutoMessaggio.versione,
    'data': consigli,
  });
}

/// Un documento — N21.
///
/// ── 💡 Perche' non e' una `ContenutoFoto` con un nome diverso ─────────────
///
/// Viaggiano nello stesso modo — token, chiave, byte cifrati altrove — ma si
/// **mostrano** in modo opposto: una foto si disegna, un documento no. ⚠️ Un
/// riquadro che prova a disegnare un PDF darebbe un rettangolo grigio, e chi lo
/// guarda penserebbe che la foto non e' arrivata.
///
/// 🚨 E qui il **nome del file conta**: «piano-marzo.pdf» dice cosa si sta
/// per aprire, mentre una foto si riconosce guardandola. E' l'unica differenza
/// vera nella busta.
class ContenutoDocumento extends ContenutoMessaggio {
  const ContenutoDocumento({
    required this.token,
    required this.chiaveBase64,
    required this.nome,
    this.byteTotali,
  });

  factory ContenutoDocumento.daiDati(Map<String, dynamic> dati) =>
      ContenutoDocumento(
        token: dati['token']?.toString() ?? '',
        chiaveBase64: dati['k']?.toString() ?? '',
        nome: dati['nome']?.toString() ?? 'documento.pdf',
        byteTotali: (dati['bytes'] as num?)?.toInt(),
      );

  final String token;
  final String chiaveBase64;

  /// 🚨 Il nome che si mostra, **non un percorso**. Chi lo scrive su disco
  /// deve passarlo comunque da `basename`: arriva dall'altro telefono.
  final String nome;

  final int? byteTotali;

  bool get completa => token.isNotEmpty && chiaveBase64.isNotEmpty;

  /// «2,4 MB» — per dirlo prima di cominciare a scaricare.
  ///
  /// 💡 Su un documento serve piu' che su una foto: una foto la si scarica
  /// e la si guarda, un PDF da otto megabyte su rete mobile e' una decisione.
  String? get pesoLeggibile {
    final b = byteTotali;

    if (b == null) return null;
    if (b < 1000) return '$b byte';

    const unita = ['kB', 'MB', 'GB'];
    var v = b / 1000;
    var i = 0;

    while (v >= 1000 && i < unita.length - 1) {
      v /= 1000;
      i++;
    }

    return '${v.toStringAsFixed(1).replaceAll('.', ',')} ${unita[i]}';
  }

  @override
  String perLaBusta() => json.encode({
    't': 'document',
    'v': ContenutoMessaggio.versione,
    'data': {
      'token': token,
      'k': chiaveBase64,
      'nome': nome,
      if (byteTotali != null) 'bytes': byteTotali,
    },
  });
}
