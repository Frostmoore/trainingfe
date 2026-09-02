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

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/archivio_salute.dart';
import '../../health/health_controller.dart';
import 'diary_models.dart' as modelli;
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
  /// ⚠️ **I grammi si derivano se non arrivano**, con la stessa regola del
  /// server: quantità × unità. ⛔ Senza, una voce scritta come «2 cucchiai»
  /// resterebbe senza peso, e il giorno che si corregge la quantità non ci
  /// sarebbe niente da riscalare.
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
  }) => _archivio.scriviVoceDiario(
    VociDiarioCompanion.insert(
      mangiatoIl: _soloIlGiorno(giorno),
      pasto: pasto,
      descrizione: descrizione,
      grammi: Value(grammi ?? inGrammi(quantita, unita)),
      quantita: Value(quantita),
      unita: Value(unita),
      kcal: Value(kcal),
      proteine: Value(proteine),
      carboidrati: Value(carboidrati),
      grassi: Value(grassi),
      kcal100: Value(kcal100),
      proteine100: Value(proteine100),
      carboidrati100: Value(carboidrati100),
      grassi100: Value(grassi100),
      fonte: Value(fonte),
      aiGrezzo: Value(aiGrezzo),
      pianoId: Value(pianoId),
      alimentoId: Value(alimentoId),
    ),
  );

  Future<void> cancella(int id) => _archivio.cancellaVoceDiario(id);
}

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
