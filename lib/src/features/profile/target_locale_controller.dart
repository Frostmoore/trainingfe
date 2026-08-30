import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../forma/indici_di_forma.dart';
import '../health/health_controller.dart';
import 'corpo_controller.dart';
import 'data/calcolatore_calorie.dart';
import 'data/target_scelto.dart';
import 'livello_attivita.dart';
import 'profile_controller.dart';
import 'tdee_misurato_controller.dart';

/// Il fabbisogno calorico, **calcolato sul telefono** — S5.1 / correzione S7.
///
/// ── 🚨 Perché questo file è dovuto nascere ────────────────────────────────
///
/// In S5 il peso è uscito dal server, e `Profile::computedTargets()` ha smesso
/// di poter calcolare: senza peso non c'è BMR, senza BMR non c'è TDEE, senza
/// TDEE non c'è nessun obiettivo. Il commento nel backend diceva già la cosa
/// giusta — *«chi chiede i target di una persona vera li calcola nell'app»* —
/// ⚠️ **ma nell'app non li calcolava nessuno.**
///
/// Il risultato lo ha visto il committente provandola: profilo compilato, peso
/// registrato, e la schermata principale che continuava a dire *«Nessun
/// obiettivo impostato — compila i tuoi dati»*. Cioè l'app chiedeva dei dati
/// che erano già stati inseriti, e non li usava.
///
/// 💡 **Il calcolo c'era già**: `CalcolatoreCalorie` è il ritratto fedele di
/// `CalorieCalculator`, portato in Dart in S5.1 con i suoi tredici test.
/// Mancava solo qualcuno che gli passasse i due pezzi — il profilo dal server,
/// il peso dall'archivio locale.

/// Quello che l'app riesce a calcolare da sola.
class TargetLocale {
  const TargetLocale({
    required this.kcal,
    required this.macro,
    required this.bmr,
    required this.tdee,
    required this.kcalStimato,
    required this.macroStimato,
    this.aMano = false,
  });

  /// Quello **in uso**: la scelta della persona se c'è, altrimenti la stima.
  final int kcal;

  final Macro macro;
  final double bmr;
  final double tdee;

  /// 🚨 **La stima resta visibile accanto alla scelta** — N18.2.
  ///
  /// ⚠️ Nasconderla trasformerebbe una scelta informata in una a caso: chi
  /// scrive 1.500 deve poter vedere che la formula ne diceva 2.100, e decidere
  /// sapendolo. È anche l'unico modo di accorgersi di uno zero di troppo.
  final int kcalStimato;

  final Macro macroStimato;

  /// Se i valori in uso li ha scelti la persona.
  final bool aMano;
}

/// Il pezzo che manca per poter calcolare.
///
/// 🚨 **Esiste perché «non si può calcolare» e «non so cosa ti manca» sono due
/// cose diverse**, e la seconda è quella che fa arrabbiare.
///
/// Provando l'app il 12/08/2026 il committente ha riferito: *«Non mi calcola
/// più i valori che inserisco di peso, altezza eccetera»*. ⚠️ Il profilo era
/// compilato; a mancare era **solo la pesata**, che vive nell'archivio locale e
/// si registra da un'altra parte. La card diceva «Compila i tuoi dati» — cioè
/// mandava a rifare una cosa già fatta, per una che non era mai stata offerta.
enum PezzoMancante {
  peso('il tuo peso'),
  altezza('la tua altezza'),
  dataDiNascita('la tua data di nascita'),
  sesso('il sesso'),

  /// 🚨 **Nuovo con la 3b-G, e prima non poteva mancare niente.**
  ///
  /// ⛔ Un livello sconosciuto — o mai scelto — cadeva su `sedentary`, cioè
  /// **1,2**. Chi era su «estremamente attivo» (1,9) si vedeva un fabbisogno
  /// più basso di **1.300 kcal** senza nessun errore da nessuna parte, e chi
  /// non aveva mai risposto ne prendeva uno inventato di sana pianta.
  ///
  /// 💡 Adesso è un pezzo che manca come gli altri quattro, e si dice.
  attivita('come vuoi che l\'app conti le calorie');

