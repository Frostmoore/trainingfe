import 'package:health/health.dart';

/// Cosa c'è **davvero** dentro Health Connect — strumento, non funzione.
///
/// ══ 📌 PERCHÉ ESISTE ══════════════════════════════════════════════════════
///
/// 📌 Il committente, il 30/08: *«prima di fossilizzarci su solo quei tre valori
/// vediamo cosa passa health connect»*.
///
/// 🚨 **La domanda non si risponde leggendo la documentazione**, e questa classe
/// esiste per dimostrarlo: il pacchetto `health` elenca `BODY_MASS_INDEX` fra i
/// tipi Android, e il plugin nativo **non lo mappa a nessun record** — perché in
/// Health Connect un record «BMI» non esiste. ⛔ Chiederlo non dà errore: dà
/// zero risultati, per sempre.
///
/// ⚠️ **È esattamente il difetto ricorrente di questo progetto**: codice che si
/// legge benissimo, non solleva niente, e non trova mai niente.
///
/// ══ ⛔ NON È UNA FUNZIONE DELL'APP ════════════════════════════════════════
///
/// Gira **solo** con `--dart-define=DIAGNOSTICA=salute`, scrive su `logcat` e
/// non tocca nessun dato. 🚨 Non deve finire in una schermata: chiede permessi
/// su dati sanitari e li elenca, ed è una cosa che facciamo **noi** per
/// decidere, non qualcosa che si offre a chi usa l'app.
///
/// Uso:
///
///     fvm flutter build apk --release \
///       --dart-define=ENV=staging --dart-define=DIAGNOSTICA=salute
///     adb install -r build/app/outputs/flutter-apk/app-release.apk
///     adb logcat -s flutter | grep DIAGNOSTICA
class DiagnosticaSalute {
  const DiagnosticaSalute(this._salute);

  /// 💡 Iniettabile solo per i test: in produzione non gira mai.
  final Health? _salute;

  /// 🚨 **Acceso solo da un `--dart-define`.** Senza, questa classe non gira
  /// mai — e `const` fa sì che il compilatore la tolga del tutto dalle build
  /// normali.
  static const accesa = String.fromEnvironment('DIAGNOSTICA') == 'salute';

  /// **Tutto** quello che il pacchetto dichiara su Android, meno i percorsi.
  ///
  /// ══ 🚨 TUTTO, E NON CINQUE TIPI SCELTI A MANO ═════════════════════════
  ///
  /// 📌 Il committente: *«ci dovrebbe essere una cosa come body measurements
  /// […] metti uno scriptino dart che dice tutto quello che si prende health
  /// connect»*.
  ///
  /// ⚠️ **Aveva ragione, e la prima versione di questo file sbagliava**:
  /// sceglieva cinque tipi che *sembravano* quelli del corpo. ⛔ Scegliere
  /// prima di guardare è esattamente quello che questa diagnostica esiste per
  /// non fare — e «Body measurements» in Health Connect contiene anche massa
  /// ossea, acqua corporea e metabolismo basale, che non erano nella cinquina.
  ///
  /// ══ ⛔ L'UNICA ECCEZIONE, ED È UNA REGOLA DI CASA ════════════════════
  ///
  /// `WORKOUT_ROUTE` **non si chiede mai**, nemmeno per guardare. 🚨 È la traccia GPS: dice dove abiti e che giro fai la domenica,
  /// ed è il dato più identificante che il telefono possieda. La regola sta
  /// scritta in `PonteSalute` dal giorno in cui il ponte è nato, e una
  /// diagnostica non è un motivo per farle un'eccezione.
  static final tuttiITipi = dataTypeKeysAndroid
      .where((t) => t != HealthDataType.WORKOUT_ROUTE)
      .toList(growable: false);

  /// I tipi di «Body measurements», per leggere il risultato con un ordine.
  ///
  /// ⛔ **`BODY_MASS_INDEX` non c'è, e non è una dimenticanza.** Il plugin
  /// Android (`HealthConstants.kt`) non ha **nessuna riga** che lo mappi:
  /// Health Connect non ha un record per il BMI. 💡 Sta nella lista Dart
  /// perché su **iOS** esiste (`HKQuantityTypeIdentifierBodyMassIndex`), e
  /// quella lista non distingue le due piattaforme.
  ///
  /// 🚨 Quindi su Android **il BMI non arriva mai**: si calcola, sempre.
  static const misureDelCorpo = <HealthDataType>{
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.LEAN_BODY_MASS,
    HealthDataType.BODY_WATER_MASS,
    HealthDataType.HEIGHT,
    HealthDataType.BASAL_ENERGY_BURNED,
  };

  /// Quanto indietro si guarda. 💡 Due anni: serve a sapere **se** c'è uno
  /// storico e quanto è fitto, non a importarlo.
  static const mesiIndietro = 24;

