import 'dart:math' as math;

/// I grammi dei tre macronutrienti.
class Macro {
  const Macro({
    required this.proteineG,
    required this.carboidratiG,
    required this.grassiG,
  });

  final int proteineG;
  final int carboidratiG;
  final int grassiG;
}

/// Il ritratto in Dart di `CalorieCalculator` — S5.1.
///
/// 🚨 **È una traduzione fedele.** I coefficienti sono stati **copiati dal file
/// PHP**, non ricordati: la regola §2.3 del piano — *spostare non è migliorare*
/// — esiste perché altrimenti un difetto del trasloco e uno introdotto per
/// strada diventano indistinguibili.
///
/// ⚠️ **Questa classe contraddice §8.3 dell'atlante dell'app** — *«le decisioni
/// del server non si riscrivono in Dart»* — ed è **un'eccezione dichiarata, non
/// un precedente**. La ragione è precisa: dopo S5 il server **non ha più peso,
/// altezza ed età di nessuno** (decisione D9-bis), quindi non può calcolare
/// niente su di essi. Non è che abbiamo preferito farlo qui: è che là non si
/// può più.
///
/// 🚨 Chi in futuro volesse spostare in Dart un'altra regola del server deve
/// chiedersi se il server **ha ancora i dati per applicarla**. Se sì, la
/// risposta è no.
///
/// ⚠️ **`CalorieCalculator` resta vivo sul backend**: serve al pannello del
/// trainer, che compone i **modelli** di piano — e i modelli non sono dati
/// personali. Le due copie non divergono perché nessuna delle due calcola sulla
/// stessa cosa: quella lì lavora su valori d'esempio, questa sulla persona.
class CalcolatoreCalorie {
  const CalcolatoreCalorie();

  /// Moltiplicatori del **modello «stima»**: i valori standard di
  /// Harris-Benedict.
  ///
  /// ⚠️ Sono descritti ad **allenamenti a settimana**, e quindi lo sport ce
  /// l'hanno già dentro: chi sceglie uno di questi non deve sommarci anche gli
  /// allenamenti misurati dall'orologio, o li conta due volte.
  ///
  /// 💡 L'ultimo, `athlete`, copre chi si allena due volte al giorno e nella
  /// tabella standard non c'è.
  static const attivitaStima = <String, double>{
    'sedentary': 1.2,
    'light': 1.375,
    'moderate': 1.55,
    'active': 1.725,
    'very_active': 1.9,
  };

  /// Moltiplicatori del **modello «misurata»**: l'attività quotidiana **non
  /// sportiva** — 3b-G.1, 26/08/2026.
  ///
  /// ══ 🚨 QUESTI NON SONO I FATTORI DI HARRIS-BENEDICT ═══════════════════════
  ///
  /// ⛔ **E non vanno «corretti» riportandoli alla tabella qui sopra.** Quelli
  /// includono lo sport, questi lo **escludono di proposito**, perché in questo
  /// modello lo sport lo misura l'orologio e si somma a parte. Chi li allinea fa
  /// contare gli allenamenti due volte, e nessun test se ne accorge perché il
  /// numero resta plausibile.
  ///
  /// ⚠️ **Non sono nemmeno i PAL della FAO** (1,40-1,69 per la vita sedentaria):
  /// quelli descrivono chi cammina 6-8.000 passi al giorno. Il pavimento qui è
  /// più basso perché esiste — ed è misurato — chi ne fa 2.500, e per lui la
  /// tabella FAO non ha nessun gradino.
  ///
  /// ══ 💡 DA DOVE VENGONO I NUMERI ═══════════════════════════════════════════
  ///
  /// Ricavati il 26/08/2026 dai dati veri del committente, con **due conti
  /// indipendenti che concordano**:
  ///
  /// | Metodo | Risultato |
  /// |---|---|
  /// | bilancio energetico (assunte + peso perso × 7.700) | 1,16 ± 0,20 |
  /// | costruzione dal basso (BMR + termogenesi + passi misurati) | 1,24-1,27 |
  ///
  /// 🚨 E hanno **escluso 1,50**, che era la proposta di partenza: a 96,6 kg un
  /// fattore 1,50 richiede ~761 kcal di movimento al giorno, cioè **circa 28.000
  /// passi**. Lui ne fa 2.492 (agosto 2026, misurati da Health Connect).
  static const attivitaQuotidiana = <String, double>{
    'desk': 1.25,
    'standing': 1.45,
    'on_feet': 1.65,
    'labour': 1.9,
  };

