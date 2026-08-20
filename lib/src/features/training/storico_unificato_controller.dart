import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/archivio_salute.dart';
import '../health/health_controller.dart';
import 'data/storico_unificato.dart';
import 'schede_ricevute_controller.dart';
import 'session_controller.dart';

/// Gli allenamenti registrati dall'orologio, dal telefono — FASE 1.9.
///
/// 🚨 **Non passa dal server, e non ci deve passare.** Sono dati sanitari, e la
/// regola del 19/08 non ha eccezioni: restano sul telefono e nel backup.
final allenamentiDalPolsoProvider =
    FutureProvider.autoDispose<List<AllenamentoDaOrologio>>((ref) async {
  ref.watch(revisioneAllenamentiProvider);

  return ref.watch(archivioSaluteProvider).allenamentiDellOrologio();
});

/// Lo storico completo: le sedute dell'app e gli allenamenti dell'orologio,
/// fusi — FASE 1.10.
///
/// ── ⚠️ Perché l'orologio non fa fallire lo storico ────────────────────────
///
/// Le sedute arrivano dalla rete, gli allenamenti dal disco. Se l'archivio
/// locale desse un errore — un telefono senza Health Connect, un database
/// appena migrato — far fallire tutto vorrebbe dire nascondere anche le sedute
/// che avevamo già, per un dato **accessorio**.
///
/// 💡 Quindi: un guasto sul lato locale vale «nessun allenamento dall'orologio»,
/// e lo storico resta quello di prima. 🚨 Il contrario no: se cade la rete, lo
/// storico deve dirlo, perché lì manca la parte principale.
final storicoUnificatoProvider =
    FutureProvider.autoDispose<List<VoceStorico>>((ref) async {
  final sessioni = await ref.watch(sessionsProvider.future);

  /*
   * ⚠️ **Il `debugPrint` non è decorazione.** Una ricaduta silenziosa su lista
   * vuota è la stessa forma del difetto del 20/08: la schermata diceva «Nessun
   * allenamento» e nel database la riga c'era. Se un giorno la lettura locale
   * fallisce davvero, «vuoto» e «rotto» devono essere distinguibili almeno da
   * chi ha il telefono attaccato al cavo.
   */
  final dalPolso = await ref
      .watch(allenamentiDalPolsoProvider.future)
      .catchError((Object e) {
    debugPrint('storicoUnificato: gli allenamenti locali non si leggono — $e');

    return const <AllenamentoDaOrologio>[];
  });

  final schede = await ref
      .watch(schedeRicevuteProvider.future)
      .then((v) => {for (final s in v) s.id: s})
      .catchError((Object e) {
    debugPrint('storicoUnificato: le schede non si leggono — $e');

    return const <int, SchedaRicevuta>{};
  });

  return StoricoUnificato.fondi(
    sessioni: sessioni,
    dallOrologio: dalPolso,
    schede: schede,
  );
});

/// La riga di storico a cui appartiene una seduta — FASE 1-bis.
///
/// ── 🚨 Perché il riepilogo ne ha bisogno ──────────────────────────────────
///
/// Perché altrimenti **si contraddice con lo storico**. La card dello storico
/// mostra le calorie misurate dall'orologio; il riepilogo mostrava la nostra
/// stima e la chiamava «stima calcolata dagli esercizi». ⚠️ Due schermate, la
/// stessa ora, due numeri diversi e nessuno che dica quale vale.
///
/// 💡 `null` quando quella seduta non è (ancora) in nessun gruppo: il riepilogo
/// si comporta come prima, che è la cosa giusta.
final voceDellaSedutaProvider =
    FutureProvider.autoDispose.family<VoceStorico?, int>((ref, sedutaId) async {
  final voci = await ref.watch(storicoUnificatoProvider.future);

  for (final v in voci) {
    if (v.sedute.any((s) => s.id == sedutaId)) return v;
  }

  return null;
});

/// Assegna a un allenamento dell'orologio una delle proprie schede — FASE 1.10.
///
/// 💡 È la richiesta del 19/08 detta così: *«devo poter scegliere di assegnarvi
/// una mia scheda»*. `null` toglie l'assegnazione, perché una scelta che non si
/// può disfare è una trappola.
///
/// ⚠️ `WidgetRef` e non `Ref`: la chiama una schermata, non un provider. Sono
/// due tipi diversi e non imparentati — `Ref` vive dentro il grafo, `WidgetRef`
/// lo guarda da fuori.
Future<void> assegnaSchedaAllAllenamento(
  WidgetRef ref, {
  required int allenamentoId,
  required int? schedaId,
}) async {
  await ref
      .read(archivioSaluteProvider)
      .assegnaSchedaAllenamento(allenamentoId, schedaId);

  ref.read(revisioneAllenamentiProvider.notifier).state++;
}

/// «Non è lo stesso allenamento» — FASE 1-bis.
///
/// ── 🚨 È la contropartita della regola larga ──────────────────────────────
///
/// Dal 20/08 basta **un istante** di sovrapposizione perché due registrazioni
/// finiscano nella stessa riga (decisione D-1bis/A). ⚠️ Senza questo comando un
/// raggruppamento sbagliato farebbe **sparire** un allenamento vero dallo
/// storico, e non ci sarebbe modo di riaverlo.
///
/// 💡 Il committente l'ha messa proprio come uno scambio: *«se i timeframes si
/// sovrappongono allora è lo stesso allenamento. Poi ci mettiamo la possibilità
/// di splittarli e via»*. Le due cose stanno o cadono insieme.
Future<void> staccaAllenamento(
  WidgetRef ref, {
  required int allenamentoId,
  required bool staccato,
}) async {
  await ref
      .read(archivioSaluteProvider)
      .staccaAllenamento(allenamentoId, staccato: staccato);

  ref.read(revisioneAllenamentiProvider.notifier).state++;
}
