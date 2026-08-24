/// Quali muscoli hai allenato, e quanto — 3b-A.6, 24/08/2026.
///
/// ══ 🚨 IL CALCOLO STA QUI, NON NEL DISEGNO ════════════════════════════════
///
/// 📌 Il committente: *«un'immagine di un uomo in cui i muscoli e i gruppi
/// muscolari più allenati hanno un colore rosso più intenso»* e *«un grafico a
/// stella con tutti i gruppi muscolari»*.
///
/// 💡 **Due disegni, un conto solo.** La figura del corpo e la stella dicono la
/// stessa cosa in due modi: se il conto stesse dentro i widget, il giorno che
/// cambia il peso di un secondario ne cambierebbe uno solo — e le due card
/// direbbero cose diverse nella stessa schermata, una accanto all'altra.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/catalogo_esercizi.dart';
import 'data/gruppo_muscolare.dart';
import 'data/storico_unificato.dart';
import 'storico_unificato_controller.dart';

/// I muscoli che un allenamento dell'orologio ha mosso.
///
/// ══ ⚠️ L'OROLOGIO DICE **COSA**, NON **QUALI ESERCIZI** ════════════════════
///
/// 🚨 Una seduta registrata nell'app ha le serie, quindi si sa esercizio per
/// esercizio cosa hai allenato. Una corsa letta dall'orologio dice «RUNNING» e
/// basta: la precisione che si può avere è quella di una **categoria**.
///
/// ⛔ E ignorarla non era un'opzione: chi corre e basta — che è tantissima
/// gente — avrebbe visto una figura **tutta grigia**, cioè l'app che gli dice
/// che non ha allenato niente. È lo stesso errore di trattare `cardio` come un
/// muscolo, visto dall'altro lato.
///
/// 💡 **Peso uguale per tutti i muscoli di un tipo**, e non è pigrizia: in una
/// corsa non c'è un «muscolo principale» nel senso in cui c'è in una panca, e
/// inventarne uno sarebbe una precisione finta.
///
/// ⚠️ Quello che non è in tabella **non colora niente**, di proposito: meglio
/// una figura che tace su uno sport strano che una che indovina.
class MuscoliDelTipo {
  const MuscoliDelTipo._();

  static const _mappa = <String, List<GruppoMuscolare>>{
    // ── Correre e camminare ─────────────────────────────────────────────
    'RUNNING': _gambe,
    'RUNNING_TREADMILL': _gambe,
    'WALKING': _gambeLeggere,
    'WALKING_TREADMILL': _gambeLeggere,
    'HIKING': _gambe,
    'STAIR_CLIMBING': _gambe,
    'STAIRS': _gambe,
    'STAIR_CLIMBING_MACHINE': _gambe,
    'STEP_TRAINING': _gambe,

    // ── Pedalare ────────────────────────────────────────────────────────
    'BIKING': _pedalata,
    'BIKING_STATIONARY': _pedalata,
    'ELLIPTICAL': _pedalata,

    // ── Acqua e remi ────────────────────────────────────────────────────
    'SWIMMING': _nuoto,
    'SWIMMING_POOL': _nuoto,
    'SWIMMING_OPEN_WATER': _nuoto,
    'ROWING': _remata,
    'ROWING_MACHINE': _remata,

    // ── Pesi e corpo libero ─────────────────────────────────────────────
    //
    // ⚠️ `full_body` non è un muscolo (vedi `eUnMuscolo`), quindi qui si
    // elencano le zone vere: una figura non si colora con «tutto il corpo».
    'STRENGTH_TRAINING': _tuttoIlCorpo,
    'TRADITIONAL_STRENGTH_TRAINING': _tuttoIlCorpo,
    'WEIGHTLIFTING': _tuttoIlCorpo,
    'FUNCTIONAL_STRENGTH_TRAINING': _tuttoIlCorpo,
    'CROSS_TRAINING': _tuttoIlCorpo,
    'CALISTHENICS': _tuttoIlCorpo,
    'HIGH_INTENSITY_INTERVAL_TRAINING': _tuttoIlCorpo,

    // ── Il resto ────────────────────────────────────────────────────────
    'CORE_TRAINING': [GruppoMuscolare.addome],
    'JUMP_ROPE': [GruppoMuscolare.polpacci, GruppoMuscolare.spalle],
    'BOXING': [
      GruppoMuscolare.spalle,
      GruppoMuscolare.addome,
      GruppoMuscolare.schiena,
    ],
    'KICKBOXING': [
      GruppoMuscolare.spalle,
      GruppoMuscolare.addome,
      GruppoMuscolare.quadricipiti,
    ],
  };

