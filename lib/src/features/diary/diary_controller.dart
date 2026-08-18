import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import 'data/diary_models.dart';
import 'data/stima_ai.dart';

/// Il giorno che si sta guardando.
///
/// Sta in un provider separato dal diario perché cambiare giorno deve
/// **rifare la richiesta**, e con `family` sulla data quel comportamento è
/// automatico invece di dover ricordarsi di invalidare.
final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();

  return DateTime(now.year, now.month, now.day);
});

String _iso(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// Le voci che stanno sparendo, mentre il server non lo sa ancora — C15.
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
/// 💡 **Per questo la cancellazione «funzionava lo stesso»**: la richiesta partiva
/// davvero, e il diario si aggiornava. L'eccezione riguardava solo la coerenza
/// dell'albero — ma un rettangolo rosso in mezzo alla schermata è, per chi usa
/// l'app, indistinguibile da un guasto.
///
/// ⚠️ **Rimuovere l'elemento subito è l'unico modo corretto**, e vale anche come
/// scelta d'interfaccia: la riga sparisce quando il dito la lascia, non quando
/// risponde il server. Se la cancellazione fallisce, la riga **torna** e si dice
/// perché.
///
/// 💡 **Gli id cancellati non si tolgono mai dall'insieme, ed è voluto.** Toglierli
/// vorrebbe dire aspettare che il diario nuovo sia arrivato — e se lo si facesse
/// prima, la riga riapparirebbe per un frame prima di sparire di nuovo. Un id
/// che non esiste più nei dati non fa nessun danno: filtra qualcosa che non c'è,
/// e l'insieme cresce di un intero per ogni cancellazione della sessione.
final vociInUscitaProvider = StateProvider<Set<int>>((ref) => const {});

/// La giornata alimentare — A4.1.
final diaryProvider = FutureProvider.autoDispose<DiaryDay>((ref) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/diary', query: {'date': _iso(ref.watch(selectedDateProvider))});

  return DiaryDay.fromJson(data);
});

/// Le scritture sul diario — A4.2 / A4.4 / A4.6.
class DiaryActions {
  DiaryActions(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  /// Inserimento manuale — A4.4.
  ///
  /// `grams` si manda **solo se c'è**: quando manca, il backend lo deriva da
  /// `qty × unit` con la tabella di `FoodUnit`. Mandare uno zero invece di
  /// niente farebbe entrare nel diario una voce che non pesa nulla.
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
    await _api.post<dynamic>(
      '/food-entries',
      body: {
        'description': description,
        'meal': meal,
        'eaten_at': _ref.read(selectedDateProvider).toIso8601String(),
        // `?chiave: valore` omette la voce quando il valore è nullo: mandare
        // uno zero invece di niente farebbe entrare nel diario una voce che non
        // pesa nulla, e il backend non potrebbe più derivare i grammi da
        // quantità e unità.
        'grams': ?grams,
        'qty': ?qty,
        'unit': ?unit,
        'kcal': ?kcal,
        'protein': ?protein,
        'carbs': ?carbs,
        'fat': ?fat,
      },
    );

    _ref.invalidate(diaryProvider);
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
  /// Prima, se falliva la scrittura, si perdeva comunque tutto — solo senza
  /// averla mai vista.
  Future<StimaAi> stimaDaTesto(String text, String meal) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/ai/food/text',
      body: {
        'text': text,
        'meal': meal,
        'eaten_at': _ref.read(selectedDateProvider).toIso8601String(),
        'save': false,
      },
    );

