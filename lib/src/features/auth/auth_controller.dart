import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/errors/api_exception.dart';
import '../../core/providers.dart';
import '../../core/sicurezza/blocco_biometrico.dart';
import '../../core/storage/local_cache.dart';
import '../../core/storage/token_store.dart';
import '../../core/tempo/fuso_del_dispositivo.dart';
import '../health/health_controller.dart';
import '../onboarding/branding_controller.dart';
import 'data/app_user.dart';
import 'data/social_sign_in.dart';

/// In quale dei quattro stati si trova la sessione — A2.4.
enum AuthStatus {
  /// Si sta ancora leggendo il token dal Keychain.
  unknown,

  /// Nessuna sessione: si va al login.
  loggedOut,

  /// Sessione valida.
  loggedIn,

  /// 🚨 Autenticato **ma la palestra è sospesa**.
  ///
  /// Non è «disconnesso»: le credenziali sono giuste e l'utente non può farci
  /// niente. Mandarlo al login lo farebbe riprovare all'infinito con la
  /// password corretta, convinto di sbagliarla. Serve una schermata che dica
  /// cosa è successo.
  gymInactive,

  /// 🔒 Il token c'è, ma è **chiuso a chiave** — A1.
  ///
  /// ⚠️ **Non è «disconnesso»**, e la differenza è tutto il senso della
  /// funzione: la sessione esiste, il token è valido, e basta un dito per
  /// riaprirla. Trattarlo come un logout vorrebbe dire cancellare il token e
  /// far ridigitare la password — cioè rendere l'impronta un peso invece di una
  /// scorciatoia.
  locked,
}

/// Lo stato della sessione.
class AuthState {
  const AuthState({required this.status, this.user, this.message});

  const AuthState.unknown()
    : status = AuthStatus.unknown,
      user = null,
      message = null;

  final AuthStatus status;
  final AppUser? user;
  final String? message;

  bool get isAuthenticated => status == AuthStatus.loggedIn;
}

/// Chi è l'utente, e cosa succede quando smette di esserlo — A2.3 / A2.4.
class AuthController extends StateNotifier<AuthState> {
  AuthController(
    this._api,
    this._tokens, [
    this._svuotaLArchivio,
    this._blocco,
    this._cache,
    this._adottaIlBranding,
  ]) : super(const AuthState.unknown()) {
    // 🚨 Il 401 arriva da **qualunque** richiesta, non solo da quelle di
    // autenticazione: una schermata qualsiasi può essere la prima ad accorgersi
    // che la sessione è morta. Ascoltare lo stream centrale è ciò che evita di
    // gestire quel caso in ogni chiamata.
    _sessionSub = _api.onSessionExpired.listen((_) => _forgetSession());
  }

  final ApiClient _api;

  /// L'archivio locale, da svuotare all'uscita.
  ///
  /// ⚠️ **Facoltativo di proposito**: i test del controller non hanno un
  /// database `drift` sotto, e pretenderlo li costringerebbe a montarne uno per
  /// verificare cose che con l'archivio non c'entrano niente.
  /// Come si svuota l'archivio locale, **senza sapere qual e'**.
  ///
  /// ── 🚨 Perche' una funzione e non l'archivio ──────────────────────────
  ///
  /// Qui prima c'era `ArchivioSalute`, preso con `ref.watch`. ⚠️ **Quella riga
  /// legava l'identita' della persona al database locale**, che sono due cose
  /// che non c'entrano niente l'una con l'altra — e il legame si e' visto
  /// eccome: il ripristino riapre l'archivio, il provider dell'archivio cambia,
  /// e con lui veniva **buttato e ricostruito da zero anche questo
  /// controller**. Nasceva senza utente, e nome e foto sparivano
  /// dall'intestazione finche' qualcuno non li richiedeva al server.
  ///
  /// 💡 Cosi' invece la dipendenza non esiste: si tiene **come** svuotare, non
  /// **cosa**. La funzione va a prendere l'archivio corrente nel momento in cui
  /// serve — che e' anche piu' corretto di prima, perche' un archivio preso una
  /// volta sola diventerebbe quello vecchio dopo un ripristino.
  ///
  /// ⚠️ Si svuota in un caso solo: **quando entra un'altra persona** su questo
  /// telefono. Non e' un'operazione da fare per sbaglio.
  final Future<void> Function()? _svuotaLArchivio;
  final TokenStore _tokens;

