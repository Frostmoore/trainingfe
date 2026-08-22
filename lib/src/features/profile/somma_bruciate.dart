import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

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

  @override
  bool build() => ref.watch(localCacheProvider).getBool(chiave) ?? acceso;

  Future<void> imposta({required bool somma}) async {
    state = somma;

    await ref.read(localCacheProvider).setBool(chiave, value: somma);
  }
}

final sommaLeBruciateProvider = NotifierProvider<SommaLeBruciate, bool>(
  SommaLeBruciate.new,
);
