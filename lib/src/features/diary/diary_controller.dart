/// Il diario alimentare, **letto e scritto sul telefono** — Parte I, I2.5.
///
/// ══ 🚨 COSA E' CAMBIATO IL 03/09/2026, E COSA NO ═════════════════════════
///
/// ⛔ **Le rotte del diario non si chiamano più.** `GET /diary`,
/// `POST/PATCH/DELETE /food-entries`, tutta la famiglia `/food-favorites`: erano
/// nove chiamate, e adesso sono nove letture di SQLite. 📌 Regola R3 del
/// progetto: *«tutto ciò che è anche lontanamente sensibile resta sul
/// telefono»*, e cosa mangia una persona è dato dell'art. 9.
///
/// 💡 **Le forme non cambiano**: `DiaryDay`, `FoodEntry`, `FoodFavorite` sono le
/// stesse classi di ieri, e i nomi dei provider pure. ⚠️ Cambiare *dove* nascono
/// i dati e *come sono fatti* nello stesso giro vorrebbe dire non sapere quale
/// delle due cose ha rotto cosa.
///
/// ══ 🚨 L'UNICA COSA CHE RESTA DEL SERVER, E PERCHE' ══════════════════════
///
/// `POST /ai/food/valida`: il **setaccio** su una risposta del modello, cioè
/// `MealValidator`. ⛔ Non è un calcolo che si porta in Dart come le altre: qui
/// il rischio non è un numero sbagliato, è testo non filtrato che entra in
/// diario così com'è. 💡 La rotta valida e **restituisce**; a scrivere è l'app.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import '../health/health_controller.dart';
import 'data/diario_locale.dart';
import 'data/diary_models.dart';
import 'data/stima_ai.dart';
import 'data/stime_in_coda.dart';

/// Il giorno che si sta guardando.
///
/// ⚠️ **Resta dov'è, e non c'entra col trasloco**: è la data che si ha davanti,
/// non un dato. 💡 Sta in un provider separato dal diario perché cambiare giorno
/// deve **rifare la lettura**, e con la `family` sulla data quel comportamento è
/// automatico invece di dover ricordarsi di invalidare.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();

  return DateTime(now.year, now.month, now.day);
});

/// Le voci che stanno sparendo, mentre la scrittura non è ancora finita — C15.
///
/// ── 🚨 Il difetto, riferito il 12/08/2026 ────────────────────────────────
///
/// *«Quando slido via un cibo, mi dà una schermata rossa di errore (funziona,
/// ma dà errore).»*
///
/// L'errore era **`A dismissed Dismissible widget is still part of the tree`**,
/// e ha una causa precisa: `Dismissible.onDismissed` promette che chi lo ascolta
/// tolga l'elemento dalla lista **nello stesso frame**. Qui invece partiva una
/// `DELETE` sulla rete e poi un `invalidate`: fra il gesto e la lista nuova
/// passano centinaia di millisecondi, e in quel tempo Flutter ritrova nell'albero
/// un widget che si era già dichiarato scomparso.
///
/// ⚠️ **Serve ancora dopo il trasloco.** Una scrittura su SQLite dura pochi
/// millisecondi invece di mezzo secondo, ma resta `Future`: il frame del gesto
/// finisce prima, e il rettangolo rosso tornerebbe uguale.
///
/// 💡 **Gli id cancellati non si tolgono mai dall'insieme, ed è voluto.** Toglierli
/// vorrebbe dire aspettare che il diario nuovo sia arrivato — e se lo si facesse
/// prima, la riga riapparirebbe per un frame prima di sparire di nuovo. Un id
/// che non esiste più nei dati non fa nessun danno: filtra qualcosa che non c'è,
/// e l'insieme cresce di un intero per ogni cancellazione della sessione.
final vociInUscitaProvider = StateProvider<Set<int>>((ref) => const {});

/// La giornata alimentare di **un giorno qualunque** — I2.5.
///
/// 💡 Esiste separato da [diaryProvider] perché il calendario apre il dettaglio
/// di un giorno che non è quello selezionato nel diario. ⛔ Prima quel dettaglio
/// se lo faceva dare da `GET /calendar/{data}`, che adesso il cibo non ce l'ha
/// più.
final giornataProvider = FutureProvider.autoDispose
    .family<DiaryDay, DateTime>((ref, giorno) {
      ref.watch(revisioneDiarioProvider);

      return ref.watch(diarioLocaleProvider).giornata(giorno);
    });

