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

/// Un punto del grafico: la media di una metrica in un giorno.
///
/// 💡 Porta anche **minimo e massimo**: su una metrica che l'orologio campiona
/// centinaia di volte al giorno, la sola media nasconde quanto è ballerina —
/// e una giornata con HRV fra 20 e 90 non è la stessa cosa di una stabile a 55,
/// anche quando la media coincide.
class MediaGiornaliera {
  const MediaGiornaliera({
    required this.giorno,
    required this.media,
    required this.minimo,
    required this.massimo,
    required this.quante,
  });

  final DateTime giorno;
  final double media;
  final double minimo;
  final double massimo;

  /// Quante letture ci sono dietro. ⚠️ Un giorno con **una** lettura non è una
  /// media: l'interfaccia deve poterlo distinguere.
  final int quante;
}

/// L'ora dopo la quale un sonno che comincia **appartiene al giorno dopo**.
///
/// ⚠️ È una convenzione, non una verità: chi va a dormire alle 17:30 la vedrà
/// contata come riposino del giorno stesso. Diciotto è il compromesso che tiene
/// insieme «vado a letto presto, alle 21» e «schiaccio un pisolino alle 17».
const int oraCheChiudeLaGiornata = 18;

/// A quale **giornata di riposo** appartiene un istante.
///
/// ── 🚨 La regola, dettata il 12/08/2026 dopo la prova su telefono ─────────
///
/// *«Il sonno deve cominciare quando mi sono addormentato e finire quando mi
/// sono svegliato. Se vado a letto alle 21:00 e mi sveglio alle 08:00 me lo
/// deve considerare tutto come questa notte; poi magari mi faccio una pennica
/// dalle 15:00 alle 16:30, si deve aggiungere alla giornata di oggi.»*
///
/// Cioè: **il riposo si accredita al giorno in cui ci si sveglia**, e i
/// riposini del pomeriggio si sommano a quello stesso giorno.
///
/// | Quando cominci | Giornata |
/// |---|---|
/// | 21:00 del 12 | **13** — ti sveglierai domani |
/// | 02:00 del 13 | **13** — stessa dormita, stesso mucchio |
/// | 07:30 del 13 | **13** — ancora la stessa |
/// | 15:00 del 13 *(pennica)* | **13** — si somma a oggi |
///
/// ── ⚠️ Perché lo spartiacque NON è mezzogiorno ────────────────────────────
///
/// Prima la regola era «prima di mezzogiorno = notte precedente», e il sintomo
/// era quello riferito provando l'app: **il sonno di stanotte compariva sotto
/// ieri**. Il rimedio ovvio — tenere mezzogiorno e spostare l'etichetta di un
/// giorno — sembra funzionare e **rompe i riposini**: la pennica delle 15:00
/// finirebbe accreditata a **domani**.
///
/// 🚨 Ci vogliono due soglie diverse perché le due cose sono diverse: la sera
/// apre la notte **del giorno dopo**, il pomeriggio appartiene al giorno
/// stesso.
///
/// ── ⚠️ `DateTime(y, m, d + 1)`, mai `add(Duration(days: 1))` ─────────────
///
/// Il costruttore normalizza sull'**orologio da parete** e regge l'ora legale;
/// sommare 86.400 secondi no. Il 25 ottobre a Roma dura 25 ore, e `+24h` da
/// mezzanotte cade alle 23:00 dello stesso giorno — cioè il riposo di quella
/// notte sparirebbe nel giorno sbagliato una volta l'anno. È la stessa
/// trappola di `GiornoLocale::piuGiorni()` lato server.
DateTime notteDi(DateTime istante) {
  final giorno = DateTime(istante.year, istante.month, istante.day);

  return istante.hour >= oraCheChiudeLaGiornata
      ? DateTime(giorno.year, giorno.month, giorno.day + 1)
      : giorno;
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