  const PezzoMancante(this.etichetta);

  /// Come si nomina in una frase: *«Manca ancora `<etichetta>`»*.
  final String etichetta;

  /// 🚨 Il peso si registra da un'**altra schermata** rispetto agli altri tre:
  /// sta nell'archivio locale (S5), non nel profilo sul server. È la ragione
  /// per cui l'interfaccia deve mandare in due posti diversi.
  bool get staNelProfilo => this != PezzoMancante.peso;
}

/// L'esito del calcolo: il numero, **oppure il motivo per cui non c'è**.
class EsitoTarget {
  const EsitoTarget.calcolato(TargetLocale questo)
    : target = questo,
      mancano = const {};

  const EsitoTarget.incompleto(this.mancano) : target = null;

  final TargetLocale? target;

  /// Vuoto quando il calcolo è riuscito.
  final Set<PezzoMancante> mancano;

  bool get riuscito => target != null;

  /// La frase da mostrare, già montata: *«Manca ancora il tuo peso.»*
  ///
  /// 💡 Elencare **tutto** quello che manca invece del primo pezzo evita il
  /// giro dell'oca — compili una cosa, torni, e ne scopri un'altra.
  String get spiegazione {
    if (mancano.isEmpty) return '';

    final pezzi = mancano.map((p) => p.etichetta).toList();

    if (pezzi.length == 1) return 'Manca ancora ${pezzi.first}.';

    return 'Mancano ancora ${pezzi.sublist(0, pezzi.length - 1).join(', ')} '
        'e ${pezzi.last}.';
  }

  /// Se **l'unica** cosa che manca è la pesata: si manda dritti lì.
  bool get soloIlPeso =>
      mancano.length == 1 && mancano.first == PezzoMancante.peso;
}

