/// I modelli dell'allenamento — C9/C10.
library;

import '../../../core/storage/archivio_salute.dart';
import 'calorie_allenamento.dart';

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

/*
 * ══ 🪦 QUI C'ERANO `PlayerExercise` E `PlayerSet` — tolti in 3b-E ══════════
 *
 * ⛔ Erano **due modelli affiancati**: uno per quello che la scheda prescrive
 * (`previste`) e uno per quello che si stava facendo (`rows`), con due
 * numerazioni tenute in fila a mano. 🚨 Il loro disallineamento e' la sorgente
 * di meta' dei difetti di B.15.
 *
 * 💡 Da 3b-E la riga della scheda **e'** la riga che si compila:
 * `EsercizioInAllenamento` in `data/allenamento_in_corso.dart`, che estende
 * quello dell'editor. ⚠️ Sono stati **cancellati e non lasciati li'**: un
 * modello morto che si legge ancora bene e' il primo che qualcuno riusa.
 */
