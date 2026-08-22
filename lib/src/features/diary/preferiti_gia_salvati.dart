import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'diary_controller.dart';

/// Se una cosa è **già** fra i preferiti — 3b-D.5, 22/08/2026.
///
/// ══ 🚨 PERCHÉ SERVE UN INDICE E NON UN CAMPO ══════════════════════════════
///
/// 📌 Il committente: *«Quando clicco sulla stella per rendere un cibo
/// preferito, la stella si deve riempire, e se ci clicco di nuovo, si deve
/// togliere dai preferiti»*.
///
/// ⚠️ **Il server non lega un preferito alla voce da cui è nato**: sono due
/// tabelle senza una chiave in comune, e non è una dimenticanza — un preferito
/// sopravvive alla voce che l'ha generato, ed è tutto il suo senso.
///
/// 🚨 Quindi «è già salvato?» non è un campo da leggere: è una **domanda che si
/// risponde per contenuto**. ⛔ E va risposta bene, perché una stella piena su
/// una cosa che non è salvata è peggio di una stella sempre vuota: la seconda
/// non promette niente.
///
/// ── 💡 Due identità diverse, per due cose diverse ────────────────────────
///
/// | Cosa | Come si riconosce | Perché |
/// |---|---|---|
/// | **Un alimento** | il nome, senza maiuscole né spazi | «Croissant» e «croissant» sono la stessa cosa, e chi ne salva uno si aspetta la stella piena sull'altro |
/// | **Un pasto** | quante voci ha e quante calorie fa | 🚨 Il nome non serve: il committente lo può cambiare al volo, e un pasto salvato come «la mia colazione» resterebbe senza segnalibro |
///
/// ⚠️ **Il pasto si riconosce dal contenuto, ed è la scelta giusta anche
/// quando sembra fragile**: se si aggiunge una voce, il segnalibro si svuota. E
/// deve svuotarsi — quel pasto non è più quello che era stato salvato.
///
/// ⛔ **Niente di tutto questo si scrive da nessuna parte.** Si deriva dai
/// preferiti che il server manda già: nessun dato nuovo, e quindi nessuna
/// domanda su dove metterlo nel backup.
class PreferitiGiaSalvati {
  const PreferitiGiaSalvati(this._tutti);

  final List<FoodFavorite> _tutti;

  /// Il preferito che corrisponde a questo alimento, o `null`.
  FoodFavorite? perAlimento(String descrizione) {
    final cercato = _chiave(descrizione);
    if (cercato.isEmpty) return null;

    for (final f in _tutti) {
      if (!f.isMeal && _chiave(f.description) == cercato) return f;
    }

    return null;
  }

  /// Il preferito che corrisponde a **questo** pasto, o `null`.
  ///
  /// 🚨 `voci` e `kcal` insieme: solo le calorie non bastano — due colazioni da
  /// 400 kcal fatte con cose diverse non sono lo stesso preferito.
  ///
  /// ⚠️ Le calorie si confrontano **arrotondate**: sono `double` che hanno
  /// attraversato JSON e una somma, e un confronto esatto fallirebbe per
  /// mezzo decimale — cioè il segnalibro resterebbe vuoto senza motivo.
  FoodFavorite? perPasto({required int voci, required double kcal}) {
    if (voci == 0) return null;

    for (final f in _tutti) {
      if (!f.isMeal) continue;
      if (f.itemsCount != voci) continue;
      if ((f.kcal ?? 0).round() != kcal.round()) continue;

      return f;
    }

    return null;
  }

  static String _chiave(String s) => s.trim().toLowerCase();
}

final preferitiGiaSalvatiProvider = Provider.autoDispose<PreferitiGiaSalvati>((
  ref,
) {
  /*
   * 💡 `valueOrNull ?? []` e non un caricamento bloccante: finché l'elenco non
   * è arrivato le stelle sono vuote, e mezzo secondo dopo si riempiono da sole.
   * ⚠️ Una rotellina al posto di ogni stella sarebbe molto peggio.
   */
  return PreferitiGiaSalvati(
    ref.watch(favoritesProvider).valueOrNull ?? const [],
  );
});
