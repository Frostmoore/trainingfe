/// I modelli dell'allenamento — C9/C10.
library;

import '../../../core/storage/archivio_salute.dart';
import 'calorie_allenamento.dart';
import 'gruppo_muscolare.dart';

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
      // 🚨 `.toLocal()` — A3. Il server manda un ISO8601 con l'offset, e
      // `DateTime.parse` restituisce percio' un `DateTime` **in UTC**: ogni
      // `DateFormat(...).format()` su quello scriveva l'ora di Greenwich.
      // L'allenamento delle 20:00 compariva come «18:00», e quello di mezzanotte
      // e mezza finiva nel giorno prima.
      startedAt: DateTime.parse(j['started_at'].toString()).toLocal(),
      endedAt: j['ended_at'] == null
          ? null
          : DateTime.parse(j['ended_at'].toString()).toLocal(),
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

  /// Una seduta letta **dall'archivio locale** — FASE 11.4, 21/08/2026.
  ///
  /// ══ 🚨 STESSA CLASSE, ALTRA SORGENTE ══════════════════════════════════
  ///
  /// 📌 Il committente: *«Nessun allenamento deve risiedere sul server, devono
  /// stare tutti nell'app»*.
  ///
  /// 💡 **Si tiene [WorkoutSession] invece di inventarne una locale**: la usano
  /// il player, il riepilogo, lo storico unificato e il carico. Una seconda
  /// classe con gli stessi campi vorrebbe dire due modelli da tenere allineati
  /// — e il primo che diverge lo fa in silenzio.
  ///
  /// ⚠️ **`id` qui è quello LOCALE**, non `idServer`: è quello che le rotte si
  /// passano (`AppRoutes.player`, `AppRoutes.riepilogo`) e quello a cui le
  /// serie si legano.
  ///
  /// 🚨 Le calorie si **calcolano qui se non sono salvate**, con
  /// `CalorieAllenamento`: è la stessa regola del server — quello che è scritto
  /// vince, la formula è il ripiego.
  factory WorkoutSession.dallArchivio(
    SedutaAllenamento seduta,
    List<SerieSeduta> serie, {
    required double kg,
  }) {
    final fine = seduta.finitaIl;
    final durata = (fine ?? DateTime.now()).difference(seduta.iniziataIl);

    return WorkoutSession(
      id: seduta.id,
      planId: seduta.schedaServerId,
      planName: seduta.nomeScheda,
      startedAt: seduta.iniziataIl,
      endedAt: fine,
      durationMinutes: durata.inMinutes,
      isOpen: fine == null,

      /*
       * ⛔ Su una seduta **ancora aperta** non si mostra nessun numero: la
       * formula darebbe le calorie «finora», che a metà allenamento è un
       * numero che cambia mentre lo si guarda.
       */
      kcal: fine == null
          ? seduta.kcal
          : CalorieAllenamento.kcalDi(
              kcalSalvate: seduta.kcal,
              durata: durata,
              kg: kg,
              metDelleSerie: serie.map((r) => r.met),
            ),

      // 💡 `formula` e non `ai`: da FASE 11 il modello qui non c'entra più.
      kcalSource: seduta.kcalAMano ? 'manual' : 'formula',
      notes: seduta.note,
      sets: serie.map(LoggedSet.dallArchivio).toList(),

      // 🚨 Le foto stanno già sul telefono da S5.3: `photos` è morto.
      photos: const [],
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

  /// Una serie letta dall'archivio locale — FASE 11.4.
  factory LoggedSet.dallArchivio(SerieSeduta r) => LoggedSet(
    id: r.id,
    exerciseId: r.esercizioId,
    exerciseName: r.nomeEsercizio,
    setNumber: r.numero,
    reps: r.ripetizioni,
    weight: r.pesoKg,
    restSec: r.riposoSec,
  );

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
    this.seriePreviste,
    this.restSec = 90,
    this.targetWeight,
    this.notes,
    this.imageUrl,
    this.muscoli,
  });

  int? exerciseId;
  String name;

  /// Le serie **prescritte** dalla scheda, quando viene da una scheda.
  ///
  /// ══ 🚨 LA PRESCRIZIONE NON È LO STORICO — B.15, 24/08/2026 ════════════
  ///
  /// ⛔ Il salvataggio a fine allenamento mandava `sets: rows.length`, cioè
  /// **quante righe c'erano nel player**. Un esercizio non toccato ne riceve tre
  /// di default, quindi dire «sì» a fine seduta riscriveva la scheda da 4×15 a
  /// **3×15** su tutto quello che non si era fatto.
  ///
  /// 🚨 Quante serie hai fatto è **storia**; quante ne devi fare è **scheda**.
  /// Sono due cose diverse e non devono passare per lo stesso campo.
  ///
  /// ⚠️ `null` per un esercizio aggiunto al volo: lì non c'è nessuna
  /// prescrizione da conservare, e il numero di righe è l'unica cosa che si sa.
  int? seriePreviste;

  /// Che muscoli allena, quando l'ha detto qualcuno — 3b-A.3.5, 24/08/2026.
  ///
  /// 🚨 Serve **solo** per gli esercizi scritti al volo che il catalogo non
  /// conosce: da A.3.5 il server rifiuta di crearne uno senza muscoli, e senza
  /// questo campo la serie prenderebbe un 422 **a metà allenamento** — cioè nel
  /// momento peggiore possibile per scoprire che manca un dato.
  ///
  /// ⚠️ `null` non vuol dire «nessuno»: vuol dire che nessuno ha risposto.
  MuscoliScelti? muscoli;

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
  PlayerSet({
    required this.setNumber,
    this.reps,
    this.weight,
    this.done = false,
  });

  final int setNumber;
  int? reps;
  double? weight;
  bool done;
}
