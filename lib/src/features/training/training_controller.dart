import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';

/// Una scheda assegnata — A5.1.
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.exercisesCount,
    this.notes,
    this.exercises = const [],
    this.editable = false,
    this.imageUrl,
    this.authorName,
    this.authorIsMe = false,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) => WorkoutPlan(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? '',
    notes: j['notes']?.toString(),
    exercisesCount: (j['exercises_count'] as num?)?.toInt() ?? 0,
    exercises: (j['exercises'] as List? ?? const [])
        .map((e) => PlanExercise.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
    // 🚨 Chi può modificare cosa lo dice il SERVER (campo `editable`).
    // Dedurlo qui confrontando l'autore con l'utente vorrebbe dire riscrivere
    // in Dart una regola che vive in `WorkoutPlanPolicy`: due copie divergono
    // sempre, e quella sbagliata mostra un pulsante «Modifica» che il server
    // rifiuta con un 403.
    editable: j['editable'] == true,
    imageUrl: j['image_url']?.toString(),
    authorName: (j['author'] as Map?)?['name']?.toString(),
    authorIsMe: (j['author'] as Map?)?['is_me'] == true,
  );

  final int id;
  final String name;
  final String? notes;
  final int exercisesCount;
  final List<PlanExercise> exercises;

  /// Vero solo per le schede che l'iscritto si è scritto da solo.
  final bool editable;

  /// La copertina — C23. `null` quando nessuno l'ha caricata.
  final String? imageUrl;

  final String? authorName;
  final bool authorIsMe;

  /// Da mostrare sotto il nome: «scritta dal tuo trainer» dà contesto a un
  /// elenco che altrimenti è solo una lista di nomi.
  String get attribuzione =>
      authorIsMe ? 'Scheda tua' : (authorName == null ? '' : 'Scritta da $authorName');
}

/// Una riga della scheda.
class PlanExercise {
  const PlanExercise({
    required this.id,
    required this.name,
    required this.prescription,
    this.restSec,
    this.targetWeight,
    this.notes,
    this.imageUrl,
  });

  factory PlanExercise.fromJson(Map<String, dynamic> j) => PlanExercise(
    id: (j['id'] as num).toInt(),
    name: (j['exercise'] as Map?)?['name']?.toString() ?? 'Esercizio',
    // 🚨 Arriva già formattata dal backend («3 × 8-12»): comporla qui
    // significherebbe avere due formati diversi fra app e pannello per la
    // stessa scheda.
    prescription: j['prescription']?.toString() ?? '',
    imageUrl: (j['exercise'] as Map?)?['image_url']?.toString(),
    restSec: (j['rest_sec'] as num?)?.toInt(),
    targetWeight: (j['target_weight'] as num?)?.toDouble(),
    notes: j['notes']?.toString(),
  );

  final int id;
  final String name;
  final String prescription;
  final int? restSec;
  final double? targetWeight;
  final String? notes;

  /// L'illustrazione dell'esercizio — C23.
  final String? imageUrl;
}

/// Le schede pubblicate dell'iscritto.
final plansProvider = FutureProvider.autoDispose<List<WorkoutPlan>>((ref) async {
  final data = await ref.watch(apiClientProvider).get<List<dynamic>>('/workout-plans');

  return data.map((e) => WorkoutPlan.fromJson((e as Map).cast<String, dynamic>())).toList();
});

/// Il dettaglio di una scheda, con gli esercizi.
final planDetailProvider = FutureProvider.autoDispose.family<WorkoutPlan, int>((ref, id) async {
  final data = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/workout-plans/$id');

  return WorkoutPlan.fromJson(data);
});

/// Le scritture sulle schede — C11.
///
/// L'iscritto si scrive le proprie (decisione D1); quelle del trainer le legge
/// e le esegue. Il rifiuto arriva dal server con `code: plan_not_editable`, ma
/// l'app non ci arriva mai perché nasconde il pulsante quando `editable` è
/// falso.
class PlanActions {
  PlanActions(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  Future<int> create({
    required String name,
    String? notes,
    required List<Map<String, dynamic>> exercises,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/workout-plans',
      body: {'name': name, 'notes': notes, 'exercises': exercises},
    );

    _ref.invalidate(plansProvider);

    return (data['id'] as num).toInt();
  }

  Future<void> update({
    required int id,
    required String name,
    String? notes,
    List<Map<String, dynamic>>? exercises,
  }) async {
    await _api.put<Map<String, dynamic>>(
      '/workout-plans/$id',
      body: {
        'name': name,
        'notes': notes,
        // `exercises` assente significa «non toccare gli esercizi»: rinominare
        // una scheda non deve costringere a rimandare tutte le righe.
        'exercises': ?exercises,
      },
    );

    _ref.invalidate(plansProvider);
    _ref.invalidate(planDetailProvider(id));
  }

  Future<void> delete(int id) async {
    await _api.delete('/workout-plans/$id');

    _ref.invalidate(plansProvider);
  }
}

final planActionsProvider = Provider<PlanActions>(PlanActions.new);
