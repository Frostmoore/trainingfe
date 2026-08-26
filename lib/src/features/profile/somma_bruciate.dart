import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/modello_calorie.dart';
import 'livello_attivita.dart';

/// Se le calorie bruciate si sommano all'obiettivo — 3b-P.2.1, 22/08/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// Il committente: *«Ci voglio un toggle per decidere se le calorie bruciate si
/// sommano all'obbiettivo calorico o no (default sì)»*.
///
/// ── 💡 Perché qualcuno vorrebbe spegnerlo ────────────────────────────────
///
/// La regola di prodotto del 09/08/2026 è *«chi si allena può mangiare di
/// più»*, e per la maggior parte delle persone è quella giusta. ⚠️ Ma sono due
/// scuole diverse, e nessuna delle due è sbagliata:
///
/// | Acceso | Spento |
/// |---|---|
/// | L'obiettivo **respira** con la giornata: ti muovi di più, mangi di più | L'obiettivo è **un numero fisso**, e il movimento è il margine che fa dimagrire |
///
/// 🚨 **Acceso di default perché è la regola su cui è tarato tutto il resto**:
/// il TDEE, la stima del peso, le frasi del consiglio. ⛔ Chi lo spegne sceglie
/// consapevolmente, chi non ci pensa resta dov'era — che è il verso giusto per
/// un'impostazione che cambia un numero già visto.
///
/// ── ⚠️ Sta in `LocalCache`, e finisce nel backup ─────────────────────────
///
/// 🚨 **Diversamente da quello che dicevano i commenti fino al 22/08**:
/// `LocalCache` è `SharedPreferences`, e `PreferenzeNelBackup` le **enumera
/// tutte**. Quindi questa preferenza viaggia con la copia di sicurezza **da
/// sola**, senza che nessuno la aggiunga a un elenco.
///
/// 💡 Ed è la proprietà giusta: è una scelta della persona, non lo stato di uno
/// schermo. Chi cambia telefono se la ritrova, e non ricomincia da un obiettivo
/// che si comporta diversamente da come l'aveva lasciato.
class SommaLeBruciate extends Notifier<bool> {
  static const chiave = 'obiettivo.somma_bruciate';

  /// ⛔ **Il default è `true` e va letto così anche quando la chiave manca.**
  /// 🚨 `getBool() ?? false` sarebbe stato il ripiego naturale, e avrebbe
  /// spento la somma a **tutti** quelli che non hanno mai toccato
  /// l'interruttore — cioè tutti: un obiettivo più basso, plausibile, senza
  /// nessun errore da nessuna parte.
  static const acceso = true;

  /// ══ 🚨 DAL 26/08 NON E' PIU' UNA PREFERENZA LIBERA — 3b-G.1 ═════════════
  ///
  /// 📌 Il committente, alla domanda se l'interruttore dovesse diventare una
  /// conseguenza del modello: *«Ovviamente sì, è una conseguenza»*.
  ///
  /// ⛔ **Il difetto che questo chiude.** Prima si poteva stare sul livello
  /// «moderato» — che *dichiara* 3-4 allenamenti a settimana — **e** avere la
  /// somma accesa: gli allenamenti finivano nell'obiettivo due volte, una dentro
  /// il fattore e una dall'orologio. 🚨 Non era un errore di calcolo: erano
  /// **due scelte che devono muoversi insieme, lasciate indipendenti**.
  ///
  /// | Modello scelto | Si somma? |
  /// |---|---|
  /// | `misurata` — «registro ogni allenamento» | ✅ sempre: è il modello |
  /// | `stima` — «stimalo tu» | ⛔ mai: sono già dentro il fattore |
  /// | **nessuno**, non ha ancora risposto | la preferenza di prima |
  ///
  /// ⚠️ **L'ultima riga è deliberata.** Finché la persona non ha risposto alla
  /// domanda nuova, l'obiettivo non deve muoversi di un chilocaloria: un numero
  /// che cambia da solo prima che tu abbia scelto è peggio di un numero vecchio.
  ///
  /// 💡 Guarda la scelta **locale** e non il livello in uso, di proposito: chi
  /// ha ereditato `moderate` dal server ha un livello, ma non ha ancora deciso
  /// con quale modello vuole che l'app conti.
  @override
  bool build() {
    final preferenza = ref.watch(localCacheProvider).getBool(chiave) ?? acceso;
    final modello = modelloDelLivello(ref.watch(livelloAttivitaSceltoProvider));

    if (modello == null) return preferenza;

    return modello.sommaGliAllenamenti;
  }
}

final sommaLeBruciateProvider = NotifierProvider<SommaLeBruciate, bool>(
  SommaLeBruciate.new,
);
