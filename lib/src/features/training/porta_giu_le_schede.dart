/// Le schede scendono dal server **una volta sola** — 3b-B.17, 24/08/2026.
///
/// ══ 📌 IL CAMBIO DI ROTTA ═════════════════════════════════════════════════
///
/// *«le modifiche dal pannello di base non esistono. Cioè la scheda viene
/// generata dal trainer e inviata via chat all'utente, poi l'utente ce l'ha sul
/// telefono, non ha senso la modifica dal pannello. […] la scheda risiede sul
/// telefono (e finisce nel backup). Basta, niente server, sticazzi crea solo
/// problemi. Tanto se serve una nuova scheda il trainer la rimanda e l'utente
/// cancella la vecchia e usa la nuova. Fine»*.
///
/// ══ 🚨 COSA È SPARITO, E PERCHÉ È UN GUADAGNO ════════════════════════════
///
/// ⛔ Qui c'era `SincronizzaLeSchede`: tirava, spingeva, confrontava i timbri e
/// risolveva i conflitti fra due copie. Tutta quella macchina esisteva per un
/// problema che **non c'è**: nessuno modifica la scheda da due parti, perché
/// dal pannello non la si modifica affatto.
///
/// 💡 Senza due sorgenti non c'è conflitto, e senza conflitto non serve né il
/// timbro, né la copia messa da parte, né la regola su chi vince. ⚠️ Il codice
/// più solido è quello che non c'è.
///
/// ── ⛔ Resta un'importazione, e gira una volta per sempre ─────────────────
///
/// 🚨 Perché le schede che ci sono **già** sul server non si buttano: Giorno 1,
/// 2 e 3 stanno lì, e il committente le usa domani. ⚠️ Dopo quella, di schede
/// il server non ne sa più niente.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart' show ApiClient;
import '../../core/providers.dart';
import '../../core/storage/archivio_salute.dart';
import '../../core/storage/local_cache.dart';
import '../health/health_controller.dart';

class PortaGiuLeSchede {
  const PortaGiuLeSchede({
    required this.api,
    required this.archivio,
    required this.cache,
  });

  final ApiClient api;
  final ArchivioSalute archivio;
  final LocalCache cache;

  /// Quante schede sono scese. `null` = non c'era niente da fare.
  ///
  /// ⛔ **Una volta per telefono**, e il segno si mette **dopo** che è andata:
  /// segnarlo prima vorrebbe dire che un'importazione fallita a metà non si
  /// ripete mai più, e le schede rimaste sul server sparirebbero per sempre.
  Future<int?> forse() async {
    if (cache.schedePortateGiu) return null;

    final List<dynamic> elenco;

    try {
      elenco = await api.get<List<dynamic>>('/workout-plans');
    } on Object catch (e) {
      // ⚠️ Senza rete non è un fallimento: si riprova alla prossima apertura.
      debugPrint('schede: il server non risponde, si riprova — $e');

      return null;
    }

    var quante = 0;

    for (final riga in elenco) {
      final dati = (riga as Map).cast<String, dynamic>();
      final id = (dati['id'] as num).toInt();

      // 💡 Quella che c'è già non si tocca: potrebbe averla modificata.
      if (await archivio.laScheda(id) != null) continue;

      try {
        final dettaglio = await api.get<Map<String, dynamic>>(
          '/workout-plans/$id',
        );

        await archivio.scriviScheda(
          id: id,
          nome: dettaglio['name']?.toString() ?? 'Scheda',
          scheda: jsonEncode(dettaglio),
          mia: dettaglio['editable'] == true,
        );

        quante++;
      } on Object catch (e) {
        /*
         * ⛔ **Una che non scende ferma tutto.** Non si segna «fatto» se manca
         * qualcosa: meglio riprovare l'intera importazione alla prossima
         * apertura che dichiararla riuscita con dentro un buco.
         */
        debugPrint('schede: la $id non scende, si riprova — $e');

        return quante;
      }
    }

    await cache.segnaSchedePortateGiu();

    debugPrint('schede: portate giù $quante, e non si guarda più il server');

    return quante;
  }
}

final portaGiuLeSchedeProvider = Provider<PortaGiuLeSchede>(
  (ref) => PortaGiuLeSchede(
    api: ref.watch(apiClientProvider),
    archivio: ref.watch(archivioSaluteProvider),
    cache: ref.watch(localCacheProvider),
  ),
);

/// L'importazione, agganciata a chi guarda le schede.
///
/// 💡 `autoDispose`: rientrando nella schermata riprova, il che serve a chi la
/// prima volta era senza rete. ⚠️ Quando è già stata fatta esce subito senza
/// toccare niente — `forse()` guarda un booleano prima di qualunque chiamata.
final schedePortateGiuProvider = FutureProvider.autoDispose<int?>(
  (ref) => ref.read(portaGiuLeSchedeProvider).forse(),
);