  /// Il blocco con l'impronta — A1.
  ///
  /// ⚠️ **Facoltativo per la stessa ragione dell'archivio**: i test del
  /// controller non hanno un canale di piattaforma sotto, e pretenderlo li
  /// costringerebbe a mockare `local_auth` per verificare cose che con
  /// l'impronta non c'entrano niente. `null` = nessun blocco, cioè il
  /// comportamento di prima di A1.
  final BloccoBiometrico? _blocco;

  /// La cache in chiaro, per ricordare **chi c'era prima** su questo telefono.
  ///
  /// ⚠️ Facoltativa come le altre due, e per lo stesso motivo: i test del
  /// controller non hanno `shared_preferences` sotto. `null` = nessuna pulizia
  /// al cambio di persona, cioè il comportamento di prima.
  final LocalCache? _cache;

  /// 🏷️ Adotta il branding che arriva insieme all'utente — 3b-J.1.
  ///
  /// ⚠️ **Un gancio e non il controller del branding**, per la stessa ragione
  /// scritta su `_svuotaLArchivio`: dipendere da un altro provider vorrebbe dire
  /// farsi ricostruire — cioè **perdere la sessione** — ogni volta che quello
  /// cambia. 🚨 È già successo con l'archivio locale il 19/08.
  final Future<void> Function(Object? branding)? _adottaIlBranding;

  StreamSubscription<void>? _sessionSub;

  /// 🚨 **Il telefono ha cambiato padrone: si azzera l'archivio locale.**
  ///
  /// ── Perché qui e non al logout ─────────────────────────────────────────
  ///
  /// Fino al 13/08/2026 l'archivio si svuotava a **ogni** uscita, per proteggere
  /// il telefono condiviso — la tavoletta della reception, il telefono di
  /// famiglia. ⚠️ La preoccupazione era giusta e il momento sbagliato: chi esce
  /// e rientra sul **proprio** telefono perdeva mesi di storico, e peso e misure
  /// inseriti a mano **non tornano** da Health Connect.
  ///
  /// 💡 Spostata qui, la protezione fa esattamente la stessa cosa nel caso che
  /// contava — *entra una persona diversa* — e nessuna in quello che non
  /// c'entrava.
  ///
  /// 🚨 **Prima di scrivere, non dopo**: la pulizia deve finire mentre lo stato
  /// è ancora `unknown`, cioè prima che una qualunque schermata abbia potuto
  /// leggere l'archivio della persona precedente.
  Future<void> _puliziaSeCambiaPersona(AppUser? utente) async {
    if (_cache == null || utente == null) return;

    final precedente = _cache.ultimaPersona;

    if (precedente != null && precedente != utente.id) {
      try {
        await _svuotaLArchivio?.call();
      } on Object {
        // Come altrove: peggio fallire la pulizia che bloccare l'accesso.
      }
    }

    await _cache.setUltimaPersona(utente.id);
  }

