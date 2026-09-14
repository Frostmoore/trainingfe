import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

// ⚠️ **`AndroidAuthMessages` sta qui, e `local_auth` NON lo riesporta**: da
// lì arrivano solo `LocalAuthentication`, `BiometricType` e le eccezioni. 💡 Per
// questo `local_auth_android` è dichiarato nel `pubspec.yaml` invece di essere
// usato come transitiva.
import 'package:local_auth_android/local_auth_android.dart';

/// Cosa sappiamo del blocco — 3b-J.5, 27/08/2026.
///
/// 🚨 **Tre stati e non due**, perché «non riesco a leggere» non è «spento»:
/// confonderli è ciò che ha fatto entrare l'app senza chiedere niente.
enum StatoDelBlocco {
  acceso,
  spento,

  /// ⛔ L'archivio cifrato non risponde. Vedi `BloccoBiometrico.stato()`.
  illeggibile,
}

/// Il blocco con l'impronta — A1.
///
/// ── 🚨 Cos'è, e soprattutto cosa NON è ────────────────────────────────────
///
/// **Non è un secondo fattore, e non è un accesso.** È una scorciatoia per
/// riaprire una sessione **che esiste già**: il token di Sanctum sta nel
/// Keychain, e l'impronta serve a sbloccarne l'uso — non a ottenerlo dal
/// server.
///
/// La differenza non è terminologica. Se l'impronta fosse trattata come un
/// login, per rifare quel login servirebbe la password, e la password
/// finirebbe conservata sul telefono: cioè si scambierebbe una credenziale
/// forte e revocabile (il token) con una che vale su ogni dispositivo e non si
/// revoca. È il modo classico di peggiorare la sicurezza credendo di
/// migliorarla.
///
/// 💡 Nessun dato biometrico passa da qui. `local_auth` disegna la richiesta e
/// la verifica avviene nel chip sicuro del telefono: a Dart torna solo un `bool`.
///
/// ── ⚠️ Il ripiego non è facoltativo ───────────────────────────────────────
///
/// Dito bagnato in palestra, lettore che non legge, telefono senza biometria,
/// impronta riconfigurata dopo un aggiornamento. Chi usa questa classe **deve**
/// offrire sempre una via d'uscita con la password: senza, la persona resta
/// chiusa fuori dal proprio account da una funzione che aveva acceso per
/// comodità.
class BloccoBiometrico {
  BloccoBiometrico({LocalAuthentication? auth, FlutterSecureStorage? storage})
    : _auth = auth ?? LocalAuthentication(),
      _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  /// 🚨 La preferenza sta nell'archivio **cifrato**, non in `shared_preferences`.
  ///
  /// In un file XML in chiaro sarebbe un interruttore che chiunque abbia accesso
  /// al filesystem può spegnere: il blocco si aggirerebbe senza toccare né il
  /// token né l'impronta, cioè sarebbe teatro invece che una difesa.
  static const _chiave = 'blocco_biometrico_attivo';

  /// Se lo sblocco è già stato **proposto** su questo dispositivo.
  ///
  /// 🚨 È una cosa diversa da «attivo»: serve a chiedere **una volta sola**.
  /// Ripresentare la proposta a ogni avvio a chi ha detto di no è il modo più
  /// rapido per far disattivare le notifiche e disinstallare l'app.
  static const _chiaveProposto = 'blocco_biometrico_proposto';

  /// Il telefono sa fare il riconoscimento?
  ///
  /// ⚠️ `false` anche quando l'hardware c'è ma **non è configurato**: un lettore
  /// senza impronte registrate accetterebbe l'attivazione e poi fallirebbe
  /// sempre. Meglio non offrire l'interruttore.
  Future<bool> disponibile() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;

