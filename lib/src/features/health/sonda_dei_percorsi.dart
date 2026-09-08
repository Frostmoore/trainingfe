import 'package:health/health.dart';

/// 🔬 I percorsi degli allenamenti arrivano? — 08/09/2026.
///
/// ══ 📌 PERCHE' ESISTE ═════════════════════════════════════════════════════
///
/// Il committente: *«quando scelgo come esercizio camminata, hiking,
/// bicicletta… se non metto la foto, al posto di quella nella schermata dello
/// storico degli allenamenti ci deve essere la forma del percorso che ho
/// fatto»*.
///
/// ⛔ **Non si costruisce niente prima di sapere se il percorso arriva.** È la
/// lezione delle calorie attive: il 07/09 una sonda ha scoperto che l'orologio
/// non le scrive **affatto**, dopo che tre commenti nel codice davano per
/// scontato che ci fossero.
///
/// ══ 🚨 COSA SI SA GIA', E VIENE DALLA DOCUMENTAZIONE DEL PACCHETTO ════════
///
/// > *«Android only surfaces routes while your app is in the foreground, and
/// > other apps' routes may return a `ConsentRequired` flag. Today (Health
/// > Connect 1.1.0) the system does not expose the `ExerciseRouteRequestContract`
/// > documented by Google, so the only way to read third-party routes is to have
/// > the user manually grant "Always allow" for Exercise routes inside the
/// > Health Connect app.»*
///
/// ⚠️ Quindi i risultati possibili sono **tre**, non due, e vanno distinti:
///
/// | Esito | Cosa vuol dire |
/// |---|---|
/// | `punti: N` | ✅ Il percorso c'è e lo leggiamo |
/// | `SERVE IL CONSENSO` | ⚠️ Il percorso **esiste**, ma Health Connect non ce lo dà finché la persona non concede «Consenti sempre» a mano |
/// | nessuna riga | ⛔ L'app dell'orologio il percorso non lo scrive proprio |
///
/// 🚨 **Il secondo e il terzo caso si somigliano e non sono la stessa cosa**: nel
/// secondo il lavoro si può fare e basta spiegarlo, nel terzo non si può fare.
///
/// ── Come si accende ───────────────────────────────────────────────────────
///
///     flutter build apk --release --dart-define=ENV=staging \
///         --dart-define=DIAGNOSTICA=percorsi
///     adb logcat -d | grep "PERCORSI|"
class SondaDeiPercorsi {
  const SondaDeiPercorsi([this._salute]);

  final Health? _salute;

  static const accesa = String.fromEnvironment('DIAGNOSTICA') == 'percorsi';

  /// Quanti giorni indietro guardare.
  ///
  /// 🚨 **Novanta e non due.** Le sonde di ieri guardavano due giorni perché
  /// cercavano dati continui — passi, battito — che ci sono tutti i giorni. ⛔ Un
  /// giro in bici all'aperto no: cercarlo in quarantott'ore vuol dire quasi
  /// sicuramente non trovarne nessuno, e leggere quello zero come «i percorsi non
  /// arrivano» sarebbe la conclusione sbagliata dal dato giusto.
  static const giorni = 90;

  Future<void> racconta() async {
    if (!accesa) return;

    final salute = _salute ?? Health();

    await salute.configure();

    final adesso = DateTime.now();
    final da = adesso.subtract(const Duration(days: giorni));

    _riga('══════ ultimi $giorni giorni ══════');

    /*
     * 🚨 **`WORKOUT` va chiesto insieme a `WORKOUT_ROUTE`**, e il pacchetto lo
     * aggiunge da solo (`_handleWorkoutRoute`). Lo mettiamo comunque esplicito:
     * una dipendenza che si vede è una dipendenza che si può rompere ad occhi
     * aperti.
     */
    const tipi = [
      HealthDataType.WORKOUT,
      HealthDataType.WORKOUT_ROUTE,
      HealthDataType.SPEED,
      HealthDataType.DISTANCE_DELTA,
    ];

    final concessi = await salute.hasPermissions(tipi) ?? false;

    _riga('permessi: $concessi');

    if (!concessi) {
      _riga('li chiedo — sblocca il telefono');

      await salute.requestAuthorization(tipi);
    }

    await _allenamenti(salute, da, adesso);
    await _percorsi(salute, da, adesso);
    await _iDatiPerLeStatistiche(salute, da, adesso);

    _riga('══════ fine ══════');
  }

