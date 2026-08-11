import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../api/api_client.dart';
import '../errors/api_exception.dart';
import 'busta_messaggio.dart';
import 'cassaforte.dart';
import 'portachiavi.dart';

/// Cosa deve fare l'app all'avvio, riguardo alle chiavi — S6.7.
enum StatoChiavi {
  /// La chiave maestra è su questo telefono: si può scrivere e leggere.
  pronto,

  /// Account nuovo: non esiste nessun pacchetto incartato sul server.
  /// Si chiede di **creare** la password di recupero.
  daCreare,

  /// 🚨 **Il caso che va trattato per primo e con la massima cura.**
  ///
  /// Sul server c'è un pacchetto, su questo telefono no: è qualcuno che ha
  /// cambiato dispositivo, o reinstallato. Si chiede la password di recupero —
  /// **non si genera niente**.
  daRipristinare,
}

/// Le chiavi dell'account, dal punto di vista dell'app — S6.4 / S6.7.
///
/// ── 🚨 L'ordine della sequenza di ripristino, che è facile sbagliare ───────
///
/// La domanda *«hai già usato questa app?»* deve arrivare **prima** che l'app
/// generi una chiave maestra nuova. Sbagliando l'ordine ci si ritrova con due
/// chiavi: quella appena generata, con cui l'app comincia subito a lavorare, e
/// quella vera, che sta ancora dietro il pacchetto sul server — e il primo
/// salvataggio scrive sopra al pacchetto buono, chiudendo la persona fuori dai
/// propri messaggi **per sempre**.
///
/// ⚠️ Il segnale non è «l'utente è registrato» — lo è sempre, a questo punto —
/// ma **«esiste il pacchetto incartato sul server»**. Per questo [stato] chiede
/// al server prima di decidere, e per questo [creaPasswordDiRecupero] rifiuta di
/// funzionare se un pacchetto c'è già.
class ServizioChiavi {
  // ⚠️ `prefer_initializing_formals` qui non si può soddisfare: Dart vieta i
  // parametri con nome che cominciano per underscore, quindi `this._api` non è
  // scrivibile in un costruttore a parametri nominati. L'alternativa sarebbe
  // rendere pubblici due campi che nessuno fuori da questa classe deve toccare.
  // ignore_for_file: prefer_initializing_formals
  ServizioChiavi({
    required SodiumSumo sodium,
    required ApiClient api,
    required Portachiavi portachiavi,
  }) : _api = api,
       _portachiavi = portachiavi,
       _sodium = sodium,
       _cassaforte = Cassaforte(sodium),
       cifratura = CifraturaChat(sodium);

  /// ⚠️ Una sola istanza di libsodium in tutta l'app. Due inizializzazioni
  /// funzionerebbero, ma le `SecureKey` dell'una non sono utilizzabili con
  /// l'altra, e il fallimento arriverebbe lontano dal punto che l'ha causato.
  final SodiumSumo _sodium;

  final ApiClient _api;
  final Portachiavi _portachiavi;
  final Cassaforte _cassaforte;

  /// Esposta perché la chat ci cifra e decifra sopra.
  final CifraturaChat cifratura;

  KeyPair? _identita;

  // ───────────────────────── all'avvio ─────────────────────────

  /// Cosa serve fare adesso.
  ///
  /// ⚠️ Se il server non risponde si dice [StatoChiavi.daRipristinare], non
  /// [StatoChiavi.daCreare]: sbagliando in questa direzione si chiede una
  /// password di troppo, sbagliando nell'altra si distrugge un account.
  Future<StatoChiavi> stato() async {
    if (await _portachiavi.chiaveMaestra() != null) {
      return StatoChiavi.pronto;
    }

    try {
      final pacchetto = await _pacchettoDalServer();

      return pacchetto == null ? StatoChiavi.daCreare : StatoChiavi.daRipristinare;
    } on ApiException {
      return StatoChiavi.daRipristinare;
    }
  }

  // ───────────────────────── creazione ─────────────────────────

  /// Genera la chiave maestra e la chiude dietro la password di recupero.
  ///
  /// 🚨 **Rifiuta di procedere se un pacchetto esiste già.** Non è prudenza
  /// eccessiva: è l'unica cosa che impedisce a un ordine sbagliato delle
  /// schermate di cancellare la chiave vera di qualcuno.
  ///
  /// 🚨 **Chi dimentica questa password perde tutto**, e va detto nella
  /// schermata in cui la si crea, non in una casella da spuntare. È la
  /// definizione di end-to-end: se potessimo recuperarla, potremmo leggere.
  Future<void> creaPasswordDiRecupero(String password) async {
    if (await _pacchettoDalServer() != null) {
      throw StateError(
        'Questo account ha già una password di recupero: va ripristinato, '
        'non ricreato.',
      );
    }

    final maestra = _cassaforte.generaChiaveMaestra();

    await _incartaESalva(maestra: maestra, password: password);
  }

  // ───────────────────────── ripristino ─────────────────────────

  /// Riapre il pacchetto del server con la password e si porta a casa la chiave.
  ///
  /// Lancia [PasswordDiRecuperoSbagliata] se non è quella.
  Future<void> ripristinaConPassword(String password) async {
    final json = await _pacchettoDalServer();

    if (json == null) {
      throw StateError('Non c\'è nessun pacchetto da ripristinare.');
    }

    final maestra = _cassaforte.scarta(
      pacchetto: PacchettoIncartato.fromJson(json),
      password: password,
    );

    await _adotta(maestra);
  }

