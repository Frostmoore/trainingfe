import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../dashboard/dashboard_controller.dart';
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
/// ⚠️ **Le assunte vengono dal server e il peso dal telefono**, ed è l'unico
/// posto dell'app dove i due mondi si incontrano per fare un conto. 🚨 È anche
/// il motivo per cui questo provider può fallire in due modi diversi: senza
/// rete non c'è il diario, senza pesate non c'è la variazione.
final tdeeMisuratoProvider = FutureProvider.autoDispose<TdeeMisurato>((
  ref,
) async {
  ref.watch(revisioneCorpoProvider);

  final archivio = ref.watch(archivioSaluteProvider);
  final api = ref.watch(apiClientProvider);

  final dati = await api.get<Map<String, dynamic>>(
    '/series',
    query: {'metric': 'calories', 'days': _finestraGiorni, 'offset': 0},
  );

  final serie = Series.fromJson(dati);

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
