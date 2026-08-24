/// Il tipo che **dichiari tu** per un allenamento del polso — 3b-B.20.5.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«nel caso di allenamenti con l'orologio voglio poterci assegnare anche un
/// tipo di allenamento diverso dalla scheda. Tipo corsa, bicicletta, nuoto, ste
/// cose qui, in modo che possa stimare i muscoli coinvolti e le calorie tanto
/// le facciamo con una formula»*.
///
/// ══ 🚨 E NON CONTRADDICE B.9 — VA LETTO BENE ══════════════════════════════
///
/// Il 24/08 il committente aveva corretto una nostra scelta: *«I gruppi
/// muscolari NON arrivano dall'orologio»*. Era stata cancellata `MuscoliDelTipo`,
/// che indovinava i muscoli dal codice che l'orologio scriveva da solo.
///
/// ⚠️ **Quella regola resta, e qui non si tocca**: l'orologio scrive
/// `STRENGTH_TRAINING` e da lì non si deduce niente. 💡 Qui la fonte è
/// **un'altra**: è la persona che dice *«quella era una nuotata»*. Una
/// dichiarazione non è un'ipotesi, e un'app che rifiuta di usare quello che le
/// hai appena detto è un'app che ti fa scrivere per niente.
///
/// ⛔ Da qui la forma del codice: questa tabella si consulta **solo** partendo da
/// `AllenamentoDaOrologio.tipoScelto`, cioè da una colonna che nessun
/// sensore può riempire. Il codice dell'orologio non entra mai da questa porta.
library;

import 'gruppo_muscolare.dart';

/// Uno sport che si può dichiarare, con quello che se ne può dedurre.
class TipoScelto {
  const TipoScelto({
    required this.codice,
    required this.nome,
    required this.met,
    required this.muscoli,
  });

  /// Il codice di Health Connect, così che `TipoAllenamento.da()` sappia già
  /// come chiamarlo e che icona dargli.
  ///
  /// 🚨 **Non si inventa un vocabolario nuovo.** Usare gli stessi codici vuol
  /// dire che l'etichetta e l'icona restano una sola copia, in
  /// `TipoAllenamento`: un elenco parallelo di nomi italiani sarebbe la seconda
  /// lista da tenere allineata, e le seconde liste divergono.
  final String codice;

  /// Il nome corto per il foglio della scelta.
  final String nome;

  /// Il MET, dal Compendium of Physical Activities.
  ///
  /// ⚠️ **Valori da intensità moderata**, non da gara: chi dichiara «corsa» a
  /// mano di solito ha corso, non fatto una maratona a ritmo. 🚨 Sovrastimare le
  /// calorie porta a mangiare di più credendo di essere in deficit — la stessa
  /// prudenza di `CalorieAllenamento.met`.
  final double met;

  /// `gruppo → 0..1`. Quanto quel gruppo lavora in questo sport.
  ///
  /// ⚠️ **Non è una misura, è una ripartizione dichiarata.** Non c'è modo di
  /// sapere quanto ha lavorato il tuo gran dorsale in piscina: qui si dice cosa
  /// quello sport muove, in proporzione, e la figura lo colora di conseguenza.
  final Map<GruppoMuscolare, double> muscoli;

