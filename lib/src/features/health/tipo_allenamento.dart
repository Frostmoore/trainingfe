import 'package:flutter/material.dart';

/// Come si chiama, in italiano, un allenamento che arriva dall'orologio — FASE 1.8.
///
/// ── 🚨 Perché una traduzione e non l'etichetta originale ──────────────────
///
/// Quello che arriva da Health Connect è un codice per macchine:
/// `STRENGTH_TRAINING`, `HIGH_INTENSITY_INTERVAL_TRAINING`,
/// `SWIMMING_OPEN_WATER`. Metterlo a schermo così com'è vuol dire chiedere a chi
/// usa l'app di leggere il nostro protocollo.
///
/// ── ⚠️ E perché non si traducono tutti ────────────────────────────────────
///
/// Il pacchetto ne dichiara più di cento, e una buona parte non la vedrà mai
/// nessuno: `CURLING`, `EQUESTRIAN_SPORTS`, `PARAGLIDING`. Tradurli tutti
/// vorrebbe dire cento righe da mantenere per coprire casi che non esistono.
///
/// 💡 Quindi: **si traduce quello che la gente fa davvero**, e per tutto il
/// resto c'è una regola che se la cava da sola — `DISC_SPORTS` diventa «Disc
/// sports». Brutto ma leggibile, e soprattutto **non sbagliato**.
///
/// 🚨 Il codice originale resta comunque salvato nell'archivio: se un giorno
/// serve tradurne uno in più, i dati di chi l'ha già fatto ci sono ancora.
///
/// ── ⚠️ Una stranezza del pacchetto, che è bene sapere ─────────────────────
///
/// `HealthWorkoutActivityType` contiene anche `SINUS_RHYTHM`,
/// `ATRIAL_FIBRILLATION` e altri esiti di **elettrocardiogramma**: non sono
/// allenamenti, stanno lì per come è fatto il pacchetto. Non li leggiamo — non
/// chiediamo l'ECG — ma se comparissero non devono finire nello storico
/// travestiti da attività fisica. Per questo c'è `eUnAllenamento`.
class TipoAllenamento {
  const TipoAllenamento({
    required this.codice,
    required this.nome,
    required this.icona,
  });

  /// Il codice originale, come arriva dall'orologio.
  final String codice;

  /// Come si chiama per una persona.
  final String nome;

  final IconData icona;

