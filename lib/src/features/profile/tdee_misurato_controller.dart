import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../diary/data/diario_locale.dart';
import '../diary/data/serie_del_cibo.dart';
import '../health/health_controller.dart';
import 'corpo_controller.dart';
import 'data/tdee_misurato.dart';

/// Il TDEE misurato: il calcolo, e la scelta di usarlo — 3b-G.8, 26/08/2026.

/// Quanti giorni si guardano indietro per misurare.
///
/// 💡 Due mesi e non uno: con trenta giorni esatti basta una pesata saltata
/// all'inizio per scendere sotto la soglia dei ventotto, e la misura sparirebbe
/// senza che si capisca perché.
const _finestraGiorni = 60;

/// La misura, rifatta sui dati di adesso.
///
/// ══ 🚨 NON HA MAI FUNZIONATO, E SI E' SCOPERTO QUI — I2.5, 03/09/2026 ═════
///
/// ⛔ Chiedeva `days: _finestraGiorni`, cioè **60**, e `SeriesController`
/// ammetteva solo `0, 7, 30, 90, 365`: ogni lettura prendeva un
/// **`422 validation.in`**, quindi la misura del TDEE non è mai comparsa a
/// nessuno. 🚨 È lo stesso difetto del 21/08 sulla carica — e c'era pure un test
/// a sorvegliarlo: cercava i **letterali** `'days': 28`, e qui c'era una
/// costante. 📌 *«Un test che passa per il motivo sbagliato è peggio di uno
/// rosso, perché nessuno lo guarda»*.
///
/// 💡 Adesso le assunte vengono dall'archivio locale come le pesate: niente
/// rete, niente elenco di periodi ammessi, e i 60 giorni si chiedono e basta.
final tdeeMisuratoProvider = FutureProvider.autoDispose<TdeeMisurato>((
  ref,
) async {
  ref.watch(revisioneCorpoProvider);
  ref.watch(revisioneDiarioProvider);

  final archivio = ref.watch(archivioSaluteProvider);

  final serie = await ref
      .watch(serieDelCiboProvider)
      .calorie(giorni: _finestraGiorni);

  final misure = await archivio.storicoMisure(ultimiGiorni: _finestraGiorni);

  return misuraIlTdee(
    giorni: [for (final d in serie.dates) DateTime.tryParse(d) ?? DateTime(0)],
    assunte: serie.consumed,
    pesate: [
      for (final m in misure)
        if (m.pesoKg != null) Pesata(giorno: m.giorno, kg: m.pesoKg!),
    ],
  );
});

/// Il TDEE misurato **che la persona ha deciso di usare**.
///
/// ══ 🚨 SI PROPONE, NON SI SOSTITUISCE ═════════════════════════════════════
///
/// ⛔ L'app non passa da sola dalla stima alla misura, per quanto la misura sia
/// migliore. Un obiettivo che cambia da solo non lo si può più controllare: chi
/// se lo vede scendere di 200 kcal senza aver toccato niente non ha modo di
/// capire se è successo qualcosa o se l'app si è rotta.
///
/// 💡 E si può tornare indietro: `dimentica()` rimette la stima.
///
/// ⚠️ Si salva **il numero**, non «usa la misura». Ricalcolarlo a ogni avvio
/// vorrebbe dire un fabbisogno che si muove da solo di qualche kcal al giorno —
/// tecnicamente più giusto, e inutilizzabile.
class TdeeAccettato extends Notifier<double?> {
  static const chiave = 'obiettivo.tdee_misurato';

  @override
  double? build() {
    final salvato = ref.watch(localCacheProvider).getString(chiave);

    if (salvato == null) return null;

    final valore = double.tryParse(salvato);

    // ⛔ Un valore illeggibile o assurdo vale «non c'è»: meglio tornare alla
    // stima che costruire una dieta su una stringa rotta.
    if (valore == null || valore < 800 || valore > 8000) return null;

    return valore;
  }

  Future<void> accetta(double kcal) async {
    state = kcal;

    await ref.read(localCacheProvider).setString(chiave, kcal.toString());
  }

  Future<void> dimentica() async {
    state = null;

    await ref.read(localCacheProvider).remove(chiave);
  }
}

final tdeeAccettatoProvider = NotifierProvider<TdeeAccettato, double?>(
  TdeeAccettato.new,
);
