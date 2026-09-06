/// Quello che succede a una voce **prima** di finire in diario — Parte I, I2.5.
///
/// ══ 🚨 IL PEZZO CHE SI STAVA PER PERDERE ═════════════════════════════════
///
/// Sul server queste cinque cose stavano dentro `FoodEntry::booted()->saving()`,
/// cioè in un posto dove **nessuna schermata doveva ricordarsele**: valevano per
/// l'inserimento a mano, per la conferma di una stima, per i preferiti, per il
/// piano alimentare e per la modifica. 📌 Il commento di là lo diceva: *«sta nel
/// `saving()` e non in una regola di validazione, così vale per OGNI strada […]
/// una `Rule` andrebbe ripetuta in cinque controller e dimenticata nel sesto»*.
///
/// ⛔ Portando il diario sul telefono quel gancio sparisce, e senza di lui:
///
/// | Cosa smetteva di succedere | Cosa si sarebbe visto |
/// |---|---|
/// | I valori **per 100 g** non si derivano più | ⚠️ Correggere la quantità di una voce dell'AI **non ricalcola più niente**: era il difetto #9 del 12/08, richiuso |
/// | Le unità sconosciute restano tali | 🚨 «2 pezzi» non si converte mai in grammi, e non si riscala mai |
/// | La **massa impossibile** non si ferma | ⛔ Entrano in diario 100 g di prodotto con 120 g di macro, e i totali diventano falsi |
///
/// 💡 Sta in una funzione sola e la chiama [DiarioLocale], per la stessa ragione
/// per cui di là stava nel modello: perché **chi scrive non debba saperlo**.
library;

import '../../../core/errors/api_exception.dart';
import 'unita_di_misura.dart';

/// Una voce dopo le derivazioni: i valori come vanno scritti.
class VoceNormalizzata {
  const VoceNormalizzata({
    this.grammi,
    this.quantita,
    this.unita,
    this.kcal,
    this.proteine,
    this.carboidrati,
    this.grassi,
    this.kcal100,
    this.proteine100,
    this.carboidrati100,
    this.grassi100,
  });

  final double? grammi, quantita, kcal, proteine, carboidrati, grassi;
  final double? kcal100, proteine100, carboidrati100, grassi100;
  final String? unita;
}

