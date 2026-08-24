import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/contenuto_messaggio.dart';
import '../../core/providers.dart';
import '../../core/storage/archivio_salute.dart';
import '../health/health_controller.dart';
import 'training_controller.dart' show revisioneSchedeProvider;

/// Le schede arrivate dal trainer via chat — S7.4.
///
/// 🚨 **Vivono sul telefono, ed è il punto dell'intera fase.** Una scheda
/// assegnata dice *«questa persona segue questo programma»*, e da un programma
/// post-infortunio si capisce cos'è successo a chi lo esegue. Il **modello**
/// resta sul server — è il patrimonio della palestra e non parla di nessuno —
/// ma il legame fra la persona e il programma non ci arriva mai.

/*
 * ══ 🗃️ E L'ELENCO NON È PIÙ QUI — 3b-B.17.6, 25/08/2026 ═════════════════
 *
 * ⛔ Qui c'erano `revisioneSchedeProvider` e `schedeRicevuteProvider`. Il primo
 * era **omonimo** di quello di `training_controller.dart` e non lo stesso: chi
 * importava una scheda dalla chat incrementava un contatore che l'elenco delle
 * schede non guardava — e la scheda appena aggiunta non compariva.
 *
 * 💡 Le schede si leggono da `schedeUniteProvider`, e la revisione è **una**.
 * ⚠️ Due provider con lo stesso nome in due file non danno nessun errore finché
 * non li importa lo stesso file: sembrano la stessa cosa, e non lo sono.
 */

/// Se una scheda arrivata in un certo messaggio è già stata aggiunta.
///
/// 💡 Serve alla chat per dire *«aggiunta»* invece di *«aggiungi»*: senza,
/// l'unico modo di sapere se si è già premuto il pulsante è provare — e
/// riprovare su un messaggio vecchio è la cosa più naturale del mondo.
final schedaGiaSalvataProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  messaggioId,
) async {
  ref.watch(revisioneSchedeProvider);

  return ref.watch(archivioSaluteProvider).schedaGiaSalvata(messaggioId);
});

class AzioniSchede {
  const AzioniSchede(this._ref);

  final Ref _ref;

  ArchivioSalute get _archivio => _ref.read(archivioSaluteProvider);

  /// Importa una scheda ricevuta.
  ///
  /// ⚠️ **`messaggioId` e non l'id della scheda.** Lo stesso modello può
  /// arrivare due volte — il trainer lo rimanda dopo averlo corretto — e sono
  /// due schede diverse nella vita di chi le riceve. Toccare due volte
  /// «aggiungi» sullo stesso messaggio invece non deve produrre due copie.
  Future<void> importa({
    required int messaggioId,
    required ContenutoScheda contenuto,
  }) async {
    await _archivio.salvaSchedaDallaChat(
      messaggioId: messaggioId,
      nome: contenuto.titolo,
      scheda: json.encode(contenuto.scheda),
      origineId: contenuto.origineId,
    );

    _ref.read(revisioneSchedeProvider.notifier).state++;
  }

  Future<void> butta(int id) async {
    await _archivio.cancellaScheda(id);

    _ref.read(revisioneSchedeProvider.notifier).state++;
  }
}

final azioniSchedeProvider = Provider<AzioniSchede>(AzioniSchede.new);

/// I piani alimentari arrivati dal trainer via chat — G8.5.
///
/// 🚨 **Vivono sul telefono**, come le schede e per la stessa ragione: da un
/// piano si capisce molto di chi lo segue, e il legame fra la persona e il piano
/// sul server non ci arriva mai (D4).
final pianiRicevutiProvider = FutureProvider.autoDispose<List<PianoRicevuto>>((
  ref,
) async {
  ref.watch(revisioneSchedeProvider);

  return ref.watch(archivioSaluteProvider).piani();
});

class AzioniPianiRicevuti {
  const AzioniPianiRicevuti(this._ref);

  final Ref _ref;

  /// Butta un piano — e **ricorda che e' stato buttato**.
  ///
  /// 🚨 Senza la seconda meta', il salvataggio automatico di G8.8 glielo
  /// rimetterebbe davanti al messaggio successivo, e l'allievo lo butterebbe di
  /// nuovo. Per sempre.
  Future<void> butta(int id) async {
    await _ref.read(archivioSaluteProvider).dimenticaPiano(id);

    _ref.read(revisioneSchedeProvider.notifier).state++;
  }
}

final azioniPianiRicevutiProvider = Provider<AzioniPianiRicevuti>(
  AzioniPianiRicevuti.new,
);

/// I modelli della palestra — solo per chi allena.
///
/// 🚨 Il trainer li scrive nel pannello e li **manda dall'app**, perché è
/// l'unico posto in cui esistono le chiavi per cifrarli. Questo provider è ciò
/// che glieli mette davanti nella schermata della chat.
final modelliPalestraProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final data = await ref
          .watch(apiClientProvider)
          .get<List<dynamic>>('/workout-plans/templates');

      return data.map((e) => (e as Map).cast<String, dynamic>()).toList();
    });
