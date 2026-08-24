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
    this.minuti,
    this.serie,
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

  /// I minuti passati ad allenarsi, sommati su tutte le sessioni.
  ///
  /// ⚠️ `null` — e non `0` — quando nessuna sessione ha una durata: sono due
  /// affermazioni diverse, come per i chili e i chilometri.
  final int? minuti;

  /// Le serie registrate nell'app.
  ///
  /// ⛔ `null` per chi non registra le serie, che è il caso di chi usa solo
  /// l'orologio: «0 serie» direbbe che non ne ha fatte, e non è vero — è che
  /// non le ha scritte.
  final int? serie;

  bool get eVuoto => sessioni == 0;
}

/// Quante sessioni per ciascuno degli ultimi [quanti] mesi, dal più vecchio.
///
/// 📌 Il committente: *«ci puoi mettere anche sotto un grafico dentro a un altro
/// rettangolo bianco con il confronto degli allenamenti degli ultimi x mesi»*.
///
/// 🚨 **I mesi vuoti ci sono lo stesso, con zero.** ⛔ Saltarli farebbe un
/// grafico dove due colonne vicine sono maggio e settembre: l'occhio legge una
/// continuità che non c'è, e un mese in cui non ti sei allenato **è
/// un'informazione**, forse la più importante del grafico.
///
/// ⚠️ Qui lo zero è **giusto**, al contrario di «0 km»: la domanda è «quante
/// sessioni a giugno», e la risposta *è* zero. Non è un dato mancante.
List<({DateTime mese, int sessioni})> sessioniPerMese(
  Iterable<VoceStorico> voci, {
  required DateTime fino,
  int quanti = 6,
}) {
  final mesi = <DateTime>[
    for (var i = quanti - 1; i >= 0; i--) DateTime(fino.year, fino.month - i),
  ];

  final conteggio = {for (final m in mesi) m: 0};

  for (final v in voci) {
    final m = DateTime(v.quando.year, v.quando.month);

    if (!conteggio.containsKey(m)) continue;

    conteggio[m] = conteggio[m]! + 1;
  }

  return [for (final m in mesi) (mese: m, sessioni: conteggio[m]!)];
}

/// Il grafico degli ultimi sei mesi, fino al mese scelto.
final sessioniPerMeseProvider =
    Provider.family<List<({DateTime mese, int sessioni})>, DateTime>((
      ref,
      mese,
    ) {
      final voci = ref.watch(storicoUnificatoProvider).valueOrNull ?? const [];

      return sessioniPerMese(voci, fino: mese);
    });

/// I numeri del mese di una data.
MeseInNumeri numeriDelMese(Iterable<VoceStorico> voci) {
  var sessioni = 0;
  var kg = 0.0;
  var conKg = false;
  var metri = 0;
  var conMetri = false;
  var kcal = 0;
  var conKcal = false;
  var minuti = 0;
  var conMinuti = false;
  var serie = 0;
  var conSerie = false;

  for (final v in voci) {
    sessioni++;

    final durata = v.durata.inMinutes;

    if (durata > 0) {
      minuti += durata;
      conMinuti = true;
    }

    for (final seduta in v.sedute) {
      if (seduta.sets.isNotEmpty) {
        serie += seduta.sets.length;
        conSerie = true;
      }

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
    minuti: conMinuti ? minuti : null,
    serie: conSerie ? serie : null,
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
