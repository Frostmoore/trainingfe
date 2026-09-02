/// La conversione delle unità di misura in grammi — Parte I, I2.
///
/// ══ 🚨 TRASPORTATA, NON REINVENTATA ══════════════════════════════════════
///
/// 📌 Regola R2 della Parte I: *«la formula si **trasporta**, non si
/// reinventa»*.
///
/// Questo file è il ritratto fedele di `App\Services\Nutrition\FoodUnit`:
/// **stessi fattori, stessi sinonimi, stesso ordine, stessi arrotondamenti**.
/// ⛔ Un numero diverso qui non sarebbe un arrotondamento: sarebbe un difetto,
/// e produrrebbe un diario che mostra un totale e ne contiene un altro.
///
/// ══ ⚠️ IL COMMENTO DEL SERVER DICEVA IL CONTRARIO, ED ERA GIUSTO ═════════
///
/// `DiaryController::ricalcolaSeCambiaLaQuantita()` porta scritto: *«Il
/// ricalcolo lo fa il SERVER, non l'app … se l'app li riscrivesse in Dart
/// avremmo due conversioni da tenere allineate»*.
///
/// 🚨 **Aveva ragione finché le conversioni erano due.** Dopo la Parte I ne
/// resta **una**: il diario vive qui, e il server non ha più niente da
/// ricalcolare. ⛔ Il pericolo di allora non era «scrivere la formula in Dart»,
/// era **averla in due posti** — ed è esattamente ciò che I4 va a chiudere
/// togliendo l'altra.
///
/// ══ 💡 E NON È LA VERITÀ NUTRIZIONALE ═════════════════════════════════════
///
/// Un cucchiaio d'olio pesa 14 g, uno di miele 21, uno di farina 8: questa
/// tabella ne conosce **uno solo**, 15, ed è giusto così — serve a chi inserisce
/// a mano senza sapere il peso. 🚨 Quando c'è di mezzo l'AI i grammi li decide
/// il modello, che sa di che alimento si parla, e **la sua risposta vince**.
library;

/// Quanti grammi (o millilitri, trattati 1:1) vale un'unità.
///
/// ⚠️ Il rapporto 1:1 fra ml e g è un'approssimazione consapevole: vale per
/// l'acqua, sbaglia del 10% sull'olio. 💡 Distinguere volume e massa
/// richiederebbe la densità di ogni alimento — e in un diario alimentare
/// l'errore sta sotto il rumore dell'inserimento a occhio.
const fattoriDelleUnita = <String, double>{
  'g': 1,
  'mg': 0.001,
  'hg': 100,
  'kg': 1000,
  'ml': 1,
  'cl': 10,
  'dl': 100,
  'l': 1000,
  'bicchiere': 200,
  'cucchiaio': 15,
  'cucchiaino': 5,
  'tazza': 240,
  'scoop': 30,
};

/// L'ordine in cui compaiono in una tendina.
///
/// 💡 **Non alfabetico**: prima quelle che si usano davvero. Un elenco
/// alfabetico mette «bicchiere» prima di «g», e l'unità più usata finisce in
/// mezzo.
const ordineDelleUnita = <String>[
  'g', 'kg', 'ml', 'l', 'cucchiaio', 'cucchiaino', 'bicchiere', 'tazza',
  'scoop', 'hg', 'dl', 'cl', 'mg',
];

/// Sinonimi e abbreviazioni, come arrivano dall'inserimento libero e dall'AI.
const _sinonimi = <String, String>{
  'grammi': 'g',
  'grammo': 'g',
  'gr': 'g',
  'millilitri': 'ml',
  'litro': 'l',
  'litri': 'l',
  'chilogrammi': 'kg',
  'chili': 'kg',
  'etto': 'hg',
  'etti': 'hg',
  'cucchiai': 'cucchiaio',
  'cucchiaini': 'cucchiaino',
  'bicchieri': 'bicchiere',
  'tazze': 'tazza',
  'scoops': 'scoop',
  'misurino': 'scoop',
  'tbsp': 'cucchiaio',
  'tsp': 'cucchiaino',
  'cup': 'tazza',
};

/// L'unità normalizzata, o `null` se non la conosciamo.
///
/// 🚨 **`null` invece di indovinare, ed è voluto**: un'unità sconosciuta fatta
/// passare per grammi produce un numero plausibile e sbagliato, che nessuno
/// controllerà più.
String? unitaValida(String? unita) {
  if (unita == null) return null;

  var u = unita.toLowerCase().trim();

  while (u.endsWith('.')) {
    u = u.substring(0, u.length - 1);
  }

  u = _sinonimi[u] ?? u;

  return fattoriDelleUnita.containsKey(u) ? u : null;
}

/// Quantità × unità → grammi.
///
/// ⛔ `null` se manca uno dei due o se l'unità non si riconosce: chi chiama
/// decide cosa farne, ma **non riceve mai un numero inventato**.
double? inGrammi(double? quantita, String? unita) {
  if (quantita == null) return null;

  final u = unitaValida(unita);

  if (u == null) return null;

  return _arrotonda(quantita * fattoriDelleUnita[u]!);
}

/// Grammi → quantità nell'unità indicata. L'inverso di [inGrammi].
double? daGrammi(double? grammi, String? unita) {
  if (grammi == null) return null;

  final u = unitaValida(unita);

  if (u == null || fattoriDelleUnita[u] == 0) return null;

  return _arrotonda(grammi / fattoriDelleUnita[u]!);
}

/// ⚠️ **Due decimali, come `round(…, 2)` di PHP.** Non è pignoleria: i test che
/// difendono questa tabella confrontano numeri esatti con quelli del server, e
/// un arrotondamento diverso li farebbe divergere sull'ultima cifra — cioè
/// abbastanza da rompere i test e non abbastanza da spiegare perché.
double _arrotonda(double n) => (n * 100).roundToDouble() / 100;
