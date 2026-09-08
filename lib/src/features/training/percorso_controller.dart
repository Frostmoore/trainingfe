import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health/health_controller.dart';
import '../health/salute_in_piu.dart';

/// Il percorso salvato di un allenamento, se c'è — 08/09/2026.
///
/// ⛔ **Non lo chiede**: legge soltanto quello che è già in archivio. 🚨 Chiedere
/// apre una finestra di sistema, e una finestra che si apre da sola perché una
/// card è comparsa a schermo sarebbe insopportabile — nello storico ce ne sono
/// otto alla volta.
///
/// 💡 A chiederlo è [ChiediIlPercorso], che parte da un gesto.
final percorsoDellAllenamentoProvider = FutureProvider.autoDispose
    .family<List<PuntoDelPercorso>?, int>((ref, allenamentoId) {
      ref.watch(revisioneDeiPercorsiProvider);

      return ref.watch(archivioSaluteProvider).percorsoDi(allenamentoId);
    });

/// Se per questo allenamento la persona ha già detto di no.
final percorsoRifiutatoProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  allenamentoId,
) {
  ref.watch(revisioneDeiPercorsiProvider);

  return ref.watch(archivioSaluteProvider).percorsoRifiutato(allenamentoId);
});

/// Gli allenamenti che un percorso ce l'hanno — per lo storico.
///
/// ⚠️ **Una interrogazione sola per tutta la lista**, e non una per card: lo
/// storico disegna otto miniature per schermata, e otto letture di tracciati
/// interi per sapere *se* disegnarli sarebbe il modo di far scattare lo scorrimento.
final allenamentiConPercorsoProvider = FutureProvider.autoDispose<Set<int>>((
  ref,
) {
  ref.watch(revisioneDeiPercorsiProvider);

  return ref.watch(archivioSaluteProvider).allenamentiConPercorso();
});

/// Cambia quando un percorso viene salvato o rifiutato.
///
/// 💡 Stessa forma di `revisioneAllenamentiProvider`: un contatore che fa
/// ricalcolare chi guarda, senza che ognuno debba sapere chi ha scritto.
final revisioneDeiPercorsiProvider = StateProvider<int>((ref) => 0);

/// Chiede alla persona il percorso di un allenamento.
///
/// ══ 🚨 PARTE SEMPRE DA UN GESTO ═══════════════════════════════════════════
///
/// ⛔ Health Connect apre **una finestra di sistema** con la mappa del tracciato
/// e chiede se condividerlo. Non è una lettura: è una domanda, e le domande le
/// fa chi ha premuto un pulsante.
///
/// ⚠️ **E funziona solo con l'app in primo piano.** Google: *«when your app runs
/// in the background … Health Connect returns ConsentRequired, even if your app
/// has Always allow»*. 💡 Il che va benissimo, visto che parte da un dito.
class ChiediIlPercorso {
  const ChiediIlPercorso(this._ref);

  final Ref _ref;

  /// Torna `true` se il percorso è arrivato.
  ///
  /// ⚠️ **Un `false` non è un errore da mostrare in rosso**: quasi sempre è la
  /// persona che ha detto di no, ed è una risposta legittima. 🚨 Il rifiuto viene
  /// **salvato**, così la volta dopo la pagina non ripropone la domanda da sola.
  Future<bool> per({
    required int allenamentoId,
    required String? idSalute,
  }) async {
    /*
     * ⛔ **Senza l'id di Health Connect non si può nemmeno chiedere.** Succede
     * sulle righe scritte prima della v31: l'id si riempie alla prima
     * risincronizzazione, e per gli allenamenti troppo vecchi non arriverà mai.
     */
    if (idSalute == null || idSalute.isEmpty) return false;

    final risposta = await const SaluteInPiu().percorso(idSalute);

    /*
     * ⚠️ **«non chiesto» non si salva.** Un canale che non risponde — iOS, o una
     * richiesta già aperta — non è una scelta della persona: segnarlo come
     * rifiuto le toglierebbe il pulsante per un guasto nostro.
     */
    if (risposta.esito == EsitoDelPercorso.nonChiesto) return false;

    await _ref
        .read(archivioSaluteProvider)
        .scriviIlPercorso(allenamentoId: allenamentoId, punti: risposta.punti);

    _ref.read(revisioneDeiPercorsiProvider.notifier).state++;

    return risposta.esito == EsitoDelPercorso.concesso;
  }
}

final chiediIlPercorsoProvider = Provider<ChiediIlPercorso>(
  ChiediIlPercorso.new,
);