/// Le cinque guardie, **nell'ordine in cui girava `saving()`**.
///
/// 🚨 L'ordine non è arbitrario, e il commento del server lo dichiarava: la
/// guardia sulla massa è l'**ultima** perché deve vedere i valori definitivi.
/// ⛔ Controllarla prima delle derivazioni vorrebbe dire bocciare voci sane, i
/// cui numeri erano solo ancora incompleti.
///
/// Throws [MassaImpossibileException] quando i macro superano il peso.
VoceNormalizzata normalizzaLaVoce({
  required String descrizione,
  double? grammi,
  double? quantita,
  String? unita,
  double? kcal,
  double? proteine,
  double? carboidrati,
  double? grassi,
  double? kcal100,
  double? proteine100,
  double? carboidrati100,
  double? grassi100,
}) {
  // ── 1. I grammi mancanti si derivano da quantità e unità ────────────────
  //
  // 💡 Meglio un valore derivato che una voce che non entra in nessun totale.
  grammi ??= inGrammi(quantita, unita);

  /*
   * ── 2. Un'unità che non sappiamo convertire diventa **grammi** ───────────
   *
   * 📌 Il difetto, riferito provando l'app il 12/08/2026: *«Ho scritto "Due
   * cotolette di pollo" e me le segna come 2 pezzi. Ma pezzi non è un'unità di
   * misura, e quando vado a modificarle a mano non mi ricalcola nulla»*.
   *
   * 💡 **Ma i grammi l'AI li ha già dati**, perché sa di che alimento si parla:
   * non si butta niente, si tiene il peso e si riscrive la quantità in grammi —
   * l'unica unità su cui il ricalcolo funziona sempre.
   *
   * ⚠️ **La descrizione resta intatta** («Due cotolette di pollo»), quindi
   * l'informazione «erano due» non si perde: cambia solo il modo di misurarle.
   */
  if (grammi != null && grammi > 0 && unitaValida(unita) == null) {
    unita = 'g';
    quantita = grammi;
  }

  /*
   * ── 2-bis. La quantità deve dire la STESSA cosa dei grammi ──────────────
   *
   * ══ 🚨 IL DIFETTO DEL «1 g» — riferito il 06/09/2026 ══════════════════
   *
   * 📌 Il committente: *«ci sono ancora alimenti che se li inserisco con l'ai mi
   * mette di default 1g»*, con la prova: due voci «Un cinnamon roll» a **1 g** e
   * **315 kcal**.
   *
   * ⛔ **Non era un grammo di default, e non era la guardia 2.** Riprodotto con
   * il modello vero, la risposta è:
   *
   *     qty 1.0 · unit 'g' · grams 100.0 · kcal 315
   *
   * 🚨 Cioè il modello ha **contato i pezzi** in `qty` e ha scritto `g`
   * nell'unità, mentre in `grams` ha messo il peso giusto. La coppia dice «un
   * grammo», il peso dice «cento grammi», e le calorie sono quelle dei cento.
   *
   * ⚠️ **La guardia 2 non poteva vederlo**: `g` è un'unità validissima, quindi
   * non scattava niente. E le calorie erano giuste, quindi nemmeno la guardia
   * sulla massa si accorgeva di niente. ⛔ Restava una voce **internamente
   * contraddittoria** che nessuno fermava: si vede «1 g» e si legge «315 kcal»,
   * e chi guarda pensa che l'app sia impazzita.
   *
   * 💡 **Fra i due si crede a `grams`**, e non è una scelta arbitraria: è il
   * campo che il prompt dichiara obbligatorio (*«`grams` non è mai vuoto: una
   * voce senza peso non entra in nessun totale»*), ed è quello su cui sono
   * calcolate le calorie. Riscrivere i grammi per farli tornare con «1» vorrebbe
   * dire buttare via la stima buona e tenere quella sbagliata.
   *
   * ══ ⛔ E VALE SOLO PER LE UNITA' DI MASSA ═══════════════════════════════
   *
   * 🚨 **Non per i millilitri e non per le unità domestiche**, e i test lo
   * dimostrano: 500 ml di succo pesano **525 g** (densità 1,05), e due cucchiai
   * d'olio ne pesano 28 mentre la tabella ne direbbe 30.
   *
   * ⚠️ Lì la differenza **non è un errore**: è la densità, o è
   * l'approssimazione della tabella. Riscrivere trasformerebbe «500 ml» in
   * «525 g» e «2 cucchiai» in «28 g» — numeri che nessuno ha pronunciato e più
   * difficili da rileggere.
   *
   * 💡 Su grammi e chilogrammi, invece, l'uguaglianza è **vera per
   * definizione**: se non torna, uno dei due campi sta mentendo. Ed è
   * esattamente lì che il modello sbaglia.
   */
  final unitaDiMassa = {'g', 'kg', 'mg', 'hg'}.contains(unitaValida(unita));

  if (grammi != null && grammi > 0 && unitaDiMassa) {
    final dettoDallaCoppia = inGrammi(quantita, unita);

    final scostamento =
        dettoDallaCoppia == null ? null : (dettoDallaCoppia - grammi).abs();

    // ⚠️ Una tolleranza c'è comunque: gli arrotondamenti a due decimali di
    // `inGrammi` non devono far riscrivere una voce che è già giusta.
    final tollerato = grammi * 0.02 < 1 ? 1.0 : grammi * 0.02;

    if (dettoDallaCoppia == null || scostamento! > tollerato) {
      /*
       * 💡 Si riscrive **nell'unità che c'era**, non si forza «g»: se qualcuno
       * ha scritto 500 ml e i grammi sono 525 (densità 1,05), la quantità giusta
       * resta 500 ml — non 525 g, che nessuno ha detto e che sarebbe più
       * difficile da rileggere.
       */
      quantita = daGrammi(grammi, unita) ?? grammi;

      if (daGrammi(grammi, unita) == null) unita = 'g';
    }
  }

  /*
   * ── 3. Dagli assoluti si ricavano i valori per 100 g ────────────────────
   *
   * 🚨 **È la riga per cui la modifica a mano ricalcola qualcosa.**
   * [DiarioLocale.aggiorna] esce subito quando `kcal100` è nullo, e **lo schema
   * dell'AI non ha nessun campo per 100 g**: chiede `grams`, `kcal`, `protein`,
   * `carbs`, `fat` e basta. ⛔ Senza questa derivazione ogni voce dell'AI
   * nascerebbe senza riferimento, e cambiarne la quantità lascerebbe i macro
   * fermi ai valori di prima.
   *
   * 💡 Il conto è esatto e non inventa niente: se 300 g valgono 480 kcal, 100 g
   * ne valgono 160. È l'informazione che c'era già, in una forma riscalabile.
   *
   * ⚠️ **Non sovrascrive quello che arriva**: chi manda già i valori per 100 g —
   * l'inserimento da un'etichetta — li ha più precisi di qualunque divisione.
   */
  if (grammi != null && grammi > 0) {
    final fattore = 100 / grammi;

    if (kcal100 == null && kcal != null) kcal100 = _due(kcal * fattore);
    if (proteine100 == null && proteine != null) {
      proteine100 = _due(proteine * fattore);
    }
    if (carboidrati100 == null && carboidrati != null) {
      carboidrati100 = _due(carboidrati * fattore);
    }
    if (grassi100 == null && grassi != null) grassi100 = _due(grassi * fattore);
  }

  /*
   * ── 4. E il verso opposto ───────────────────────────────────────────────
   *
   * 💡 Se conosciamo i valori per 100 g ma non gli assoluti, si calcolano:
   * l'inserimento da un'etichetta risponde spesso solo con i primi.
   */
  if (grammi != null && kcal == null && kcal100 != null) {
    final fattore = grammi / 100;

    kcal = _due(kcal100 * fattore);
    proteine ??= proteine100 == null ? null : _due(proteine100 * fattore);
    carboidrati ??=
        carboidrati100 == null ? null : _due(carboidrati100 * fattore);
    grassi ??= grassi100 == null ? null : _due(grassi100 * fattore);
  }

  // ── 5. Per ultima: i macro non possono pesare più dell'alimento ─────────
  _rifiutaMassaImpossibile(
    descrizione: descrizione,
    grammi: grammi,
    proteine: proteine,
    carboidrati: carboidrati,
    grassi: grassi,
  );

  return VoceNormalizzata(
    grammi: grammi,
    quantita: quantita,
    unita: unita,
    kcal: kcal,
    proteine: proteine,
    carboidrati: carboidrati,
    grassi: grassi,
    kcal100: kcal100,
    proteine100: proteine100,
    carboidrati100: carboidrati100,
    grassi100: grassi100,
  );
}