  /// Guarda, racconta, e non scrive niente.
  Future<void> racconta() async {
    if (!accesa) return;

    final salute = _salute ?? Health();

    _riga('════════ DIAGNOSTICA HEALTH CONNECT ════════');

    try {
      await salute.configure();
    } on Object catch (e) {
      _riga('⛔ configure() è fallito: $e');

      return;
    }

    /*
     * ⚠️ **Si chiede il permesso anche se forse c'è già.** `requestAuthorization`
     * è idempotente e non ripropone niente a chi ha già concesso: chiederlo è
     * più economico che scoprire, dopo venti righe di «zero record», che il
     * problema era un permesso.
     */
    _riga('Chiedo ${tuttiITipi.length} tipi in un colpo solo.');

    try {
      final concesso = await salute.requestAuthorization(tuttiITipi);

      _riga(
        concesso ? '✅ richiesta accettata' : '⚠️ richiesta rifiutata in blocco',
      );
    } on Object catch (e) {
      /*
       * ⚠️ **Non si esce.** Un `requestAuthorization` che esplode su un tipo
       * non dice niente sugli altri, e magari qualche permesso era già
       * concesso da prima. 💡 Si va avanti e si guarda tipo per tipo: è
       * proprio quello che serve sapere.
       */
      _riga('⚠️ requestAuthorization ha lanciato: $e — vado avanti lo stesso');
    }

    final adesso = DateTime.now();
    final da = DateTime(adesso.year, adesso.month - mesiIndietro, adesso.day);

    /*
     * 💡 **Prima «Body measurements», poi tutto il resto.** È la categoria che
     * interessa a 3b-W, e leggerla in cima a un elenco di quaranta righe è la
     * differenza fra un dato e un muro di testo.
     */
    _riga('──── BODY MEASUREMENTS ────');

    for (final tipo in tuttiITipi.where(misureDelCorpo.contains)) {
      await _raccontaIlTipo(salute, tipo, da, adesso);
    }

    _riga('──── TUTTO IL RESTO ────');

    for (final tipo in tuttiITipi.where((t) => !misureDelCorpo.contains(t))) {
      await _raccontaIlTipo(salute, tipo, da, adesso);
    }

    _riga('════════ FINE ════════');
  }

  Future<void> _raccontaIlTipo(
    Health salute,
    HealthDataType tipo,
    DateTime da,
    DateTime a,
  ) async {
    /*
     * 🚨 **Si distingue «non ho il permesso» da «non c'è niente».**
     *
     * ⛔ Sono due risposte diversissime che si presentano identiche: zero
     * record. Confonderle vorrebbe dire concludere «la bilancia non scrive la
     * massa grassa» quando il vero problema era un permesso mai chiesto — ed è
     * il genere di conclusione sbagliata che poi finisce in un piano.
     */
    bool? permesso;

    try {
      permesso = await salute.hasPermissions([tipo]);
    } on Object {
      permesso = null;
    }

    List<HealthDataPoint> punti;

    try {
      punti = await salute.getHealthDataFromTypes(
        types: [tipo],
        startTime: da,
        endTime: a,
      );
    } on Object catch (e) {
      _riga('${tipo.name}: ⛔ lettura fallita (permesso: $permesso) — $e');

      return;
    }

    if (punti.isEmpty) {
      _riga(
        permesso == true
            ? '${tipo.name}: — nessun dato (permesso OK)'
            : '${tipo.name}: — nessun dato · ⚠️ PERMESSO $permesso',
      );

      return;
    }

    punti.sort((x, y) => x.dateFrom.compareTo(y.dateFrom));

    final primo = punti.first;
    final ultimo = punti.last;

    /*
     * 💡 **Chi li ha scritti conta quanto i numeri.** Sapere che il peso arriva
     * da `com.vt.vitafit` e non da un'app di diete dice se ci si può fidare —
     * e dice quale app disinstallare se un giorno i numeri impazziscono.
     */
    final fonti = punti.map((p) => p.sourceId).toSet();

    /*
     * ⚠️ Quanti giorni **distinti**, non quanti record: tre pesate in un giorno
     * sono un giorno solo, ed è la cadenza che interessa.
     */
    final giorni = punti
        .map((p) => DateTime(p.dateFrom.year, p.dateFrom.month, p.dateFrom.day))
        .toSet()
        .length;

    _riga(
      '${tipo.name}: ${punti.length} record su $giorni giorni · '
      'dal ${_data(primo.dateFrom)} al ${_data(ultimo.dateFrom)} · '
      'ultimo ${_valore(ultimo)} · fonti ${fonti.join(', ')}',
    );

    // 💡 Le ultime cinque, per vedere la forma vera dei numeri.
    for (final p in punti.reversed.take(5)) {
      _riga(
        '    ${_data(p.dateFrom)} ${_ora(p.dateFrom)}  ${_valore(p)}  [${p.sourceId}]',
      );
    }
  }

  String _valore(HealthDataPoint p) {
    final v = p.value;

    return v is NumericHealthValue
        ? '${v.numericValue} ${p.unit.name}'
        : v.toString();
  }

  String _data(DateTime d) => '${d.year}-${_due(d.month)}-${_due(d.day)}';

  String _ora(DateTime d) => '${_due(d.hour)}:${_due(d.minute)}';

  String _due(int n) => n.toString().padLeft(2, '0');

  /// ⛔ **`print` e non `dart:developer.log`**, ed è il contrario di quello che
  /// c'era scritto qui prima.
  ///
  /// 🚨 In una build **release** `developer.log` è **inerte**: non scrive
  /// niente, non lancia niente, non lascia traccia. La prima versione di questa
  /// diagnostica l'ha usato, e il risultato è stato zero righe su `logcat` —
  /// indistinguibile da «la diagnostica non è partita».
  ///
  /// 💡 `print` in release finisce su `logcat` come `I flutter`, ed è l'unica
  /// cosa che funziona dove serve: sul telefono, con l'APK vero.
  // ignore: avoid_print
  void _riga(String testo) => print('DIAGNOSTICA| $testo');
}
