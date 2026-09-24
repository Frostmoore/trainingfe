import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'data/avviso.dart';

/// 📣 **Gli avvisi in-app, lato app** — blocco B4, 24/09/2026.
///
/// 🚨 **Uno per volta**: il server risponde con il più vecchio non ancora
/// deciso, e non con un elenco. ⛔ Due modali in fila all'apertura non sono un
/// avviso, sono un pedaggio — e chi si trova davanti una coda non legge: preme
/// il primo pulsante per arrivare all'app.
final prossimoAvvisoProvider = FutureProvider<Avviso?>((ref) async {
  final dati = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>?>('/avvisi/prossimo');

  if (dati == null || dati.isEmpty) return null;

  return Avviso.fromJson(dati);
});

final avvisiActionsProvider = Provider((ref) => AvvisiActions(ref));

class AvvisiActions {
  AvvisiActions(this._ref);

  final Ref _ref;

  /// Registra la risposta.
  ///
  /// 🚨 **Si manda sempre**, anche il rifiuto: *«il numero di chi dice di no è
  /// metà del motivo per cui si manda un avviso»*. ⚠️ Ed è anche la difesa il
  /// giorno in cui qualcuno dice «non ho mai accettato».
  ///
  /// 💡 L'eventuale promozione la attiva **il server**, dentro questa chiamata.
  Future<void> rispondi(int avvisoId, {required bool approvato}) async {
    await _ref
        .read(apiClientProvider)
        .post<Map<String, dynamic>>(
          '/avvisi/$avvisoId/decisione',
          body: {'decisione': approvato ? 'approvato' : 'rifiutato'},
        );

    _ref.invalidate(prossimoAvvisoProvider);
  }
}