/// 🚨 **La stessa regola di `VoceStimata.macroImpossibili`**, e devono restare
/// uguali: quella avvisa nel foglio di conferma, questa blocca la scrittura.
/// ⛔ Se le due divergono, il foglio lascia salvare qualcosa che poi non entra —
/// oppure, peggio, avvisa su qualcosa che entra benissimo.
///
/// 💡 Sul server erano due copie della stessa regola per lo stesso motivo, e il
/// commento di là lo diceva: *«se le due divergono, l'app lascia salvare
/// qualcosa che il server rifiuta»*.
void _rifiutaMassaImpossibile({
  required String descrizione,
  required double? grammi,
  required double? proteine,
  required double? carboidrati,
  required double? grassi,
}) {
  if (grammi == null || grammi <= 0) return;

  final p = proteine ?? 0;
  final c = carboidrati ?? 0;
  final f = grassi ?? 0;
  final somma = p + c + f;

  // 1. Oltre la massa dell'alimento: impossibile, punto.
  final oltreLaMassa = somma > grammi * 1.02;

  /*
   * 2. Al limite, ma con più di un macronutriente.
   *
   * 🚨 **La prima prova da sola non prendeva le coppiette**: 56 + 4 + 40 fa
   * esattamente 100 su 100 g, cioè al limite e non oltre.
   *
   * 💡 Un alimento con più di un macronutriente contiene **sempre acqua**, e non
   * arriva mai al 100%. Al 100% ci arrivano solo i grassi puri e gli zuccheri
   * puri, che di macronutrienti ne hanno **uno solo**: 100 g d'olio sono 100 g
   * di grassi, e vanno salvati.
   *
   * ⚠️ È l'unico pezzo **euristico** di una regola altrimenti fisica: al 97% non
   * è impossibile in senso stretto, è solo inverosimile. Se un alimento vero
   * dovesse mai inciamparci, la soglia va allargata **qui e in
   * `VoceStimata.macroImpossibili` insieme**.
   */
  final quantiMacro = [p, c, f].where((m) => m > 0.5).length;
  final senzaAcqua = quantiMacro > 1 && somma > grammi * 0.97;

  if (!oltreLaMassa && !senzaAcqua) return;

  throw MassaImpossibileException(
    alimento: descrizione,
    grammi: grammi,
    macroTotali: somma,
  );
}

/// ⚠️ **Due decimali, come `round(…, 2)` di PHP.**
double _due(double n) => (n * 100).roundToDouble() / 100;
