import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import 'data/scheda_allenamento.dart';

/// Le schede scritte da un trainer — G7.1.
///
/// 🚨 **Gemello di `compositore_piano_controller.dart`**, e le due famiglie di
/// provider restano separate di proposito: schede e piani alimentari si
/// somigliano nella forma (giorni, alternative, un promemoria privato) e in
/// niente altro. Un provider generico su «cosa componibile» costringerebbe ogni
/// schermata a sapere quale delle due sta guardando.
///
/// ⚠️ **`/workout-plans` è la stessa rotta che l'iscritto usa per le schede
/// proprie.** Non ce n'è una «da trainer»: quello che cambia è chi la chiama e
/// cosa gli torna indietro. Il filtro lo fa `forMember()` sul server, e va bene
/// così — due rotte che fanno la stessa cosa divergono alla prima modifica.
final mieSchedeProvider = FutureProvider.autoDispose<List<SchedaAllenamento>>((ref) async {
  final dati = await ref.watch(apiClientProvider).get<List<dynamic>>('/workout-plans');

  return dati
      .map((e) => SchedaAllenamento.fromJson((e as Map).cast<String, dynamic>()))
      .toList(growable: false);
});

/// Una scheda per intero, con giorni, esercizi e alternative.
///
/// 💡 **Prima di G7 questa chiamata non serviva a niente per un compositore**:
/// `dettaglio()` tornava la sola lista piatta, quindi riaprire una scheda a tre
/// giorni ne avrebbe mostrato uno e il salvataggio avrebbe cancellato gli altri.
final schedaProvider = FutureProvider.autoDispose.family<SchedaAllenamento, int>((ref, id) async {
  final dati = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/workout-plans/$id');

  return SchedaAllenamento.fromJson(dati);
});

final azioniSchedaProvider = Provider(
  (ref) => AzioniScheda(ref.watch(apiClientProvider), ref),
);

class AzioniScheda {
  const AzioniScheda(this._api, this._ref);

  final ApiClient _api;
  final Ref _ref;

  /// Salva la scheda, creandola o aggiornandola.
  ///
  /// 💡 **Una richiesta sola con l'albero intero**, come per i piani
  /// alimentari: una scheda si modifica come un tutto — si sposta un esercizio,
  /// si duplica un giorno, si riordina. Con richieste granulari ogni gesto
  /// diventerebbe tre chiamate, e perdere la rete a metà lascerebbe la scheda in
  /// uno stato che non è né quello di prima né quello di dopo.
  ///
  /// ⚠️ Il server **riscrive i giorni da zero** a ogni salvataggio: gli `id`
  /// che tornano non sono quelli mandati. È il motivo per cui questo metodo
  /// restituisce la scheda **riletta** invece di `void` — chi la tiene nello
  /// stato deve sostituirla, o al secondo salvataggio manderebbe id defunti.
  Future<SchedaAllenamento> salva(SchedaAllenamento scheda) async {
    final corpo = scheda.toJson();

    final dati = scheda.nuova
        ? await _api.post<Map<String, dynamic>>('/workout-plans', body: corpo)
        : await _api.put<Map<String, dynamic>>('/workout-plans/${scheda.id}', body: corpo);

    _ref.invalidate(mieSchedeProvider);

    if (scheda.id != null) {
      _ref.invalidate(schedaProvider(scheda.id!));
    }

    return SchedaAllenamento.fromJson(dati);
  }

  Future<void> elimina(int id) async {
    await _api.delete('/workout-plans/$id');

    _ref.invalidate(mieSchedeProvider);
  }
}
