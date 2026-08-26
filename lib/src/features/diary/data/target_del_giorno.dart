import 'package:flutter/foundation.dart';

/// L'obiettivo calorico di **oggi**, bruciate comprese — N23.B1.
///
/// ── 🚨 Il difetto che questa classe esiste per chiudere ───────────────────
///
/// *«se aggiungo quante calorie ho bruciato nella scheda cibo, queste non
/// appaiono da nessuna parte, né nell'header della scheda oggi, né nel target
/// calorico odierno»* — il committente, 19/08/2026. **Misurato, ed era vero.**
///
/// La somma esisteva, ma solo sul server (`DiaryService::targetsFor()`), e dopo
/// **D9-bis** il server non conosce più il peso: senza peso non c'è BMR, senza
/// BMR non c'è TDEE, e `targets` torna **`null`** a chiunque non abbia un piano
/// alimentare assegnato da un trainer. L'app cadeva sul calcolo locale — che le
/// bruciate non le guardava affatto.
///
/// 💡 Risultato: il ramo «+ bruciate» girava per davvero e non arrivava a
/// nessuno schermo, tranne che ai pochi con un piano del trainer.
///
/// ── 🚨 Perché la somma sta QUI e non nelle tre schermate ──────────────────
///
/// Perché le schermate che mostrano un obiettivo calorico sono **tre**
/// (`macro_summary`, `today_cards`, `today_header`) e la regola è una sola.
/// ⚠️ Scritta tre volte, il giorno che cambia se ne aggiorna due — e la terza
/// mostra un numero diverso dalle altre nella stessa app, che è il modo più
/// rapido per far smettere qualcuno di fidarsi di tutti e tre.
@immutable
class TargetDelGiorno {
  const TargetDelGiorno._({required this.kcal, required this.bruciateIncluse});

  /// 🚨 **Il numero da mostrare.** `null` vuol dire «non lo so», e va detto —
  /// non si inventa: qualcuno ci costruirebbe sopra una dieta.
  final double? kcal;

  /// Se in [kcal] le bruciate ci sono già dentro.
  ///
  /// 💡 Serve all'interfaccia per **spiegare** un numero più alto del solito:
  /// «2.100 kcal, di cui 450 bruciate oggi». Senza, chi vede l'obiettivo salire
  /// non ha nessun modo di capire perché.
  final bool bruciateIncluse;

  bool get esiste => kcal != null && kcal! > 0;

  /// Sceglie la fonte e, se serve, somma.
  ///
  /// ── 🚨 La precedenza, che è quella di sempre (D8) ─────────────────────
  ///
  /// | Fonte | Bruciate |
  /// |---|---|
  /// | **Piano del trainer** (dal server) | 🚨 si sommano **qui** — vedi sotto |
  /// | Calcolo locale | 🚨 si sommano **qui** |
  /// | Niente | `null` |
  ///
  /// ══ 🚨 IL PRIMO RAMO È CAMBIATO — FASE 11.5, 21/08/2026 ═══════════════
  ///
  /// ⚠️ Fino a `v8.4.1` il server mandava `kcal_base + bruciate` già sommate, e
  /// **risommarle qui avrebbe dato il doppio del margine**. Era il caso che si
  /// sbagliava, ed era documentato come tale.
  ///
  /// 🚨 **Adesso è l'opposto**: dopo il trasloco il server le sedute non ce le
  /// ha più, quindi manda il target del piano **e basta**. Non sommarle qui
  /// vorrebbe dire che chi ha un trainer **perde il margine dell'allenamento** —
  /// un numero più basso, plausibile, e nessun errore da nessuna parte.
  ///
  /// 💡 Il risultato è più semplice di prima: la somma si fa **sempre qui**, e
  /// in nessun altro posto. Il doppio conteggio non è più possibile perché non
  /// c'è più nessun altro che possa sommare.
  /// [sommaLeBruciate] — 3b-P.2.2, 22/08/2026.
  ///
  /// 📌 *«Ci voglio un toggle per decidere se le calorie bruciate si sommano
  /// all'obbiettivo calorico o no (default sì)»*.
  ///
  /// 🚨 **Obbligatorio di proposito, e non con un default a `true`.** Un valore
  /// di ripiego qui vorrebbe dire che un chiamante nuovo somma le bruciate
  /// **ignorando la scelta della persona**, e lo farebbe senza errori: un
  /// obiettivo più alto del dovuto, plausibile, in una sola delle quattro
  /// schermate che lo mostrano. ⛔ È la stessa famiglia di O.D.15 e O.D.20 —
  /// due numeri per la stessa cosa — e l'unico modo di renderla impossibile è
  /// **non far compilare** chi se ne dimentica.
  /// [bruciateExtra] — 3b-G.7, 26/08/2026.
  ///
  /// 🚨 **Si sommano SEMPRE, anche quando [sommaLeBruciate] è falso**, ed è
  /// tutto il punto: nel modello «stima» gli allenamenti normali stanno già
  /// dentro il fattore di attività, ma quello fuori dal solito no.
  ///
  /// ⛔ **Obbligatorio, e non con un valore di serie a zero.** Un `= 0` avrebbe
  /// fatto compilare chi se ne dimentica, e il risultato sarebbe stato la mezza
  /// maratona che non alza l'obiettivo **in una sola** delle schermate che lo
  /// mostrano. È la stessa ragione per cui [sommaLeBruciate] è obbligatorio.
  ///
  /// ⚠️ Chi lo passa deve leggerlo da `bruciateExtraDelGiornoProvider`, che vale
  /// **zero** fuori dal modello «stima»: passare il totale grezzo qui
  /// raddoppierebbe le sedute marcate per chi sta su «misurata».
  factory TargetDelGiorno.scegli({
    required double? dalServer,
    required double? locale,
    required int bruciate,
    required bool sommaLeBruciate,
    required int bruciateExtra,
  }) {
    /*
     * 💡 Si azzera **qui**, in un punto solo, invece di chiedere a ogni
     * chiamante di passare `0`. ⚠️ Chiedere a loro vorrebbe dire quattro posti
     * che possono sbagliare, e un quinto che nascerà domani.
     */
    if (!sommaLeBruciate) bruciate = 0;

    /*
     * 🏃 **Le sedute fuori dal solito si sommano comunque** — 3b-G.7.
     *
     * 🚨 Dopo l'azzeramento e non prima: nel modello «stima» `sommaLeBruciate`
     * e' falso, e sommarle prima le farebbe sparire insieme alle altre — cioe'
     * la funzione non farebbe niente proprio nel modello per cui esiste.
     */
    bruciate += bruciateExtra;

    if (dalServer != null && dalServer > 0) {
      return TargetDelGiorno._(
        kcal: dalServer + bruciate,
        bruciateIncluse: bruciate > 0,
      );
    }

    if (locale == null || locale <= 0) {
      return const TargetDelGiorno._(kcal: null, bruciateIncluse: false);
    }

    /*
     * 🚨 **Qui la somma, e in nessun altro posto.**
     *
     * È la regola di prodotto scritta il 09/08/2026: *«il target del giorno =
     * target base + calorie bruciate. Chi si allena può mangiare di più»*. Fino
     * a oggi valeva solo per chi aveva un piano del trainer, perché era
     * l'unico ramo che arrivava allo schermo.
     */
    return TargetDelGiorno._(
      kcal: locale + bruciate,
      bruciateIncluse: bruciate > 0,
    );
  }
}
