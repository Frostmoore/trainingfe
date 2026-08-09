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
  Future<void> favorite(int entryId) async {
    await _api.post<dynamic>('/food-entries/$entryId/favorite');
  }
}

final diaryActionsProvider = Provider<DiaryActions>(DiaryActions.new);
