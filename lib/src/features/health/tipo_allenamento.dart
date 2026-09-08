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

  // ═══════════════ 🗺️ CHE COSA HA SENSO CHIEDERE — 08/09/2026 ═══════════════
  //
  // 📌 Il committente: *«quando scelgo come esercizio camminata, hiking,
  // bicicletta… vatti a vedere che esercizi accettiamo»*.
  //
  // 🚨 **Sono tre domande diverse, e tenerle separate è il punto.** Un vogatore
  // ha una distanza ma non un percorso; un tapis roulant ha un passo al km ma
  // non una velocità che voglia dire qualcosa fuori; una seduta di pesi non ha
  // niente di tutto questo. ⛔ Una lista sola avrebbe risposto male ad almeno
  // due delle tre.

  /// Se per questo tipo vale la pena **chiedere** il percorso a Health Connect.
  ///
  /// ══ ⚠️ DECIDE QUANDO SI CHIEDE, NON QUANDO SI MOSTRA ══════════════════════
  ///
  /// 🚨 Il percorso si **mostra** ogni volta che c'è, qualunque sia il tipo: se
  /// un orologio strano attacca una traccia a una seduta di pesi, disegnarla è
  /// giusto lo stesso. ⛔ Questa lista serve a decidere **a chi chiederlo**, e
  /// la ragione è concreta: Health Connect dà i percorsi solo con l'app in primo
  /// piano, e chiederli per quindici sedute di pesi vuol dire quindici richieste
  /// che tornano vuote mentre qualcuno guarda lo schermo.
  ///
  /// 💡 `OTHER` c'è di proposito: parecchi orologi ci finiscono dentro quello che
  /// non sanno classificare, e fra quelle cose ci sono uscite vere.
  ///
  /// ⛔ **Fuori i chiusi che somigliano agli aperti**: tapis roulant, cyclette,
  /// vogatore, ellittica, nuoto in piscina. Un percorso non ce l'hanno mai, e
  /// somigliano abbastanza ai loro gemelli all'aperto da farsi includere da
  /// chiunque copi la lista senza leggerla.
  static const _conPercorso = <String>{
    'WALKING',
    'RUNNING',
    'BIKING',
    'HAND_CYCLING',
    'HIKING',
    'SWIMMING_OPEN_WATER',
    'ROWING',
    'SURFING',
    'CLIMBING',
    'ROCK_CLIMBING',
    'DOWNHILL_SKIING',
    'CROSS_COUNTRY_SKIING',
    'SKIING',
    'SNOWBOARDING',
    'SNOWSHOEING',
    'ICE_SKATING',
    'SKATING',
    'OTHER',
  };

  /// Se si va **sulle proprie gambe**, un passo per volta.
  ///
  /// 💡 Da qui dipendono **passo al km**, **cadenza** e **lunghezza del passo**:
  /// tre numeri che in bici non vogliono dire niente. ⚠️ Il tapis roulant c'è —
  /// il percorso no, ma i passi sì, e il passo al km su un tapis roulant è
  /// esattamente il numero che si guarda.
  static const _aPiedi = <String>{
    'WALKING',
    'WALKING_TREADMILL',
    'RUNNING',
    'RUNNING_TREADMILL',
    'HIKING',
    'SNOWSHOEING',
    'STAIR_CLIMBING',
    'STAIRS',
  };

  /// Se una **distanza** ha senso, e quindi anche una velocità media.
  ///
  /// ⚠️ Non è «ha percorso più zero»: una seduta di pesi può avere una distanza
  /// scritta dall'orologio — i passi fatti fra un attrezzo e l'altro — e
  /// mostrarla come «distanza dell'allenamento» direbbe una cosa falsa con un
  /// numero vero.
  /// ⚠️ Solo i tipi **in più** rispetto a [_aPiedi] e [_conPercorso]: sono i
  /// chiusi che una distanza ce l'hanno lo stesso, letta da un rullo o da una
  /// vasca. 🚨 Elencarli tutti in un insieme solo non si può — Dart rifiuta i
  /// doppioni in un `Set` costante — e il rifiuto qui è un servizio: è il
  /// compilatore che impedisce due elenchi che si sovrappongono senza dirlo.
  static const _conDistanzaInPiu = <String>{
    'BIKING_STATIONARY',
    'ROWING_MACHINE',
    'SWIMMING',
    'SWIMMING_POOL',
    'ELLIPTICAL',
  };

  /// Vale la pena chiedere il percorso per questo tipo? Vedi [_conPercorso].
  static bool conPercorso(String codice) =>
      _conPercorso.contains(codice.toUpperCase());

  /// Si va a piedi? Vedi [_aPiedi].
  static bool aPiedi(String codice) => _aPiedi.contains(codice.toUpperCase());

  /// Una distanza ha senso? Vedi [_conDistanzaInPiu].
  static bool conDistanza(String codice) {
    final chiave = codice.toUpperCase();

    return _aPiedi.contains(chiave) ||
        _conPercorso.contains(chiave) ||
        _conDistanzaInPiu.contains(chiave);
  }
}
