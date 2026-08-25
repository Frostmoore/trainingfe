/// Quante schede può avere chi non è abbonato — 3b-C.6, 25/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// *«Bisogna fare in modo che un utente che non sia abbonato o non abbia l'ai
/// illimitata possa avere solamente 3 schede (le ultime 3 per data di
/// creazione, le altre le deve vedere disabilitate, con scritto che senza
/// abbonamento il massimo è 3)»* e *«Le schede di chi non è abbonato … possono
/// essere solo schede a un giorno singolo, le altre devono essere disabilitate
/// con la stessa indicazione»*.
///
/// ══ 🚨 DISABILITATE, NON CANCELLATE ═══════════════════════════════════════
///
/// ⛔ Le schede **restano tutte**: nessuna sparisce, nessuna si cancella. Chi si
/// abbona ritrova quelle che aveva, e chi non si abbona **vede cosa si sta
/// perdendo** — che è il punto di un limite commerciale.
///
/// 🚨 E una scheda mandata dal trainer che sparisce sarebbe un danno vero: quel
/// trainer l'ha scritta per quella persona, e l'app non ha il diritto di
/// buttarla perché è scaduto un abbonamento.
library;

import '../training_controller.dart';

/// Perché una scheda non si può usare.
///
/// ⚠️ Si chiama `MotivoBlocco` e non `PerchéBloccata`: in Dart un identificatore
/// non può contenere una lettera accentata, e l'analizzatore lo rifiuta.
enum MotivoBlocco {
  /// ⛔ Non è fra le tre più recenti.
  troppeSchede('Senza abbonamento puoi usare le 3 schede più recenti.'),

  /// ⛔ Ha più di un giorno.
  piuGiorni(
    'Senza abbonamento puoi usare solo schede di un giorno. '
    'Questa ne ha più di uno.',
  );

  const MotivoBlocco(this.spiegazione);

  /// 💡 **La frase sta qui, non nel widget.** Le schermate che la mostrano sono
  /// due — l'elenco e il dettaglio — e due copie di un messaggio divergono alla
  /// prima correzione.
  final String spiegazione;
}

/// Quante ne può usare chi non è abbonato.
const quanteSenzaAbbonamento = 3;

/// Quali schede sono bloccate, e perché.
///
/// ⚠️ **`illimitata` viene da `Gettoni`**, cioè dalla quota AI. In questo
/// impianto è **la stessa cosa** che essere abbonati: la quota illimitata è ciò
/// che l'abbonamento concede (`MemberAiQuota.remaining()` torna `null`). 🚨 Se un
/// giorno le due cose si separassero, questo è il punto in cui aggiungere il
/// secondo controllo — non nei widget.
///
/// 🚨 **Se non si sa, non si blocca niente.** Il flag arriva dalla rete, e un
/// errore di rete non deve nascondere le schede a chi le ha pagate: ⛔ meglio un
/// limite che non scatta che un abbonato chiuso fuori dai propri allenamenti.
/// Per questo `illimitata` è un `bool?` e `null` vale «lascia stare».
Map<int, MotivoBlocco> schedeBloccate({
  required List<WorkoutPlan> schede,
  required bool? illimitata,
}) {
  if (illimitata != false) return const {};

  final bloccate = <int, MotivoBlocco>{};

  /*
   * ⚠️ **Le più recenti per data di CREAZIONE**, che non è l'ordine in cui
   * arrivano: `schedeUniteProvider` le ordina per ultima modifica, e rinominare
   * una scheda vecchia la porterebbe in cima scavalcando una nuova. 💡 Chi
   * chiama passa già l'elenco nell'ordine giusto — vedi `schedePerCreazione`.
   */
  var usabili = 0;

  for (final scheda in schede) {
    /*
     * 🚨 **Il limite dei giorni si controlla PRIMA di contare.** Una scheda a
     * più giorni è bloccata comunque: farla occupare uno dei tre posti vorrebbe
     * dire togliere un posto usabile per una scheda che comunque non si può
     * usare.
     */
    if (scheda.giorni > 1) {
      bloccate[scheda.id] = MotivoBlocco.piuGiorni;
      continue;
    }

    if (usabili >= quanteSenzaAbbonamento) {
      bloccate[scheda.id] = MotivoBlocco.troppeSchede;
      continue;
    }

    usabili++;
  }

  return bloccate;
}
