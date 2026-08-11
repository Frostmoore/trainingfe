/// I tipi dei dati del corpo — S3.
///
/// 🚨 **Sono il ritratto fedele degli enum PHP cancellati in S1**
/// (`App\Enums\HealthMetric` e `App\Enums\SleepStage`). Le soglie, le
/// numerazioni e i limiti di plausibilità sono **copiati, non ricordati**: la
/// regola §2.3 del piano dice che spostare non è migliorare, perché altrimenti
/// non si distingue più un difetto del trasloco da uno della modifica.
library;

/// Cosa misura il sensore.
///
/// ⚠️ I valori stringa (`hrv`, `resting_hr`, `hr`) sono gli stessi che usava il
/// backend. Non servono più a nessun protocollo — i dati non escono dal telefono
/// — ma restano identici perché sono **anche** ciò che si legge in un dump del
/// database locale quando qualcosa non torna.
enum MetricaSalute {
  hrv('hrv', 'Variabilità cardiaca', 'ms', 5.0, 300.0),
  battitoARiposo('resting_hr', 'Battito a riposo', 'bpm', 25.0, 120.0),
  battitoMedio('hr', 'Battito medio', 'bpm', 30.0, 220.0);

  const MetricaSalute(this.codice, this.etichetta, this.unita, this._min, this._max);

  final String codice;
  final String etichetta;
  final String unita;
  final double _min;
  final double _max;

  /// 🚨 **Un valore fuori scala si SCARTA, non si salva «tanto poi si vede».**
  ///
  /// Un HRV di 4000 ms non è un dato con un errore: è rumore del sensore, e
  /// basta una lettura del genere per spostare la media di riferimento di
  /// giorni. Siccome tutto il resto ragiona **sullo scostamento dalla media**,
  /// un solo valore assurdo non sbaglia un numero: rende inutile la funzione.
  bool plausibile(double valore) => valore >= _min && valore <= _max;

  static MetricaSalute? daCodice(String codice) {
    for (final m in MetricaSalute.values) {
      if (m.codice == codice) return m;
    }
    return null;
  }
}

/// Le fasi del sonno.
///
/// ⚠️ **La numerazione è NOSTRA, non quella di Health Connect.** Health Connect
/// usa una scala più fine (e diversa fra versioni); questi quattro valori sono
/// quelli su cui ragiona il giudizio della notte, e `daHealthConnect()` è
/// l'unico punto in cui le due scale si incontrano.
enum FaseSonno {
  sveglio(1, 'Sveglio'),
  leggero(2, 'Leggero'),
  profondo(3, 'Profondo'),
  rem(4, 'REM');

  const FaseSonno(this.codice, this.etichetta);

  final int codice;
  final String etichetta;

  bool get dorme => this != FaseSonno.sveglio;

  static FaseSonno daCodice(int codice) => switch (codice) {
    2 => FaseSonno.leggero,
    3 => FaseSonno.profondo,
    4 => FaseSonno.rem,
    _ => FaseSonno.sveglio,
  };

  /// La traduzione dalla scala di Health Connect alla nostra.
  ///
  /// ⚠️ Copiata da `SleepStage::fromHealthConnect()`: tutto ciò che non è
  /// riconosciuto diventa **sveglio**, non «leggero». Contare come sonno una
  /// fase che non si sa interpretare gonfia i minuti dormiti, che è l'errore
  /// che rende il giudizio troppo generoso proprio a chi ha dormito male.
  static FaseSonno daHealthConnect(int codice) => switch (codice) {
    4 || 2 => FaseSonno.leggero,
    5 => FaseSonno.profondo,
    6 => FaseSonno.rem,
    _ => FaseSonno.sveglio,
  };
}

/// A quale notte appartiene un istante.
///
/// 🚨 **Un campione delle 02:00 appartiene alla notte del giorno PRECEDENTE.**
/// Senza questa regola, chi va a letto alle 23:30 avrebbe il sonno spezzato su
/// due giorni e **nessuna delle due notti risulterebbe sufficiente**.
///
/// Lo spartiacque è **mezzogiorno**: chi dorme a cavallo di mezzogiorno sta
/// facendo qualcosa che questo sistema non saprebbe interpretare comunque.
///
/// ⚠️ È il ritratto di `HealthSample::nightOf()`. Sbagliarlo sposta tutto di un
/// giorno, e il sintomo — «l'ipnogramma è vuoto» — fa cercare il difetto nella
/// lettura dei dati invece che qui.
DateTime notteDi(DateTime istante) {
  final giorno = DateTime(istante.year, istante.month, istante.day);

  return istante.hour < 12 ? giorno.subtract(const Duration(days: 1)) : giorno;
}

/// Il giudizio su un indicatore: `ok`, `warn` o `bad`.
enum Giudizio {
  ok,
  warn,
  bad;

  static Giudizio daNome(String nome) => switch (nome) {
    'ok' => Giudizio.ok,
    'warn' => Giudizio.warn,
    _ => Giudizio.bad,
  };

  String get nome => switch (this) {
    Giudizio.ok => 'ok',
    Giudizio.warn => 'warn',
    Giudizio.bad => 'bad',
  };
}
