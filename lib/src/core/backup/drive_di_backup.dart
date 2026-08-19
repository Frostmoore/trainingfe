import 'dart:async';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

import 'cloud_di_backup.dart';

/// La copia di sicurezza nella cartella nascosta di Google Drive — N3.3.
///
/// ── 🚨 `appDataFolder`, e non una cartella nei documenti ───────────────────
///
/// È una cartella **per app, per persona**, che l'app vede e l'utente non trova
/// fra i propri file. ⚠️ Una cartella normale sarebbe stata cancellabile per
/// sbaglio mentre si fa ordine, e sarebbe comparsa fra i documenti come un file
/// misterioso che nessuno sa cosa sia.
///
/// 💡 E soprattutto: lo scope `drive.appdata` è **non sensibile** per Google.
/// Con `drive` o `drive.readonly` sarebbe servito un security assessment da
/// migliaia di euro — per la stessa funzione.
///
/// ── ⚠️ Cosa succede quando la persona disinstalla ─────────────────────────
///
/// Google **cancella la cartella**. È un backup, non un archivio, e va detto:
/// chi disinstalla per fare spazio e reinstalla dopo un mese non ci trova più
/// niente.
class DriveDiBackup implements CloudDiBackup {
  DriveDiBackup({required this.serverClientId});

  /// L'ID client **web** del progetto Google.
  ///
  /// 💡 Pubblico e non privato: Dart vieta i parametri con nome che cominciano
  /// per underscore, e girargli intorno con un costruttore a due righe
  /// costerebbe piu' di quello che nasconde. Non e' un segreto: finisce
  /// comunque dentro l'APK.
  final String serverClientId;

  bool _avviato = false;

  /// Il client Drive gia' autorizzato, tenuto da parte per qualche minuto.
  ///
  /// ── 🚨 Perche' esiste: senza, Google appariva «duemila volte» ────────
  ///
  /// **Ogni** operazione su Drive passava da `_api()`, che chiama
  /// `attemptLightweightAuthentication()` — e su Android quella disegna il
  /// riquadro con l'indirizzo email che «carica». Un ripristino fa **decine** di
  /// operazioni (il file, l'elenco degli allegati, ogni foto): il riquadro
  /// compariva e spariva a ogni giro, in momenti e forme diverse.
  ///
  /// ⚠️ Il committente l'ha descritto cosi': *«appare duemila volte, in tempi
  /// diversi e in modi diversi. Da' un'impressione di poca cura»*. Aveva
  /// ragione, e non era un problema di Google: era il nostro codice che
  /// richiedeva l'autorizzazione a ogni chiamata invece che una volta.
  ///
  /// 💡 Cinque minuti e non di piu': un token di accesso dura circa un'ora, ma
  /// tenerlo troppo vorrebbe dire non accorgersi di una revoca. Cinque minuti
  /// coprono un ripristino intero e restano onesti.
  drive.DriveApi? _clientTenuto;
  DateTime? _tenutoDal;

  static const _duraLaTenuta = Duration(minutes: 5);

  /// 🚨 Solo `drive.appdata`, e mai altro.
  ///
  /// ⚠️ Aggiungere `drive` o `drive.readonly` — anche «per comodità», anche
  /// temporaneamente — farebbe scattare la verifica ristretta di Google: un
  /// assessment di sicurezza da terza parte, con costi e settimane. Questa riga
  /// vale migliaia di euro e va lasciata com'è.
  static const _ambiti = <String>['https://www.googleapis.com/auth/drive.appdata'];

  /// I due nomi, e sono **due generazioni** — N3.4.
  ///
  /// 💡 Se un caricamento si interrompe a metà, quello precedente è ancora
  /// buono. ⚠️ Un backup solo è un backup che si può perdere proprio mentre lo
  /// si sta rifacendo — cioè nel momento in cui uno crede di essere al sicuro.
  static const _nomeAttuale = 'backup.tcb';
  static const _nomePrecedente = 'backup-precedente.tcb';

  static const _cartella = 'appDataFolder';

  @override
  String get nome => 'Google Drive';

  Future<void> _avvia() async {
    if (_avviato) return;

    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _avviato = true;
  }

