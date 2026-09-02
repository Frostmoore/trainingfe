/// Il diario, letto e scritto **sul telefono** — Parte I, I2.
///
/// ══ 📌 COSA FA ════════════════════════════════════════════════════════════
///
/// Quello che faceva `GET /diary` sul server: raggruppa per pasto, somma i
/// totali, e li mette nella forma che la schermata già conosce ([DiaryDay]).
///
/// 🚨 **La forma non cambia**, ed è deliberato: la schermata del diario, i
/// widget e i test parlano di `DiaryDay` da mesi. Cambiare *dove* nascono i dati
/// e *come sono fatti* nello stesso giro vorrebbe dire non sapere quale delle
/// due cose ha rotto cosa.
///
/// ══ 🚨 I TOTALI SI SOMMANO QUI, E SONO GLI STESSI ════════════════════════
///
/// 📌 Regola R2 della Parte I: *«i test del server che coprivano quei calcoli
/// diventano test Dart, con gli stessi numeri. Se un numero cambia, è un
/// difetto — non un arrotondamento diverso»*.
///
/// 💡 `FoodEntry::totals()` sommava e arrotondava a due decimali: qui si fa lo
/// stesso, nello stesso ordine.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/storage/archivio_salute.dart';
import '../../health/health_controller.dart';
import 'diary_models.dart' as modelli;
import 'guardie_della_voce.dart';
import 'stima_ai.dart';
import 'unita_di_misura.dart';

/// I pasti, nell'ordine della giornata.
///
/// ⛔ **Le chiavi sono quelle del server** — `MealType` — e non si toccano: sono
/// nelle righe già scritte, nel piano alimentare e nel contesto del consiglio.
/// 💡 Le **etichette** invece sono nostre, e sono sempre state dell'app.
const pastiDelGiorno = <String, String>{
  'breakfast': 'Colazione',
  'morning_snack': 'Spuntino',
  'lunch': 'Pranzo',
  'afternoon_snack': 'Merenda',
  'dinner': 'Cena',
  'evening_snack': 'Dopo cena',
};

/// Legge e scrive il diario nell'archivio locale.
class DiarioLocale {
  const DiarioLocale(this._archivio);

  final ArchivioSalute _archivio;

  /// La giornata, nella forma che la schermata già conosce.
  ///
  /// ⚠️ **Tutti i pasti, anche vuoti**: la schermata disegna sei sezioni e ci
  /// mette dentro «aggiungi». ⛔ Saltare quelli vuoti farebbe sparire il posto
  /// in cui si scrive la colazione a chi non l'ha ancora scritta.
  Future<modelli.DiaryDay> giornata(DateTime giorno) async {
    final righe = await _archivio.vociDelGiorno(giorno);

    final perPasto = <String, List<VoceDiario>>{};

    for (final r in righe) {
      (perPasto[r.pasto] ??= []).add(r);
    }

    final pasti = [
      for (final voce in pastiDelGiorno.entries)
        modelli.DiaryMeal(
          meal: voce.key,
          label: voce.value,
          entries: [
            for (final r in perPasto[voce.key] ?? const []) _versoLaSchermata(r),
          ],
          kcal: _somma(perPasto[voce.key] ?? const [], (r) => r.kcal),
        ),
    ];

    return modelli.DiaryDay(
      date: giorno,
      meals: pasti,
      kcal: _somma(righe, (r) => r.kcal),
      protein: _somma(righe, (r) => r.proteine),
      carbs: _somma(righe, (r) => r.carboidrati),
      fat: _somma(righe, (r) => r.grassi),

      /*
       * ⛔ **Le bruciate non le sa questo oggetto**, e non è una mancanza: dopo
       * la FASE 11.6 vivono in `bruciateLocaliProvider`, che le mette insieme
       * dalle sedute, dall'orologio e dalla dichiarazione a mano. 💡 Chi
       * costruisce la schermata le prende da lì, come fa già oggi.
       */
      burnedKcal: 0,
    );
  }

