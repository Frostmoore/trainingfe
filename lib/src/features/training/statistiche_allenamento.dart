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
/// ══ 🚨 COSA C'E' DAVVERO, MISURATO SUL TELEFONO ══════════════════════════
///
/// | Dato | Esito |
/// |---|---|
/// | `WORKOUT` (durata, distanza, passi, kcal) | ✅ c'è |
/// | `HEART_RATE` | ✅ un campione **al minuto** |
/// | `DISTANCE_DELTA` | ✅ 236 campioni |
/// | `SPEED` | ✅ c'è — **3,792 km/h** sulla camminata delle 10:49 |
/// | `ELEVATION_GAINED` | ✅ c'è — **27 m**, da un canale nativo nostro |
/// | `FLIGHTS_CLIMBED` | ⛔ nessun campione, e non serve: il dislivello lo dice l'altro |
///
/// ══ ⛔ E DUE COSE CHE L'08/09 AVEVO SCRITTO QUI, SBAGLIATE ════════════════
///
/// 🚨 Qui c'era scritto *«`SPEED` nessun campione»* e *«la velocità si calcola,
/// non si legge»*. **Falso**: la velocità l'orologio la scrive, e quello zero
/// misurava **una porta chiusa da noi** — `READ_SPEED` non era nel manifest.
/// ⚠️ È lo stesso errore dei 23.471 passi: uno zero letto come una risposta di
/// chi sta dall'altra parte.
///
/// 🚨 E c'era scritto che l'inclinazione poteva venire **solo dalle quote del
/// percorso**. Anche questo è falso: `ElevationGainedRecord` esiste ed è pieno.
/// ⛔ Non lo espone il pacchetto `health`, ed era quello il problema — non il
/// dato. Adesso lo legge `SaluteInPiu`, e **non dipende dal consenso del
/// percorso**.
class StatisticheAllenamento {
  const StatisticheAllenamento({
    required this.tipo,
    required this.durata,
    this.distanzaMetri,
    this.passi,
    this.kcal,
    this.battitoMedio,
    this.battitoMassimo,
    this.velocitaMisurataMs,
    this.dislivelloMetri,
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

  /// La velocità media **come la dice l'orologio**, in metri al secondo.
  ///
  /// ══ 🚨 PERCHE' NON BASTA DIVIDERE DISTANZA PER TEMPO ══════════════════════
  ///
  /// 📌 Il committente, l'08/09: *«dovremo usare i dati dell'orologio, perché
  /// presumibilmente tiene da conto il fatto che mi sono fermato 10 minuti al
  /// bar e la discrepanza arriva da quello»*.
  ///
  /// ⛔ Sulla camminata delle 10:49: 1,27 km in 27 minuti danno **2,8 km/h**;
  /// l'orologio dice **3,79 km/h**. 🚨 Il 34% di scarto, e due numeri per la
  /// stessa cosa nella stessa pagina.
  ///
  /// 💡 La sua media è sul **tempo in movimento**, la nostra su tutta la durata.
  /// La sua è quella che risponde alla domanda «a che andatura ho camminato».
  final double? velocitaMisurataMs;

  /// I metri saliti, da `ElevationGainedRecord`.
  ///
  /// ⛔ **Non si legge col pacchetto `health`**, che quel tipo non lo conosce
  /// affatto: arriva da un canale nativo nostro. Vedi `SaluteInPiu`.
  ///
  /// 🚨 **`null` e non `0`**: zero è una pianura, l'assenza è «non lo sappiamo».
  final double? dislivelloMetri;

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

  /// Se la velocità che mostriamo l'ha misurata l'orologio.
  ///
  /// 🚨 **Serve a schermo, non qui**: una media sul tempo in movimento e una
  /// sulla durata totale sono due grandezze diverse, e chi legge deve poter
  /// sapere quale sta guardando. ⛔ Mostrarle con la stessa etichetta è il modo
  /// di far sembrare sbagliato il numero giusto.
  bool get velocitaDallOrologio => velocitaMisurataMs != null;

  /// La velocità media in km/h — **quella dell'orologio, quando c'è**.
  ///
  /// ⚠️ Il calcolo resta come **ripiego**, e comprende le soste: è quello che
  /// vuol dire «media sull'uscita», ed è un numero più basso.
  double? get velocitaKmH {
    final misurata = velocitaMisurataMs;

    if (misurata != null && misurata > 0) return misurata * 3.6;

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
    if (!TipoAllenamento.aPiedi(tipo)) return null;

    /*
     * ⚠️ **Dalla stessa fonte della velocità, sempre.** Il passo è la velocità
     * girata: prenderlo dal calcolo mentre la velocità viene dall'orologio
     * darebbe due numeri che si contraddicono a vicenda nella stessa card —
     * «3,79 km/h» accanto a «21:15 /km», che è il passo di 2,8 km/h.
     */
    final v = velocitaKmH;

    if (v == null || v <= 0) return null;

    return Duration(seconds: (3600 / v).round());
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
     * ══ 🚨 LA BANDA E' STATA ALZATA DOPO UNA MISURA VERA ═══════════════════
     *
     * ⛔ Era `0.3`, e la camminata dell'08/09 l'ha attraversata indisturbata:
     * 1.270 m di GPS contro 3.523 passi fanno **36 cm a falcata**. 🚨 Non è un
     * passo corto: è la prova che le due fonti **non sono d'accordo fra loro**
     * — un adulto che cammina sta fra 65 e 85 cm.
     *
     * 💡 Il pavimento a **mezzo metro** non nasconde una misura scomoda: toglie
     * un numero che non descrive nessuno. ⚠️ Chi cammina davvero con falcate da
     * 40 cm è una persona molto bassa o molto lenta — e in quel caso il
     * rapporto sarebbe *stabile*, mentre qui è l'effetto di un GPS che ha perso
     * strada.
     *
     * 🚨 **E il tetto resta a 2,5 m**: quello serve al caso opposto, la
     * pedalata registrata col telefono in tasca, dove i «passi» sono
     * l'oscillazione del polso.
     */
    if (lunghezza < 0.5 || lunghezza > 2.5) return null;

    return lunghezza;
  }

  /// Il passo scritto come si legge: `5:42`.
  ///
  /// ⚠️ **Sta qui e non nel widget che lo mostra**, ed è la lezione di
  /// stamattina: quando il passo veniva calcolato in due posti, la pagina ne
  /// mostrava due diversi — 21:16 nel carosello e 15:43 nella card. 🚨 Un
  /// numero solo vuol dire anche **un posto solo** in cui diventa testo.
  ///
  /// 💡 I secondi hanno sempre due cifre: `6:5` si legge come sei minuti e
  /// cinque decimi.
  static String passoScritto(Duration passo) =>
      '${passo.inMinutes}:${(passo.inSeconds % 60).toString().padLeft(2, '0')}';

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
      km != null ||
      cadenzaAlMinuto != null ||
      battitoMedio != null ||
      dislivelloMetri != null;
}
