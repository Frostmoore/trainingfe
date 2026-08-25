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
/// ══ 🚨 DUE CONDIZIONI DIVERSE, E NON VANNO CONFUSE ════════════════════════
///
/// 📌 *«ovviamente AI illimitata e abbonato sono due cose diverse, non va bene
/// che siano trattati come una cosa singola»*.
///
/// ⛔ **Le avevo trattate come una sola**, appoggiandomi al fatto che oggi
/// l'abbonamento concede la quota illimitata. È un'osservazione sul presente,
/// non una definizione: il giorno in cui si vendesse un pacchetto AI senza
/// abbonamento — o un abbonamento senza AI — quella riga avrebbe sbagliato in
/// silenzio, e nessun test se ne sarebbe accorto perché il test l'avrebbe
/// scritta uguale.
///
/// 💡 Adesso sono **due parametri**, e la regola è: *«chi è abbonato **o** chi ha
/// AI illimitata»* non ha il limite. **Ne basta una.**
///
/// ⛔ **L'avevo letta al contrario**, come «servono tutte e due», e il risultato
/// era che chi ha l'AI illimitata per un interruttore acceso a mano — senza
/// abbonamento — si vedeva le schede bloccate lo stesso. 🚨 Le due condizioni
/// sono **due porte d'ingresso allo stesso privilegio**, non due lucchetti sulla
/// stessa porta.
///
/// ══ ⚠️ E CIASCUNA, SE NON SI SA, NON BLOCCA ══════════════════════════════
///
/// I flag arrivano dalla rete, e un errore lì non deve nascondere le schede a
/// chi le ha pagate: ⛔ meglio un limite che non scatta che un abbonato chiuso
/// fuori dai propri allenamenti. Per questo sono `bool?`, e `null` vale «questa
/// condizione lasciala stare».
///
/// ⏳ **Oggi `abbonato` arriva sempre `null`**, perché il server non lo manda:
/// `/me` non espone niente sull'abbonamento, e l'unica cosa che ci somiglia è lo
/// stato del *tenant*, che è la palestra e non la persona. 🚨 Finché non c'è,
/// blocca solo `illimitata` — ed è dichiarato qui invece che nascosto in un
/// `?? true` da qualche parte.
Map<int, MotivoBlocco> schedeBloccate({
  required List<WorkoutPlan> schede,
  required bool? abbonato,
  required bool? illimitata,
}) {
  /*
   * 🚨 **Si blocca solo quando sono false TUTTE E DUE.** `!= false` e non
   * `== true`: `null` vuol dire «non lo so», e un flag che non è arrivato non
   * deve chiudere fuori nessuno — vale come una porta aperta, non come una
   * chiusa.
   */
  final senzaLimiti = illimitata != false || abbonato != false;

  if (senzaLimiti) return const {};

  final bloccate = <int, MotivoBlocco>{};

  /*
   * ⚠️ **Le più recenti per data di CREAZIONE**, che non è l'ordine in cui
   * arrivano: `schedeUniteProvider` le ordina per ultima modifica, e rinominare
   * una scheda vecchia la porterebbe in cima scavalcando una nuova. 💡 Chi
   * chiama passa già l'elenco nell'ordine giusto — vedi `schedePerCreazione`.
   */
  var contate = 0;

  for (final scheda in schede) {
    /*
     * ══ 🚨 IL POSTO LO OCCUPA COMUNQUE — corretto dal committente il 25/08 ══
     *
     * 📌 *«Una scheda a più giorni certo che occupa uno slot scheda. In realtà è
     * un deficit piccolo, un utente può sempre crearsi una scheda a giorno
     * singolo finché non arriva a tre. Quelle multiday sono bloccate se non sei
     * iscritto»*.
     *
     * ⛔ **Avevo fatto il contrario**: le multi-giorno saltavano il conteggio,
     * col ragionamento che un posto non va sprecato per una scheda inutilizzabile.
     * 🚨 Sbagliato, e per un motivo semplice: **il limite conta le schede che
     * hai, non quelle che puoi usare**. Saltarle vorrebbe dire che chi ne
     * accumula dieci a più giorni ha ancora tutti e tre i posti liberi — cioè
     * che una scheda in più non costa niente finché è multi-giorno.
     *
     * 💡 Il «deficit» che ne esce è dichiarato e accettato: chi riempie i tre
     * posti di schede a più giorni resta senza schede usabili finché non ne
     * cancella una. ⚠️ Se ne accorge subito, perché il perché c'è scritto sotto
     * ognuna.
     */
    contate++;

    if (contate > quanteSenzaAbbonamento) {
      bloccate[scheda.id] = MotivoBlocco.troppeSchede;
      continue;
    }

    // 💡 Dentro i tre posti, ma a più giorni: si dice **quello**, che è il
    // motivo vero per cui questa non si apre.
    if (scheda.giorni > 1) bloccate[scheda.id] = MotivoBlocco.piuGiorni;
  }

  return bloccate;
}