/// La giornata alimentare — A4.1.
final diaryProvider = FutureProvider.autoDispose<DiaryDay>(
  (ref) => ref.watch(giornataProvider(ref.watch(selectedDateProvider)).future),
);

/// L'attesa delle stime — FASE 9.
///
/// 💡 Un provider e non un campo di `DiaryActions` perché lo usa anche chi
/// riprende una stima all'avvio, che di `DiaryActions` non ha bisogno.
final stimeInCodaProvider = Provider<StimeInCoda>((ref) {
  return StimeInCoda(
    ref.watch(apiClientProvider),
    ref.watch(localCacheProvider),
  );
});

/// Le scritture sul diario — A4.2 / A4.4 / A4.6.
class DiaryActions {
  DiaryActions(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  DiarioLocale get _diario => _ref.read(diarioLocaleProvider);

  DateTime get _giorno => _ref.read(selectedDateProvider);

  /// 🚨 **Un posto solo per dire «il diario è cambiato».**
  ///
  /// ⛔ Prima bastava `invalidate(diaryProvider)`: dashboard, calendario e
  /// grafici rifacevano la loro chiamata HTTP e trovavano i numeri nuovi.
  /// Adesso quei numeri nascono da SQLite, che non avvisa nessuno — e senza
  /// questo contatore aggiungere un alimento aggiornerebbe **solo** la
  /// schermata del diario, lasciando «Oggi» sulle calorie di prima.
  void _cambiato() {
    _ref.read(revisioneDiarioProvider.notifier).state++;
  }

  /// Inserimento manuale — A4.4.
  ///
  /// ⚠️ `grams` si passa **solo se c'è**: quando manca lo deriva
  /// [DiarioLocale.aggiungi] da `qty × unit`, con la stessa tabella che usava
  /// `FoodUnit` sul server. 🚨 Uno zero al posto di niente farebbe entrare nel
  /// diario una voce che non pesa nulla, e il giorno che si corregge la quantità
  /// non ci sarebbe niente da riscalare.
  Future<void> addManual({
    required String description,
    required String meal,
    double? grams,
    double? qty,
    String? unit,
    double? kcal,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    await _diario.aggiungi(
      giorno: _giorno,
      pasto: meal,
      descrizione: description,
      grammi: grams,
      quantita: qty,
      unita: unit,
      kcal: kcal,
      proteine: protein,
      carboidrati: carbs,
      grassi: fat,
    );

    _cambiato();
  }

  /// Riconoscimento da testo — A4.2 / A4.8.
  ///
  /// ── 🚨 `save: false`: si stima, non si scrive ───────────────────────────
  ///
  /// Fino al 12/08/2026 questa chiamata mandava `save: true` e il backend
  /// scriveva subito in diario. Il commento diceva che era per evitare «due
  /// richieste e la possibilità che la seconda fallisca», ed era un ragionamento
  /// giusto su una premessa sbagliata: dava per scontato che la stima fosse da
  /// accettare.
  ///
  /// ⚠️ Non lo è. Su «due cotolette di pollo» il modello ha risposto con **zero
  /// carboidrati** — cioè petto di pollo, non una cotoletta impanata — e nella
  /// `note` aveva scritto di non sapere se fossero panate. Scrivendo subito,
  /// quella nota non la leggeva nessuno e il numero sbagliato entrava nei totali.
  ///
  /// 💡 Il rischio che il vecchio commento temeva resta gestito: se la conferma
  /// fallisce, **il foglio è ancora aperto con la stima dentro** e si riprova.
  ///
  /// 🆕 **Dalla FASE 9 la stima non arriva più nella risposta.** Il server
  /// accoda e risponde in ~50 ms; l'attesa la fa `StimeInCoda`, qui sull'app,
  /// dove non tiene occupato uno dei sei processi del dominio.
  ///
  /// 💡 [avanzamento] dice **da quanto** si sta aspettando, così la schermata
  /// può cambiare quello che scrive invece di limitarsi a girare.
  Future<StimaAi> stimaDaTesto(
    String text,
    String meal, {
    void Function(Duration)? avanzamento,
  }) async {
    final coda = _ref.read(stimeInCodaProvider);

    final id = await coda.accodaTesto(
      testo: text,
      pasto: meal,
      quando: _giorno,
    );

    final pronta = await coda.aspetta(id, avanzamento: avanzamento);

    return StimaAi.fromJson(pronta.risultato).conFrase(text);
  }

  /// Riprende una stima lasciata a metà — FASE 9.7.
  ///
  /// 🚨 Il lavoro sul server **continua** anche con l'app chiusa: al rientro
  /// si ritrova, non si ricomincia. Ricominciare vorrebbe dire una seconda
  /// chiamata al modello per lo stesso piatto, pagata due volte.
  ///
  /// `null` quando non c'è niente in sospeso, che è il caso normale.
  Future<StimaRipresa?> riprendiStimaInSospeso({
    void Function(Duration)? avanzamento,
  }) async {
    final coda = _ref.read(stimeInCodaProvider);
    final id = await coda.inSospeso();

    if (id == null) return null;

    final pronta = await coda.aspetta(id, avanzamento: avanzamento);

    /*
     * 🚨 Il **pasto** arriva dal server e non si chiede di nuovo. La persona
     * l'aveva già scelto prima di chiudere l'app: richiederlo sarebbe farle
     * rifare un passo che aveva già fatto, per una nostra difficoltà tecnica.
     */
    return StimaRipresa(
      stima: StimaAi.fromJson(pronta.risultato),
      pasto: pronta.pasto ?? 'lunch',
      daFoto: pronta.daFoto,
    );
  }

  /// Riconoscimento da foto — A4.3 / A4.8.
  ///
  /// 🚨 Il file va **già compresso** da chi chiama: vedi `CanaleFoto`. Qui non
  /// si comprime perché questa classe non sa niente di piattaforma, e mandare
  /// l'originale da 10 MB su rete mobile è un upload che fallisce.
  ///
  /// ⚠️ `frase` resta nulla: da una foto non c'è niente da «precisare» — il
  /// foglio di conferma lo sa e offre di correggere i numeri invece di rifare
  /// la domanda.
  Future<StimaAi> stimaDaFoto(
    String path,
    String meal, {
    void Function(Duration)? avanzamento,
  }) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(path),
      'meal': meal,
      'eaten_at': _giorno.toIso8601String(),
    });