  @override
  Future<bool> collega() async {
    await _avvia();

    try {
      /*
       * 💡 `authenticate()` chiede l'accesso all'identità; l'autorizzazione
       * agli **ambiti** è una cosa separata in `google_sign_in` 7.x, e va
       * chiesta dopo. ⚠️ Chiedere solo il primo darebbe un accesso che non può
       * scrivere niente, e il guasto comparirebbe al primo backup invece che
       * qui.
       */
      final conto = await GoogleSignIn.instance.authenticate(
        scopeHint: _ambiti,
      );

      final autorizzazione = await conto.authorizationClient.authorizeScopes(
        _ambiti,
      );

      return autorizzazione.accessToken.isNotEmpty;
    } on GoogleSignInException catch (e) {
      /*
       * 🚨 «Ha detto di no» **non è un errore**.
       *
       * ⚠️ Rifiutare l'accesso al proprio spazio è una risposta legittima:
       * trattarla come un guasto farebbe comparire un messaggio rosso a chi ha
       * solo cambiato idea.
       */
      if (e.code == GoogleSignInExceptionCode.canceled) return false;

      throw CloudNonRaggiungibile('Google ha rifiutato l\'accesso: ${e.code.name}');
    }
  }

  @override
  Future<void> scollega() async {
    await _avvia();

    // ⚠️ Scollegandosi si butta anche il client tenuto: riusarlo dopo vorrebbe
    // dire continuare a scrivere su un account da cui si e' appena usciti.
    _clientTenuto = null;
    _tenutoDal = null;

    await GoogleSignIn.instance.disconnect();
  }

  @override
  Future<bool> eCollegato() async {
    await _avvia();

    final conto = await GoogleSignIn.instance.attemptLightweightAuthentication();

    if (conto == null) return false;

    // ⚠️ Essere identificati non basta: serve **anche** l'autorizzazione agli
    // ambiti, e le due cose si revocano separatamente.
    final autorizzazione = await conto.authorizationClient.authorizationForScopes(
      _ambiti,
    );

    return autorizzazione != null;
  }

  @override
  Future<void> carica(Uint8List contenuto) async {
    final api = await _api();

    /*
     * 🚨 **Prima si sposta il vecchio, poi si scrive il nuovo.**
     *
     * ⚠️ L'ordine inverso — scrivo e poi archivio — lascerebbe una finestra in
     * cui esiste **un solo** file: se il caricamento si interrompesse lì, non
     * ci sarebbe più niente da cui ripristinare.
     */
    final vecchio = await _trova(api, _nomeAttuale);

    if (vecchio != null) {
      final precedente = await _trova(api, _nomePrecedente);

      if (precedente != null) {
        await api.files.delete(precedente.id!);
      }

      await api.files.update(
        drive.File()..name = _nomePrecedente,
        vecchio.id!,
      );
    }

    await api.files.create(
      drive.File()
        ..name = _nomeAttuale
        ..parents = [_cartella],
      uploadMedia: drive.Media(
        Stream.value(contenuto),
        contenuto.length,
        contentType: 'application/octet-stream',
      ),
    );
  }

