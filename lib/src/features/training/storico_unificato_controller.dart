import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/archivio_salute.dart';
import '../health/health_controller.dart';
import 'data/storico_unificato.dart';
import 'schede_ricevute_controller.dart';
import 'session_controller.dart';

/// Quante volte gli allenamenti dell'orologio sono cambiati.
///
/// 💡 Stesso meccanismo di `revisioneSchedeProvider`: l'archivio è un database
/// locale, non una sorgente reattiva. Dopo un'assegnazione o un «nascondi»
/// bisogna dire a chi guarda di rileggere, e questo contatore è il modo che il
/// progetto usa già.
final revisioneAllenamentiProvider = StateProvider<int>((ref) => 0);

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

  final dalPolso = await ref
      .watch(allenamentiDalPolsoProvider.future)
      .catchError((Object _) => const <AllenamentoDaOrologio>[]);

  final schede = await ref
      .watch(schedeRicevuteProvider.future)
      .then((v) => {for (final s in v) s.id: s})
      .catchError((Object _) => const <int, SchedaRicevuta>{});

  return StoricoUnificato.fondi(
    sessioni: sessioni,
    dallOrologio: dalPolso,
    schede: schede,
  );
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
