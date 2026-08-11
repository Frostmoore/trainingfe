import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../../core/storage/archivio_salute.dart';
import 'dati_salute.dart';

/// Il ponte fra il telefono e l'archivio locale — S3.3.
///
/// 🚨 **I dati entrano da qui e non escono più.** Prima di S1 esisteva
/// `POST /health/ingest`, che mandava sonno e parametri vitali al server: quel
/// canale **non esiste più** (decisione D9 di `todo-2026-08-11.md`). Questo
/// ponte scrive **solo** in `ArchivioSalute`, che vive sul telefono.
///
/// ⚠️ Chi in futuro aggiungesse qui una chiamata di rete starebbe annullando
/// l'intera fase di sicurezza. Non è una svista possibile: è il punto in cui
/// bisogna fermarsi e rileggere §C11.
///
/// **Cosa legge**: HRV, battito a riposo e le fasi del sonno. Non le calorie
/// bruciate — quelle sono attività, non un parametro del corpo, e restano un
/// problema di S5.
class PonteSalute {
  PonteSalute(this._archivio, {Health? salute}) : _salute = salute ?? Health();

  final ArchivioSalute _archivio;
  final Health _salute;

  /// I tipi che chiediamo. Meno se ne chiedono, più è probabile che vengano
  /// concessi: ogni voce in più in quella schermata è un motivo per dire di no.
  static const _tipi = <HealthDataType>[
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_AWAKE,
  ];

  /// 🚨 **Solo lettura.** Non scriviamo niente in Health Connect: l'app non ha
  /// nessun motivo per farlo, e chiedere il permesso di scrittura raddoppierebbe
  /// la superficie del consenso in cambio di niente.
  static final _permessi = List<HealthDataAccess>.filled(
    _tipi.length,
    HealthDataAccess.READ,
  );

  /// Chiede i permessi. `false` se la persona ha detto di no, o se il telefono
  /// non ha Health Connect.
  ///
  /// ⚠️ **Non si chiama all'avvio.** Chiedere un permesso prima che l'utente
  /// abbia capito a cosa serve è il modo più rapido per farselo negare **per
  /// sempre**: su Android un rifiuto ripetuto rende il dialogo non più
  /// riproponibile. Si chiama dalla schermata che lo spiega (S3.4).
  Future<bool> chiediPermessi() async {
    try {
      await Health().configure();

      final gia = await _salute.hasPermissions(_tipi, permissions: _permessi);

      if (gia ?? false) return true;

      return await _salute.requestAuthorization(_tipi, permissions: _permessi);
    } on Object catch (errore, stack) {
      // Un telefono senza Health Connect non è un errore da mostrare: è una
      // funzione che quel telefono non ha.
      debugPrintStack(label: 'PonteSalute.chiediPermessi: $errore', stackTrace: stack);
      return false;
    }
  }

  /// Legge dal telefono e scrive nell'archivio. Torna quanti campioni sono
  /// entrati davvero (i duplicati e gli implausibili non contano).
  ///
  /// ⚠️ **Rilegge sempre una finestra intera, non solo il nuovo.** È il motivo
  /// per cui l'archivio ha gli indici univoci: un sensore può consegnare in
  /// ritardo un campione di ieri, e chiedere «solo da adesso in poi»
  /// significherebbe perderlo per sempre.
  ///
  /// 🚨 **`giorniIndietro` di serie è 7, ma Health Connect ne concede ~30** e
  /// oltre serve un permesso a parte che Google dà con parsimonia. Quindi:
  /// la prima sincronizzazione prende quel che può, e **da lì in poi la memoria
  /// lunga è l'archivio locale**, che accumula. La media di riferimento a sette
  /// giorni esiste solo dopo sette giorni di app installata — non è un difetto,
  /// ma va detto a chi la usa o sembrerà che la funzione non parta.
  Future<int> sincronizza({int giorniIndietro = 7}) async {
    final a = DateTime.now();
    final da = a.subtract(Duration(days: giorniIndietro));

    final List<HealthDataPoint> punti;

    try {
      punti = await _salute.getHealthDataFromTypes(
        types: _tipi,
        startTime: da,
        endTime: a,
      );
    } on Object catch (errore, stack) {
      debugPrintStack(label: 'PonteSalute.sincronizza: $errore', stackTrace: stack);
      return 0;
    }

    final letture = <LetturaSalute>[];
    final campioni = <CampioneSonno>[];

    for (final punto in punti) {
      final metrica = _metricaDi(punto.type);

      if (metrica != null) {
        final valore = _numero(punto.value);
        if (valore == null) continue;

        letture.add(LetturaSalute(
          id: 0,
          fonte: _fonte(punto),
          metrica: metrica.codice,
          misurataIl: punto.dateFrom,
          giorno: DateTime(punto.dateFrom.year, punto.dateFrom.month, punto.dateFrom.day),
          valore: valore,
        ));

        continue;
      }

      final fase = _faseDi(punto.type);

      if (fase != null) {
        campioni.add(CampioneSonno(
          id: 0,
          fonte: _fonte(punto),
          notte: notteDi(punto.dateFrom),
          iniziatoIl: punto.dateFrom,
          finitoIl: punto.dateTo,
          fase: fase.codice,
        ));
      }
    }

    final a1 = await _archivio.scriviLetture(letture);
    final a2 = await _archivio.scriviCampioniSonno(campioni);

    return a1 + a2;
  }

  static String _fonte(HealthDataPoint punto) {
    final nome = punto.sourceName.trim();

    return nome.isEmpty ? 'health' : nome.substring(0, nome.length.clamp(0, 32));
  }

  static double? _numero(HealthValue valore) =>
      valore is NumericHealthValue ? valore.numericValue.toDouble() : null;

  static MetricaSalute? _metricaDi(HealthDataType tipo) => switch (tipo) {
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD => MetricaSalute.hrv,
    HealthDataType.RESTING_HEART_RATE => MetricaSalute.battitoARiposo,
    HealthDataType.HEART_RATE => MetricaSalute.battitoMedio,
    _ => null,
  };

  /// ⚠️ `SLEEP_ASLEEP` è la fase «dorme ma non sappiamo come»: la si conta come
  /// **leggero**, che è il comportamento del vecchio `SleepStage`. Non come
  /// profondo: sarebbe la lettura più generosa proprio dove serve prudenza.
  static FaseSonno? _faseDi(HealthDataType tipo) => switch (tipo) {
    HealthDataType.SLEEP_DEEP => FaseSonno.profondo,
    HealthDataType.SLEEP_REM => FaseSonno.rem,
    HealthDataType.SLEEP_LIGHT || HealthDataType.SLEEP_ASLEEP => FaseSonno.leggero,
    HealthDataType.SLEEP_AWAKE => FaseSonno.sveglio,
    _ => null,
  };
}