    final coda = _ref.read(stimeInCodaProvider);

    final id = await coda.accodaFoto(form);
    final pronta = await coda.aspetta(id, avanzamento: avanzamento);

    return StimaAi.fromJson(pronta.risultato);
  }

  /// Scrive in diario una stima **guardata da chi l'ha chiesta** — A4.8.
  ///
  /// ══ 🚨 IL SETACCIO RESTA SUL SERVER, LA SCRITTURA NO — I2.5 ═════════════
  ///
  /// Fino al 03/09/2026 `POST /ai/food/confirm` faceva **due cose**: validava le
  /// voci con `MealValidator` e le scriveva in `food_entries`.
  ///
  /// ⛔ **La validazione non si porta in Dart**, ed è l'unica eccezione alla
  /// regola R2 della Parte I. Le altre formule trasportate — le unità, i totali,
  /// le serie — sbagliano al massimo un numero. Questa no: è il filtro che
  /// impedisce a una risposta del modello di entrare nel diario così com'è, e un
  /// filtro che vive sul telefono è un filtro che si può aggirare e che non si
  /// può correggere senza pubblicare una versione.
  ///
  /// 💡 Quindi la rotta **valida e restituisce**, e a scrivere è l'app. ⚠️ Il
  /// prezzo è che confermare una stima **vuole la rete** — ma la stima stessa
  /// era arrivata dalla rete un attimo prima, quindi non toglie niente a nessuno.
  ///
  /// 🚨 **Si scrive PRIMA di dire che è andata bene.** Se la scrittura fallisce,
  /// l'eccezione arriva a chi ha chiamato e il foglio resta aperto con la stima
  /// dentro: è una proprietà del 12/08 e non si perde.
  Future<void> confermaStima(
    StimaAi stima, {
    required String meal,
    required bool daFoto,
  }) async {
    final risposta = await _api.post<Map<String, dynamic>>(
      '/ai/food/valida',
      body: {'items': stima.voci.map((v) => v.toJson()).toList()},
    );

    /*
     * 💡 **La risposta intera, non solo `estimate`**: `StimaAi.fromJson` prende
     * le voci da lì dentro e gli avvisi da `warnings`, che sta di fuori. ⚠️
     * Passando solo `estimate` gli avvisi si perderebbero in silenzio.
     */
    final pulita = StimaAi.fromJson(risposta);

    /*
     * 🚨 **Un pasto è una cosa sola.** Cinque scritture separate possono fallire
     * alla terza e lasciare in diario mezza cena, che nei totali è un numero
     * sbagliato senza nessun segno che lo sia. ⚠️ È la stessa ragione per cui
     * `AiController::scriviVoci()` scriveva in transazione.
     */
    await _diario.scriviLaStima(
      pulita.voci,
      giorno: _giorno,
      pasto: meal,
      fonte: daFoto ? 'ai_photo' : 'ai_text',
    );

    _cambiato();
  }

  Future<void> delete(int entryId) async {
    await _diario.cancella(entryId);

    _cambiato();
  }

  /// Cancella **facendo sparire subito la riga** — C15.
  ///
  /// 🚨 Serve allo scorrimento: `Dismissible` pretende che l'elemento esca dalla
  /// lista **nello stesso frame** del gesto, e nemmeno una scrittura locale ci
  /// arriva in tempo. Da lì il rettangolo rosso *«a dismissed Dismissible widget
  /// is still part of the tree»*, che compariva mentre la cancellazione
  /// funzionava benissimo.
  ///
  /// ⚠️ **Se la scrittura fallisce la riga torna**, e l'errore si rilancia a chi
  /// ha chiamato perché lo mostri. Far sparire per sempre una voce che
  /// nell'archivio c'è ancora sarebbe peggio dell'errore che si stava togliendo:
  /// al prossimo aggiornamento ricomparirebbe da sola, senza nessuna spiegazione.
  ///
  /// 💡 Il ripristino **non ripristina la posizione** nell'elenco: la giornata è
  /// ordinata per pasto e ora di scrittura, quindi la riga rientra dove le
  /// spetta senza che l'app debba ricordarselo.
  Future<void> deleteSubito(int entryId) async {
    final prima = _ref.read(vociInUscitaProvider);

    _ref.read(vociInUscitaProvider.notifier).state = {...prima, entryId};

    try {
      await _diario.cancella(entryId);

      _cambiato();
    } on Object {
      _ref.read(vociInUscitaProvider.notifier).state = {
        ..._ref.read(vociInUscitaProvider),
      }..remove(entryId);

      rethrow;
    }
  }

  /// Modifica una voce — C15.
  ///
  /// 🚨 **Si passa solo ciò che è stato toccato**, e `null` vuol dire «non
  /// toccato». I macro che arrivano vincono sempre sul ricalcolo: se l'utente li
  /// ha corretti a mano non vanno sovrascritti da una proporzione. Mandarli
  /// sempre — anche invariati — impedirebbe per sempre il ricalcolo automatico, e
  /// cambiare la quantità non aggiornerebbe più niente.
  ///
  /// 💡 La regola sta tutta in [DiarioLocale.aggiorna], che è il ritratto di
  /// `DiaryController::ricalcolaSeCambiaLaQuantita()`.
  Future<void> update(
    int entryId, {
    String? description,
    String? meal,
    double? qty,
    String? unit,
    double? grams,
    double? kcal,
    double? protein,
    double? carbs,
    double? fat,
  }) async {
    await _diario.aggiorna(
      entryId,
      descrizione: description,
      pasto: meal,
      quantita: qty,
      unita: unit,
      grammi: grams,
      kcal: kcal,
      proteine: protein,
      carboidrati: carbs,
      grassi: fat,
    );

    _cambiato();
  }

  /// Dichiara (o disfa) le calorie bruciate del giorno.
  ///
  /// ══ 🚨 SCRIVE SUL TELEFONO, NON SUL SERVER — FASE 11.5 ═════════════════
  ///
  /// 📌 Il committente: *«Nessun allenamento deve risiedere sul server, devono
  /// stare tutti nell'app»*. `daily_burns` è una delle tre tabelle che se ne
  /// vanno (`plan_tutto_sul_telefono.md` §2.1).
  ///
  /// ⚠️ `null` **disfa** la dichiarazione, non scrive zero: uno zero dichiarato
  /// è «oggi fermo» e vince sulla stima, l'assenza è «non lo so» e lascia
  /// parlare le sedute. 🚨 Confonderli qui vorrebbe dire che chi svuota il
  /// campo si ritrova a zero invece che com'era prima.
  Future<void> setDailyBurn(int? kcal) async {
    final giorno = _giorno;
    final archivio = _ref.read(archivioSaluteProvider);

    if (kcal == null) {
      await archivio.togliBruciateAMano(giorno);
    } else {
      await archivio.dichiaraBruciate(giorno, kcal);
    }

    _ref.read(revisioneAllenamentiProvider.notifier).state++;
    _cambiato();
  }

  /// Salva una voce fra i preferiti — A4.5.
  Future<void> favorite(int entryId) async {
    await _diario.salvaVoceComePreferito(entryId);

    _ref.invalidate(favoritesProvider);
  }
}