  static const _gambe = [
    GruppoMuscolare.quadricipiti,
    GruppoMuscolare.femorali,
    GruppoMuscolare.polpacci,
    GruppoMuscolare.glutei,
  ];

  static const _gambeLeggere = [
    GruppoMuscolare.quadricipiti,
    GruppoMuscolare.polpacci,
  ];

  static const _pedalata = [
    GruppoMuscolare.quadricipiti,
    GruppoMuscolare.glutei,
    GruppoMuscolare.polpacci,
  ];

  static const _nuoto = [
    GruppoMuscolare.schiena,
    GruppoMuscolare.spalle,
    GruppoMuscolare.petto,
  ];

  static const _remata = [
    GruppoMuscolare.schiena,
    GruppoMuscolare.bicipiti,
    GruppoMuscolare.quadricipiti,
    GruppoMuscolare.spalle,
  ];

  /// ══ 🚨 «TUTTO IL CORPO» VUOL DIRE TUTTO — difetto del 24/08/2026 ═══════
  ///
  /// 📌 Il committente: *«Non mi ha segnato i bicipiti, quando effettivamente
  /// ne ho fatti un bel po'»*.
  ///
  /// ⛔ **Aveva ragione, e la causa era qui.** Questo elenco conteneva cinque
  /// gruppi — petto, schiena, spalle, quadricipiti, addome — e **le braccia
  /// no**. Un allenamento di pesi letto dall'orologio si chiama
  /// `STRENGTH_TRAINING` e basta: l'app coloriva quei cinque e taceva su
  /// bicipiti e tricipiti, **sempre**, qualunque cosa avessi fatto.
  ///
  /// 🚨 Il danno era peggiore di una zona spenta: era una figura che sembrava
  /// informata. Chi la guardava concludeva «le braccia non le alleno», che è
  /// una cosa **falsa** detta con l'aria di saperla.
  ///
  /// 💡 Adesso ci sono tutte le zone, con lo stesso peso. ⚠️ Non è precisione —
  /// l'orologio non sa cosa hai fatto — ma è **onesto**: «pesi» vuol dire tutto
  /// il corpo, e nessuna zona viene esclusa da una scelta che nessuno ha preso.
  static const _tuttoIlCorpo = [
    GruppoMuscolare.petto,
    GruppoMuscolare.schiena,
    GruppoMuscolare.spalle,
    GruppoMuscolare.bicipiti,
    GruppoMuscolare.tricipiti,
    GruppoMuscolare.addome,
    GruppoMuscolare.quadricipiti,
    GruppoMuscolare.femorali,
    GruppoMuscolare.glutei,
  ];

  static List<GruppoMuscolare> di(String codice) =>
      _mappa[codice.toUpperCase()] ?? const [];
}