/// Il fabbisogno, oppure l'elenco di ciò che serve per calcolarlo.
///
/// 🚨 Servono tutti e quattro: sesso, data di nascita, altezza e **peso**. Senza
/// uno solo, Mifflin-St Jeor non si applica — e un obiettivo calorico
/// inventato non è un numero storto, è **una dieta storta**. È la stessa regola
/// che il backend applicava restituendo `null`.
///
/// ⚠️ Il peso arriva dall'**archivio locale**, non dal server: dopo S5 il server
/// non ce l'ha, e chiederglielo restituirebbe sempre niente.
final targetLocaleProvider = FutureProvider.autoDispose<EsitoTarget>((
  ref,
) async {
  /*
   * 🚨 **TUTTE le `ref.watch` PRIMA del primo `await`.**
   *
   * ── Il difetto, riferito il 12/08/2026 ──────────────────────────────────
   *
   * *«Mi ha calcolato i target solo dopo che ho inserito una seconda pesata a
   * ieri.»*
   *
   * ⚠️ E la seconda pesata **non c'entrava niente**: nell'archivio la prima era
   * salvata correttamente, e `ultimoPeso()` l'avrebbe restituita da subito. A
   * non aggiornarsi era l'interfaccia — a farla ripartire è stato uscire e
   * rientrare dalla schermata, che con un provider `autoDispose` lo ricostruisce
   * da zero. Le due cose sono successe vicine e sembravano legate.
   *
   * La causa vera: `ref.watch(revisioneCorpoProvider)` stava **dopo due
   * `await`**. In Riverpod le dipendenze si registrano durante la costruzione
   * **sincrona**: dopo una pausa asincrona `ref.watch` si comporta come
   * `ref.read`, cioè legge il valore e **non si iscrive**. Il contatore si
   * incrementava a ogni pesata e questo provider non se ne accorgeva mai.
   *
   * 💡 Non dà nessun errore, nessun avviso e nessun log: si manifesta solo come
   * «l'app non si aggiorna finché non cambio schermata», che si scambia per
   * lentezza.
   */
  final revisione = ref.watch(revisioneCorpoProvider);
  final archivio = ref.watch(archivioSaluteProvider);
  final profiloFuturo = ref.watch(profileProvider.future);

  /*
   * 🚨 **Letto qui, prima dell'`await`, come tutti gli altri.** Vale la stessa
   * regola scritta sopra: dopo una pausa asincrona `ref.watch` non si iscrive
   * più, e questo provider non si accorgerebbe di una scelta appena fatta —
   * cioè la persona sceglie il modello e l'obiettivo non cambia finché non
   * esce e rientra dalla schermata.
   */
  final livelloScelto = ref.watch(livelloAttivitaSceltoProvider);

  /*
   * 📏 **La misura, se la persona ha deciso di usarla** — 3b-G.8.
   *
   * 🚨 Quando c'è, il livello di attività non serve più a niente: il dispendio
   * non si stima da una tabella, si è misurato. ⚠️ Ed è per questo che qui
   * sotto `PezzoMancante.attivita` non scatta se questo numero c'è — chi ha la
   * misura non deve dichiarare un mestiere per avere un obiettivo.
   */
  final tdeeMisurato = ref.watch(tdeeAccettatoProvider);

  // ⚠️ Letta apposta, o l'analizzatore la segnerebbe come inutilizzata e
  // qualcuno la toglierebbe insieme alla dipendenza.
  assert(revisione >= 0, 'la revisione del corpo non è mai negativa');

  final profilo = await profiloFuturo;
  final pesata = await archivio.ultimoPeso();

  /*
   * ══ ⚖️ LA COMPOSIZIONE, LETTA A PARTE — 3b-W ══════════════════════════════
   *
   * 📌 *«bisogna prendere solo i dati che vengono davvero passati e stimare
   * quelli che non vengono passati»*.
   *
   * 🚨 **Due letture separate e non «l'ultima misura».** Peso, massa grassa e
   * massa magra arrivano da record diversi e **possono essere di giorni
   * diversi**: chi si pesa ogni giorno e misura il grasso una volta a settimana
   * ha il peso di stamattina e il grasso di martedì. ⛔ Leggere tre campi dalla
   * stessa riga butterebbe via il valore più fresco.
   */
  final magraMisurata = (await archivio.ultimaMassaMagra())?.massaMagraKg;
  final grassoRecente = await archivio.massaGrassaRecente();

  final kg = pesata?.pesoKg;
  final cm = profilo.heightCm?.toDouble();
  final nascita = profilo.birthdate;
  final sesso = profilo.sex;

  /*
   * ══ ⚠️ IL LIVELLO IN USO, E L'EREDITA' — 3b-G.2 ═══════════════════════════
   *
   * La scelta locale vince; se non c'è, vale ancora quello che stava sul
   * server. ⛔ **Non si converte in automatico**: chi aveva scelto «moderato
   * (3-4 allenamenti)» ha dichiarato lo sport, e del suo lavoro non sappiamo
   * niente — mapparlo su un gradino del modello misurato vuol dire inventargli
   * un mestiere. 💡 Glielo si chiede, e finché non risponde non cambia niente.
   *
   * 🚨 Preso dal profilo **già atteso** e non da `livelloAttivitaProvider`:
   * quello legge l'`AsyncValue`, che al primo giro è ancora `loading` — e
   * l'obiettivo avrebbe lampeggiato «manca il livello» per un istante, su una
   * schermata che dice a qualcuno quanto può mangiare.
   */
  final livello = livelloScelto ?? profilo.activityLevel;
  final fattore = CalcolatoreCalorie.fattoreDi(livello);

  const calcolatore = CalcolatoreCalorie();

  /*
   * ══ 🚨 ALTEZZA, ETA' E SESSO SI CHIEDONO SEMPRE ══════════════════════════
   *
   * ⛔ **Il 30/08 li avevo resi facoltativi quando c'è la massa grassa**, con
   * il ragionamento che Katch-McArdle non li usa. 📌 Il committente:
   * *«Se katch-mcardle non li usa non significa che non servano. Se uno non ha
   * gli altri dati si devono usare quelli per forza»*. Aveva ragione.
   *
   * ── ⚠️ Il motivo, che è più forte del ragionamento sbagliato ────────────
   *
   * 🚨 **La massa grassa è un dato che può sparire.** Si revoca il permesso a
   * Health Connect, la bilancia si rompe o si cambia, una lettura d'impedenza
   * fallita scrive `0` — e per un mese ci si pesa su una bilancia normale.
   *
   * ⛔ Altezza, età e sesso **non spariscono mai**. Costruire l'insieme dei
   * dati obbligatori sopra quello volatile è esattamente al contrario: la base
   * si tiene, e la composizione è un **miglioramento sopra**, non un rimpiazzo.
   *
   * ── 💡 Il caso concreto ─────────────────────────────────────────────────
   *
   * Uno si configura con la bilancia smart e non dà mai la data di nascita.
   * Due mesi dopo revoca il permesso — o la bilancia muore. Da quel momento
   * **non ha più nessun target**, e l'app gli chiede la data di nascita dal
   * nulla, per un dato che non c'entra niente con quello che è cambiato.
   *
   * 🚨 È il difetto che questo progetto documenta da sempre, in una forma
   * nuova: un numero che sparisce senza che sia successo niente di
   * comprensibile.
   */
  final mancano = <PezzoMancante>{
    if (kg == null) PezzoMancante.peso,
    if (cm == null) PezzoMancante.altezza,
    if (nascita == null) PezzoMancante.dataDiNascita,
    if (sesso == null) PezzoMancante.sesso,
    if (fattore == null && tdeeMisurato == null) PezzoMancante.attivita,
  };

  if (mancano.isNotEmpty) return EsitoTarget.incompleto(mancano);

  /*
   * 🚨 **I valori vanno TRADOTTI, non passati così come sono.**
   *
   * Il profilo salva `m`, `lose_weight`, `very_active`; il calcolatore parla di
   * `male`, `lose`, `athlete`. Lato server la traduzione esiste da sempre in
   * `Profile::goalForFormula()` e compagni — ⚠️ **portando il calcolatore in
   * Dart erano stati portati i numeri e non lei**.
   *
   * Il risultato, trovato il 12/08/2026 rispondendo a *«secondo te il target è
   * adeguato per il dimagrimento?»*: `'lose_weight'` non è una chiave di
   * `deltaObiettivo`, quindi il deficit era **0%** — un target di
   * **mantenimento** a chi ha scritto «voglio dimagrire». E `'m'` non è
   * `'male'`, quindi il metabolismo basale usava la costante **femminile**:
   * 166 kcal in meno.
   *
   * 💡 Nessuno dei due dà errore. Producono un numero plausibile e sbagliato.
   */
  /*
   * 💡 **La composizione migliora il calcolo, non lo sostituisce.** Qui i
   * quattro dati di base ci sono per certo — `mancano` è vuoto — e la massa
   * grassa, se c'è, li rende più precisi. ⚠️ Il giorno che sparisce, il
   * fabbisogno **peggiora un po'** invece di svanire.
   */
  final bmr = bmrConLaComposizione(
    calcolatore: calcolatore,
    kg: kg!,
    cm: cm!,
    eta: calcolatore.etaDa(nascita!),
    sesso: profilo.sessoPerFormula,
    massaMagraMisurataKg: magraMisurata,
    grassoRecente: grassoRecente,
  );

  /*
   * ⛔ **`tdeeSeNoto` e non `tdee`**: il secondo ripiega su 1,2 quando la
   * chiave non la conosce, ed è il ripiego che la 3b-G esiste per togliere.
   * 💡 Qui non può tornare `null`: `fattore` è già stato controllato sopra, e
   * senza di lui non si arriva a questa riga.
   */
  /*
   * 💡 La misura batte la stima, quando c'è: è lo stesso ordine di precedenza
   * di `TargetScelto` sopra il calcolo, e per la stessa ragione — un dato che
   * riguarda **questa** persona vale più di una formula che riguarda tutti.
   */
  final tdee = tdeeMisurato ?? calcolatore.tdeeSeNoto(bmr, livello)!;
  final kcal = calcolatore.targetCalorico(tdee, profilo.obiettivoPerFormula);

  final macroStimato = calcolatore.macro(kcal, profilo.obiettivoPerFormula);

  /*
   * 🚨 **La scelta della persona vince sulla formula** — N18.1.
   *
   * ⚠️ E vince **sempre**, anche quando l'obiettivo automatico cambia: chi ha
   * messo un numero a mano non deve ritrovarselo sovrascritto perché ha
   * aggiornato il peso o ha cambiato «dimagrire» in «mantenere». Un valore che
   * si azzera da solo è peggio di un valore che non si può cambiare.
   */
  final scelto = await TargetScelto.leggi();

  return EsitoTarget.calcolato(
    TargetLocale(
      kcal: scelto?.kcal ?? kcal,
      macro: scelto?.macro ?? macroStimato,
      bmr: bmr,
      tdee: tdee,
      kcalStimato: kcal,
      macroStimato: macroStimato,
      aMano: scelto != null,
    ),
  );
});