  /// I totali di un giorno, senza costruire la giornata intera.
  ///
  /// 💡 Serve a «Oggi» e ai grafici, che dei singoli pasti non sanno che farsene.
  Future<({double kcal, double proteine, double carboidrati, double grassi})>
  totaliDel(DateTime giorno) async {
    final righe = await _archivio.vociDelGiorno(giorno);

    return (
      kcal: _somma(righe, (r) => r.kcal),
      proteine: _somma(righe, (r) => r.proteine),
      carboidrati: _somma(righe, (r) => r.carboidrati),
      grassi: _somma(righe, (r) => r.grassi),
    );
  }

  /// Quante voci ha un giorno.
  ///
  /// 💡 Era `entries_count` di `/dashboard`. ⚠️ Non è la stessa cosa delle
  /// calorie: un giorno con tre voci da zero kcal è **registrato**, e un giorno
  /// senza voci no — è la differenza fra «ho mangiato poco» e «non ho segnato».
  Future<int> quanteVociDel(DateTime giorno) async =>
      (await _archivio.vociDelGiorno(giorno)).length;

  /// I totali giorno per giorno, per i grafici — `2026-09-02` → kcal.
  ///
  /// 🚨 **Una lettura sola per tutto l'intervallo.** Un ciclo che chiama
  /// [totaliDel] una volta al giorno sarebbe trenta viaggi nel database per
  /// disegnare un mese.
  Future<Map<String, ({double kcal, double proteine, double carboidrati, double grassi})>>
  totaliFra(DateTime da, DateTime a) async {
    final righe = await _archivio.vociFra(da, a);

    final perGiorno = <String, List<VoceDiario>>{};

    for (final r in righe) {
      (perGiorno[etichettaDelGiorno(r.mangiatoIl)] ??= []).add(r);
    }

    return {
      for (final voce in perGiorno.entries)
        voce.key: (
          kcal: _somma(voce.value, (r) => r.kcal),
          proteine: _somma(voce.value, (r) => r.proteine),
          carboidrati: _somma(voce.value, (r) => r.carboidrati),
          grassi: _somma(voce.value, (r) => r.grassi),
        ),
    };
  }

  /// Da riga dell'archivio a voce della schermata.
  ///
  /// ⚠️ **L'id è quello LOCALE**, non `idSulServer`: è quello con cui la
  /// schermata cancella e corregge, e dopo I4 sarà l'unico che esiste. ⛔
  /// Passare l'id del server vorrebbe dire che le voci nate qui — che non ce
  /// l'hanno — non si possono toccare.
  modelli.FoodEntry _versoLaSchermata(VoceDiario r) => modelli.FoodEntry(
    id: r.id,
    description: r.descrizione,
    meal: r.pasto,
    grams: r.grammi,
    qty: r.quantita,
    unit: r.unita,
    kcal: r.kcal,
    protein: r.proteine,
    carbs: r.carboidrati,
    fat: r.grassi,
    kcal100: r.kcal100,
    protein100: r.proteine100,
    carbs100: r.carboidrati100,
    fat100: r.grassi100,
    source: r.fonte,
  );

  // ───────────────────────── le scritture ─────────────────────────

