import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Quanti gettoni **comprati** restano — 16/08/2026.
///
/// ── 🚨 La dotazione dell'abbonamento NON si conta qui ─────────────────────
///
/// Fino alla sera del 16/08 questo numero era `quota del mese + gettoni
/// comprati`. ⚠️ Sommandoli, chi ha un abbonamento vedeva **quante chiamate
/// gli restano incluse** — e quel numero, accanto al listino pubblicato,
/// diventa una divisione che chiunque sa fare: comprare un pacchetto costa
/// meno che abbonarsi.
///
/// 🎯 Decisione del committente: *«per chi ha il piano flat non deve vedere
/// quanti gettoni ha»*. La dotazione inclusa è **uso compreso**, non credito.
///
/// 💡 Chi ha comprato gettoni continua a vederli, ed è giusto: li ha pagati a
/// parte, sono suoi, e vuole sapere quanti gliene restano.
class Gettoni {
  const Gettoni({
    required this.disponibili,
    required this.illimitata,
    required this.daMostrare,
  });

  factory Gettoni.fromJson(Map<String, dynamic> j) => Gettoni(
    disponibili: (j['gettoni_disponibili'] as num?)?.toInt(),
    illimitata: j['illimitata'] as bool? ?? false,
    // ⚠️ Il valore di ripiego è `false`: se il server non lo dice — perché è
    // più vecchio dell'app — **non si mostra niente**. Il contrario
    // rimetterebbe in giro il numero che si è appena smesso di mostrare.
    daMostrare: j['mostra_gettoni'] as bool? ?? false,
  );

  /// I soli gettoni **comprati**. `null` quando la quota è illimitata.
  ///
  /// 🚨 Sommare `null` a un numero darebbe zero, cioè **il contrario** di
  /// «illimitato». È il motivo per cui questo campo è nullable invece di avere
  /// un valore di comodo.
  final int? disponibili;

  final bool illimitata;

  /// Se l'intestazione debba disegnare il contatore, oppure niente.
  ///
  /// ── ⚠️ Perché non basta mostrare zero ───────────────────────────────────
  ///
  /// Perché uno zero accanto a un'AI che **funziona** è una contraddizione:
  /// chi lo legge pensa che sia rotta, e scrive. Il contatore va **nascosto**,
  /// non azzerato.
  final bool daMostrare;

  /// 💡 Sotto il costo di una foto il numero va segnalato: chi ha 6 gettoni non
  /// è a zero, ma la prossima foto non la fa — e scoprirlo dopo aver inquadrato
  /// il piatto è la sequenza peggiore.
  bool get quasiFiniti => !illimitata && disponibili != null && disponibili! < 10;
}

/// 🚨 **Non è `autoDispose`**, ed è voluto: il numero sta nell'intestazione di
/// «Oggi», cioè su una schermata che si apre e si chiude di continuo. Buttarlo a
/// ogni uscita vorrebbe dire una richiesta in più ogni volta che si torna.
final gettoniProvider = FutureProvider<Gettoni>((ref) async {
  final dati = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/ai/usage');

  return Gettoni.fromJson(dati);
});