  @override
  Future<Uint8List?> scarica() async {
    final api = await _api();

    /*
     * 💡 Si prova il file attuale, e **se non c'è si ripiega sul precedente**.
     *
     * ⚠️ È il caso di un caricamento interrotto: l'attuale può essere assente o
     * rovinato, e il precedente è comunque meglio di niente. Chi ripristina
     * vuole i suoi dati di ieri, non un messaggio d'errore.
     */
    for (final nome in [_nomeAttuale, _nomePrecedente]) {
      final file = await _trova(api, nome);

      if (file == null) continue;

      final media = await api.files.get(
        file.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final byte = <int>[];
      await for (final pezzo in media.stream) {
        byte.addAll(pezzo);
      }

      return Uint8List.fromList(byte);
    }

    return null;
  }

  @override
  Future<DateTime?> quandoLUltimo() async {
    final api = await _api();
    final file = await _trova(api, _nomeAttuale);

    return file?.modifiedTime;
  }

  @override
  Future<void> cancellaTutto() async {
    final api = await _api();

    for (final nome in [_nomeAttuale, _nomePrecedente]) {
      final file = await _trova(api, nome);

      if (file != null) await api.files.delete(file.id!);
    }

    /*
     * 🚨 **Anche gli allegati** — N5.
     *
     * ⚠️ Dimenticarli qui vorrebbe dire che «spegni e cancella» lascia nel
     * proprio Drive centinaia di megabyte di foto cifrate che nessuno vedrà
     * mai più e che continuano a occupare la quota. Chi ha detto «cancella
     * tutto» intendeva tutto.
     */
    for (final nome in await elencaAllegati()) {
      await cancellaAllegato(nome);
    }
  }

  // ────────────────────────── gli allegati ──────────────────────────

  /// 💡 Il prefisso serve a distinguerli dall'archivio dentro la stessa
  /// cartella, e a poterli elencare tutti con una domanda sola.
  static const _prefissoAllegato = 'allegato-';

  @override
  Future<void> caricaAllegato(String nome, Uint8List contenuto) async {
    final api = await _api();
    final vero = '$_prefissoAllegato$nome';

    // ⚠️ Si cancella e si riscrive invece di aggiornare: `files.update` con
    // media su appDataFolder è la strada in cui si inciampa sui permessi, e
    // qui riscrivere costa quanto aggiornare.
    final gia = await _trova(api, vero);

    if (gia != null) await api.files.delete(gia.id!);

    await api.files.create(
      drive.File()
        ..name = vero
        ..parents = [_cartella],
      uploadMedia: drive.Media(
        Stream.value(contenuto),
        contenuto.length,
        contentType: 'application/octet-stream',
      ),
    );
  }

  @override
  Future<Uint8List?> scaricaAllegato(String nome) async {
    final api = await _api();
    final file = await _trova(api, '$_prefissoAllegato$nome');

    if (file == null) return null;

    final media = await api.files.get(
      file.id!,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final byte = <int>[];

    await for (final pezzo in media.stream) {
      byte.addAll(pezzo);
    }

    return Uint8List.fromList(byte);
  }

  @override
  Future<Set<String>> elencaAllegati() async {
    final api = await _api();
    final nomi = <String>{};

    /*
     * 🚨 **Con le pagine, non senza.**
     *
     * ⚠️ Drive ne restituisce cento per volta. Fermarsi alla prima pagina
     * significherebbe, per chi ha più di cento foto, ricaricare ogni volta
     * tutte quelle dalla centunesima in poi — credendo che manchino.
     */
    String? pagina;

    do {
      final elenco = await api.files.list(
        q: "name contains '$_prefissoAllegato'",
        spaces: _cartella,
        $fields: 'nextPageToken,files(id,name)',
        pageSize: 1000,
        pageToken: pagina,
      );

      for (final f in elenco.files ?? const <drive.File>[]) {
        final n = f.name;

        if (n != null && n.startsWith(_prefissoAllegato)) {
          nomi.add(n.substring(_prefissoAllegato.length));
        }
      }

      pagina = elenco.nextPageToken;
    } while (pagina != null);

    return nomi;
  }

  @override
  Future<void> cancellaAllegato(String nome) async {
    final api = await _api();
    final file = await _trova(api, '$_prefissoAllegato$nome');

    // 💡 Non c'era: non è un errore. Cancellare qualcosa che già non esiste è
    // il risultato che si voleva.
    if (file != null) await api.files.delete(file.id!);
  }

  /// Il client di Drive, con il token in testa a ogni richiesta.
  Future<drive.DriveApi> _api() async {
    /*
     * 🚨 Se ce l'abbiamo gia', si riusa: e' l'unica riga che toglie di mezzo
     * il riquadro di Google che compariva a ogni operazione. Vedi
     * `_clientTenuto`.
     */
    final tenuto = _clientTenuto;
    final dal = _tenutoDal;

    if (tenuto != null && dal != null && DateTime.now().difference(dal) < _duraLaTenuta) {
      return tenuto;
    }

    await _avvia();

    final conto = await GoogleSignIn.instance.attemptLightweightAuthentication();

    if (conto == null) {
      throw const CloudNonRaggiungibile('Non sei collegato a Google Drive.');
    }

    final autorizzazione = await conto.authorizationClient.authorizationForScopes(
      _ambiti,
    );

    if (autorizzazione == null) {
      throw const CloudNonRaggiungibile(
        'Manca il permesso di scrivere nella cartella dell\'app.',
      );
    }

    final api = drive.DriveApi(_ClientConToken(autorizzazione.accessToken));

    _clientTenuto = api;
    _tenutoDal = DateTime.now();

    return api;
  }

  /// Cerca un file **dentro `appDataFolder`**.
  ///
  /// 🚨 `spaces: 'appDataFolder'` non è facoltativo: senza, la ricerca guarda
  /// nei documenti della persona — dove non abbiamo il permesso di guardare e
  /// dove il nostro file non c'è comunque.
  Future<drive.File?> _trova(drive.DriveApi api, String nome) async {
    final elenco = await api.files.list(
      q: "name = '$nome'",
      spaces: _cartella,
      $fields: 'files(id,name,modifiedTime)',
    );

    final file = elenco.files;

    return file == null || file.isEmpty ? null : file.first;
  }
}

/// 💡 `googleapis` vuole un `http.Client` che sappia autenticarsi da solo.
class _ClientConToken extends http.BaseClient {
  _ClientConToken(this._token);

  final String _token;
  final http.Client _dentro = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest richiesta) {
    richiesta.headers['Authorization'] = 'Bearer $_token';

    return _dentro.send(richiesta);
  }

  @override
  void close() {
    _dentro.close();
    super.close();
  }
}
