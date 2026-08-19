import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:training_companion/src/core/api/api_client.dart';
import 'package:training_companion/src/core/config/app_config.dart';
import 'package:training_companion/src/core/sicurezza/blocco_biometrico.dart';
import 'package:training_companion/src/core/storage/archivio_salute.dart';
import 'package:training_companion/src/core/storage/local_cache.dart';
import 'package:training_companion/src/core/storage/token_store.dart';
import 'package:training_companion/src/features/auth/auth_controller.dart';

/// A2.3 — la sessione.
///
/// 🚨 **Il test che mancava.** `api_client_test.dart` provava già che la
/// risposta di login ha la forma `{token, data, branding}`, ma nessuno provava
/// che `AuthController` la **leggesse** giusta: cercava l'utente sotto `user`,
/// che non esiste, e otteneva sempre `null`.
///
/// Il difetto era invisibile a chi riapriva l'app — `restore()` chiama
/// `/auth/me`, che l'utente lo legge dal posto giusto — e quindi sopravviveva a
/// ogni prova manuale fatta il giorno dopo. Si vedeva solo nella sessione
/// appena aperta: la chat metteva **tutti** i messaggi dal lato dell'altra
/// persona, perché `user?.id ?? -1` non corrisponde a nessun mittente.
void main() {
  late Dio dio;
  late DioAdapter adapter;
  late ApiClient client;
  late _TokenStoreFinto token;

  /// La risposta comune a `/auth/login` e `/auth/register`: l'utente sta sotto
  /// `data`, **accanto** al token, non dentro un inviluppo.
  const rispostaConToken = {
    'token': '1|abcdef',
    'data': {
      'id': 7,
      'name': 'Mario Rossi',
      'email': 'mario@esempio.test',
      'username': 'mario.rossi',
    },
    'branding': {'name': 'Palestra Demo'},
  };

  setUp(() {
    dio = Dio(
      BaseOptions(
        baseUrl: 'https://esempio.test/api/v1',
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    adapter = DioAdapter(dio: dio);
    dio.httpClientAdapter = adapter;

    token = _TokenStoreFinto();

    client = ApiClient(
      config: const AppConfig(
        environment: AppEnvironment.local,
        apiBaseUrl: 'https://esempio.test/api/v1',
        enableDebugTools: true,
      ),
      tokenStore: token,
      dio: dio,
    );
  });

  test('dopo il login la sessione sa chi è l\'utente', () async {
    adapter.onPost(
      '/auth/login',
      (s) => s.reply(200, rispostaConToken),
      data: Matchers.any,
    );

    final auth = AuthController(client, token);

    await auth.login(login: 'mario.rossi', password: 'x');

    expect(auth.state.status, AuthStatus.loggedIn);
    expect(
      auth.state.user,
      isNotNull,
      reason: 'Senza utente la chat attribuisce ogni messaggio all\'altra '
          'persona e «Oggi» non saluta nessuno.',
    );
    expect(auth.state.user!.id, 7);
    expect(auth.state.user!.name, 'Mario Rossi');
    expect(auth.state.user!.username, 'mario.rossi');
  });

  test('il token arriva nel portachiavi, non solo nello stato', () async {
    adapter.onPost(
      '/auth/login',
      (s) => s.reply(200, rispostaConToken),
      data: Matchers.any,
    );

    final auth = AuthController(client, token);

    await auth.login(login: 'mario.rossi', password: 'x');

    expect(token.salvato, '1|abcdef');
  });

  test('anche la registrazione porta con sé l\'utente', () async {
    adapter.onPost(
      '/auth/register',
      (s) => s.reply(201, rispostaConToken),
      data: Matchers.any,
    );

    final auth = AuthController(client, token);

    await auth.register(
      joinCode: 'DEMO2345',
      name: 'Mario Rossi',
      email: 'mario@esempio.test',
      username: 'mario.rossi',
      password: 'x',
      passwordConfirmation: 'x',
      maggiorenne: true,
      condizioniAccettate: true,
    );

    expect(auth.state.user?.id, 7);
  });

  /// 🚨 La conferma viaggia come campo **suo**, non come copia della password.
  ///
  /// Se il client ricopiasse il primo valore, la regola `confirmed` del backend
  /// non potrebbe fallire mai: il controllo esisterebbe senza proteggere dal
  /// caso per cui è lì — l'errore di battitura che chiude fuori dal proprio
  /// account il giorno dopo l'iscrizione.
  test('la conferma della password si manda separata, non ricopiata', () async {
    Map<String, dynamic>? inviato;

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (options.path.contains('register')) {
            inviato = (options.data as Map).cast<String, dynamic>();
          }
          handler.next(options);
        },
      ),
    );

    adapter.onPost(
      '/auth/register',
      (s) => s.reply(201, rispostaConToken),
      data: Matchers.any,
    );

    final auth = AuthController(client, token);

    await auth.register(
      joinCode: 'DEMO2345',
      name: 'Mario Rossi',
      email: 'mario@esempio.test',
      username: 'mario.rossi',
      password: 'primo-valore',
      passwordConfirmation: 'secondo-valore',
      maggiorenne: true,
      condizioniAccettate: true,
    );

    expect(inviato?['password'], 'primo-valore');
    expect(inviato?['password_confirmation'], 'secondo-valore');

    // 🚨 S9.2 — le dichiarazioni devono partire davvero, non restare
    // nell'interfaccia: senza, il server risponde 422 e non si registra
    // nessuno.
    expect(inviato?['age_confirmed'], true);
    expect(inviato?['terms_accepted'], true);
  });

  /// La via che funzionava già, e che nascondeva l'altra: qui l'utente sta
  /// sotto `data` di una risposta **senza** token.
  test('al riavvio la sessione si ricostruisce da /auth/me', () async {
    token.salvato = '1|abcdef';

    adapter.onGet(
      '/auth/me',
      (s) => s.reply(200, {
        'data': {'id': 7, 'name': 'Mario Rossi', 'email': 'mario@esempio.test'},
        'branding': {'name': 'Palestra Demo'},
      }),
    );

    final auth = AuthController(client, token);

    await auth.restore();

    expect(auth.state.status, AuthStatus.loggedIn);
    expect(auth.state.user?.id, 7);
  });

  test('senza token salvato si parte disconnessi, senza chiamare il server', () async {
    final auth = AuthController(client, token);

    await auth.restore();

    expect(auth.state.status, AuthStatus.loggedOut);
    expect(auth.state.user, isNull);
  });

  /// 🚨 Dopo l'eliminazione dell'account il token è **già** revocato: una
  /// `logout()` farebbe una chiamata destinata a un 401.
  test('forgetSession svuota la sessione senza chiamare il server', () async {
    adapter.onPost(
      '/auth/login',
      (s) => s.reply(200, rispostaConToken),
      data: Matchers.any,
    );

    final auth = AuthController(client, token);

    await auth.login(login: 'mario.rossi', password: 'x');
    await auth.forgetSession();

    expect(auth.state.status, AuthStatus.loggedOut);
    expect(auth.state.user, isNull);
    expect(token.salvato, isNull);
  });

  // ─────────── 🚨 L'archivio locale: chi lo cancella, e quando ───────────

  /// **Il difetto riferito il 13/08/2026, ed è quello che è costato di più.**
  ///
  /// *«Anche se non ho cambiato dispositivo, quando sono uscito mi ha cancellato
  /// tutti i dati di peso, altezza eccetera nonché tutti i dati di Health
  /// Connect, che ho dovuto risincronizzare a mano.»*
  ///
  /// ⚠️ Lo svuotamento era **incondizionato**, per proteggere il telefono
  /// condiviso. La preoccupazione era giusta e il momento sbagliato: uscire dal
  /// proprio account sul proprio telefono è la cosa più normale del mondo — lo
  /// si fa per rientrare — e pagarla con mesi di storico è un prezzo che nessuno
  /// si aspetta.
  ///
  /// 🚨 E la giustificazione scritta nel codice — *«si ripopola da Health
  /// Connect in pochi secondi»* — era **falsa**: peso e misure inseriti a mano
  /// non stanno in Health Connect, e non tornano da nessuna parte.
  group('archivio locale', () {
    late _ArchivioFinto archivio;
    late _CacheFinta cache;

    setUp(() {
      archivio = _ArchivioFinto();
      cache = _CacheFinta();

      adapter.onPost(
        '/auth/login',
        (s) => s.reply(200, rispostaConToken),
        data: Matchers.any,
      );
    });

    test('uscire NON cancella i dati locali', () async {
      adapter.onPost('/auth/logout', (s) => s.reply(200, {}), data: Matchers.any);

      final auth = AuthController(client, token, archivio.svuota, null, cache);

      await auth.login(login: 'mario.rossi', password: 'x');
      await auth.logout();

      expect(auth.state.status, AuthStatus.loggedOut);
      expect(
        archivio.svuotato,
        isFalse,
        reason: 'Uscire dal proprio account ha cancellato peso, misure e sonno.',
      );
    });

    /// 🚨 **Ma cancellare l'account sì, ed è obbligatorio** — S9.3.
    ///
    /// Il server cancella ciò che ha, e **non ha** peso, misure, sonno e
    /// battito: vivono qui. Senza questo, i dati più personali del sistema
    /// sopravvivrebbero a una richiesta di cancellazione.
    test('cancellare l\'account cancella tutto', () async {
      final auth = AuthController(client, token, archivio.svuota, null, cache);

      await auth.login(login: 'mario.rossi', password: 'x');
      await auth.forgetSession();

      expect(archivio.svuotato, isTrue);
      expect(cache.ultima, isNull, reason: 'Un id che punta a un account cancellato mente.');
    });

    /// 💡 La protezione del telefono condiviso resta, spostata dove serve.
    test('entrando una persona diversa, l\'archivio si azzera', () async {
      cache.ultima = 999; // qualcun altro ha usato questo telefono

      final auth = AuthController(client, token, archivio.svuota, null, cache);

      await auth.login(login: 'mario.rossi', password: 'x');

      expect(archivio.svuotato, isTrue);
      expect(cache.ultima, 7, reason: 'Adesso il telefono è di Mario.');
    });

    /// ⚠️ E rientrando **la stessa** persona non si tocca niente: è il caso
    /// normale, ed è quello che il difetto rendeva distruttivo.
    test('rientrando la stessa persona non si tocca niente', () async {
      cache.ultima = 7;

      final auth = AuthController(client, token, archivio.svuota, null, cache);

      await auth.login(login: 'mario.rossi', password: 'x');

      expect(archivio.svuotato, isFalse);
    });

    /// 💡 Al primo accesso su un telefono nuovo non c'è niente da cancellare —
    /// e cancellare comunque sarebbe innocuo, ma l'id va scritto per la
    /// prossima volta.
    test('al primo accesso non si cancella, ma si prende nota', () async {
      final auth = AuthController(client, token, archivio.svuota, null, cache);

      await auth.login(login: 'mario.rossi', password: 'x');

      expect(archivio.svuotato, isFalse);
      expect(cache.ultima, 7);
    });
  });

  // ───────────────────────── A1 — lo sblocco rapido ─────────────────────────

  group('blocco biometrico', () {
    late _BloccoFinto blocco;

    setUp(() {
      blocco = _BloccoFinto();
      token.salvato = '1|abcdef';

      adapter.onGet(
        '/auth/me',
        (s) => s.reply(200, {
          'data': {'id': 7, 'name': 'Mario Rossi', 'email': 'mario@esempio.test'},
          'branding': {'name': 'Palestra Demo'},
        }),
      );
    });

    /// 🚨 Il blocco sta **davanti alla lettura del token**: se scattasse dopo,
    /// l'app avrebbe già chiesto al server chi siamo — cioè avrebbe già usato
    /// la credenziale che il blocco dovrebbe proteggere.
    test('con il blocco acceso si parte bloccati, senza chiamare il server', () async {
      blocco.acceso = true;

      final auth = AuthController(client, token, null, blocco);

      await auth.restore();

      expect(auth.state.status, AuthStatus.locked);
      expect(auth.state.user, isNull, reason: '/auth/me non deve essere stata chiamata');
      expect(token.salvato, '1|abcdef', reason: 'il token NON si cancella: la sessione esiste');
    });

    test('con il blocco spento si entra come prima', () async {
      final auth = AuthController(client, token, null, blocco);

      await auth.restore();

      expect(auth.state.status, AuthStatus.loggedIn);
    });

    /// 🚨 **Niente impronta senza una sessione da proteggere** — 13/08/2026.
    ///
    /// Riferito provando la `v6.3.0`: *«al primo accesso mi chiede l'impronta
    /// prima ancora di aver creato un account»*.
    ///
    /// ⚠️ Il blocco esiste per proteggere **un token già in mano**: senza
    /// token non c'è niente da proteggere, e chiedere l'impronta a chi non ha
    /// ancora un account è una porta chiusa davanti a una stanza vuota.
    ///
    /// 💡 Questo test **non riproduce** il difetto riferito — sul telefono il
    /// token c'era, sopravvissuto all'installazione con `-r`, e il blocco ha
    /// fatto il suo lavoro. Resta perché fissa l'invariante: se un giorno il
    /// blocco scattasse davvero senza sessione, sarebbe qui che si vedrebbe.
    test('senza token non si chiede niente: si va al login', () async {
      blocco.acceso = true;
      token.salvato = null;

      final auth = AuthController(client, token, null, blocco);

      await auth.restore();

      expect(
        auth.state.status,
        AuthStatus.loggedOut,
        reason: 'Impronta chiesta a chi non ha ancora un account.',
      );
    });

    /// ⚠️ E nemmeno con un token **vuoto**, che è ciò che resta dopo un logout
    /// scritto male.
    test('nemmeno con un token vuoto', () async {
      blocco.acceso = true;
      token.salvato = '';

      final auth = AuthController(client, token, null, blocco);

      await auth.restore();

      expect(auth.state.status, AuthStatus.loggedOut);
    });

    test('sbloccando si entra', () async {
      blocco
        ..acceso = true
        ..apre = true;

      final auth = AuthController(client, token, null, blocco);

      await auth.restore();

      expect(await auth.sbloccaConImpronta(), isTrue);
      expect(auth.state.status, AuthStatus.loggedIn);
      expect(auth.state.user?.id, 7);
    });

    /// ⚠️ Dito bagnato, lettore che non legge, richiesta annullata: si resta
    /// bloccati e si **riprova**. Cancellare il token qui trasformerebbe un
    /// tentativo andato male in un logout.
    test('un tentativo fallito lascia bloccati, non disconnessi', () async {
      blocco
        ..acceso = true
        ..apre = false;

      final auth = AuthController(client, token, null, blocco);

      await auth.restore();

      expect(await auth.sbloccaConImpronta(), isFalse);
      expect(auth.state.status, AuthStatus.locked);
      expect(token.salvato, isNotNull);
    });

    /// 🚨 La via d'uscita **spegne il blocco**: chi ci arriva ci arriva perché
    /// l'impronta non funziona, e lasciarlo acceso lo rimetterebbe davanti allo
    /// stesso muro al riavvio successivo.
    test('«entra con la password» disconnette e spegne il blocco', () async {
      blocco.acceso = true;

      final auth = AuthController(client, token, null, blocco);

      await auth.restore();
      await auth.entraConLaPassword();

      expect(auth.state.status, AuthStatus.loggedOut);
      expect(token.salvato, isNull);
      expect(blocco.acceso, isFalse);
    });

    /// 💡 Un blocco rimasto acceso su un account che non c'è più chiederebbe
    /// l'impronta per sbloccare il nulla, subito prima di mandare al login.
    test('anche l\'uscita normale spegne il blocco', () async {
      blocco.acceso = true;

      final auth = AuthController(client, token, null, blocco);

      await auth.forgetSession();

      expect(blocco.acceso, isFalse);
    });
  });
}