final diaryActionsProvider = Provider<DiaryActions>(DiaryActions.new);

/// I preferiti dell'iscritto, **ordinati per uso reale** — D2.
///
/// ⚠️ L'ordine non è alfabetico né cronologico: è `volteUsato`, poi `usatoIl`.
/// 📌 *«Chi ha venticinque preferiti vuole i tre che usa ogni giorno in cima,
/// non quelli che cominciano per A»*.
///
/// 🚨 **Il contatore è un dato salvato, non un aggregato**: contare le voci del
/// diario con la stessa descrizione darebbe un altro numero — chi ha scritto
/// «Pollo» a mano dieci volte non ha usato dieci volte il preferito «Pollo».
///
/// ⚠️ **Il nome resta inglese come le classi che maneggia**, e non è pigrizia:
/// lo guardano `favorites_sheet`, `diary_screen` e `preferiti_gia_salvati`, e
/// rinominarlo *nello stesso giro* in cui cambia da dove vengono i dati vorrebbe
/// dire non sapere quale delle due cose ha rotto cosa.
final favoritesProvider = FutureProvider.autoDispose<List<FoodFavorite>>(
  (ref) => ref.watch(diarioLocaleProvider).preferiti(),
);

/// Le azioni sui preferiti — D2.
class FavoriteActions {
  FavoriteActions(this._ref);

