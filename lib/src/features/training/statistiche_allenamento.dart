import '../health/tipo_allenamento.dart';

/// I numeri di un allenamento, ricavati da quello che l'orologio ha scritto —
/// 08/09/2026.
///
/// ══ 📌 LA RICHIESTA ═══════════════════════════════════════════════════════
///
/// Il committente: *«nella pagina di riassunto dell'esercizio ci devono essere
/// tutti i dati dell'allenamento, quindi tempo velocità media inclinazione passo
/// medio per minuto e tutte queste cose qui»*.
///
/// ══ 🚨 COSA C'E' E COSA NO, MISURATO E NON SUPPOSTO ══════════════════════
///
/// L'08/09/2026 una sonda ha guardato Health Connect sul telefono del
/// committente, novanta giorni:
///
/// | Dato | Esito |
/// |---|---|
/// | `WORKOUT` (durata, distanza, passi, kcal) | ✅ c'è |
/// | `HEART_RATE` | ✅ un campione **al minuto** |
/// | `DISTANCE_DELTA` | ✅ 235 campioni |
/// | `SPEED` | ⛔ **nessun campione** |
/// | `FLIGHTS_CLIMBED` | ⛔ **nessun campione** |
/// | `ELEVATION_GAINED` | ⛔ il pacchetto `health` **non lo espone affatto** |
///
/// 💡 Quindi la velocità **si calcola**, non si legge: distanza diviso tempo. E
/// va bene così — la media è esattamente quello che si vuole in un riassunto.
///
/// ⛔ **L'inclinazione invece qui non c'è, e non è un rinvio pigro.** L'unica
/// fonte possibile sono le **quote dei punti del percorso**, e il percorso
/// Health Connect lo tiene dietro un consenso che si concede a mano. Finché non
/// arriva, questa classe non ha un campo `dislivello` — perché un campo che
/// vale sempre `null` si legge come «l'orologio non lo manda», che è una
/// diagnosi sbagliata di un problema diverso.
class StatisticheAllenamento {
  const StatisticheAllenamento({
    required this.tipo,
    required this.durata,
    this.distanzaMetri,
    this.passi,
    this.kcal,
    this.battitoMedio,
    this.battitoMassimo,
  });

  /// Il codice originale: `RUNNING`, `BIKING`, `STRENGTH_TRAINING`.
  ///
  /// 🚨 **Serve al calcolo, non solo all'etichetta.** Il passo al km su una
  /// pedalata e la cadenza su una nuotata sono numeri veri e senza senso: il
  /// tipo è quello che decide **quali** compaiono. Vedi `TipoAllenamento`.
  final String tipo;

  final Duration durata;
  final int? distanzaMetri;
  final int? passi;
  final int? kcal;

  /// La media dei campioni di battito **dentro la finestra dell'allenamento**.
  ///
  /// ⚠️ Non è `MetricaSalute.battitoARiposo`, che è un aggregato del giorno.
  final int? battitoMedio;
  final int? battitoMassimo;

  /// La distanza in km, se ha senso per questo tipo.
  ///
  /// ⛔ **`null` quando il tipo non la prevede, anche se il numero c'è.** Un
  /// orologio scrive spesso qualche centinaio di metri su una seduta di pesi —
  /// i passi fra un attrezzo e l'altro — e mostrarli come «distanza
  /// dell'allenamento» sarebbe una cosa falsa detta con un numero vero.
  double? get km {
    final m = distanzaMetri;

    if (m == null || m <= 0) return null;
    if (!TipoAllenamento.conDistanza(tipo)) return null;

    return m / 1000;
  }

  /// La velocità media in km/h.
  ///
  /// 💡 Si **calcola**: `SPEED` non arriva (vedi la nota in testa). ⚠️ È la media
  /// sull'intera durata, **soste comprese**: è quello che vuol dire «velocità
  /// media di un'uscita», e chiamarla così non inganna nessuno.
  double? get velocitaKmH {
    final d = km;

    if (d == null || durata.inSeconds <= 0) return null;

    return d / (durata.inSeconds / 3600);
  }

  /// Il passo, come tempo per fare un chilometro.
  ///
  /// 🚨 **Solo a piedi.** In bici il passo al km non lo guarda nessuno: si guarda
  /// la velocità, ed è lo stesso dato girato. ⛔ Mostrarli tutti e due sempre
  /// vorrebbe dire due righe che dicono la stessa cosa, e chi legge cerca la
  /// differenza.
  Duration? get passoAlKm {
    final d = km;

    if (d == null || d <= 0) return null;
    if (!TipoAllenamento.aPiedi(tipo)) return null;

    return Duration(seconds: (durata.inSeconds / d).round());
  }

  /// I passi al minuto — la cadenza.
  ///
  /// 📌 Il committente: *«passo medio per minuto»*.
  ///
  /// 💡 Una camminata sta intorno ai 100-120, una corsa ai 160-180: è il numero
  /// che dice **come** ti sei mosso, non solo quanto.
  double? get cadenzaAlMinuto {
    final p = passi;

    if (p == null || p <= 0 || durata.inSeconds <= 0) return null;
    if (!TipoAllenamento.aPiedi(tipo)) return null;

    return p / (durata.inSeconds / 60);
  }

  /// La lunghezza media del passo, in metri.
  ///
  /// ⚠️ **Misurata, non stimata** — ed è la differenza che conta: la stima delle
  /// calorie del cammino usa `0.415 × altezza`, che è una media di popolazione.
  /// Qui distanza e passi vengono tutti e due dall'orologio, quindi questo è il
  /// passo **suo**.
  double? get lunghezzaDelPasso {
    final m = distanzaMetri;
    final p = passi;

    if (m == null || p == null || p <= 0) return null;
    if (!TipoAllenamento.aPiedi(tipo)) return null;

    final lunghezza = m / p;

    /*
     * ⛔ Fuori da questa banda non è un passo: è una distanza che l'orologio ha
     * attribuito a una sessione in cui i passi contati sono altra cosa — tipico
     * di una pedalata registrata con il telefono in tasca. 🚨 Un «passo da 3,4
     * metri» è un numero che nessuno controlla e che rende sospetto tutto il
     * resto della pagina.
     */
    if (lunghezza < 0.3 || lunghezza > 2.5) return null;

    return lunghezza;
  }

  /// Le calorie per minuto: quanto è stato intenso, a parità di durata.
  ///
  /// 💡 Serve a confrontare due allenamenti di lunghezza diversa, che è la cosa
  /// che le calorie totali da sole non lasciano fare.
  double? get kcalAlMinuto {
    final k = kcal;

    if (k == null || k <= 0 || durata.inMinutes <= 0) return null;

    return k / durata.inMinutes;
  }

  /// Se c'è abbastanza per riempire una scheda di riassunto.
  ///
  /// ⛔ **Senza questo la pagina disegnerebbe un riquadro vuoto** su una seduta
  /// di pesi senza calorie: un titolo, una cornice e niente dentro si legge come
  /// un guasto, non come «di questo non sappiamo niente».
  bool get qualcosaDaDire =>
      km != null || cadenzaAlMinuto != null || battitoMedio != null;
}