  /// I tipi che vale la pena tradurre, cioè quelli che la gente fa.
  ///
  /// 💡 L'ordine non conta: è una mappa. Conta che ci siano **corsa, bici e
  /// palestra**, che sono i tre casi per cui questa funzione esiste.
  static const _tradotti = <String, (String, IconData)>{
    // ── Le tre che coprono quasi tutto ──────────────────────────────────
    'RUNNING': ('Corsa', Icons.directions_run),
    'BIKING': ('Bici', Icons.directions_bike),
    'STRENGTH_TRAINING': ('Pesi', Icons.fitness_center),

    // ── Le varianti degli stessi tre ────────────────────────────────────
    'RUNNING_TREADMILL': ('Corsa sul tapis roulant', Icons.directions_run),
    'BIKING_STATIONARY': ('Cyclette', Icons.directions_bike),
    'HAND_CYCLING': ('Handbike', Icons.directions_bike),
    'WEIGHTLIFTING': ('Sollevamento pesi', Icons.fitness_center),
    'TRADITIONAL_STRENGTH_TRAINING': ('Pesi', Icons.fitness_center),
    'FUNCTIONAL_STRENGTH_TRAINING': ('Functional', Icons.fitness_center),
    'CALISTHENICS': ('Corpo libero', Icons.accessibility_new),
    'CORE_TRAINING': ('Addominali', Icons.accessibility_new),
    'CROSS_TRAINING': ('Cross training', Icons.fitness_center),

    // ── Camminate ───────────────────────────────────────────────────────
    'WALKING': ('Camminata', Icons.directions_walk),
    'WALKING_TREADMILL': ('Camminata sul tapis roulant', Icons.directions_walk),
    'HIKING': ('Escursione', Icons.terrain),
    'STAIR_CLIMBING': ('Scale', Icons.stairs),
    'STAIRS': ('Scale', Icons.stairs),
    'STAIR_CLIMBING_MACHINE': ('Step machine', Icons.stairs),
    'STEP_TRAINING': ('Step', Icons.stairs),

    // ── Acqua ───────────────────────────────────────────────────────────
    'SWIMMING': ('Nuoto', Icons.pool),
    'SWIMMING_POOL': ('Nuoto in piscina', Icons.pool),
    'SWIMMING_OPEN_WATER': ('Nuoto in acque libere', Icons.pool),
    'WATER_FITNESS': ('Acquagym', Icons.pool),
    'ROWING': ('Canottaggio', Icons.rowing),
    'ROWING_MACHINE': ('Vogatore', Icons.rowing),
    'SURFING': ('Surf', Icons.surfing),

    // ── Sala e corsi ────────────────────────────────────────────────────
    'ELLIPTICAL': ('Ellittica', Icons.airline_seat_legroom_extra),
    'HIGH_INTENSITY_INTERVAL_TRAINING': ('HIIT', Icons.bolt),
    'JUMP_ROPE': ('Corda', Icons.sports_martial_arts),
    'YOGA': ('Yoga', Icons.self_improvement),
    'PILATES': ('Pilates', Icons.self_improvement),
    'TAI_CHI': ('Tai chi', Icons.self_improvement),
    'FLEXIBILITY': ('Stretching', Icons.self_improvement),
    'MIND_AND_BODY': ('Mind & body', Icons.self_improvement),
    'BARRE': ('Sbarra', Icons.self_improvement),
    'CARDIO_DANCE': ('Danza cardio', Icons.music_note),
    'DANCING': ('Ballo', Icons.music_note),
    'SOCIAL_DANCE': ('Ballo', Icons.music_note),
    'MIXED_CARDIO': ('Cardio misto', Icons.favorite),
    'GYMNASTICS': ('Ginnastica', Icons.accessibility_new),
    'COOLDOWN': ('Defaticamento', Icons.ac_unit),
    'PREPARATION_AND_RECOVERY': ('Riscaldamento', Icons.whatshot),

    // ── Combattimento ───────────────────────────────────────────────────
    'BOXING': ('Boxe', Icons.sports_mma),
    'KICKBOXING': ('Kickboxing', Icons.sports_mma),
    'MARTIAL_ARTS': ('Arti marziali', Icons.sports_mma),
    'WRESTLING': ('Lotta', Icons.sports_mma),
    'FENCING': ('Scherma', Icons.sports_mma),

    // ── Sport di squadra e racchetta ────────────────────────────────────
    'SOCCER': ('Calcio', Icons.sports_soccer),
    'BASKETBALL': ('Basket', Icons.sports_basketball),
    'VOLLEYBALL': ('Pallavolo', Icons.sports_volleyball),
    'TENNIS': ('Tennis', Icons.sports_tennis),
    'TABLE_TENNIS': ('Ping pong', Icons.sports_tennis),
    'PADDLE_SPORTS': ('Padel', Icons.sports_tennis),
    'PICKLEBALL': ('Pickleball', Icons.sports_tennis),
    'SQUASH': ('Squash', Icons.sports_tennis),
    'BADMINTON': ('Badminton', Icons.sports_tennis),
    'RUGBY': ('Rugby', Icons.sports_rugby),
    'HANDBALL': ('Pallamano', Icons.sports_handball),
    'BASEBALL': ('Baseball', Icons.sports_baseball),
    'HOCKEY': ('Hockey', Icons.sports_hockey),
    'GOLF': ('Golf', Icons.sports_golf),

    // ── Montagna e neve ─────────────────────────────────────────────────
    'CLIMBING': ('Arrampicata', Icons.terrain),
    'ROCK_CLIMBING': ('Arrampicata', Icons.terrain),
    'DOWNHILL_SKIING': ('Sci', Icons.downhill_skiing),
    'CROSS_COUNTRY_SKIING': ('Sci di fondo', Icons.downhill_skiing),
    'SKIING': ('Sci', Icons.downhill_skiing),
    'SNOWBOARDING': ('Snowboard', Icons.snowboarding),
    'SNOWSHOEING': ('Ciaspole', Icons.snowshoeing),
    'ICE_SKATING': ('Pattinaggio', Icons.ice_skating),
    'SKATING': ('Pattinaggio', Icons.ice_skating),

    // ── Il generico dichiarato ──────────────────────────────────────────
    'OTHER': ('Allenamento', Icons.fitness_center),
    'WORKOUT': ('Allenamento', Icons.fitness_center),
  };

  /// 🚨 Gli esiti di elettrocardiogramma che il pacchetto tiene nello **stesso**
  /// enum degli allenamenti. Non sono attività fisica e non devono entrare nello
  /// storico: un «Fibrillazione atriale · 0 kcal» fra le sedute sarebbe insieme
  /// assurdo e allarmante.
  static const _nonSonoAllenamenti = <String>{
    'SINUS_RHYTHM',
    'ATRIAL_FIBRILLATION',
    'INCONCLUSIVE_LOW_HEART_RATE',
    'INCONCLUSIVE_HIGH_HEART_RATE',
    'INCONCLUSIVE_POOR_READING',
    'INCONCLUSIVE_OTHER',
    'NOT_SET',
    'UNRECOGNIZED',
  };

  /// Se questo codice è un allenamento, o una cosa che ci somiglia solo perché
  /// il pacchetto la tiene nella stessa lista.
  static bool eUnAllenamento(String codice) =>
      !_nonSonoAllenamenti.contains(codice.toUpperCase());

  /// Il tipo, tradotto se lo conosciamo e reso leggibile se no.
  static TipoAllenamento da(String codice) {
    final chiave = codice.toUpperCase();
    final tradotto = _tradotti[chiave];

    if (tradotto != null) {
      return TipoAllenamento(
        codice: chiave,
        nome: tradotto.$1,
        icona: tradotto.$2,
      );
    }

    return TipoAllenamento(
      codice: chiave,
      nome: _leggibile(chiave),
      icona: Icons.fitness_center,
    );
  }

  /// `DISC_SPORTS` → `Disc sports`.
  ///
  /// 💡 Non è italiano, ed è comunque meglio di `DISC_SPORTS`: chi fa quello
  /// sport lo riconosce, e chi non lo fa non lo vedrà mai. ⚠️ L'alternativa —
  /// scrivere «Allenamento» per tutto ciò che non è tradotto — perderebbe
  /// l'unica informazione che quel record porta.
  static String _leggibile(String codice) {
    final parole = codice.toLowerCase().replaceAll('_', ' ').trim();

    if (parole.isEmpty) return 'Allenamento';

    return parole[0].toUpperCase() + parole.substring(1);
  }
}