  /// Il ripristino a partire da un file di backup esportato (S6.6).
  ///
  /// 💡 Serve il caso *«ho scordato la password **e** non avevo il backup di
  /// sistema»*: qui la chiave maestra arriva dal file, non dal server, e il
  /// pacchetto viene **riscritto** con la password nuova.
  Future<void> ripristinaDaChiave({
    required Uint8List chiaveMaestra,
    required String nuovaPassword,
  }) async {
    await _incartaESalva(
      maestra: SecureKey.fromList(_sodium, chiaveMaestra),
      password: nuovaPassword,
    );
  }

  // ───────────────────────── manutenzione ─────────────────────────

  /// Cambia la password di recupero.
  ///
  /// ⚠️ **Serve quella vecchia.** Senza, chiunque avesse il telefono sbloccato
  /// per un minuto potrebbe sostituirla e chiudere fuori il proprietario.
  ///
  /// 💡 Non tocca **nessun** messaggio: la chiave maestra è *incartata* dalla
  /// password, non derivata da essa, quindi cambiare password re-incarta poche
  /// decine di byte. È l'intera ragione di quella scelta.
  Future<void> cambiaPassword({
    required String vecchia,
    required String nuova,
  }) async {
    final json = await _pacchettoDalServer();

    if (json == null) {
      throw StateError('Non c\'è nessuna password di recupero da cambiare.');
    }

    final maestra = _cassaforte.scarta(
      pacchetto: PacchettoIncartato.fromJson(json),
      password: vecchia,
    );

    await _incartaESalva(maestra: maestra, password: nuova);
  }

  // ───────────────────────── uso quotidiano ─────────────────────────

  /// L'identità X25519 di questo account, ricalcolata dalla chiave maestra.
  ///
  /// Lancia [StateError] se la chiave maestra non c'è: chiamarla in quello
  /// stato è un errore di programmazione, non una condizione da gestire con un
  /// `null` che poi qualcuno ignora.
  Future<KeyPair> identita() async {
    if (_identita != null) return _identita!;

    final maestra = await _portachiavi.chiaveMaestra();

    if (maestra == null) {
      throw StateError('Nessuna chiave maestra su questo dispositivo.');
    }

    return _identita = _cassaforte.identitaChat(
      SecureKey.fromList(_sodium, maestra),
    );
  }

  /// La chiave con cui si cifra il file di backup esportabile.
  Future<SecureKey> chiaveBackup() async {
    final maestra = await _portachiavi.chiaveMaestra();

    if (maestra == null) {
      throw StateError('Nessuna chiave maestra su questo dispositivo.');
    }

    return _cassaforte.chiaveBackup(
      SecureKey.fromList(_sodium, maestra),
    );
  }

  /// La chiave pubblica dell'altra persona in una conversazione.
  ///
  /// Restituisce `null` se non ne ha ancora una — cioè se non ha mai aperto
  /// l'app dopo questa versione. ⚠️ L'app deve dirlo («non puoi ancora
  /// scrivergli»): cifrare verso il nulla produrrebbe un messaggio che nessuno
  /// potrà mai leggere.
  Future<ChiavePubblica?> chiaveDellAltro(int conversationId) async {
    try {
      final json = await _api.get<Map<String, dynamic>>(
        '/conversations/$conversationId/key',
      );

      return ChiavePubblica(
        userId: (json['user_id'] as num).toInt(),
        byte: base64Decode(json['public_key'] as String),
        aggiornataIl: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
      );
    } on NotFoundException {
      return null;
    }
  }

  // ───────────────────────── interni ─────────────────────────

  /// Incarta, manda al server, salva in locale, pubblica la chiave pubblica.
  ///
  /// 🚨 **L'ordine non è indifferente: prima il server, poi il telefono.** Se il
  /// caricamento fallisse dopo il salvataggio locale, l'app lavorerebbe con una
  /// chiave che il server non conosce — e al primo cambio di telefono non ci
  /// sarebbe niente da ripristinare, senza che nessuno se ne fosse accorto.
  Future<void> _incartaESalva({
    required SecureKey maestra,
    required String password,
  }) async {
    final pacchetto = _cassaforte.incarta(
      chiaveMaestra: maestra,
      password: password,
    );

    await _api.put<dynamic>(
      '/account/recovery-key',
      body: {...pacchetto.toJson(), 'kdf': 'argon2id13'},
    );

    await _adotta(maestra);
  }

  /// Fa propria una chiave maestra: la salva e pubblica l'identità che ne esce.
  Future<void> _adotta(SecureKey maestra) async {
    _identita = _cassaforte.identitaChat(maestra);

    await _portachiavi.salvaChiaveMaestra(maestra.extractBytes());

    await _api.put<dynamic>(
      '/chat-key',
      body: {'public_key': base64Encode(_identita!.publicKey)},
    );
  }

  Future<Map<String, dynamic>?> _pacchettoDalServer() async {
    final json = await _api.get<Map<String, dynamic>?>('/account/recovery-key');

    return json;
  }
}

/// La chiave pubblica di qualcun altro, con quando è cambiata.
class ChiavePubblica {
  const ChiavePubblica({
    required this.userId,
    required this.byte,
    this.aggiornataIl,
  });

  final int userId;
  final Uint8List byte;

  /// ⚠️ Serve a accorgersi che la chiave è **cambiata** rispetto a quella vista
  /// l'ultima volta. Il caso di gran lunga più comune non è un attacco: è
  /// qualcuno che ha perso la chiave maestra e ne ha generata una nuova.
  final DateTime? aggiornataIl;
}