  /// Cosa c'è, come allenamenti, in cui un percorso potrebbe stare.
  ///
  /// 💡 Serve al confronto: *«tre uscite in bici, zero percorsi»* è una risposta;
  /// *«zero percorsi»* da solo non lo è, perché non distingue «non li scrive» da
  /// «non sei uscito».
  Future<void> _allenamenti(Health salute, DateTime da, DateTime a) async {
    final punti = await _leggi(salute, HealthDataType.WORKOUT, da, a);

    if (punti.isEmpty) {
      _riga('ALLENAMENTI nessuno in $giorni giorni');

      return;
    }

    _riga('ALLENAMENTI ${punti.length}');

    final perTipo = <String, int>{};

    for (final p in punti) {
      final v = p.value;

      if (v is! WorkoutHealthValue) continue;

      final tipo = v.workoutActivityType.name;

      perTipo[tipo] = (perTipo[tipo] ?? 0) + 1;

      /*
       * ⚠️ Si stampano **tutti** quelli all'aperto, con i loro numeri: sono
       * esattamente quelli su cui la richiesta del committente vive, e i campi
       * che escono qui sono quelli con cui si potranno calcolare le statistiche.
       */
      if (!_allAperto.contains(tipo)) continue;

      _riga(
        '  ${_data(p.dateFrom)} $tipo · '
        '${p.dateTo.difference(p.dateFrom).inMinutes} min · '
        'm ${v.totalDistance ?? "-"} · '
        'kcal ${v.totalEnergyBurned ?? "-"} · '
        'passi ${v.totalSteps ?? "-"}',
      );
    }

    _riga('  per tipo: $perTipo');
  }

  Future<void> _percorsi(Health salute, DateTime da, DateTime a) async {
    final punti = await _leggi(salute, HealthDataType.WORKOUT_ROUTE, da, a);

    if (punti.isEmpty) {
      /*
       * ⛔ **Questo è il caso che chiude la richiesta**, e va detto così: se non
       * torna nemmeno una riga, l'app dell'orologio i percorsi non li scrive, e
       * la forma del percorso non si può disegnare — non «è difficile».
       */
      _riga('PERCORSI nessuno — né dati né richieste di consenso');

      return;
    }

    _riga('PERCORSI ${punti.length}');

    for (final p in punti) {
      final v = p.value;

      if (v is! WorkoutRouteHealthValue) {
        _riga('  ${_data(p.dateFrom)} valore inatteso: ${v.runtimeType}');

        continue;
      }

      final quanti = v.locations.length;

      if (quanti == 0) {
        // ⚠️ Zero punti con un valore presente = la richiesta di consenso.
        _riga('  ${_data(p.dateFrom)} SERVE IL CONSENSO · id ${p.uuid}');

        continue;
      }

      final primo = v.locations.first;
      final conQuota = v.locations.where((l) => l.altitude != null).length;

      _riga(
        '  ${_data(p.dateFrom)} punti $quanti · '
        'con quota $conQuota · '
        'primo ${primo.latitude.toStringAsFixed(4)},'
        '${primo.longitude.toStringAsFixed(4)}',
      );
    }
  }

  /// Cosa c'è per le statistiche, oltre al percorso.
  ///
  /// 📌 *«ci devono essere tutti i dati dell'allenamento, quindi tempo velocità
  /// media inclinazione passo medio per minuto»*.
  ///
  /// 💡 Tempo, velocità media e passo si ricavano da durata e distanza, che
  /// abbiamo già. ⚠️ **L'inclinazione no**: serve la quota, e quella sta o nei
  /// punti del percorso o in `FLIGHTS_CLIMBED`. Qui si guarda se il secondo c'è.
  Future<void> _iDatiPerLeStatistiche(
    Health salute,
    DateTime da,
    DateTime a,
  ) async {
    for (final (tipo, nome) in const [
      (HealthDataType.FLIGHTS_CLIMBED, 'PIANI'),
      (HealthDataType.SPEED, 'VELOCITA'),
      (HealthDataType.DISTANCE_DELTA, 'DISTANZA'),
    ]) {
      final punti = await _leggi(salute, tipo, da, a);

      _riga(
        punti.isEmpty
            ? '$nome nessun campione'
            : '$nome ${punti.length} campioni · '
                  'fonti: ${punti.map((p) => p.sourceId).toSet().join(", ")}',
      );
    }
  }

  /// I tipi per cui un percorso ha senso.
  ///
  /// ⛔ Una seduta di pesi un percorso non ce l'ha, e chiederlo non è innocuo:
  /// sarebbe una riga vuota in un elenco diagnostico, cioè rumore che somiglia a
  /// un'assenza.
  static const _allAperto = {
    'WALKING',
    'RUNNING',
    'BIKING',
    'HIKING',
    'SWIMMING_OPEN_WATER',
    'ROWING',
    'SKIING',
    'SNOWBOARDING',
    'SKATING',
    'OTHER',
  };

  Future<List<HealthDataPoint>> _leggi(
    Health salute,
    HealthDataType tipo,
    DateTime da,
    DateTime a,
  ) async {
    try {
      return await salute.getHealthDataFromTypes(
        types: [tipo],
        startTime: da,
        endTime: a,
      );
    } on Object catch (errore) {
      _riga('${tipo.name}: errore — $errore');

      return const [];
    }
  }

  String _data(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';

  // ignore: avoid_print
  void _riga(String testo) => print('PERCORSI| $testo');
}