      return await _auth.canCheckBiometrics ||
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  /// Lo stato del blocco, **con il terzo caso** — 3b-J.5, 27/08/2026.
  ///
  /// ══ ⛔ IL DIFETTO: UN CONTROLLO CHE FALLIVA IN SILENZIO ════════════════
  ///
  /// 📌 Riferito il 27/08: *«Neanche adesso mi chiede l'accesso con l'impronta.
  /// Mi fa accedere senza chiedermi nulla, che non va per niente bene»*.
  ///
  /// 🚨 **E il telefono aveva ragione a lamentarsi.** Nel log di sistema, a ogni
  /// avvio:
  ///
  /// ```
  /// keystore2: Finish failed for uid 10354
  ///            Error::Km(r#VERIFICATION_FAILED)
  /// ```
  ///
  /// L'archivio cifrato non riusciva più a decifrare — succede quando la chiave
  /// nel keystore viene invalidata: un aggiornamento del sistema, una biometria
  /// ri-registrata, un ripristino. ⛔ E `attivo()` catturava **qualunque**
  /// errore rispondendo `false`: il blocco risultava spento, e l'app entrava.
  ///
  /// ⚠️ **Il commento che c'era diceva una cosa non vera**: *«il contrario
  /// bloccherebbe l'app, e la via d'uscita sarebbe reinstallarla»*. La via
  /// d'uscita c'è ed è nella schermata di blocco — «Entra con la password». 🚨 È
  /// il tipo di ragionamento che giustifica un fallimento aperto con un pericolo
  /// che non esiste.
  ///
  /// 💡 Adesso il dubbio è **un terzo stato**, e chi chiama decide: vedi
  /// `AuthController.restore()`, che di fronte a [StatoDelBlocco.illeggibile]
  /// **blocca**.
  Future<StatoDelBlocco> stato() async {
    try {
      return await _storage.read(key: _chiave) == '1'
          ? StatoDelBlocco.acceso
          : StatoDelBlocco.spento;
    } on Object catch (e) {
      debugPrint('blocco biometrico: non si riesce a leggere lo stato — $e');

      return StatoDelBlocco.illeggibile;
    }
  }

  /// ⚠️ **Solo per chi non deve decidere niente**, come l'interruttore nel
  /// profilo: `illeggibile` vale «non acceso». ⛔ Non usarlo dove si decide se
  /// far entrare qualcuno — là serve [stato].
  Future<bool> attivo() async => await stato() == StatoDelBlocco.acceso;

  /// Accende o spegne il blocco.
  ///
  /// 🚨 **Accendere richiede di superare la verifica subito.** Senza, si
  /// attiverebbe un blocco che nessuno ha mai provato, e il primo tentativo
  /// avverrebbe al riavvio successivo — quando ormai la scelta è fatta e
  /// l'unica uscita è rifare l'accesso con la password.
  ///
  /// Restituisce `true` se lo stato è cambiato davvero.
  Future<bool> imposta({required bool acceso}) async {
    if (!acceso) {
      // ⚠️ Spegnere NON chiede l'impronta, ed è voluto: chi ha già la sessione
      // aperta è dentro. Pretendere la verifica per disattivare la funzione
      // significherebbe che un lettore rotto la rende impossibile da togliere.
      await _storage.delete(key: _chiave);

      return true;
    }

    if (!await disponibile()) return false;

    /*
     * ⚖️ **Qui la descrizione resta l'azione, non la spiegazione** — 15/09/2026.
     *
     * 🚨 La spiegazione su dove finisce l'impronta sta sulla richiesta di
     * **sblocco** (vedi `AuthController.sbloccaConImpronta()`), non su questa.
     * ⛔ Era stata messa anche qui — è la prima volta che la finestra compare,
     * e sembrava il posto giusto — ma il committente ha guardato la schermata e
     * ha detto che va bene com'è.
     *
     * 💡 E il motivo tiene: qui la persona ha appena toccato «Sblocco rapido»,
     * quindi sa perfettamente cosa sta facendo. La domanda a cui questa riga
     * deve rispondere è *«cosa sto confermando?»*, non *«cosa ne fate del mio
     * dito?»*.
     */
    if (!await sblocca(motivo: 'Conferma per attivare lo sblocco rapido')) {
      return false;
    }

    await _storage.write(key: _chiave, value: '1');

    return true;
  }