  /// Tutti i fattori, di qualunque modello.
  ///
  /// ⚠️ **Le chiavi dei due modelli non si sovrappongono**, ed è la proprietà su
  /// cui poggia tutto il resto: da una chiave si risale al modello, quindi non
  /// serve un secondo campo «modalità» da tenere allineato — e da sbagliare.
  /// I nomi del **vocabolario del calcolatore**, che non è quello del profilo.
  ///
  /// ══ 🚨 DUE NOMI PER LO STESSO GRADINO, E COSA E' COSTATO ══════════════════
  ///
  /// Il profilo salva `very_active`, il calcolatore lo chiamava `athlete`: sono
  /// lo stesso 1,9, con due nomi, perché la tabella nasce in B1.4 e il
  /// calcolatore è il port di un'app precedente. ⛔ Il 12/08/2026 quel disallineo
  /// è costato **1,2 al posto di 1,9** a chi si allenava ogni giorno — nessun
  /// errore, solo un fabbisogno più basso del vero.
  ///
  /// 💡 Da 3b-G il gradino si cerca con il **nome del profilo**, che è quello
  /// che l'app salva davvero. `athlete` resta qui perché [tdee] è il ritratto
  /// fedele del metodo PHP e continua a riceverlo, e perché i profili non ancora
  /// ritradotti passano di lì.
  ///
  /// ⚠️ Non è una tabella nuova: è **lo stesso numero sotto l'altro nome**. Chi
  /// ne cambia uno deve cambiare l'altro, e il test `traduzione_profilo_test`
  /// fallisce se non lo fa.
  static const aliasStorici = <String, double>{'athlete': 1.9};

  /// Tutti i fattori, di qualunque modello e con tutti i nomi.
  static const attivita = <String, double>{
    ...attivitaStima,
    ...attivitaQuotidiana,
    ...aliasStorici,
  };

  /// Il fattore di un livello, **`null` se non lo conosciamo**.
  ///
  /// 🚨 **Niente ripiego, ed è il punto di tutta la 3b-G.** Il ripiego naturale
  /// sarebbe `?? 1.2`: una chiave sconosciuta darebbe un fabbisogno **più basso
  /// del vero**, plausibile, senza nessun errore da nessuna parte. È già
  /// successo con `very_active`, che valeva 1,9 e ne prendeva 1,2.
  ///
  /// 💡 Chi non sa il fattore non deve inventarlo: deve **dire che non lo sa**.
  static double? fattoreDi(String? chiave) {
    if (chiave == null) return null;

    return attivita[chiave.toLowerCase().trim()];
  }

  /// Scostamento dal fabbisogno, per obiettivo.
  ///
  /// ⚠️ **Percentuali e non valori fissi**: −500 kcal su chi ne consuma 3.000 è
  /// un taglio del 17%, sulla stessa persona a 1.600 è il 31% ed è
  /// insostenibile.
  ///
  /// 🚨 **Cinque gradini, simmetrici** — 12/08/2026.
  ///
  /// Il committente: *«non è una stima accurata se sono solo 3 scelte»*. Con
  /// tre gradini l'unica alternativa a «mantenere» era un taglio del 15%:
  /// troppo per chi vuole andare piano, troppo poco per chi ha fretta — e chi
  /// non si ritrova nel numero smette di fidarsi dell'app, non dell'obiettivo.
  ///
  /// Su un TDEE di 2.500 kcal: 2.000 → 2.250 → 2.500 → 2.750 → 3.000.
  ///
  /// ⚠️ **Ritratto fedele di `CalorieCalculator::GOAL_DELTA`.** Chi cambia un
  /// numero di là deve cambiarlo qui, o l'app e il server mostrerebbero due
  /// target diversi per la stessa persona.
  static const deltaObiettivo = <String, double>{
    'lose_fast': -0.20,
    'lose_slow': -0.10,
    'maintain': 0.0,
    'gain_lean': 0.10,
    'gain_fast': 0.20,
  };

