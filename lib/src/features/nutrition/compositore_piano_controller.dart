import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/providers.dart';
import 'data/piano_alimentare.dart';

/// I piani alimentari scritti da un trainer — G7.3/G7.4.
///
/// 🚨 **Prima di G5 non c'era dove mandarli.** I piani alimentari avevano un
/// editor nel pannello e **nessuna API di scrittura**: un trainer non poteva
/// comporre un piano dall'app perché l'endpoint non esisteva.
///
/// ⚠️ **Plurale**: `/nutrition-plans`. Il singolare `/nutrition-plan` è il piano
/// **dell'iscritto**, ed è un'altra cosa a un carattere di distanza.
final mieiPianiProvider = FutureProvider.autoDispose<List<PianoAlimentare>>((
  ref,
) async {
  final dati = await ref
      .watch(apiClientProvider)
      .get<List<dynamic>>('/nutrition-plans');

  return dati
      .map((e) => PianoAlimentare.fromJson((e as Map).cast<String, dynamic>()))
      .toList(growable: false);
});

/// I **modelli** da mandare in chat — G8.2.
///
/// 🚨 Torna la forma grezza (`Map`) e non `PianoAlimentare`, ed è voluto: quello
/// che parte dentro la busta è **il JSON del server**, non una sua traduzione.
/// Passare dal modello dell'app e ritornare indietro vorrebbe dire che un campo
/// che l'app non conosce si perde per strada — e chi lo riceve non saprebbe mai
/// che c'era.
final mieiPianiTemplateProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final dati = await ref
          .watch(apiClientProvider)
          .get<List<dynamic>>('/nutrition-plans/templates');

      return dati.map((e) => (e as Map).cast<String, dynamic>()).toList();
    });

/// Un piano per intero, con giorni, pasti e alimenti.
final pianoProvider = FutureProvider.autoDispose.family<PianoAlimentare, int>((
  ref,
  id,
) async {
  final dati = await ref
      .watch(apiClientProvider)
      .get<Map<String, dynamic>>('/nutrition-plans/$id');

  return PianoAlimentare.fromJson(dati);
});

final azioniPianoProvider = Provider(
  (ref) => AzioniPiano(ref.watch(apiClientProvider), ref),
);

class AzioniPiano {
  const AzioniPiano(this._api, this._ref);

  final ApiClient _api;
  final Ref _ref;

  /// Salva il piano, creandolo o aggiornandolo.
  ///
  /// 💡 **Una richiesta sola con l'albero intero**, e non un endpoint per
  /// livello: un piano si modifica come un tutto — si sposta un alimento, si
  /// duplica un giorno, si riordina. Con richieste granulari ogni gesto
  /// diventerebbe tre chiamate, e perdere la rete a metà lascerebbe il piano in
  /// uno stato che non è né quello di prima né quello di dopo.
  Future<PianoAlimentare> salva(PianoAlimentare piano) async {
    final corpo = piano.toJson();

    final dati = piano.nuovo
        ? await _api.post<Map<String, dynamic>>('/nutrition-plans', body: corpo)
        : await _api.put<Map<String, dynamic>>(
            '/nutrition-plans/${piano.id}',
            body: corpo,
          );

    _ref.invalidate(mieiPianiProvider);

    if (piano.id != null) {
      _ref.invalidate(pianoProvider(piano.id!));
    }

    return PianoAlimentare.fromJson(dati);
  }

  Future<void> elimina(int id) async {
    await _api.delete('/nutrition-plans/$id');

    _ref.invalidate(mieiPianiProvider);
  }

  /// Chiede all'AI i valori di un alimento — D13.
  ///
  /// ── 🚨 La paga il trainer, e va detto ────────────────────────────────
  ///
  /// Questa chiamata consuma **la quota di chi sta componendo**, non quella
  /// dell'allievo che riceverà il piano. È giusto — quando il piano arriva, il
  /// costo è già stato sostenuto — ma l'interfaccia deve dirlo, o il trainer
  /// scopre di aver speso solo quando finisce.
  ///
  /// ⚠️ **Restituisce una proposta, non una decisione.** Il trainer corregge
  /// quello che vuole: `origineValori` torna a `manual` appena tocca un campo,
  /// ed è il modo in cui si vede a colpo d'occhio cosa ha già controllato.
  Future<List<AlimentoDelPiano>> stima(String testo) async {
    final dati = await _api.post<Map<String, dynamic>>(
      '/nutrition-plans/stima-alimento',
      body: {'text': testo},
    );

    return ((dati['items'] as List?) ?? const [])
        .map(
          (e) => AlimentoDelPiano.fromJson((e as Map).cast<String, dynamic>()),
        )
        .toList(growable: false);
  }
}
