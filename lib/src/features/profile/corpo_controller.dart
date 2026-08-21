import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/archivio_salute.dart';
import '../dashboard/data/dashboard_models.dart';
import '../health/health_controller.dart';

/// Peso e misure, **letti dal telefono** — S5.2.
///
/// 🚨 **Erano `GET /body-metrics`.** Da S5 quell'endpoint non esiste più: peso e
/// misure sono dati del corpo, e i dati del corpo non stanno sul server
/// (decisione **D9-bis**).
///
/// ⚠️ **Questi sono i dati che vale davvero la pena non perdere.** Il peso di
/// due anni è la cosa che si guarda indietro; sonno e HRV valgono giorni. È per
/// questo che il file di backup di S6.6 esiste soprattutto per loro.

/// Ogni scrittura del peso incrementa questo contatore, e i provider che lo
/// osservano si ricalcolano.
///
/// ⚠️ Serve perché `drift` qui non è osservato con uno stream: senza,
/// registrare un peso non aggiornerebbe né il grafico né la card finché non si
/// riapre la schermata.
final revisioneCorpoProvider = StateProvider<int>((ref) => 0);

/// Lo storico delle misure, dalla più recente.
final storicoCorpoProvider = FutureProvider.autoDispose<List<MisuraCorpo>>((
  ref,
) async {
  ref.watch(revisioneCorpoProvider);

  return ref.watch(archivioSaluteProvider).storicoMisure();
});

/// L'ultimo peso e quanto è cambiato — quel che serviva a `WeightCard`.
///
/// Sostituisce la sezione `body` che `GET /dashboard` restituiva prima di S5.
final corpoOggiProvider = FutureProvider.autoDispose<BodyToday>((ref) async {
  ref.watch(revisioneCorpoProvider);

  final archivio = ref.watch(archivioSaluteProvider);
  final storico = await archivio.storicoMisure();
  final conPeso = storico.where((m) => m.pesoKg != null).toList();

  if (conPeso.isEmpty) {
    return const BodyToday(
      weightKg: null,
      weightDelta: null,
      targetWeightKg: null,
    );
  }

  final ultimo = conPeso.first;

  /*
   * ⚠️ Lo scostamento si calcola sulla misura di **circa una settimana fa**,
   * non sulla precedente.
   *
   * Fra due pesate a un giorno di distanza la differenza e' acqua, non grasso:
   * mostrarla come «−0,8 kg» insegnerebbe a leggere il rumore come progresso, e
   * il giorno che risale a +0,8 sembrerebbe un fallimento. E' la stessa
   * finestra che usava `DashboardService::corpo()`.
   */
  final riferimento = conPeso.firstWhere(
    (m) => ultimo.giorno.difference(m.giorno).inDays >= 7,
    orElse: () => conPeso.last,
  );

  final delta = identical(riferimento, ultimo)
      ? null
      : _arrotonda(ultimo.pesoKg! - riferimento.pesoKg!, 1);

  return BodyToday(
    weightKg: ultimo.pesoKg,
    weightDelta: delta,
    // ⚠️ Il peso obiettivo resta nel profilo sul server: e' una **preferenza**,
    // non una misura del corpo. Lo aggiunge chi costruisce la card.
    targetWeightKg: null,
  );
});

double _arrotonda(double v, int decimali) {
  final f = <int, double>{0: 1, 1: 10, 2: 100}[decimali] ?? 10;

  return (v * f).roundToDouble() / f;
}

/// Le azioni sul corpo.
class AzioniCorpo {
  const AzioniCorpo(this._ref);

  final Ref _ref;

  /// Registra il peso del giorno.
  ///
  /// 🚨 **UPSERT sul giorno**: pesarsi due volte lo stesso giorno è una
  /// **correzione**, non un secondo punto sul grafico. Era il comportamento del
  /// server (`UNIQUE(user_id, date)`) e non cambia perché cambia casa.
  Future<void> registraPeso({
    required double kg,
    DateTime? giorno,
    double? massaGrassaPct,
  }) async {
    final quando = giorno ?? DateTime.now();

    await _ref
        .read(archivioSaluteProvider)
        .registraMisura(
          MisuraCorpo(
            id: 0,
            giorno: DateTime(quando.year, quando.month, quando.day),
            pesoKg: kg,
            massaGrassaPct: massaGrassaPct,
          ),
        );

    _ref.read(revisioneCorpoProvider.notifier).state++;
  }
}

final azioniCorpoProvider = Provider<AzioniCorpo>(AzioniCorpo.new);