  /// ⚠️ Il vocabolario precedente, per i profili non ancora migrati.
  ///
  /// 🚨 `cut` valeva −25% e **nessuno lo impostava mai**: il commento diceva
  /// che arrivava dal piano alimentare, e nel piano alimentare non c'era una
  /// riga che lo facesse. Il suo posto lo prende `lose_fast`.
  static const obiettiviStorici = <String, String>{
    'lose': 'lose_slow',
    'cut': 'lose_fast',
    'bulk': 'gain_lean',
    'lose_weight': 'lose_slow',
    'gain_muscle': 'gain_lean',
  };

  /// Un obiettivo qualunque, portato al vocabolario di oggi.
  static String normalizzaObiettivo(String obiettivo) {
    final o = obiettivo.toLowerCase().trim();

    return obiettiviStorici[o] ?? o;
  }

  /// Ripartizione dei macro in percentuale delle calorie, per obiettivo.
  ///
  /// 🚨 **Percentuali del target e non grammi per chilo, ed è una scelta.** La
  /// formula g/kg è più comune, ma su una persona di 120 kg in forte deficit
  /// produce più proteine di quante ne stiano nel target: il conto non torna e
  /// bisogna correggerlo a mano. In percentuale il conto torna sempre.
  ///
  /// I due gradini di dimagrimento alzano le proteine perché in deficit servono
  /// a limitare la perdita di massa magra — che è esattamente ciò che l'utente
  /// non vuole perdere. Più il deficit è grande, più servono.
  static const ripartizioneMacro = <String, Map<String, double>>{
    'lose_fast': {'protein': 0.38, 'carbs': 0.32, 'fat': 0.30},
    'lose_slow': {'protein': 0.32, 'carbs': 0.38, 'fat': 0.30},
    'maintain': {'protein': 0.25, 'carbs': 0.48, 'fat': 0.27},
    'gain_lean': {'protein': 0.28, 'carbs': 0.50, 'fat': 0.22},
    'gain_fast': {'protein': 0.25, 'carbs': 0.52, 'fat': 0.23},
  };

  /// Calorie per grammo: le costanti di Atwater.
  static const _kcalPerGrammo = <String, double>{
    'protein': 4.0,
    'carbs': 4.0,
    'fat': 9.0,
  };

  /// 🚨 **Il pavimento a 1.200 kcal non è negoziabile.**
  ///
  /// Sotto quella soglia un piano alimentare non è più una dieta, e questo
  /// sistema **non è un dispositivo medico**. È la prima cosa che si perde
  /// riscrivendo «uguale ma in un'altra lingua», e la sola il cui smarrimento
  /// farebbe male a qualcuno.
  static const pavimentoKcal = 1200;

  // ───────────────────────── indici ─────────────────────────

  double bmi(double kg, double cm) {
    if (cm <= 0) throw ArgumentError('Altezza non valida.');

    final m = cm / 100;

    return _arrotonda(kg / (m * m), 1);
  }

