import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/archivio_salute.dart';
import '../health/dati_salute.dart';
import '../health/health_controller.dart';
import 'statistiche_allenamento.dart';

/// Le statistiche di un allenamento dell'orologio — 08/09/2026.
///
/// ══ 🚨 IL GRUPPO, NON IL SINGOLO TRATTO ══════════════════════════════════
///
/// L'orologio spezza volentieri un'uscita in più record: una pausa al semaforo,
/// una sincronizzazione a metà. ⛔ Calcolare la velocità media di un tratto solo
/// darebbe un numero giusto per quel tratto e sbagliato per l'uscita — che è
/// quella che la persona ha fatto e che la pagina racconta.
///
/// 💡 Quindi: **durata dal primo inizio all'ultima fine**, distanze e passi
/// sommati. ⚠️ La durata comprende quindi anche i buchi fra un tratto e l'altro,
/// ed è **voluto**: se ti sei fermato dieci minuti al bar, quei dieci minuti
/// fanno parte dell'uscita e la velocità media deve risentirne.
final statisticheAllenamentoProvider = FutureProvider.autoDispose
    .family<StatisticheAllenamento?, List<AllenamentoDaOrologio>>((
      ref,
      tratti,
    ) async {
      if (tratti.isEmpty) return null;

      final inizio = tratti
          .map((a) => a.iniziatoIl)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final fine = tratti
          .map((a) => a.finitoIl)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      /*
       * ⚠️ **Il tipo del primo tratto**, e non «il più frequente».
       *
       * 🚨 I tratti di un gruppo sono lo stesso allenamento spezzato, quindi il
       * tipo è lo stesso per tutti: la domanda non si pone. ⛔ Se un giorno si
       * ponesse — due tipi diversi finiti nello stesso gruppo — vorrebbe dire
       * che il raggruppamento è rotto, e il rimedio sta lì, non qui.
       */
      final tipo = tratti.first.tipo;

      final battito = await _battito(
        ref.watch(archivioSaluteProvider),
        da: inizio,
        a: fine,
      );

      return StatisticheAllenamento(
        tipo: tipo,
        durata: fine.difference(inizio),
        distanzaMetri: _somma(tratti.map((a) => a.distanzaMetri)),
        passi: _somma(tratti.map((a) => a.passi)),
        kcal: _somma(tratti.map((a) => a.kcal)),
        battitoMedio: battito?.$1,
        battitoMassimo: battito?.$2,
      );
    });

/// Media e massimo del battito nella finestra, o `null` se non ci sono campioni.
///
/// ⛔ **`null` e non zero.** Un allenamento senza campioni di battito e uno con
/// battito zero sono due cose diverse, e la seconda non esiste: scrivere «0 bpm»
/// vorrebbe dire dichiarare morto chi si è allenato senza orologio al polso.
Future<(int, int)?> _battito(
  ArchivioSalute archivio, {
  required DateTime da,
  required DateTime a,
}) async {
  final letture = await archivio.lettureFraIstanti(
    MetricaSalute.battitoMedio,
    da: da,
    a: a,
  );

  if (letture.isEmpty) return null;

  var somma = 0.0;
  var massimo = 0.0;

  for (final l in letture) {
    somma += l.valore;

    if (l.valore > massimo) massimo = l.valore;
  }

  return ((somma / letture.length).round(), massimo.round());
}

/// La somma di quelli che ci sono, `null` se non ce n'è nessuno.
///
/// 🚨 **Non `fold(0, ...)`**: quello darebbe zero anche quando nessun tratto ha
/// il dato, e uno zero si legge come una misura. ⚠️ Un'uscita in bici senza
/// distanza scritta deve dire «non lo so», non «zero chilometri».
int? _somma(Iterable<int?> valori) {
  int? fuori;

  for (final v in valori) {
    if (v == null) continue;

    fuori = (fuori ?? 0) + v;
  }

  return fuori;
}