  /// Scrive una voce nuova.
  ///
  /// 🚨 **Passa da [normalizzaLaVoce], e non è facoltativo.** Lì dentro ci sono
  /// le cinque cose che sul server faceva `FoodEntry::booted()->saving()` per
  /// ogni strada di scrittura: i grammi derivati da quantità × unità, l'unità
  /// sconosciuta convertita in grammi, i valori per 100 g ricavati dagli
  /// assoluti (e viceversa), e il rifiuto di una massa impossibile.
  ///
  /// ⛔ Senza, una voce scritta come «2 cucchiai» resterebbe senza peso, una
  /// stima dell'AI nascerebbe senza riferimento per 100 g — e correggerne la
  /// quantità non ricalcolerebbe più niente.
  ///
  /// Throws [MassaImpossibileException] quando i macro superano il peso.
  Future<int> aggiungi({
    required DateTime giorno,
    required String pasto,
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
    String fonte = 'manual',
    String? aiGrezzo,
    int? pianoId,
    int? alimentoId,
  }) {
    final v = normalizzaLaVoce(
      descrizione: descrizione,
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

    return _archivio.scriviVoceDiario(
      VociDiarioCompanion.insert(
        mangiatoIl: _soloIlGiorno(giorno),
        pasto: pasto,
        descrizione: descrizione,
        grammi: Value(v.grammi),
        quantita: Value(v.quantita),
        unita: Value(v.unita),
        kcal: Value(v.kcal),
        proteine: Value(v.proteine),
        carboidrati: Value(v.carboidrati),
        grassi: Value(v.grassi),
        kcal100: Value(v.kcal100),
        proteine100: Value(v.proteine100),
        carboidrati100: Value(v.carboidrati100),
        grassi100: Value(v.grassi100),
        fonte: Value(fonte),
        aiGrezzo: Value(aiGrezzo),
        pianoId: Value(pianoId),
        alimentoId: Value(alimentoId),
      ),
    );
  }

  /// Scrive in diario una stima **già passata dal setaccio** — I2.5.
  ///
  /// ══ 🚨 UN PASTO E' UNA COSA SOLA ══════════════════════════════════════════
  ///
  /// ⛔ Cinque scritture separate possono fallire alla terza e lasciare in diario
  /// mezza cena: nei totali è un numero sbagliato **senza nessun segno che lo
  /// sia**. È la stessa ragione per cui `AiController::scriviVoci()` apriva una
  /// transazione.
  ///
  /// ══ 💡 E LE GUARDIE VALGONO ANCHE QUI ════════════════════════════════════
  ///
  /// ⚠️ Passa da [aggiungi], quindi da [normalizzaLaVoce]: i valori per 100 g si
  /// derivano, e sono **la ragione per cui una voce dell'AI si può riscalare**.
  /// 🚨 Lo schema del modello non ha nessun campo per 100 g: senza quella
  /// derivazione, correggere «300 g» in «450 g» lascerebbe le calorie ferme.
  ///
  /// 📌 Era il difetto #9 del 12/08, e sul server lo chiudeva `saving()` — che
  /// girava anche per la conferma, non solo per l'inserimento a mano.
  ///
  /// ⚠️ [fonte] è `ai_text` o `ai_photo`, e sopravvive alla conferma: 📌 *«quando
  /// un modello comincia a sbagliare le stime, bisogna poter ritrovare TUTTE le
  /// voci che ha prodotto»*. 🚨 Insieme a `aiGrezzo`, che è il campo che il 12/08
  /// ha spiegato una stima sbagliata mentre `confidence` diceva 0.85.
  Future<void> scriviLaStima(
    List<VoceStimata> voci, {
    required DateTime giorno,
    required String pasto,
    required String fonte,
  }) => _archivio.tuttoOniente(() async {
    for (final v in voci) {
      await aggiungi(
        giorno: giorno,
        pasto: pasto,
        descrizione: v.nome,
        grammi: v.grammi,
        quantita: v.qty,
        unita: v.unita,
        kcal: v.kcal,
        proteine: v.proteine,
        carboidrati: v.carboidrati,
        grassi: v.grassi,
        fonte: fonte,
        aiGrezzo: jsonEncode(v.toJson()),
      );
    }
  });

  /// Modifica una voce, e ricalcola ciò che va ricalcolato — I2.5.
  ///
  /// ══ 🚨 TRASPORTATA DA `DiaryController::ricalcolaSeCambiaLaQuantita()` ═══
  ///
  /// 📌 Regola R2 della Parte I: *«la formula si **trasporta**, non si
  /// reinventa»*. Le quattro parti, nell'ordine in cui il server le applica:
  ///
  /// 1. **si ricalcola solo se è stata toccata la quantità** ([quantita],
  ///    [unita] o [grammi]). ⛔ Correggere solo il nome non deve toccare
  ///    nessun numero;
  /// 2. ⛔ **i grammi espliciti vincono** su qualunque conversione — *«l'utente
  ///    ha pesato la porzione, e nessuna tabella sa più di una bilancia»*;
  /// 3. ⚠️ il fattore per unità si prende **dalla voce**, non dalla tabella
  ///    generica, finché l'unità non cambia: vedi [grammiPerLaQuantita];
  /// 4. 🚨 **i macro passati vincono sempre**: si riscalano dai valori per
  ///    100 g **solo** quelli assenti, e se i per-100 non ci sono **non si
  ///    inventa niente** e restano com'erano. Meglio un numero vecchio e
  ///    visibile che uno nuovo e sbagliato.
  ///
  /// ══ ⚠️ `null` VUOL DIRE «NON TOCCATO», NON «AZZERA» ═══════════════════════
  ///
  /// È la stessa convenzione che l'app usava con `PATCH /food-entries`, dove
  /// `'kcal': ?kcal` ometteva il campo quando era nullo. 🚨 Chi passasse un
  /// `null` per **cancellare** un valore non otterrebbe niente — e non è una
  /// dimenticanza: `edit_entry_sheet` manda solo ciò che è stato toccato, e un
  /// `null` che azzera renderebbe impossibile il ricalcolo automatico (che è
  /// esattamente il difetto che la nota sul server metteva in guardia).
  ///
  /// 💡 [grammi] fa eccezione **in uscita**: quando la quantità cambia, i
  /// grammi si riscrivono comunque — anche a `null`, se l'unità nuova non si sa
  /// convertire. ⛔ Lasciarli fermi vorrebbe dire una voce da «2 cucchiai» che
  /// pesa ancora quanto ne pesava uno.
  Future<void> aggiorna(
    int id, {
    String? descrizione,
    String? pasto,
    double? quantita,
    String? unita,
    double? grammi,
    double? kcal,
    double? proteine,
    double? carboidrati,
    double? grassi,
  }) async {
    final voce = await _archivio.voceDelDiario(id);

    if (voce == null) throw const DatoSparitoException();

    // ── 1. Si ricalcola solo se è stata toccata la quantità ──────────────
    final toccaLaQuantita = quantita != null || unita != null || grammi != null;

    // ── 2. e 3. I grammi ─────────────────────────────────────────────────
    final grammiNuovi = !toccaLaQuantita
        ? null
        : grammi ??
              grammiPerLaQuantita(
                quantita: quantita ?? voce.quantita,
                unita: unita ?? voce.unita,
                grammiPrima: voce.grammi,
                quantitaPrima: voce.quantita,
                unitaPrima: voce.unita,
              );

    // ── 4. I macro ───────────────────────────────────────────────────────
    var kcalNuove = kcal;
    var proteineNuove = proteine;
    var carboidratiNuovi = carboidrati;
    var grassiNuovi = grassi;

    final grammiFinali = grammiNuovi ?? voce.grammi;

    /*
     * 🚨 **`kcal100` fa da cancello a tutto il blocco**, ed è così anche sul
     * server: `if ($grammi === null || $voce->kcal_100 === null) return`.
     *
     * ⛔ Non è una svista da "correggere" riscalando le proteine quando ci sono
     * ma le calorie no: una voce senza kcal per 100 g è una voce scritta a mano
     * senza riferimento, e riscalarne **metà** dei macro darebbe una riga in cui
     * i numeri non tornano fra loro — che è peggio di una in cui sono vecchi.
     */
    if (toccaLaQuantita && grammiFinali != null && voce.kcal100 != null) {
      final fattore = grammiFinali / 100;

      kcalNuove ??= _due(voce.kcal100! * fattore);
      proteineNuove ??= _riscala(voce.proteine100, fattore);
      carboidratiNuovi ??= _riscala(voce.carboidrati100, fattore);
      grassiNuovi ??= _riscala(voce.grassi100, fattore);
    }

    /*
     * ── 5. E poi le guardie, sui valori FUSI ────────────────────────────────
     *
     * 🚨 Sul server questo era `$voce->fill($dati)->save()`: `saving()` girava
     * sull'entità **intera**, non sui soli campi cambiati. ⛔ Farlo qui solo su
     * quelli toccati vorrebbe dire che una voce che cambia unità non si
     * normalizza, e che i valori per 100 g mancanti restano mancanti per sempre.
     *
     * 💡 Per questo si passa tutto: quello che non è stato toccato entra com'era
     * e riesce com'era.
     */
    final v = normalizzaLaVoce(
      descrizione: descrizione ?? voce.descrizione,
      grammi: toccaLaQuantita ? grammiNuovi : voce.grammi,
      quantita: quantita ?? voce.quantita,
      unita: unita ?? voce.unita,
      kcal: kcalNuove ?? voce.kcal,
      proteine: proteineNuove ?? voce.proteine,
      carboidrati: carboidratiNuovi ?? voce.carboidrati,
      grassi: grassiNuovi ?? voce.grassi,
      kcal100: voce.kcal100,
      proteine100: voce.proteine100,
      carboidrati100: voce.carboidrati100,
      grassi100: voce.grassi100,
    );

    await _archivio.aggiornaVoceDiario(
      id,
      VociDiarioCompanion(
        descrizione: descrizione == null
            ? const Value.absent()
            : Value(descrizione),
        pasto: pasto == null ? const Value.absent() : Value(pasto),
        quantita: Value(v.quantita),
        unita: Value(v.unita),
        grammi: Value(v.grammi),
        kcal: Value(v.kcal),
        proteine: Value(v.proteine),
        carboidrati: Value(v.carboidrati),
        grassi: Value(v.grassi),
        kcal100: Value(v.kcal100),
        proteine100: Value(v.proteine100),
        carboidrati100: Value(v.carboidrati100),
        grassi100: Value(v.grassi100),
      ),
    );
  }

  Future<void> cancella(int id) => _archivio.cancellaVoceDiario(id);

  // ───────────────────────── i preferiti ─────────────────────────

  /// I preferiti, **i più usati per primi** — l'ordine di `scopeMostUsed()`.
  Future<List<modelli.FoodFavorite>> preferiti() async {
    final righe = await _archivio.preferitiDelDiario();

    return righe.map(_versoLElenco).toList();
  }

  /// Salva una voce di diario fra i preferiti — era `POST /food-entries/{}/favorite`.
  ///
  /// 💡 Si parte da una voce esistente invece di far compilare un modulo: chi ha
  /// appena registrato qualcosa di buono vuole salvarlo con un tocco.
  Future<int> salvaVoceComePreferito(int voceId) async {
    final voce = await _archivio.voceDelDiario(voceId);

    if (voce == null) throw const DatoSparitoException();

    return _archivio.scriviPreferito(
      PreferitiCiboCompanion.insert(
        descrizione: voce.descrizione,
        ePasto: const Value(false),
        grammi: Value(voce.grammi),
        quantita: Value(voce.quantita),
        unita: Value(voce.unita),
        kcal: Value(voce.kcal),
        proteine: Value(voce.proteine),
        carboidrati: Value(voce.carboidrati),
        grassi: Value(voce.grassi),
        kcal100: Value(voce.kcal100),
        proteine100: Value(voce.proteine100),
        carboidrati100: Value(voce.carboidrati100),
        grassi100: Value(voce.grassi100),
      ),
    );
  }

  /// Salva **un pasto intero** di un giorno fra i preferiti.
  ///
  /// 🚨 È la funzione che decide se il diario viene usato per più di una
  /// settimana: ricomporre a mano la stessa colazione ogni mattina è esattamente
  /// il punto in cui le persone smettono di registrare.
  Future<int> salvaPasto({
    required DateTime giorno,
    required String pasto,
    required String descrizione,
  }) async {
    final righe = (await _archivio.vociDelGiorno(giorno))
        .where((r) => r.pasto == pasto)
        .toList();

    if (righe.isEmpty) throw const PastoVuotoException();

    return _archivio.scriviPreferito(
      PreferitiCiboCompanion.insert(
        descrizione: descrizione,
        ePasto: const Value(true),
        voci: Value(jsonEncode([for (final r in righe) _versoIlPreferito(r)])),
        kcal: Value(_somma(righe, (r) => r.kcal)),
        proteine: Value(_somma(righe, (r) => r.proteine)),
        carboidrati: Value(_somma(righe, (r) => r.carboidrati)),
        grassi: Value(_somma(righe, (r) => r.grassi)),
      ),
    );
  }

  /// Rimette un preferito nel diario — era `POST /food-favorites/{}/add`.
  ///
  /// ⚠️ [giorno] è **il giorno che si sta guardando**, non adesso: chi completa
  /// ieri sera vuole che il cibo finisca su ieri. 💡 È lo stesso motivo per cui
  /// l'app storica ha dovuto correggerlo (v1.26.2).
  ///
  /// 🚨 **Un pasto intero è una cosa sola**: le sue voci si scrivono in
  /// transazione. ⛔ Un'interruzione a metà lascerebbe mezza colazione in
  /// diario — un totale sbagliato senza nessun segno che lo sia.
  Future<void> usaPreferito(
    int id, {
    required DateTime giorno,
    String? pasto,
  }) async {
    final preferito = await _archivio.preferitoDelDiario(id);

    if (preferito == null) throw const DatoSparitoException();

    final adesso = DateTime.now();
    final quale = pasto ?? pastoDallOra(adesso);

    final righe = preferito.ePasto
        ? _vociDelPreferito(preferito.voci)
        : [_versoIlPreferito(null, preferito)];

    await _archivio.tuttoOniente(() async {
      for (final r in righe) {
        await aggiungi(
          giorno: giorno,
          pasto: quale,
          descrizione: r['description']?.toString() ?? 'Alimento',
          grammi: _numero(r['grams']),
          quantita: _numero(r['qty']),
          unita: r['unit']?.toString(),
          kcal: _numero(r['kcal']),
          proteine: _numero(r['protein']),
          carboidrati: _numero(r['carbs']),
          grassi: _numero(r['fat']),
          kcal100: _numero(r['kcal_100']),
          proteine100: _numero(r['protein_100']),
          carboidrati100: _numero(r['carbs_100']),
          grassi100: _numero(r['fat_100']),
          fonte: 'favorite',
        );
      }

      /*
       * 🚨 **Il contatore si tocca qui dentro**, non dopo: se le voci non sono
       * entrate, il preferito non è stato usato. ⛔ Un contatore che cresce su
       * una scrittura annullata sposterebbe in cima all'elenco un preferito che
       * nessuno ha mai messo in tavola.
       */
      await _archivio.segnaPreferitoUsato(id, adesso);
    });
  }

  Future<void> togliPreferito(int id) => _archivio.cancellaPreferito(id);

  // ───────────────────────── conversioni interne ─────────────────────────

  modelli.FoodFavorite _versoLElenco(PreferitoCibo p) => modelli.FoodFavorite(
    id: p.id,
    description: p.descrizione,
    isMeal: p.ePasto,
    itemsCount: p.ePasto ? _vociDelPreferito(p.voci).length : 1,
    timesUsed: p.volteUsato,
    kcal: p.kcal,
    protein: p.proteine,
    carbs: p.carboidrati,
    fat: p.grassi,
    grams: p.grammi,
    qty: p.quantita,
    unit: p.unita,
  );

  /// Una riga come la scrive `items` di `food_favorites`.
  ///
  /// ══ 🚨 LE CHIAVI SONO QUELLE DEL SERVER, E NON SI TRADUCONO ══════════════
  ///
  /// ⛔ `description`, `grams`, `kcal_100`… sono i nomi che
  /// `FoodFavoriteController::storeMeal()` ha scritto dentro il JSON dei
  /// preferiti **già traslocati su questo telefono**. 🚨 Tradurli in italiano
  /// qui vorrebbe dire che i preferiti-pasto arrivati dal server tornano vuoti:
  /// nessun errore, un pasto che aggiunge zero voci, e la scoperta solo
  /// riguardando il diario dopo.
  ///
  /// 💡 Si passa `voce` **oppure** `preferito`: un preferito semplice è una riga
  /// sola, ed è la stessa forma che `FoodFavorite::addToDiary()` costruiva.
  Map<String, Object?> _versoIlPreferito(
    VoceDiario? voce, [
    PreferitoCibo? preferito,
  ]) => {
    'description': voce?.descrizione ?? preferito?.descrizione,
    'grams': voce?.grammi ?? preferito?.grammi,
    'qty': voce?.quantita ?? preferito?.quantita,
    'unit': voce?.unita ?? preferito?.unita,
    'kcal': voce?.kcal ?? preferito?.kcal,
    'protein': voce?.proteine ?? preferito?.proteine,
    'carbs': voce?.carboidrati ?? preferito?.carboidrati,
    'fat': voce?.grassi ?? preferito?.grassi,
    'kcal_100': voce?.kcal100 ?? preferito?.kcal100,
    'protein_100': voce?.proteine100 ?? preferito?.proteine100,
    'carbs_100': voce?.carboidrati100 ?? preferito?.carboidrati100,
    'fat_100': voce?.grassi100 ?? preferito?.grassi100,
  };

  /// ⚠️ **Un JSON illeggibile vale «nessuna voce», non un guasto.** Il testo
  /// arriva da una colonna che ha attraversato il trasloco e un backup: se un
  /// giorno è rotto, l'elenco dei preferiti deve continuare a disegnarsi.
  List<Map<String, Object?>> _vociDelPreferito(String? json) {
    if (json == null || json.isEmpty) return const [];

    try {
      final letto = jsonDecode(json);

      if (letto is! List) return const [];

      return [
        for (final v in letto)
          if (v is Map) v.cast<String, Object?>(),
      ];
    } on FormatException {
      return const [];
    }
  }
}

/// I grammi che spettano a una voce quando cambia la quantità — I2.5.
///
/// ══ 🚨 UNA REGOLA SOLA, USATA DA DUE POSTI ═══════════════════════════════
///
/// La usano [DiarioLocale.aggiorna] — che **salva** — e `edit_entry_sheet`, che
/// mostra l'anteprima mentre si digita. ⛔ Scritte due volte, il foglio
/// mostrerebbe un numero e il salvataggio ne scriverebbe un altro: è
/// letteralmente il difetto contro cui il commento del server metteva in
/// guardia, spostato dentro l'app.
///
/// ══ ⚠️ IL FATTORE VIENE DALLA VOCE, FINCHE' L'UNITA' NON CAMBIA ═══════════
///
/// 🚨 Se l'AI ha detto che un cucchiaio di **quell'olio** pesa 14 g,
/// raddoppiando la quantità devono venire **28 g**, non i 30 della conversione
/// generica. 💡 La tabella di [inGrammi] non è la verità nutrizionale: serve a
/// chi inserisce a mano senza sapere il peso, e cede il passo a chi il peso lo
/// sa.
///
/// ⛔ `null` quando non si sa convertire — e chi chiama lo scrive, invece di
/// tenersi il peso vecchio: una voce da «2 cucchiai» che pesa quanto ne pesava
/// uno è un numero sbagliato che sembra giusto.
double? grammiPerLaQuantita({
  required double? quantita,
  required String? unita,
  required double? grammiPrima,
  required double? quantitaPrima,
  required String? unitaPrima,
}) {
  final perUnita = (grammiPrima != null && quantitaPrima != null && quantitaPrima > 0)
      ? grammiPrima / quantitaPrima
      : null;

  if (unita == unitaPrima && perUnita != null && quantita != null) {
    return _due(quantita * perUnita);
  }

  return inGrammi(quantita, unita);
}

/// Il pasto plausibile a quest'ora.
///
/// 🚨 **Sono le soglie di serie di `MealType::fromProfile()`**, non gli orari
/// dichiarati nel profilo. ⚠️ Il server, quando l'app non mandava il pasto,
/// usava *quelli della persona* — «chi cena alle 18 vuole che un cibo delle 19
/// finisca nella cena». 💡 Qui non li abbiamo ancora: è un debito noto, aperto
/// da I2.5 e piccolo, perché **ogni schermata dell'app manda il pasto** — questa
/// deduzione è l'ultimo ripiego, non la strada normale.
String pastoDallOra(DateTime quando) => switch (quando.hour) {
  < 10 => 'breakfast',
  < 12 => 'morning_snack',
  < 15 => 'lunch',
  < 18 => 'afternoon_snack',
  < 22 => 'dinner',
  _ => 'evening_snack',
};

double? _numero(Object? v) => v == null ? null : (v as num).toDouble();

double? _riscala(double? per100, double fattore) =>
    per100 == null ? null : _due(per100 * fattore);

/// ⚠️ **Due decimali, come `round(…, 2)` di PHP.**
double _due(double n) => (n * 100).roundToDouble() / 100;

/// `2026-09-02` — la chiave con cui i grafici mettono in fila i giorni.
String etichettaDelGiorno(DateTime g) =>
    '${g.year.toString().padLeft(4, '0')}-'
    '${g.month.toString().padLeft(2, '0')}-'
    '${g.day.toString().padLeft(2, '0')}';

/// ⚠️ **La mezzanotte, come ha sempre fatto l'app.** `eaten_at` è sempre stato
/// il giorno scelto, non l'ora vera: qui si continua così. 💡 L'ora in cui una
/// voce è stata *scritta* c'è, e si chiama `scrittaIl` — quello è un dato vero.
DateTime _soloIlGiorno(DateTime g) => DateTime(g.year, g.month, g.day);

/// ⚠️ **Due decimali, come `FoodEntry::totals()` sul server.** Un
/// arrotondamento diverso farebbe divergere i totali sull'ultima cifra:
/// abbastanza da far litigare i test, non abbastanza da spiegare perché.
double _somma(Iterable<VoceDiario> righe, double? Function(VoceDiario) quale) {
  var totale = 0.0;

  for (final r in righe) {
    totale += quale(r) ?? 0;
  }

  return (totale * 100).roundToDouble() / 100;
}

final diarioLocaleProvider = Provider<DiarioLocale>(
  (ref) => DiarioLocale(ref.watch(archivioSaluteProvider)),
);

/// Quante volte il diario è cambiato — I2.5.
///
/// ══ 🚨 PERCHE' SERVE, E PERCHE' PRIMA NO ═════════════════════════════════
///
/// Finché il diario stava sul server, chi scriveva faceva
/// `ref.invalidate(diaryProvider)` e **tutto il resto si riaggiornava da solo**:
/// dashboard, calendario e grafici rifacevano la loro chiamata HTTP e la
/// risposta conteneva già i numeri nuovi.
///
/// ⛔ Adesso quei numeri nascono da SQLite, e SQLite non avvisa nessuno. 🚨
/// Senza questo contatore, aggiungere un alimento aggiornerebbe **solo** la
/// schermata del diario: «Oggi» resterebbe sulle calorie di prima, il grafico
/// pure, e la persona vedrebbe due totali diversi nella stessa app. È
/// esattamente il difetto della FASE 1.10, dove la sincronizzazione scriveva
/// l'allenamento e non lo diceva a nessuno.
///
/// 💡 Sta qui e non nelle schermate perché il verso giusto è che **chi mostra
/// dipenda da chi scrive**: chi legge lo guarda, chi scrive lo incrementa.
final revisioneDiarioProvider = StateProvider<int>((ref) => 0);