    return StimaAi.fromJson(data).conFrase(text);
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
  Future<StimaAi> stimaDaFoto(String path, String meal) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(path),
      'meal': meal,
      'eaten_at': _ref.read(selectedDateProvider).toIso8601String(),
      'save': 'false',
    });

    final data = await _api.upload<Map<String, dynamic>>('/ai/food/photo', form);

    return StimaAi.fromJson(data);
  }

  /// Scrive in diario una stima **guardata da chi l'ha chiesta** — A4.8.
  ///
  /// 🚨 Passa da `/ai/food/confirm` e non da `/food-entries` perché `source` e
  /// `ai_raw` devono sopravvivere: senza, ogni voce nascerebbe `manual` e il
  /// giorno che un modello peggiora non si saprebbe più quali voci rifare.
  ///
  /// ⚠️ **Non consuma quota**: la chiamata al modello è già stata pagata dalla
  /// stima.
  Future<void> confermaStima(StimaAi stima, {required String meal, required bool daFoto}) async {
    await _api.post<dynamic>(
      '/ai/food/confirm',
      body: {
        'source': daFoto ? 'ai_photo' : 'ai_text',
        'meal': meal,
        'eaten_at': _ref.read(selectedDateProvider).toIso8601String(),
        'items': stima.voci.map((v) => v.toJson()).toList(),
      },
    );

    _ref.invalidate(diaryProvider);
  }

  Future<void> delete(int entryId) async {
    await _api.delete('/food-entries/$entryId');

    _ref.invalidate(diaryProvider);
  }

  /// Cancella **facendo sparire subito la riga** — C15.
  ///
  /// 🚨 Serve allo scorrimento: `Dismissible` pretende che l'elemento esca dalla
  /// lista **nello stesso frame** del gesto, e una `DELETE` sulla rete non ci
  /// arriva mai in tempo. Da lì il rettangolo rosso *«a dismissed Dismissible
  /// widget is still part of the tree»*, che compariva mentre la cancellazione
  /// funzionava benissimo.
  ///
  /// ⚠️ **Se la richiesta fallisce la riga torna**, e l'errore si rilancia a chi
  /// ha chiamato perché lo mostri. Far sparire per sempre una voce che il server
  /// ha ancora sarebbe peggio dell'errore che si stava togliendo: al prossimo
  /// aggiornamento ricomparirebbe da sola, senza nessuna spiegazione.
  ///
  /// 💡 Il ripristino **non ripristina la posizione** nell'elenco: il diario è
  /// ordinato dal server per pasto e orario, quindi la riga rientra dove le
  /// spetta senza che l'app debba ricordarselo.
  Future<void> deleteSubito(int entryId) async {
    final prima = _ref.read(vociInUscitaProvider);

    _ref.read(vociInUscitaProvider.notifier).state = {...prima, entryId};

    try {
      await _api.delete('/food-entries/$entryId');

      _ref.invalidate(diaryProvider);
    } on Object {
      _ref.read(vociInUscitaProvider.notifier).state = {..._ref.read(vociInUscitaProvider)}
        ..remove(entryId);

      rethrow;
    }
  }

  /// Salva una voce fra i preferiti — A4.5.
  /// Modifica una voce — C15.
  ///
  /// 🚨 **Si manda solo ciò che è stato toccato.** I macro che arrivano vincono
  /// sempre sul ricalcolo del server: se l'utente li ha corretti a mano non
  /// vanno sovrascritti da una stima. Mandarli sempre — anche invariati —
  /// impedirebbe per sempre il ricalcolo automatico, e cambiare la quantità non
  /// aggiornerebbe più niente.
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
    await _api.patch<dynamic>(
      '/food-entries/$entryId',
      body: {
        'description': ?description,
        'meal': ?meal,
        'qty': ?qty,
        'unit': ?unit,
        'grams': ?grams,
        'kcal': ?kcal,
        'protein': ?protein,
        'carbs': ?carbs,
        'fat': ?fat,
      },
    );

    _ref.invalidate(diaryProvider);
  }

  /// Le calorie bruciate dichiarate a mano per il giorno — C15.
  ///
  /// ⚠️ `null` **rimette la stima**, non azzera: è la differenza fra «non lo so»
  /// e «oggi ho bruciato zero», e il backend la rispetta.
  Future<void> setDailyBurn(int? kcal) async {
    await _api.post<dynamic>(
      '/daily-burn',
      body: {
        'date': DateFormat('yyyy-MM-dd').format(_ref.read(selectedDateProvider)),
        'kcal': kcal,
      },
    );

    _ref.invalidate(diaryProvider);
  }

  Future<void> favorite(int entryId) async {
    await _api.post<dynamic>('/food-entries/$entryId/favorite');
  }
}

final diaryActionsProvider = Provider<DiaryActions>(DiaryActions.new);