  /// Metabolismo basale con **Mifflin-St Jeor**.
  ///
  /// Preferita a Harris-Benedict perché è più accurata sulla popolazione
  /// generale di oggi, che è mediamente più pesante di quella su cui la seconda
  /// era stata tarata nel 1919.
  ///
  /// ⚠️ **Un sesso sconosciuto usa la costante femminile**, che è la più
  /// prudente: un fabbisogno **sotto**stimato porta a un deficit più piccolo del
  /// previsto, uno **sopra**stimato porta a mangiare più del necessario credendo
  /// di essere a target. Fra i due errori si sceglie sempre il primo.
  double bmr({
    required String sesso,
    required double kg,
    required double cm,
    required int eta,
  }) {
    final base = (10 * kg) + (6.25 * cm) - (5 * eta);

    return _arrotonda(base + (sesso.toLowerCase() == 'male' ? 5 : -161), 1);
  }

  /// Il TDEE con il ripiego su `sedentary`.
  ///
  /// ⚠️ **Esiste solo perché è il ritratto fedele di
  /// `CalorieCalculator::tdee()`**, che sul server continua a servire ai
  /// **modelli** del pannello del trainer — e un modello non è una persona: se
  /// un valore d'esempio prende 1,2 invece di 1,55 non fa male a nessuno.
  ///
  /// ⛔ **L'app NON deve usarlo per una persona vera**: per quello c'è
  /// [tdeeSeNoto], che quando non sa dice che non sa. Vedi [fattoreDi].
  double tdee(double bmr, String attivitaScelta) {
    final fattore =
        attivita[attivitaScelta.toLowerCase()] ?? attivita['sedentary']!;

    return _arrotonda(bmr * fattore, 1);
  }

  /// Il TDEE di una persona vera, **`null` se il livello non è noto**.
  ///
  /// 🚨 È la porta stretta: un fabbisogno inventato non è un numero storto, è
  /// **una dieta storta**.
  double? tdeeSeNoto(double bmr, String? chiave) {
    final fattore = fattoreDi(chiave);

    if (fattore == null) return null;

    return _arrotonda(bmr * fattore, 1);
  }

  // ───────────────────────── obiettivo ─────────────────────────

  /// Il target calorico giornaliero.
  ///
  /// ⚠️ **Un obiettivo sconosciuto vale `maintain`, non un errore**: un piano
  /// salvato con un valore vecchio deve continuare a funzionare.
  int targetCalorico(double tdeeValore, String obiettivo) {
    final delta = deltaObiettivo[normalizzaObiettivo(obiettivo)] ?? 0.0;

    return math.max(pavimentoKcal, (tdeeValore * (1 + delta)).round());
  }

  /// I grammi di ciascun macro per un dato target.
  Macro macro(int kcal, String obiettivo) {
    final split =
        ripartizioneMacro[normalizzaObiettivo(obiettivo)] ??
        ripartizioneMacro['maintain']!;

    return Macro(
      proteineG: (kcal * split['protein']! / _kcalPerGrammo['protein']!)
          .round(),
      carboidratiG: (kcal * split['carbs']! / _kcalPerGrammo['carbs']!).round(),
      grassiG: (kcal * split['fat']! / _kcalPerGrammo['fat']!).round(),
    );
  }

  int kcalDaMacro(double proteineG, double carboidratiG, double grassiG) =>
      (proteineG * 4 + carboidratiG * 4 + grassiG * 9).round();

  /// L'età compiuta a partire dalla data di nascita.
  ///
  /// ⚠️ **Compiuta, non «anni trascorsi»**: chi compie gli anni domani ne ha
  /// ancora uno in meno oggi, e sul BMR un anno vale 5 kcal — poco, ma sbagliare
  /// per pigrizia un conto che si fa in tre righe non ha scuse.
  int etaDa(DateTime nascita, {DateTime? adesso}) {
    final oggi = adesso ?? DateTime.now();
    var anni = oggi.year - nascita.year;

    final compiuti =
        (oggi.month > nascita.month) ||
        (oggi.month == nascita.month && oggi.day >= nascita.day);

    if (!compiuti) anni--;

    return anni;
  }

  static double _arrotonda(double v, int decimali) {
    final f = <int, double>{0: 1, 1: 10, 2: 100}[decimali] ?? 10;

    return (v * f).roundToDouble() / f;
  }
}