/// Il doppio del blocco: `local_auth` parla con un canale di piattaforma che
/// nei test non esiste.
class _BloccoFinto implements BloccoBiometrico {
  bool acceso = false;

  /// Cosa risponde il lettore.
  bool apre = true;

  @override
  Future<bool> disponibile() async => true;

  @override
  Future<bool> attivo() async => acceso;

  @override
  Future<bool> imposta({required bool acceso}) async {
    this.acceso = acceso;

    return true;
  }

  @override
  Future<bool> sblocca({required String motivo}) async => apre;

  @override
  Future<bool> daProporre() async => !acceso && !proposto;

  @override
  Future<void> segnaProposto() async => proposto = true;

  /// Se la proposta di attivare lo sblocco è già stata mostrata — A1.
  bool proposto = false;

  @override
  Future<void> azzera() async {
    acceso = false;
    // ⚠️ Anche il «gliel'ho già chiesto» si dimentica: un telefono può passare
    // di mano, e chi accede dopo non ha mai visto nessuna proposta.
    proposto = false;
  }
}

/// 💡 `implements` + `noSuchMethod`: `ArchivioSalute` è una classe concreta con
/// decine di metodi, e qui ne serve **uno**. Dichiarare `noSuchMethod` dice al
/// compilatore «gli altri non li chiamo» — e se un giorno qualcuno li chiamasse,
/// il test fallirebbe nominando il metodo invece di passare in silenzio.
class _ArchivioFinto implements ArchivioSalute {
  bool svuotato = false;

  @override
  Future<void> svuota() async => svuotato = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CacheFinta implements LocalCache {
  int? ultima;

  @override
  int? get ultimaPersona => ultima;

  @override
  Future<void> setUltimaPersona(int id) async => ultima = id;

  @override
  Future<void> dimenticaUltimaPersona() async => ultima = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TokenStoreFinto implements TokenStore {
  String? salvato;

  @override
  Future<String?> read() async => salvato;

  @override
  Future<void> write(String token) async => salvato = token;

  @override
  Future<void> clear() async => salvato = null;

  @override
  void forgetCache() {}
}
