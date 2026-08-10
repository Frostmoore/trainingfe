import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import 'data/diary_models.dart';

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

  /// Riconoscimento da testo — A4.2.
  ///
  /// `save: true`: il backend crea già le voci. Restituire la stima e poi
  /// crearle dall'app significherebbe due richieste e la possibilità che la
  /// seconda fallisca lasciando l'utente con una stima che non ha salvato.
  Future<void> addFromText(String text, String meal) async {
    await _api.post<dynamic>(
      '/ai/food/text',
      body: {
        'text': text,
        'meal': meal,
        'eaten_at': _ref.read(selectedDateProvider).toIso8601String(),
        'save': true,
      },
    );

    _ref.invalidate(diaryProvider);
  }

  /// Riconoscimento da foto — A4.3.
  ///
  /// 🚨 Il file va **già compresso** da chi chiama: vedi `PhotoPicker`. Qui non
  /// si comprime perché questa classe non sa niente di piattaforma, e mandare
  /// l'originale da 10 MB su rete mobile è un upload che fallisce.
  Future<void> addFromPhoto(String path, String meal) async {
    final form = FormData.fromMap({
      'photo': await MultipartFile.fromFile(path),
      'meal': meal,
      'eaten_at': _ref.read(selectedDateProvider).toIso8601String(),
      'save': 'true',
    });

    await _api.upload<dynamic>('/ai/food/photo', form);

    _ref.invalidate(diaryProvider);
  }

  Future<void> delete(int entryId) async {
    await _api.delete('/food-entries/$entryId');

    _ref.invalidate(diaryProvider);
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