/// I preferiti — D2.
///
/// 🚨 **Due cose diverse dietro la stessa parola**: un singolo alimento
/// («fette biscottate, 30 g») e un **pasto intero** («la mia colazione», con
/// dentro cinque voci). Il secondo è quello che fa risparmiare tempo davvero,
/// perché una colazione si ripete uguale per mesi — ed è anche quello che
/// nell'app storica viene usato di più.
class FoodFavorite {
  const FoodFavorite({
    required this.id,
    required this.description,
    required this.isMeal,
    required this.itemsCount,
    required this.timesUsed,
    this.kcal,
    this.protein,
    this.carbs,
    this.fat,
    this.grams,
    this.qty,
    this.unit,
  });

  factory FoodFavorite.fromJson(Map<String, dynamic> j) => FoodFavorite(
    id: (j['id'] as num).toInt(),
    description: j['description']?.toString() ?? '',
    isMeal: j['is_meal'] == true,
    itemsCount: (j['items_count'] as num?)?.toInt() ?? 1,
    timesUsed: (j['times_used'] as num?)?.toInt() ?? 0,
    kcal: (j['kcal'] as num?)?.toDouble(),
    protein: (j['protein'] as num?)?.toDouble(),
    carbs: (j['carbs'] as num?)?.toDouble(),
    fat: (j['fat'] as num?)?.toDouble(),
    grams: (j['grams'] as num?)?.toDouble(),
    qty: (j['qty'] as num?)?.toDouble(),
    unit: j['unit']?.toString(),
  );

  final int id;
  final String description;
  final bool isMeal;
  final int itemsCount;
  final int timesUsed;
  final double? kcal, protein, carbs, fat, grams, qty;
  final String? unit;

  /// La quantità come la si legge: «100 ml · 100 g».
  String? get quantita {
    if (qty != null && unit != null) {
      final n = qty! == qty!.roundToDouble() ? qty!.toInt().toString() : qty!.toString();
      final base = '$n $unit';

      return unit != 'g' && grams != null ? '$base · ${grams!.round()} g' : base;
    }

    return grams == null ? null : '${grams!.round()} g';
  }
}

/// I preferiti dell'iscritto, **ordinati per uso reale** dal server.
///
/// ⚠️ L'ordine non è alfabetico né cronologico: è `times_used`. Chi ha
/// venticinque preferiti vuole i tre che usa ogni giorno in cima, non quelli
/// che cominciano per A.
final favoritesProvider = FutureProvider.autoDispose<List<FoodFavorite>>((ref) async {
  final data = await ref.watch(apiClientProvider).get<List<dynamic>>('/food-favorites');

  return data
      .map((e) => FoodFavorite.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
});

/// Le azioni sui preferiti — D2.
class FavoriteActions {
  FavoriteActions(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  /// Salva **l'intero pasto** di un giorno come preferito.
  Future<void> saveMeal({required String meal, required String description}) async {
    await _api.post<dynamic>(
      '/food-favorites/meal',
      body: {
        'meal': meal,
        'description': description,
        'date': DateFormat('yyyy-MM-dd').format(_ref.read(selectedDateProvider)),
      },
    );

    _ref.invalidate(favoritesProvider);
  }

  /// Rimette un preferito nel diario.
  ///
  /// ⚠️ `eaten_at` è il **giorno che si sta guardando**, non adesso: chi
  /// completa ieri sera vuole che il cibo finisca su ieri. È lo stesso motivo
  /// per cui l'app storica ha dovuto correggerlo (v1.26.2).
  Future<void> add(int favoriteId, {String? meal}) async {
    await _api.post<dynamic>(
      '/food-favorites/$favoriteId/add',
      body: {
        'meal': ?meal,
        'eaten_at': _ref.read(selectedDateProvider).toIso8601String(),
      },
    );

    _ref.invalidate(diaryProvider);
    _ref.invalidate(favoritesProvider);
  }

  Future<void> remove(int favoriteId) async {
    await _api.delete('/food-favorites/$favoriteId');

    _ref.invalidate(favoritesProvider);
  }
}

final favoriteActionsProvider = Provider<FavoriteActions>(FavoriteActions.new);
