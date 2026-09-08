import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Un punto del tracciato di un allenamento — 08/09/2026.
@immutable
class PuntoDelPercorso {
  const PuntoDelPercorso({
    required this.latitudine,
    required this.longitudine,
    required this.istante,
    this.quotaMetri,
  });

  final double latitudine;
  final double longitudine;
  final DateTime istante;

  /// ⚠️ **Può mancare punto per punto**, non solo per tutto il percorso: il GPS
  /// la quota la perde e la ritrova. 🚨 Riempirla con uno zero appiattirebbe una
  /// salita.
  final double? quotaMetri;

  Map<String, dynamic> versoIlDato() => {
    'lat': latitudine,
    'lon': longitudine,
    'istante': istante.millisecondsSinceEpoch,
    if (quotaMetri != null) 'quota': quotaMetri,
  };

  static PuntoDelPercorso? dalDato(Object? dato) {
    if (dato is! Map) return null;

    final lat = (dato['lat'] as num?)?.toDouble();
    final lon = (dato['lon'] as num?)?.toDouble();
    final istante = (dato['istante'] as num?)?.toInt();

    if (lat == null || lon == null || istante == null) return null;

    return PuntoDelPercorso(
      latitudine: lat,
      longitudine: lon,
      istante: DateTime.fromMillisecondsSinceEpoch(istante),
      quotaMetri: (dato['quota'] as num?)?.toDouble(),
    );
  }
}

/// Com'è andata la richiesta di un percorso.
enum EsitoDelPercorso {
  /// ✅ La persona ha detto di sì e i punti sono arrivati.
  concesso,

  /// ⛔ Ha chiuso la finestra o ha detto di no. **Non è un errore.**
  rifiutato,

  /// ⚠️ Non si è potuto nemmeno chiedere: id mancante, canale non registrato,
  /// una richiesta già aperta.
  nonChiesto,
}

/// L'esito, con dentro i punti se ci sono.
@immutable
class RispostaDelPercorso {
  const RispostaDelPercorso(this.esito, [this.punti = const []]);

  final EsitoDelPercorso esito;
  final List<PuntoDelPercorso> punti;
}

/// 🩺 Le due cose di Health Connect che il pacchetto `health` non sa fare.
///
/// ══ 📌 PERCHE' ESISTE ═════════════════════════════════════════════════════
///
/// 📌 *«ci deve essere la forma del percorso che ho fatto»* e *«tempo velocità
/// media inclinazione…»*.
///
/// 🚨 **I dati ci sono tutti e due, misurati l'08/09 sul telefono del
/// committente**: Health Connect mostra **27 m** di dislivello per la camminata
/// delle 10:49 e ne disegna la forma. ⛔ A mancare era la strada:
///
/// | Dato | Perché il pacchetto `health` non lo dà |
/// |---|---|
/// | Percorso | Torna sempre `ConsentRequired`, e il modo di chiedere il consenso non lo espone |
/// | Dislivello | `ElevationGainedRecord` **non è fra i tipi che conosce** |
///
/// 💡 Il lato nativo sta in `android/app/src/main/kotlin/.../SaluteInPiu.kt`.
///
/// ⚠️ **Solo Android.** Su iOS non c'è niente dall'altra parte del canale: i
/// metodi rispondono «non chiesto» e `null`, che è il comportamento giusto —
/// vedi §6 del piano, iOS è tutto dopo.
class SaluteInPiu {
  const SaluteInPiu([this._canale = const MethodChannel(_nome)]);

  static const _nome = 'mytrainingcompanion/salute_in_piu';

  final MethodChannel _canale;

  /// Chiede alla persona il percorso di **una** sessione.
  ///
  /// ══ 🚨 SI APRE UNA FINESTRA DI SISTEMA, E VA SAPUTO ══════════════════════
  ///
  /// ⛔ **Non è una lettura silenziosa**: Health Connect mostra la mappa del
  /// tracciato e chiede se condividerlo. 🚨 Quindi questa non si chiama mai da
  /// sola — la chiama un gesto della persona, e mai una sincronizzazione.
  ///
  /// ⚠️ **E funziona solo con l'app in primo piano.** Google: *«when your app
  /// runs in the background … Health Connect returns ConsentRequired, even if
  /// your app has Always allow»*.
  Future<RispostaDelPercorso> percorso(String idSessione) async {
    if (idSessione.isEmpty) {
      return const RispostaDelPercorso(EsitoDelPercorso.nonChiesto);
    }

    try {
      final fuori = await _canale.invokeMethod<List<Object?>>('percorso', {
        'id': idSessione,
      });

      /*
       * 🚨 **`null` è il «no» della persona, e non un guasto.** Il lato nativo
       * risponde `success(null)` quando la finestra si chiude senza concedere:
       * trattarlo come errore vorrebbe dire un messaggio rosso su una scelta
       * legittima.
       */
      if (fuori == null) {
        return const RispostaDelPercorso(EsitoDelPercorso.rifiutato);
      }

      final punti = fuori
          .map(PuntoDelPercorso.dalDato)
          .whereType<PuntoDelPercorso>()
          .toList();

      /*
       * ⚠️ **Una lista vuota è un rifiuto, non un percorso vuoto.** Un tracciato
       * senza punti non esiste: se il consenso fosse stato dato e i punti non
       * ci fossero, il record del percorso non ci sarebbe affatto.
       */
      return punti.isEmpty
          ? const RispostaDelPercorso(EsitoDelPercorso.rifiutato)
          : RispostaDelPercorso(EsitoDelPercorso.concesso, punti);
    } on Object catch (errore) {
      debugPrint('percorso: non si è potuto chiedere — $errore');

      return const RispostaDelPercorso(EsitoDelPercorso.nonChiesto);
    }
  }

  /// I metri saliti fra due istanti, sommati.
  ///
  /// ⚠️ **Health Connect scrive tanti record brevi**, non un totale: qui si
  /// sommano quelli che cadono nella finestra.
  ///
  /// 🚨 **`null` e non `0`.** Zero metri di dislivello è una pianura; l'assenza
  /// è «non lo sappiamo» — permesso non concesso, o nessun record. ⛔ Mostrare
  /// «0 m» a chi ha fatto una salita direbbe una cosa falsa con l'aria di una
  /// misura.
  Future<double?> dislivelloFra({
    required DateTime da,
    required DateTime a,
  }) async {
    try {
      final righe = await _canale.invokeMethod<List<Object?>>('dislivello', {
        'da': da.millisecondsSinceEpoch,
        'a': a.millisecondsSinceEpoch,
      });

      if (righe == null || righe.isEmpty) return null;

      var somma = 0.0;

      for (final riga in righe) {
        if (riga is! Map) continue;

        somma += (riga['metri'] as num?)?.toDouble() ?? 0;
      }

      return somma;
    } on Object catch (errore) {
      debugPrint('dislivello: non leggibile — $errore');

      return null;
    }
  }
}
