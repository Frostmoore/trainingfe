/// Il mese in numeri — 3b-A.6.3, 24/08/2026.
///
/// 📌 Il committente: *«una con il numero di sessioni del mese, con il totale
/// di kg sollevati, i km percorsi e le kcal bruciate»*.
///
/// ══ 🚨 QUATTRO NUMERI, E TRE DI LORO POSSONO NON ESISTERE ═════════════════
///
/// ⛔ Chi fa solo pesi non ha km. Chi corre e basta non ha chili. Chi non ha
/// l'orologio può non avere le calorie. ⚠️ Mostrare **0 km** a chi solleva
/// bilancieri è un numero falso travestito da informazione: `null` vuol dire
/// «non pertinente» e la card lo salta, `0` vorrebbe dire «hai corso zero».
///
/// 💡 È la stessa regola del «0 bruciate» del 23/08: un numero che c'è ed è
/// falso batte in danno un numero che manca.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/storico_unificato.dart';
import 'storico_unificato_controller.dart';

class MeseInNumeri {
  const MeseInNumeri({
    required this.sessioni,
    this.kgSollevati,
    this.metri,
    this.kcal,
  });

  /// Quante volte ti sei allenato: **i gruppi**, non le registrazioni.
  ///
  /// 🚨 Una seduta registrata dall'app *e* dall'orologio è **una**. È lo stesso
  /// conteggio dell'etichetta del navigatore, e per la stessa ragione.
  final int sessioni;

  /// I chili spostati: somma di `ripetizioni × peso` su tutte le serie.
  ///
  /// ⚠️ `null` quando non c'è **nessuna** serie con un peso: chi non ha mai
  /// sollevato niente non deve leggere «0 kg».
  final double? kgSollevati;

  /// I metri percorsi, dall'orologio. `null` se non ne ha mai visti.
  final int? metri;

  /// Le calorie, dalla stessa catena di priorità dello storico.
  final int? kcal;

  bool get eVuoto => sessioni == 0;
}

/// I numeri del mese di una data.
MeseInNumeri numeriDelMese(Iterable<VoceStorico> voci) {
  var sessioni = 0;
  var kg = 0.0;
  var conKg = false;
  var metri = 0;
  var conMetri = false;
  var kcal = 0;
  var conKcal = false;

  for (final v in voci) {
    sessioni++;

    for (final seduta in v.sedute) {
      for (final serie in seduta.sets) {
        final peso = serie.weight;
        final ripetizioni = serie.reps;

        /*
         * ⚠️ **Serve che ci siano tutte e due.** Una serie a corpo libero ha
         * le ripetizioni e non il peso: contarla come `reps × 0` non cambia il
         * totale, ma accenderebbe `conKg` — e la card scriverebbe «0 kg» a chi
         * fa solo trazioni.
         */
        if (peso == null || peso <= 0 || ripetizioni == null) continue;

        kg += peso * ripetizioni;
        conKg = true;
      }
    }

    final d = v.distanzaMetri;

    if (d != null && d > 0) {
      metri += d;
      conMetri = true;
    }

    /*
     * 🚨 La catena di priorità sta in `VoceStorico.kcal`, in un posto solo: la
     * usa anche il conto di quanto sei allenato, e due copie divergerebbero
     * alla prima modifica.
     */
    final k = v.kcal;

    if (k != null && k > 0) {
      kcal += k;
      conKcal = true;
    }
  }

  return MeseInNumeri(
    sessioni: sessioni,
    kgSollevati: conKg ? kg : null,
    metri: conMetri ? metri : null,
    kcal: conKcal ? kcal : null,
  );
}

final numeriDelMeseProvider = Provider.family<MeseInNumeri, DateTime>((
  ref,
  mese,
) {
  final voci = ref.watch(storicoUnificatoProvider).valueOrNull ?? const [];

  return numeriDelMese(
    voci.where(
      (v) => v.quando.year == mese.year && v.quando.month == mese.month,
    ),
  );
});