  final Ref _ref;

  DiarioLocale get _diario => _ref.read(diarioLocaleProvider);

  /// Salva **l'intero pasto** di un giorno come preferito.
  Future<void> saveMeal({
    required String meal,
    required String description,
  }) async {
    await _diario.salvaPasto(
      giorno: _ref.read(selectedDateProvider),
      pasto: meal,
      descrizione: description,
    );

    _ref.invalidate(favoritesProvider);
  }

  /// Rimette un preferito nel diario.
  ///
  /// ⚠️ Il giorno è **quello che si sta guardando**, non adesso: chi completa
  /// ieri sera vuole che il cibo finisca su ieri. È lo stesso motivo per cui
  /// l'app storica ha dovuto correggerlo (v1.26.2).
  Future<void> add(int favoriteId, {String? meal}) async {
    await _diario.usaPreferito(
      favoriteId,
      giorno: _ref.read(selectedDateProvider),
      pasto: meal,
    );

    _ref.read(revisioneDiarioProvider.notifier).state++;
    _ref.invalidate(favoritesProvider);
  }

  Future<void> remove(int favoriteId) async {
    await _diario.togliPreferito(favoriteId);

    _ref.invalidate(favoritesProvider);
  }
}

final favoriteActionsProvider = Provider<FavoriteActions>(FavoriteActions.new);

/// Una stima ritrovata dopo che l'app era stata chiusa — FASE 9.7.
///
/// 💡 Porta anche il **pasto**: la persona l'aveva già scelto prima di chiudere
/// l'app, e richiederlo sarebbe farle rifare un passo per una nostra difficoltà
/// tecnica.
class StimaRipresa {
  const StimaRipresa({
    required this.stima,
    required this.pasto,
    required this.daFoto,
  });

  final StimaAi stima;
  final String pasto;
  final bool daFoto;
}
