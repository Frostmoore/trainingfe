/// Quanto regge una password, e **cosa fare per migliorarla**.
///
/// 🚨 **Il punteggio da solo non serve a niente.** Una barra che diventa rossa
/// senza dire perché lascia l'utente ad aggiungere un punto esclamativo in fondo
/// — che è esattamente la mossa che gli attacchi si aspettano. Quello che cambia
/// il comportamento è il **suggerimento concreto**, ed è per questo che qui il
/// prodotto principale è `suggerimenti`, non `score`.
///
/// ⚠️ **Questa è una guida, non il controllo di sicurezza.** Il controllo vero è
/// del backend (`RegisterRequest`), che rifiuta con 422 quello che non accetta.
/// Un giudizio calcolato sul telefono lo si aggira spegnendo il telefono.
///
/// Le regole seguono la sostanza delle linee guida NIST 800-63B: **la lunghezza
/// è la variabile che conta**, la composizione forzata («almeno un simbolo»)
/// produce password prevedibili, e ciò che va davvero impedito sono le password
/// nelle liste e quelle costruite sui dati personali di chi le sceglie.
library;

enum PasswordLevel {
  inesistente,
  troppoDebole,
  debole,
  discreta,
  buona,
  ottima;

  String get etichetta => switch (this) {
    PasswordLevel.inesistente => '',
    PasswordLevel.troppoDebole => 'Troppo debole',
    PasswordLevel.debole => 'Debole',
    PasswordLevel.discreta => 'Accettabile',
    PasswordLevel.buona => 'Buona',
    PasswordLevel.ottima => 'Ottima',
  };
}

class PasswordStrength {
  const PasswordStrength({
    required this.score,
    required this.level,
    required this.suggerimenti,
  });

  /// Da 0 a 4. È quello che riempie la barra.
  final int score;

  final PasswordLevel level;

  /// Cosa fare, in ordine di quanto migliorerebbe la password.
  ///
  /// Vuota solo quando non c'è più niente di utile da dire.
  final List<String> suggerimenti;

  /// 🚨 **La soglia dell'app coincide con quella del backend**: 8 caratteri e
  /// almeno una lettera e un numero. Sotto, il server risponde 422 comunque, e
  /// lasciar premere «Crea account» per farlo fallire dopo un giro di rete è
  /// solo un modo più lento di dire la stessa cosa.
  bool get accettabile => score >= 2;

  /// La lunghezza minima, la stessa del backend.
  static const lunghezzaMinima = 8;

  /// Le password che non si possono usare, comunque siano scritte.
  ///
  /// ⚠️ È un elenco **corto apposta**: non è la lista dei dieci milioni di
  /// password trapelate — quella sta lato server, dietro un controllo opzionale
  /// contro HaveIBeenPwned. Qui ci sono solo quelle che una persona sceglie
  /// davvero in un modulo di iscrizione in italiano, perché il messaggio arrivi
  /// **mentre** sta digitando invece che dopo il rifiuto.
  static const _comuni = {
    'password',
    'passw0rd',
    'qwerty',
    'qwertyuiop',
    'asdfgh',
    '123456',
    '12345678',
    '123456789',
    '1234567890',
    'iloveyou',
    'admin',
    'welcome',
    'letmein',
    'monkey',
    'dragon',
    'abc123',
    'ciaociao',
    'password1',
    'juventus',
    'milan',
    'inter',
    'napoli',
    'roma',
    'ferrari',
    'amoremio',
    'ti amo',
    'tiamo',
    'gennaio',
    'estate',
    'palestra',
    'allenamento',
    'francesco',
    'alessandro',
    'giuseppe',
    'antonio',
    'giovanni',
  };