/// Quanto ogni zona è stata allenata, da 0 a 1.
///
/// ── 🚨 Il punteggio, e perché è il **tempo** e non il numero di serie ─────
///
/// ⛔ Contare le serie metterebbe sullo stesso piano dieci serie di alzate
/// laterali e dieci di squat. ⚠️ Contare i **chili** escluderebbe la corsa, che
/// di chili non ne ha nessuno.
///
/// 💡 Il **minutaggio** è l'unica unità che tutte e due le provenienze hanno:
/// una seduta dura, una corsa dura. Ogni allenamento distribuisce i suoi minuti
/// sui muscoli che ha mosso, con i pesi di `muscoliConPeso` quando li conosce.
///
/// ── ⚠️ E il risultato è **relativo**, non assoluto ────────────────────────
///
/// 🚨 Il massimo vale sempre 1: la figura dice **cosa hai allenato di più**,
/// non «quanto è tanto». ⛔ Una scala assoluta avrebbe voluto dire scegliere
/// quanti minuti sono «rosso pieno» — un numero inventato che nessuno può
/// difendere, e che sarebbe sbagliato per chiunque non si alleni come chi l'ha
/// scelto.
Map<GruppoMuscolare, double> intensitaDeiMuscoli({
  required Iterable<VoceStorico> voci,
  required CatalogoEsercizi catalogo,
}) {
  final grezzi = <GruppoMuscolare, double>{};

  void aggiungi(GruppoMuscolare m, double quanto) {
    if (!m.eUnMuscolo || quanto <= 0) return;

    grezzi[m] = (grezzi[m] ?? 0) + quanto;
  }

  for (final v in voci) {
    // ── Le serie registrate nell'app: si sa esercizio per esercizio ──────
    for (final seduta in v.sedute) {
      /*
       * 💡 I minuti della seduta si dividono fra le serie: venti serie in
       * un'ora sono tre minuti l'una. ⚠️ Non è il tempo vero di quella serie —
       * quello nessuno lo misura — ma è la ripartizione che rispetta sia la
       * durata sia quanto lavoro c'è dentro.
       */
      if (seduta.sets.isEmpty) continue;

      final minuti = (seduta.durationMinutes ?? 0).toDouble();

      if (minuti <= 0) continue;

      final perSerie = minuti / seduta.sets.length;

      for (final serie in seduta.sets) {
        final esercizio =
            catalogo.perId(serie.exerciseId) ??
            catalogo.perNome(serie.exerciseName);

        if (esercizio == null) continue;

        esercizio.muscoliConPeso.forEach(
          (muscolo, peso) => aggiungi(muscolo, perSerie * peso),
        );
      }
    }

    /*
     * ══ 🚨 SE L'APP SA GLI ESERCIZI, L'OROLOGIO NON INDOVINA ══════════════
     *
     * ⛔ Prima i due contributi si **sommavano**: una seduta registrata
     * esercizio per esercizio prendeva anche la spalmata generica del suo
     * gemello dall'orologio. Risultato, il dato preciso veniva annacquato da
     * quello approssimato — e chi si prende la briga di registrare le serie
     * otteneva una figura **peggiore** di quella che meritava.
     *
     * 💡 Il gruppo che ha delle serie dice gia' tutto: l'orologio, li', serve
     * per le calorie e la durata, non per i muscoli.
     */
    final conSerie = v.sedute.any((s) => s.sets.isNotEmpty);

    if (conSerie) continue;

    // ── Quello che ha visto l'orologio ───────────────────────────────────
    for (final a in v.dalPolso) {
      final muscoli = MuscoliDelTipo.di(a.tipo);

      if (muscoli.isEmpty) continue;

      final minuti = a.finitoIl.difference(a.iniziatoIl).inMinutes.toDouble();

      if (minuti <= 0) continue;

      /*
       * ⚠️ **I minuti si dividono, non si moltiplicano.** Un'ora di corsa è
       * un'ora, che i muscoli coinvolti siano due o quattro: assegnarne una
       * intera a ognuno farebbe valere una corsa il quadruplo di una seduta di
       * pesi della stessa durata.
       */
      final perMuscolo = minuti / muscoli.length;

      for (final m in muscoli) {
        aggiungi(m, perMuscolo);
      }
    }
  }

  if (grezzi.isEmpty) return const {};

  final massimo = grezzi.values.reduce((a, b) => a > b ? a : b);

  return {
    for (final e in grezzi.entries) e.key: (e.value / massimo).clamp(0.0, 1.0),
  };
}

/// I muscoli allenati **nel mese** di una data.
///
/// ⚠️ **Il mese e non la settimana**, anche se l'intestazione naviga per
/// settimane: una settimana sola dice poco di come ti alleni — chi fa un
/// «giorno gambe» avrebbe la figura mezza spenta il martedì e mezza accesa il
/// giovedì. 💡 Il mese è anche il periodo delle altre due card del carosello e
/// del calendario sotto, quindi il blocco in cima parla di **una cosa sola**.
final muscoliDelMeseProvider =
    Provider.family<Map<GruppoMuscolare, double>, DateTime>((ref, mese) {
      final voci = ref.watch(storicoUnificatoProvider).valueOrNull ?? const [];
      final catalogo =
          ref.watch(catalogoEserciziProvider).valueOrNull ??
          CatalogoEsercizi.vuoto;

      return intensitaDeiMuscoli(
        voci: voci.where(
          (v) => v.quando.year == mese.year && v.quando.month == mese.month,
        ),
        catalogo: catalogo,
      );
    });