  /// ══ 🆕 LE PAROLE DELLA FINESTRA DI SISTEMA — 15/09/2026 ══════════════════
  ///
  /// 📌 Il committente, dopo averla vista: *«È un po' troppo scarna»*.
  ///
  /// ⛔ **Erano in inglese e le scriveva il plugin**: «Authentication required»,
  /// «Verify identity», «Cancel». 🚨 Non è una finestra di Android: è una
  /// finestra **della nostra app**, con i nostri testi dentro — solo che
  /// nessuno gliene aveva dati, e `local_auth` ripiega sui suoi.
  ///
  /// ⚠️ **Le tre righe non sono intercambiabili**, e sbagliare quale si riempie
  /// è il modo di scrivere la frase giusta nel posto sbagliato:
  ///
  /// | Riga | Da dove viene |
  /// |---|---|
  /// | Titolo | `signInTitle` |
  /// | Sottotitolo | `signInHint` — sì, si chiama «hint» |
  /// | Descrizione | `localizedReason`, cioè `motivo` |
  ///
  /// 💡 Il titolo e il sottotitolo stanno **qui** perché non cambiano mai; la
  /// descrizione la passa chi chiama, perché cambia con il momento — sbloccare
  /// l'app non è attivare lo sblocco.
  static const _paroleAndroid = AndroidAuthMessages(
    signInTitle: "Autenticati con l'Impronta",

    /*
     * ⚠️ **`signInHint` è il sottotitolo**, non un suggerimento in fondo.
     *
     * 🚨 Il nome inganna, e il campo che si chiamava come quello che si vede —
     * `biometricHint` — **in questa versione non esiste più**: dalla 2.0.0 la
     * classe ha tre campi in tutto, e `signInHint` finisce nella stessa chiave
     * di prima. ⛔ Scrivere `biometricHint` qui non compila: se un giorno
     * compila di nuovo, vuol dire che il pacchetto è tornato indietro.
     */
    signInHint: 'Verifica la tua identità',

    // ⚠️ Si legge anche questo, e in inglese stonava come gli altri due.
    cancelButton: 'Annulla',
  );

  /// Chiede la verifica. `false` se non è andata, per qualunque ragione.
  ///
  /// ⚠️ **Non distingue «annullato» da «fallito»**, e non è una semplificazione
  /// pigra: il chiamante fa la stessa cosa in entrambi i casi — mostra la via
  /// d'uscita con la password. Distinguerli servirebbe solo a scrivere un
  /// messaggio diverso a chi ha appena deciso di non usare il dito.
  Future<bool> sblocca({required String motivo}) async {
    try {
      return await _auth.authenticate(
        localizedReason: motivo,
        authMessages: const [_paroleAndroid],

        // `false`: il codice di sblocco del telefono va bene quanto l'impronta.
        // Sono la stessa garanzia — «questo telefono è di chi dice di essere» —
        // e pretendere solo la biometria chiuderebbe fuori chi ha il lettore
        // guasto o l'ha registrata male.
        biometricOnly: false,

        // ⚠️ La richiesta non deve sopravvivere all'app messa in tasca: se
        // l'utente esce, al ritorno si ricomincia dallo schermo di blocco.
        // (In `local_auth` 2.x questo parametro si chiamava `stickyAuth` e
        // stava dentro `AuthenticationOptions`, che nella 3.x non esiste più.)
        persistAcrossBackgrounding: false,
      );
    } on Object catch (errore) {
      /*
       * 🚨 `authenticate()` restituisce `false` sul fallimento pulito ma
       * **lancia** su tutto il resto — lettore occupato, troppi tentativi,
       * biometria disattivata mentre l'app era aperta. Per chi usa l'app sono
       * la stessa cosa: non si è sbloccato.
       *
       * ⚠️ **Ma NON sono la stessa cosa per chi sviluppa, e questo `catch` l'ha
       * già nascosto una volta.** Con `MainActivity : FlutterActivity()` il
       * plugin lancia `no_fragment_activity` a **ogni** tentativo: il sintomo
       * era un interruttore che si toccava e non si accendeva, senza un
       * messaggio da nessuna parte. Ci è voluta una prova su telefono vero per
       * accorgersene.
       *
       * 💡 In debug si stampa, in release resta muto: l'utente non deve leggere
       * il nome di una classe Android, ma il prossimo che rompe la
       * configurazione deve trovarlo scritto invece di doverlo dedurre.
       */
      if (kDebugMode) debugPrint('BloccoBiometrico.sblocca: $errore');

      return false;
    }
  }