  /// Valuta la password.
  ///
  /// 🚨 `nome`, `email` e `username` non sono decorazioni: una password
  /// costruita sul proprio nome è la prima cosa che si prova, e in un modulo di
  /// iscrizione quei dati sono **lì sopra, appena digitati**. Poterlo dire nel
  /// momento in cui succede è l'unico vantaggio che questo controllo ha rispetto
  /// a uno lato server.
  static PasswordStrength valuta(
    String password, {
    String? nome,
    String? email,
    String? username,
  }) {
    if (password.isEmpty) {
      return const PasswordStrength(
        score: 0,
        level: PasswordLevel.inesistente,
        suggerimenti: [],
      );
    }

    final suggerimenti = <String>[];
    final minuscola = password.toLowerCase();

    // ── 1. La lunghezza, che è la variabile dominante ────────────────────
    var punti = switch (password.length) {
      < lunghezzaMinima => 0,
      < 10 => 1,
      < 12 => 2,
      < 16 => 3,
      _ => 4,
    };

    if (password.length < lunghezzaMinima) {
      suggerimenti.add(
        'Servono almeno $lunghezzaMinima caratteri: ne hai ${password.length}.',
      );
    } else if (password.length < 12) {
      suggerimenti.add(
        'Allungala. La lunghezza conta più di ogni altra cosa: '
        'dodici caratteri semplici reggono meglio di otto complicati.',
      );
    }

    // ── 2. La varietà, che vale un punto solo ────────────────────────────
    //
    // ⚠️ Un punto solo, e mai più di uno: pretendere una maiuscola, un numero
    // e un simbolo produce «Password1!» in tutto il mondo. La varietà aiuta,
    // ma non è ciò che rende difficile indovinare.
    final haMinuscole = RegExp(r'[a-z]').hasMatch(password);
    final haMaiuscole = RegExp(r'[A-Z]').hasMatch(password);
    final haNumeri = RegExp(r'[0-9]').hasMatch(password);
    final haSimboli = RegExp(r'[^a-zA-Z0-9]').hasMatch(password);

    final classi = [
      haMinuscole,
      haMaiuscole,
      haNumeri,
      haSimboli,
    ].where((c) => c).length;

    // 🚨 Il bonus varietà **non si applica sotto la lunghezza minima**. `Ab1c`
    // ha tre classi su quattro e resterebbe a «debole» invece che a zero: una
    // password che il server rifiuta comunque non deve accendere nemmeno un
    // segmento della barra, o l'indicatore sta dicendo il contrario di quello
    // che succederà al salvataggio.
    if (classi >= 3 && password.length >= lunghezzaMinima) punti += 1;

    // Il minimo del backend: lettere **e** numeri. Va detto sempre, perché
    // senza il salvataggio fallisce con un 422 e basta.
    if (!(haMinuscole || haMaiuscole)) {
      suggerimenti.add('Aggiungi qualche lettera.');
    }
    if (!haNumeri) {
      suggerimenti.add('Aggiungi almeno un numero.');
    }
    if (classi < 3 && password.length < 16) {
      suggerimenti.add('Mescola maiuscole, minuscole e simboli.');
    }

    // ── 3. Le penalità, che tagliano il punteggio ────────────────────────

    // Una sola classe di caratteri e corta: è un dizionario che cammina.
    if (classi == 1 && password.length < 12) {
      punti = punti.clamp(0, 1);
    }

    if (_sequenzaORipetizione(minuscola)) {
      punti -= 1;
      suggerimenti.add(
        'Evita sequenze come «1234» o «abcd» e lettere ripetute: '
        'sono le prime combinazioni che si provano.',
      );
    }

    if (_eComune(minuscola)) {
      // A zero, non «meno uno»: una password di una lista si indovina in un
      // istante **qualunque** sia la sua lunghezza, quindi non c'è punteggio
      // parziale che abbia senso.
      punti = 0;
      suggerimenti.insert(
        0,
        'Questa è in tutte le liste degli attacchi: si indovina in un istante.',
      );
    }

    final personale = _datoPersonale(
      minuscola,
      nome: nome,
      email: email,
      username: username,
    );

    if (personale != null) {
      punti = punti.clamp(0, 1);
      suggerimenti.insert(
        0,
        'Non usare $personale nella password: è la prima cosa che si prova, '
        'e chi ti conosce non deve dover indovinare.',
      );
    }

    punti = punti.clamp(0, 4);

    // ── 4. Il consiglio che funziona davvero ─────────────────────────────
    //
    // Si dà solo quando c'è ancora margine: ripeterlo a chi ha già una
    // password ottima sarebbe rumore.
    if (punti < 3) {
      suggerimenti.add(
        'Un modo semplice: tre parole senza legame fra loro e un numero — '
        'si ricorda meglio di «P4ssw0rd!» e regge molto di più.',
      );
    }

    return PasswordStrength(
      score: punti,
      level: switch (punti) {
        0 => PasswordLevel.troppoDebole,
        1 => PasswordLevel.debole,
        2 => PasswordLevel.discreta,
        3 => PasswordLevel.buona,
        _ => PasswordLevel.ottima,
      },
      suggerimenti: List.unmodifiable(suggerimenti),
    );
  }

  /// La password è una di quelle note, o lo è togliendo cifre in coda.
  ///
  /// `password123` e `qwerty1` sono la stessa password di sempre con un numero
  /// appiccicato: contarle come diverse renderebbe l'elenco inutile.
  static bool _eComune(String minuscola) {
    if (_comuni.contains(minuscola)) return true;

    final senzaCodaNumerica = minuscola.replaceFirst(RegExp(r'[0-9!.]+$'), '');

    return senzaCodaNumerica.length >= 4 && _comuni.contains(senzaCodaNumerica);
  }

  /// Quale dato personale compare nella password, se ce n'è uno.
  ///
  /// Restituisce l'etichetta da mostrare («il tuo nome»), o `null`.
  static String? _datoPersonale(
    String minuscola, {
    String? nome,
    String? email,
    String? username,
  }) {
    // Sotto i 4 caratteri il confronto darebbe falsi positivi su qualunque
    // cosa: un nome come «Ada» comparirebbe dentro «adattamento».
    bool contiene(String? valore) {
      final v = valore?.trim().toLowerCase() ?? '';

      return v.length >= 4 && minuscola.contains(v);
    }

    // Il nome si controlla anche pezzo per pezzo: «Riccardo Ronconi» dà
    // «riccardo» e «ronconi», ed è quello che una persona ci mette dentro.
    for (final pezzo in (nome ?? '').toLowerCase().split(RegExp(r'\s+'))) {
      if (contiene(pezzo)) return 'il tuo nome';
    }

    if (contiene(username)) return 'il tuo nome utente';

    final localeEmail = (email ?? '').split('@').first;

    if (contiene(localeEmail)) return 'la tua email';

    return null;
  }

  /// Quattro caratteri in fila crescenti, decrescenti o uguali.
  ///
  /// Quattro e non tre: `abc` compare dentro parole legittime, `abcd` molto
  /// meno, e una soglia troppo bassa segnalerebbe password buone facendo
  /// ignorare l'avviso proprio quando conta.
  static bool _sequenzaORipetizione(String s) {
    if (s.length < 4) return false;

    for (var i = 0; i + 3 < s.length; i++) {
      final a = s.codeUnitAt(i);
      final b = s.codeUnitAt(i + 1);
      final c = s.codeUnitAt(i + 2);
      final d = s.codeUnitAt(i + 3);

      final passo = b - a;

      if ((passo == 0 || passo == 1 || passo == -1) &&
          c - b == passo &&
          d - c == passo) {
        return true;
      }
    }

    return false;
  }
}