/// Il solo metabolismo basale — 3b-G.1, 26/08/2026.
///
/// ══ 🚨 PERCHE' NON RIUSA `targetLocaleProvider` ═══════════════════════════
///
/// ⛔ Perché deve funzionare **proprio quando quello si rifiuta**: da 3b-G, chi
/// non ha ancora scelto il livello di attività non ha un fabbisogno, e
/// `targetLocaleProvider` risponde `incompleto`. 🚨 Ma è esattamente la persona
/// che sta aprendo la pagina della scelta, e a cui va mostrato **il suo numero**
/// dentro la formula: *«1.880 × 1,25 = 2.350»* convince, *«BMR × fattore»* no.
///
/// 💡 Il basale non dipende dall'attività — solo da sesso, età, altezza e peso —
/// quindi c'è anche quando il resto non c'è. ⚠️ L'assemblaggio dei quattro pezzi
/// è ripetuto di proposito: metterlo in comune vorrebbe dire che questo
/// provider eredita anche la condizione che lo blocca.
final metabolismoBasaleProvider = FutureProvider.autoDispose<double?>((
  ref,
) async {
  // 🚨 Tutte le `ref.watch` prima del primo `await`: vedi la nota lunga sopra.
  final revisione = ref.watch(revisioneCorpoProvider);
  final archivio = ref.watch(archivioSaluteProvider);
  final profiloFuturo = ref.watch(profileProvider.future);

  assert(revisione >= 0, 'la revisione del corpo non è mai negativa');

  final profilo = await profiloFuturo;
  final pesata = await archivio.ultimoPeso();

  /*
   * 🚨 **La stessa composizione del target, letta allo stesso modo** — 3b-W.
   *
   * ⛔ Senza queste due righe questo provider resterebbe su Mifflin mentre il
   * target passa a Katch-McArdle: due numeri diversi per la stessa persona, uno
   * nell'obiettivo e l'altro dentro la formula che lo spiega. ⚠️ È il difetto
   * dell'header di «Oggi» — una correzione applicata in un posto e non
   * nell'altro — in un posto dove fa più danno.
   */
  final magraMisurata = (await archivio.ultimaMassaMagra())?.massaMagraKg;
  final grassoRecente = await archivio.massaGrassaRecente();

  final kg = pesata?.pesoKg;
  final cm = profilo.heightCm?.toDouble();
  final nascita = profilo.birthdate;

  if (kg == null || cm == null || nascita == null || profilo.sex == null) {
    return null;
  }

  const calcolatore = CalcolatoreCalorie();

  return bmrConLaComposizione(
    calcolatore: calcolatore,
    kg: kg,
    cm: cm,
    eta: calcolatore.etaDa(nascita),
    sesso: profilo.sessoPerFormula,
    massaMagraMisurataKg: magraMisurata,
    grassoRecente: grassoRecente,
  );
});

