/// I modelli dell'allenamento — C9/C10.
library;

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.startedAt,
    required this.isOpen,
    required this.sets,
    required this.photos,
    this.planId,
    this.planName,
    this.endedAt,
    this.durationMinutes,
    this.kcal,
    this.kcalSource,
    this.notes,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> j) {
    final piano = (j['plan'] as Map?)?.cast<String, dynamic>();

    return WorkoutSession(
      id: (j['id'] as num).toInt(),
      planId: (piano?['id'] as num?)?.toInt(),
      planName: piano?['name']?.toString(),
      startedAt: DateTime.parse(j['started_at'].toString()),
      endedAt: j['ended_at'] == null ? null : DateTime.parse(j['ended_at'].toString()),
      durationMinutes: (j['duration_minutes'] as num?)?.toInt(),
      isOpen: j['is_open'] == true,
      kcal: (j['kcal'] as num?)?.toInt(),
      kcalSource: j['kcal_source']?.toString(),
      notes: j['notes']?.toString(),
      sets: ((j['sets'] as List?) ?? const [])
          .map((e) => LoggedSet.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      photos: ((j['photos'] as List?) ?? const [])
          .map((e) => SessionPhoto.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  final int id;
  final int? planId;
  final String? planName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationMinutes;
  final bool isOpen;
  final int? kcal;

  /// `manual` · `ai` · `formula`. Serve a dire **da dove viene** il numero:
  /// senza, chi lo legge non sa se può sovrascriverlo.
  final String? kcalSource;

  final String? notes;
  final List<LoggedSet> sets;
  final List<SessionPhoto> photos;

  String get titolo => planName ?? 'Sessione libera';

  String get etichettaKcal => switch (kcalSource) {
    'manual' => 'inserite a mano',
    'ai' => 'stima AI',
    _ => 'stima',
  };
}

class LoggedSet {
  const LoggedSet({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    this.reps,
    this.weight,
    this.restSec,
  });

  factory LoggedSet.fromJson(Map<String, dynamic> j) {
    final esercizio = (j['exercise'] as Map?)?.cast<String, dynamic>();

    return LoggedSet(
      id: (j['id'] as num).toInt(),
      exerciseId: (esercizio?['id'] as num?)?.toInt() ?? 0,
      exerciseName: esercizio?['name']?.toString() ?? 'Esercizio',
      setNumber: (j['set_number'] as num).toInt(),
      reps: (j['reps'] as num?)?.toInt(),
      weight: (j['weight'] as num?)?.toDouble(),
      restSec: (j['rest_sec'] as num?)?.toInt(),
    );
  }

  final int id;
  final int exerciseId;
  final String exerciseName;
  final int setNumber;
  final int? reps;
  final double? weight;
  final int? restSec;
}

class SessionPhoto {
  const SessionPhoto({required this.id, required this.url});

  factory SessionPhoto.fromJson(Map<String, dynamic> j) =>
      SessionPhoto(id: (j['id'] as num).toInt(), url: j['url'].toString());

  final int id;
  final String url;
}

/// Una riga del player: un esercizio con le sue serie.
///
/// 🚨 **Non è un modello di rete**: è lo stato dell'interfaccia mentre ci si
/// allena. Nasce dalla scheda (le serie previste) e si riempie con ciò che è
/// stato davvero fatto. Tenerlo separato dal modello del server è ciò che
/// permette di aggiungere un esercizio al volo senza inventarsi un id finto.
class PlayerExercise {
  PlayerExercise({
    required this.name,
    required this.rows,
    this.exerciseId,
    this.reps,
    this.restSec = 90,
    this.targetWeight,
    this.notes,
    this.imageUrl,
  });

  int? exerciseId;
  String name;

  /// Le ripetizioni **prescritte**, come stringa: «8-12», «cedimento», «max».
  String? reps;

  int restSec;
  double? targetWeight;
  String? notes;

  /// L'illustrazione dell'esercizio — C23. Viene dalla scheda e resta anche
  /// per gli esercizi aggiunti al volo, che semplicemente non ne hanno una.
  String? imageUrl;
  List<PlayerSet> rows;

  /// Vero quando ogni serie prevista è stata registrata.
  bool get completo => rows.isNotEmpty && rows.every((r) => r.done);
}

class PlayerSet {
  PlayerSet({required this.setNumber, this.reps, this.weight, this.done = false});

  final int setNumber;
  int? reps;
  double? weight;
  bool done;
}