  /// Legge il token salvato e chiede al server chi siamo.
  ///
  /// Si chiama all'avvio. Se il token c'è ma non vale più, `_forgetSession()`
  /// scatta dallo stream e lo stato finisce a `loggedOut` senza che qui serva
  /// un `catch` dedicato.
  Future<void> restore() async {
    final token = await _tokens.read();

    if (token == null || token.isEmpty) {
      state = const AuthState(status: AuthStatus.loggedOut);

      return;
    }

    /*
     * 🔒 A1 — il blocco sta **davanti alla lettura del token**, non intorno al
     * login.
     *
     * Il token è già in mano: quello che manca è il permesso di usarlo. Perciò
     * qui non si chiede l'impronta e basta — si va in `locked` e la si chiede
     * dalla schermata di blocco, che ha anche la via d'uscita con la password.
     *
     * ⚠️ Chiederla direttamente da qui sembrerebbe più diretto e sarebbe una
     * trappola: se l'utente annulla, l'app resterebbe su uno stato senza
     * schermata, cioè bloccata davvero.
     */
    /*
     * ══ ⛔ NEL DUBBIO SI BLOCCA — 3b-J.5, 27/08/2026 ═══════════════════════
     *
     * 📌 *«Neanche adesso mi chiede l'accesso con l'impronta. Mi fa accedere
     * senza chiedermi nulla, che non va per niente bene»*.
     *
     * 🚨 **Il difetto era qui**, e non nell'impostazione: `attivo()` catturava
     * l'errore di lettura dell'archivio cifrato e rispondeva «spento». Sul
     * telefono del committente il keystore restituiva `VERIFICATION_FAILED` a
     * ogni avvio — e l'app entrava senza chiedere niente.
     *
     * ⚠️ **Un controllo di sicurezza che fallisce non deve lasciar passare.** Se
     * non sappiamo se il blocco era acceso, l'unica risposta che non tradisce
     * nessuno è comportarsi come se lo fosse: chi non l'aveva acceso perde un
     * gesto, chi l'aveva acceso non perde la protezione.
     *
     * 💡 **E la via d'uscita c'è**: la schermata di blocco ha «Entra con la
     * password». Il vecchio commento diceva che l'alternativa era reinstallare
     * l'app — non era vero, ed è quello che giustificava il fallimento aperto.
     *
     * 🔧 Si ripara subito, o il difetto sarebbe eterno: cancellata la chiave
     * illeggibile, il prossimo avvio legge «spento» pulito e l'app torna a
     * **proporre** il blocco invece di lasciarlo spento in silenzio.
     */
    if (_blocco != null) {
      final stato = await _blocco.stato();

      if (stato == StatoDelBlocco.illeggibile) {
        await _blocco.riparaSeIlleggibile();
      }

      if (stato != StatoDelBlocco.spento) {
        state = const AuthState(status: AuthStatus.locked);

        return;
      }

      /*
       * ══ 🔐 SENZA SBLOCCO RAPIDO SI RIENTRA CON LE CREDENZIALI ═══════════
       *
       * 📌 27/08/2026: *«sblocco rapido con impronta va bene, ma se non è
       * toggled allora mi deve chiedere proprio di accedere con le credenziali
       * sennò tutto un cazzo»*.
       *
       * 🚨 **Ed è la stessa cosa detta prima, portata fino in fondo.** Un token
       * che resta valido sul telefono e apre l'app senza chiedere niente è una
       * sessione che non ha nessuna porta: chi prende in mano il telefono
       * sbloccato entra nel diario, nelle foto e nella chat di qualcun altro.
       * ⛔ L'impronta non era «una comodità in più»: era **l'unica** porta, e
       * chi non l'accendeva restava senza.
       *
       * 💡 Adesso le porte sono due e sono entrambe vere: o lo sblocco rapido,
       * o le credenziali. Non esiste più il caso «nessuna delle due».
       *
       * ⚠️ **Il token si butta**, non si tiene da parte: tenerlo vorrebbe dire
       * lasciare sul telefono una credenziale valida che nessuna porta protegge
       * — cioè esattamente la cosa che questa riga esiste per togliere.
       *
       * ⛔ `cancellaIDati: false`: si chiude la **sessione**, non si cancella
       * l'archivio. Peso, sonno, allenamenti e foto restano dove sono: chi
       * rientra fra un minuto ritrova tutto.
       */
      if (stato == StatoDelBlocco.spento) {
        await _forgetSession();

        return;
      }
    }

    await _loadMe();
  }

  /// Prova a sbloccare. `false` se non è andata — annullo, dito bagnato, o
  /// lettore che non legge.
  ///
  /// ⚠️ Non cancella niente quando fallisce: si resta in `locked` e si riprova.
  /// Chi non ci riesce ha `entraConLaPassword()`.
  Future<bool> sbloccaConImpronta() async {
    if (_blocco == null) return false;

    final aperto = await _blocco.sblocca(motivo: 'Sblocca Training Companion');

    if (!aperto) return false;

    state = const AuthState.unknown();
    await _loadMe();

    return true;
  }

  /// La via d'uscita: si rinuncia alla scorciatoia e si rifà l'accesso.
  ///
  /// 🚨 **Spegne anche il blocco** — lo fa `_forgetSession()`. Chi arriva qui è
  /// arrivato perché l'impronta non funziona: lasciarlo acceso lo rimetterebbe
  /// davanti allo stesso muro al riavvio successivo, e stavolta senza aver
  /// capito perché.
  Future<void> entraConLaPassword() => _forgetSession();