/// Il metabolismo basale, con la formula giusta per i dati che ci sono — 3b-W.3.
///
/// ══ 🚨 UNA SOLA SEDE, E NON E' PIGNOLERIA ════════════════════════════════
///
/// Due provider calcolano il BMR — [targetLocaleProvider] e
/// [metabolismoBasaleProvider] — e sono separati di proposito: il secondo deve
/// funzionare proprio quando il primo si rifiuta.
///
/// ⛔ Ma la **formula** dev'essere una. Averla in due copie vuol dire due numeri
/// diversi per la stessa persona nella stessa app: uno dentro il target,
/// l'altro dentro la spiegazione della formula. ⚠️ È il difetto trovato il
/// 30/08 nell'header di «Oggi» — una correzione applicata in un posto e non
/// nell'altro — e nessun test se ne accorge, perché niente è rotto.
///
/// ══ 💡 L'ORDINE, E PERCHE' E' QUESTO ═════════════════════════════════════
///
/// | | Da dove viene la massa magra | Perché prima |
/// |---|---|---|
/// | 1 | **misurata** dalla bilancia | non eredita nessun errore |
/// | 2 | **derivata** da una percentuale **livellata** | eredita l'errore, ma smorzato |
/// | 3 | ⛔ nessuna → **Mifflin-St Jeor**, come sempre | |
///
/// ⚠️ **La percentuale si livella**, e non è un vezzo: una bioimpedenza da casa
/// oscilla di 3-5 punti con l'idratazione, e 3 punti sono ~60 kcal di BMR e ~80
/// di target. 🚨 Un obiettivo che cambia ogni mattina **insegna a non fidarsi
/// del numero**, ed è il danno peggiore che questa funzione possa fare.
///
/// ══ ⛔ E IL RIPIEGO NON E' UN NUMERO ═════════════════════════════════════
///
/// 🚨 «Non lo so» è `null`, **mai `0`**. Un `?? 0` messo per far compilare
/// darebbe a chi non ha la bilancia una massa magra pari al peso intero, e un
/// BMR alto, plausibile e sbagliato. ⚠️ È la metà che si rompe per prima.
double bmrConLaComposizione({
  required CalcolatoreCalorie calcolatore,
  required double kg,
  required double cm,
  required int eta,
  required String sesso,
  double? massaMagraMisurataKg,
  List<double> grassoRecente = const [],
}) {
  final massaMagra = massaMagraPerIlBmr(
    calcolatore: calcolatore,
    kg: kg,
    massaMagraMisurataKg: massaMagraMisurataKg,
    grassoRecente: grassoRecente,
  );

  if (massaMagra != null) {
    return calcolatore.bmrKatchMcArdle(massaMagraKg: massaMagra);
  }

  return calcolatore.bmr(kg: kg, cm: cm, eta: eta, sesso: sesso);
}