  /// Va proposto adesso? — la richiesta al primo accesso su un dispositivo.
  ///
  /// Tre condizioni, e servono tutte e tre:
  /// 1. il telefono sa farlo **e ha un'impronta registrata**;
  /// 2. non è già acceso;
  /// 3. non è già stato chiesto su questo dispositivo.
  ///
  /// ⚠️ La terza è quella che rende la funzione sopportabile: senza, chi dice
  /// di no se lo ritrova davanti a ogni avvio.
  Future<bool> daProporre() async {
    if (!await disponibile()) return false;
    if (await attivo()) return false;

    try {
      return await _storage.read(key: _chiaveProposto) != '1';
    } on Object {
      // In dubbio non si propone: una proposta di troppo è fastidio, una in
      // meno è solo un'opzione che resta nel profilo.
      return false;
    }
  }

  /// Segna che è stato chiesto — ⚠️ **anche quando la risposta è no**.
  Future<void> segnaProposto() async {
    try {
      await _storage.write(key: _chiaveProposto, value: '1');
    } on Object {
      // Al peggio si riproporrà: non vale un errore a schermo.
    }
  }

  /// 🔧 Ripara un archivio che non si riesce più a leggere — 3b-J.5.
  ///
  /// 🚨 **Senza, il difetto sarebbe eterno**: la chiave resta illeggibile a ogni
  /// avvio, e chi entra si vedrebbe la schermata di blocco per sempre.
  ///
  /// 💡 Cancella quello che non si legge e **dimentica di aver proposto**, così
  /// l'app torna a offrire il blocco invece di lasciarlo spento in silenzio. ⚠️ È
  /// la stessa cosa che fa [azzera] all'uscita, e per la stessa ragione: uno
  /// stato che non si può leggere non è uno stato.
  Future<void> riparaSeIlleggibile() async {
    try {
      await _storage.delete(key: _chiave);
      await _storage.delete(key: _chiaveProposto);
    } on Object catch (e) {
      // ⚠️ Se non si riesce nemmeno a cancellare non c'è altro da fare: al
      // prossimo avvio si ricade nello stesso ramo, che almeno **blocca**.
      debugPrint('blocco biometrico: non si riesce nemmeno a ripulire — $e');
    }
  }

  /// Spegne il blocco senza chiedere niente — si chiama all'uscita.
  ///
  /// 💡 Un blocco rimasto acceso su un account che non c'è più chiederebbe
  /// l'impronta per sbloccare **il nulla**, subito prima di mandare comunque al
  /// login.
  Future<void> azzera() async {
    try {
      await _storage.delete(key: _chiave);

      /*
       * ⚠️ Si dimentica **anche di aver chiesto**.
       *
       * Un telefono può passare di mano — quello di casa, la tavoletta della
       * reception — e la persona che accede dopo non ha mai visto nessuna
       * proposta. Tenendo il flag, si ritroverebbe una funzione mai offerta e
       * nessun modo di scoprirla se non frugando nel profilo.
       *
       * 💡 Il costo è nullo: chi esce e rientra sullo stesso telefono si
       * rivede la domanda **una volta**, subito dopo aver ridigitato la
       * password — cioè nel momento in cui è più evidente a cosa serve.
       */
      await _storage.delete(key: _chiaveProposto);
    } on Object {
      // Non c'è niente di utile da fare: si sta già uscendo.
    }
  }
}