  /// Quelli che si possono scegliere.
  ///
  /// ⛔ **Un elenco corto, e di proposito.** `TipoAllenamento` ne traduce una
  /// sessantina, ma quello serve a **leggere** quello che manda l'orologio; qui
  /// si deve **scegliere**, e sessanta voci in un foglio sono un elenco che
  /// nessuno scorre fino in fondo. 💡 Ci sono gli sport che una persona dichiara
  /// davvero — *«corsa, bicicletta, nuoto, ste cose qui»*.
  static const tutti = <TipoScelto>[
    TipoScelto(
      codice: 'RUNNING',
      nome: 'Corsa',
      met: 9.8,
      muscoli: {
        GruppoMuscolare.quadricipiti: 0.9,
        GruppoMuscolare.femorali: 0.8,
        GruppoMuscolare.polpacci: 1,
        GruppoMuscolare.glutei: 0.7,
        GruppoMuscolare.addome: 0.3,
        GruppoMuscolare.cardio: 1,
      },
    ),
    TipoScelto(
      codice: 'WALKING',
      nome: 'Camminata',
      met: 3.5,
      muscoli: {
        GruppoMuscolare.quadricipiti: 0.5,
        GruppoMuscolare.femorali: 0.4,
        GruppoMuscolare.polpacci: 0.6,
        GruppoMuscolare.glutei: 0.4,
        GruppoMuscolare.cardio: 0.5,
      },
    ),
    TipoScelto(
      codice: 'HIKING',
      nome: 'Escursione',
      met: 6,
      muscoli: {
        GruppoMuscolare.quadricipiti: 0.8,
        GruppoMuscolare.femorali: 0.6,
        GruppoMuscolare.polpacci: 0.8,
        GruppoMuscolare.glutei: 0.7,
        GruppoMuscolare.cardio: 0.7,
      },
    ),
    TipoScelto(
      codice: 'BIKING',
      nome: 'Bici',
      met: 7.5,
      muscoli: {
        GruppoMuscolare.quadricipiti: 1,
        GruppoMuscolare.femorali: 0.6,
        GruppoMuscolare.polpacci: 0.5,
        GruppoMuscolare.glutei: 0.7,
        GruppoMuscolare.cardio: 0.9,
      },
    ),
    TipoScelto(
      codice: 'SWIMMING',
      nome: 'Nuoto',
      met: 7,
      muscoli: {
        GruppoMuscolare.schiena: 0.9,
        GruppoMuscolare.spalle: 1,
        GruppoMuscolare.petto: 0.7,
        GruppoMuscolare.tricipiti: 0.6,
        GruppoMuscolare.addome: 0.6,
        GruppoMuscolare.femorali: 0.4,
        GruppoMuscolare.cardio: 0.9,
      },
    ),
    TipoScelto(
      codice: 'ROWING',
      nome: 'Vogatore',
      met: 7,
      muscoli: {
        GruppoMuscolare.schiena: 1,
        GruppoMuscolare.bicipiti: 0.6,
        GruppoMuscolare.spalle: 0.6,
        GruppoMuscolare.quadricipiti: 0.7,
        GruppoMuscolare.glutei: 0.6,
        GruppoMuscolare.addome: 0.5,
        GruppoMuscolare.cardio: 0.9,
      },
    ),
    TipoScelto(
      codice: 'ELLIPTICAL',
      nome: 'Ellittica',
      met: 5,
      muscoli: {
        GruppoMuscolare.quadricipiti: 0.7,
        GruppoMuscolare.femorali: 0.6,
        GruppoMuscolare.glutei: 0.6,
        GruppoMuscolare.polpacci: 0.5,
        GruppoMuscolare.spalle: 0.3,
        GruppoMuscolare.cardio: 0.8,
      },
    ),
    TipoScelto(
      codice: 'STAIR_CLIMBING',
      nome: 'Scale',
      met: 8.8,
      muscoli: {
        GruppoMuscolare.quadricipiti: 1,
        GruppoMuscolare.glutei: 0.9,
        GruppoMuscolare.polpacci: 0.7,
        GruppoMuscolare.femorali: 0.5,
        GruppoMuscolare.cardio: 0.9,
      },
    ),
    TipoScelto(
      codice: 'JUMP_ROPE',
      nome: 'Corda',
      met: 11,
      muscoli: {
        GruppoMuscolare.polpacci: 1,
        GruppoMuscolare.quadricipiti: 0.6,
        GruppoMuscolare.spalle: 0.4,
        GruppoMuscolare.avambracci: 0.4,
        GruppoMuscolare.cardio: 1,
      },
    ),
    TipoScelto(
      codice: 'HIGH_INTENSITY_INTERVAL_TRAINING',
      nome: 'HIIT',
      met: 8,
      muscoli: {GruppoMuscolare.totale: 0.8, GruppoMuscolare.cardio: 1},
    ),
    TipoScelto(
      codice: 'STRENGTH_TRAINING',
      nome: 'Pesi',
      met: 5,
      muscoli: {GruppoMuscolare.totale: 0.8},
    ),
    TipoScelto(
      codice: 'CALISTHENICS',
      nome: 'Corpo libero',
      met: 3.8,
      muscoli: {GruppoMuscolare.totale: 0.7, GruppoMuscolare.addome: 0.8},
    ),
    TipoScelto(
      codice: 'YOGA',
      nome: 'Yoga',
      met: 2.5,
      muscoli: {
        GruppoMuscolare.addome: 0.5,
        GruppoMuscolare.schiena: 0.4,
        GruppoMuscolare.femorali: 0.4,
      },
    ),
    TipoScelto(
      codice: 'BOXING',
      nome: 'Boxe',
      met: 7.8,
      muscoli: {
        GruppoMuscolare.spalle: 0.9,
        GruppoMuscolare.addome: 0.8,
        GruppoMuscolare.petto: 0.6,
        GruppoMuscolare.avambracci: 0.6,
        GruppoMuscolare.polpacci: 0.5,
        GruppoMuscolare.cardio: 1,
      },
    ),
  ];

  /// Il tipo scelto per un codice, o `null` se quel codice non è scegliibile.
  ///
  /// 🚨 **`null` non è un errore da nascondere**: vuol dire che quel codice
  /// l'ha scritto l'orologio, non una persona. ⛔ Cadere su un tipo di ripiego
  /// vorrebbe dire rimettere in piedi `MuscoliDelTipo` da una porta di servizio,
  /// e colorare la figura con un'ipotesi che il committente ha già rifiutato.
  static TipoScelto? per(String? codice) {
    if (codice == null) return null;

    for (final t in tutti) {
      if (t.codice == codice) return t;
    }

    return null;
  }
}
