import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Una scheda assegnata — A5.1.
class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.name,
    required this.exercisesCount,
    this.notes,
    this.exercises = const [],
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> j) => WorkoutPlan(
    id: (j['id'] as num).toInt(),
    name: j['name']?.toString() ?? '',
    notes: j['notes']?.toString(),
    exercisesCount: (j['exercises_count'] as num?)?.toInt() ?? 0,
    exercises: (j['exercises'] as List? ?? const [])
        .map((e) => PlanExercise.fromJson((e as Map).cast<String, dynamic>()))
        .toList(),
  );

  final int id;
  final String name;
  final String? notes;
  final int exercisesCount;
  final List<PlanExercise> exercises;
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
  });

  factory PlanExercise.fromJson(Map<String, dynamic> j) => PlanExercise(
    id: (j['id'] as num).toInt(),
    name: (j['exercise'] as Map?)?['name']?.toString() ?? 'Esercizio',
    // 🚨 Arriva già formattata dal backend («3 × 8-12»): comporla qui
    // significherebbe avere due formati diversi fra app e pannello per la
    // stessa scheda.
    prescription: j['prescription']?.toString() ?? '',
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