  /// Accesso con **email o nome utente**.
  ///
  /// Il campo si chiama `login` perché accetta entrambi: chiamarlo `email`
  /// sarebbe un nome che mente, ed è il motivo per cui prima o poi qualcuno gli
  /// rimetterebbe una validazione sull'email credendo di correggere una svista.
  Future<void> login({
    required String login,
    required String password,
    String? joinCode,
  }) async {
    final payload = <String, dynamic>{
      'login': login.trim(),
      'password': password,
      // Il nome del dispositivo finisce nell'elenco dei token: serve
      // all'utente per riconoscere e revocare una sessione che non ricorda.
      'device_name': 'app',
      if (joinCode != null && joinCode.isNotEmpty) 'join_code': joinCode,
    };

    // 🚨 `unwrap: false`: la risposta è `{token, data, branding}`, non un
    // inviluppo. Vedi la nota in `ApiClient._unwrap()`.
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      body: payload,
      unwrap: false,
    );

    await _acceptToken(data);
  }

  /// 🚨 `passwordConfirmation` è un parametro vero, non `password` ripetuta.
  ///
  /// Il backend valida con `confirmed`, ma se il client manda due volte lo
  /// stesso valore quella regola non può fallire mai: il controllo esiste per
  /// intercettare un **errore di battitura**, e ricopiando il primo campo lo si
  /// disattiva senza toglierlo. È il tipo di finta protezione che si scopre
  /// quando qualcuno resta chiuso fuori dal proprio account il giorno dopo
  /// l'iscrizione.
  /// 🆕 **`joinCode` è facoltativo da F3.** Senza, il server fa nascere un
  /// *tenant personale* e la persona diventa un utente senza palestra.
  ///
  /// ⚠️ Si manda `null` e **non la stringa vuota**: il server tratta il vuoto
  /// come assente, ma affidarsi a quella tolleranza vorrebbe dire che il giorno
  /// in cui qualcuno la togliesse l'app smetterebbe di funzionare senza che
  /// niente qui dentro sia cambiato.
  Future<void> register({
    String? joinCode,
    required String name,
    required String email,
    required String username,
    required String password,
    required String passwordConfirmation,
    required bool maggiorenne,
    required bool condizioniAccettate,
  }) async {
    final data = await _api.post<Map<String, dynamic>>(
      '/auth/register',
      body: {
        'join_code': joinCode == null || joinCode.trim().isEmpty
            ? null
            : joinCode.trim(),
        'name': name.trim(),
        'email': email.trim(),
        'username': username.trim().toLowerCase(),
        'password': password,
        'password_confirmation': passwordConfirmation,

        // 🚨 S9.2 — senza queste due il server risponde 422 e non si registra
        // nessuno. Sono `required` di proposito e **non hanno un valore di
        // serie**: un `= true` qui dentro vorrebbe dire dichiarare la maggiore
        // età al posto di chi si iscrive, che è esattamente ciò che lo
        // sbarramento esiste per impedire.
        'age_confirmed': maggiorenne,
        'terms_accepted': condizioniAccettate,

        'device_name': 'app',
      },
      unwrap: false,
    );

    await _acceptToken(data);
  }

  /// Accesso con Google o Apple — C17.
  ///
  /// 🚨 `joinCode` serve **solo la prima volta**, e il server lo dice: se
  /// risponde `join_code_required`, l'app deve chiedere il codice palestra e
  /// riprovare. Mandarlo sempre non servirebbe — dal secondo accesso il server
  /// lo ignora, perché la palestra di una persona è quella scritta sul suo
  /// utente e non quella che presenta al momento dell'accesso.
  ///
  /// Restituisce `false` se la persona ha annullato: **non è un errore** e non
  /// va mostrato come tale.
  Future<bool> loginWithSocial(
    String provider, {
    String? joinCode,
    bool maggiorenne = false,
    bool condizioniAccettate = false,
  }) async {
    final credenziale = await SocialSignIn.instance.accedi(provider);

    if (credenziale == null) return false;

    final data = await _api.post<Map<String, dynamic>>(
      '/auth/social',
      body: {
        'provider': credenziale.provider,
        'id_token': credenziale.idToken,
        'join_code': ?joinCode,

        // 🚨 S9.2 — **si mandano sempre**, e da F3 è obbligatorio che sia così.
        //
        // Fino a F2 si mandavano solo insieme al `join_code`, perché «niente
        // codice» voleva dire «non è un primo accesso». ⚠️ Da F3 quella
        // equivalenza è **falsa**: senza codice si può nascere, e senza queste
        // due il server risponde `consents_required` e non crea niente.
        //
        // 💡 Il server continua a ignorarle quando l'identità è già nota, quindi
        // mandarle sempre non trasforma la dichiarazione in un tasto che si
        // preme a ogni accesso: la si chiede una volta, alla prima.
        'age_confirmed': maggiorenne,
        'terms_accepted': condizioniAccettate,

        'device_name': 'app',
      },
      unwrap: false,
    );

    await _acceptToken(data);

    return true;
  }

  /// Esce, e **non lascia il token addosso se il server non risponde**.
  ///
  /// 🚨 L'ordine conta: si prova a revocare lato server, ma la sessione locale
  /// si cancella comunque. Un logout che fallisce perché il telefono è offline
  /// e lascia l'utente dentro è peggio di un token che resta valido sul server
  /// finché non scade: quello lo si revoca dall'elenco dispositivi, l'altro è
  /// un telefono prestato a qualcuno con la sessione aperta.
  Future<void> logout() async {
    try {
      await _api.post<dynamic>('/auth/logout');
    } on Object {
      // Silenzio voluto: la sessione locale se ne va comunque.
    }

    await _forgetSession();
  }

  /// Ricarica l'utente: dopo un cambio di profilo, o al ritorno in primo piano.
  Future<void> refresh() => _loadMe();

  /// Dimentica la sessione **senza chiamare il server** — C6.
  ///
  /// Serve dopo l'eliminazione dell'account: il token è già stato revocato, e
  /// una `logout()` farebbe una chiamata destinata a un 401. Il router reagisce
  /// al cambio di stato e riporta all'accesso.
  ///
  /// 🚨 **Qui l'archivio locale si svuota davvero, ed è l'unico caso** (S9.3).
  /// Chi cancella l'account ha chiesto di sparire: il server cancella ciò che
  /// ha, e **non ha** peso, misure, sonno e battito — quelli vivono qui. Senza
  /// questa riga i dati più personali del sistema sopravvivrebbero a una
  /// cancellazione.
  ///
  /// ⚠️ Da non confondere con `logout()`, che **non** cancella niente: la
  /// differenza fra «esco» e «sparisco» è tutta in questo parametro.
  Future<void> forgetSession() => _forgetSession(cancellaIDati: true);

  // ───────────────────────── interni ─────────────────────────

  Future<void> _acceptToken(Map<String, dynamic> data) async {
    final token = data['token']?.toString();

    if (token == null || token.isEmpty) {
      throw StateError('Il server non ha restituito un token.');
    }

    await _tokens.write(token);

    // 🚨 **L'utente sta sotto `data`, non sotto `user`.**
    //
    // La risposta è `{token, data, branding}` — la stessa forma su cui
    // `unwrap: false` insiste tre righe più su. Leggendo `user` si otteneva
    // sempre `null`, e la sessione partiva **senza utente**: si riempiva solo
    // al riavvio successivo, quando `restore()` chiama `/auth/me`.
    //
    // Nel frattempo, nella sessione appena aperta, il filo della chat mostrava
    // **ogni messaggio come se fosse dell'altra persona** (`user?.id ?? -1`
    // non corrisponde a nessun mittente) e l'intestazione di «Oggi» non
    // salutava nessuno. Difetto invisibile a chi riapriva l'app, cioè a chi
    // provava — che è esattamente il motivo per cui è sopravvissuto.
    final utente = data['data'];
    final persona = utente is Map<String, dynamic>
        ? AppUser.fromJson(utente)
        : null;

    /*
     * 🏷️ **I colori della palestra arrivano con l'utente** — 3b-J.1.
     *
     * 🚨 Da quando il codice non si chiede più prima del login, questo è
     * l'**unico** momento in cui l'app scopre in che palestra si trova chi sta
     * entrando. ⛔ Senza, un iscritto che reinstalla l'app resta vestito di
     * neutro dentro una palestra che ha i suoi colori.
     *
     * 💡 Il campo c'era già nella risposta e non lo leggeva nessuno.
     */
    await _adottaIlBranding?.call(data['branding']);

    // 🚨 **Prima di dichiarare la sessione aperta.** Se la pulizia avvenisse
    // dopo, per un istante lo stato sarebbe `loggedIn` con dentro l'archivio
    // della persona precedente — e basta una schermata che si ricostruisce in
    // quel momento perché quei dati si vedano.
    await _puliziaSeCambiaPersona(persona);

    state = AuthState(status: AuthStatus.loggedIn, user: persona);
  }

  Future<void> _loadMe() async {
    try {
      // Anche qui l'inviluppo non c'è: `/auth/me` risponde `{data, branding}`.
      final risposta = await _api.get<Map<String, dynamic>>(
        '/auth/me',
        unwrap: false,
      );

      final utente = risposta['data'];
      final persona = utente is Map<String, dynamic>
          ? AppUser.fromJson(utente)
          : null;

      /*
       * 🏷️ **E anche alla riapertura** — 3b-J.1.
       *
       * 💡 Non è una ripetizione del login: qui si passa a **ogni avvio**, ed è
       * il punto in cui l'app si accorge che nel frattempo la palestra è
       * cambiata — qualcuno è entrato da un altro telefono, o il trainer l'ha
       * spostato. ⛔ Solo al login vorrebbe dire scoprirlo al prossimo logout.
       */
      await _adottaIlBranding?.call(risposta['branding']);

      // ⚠️ Anche qui, e **prima** dello stato: `restore()` passa da questa
      // strada, quindi è il punto in cui un telefono che ha cambiato padrone se
      // ne accorge alla riapertura dell'app e non solo al login esplicito.
      await _puliziaSeCambiaPersona(persona);

      state = AuthState(status: AuthStatus.loggedIn, user: persona);

      unawaited(_sincronizzaFuso());
    } on Object catch (error) {
      // 🚨 Sul **tipo**, non sul messaggio. Riconoscere un errore dal testo
      // significa che il giorno in cui qualcuno riformula una frase l'app
      // smette di distinguere «palestra sospesa» da «errore generico» — e
      // manda al login una persona che ha le credenziali giuste.
      final tradotto = ApiClient.unwrapError(error);

      if (tradotto is GymInactiveException) {
        state = AuthState(
          status: AuthStatus.gymInactive,
          message: tradotto.message,
        );

        return;
      }

      // Il 401 ha già fatto scattare `_forgetSession()` dallo stream.
      if (state.status == AuthStatus.unknown) {
        state = const AuthState(status: AuthStatus.loggedOut);
      }
    }
  }

  /// Dice al server in che fuso vive questa persona — A3.
  ///
  /// ── 🚨 Perché parte da qui, e perché non si aspetta ───────────────────
  ///
  /// Il server **non può indovinarlo**: l'IP dice dov'è la rete e sbaglia su
  /// ogni VPN, l'offset non distingue Roma d'estate da Helsinki d'inverno. Lo
  /// sa solo il telefono. Senza questa chiamata `users.timezone` resta `null`
  /// per sempre e tutti ricadono sul fuso della palestra — che per chi vive
  /// altrove è il difetto A3 daccapo.
  ///
  /// ⚠️ **`unawaited` è deliberato.** È una sincronizzazione di sfondo: farci
  /// aspettare l'avvio significherebbe che un server lento tiene la persona
  /// davanti a uno spinner per un dato che non le serve *adesso*. Al massimo la
  /// prima schermata mostra il giorno vecchio, e la successiva quello giusto.
  ///
  /// 💡 Il costo è trascurabile anche a ogni avvio: il server scrive **solo se
  /// è cambiato**, quindi la chiamata normale non tocca nemmeno la riga.
  Future<void> _sincronizzaFuso() async {
    final fuso = await FusoDelDispositivo.leggi();

    if (fuso == null) return;

    try {
      await _api.put<dynamic>('/account/timezone', body: {'timezone': fuso});
    } on Object {
      // Silenzio voluto: il server ha la sua catena di ripiego, e un errore qui
      // non è una cosa su cui l'utente possa fare niente.
    }
  }

  Future<void> _forgetSession({bool cancellaIDati = false}) async {
    await _tokens.clear();

    /*
     * 🚨 **La cancellazione deve arrivare al telefono — S9.3.**
     *
     * Dopo S1-S5 peso, misure, sonno, HRV e battito **non stanno più sul
     * server**: vivono qui, in un database SQLite. Quando qualcuno cancella il
     * proprio account, `AccountEraser` fa il suo lavoro su ciò che ha — ⚠️ e
     * **il server non può cancellare quello che non ha**. Senza questo
     * svuotamento, i dati più personali del sistema sopravvivrebbero a una
     * cancellazione, proprio come faceva `health_readings`.
     *
     * ── 🚨 Ma NON al logout. Difetto riferito il 13/08/2026 ────────────────
     *
     * *«Anche se non ho cambiato dispositivo, quando sono uscito mi ha
     * cancellato tutti i dati di peso, altezza eccetera nonché tutti i dati di
     * Health Connect, che ho dovuto risincronizzare a mano.»*
     *
     * Qui c'era uno svuotamento **incondizionato**, con questa motivazione: su
     * un telefono condiviso «esci» deve voler dire che la persona dopo non
     * trova il peso di quella prima.
     *
     * ⚠️ **La preoccupazione è giusta, il momento era sbagliato.** Uscire dal
     * proprio account sul **proprio** telefono è la cosa più normale del mondo
     * — lo si fa per rientrare —, e pagarla con la perdita di mesi di storico
     * è un prezzo che nessuno si aspetta. E la riga «si ripopola da Health
     * Connect in pochi secondi» era **falsa**: peso e misure inseriti a mano
     * non stanno in Health Connect, e non tornano da nessuna parte.
     *
     * 💡 **La protezione del telefono condiviso resta, spostata dove serve**:
     * l'archivio si svuota quando entra **una persona diversa** (vedi
     * `_puliziaSeCambiaPersona()`). Chi esce e rientra ritrova i suoi dati;
     * chi trova il telefono di un altro non vede niente di suo. È lo stesso
     * risultato, senza il danno collaterale.
     *
     * 🚨 L'eccezione si cattura: un guasto del database locale **non deve
     * lasciare qualcuno dentro l'app** con la sessione già cancellata. Peggio
     * fallire la pulizia che bloccare l'uscita.
     */
    if (cancellaIDati) {
      try {
        await _svuotaLArchivio?.call();
      } on Object {
        // Volutamente silenzioso: vedi sopra.
      }

      // 💡 E si dimentica chi c'era: l'archivio è già vuoto, quindi la pulizia
      // al cambio di persona non avrebbe più niente da fare — e lasciare un id
      // che punta a un account cancellato è una riga che mente.
      await _cache?.dimenticaUltimaPersona();
    }

    /*
     * 🔒 Il blocco si spegne a **ogni** uscita, non solo quando lo si sceglie —
     * A1.
     *
     * Restando acceso su un account che non c'è più, il riavvio successivo
     * chiederebbe l'impronta per sbloccare **il nulla**, e subito dopo
     * manderebbe comunque al login. È l'attrito peggiore possibile: costa un
     * gesto e non protegge niente.
     */
    await _blocco?.azzera();

    state = const AuthState(status: AuthStatus.loggedOut);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    super.dispose();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.watch(apiClientProvider),
    ref.watch(tokenStoreProvider),

    /*
     * 🚨 **`ref.read` dentro una funzione, non `ref.watch`** — 19/08/2026.
     *
     * Con `ref.watch(archivioSaluteProvider)` questo controller **dipendeva**
     * dall'archivio locale: bastava che l'archivio venisse ricreato — e il
     * ripristino lo ricrea — perche' Riverpod buttasse via anche il controller
     * dell'autenticazione e lo rifacesse da zero, **senza utente**.
     *
     * ⚠️ Il sintomo era: dopo un ripristino, nome e avatar sparivano
     * dall'intestazione e dal profilo. La causa non somigliava per niente al
     * sintomo, ed e' il motivo per cui la prima correzione fu un cerotto —
     * ricaricare l'utente dopo il ripristino — invece della cura.
     *
     * 💡 Adesso non c'e' nessuna dipendenza: si passa **come** svuotare
     * l'archivio, e la `ref.read` avviene **al momento della chiamata**, quindi
     * prende sempre quello corrente.
     */
    () => ref.read(archivioSaluteProvider).svuota(),

    ref.watch(bloccoBiometricoProvider),
    ref.watch(localCacheProvider),

    /*
     * 🏷️ **`ref.read` dentro la funzione**, come sopra: con `ref.watch` questo
     * controller dipenderebbe dal branding, e ogni cambio di palestra
     * ricostruirebbe l'autenticazione — cioè butterebbe la sessione di chi ha
     * appena finito di entrare in palestra.
     */
    (branding) => ref
        .read(brandingControllerProvider.notifier)
        .adottaDalServer(branding),
  ),
);

final bloccoBiometricoProvider = Provider<BloccoBiometrico>(
  (ref) => BloccoBiometrico(),
);
