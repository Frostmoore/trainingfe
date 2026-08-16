import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

/// Quanti gettoni restano — 16/08/2026.
///
/// ── 🚨 Una moneta sola, e quindi un numero solo ───────────────────────────
///
/// Il piano accredita gettoni ogni mese e chi li finisce ne compra: sono **la
/// stessa moneta**, si spendono in fila — prima quelli del mese, poi i comprati
/// — e quindi si sommano senza mentire.
///
/// ⚠️ Fino a quando il server non passa al conteggio a somma, la parte mensile
/// conta **chiamate** e una foto vale 1 invece di 10. La forma è già quella
/// giusta, la scala no: il numero è ottimista finché non arriva quella modifica.
class Gettoni {
  const Gettoni({required this.disponibili, required this.illimitata});

  factory Gettoni.fromJson(Map<String, dynamic> j) => Gettoni(
    disponibili: (j['gettoni_disponibili'] as num?)?.toInt(),
    illimitata: j['illimitata'] as bool? ?? false,
  );

  /// `null` quando la quota è illimitata: l'app disegna un simbolo, non uno zero.
  ///
  /// 🚨 Sommare `null` a un numero darebbe zero, cioè **il contrario** di
  /// «illimitato». È il motivo per cui questo campo è nullable invece di avere
  /// un valore di comodo.
  final int? disponibili;

  final bool illimitata;

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