/// La massa magra da usare nel BMR, o `null` se non se ne può avere una.
///
/// ══ 💡 MISURATA, POI DERIVATA, POI NIENTE ════════════════════════════════
///
/// ⚠️ **`null` non blocca niente**: vuol dire soltanto che il BMR si fa con
/// Mifflin-St Jeor, che è quello che l'app ha sempre usato.
///
/// ⛔ **E non decide cosa chiedere.** Il 30/08 lo faceva, ed era sbagliato:
/// altezza, età e sesso si chiedono **sempre**, perché la massa grassa può
/// sparire (permesso revocato, bilancia cambiata, impedenza fallita) e quei tre
/// no. Il perché per esteso sta in `targetLocaleProvider`.
///
/// 💡 `kg` è `null`-abile perché una massa magra **misurata** vale anche senza
/// il peso: è il peso che serve a derivarla, non a leggerla.
double? massaMagraPerIlBmr({
  required CalcolatoreCalorie calcolatore,
  required double? kg,
  double? massaMagraMisurataKg,
  List<double> grassoRecente = const [],
}) {
  if (massaMagraMisurataKg != null) return massaMagraMisurataKg;

  if (kg == null || grassoRecente.isEmpty) return null;

  return calcolatore.massaMagraDa(
    kg: kg,
    grassoPct: IndiciDiForma.ewma(grassoRecente, finestraDelGrasso),
  );
}

/// Su quanti giorni si livella la percentuale di grasso — 3b-W.3.4.
///
/// 💡 **Sette**: è la finestra in cui l'idratazione si media da sola, ed è la
/// stessa che lo storico usa per lo scostamento del peso. ⚠️ Più corta lascia
/// passare il rumore, più lunga fa arrivare in ritardo un dimagrimento vero.
const finestraDelGrasso = 7;
