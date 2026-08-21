import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import 'data/session_models.dart';

/// Lo storico degli allenamenti — C10.
final sessionsProvider = FutureProvider.autoDispose<List<WorkoutSession>>((
  ref,
) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<List<dynamic>>('/workout-sessions');

  return data
      .map((e) => WorkoutSession.fromJson((e as Map).cast<String, dynamic>()))
      .toList();
});

/// Una sessione singola: il player la ricarica dopo ogni chiusura.
final sessionProvider = FutureProvider.autoDispose.family<WorkoutSession, int>((
  ref,
  id,
) async {
  final data = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/workout-sessions/$id');

  return WorkoutSession.fromJson(data);
});

/// La sessione ancora aperta, se c'è.
///
/// ⚠️ Serve a riprendere un allenamento interrotto: senza, chi chiude l'app a
/// metà seduta si ritrova a doverne aprire una nuova, e lo storico si riempie
/// di sessioni monche.
final openSessionProvider = FutureProvider.autoDispose<WorkoutSession?>((
  ref,
) async {
  final sessioni = await ref.watch(sessionsProvider.future);

  for (final s in sessioni) {
    if (s.isOpen) return s;
  }

  return null;
});

class SessionActions {
  SessionActions(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  /// Apre una sessione, con o senza scheda.
  Future<WorkoutSession> start({int? planId}) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/workout-sessions',
      body: {'workout_plan_id': ?planId},
    );

    _ref.invalidate(sessionsProvider);

    return WorkoutSession.fromJson(data);
  }

  /// Registra una serie.
  ///
  /// 🚨 **È un UPSERT lato server** sulla terna (sessione, esercizio, numero):
  /// rimandare la stessa serie quando la rete va e viene **non la duplica**.
  /// È la proprietà che rende il player utilizzabile in una palestra
  /// interrata, dove il segnale non c'è quasi mai.
  ///
  /// `exerciseName` invece di `exerciseId` quando l'esercizio è stato aggiunto
  /// al volo: il server lo riconcilia con la libreria e lo crea se serve.
  Future<int> logSet({
    required int sessionId,
    required int setNumber,
    int? exerciseId,
    String? exerciseName,
    int? reps,
    double? weight,
    int? restSec,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/workout-sessions/$sessionId/sets',
      body: {
        'exercise_id': ?exerciseId,
        if (exerciseId == null && exerciseName != null)
          'exercise_name': exerciseName,
        'set_number': setNumber,
        'reps': ?reps,
        'weight': ?weight,
        'rest_sec': ?restSec,
      },
    );

    return (data['exercise_id'] as num?)?.toInt() ?? exerciseId ?? 0;
  }

  /// Chiude la sessione e fa partire la stima delle calorie.
  Future<void> finish(int sessionId) async {
    await _api.post<dynamic>('/workout-sessions/$sessionId/finish');

    _ref.invalidate(sessionsProvider);
    _ref.invalidate(sessionProvider(sessionId));
  }

  /// Corregge a mano le calorie. `null` **rimette la stima**, non azzera.
  Future<void> setKcal(int sessionId, int? kcal) async {
    await _api.patch<dynamic>(
      '/workout-sessions/$sessionId/kcal',
      body: {'kcal': kcal},
    );

    _ref.invalidate(sessionsProvider);
    _ref.invalidate(sessionProvider(sessionId));
  }

  Future<void> delete(int sessionId) async {
    await _api.delete('/workout-sessions/$sessionId');

    _ref.invalidate(sessionsProvider);
  }
}

final sessionActionsProvider = Provider<SessionActions>(SessionActions.new);
