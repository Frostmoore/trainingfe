import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Dove vive la chiave maestra su questo telefono — S6.4.
///
/// 🚨 **Nel Keychain/Keystore, non in un file.** È la stessa scelta del token di
/// Sanctum, ma qui pesa di più: il token si revoca e si rifà, la chiave maestra
/// **no**. Persa quella, si perdono i messaggi e — dopo S7 — anche le schede e i
/// piani alimentari ricevuti.
///
/// 💡 **Perché ci si può appoggiare al portachiavi di sistema.** Apple e Google
/// non tengono questi segreti in chiaro: li custodiscono in moduli **hardware**
/// che accettano il PIN del dispositivo con un limite rigido — pochi tentativi
/// sbagliati e la chiave viene distrutta. Danno recupero senza poter leggere, e
/// non per fiducia: per il silicio. Un cluster di HSM noi non lo costruiamo, ma
/// possiamo delegargli il pezzo che non sappiamo fare.
///
/// ══ 🚨 UNA CHIAVE PER PERSONA, NON PER TELEFONO — 15/09/2026 ═══════════════
///
/// ⛔ **Fino al 15/09 la chiave stava sotto un nome fisso, uguale per chiunque
/// usasse quel telefono**, e `logout()` non la cancellava. Sullo stesso
/// dispositivo:
///
/// | Passo | Cosa succedeva |
/// |---|---|
/// | Anna crea la sua password di recupero | la sua chiave finisce nel telefono |
/// | Anna esce | la sessione se ne va, **la chiave resta** |
/// | Bruno entra col suo account | `ServizioChiavi.stato()` trova una chiave e risponde `pronto` |
/// | Bruno non vede mai la schermata della password | il controllo guardava **il telefono**, non chi era entrato |
/// | Bruno scrive | i suoi messaggi venivano chiusi **con la chiave di Anna** |
///
/// 🚨 Due danni, e il primo è il grave: chi si ritrova quel telefono — usato,
/// prestato, rivenduto — ha in mano la chiave che apre i messaggi, le schede e i
/// piani della persona di prima. Il secondo è che il secondo account non
/// pubblica nessuna chiave sul server, quindi chi gli scrive legge *«questa
/// persona non ha ancora una chiave»* e lui scrive messaggi che **nessuno potrà
/// riaprire**, senza nessun avviso.
///
/// ⚠️ Visto sull'emulatore il 15/09 facendo una chat fra un trainer e un'allieva:
/// alla seconda persona la password **non veniva chiesta**. Cancellati i dati
/// dell'app, stesso account, la password gliela chiedeva e la chat funzionava.
///
/// 💡 **Adesso lo slot porta l'identificativo di chi è entrato**
/// (`chiave_maestra_42`), quindi due persone sullo stesso telefono non si
/// incontrano mai. ⚖️ E chi esce e rientra **non deve ridigitare niente**: la
/// sua chiave è ancora al posto suo.
class Portachiavi {
  Portachiavi({required this.utenteId, FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              // `first_unlock` come per il token: dopo un riavvio la chiave non
              // è leggibile finché il telefono non viene sbloccato almeno una
              // volta. Un telefono spento e rubato non la consegna.
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  /// Di chi è questo portachiavi.
  ///
  /// 🚨 **`null` vuol dire «non si sa ancora chi è entrato»**, e non è un caso
  /// da trattare alla leggera: senza un nome non si può né leggere né scrivere
  /// una chiave, perché non si saprebbe di chi sarebbe.
  ///
  /// ⚠️ Succede davvero — fra l'avvio dell'app e la risposta di `/auth/me` —
  /// ed è il motivo per cui questa classe ha due comportamenti diversi nei due
  /// versi: in **lettura** risponde `null`, che manda `ServizioChiavi.stato()`
  /// a chiedere al server e al massimo costa una password di troppo; in
  /// **scrittura** lancia, perché una chiave salvata sotto il nome sbagliato è
  /// una chiave persa.
  final int? utenteId;

  final FlutterSecureStorage _storage;

  /// ⛔ **Il nome vecchio, senza nessun proprietario.** Non si legge più: si
  /// cancella **dopo** che una chiave nuova ha trovato casa. Vedi
  /// `_buttaViaLaChiaveDiNessuno()`.
  static const _chiaveDiNessuno = 'chiave_maestra';

  static const _giaUsata = 'app_gia_usata';

  Uint8List? _cache;
  bool _legacyGuardata = false;

  /// Lo slot di questa persona. `null` se non si sa chi è.
  String? get _slot => utenteId == null ? null : 'chiave_maestra_$utenteId';

  /// ⛔ **La chiave senza proprietario non si eredita — e si butta solo DOPO.**
  ///
  /// 🚨 Non si prova a indovinare di chi fosse: l'unico modo onesto sarebbe
  /// confrontare la chiave pubblica che ne deriva con quella pubblicata dal
  /// server per **questo** account, e finché non si fa quel confronto
  /// assegnarla a chi passa di qui è esattamente il difetto che questa classe
  /// è stata riscritta per chiudere.
  ///
  /// ⚖️ **Ma si cancella al momento giusto, e non è un dettaglio.** Chiamarla
  /// in lettura — come faceva la prima stesura — avrebbe distrutto la vecchia
  /// chiave **prima** che la persona avesse ridigitato la password di recupero:
  /// una finestra in cui chi non se la ricorda più non ha nessun modo di
  /// tornare indietro.
  ///
  /// 💡 Qui invece si chiama solo da [salvaChiaveMaestra], cioè quando una
  /// chiave è già finita in uno slot con un nome: a quel punto quella vecchia
  /// non serve più a nessuno.
  ///
  /// ⚠️ **La sicurezza non dipende da questa cancellazione**: dipende dal fatto
  /// che [chiaveMaestra] quella chiave non la **legge**. Questo è solo igiene,
  /// e l'igiene può aspettare il momento in cui non costa niente.
  Future<void> _buttaViaLaChiaveDiNessuno() async {
    if (_legacyGuardata) return;

    _legacyGuardata = true;
    await _storage.delete(key: _chiaveDiNessuno);
  }

  /// La chiave maestra di questa persona, se questo telefono ce l'ha.
  Future<Uint8List?> chiaveMaestra() async {
    final slot = _slot;

    // 🚨 Senza un nome non si legge: vedi il dartdoc di [utenteId].
    if (slot == null) return null;

    // ⚠️ **Qui NON si cancella la chiave vecchia**: vedi
    // [_buttaViaLaChiaveDiNessuno]. Non leggerla basta a chiudere la falla;
    // distruggerla prima che qualcuno abbia ridigitato la password no.
    if (_cache != null) return _cache;

    final salvata = await _storage.read(key: slot);

    return salvata == null ? null : _cache = base64Decode(salvata);
  }

  Future<void> salvaChiaveMaestra(Uint8List chiave) async {
    final slot = _slot;

    if (slot == null) {
      // 🚨 Lancia invece di scegliere uno slot di ripiego: una chiave salvata
      // sotto il nome sbagliato non si ritrova più, e il danno si vedrebbe al
      // prossimo avvio — lontano da qui.
      throw StateError(
        'Non so di chi sia questa chiave maestra: nessun utente è entrato.',
      );
    }

    await _buttaViaLaChiaveDiNessuno();

    _cache = chiave;
    await _storage.write(key: slot, value: base64Encode(chiave));
    await _storage.write(key: _giaUsata, value: 'si');
  }

  /// 🚨 **Il segnale che decide la sequenza di ripristino** (S6.7).
  ///
  /// *«Noi possiamo controllare se l'utente ha già usato l'app: basta che sia
  /// registrato e sia su un dispositivo nuovo, e questo ce lo dice una banale
  /// booleana on-device.»* — il committente.
  ///
  /// ⚠️ È **on-device di proposito**, e la differenza conta: dice «questo
  /// telefono ha già una storia», che è un'altra domanda rispetto a «questo
  /// account ha già una storia». La seconda la risponde il server, con
  /// l'esistenza del pacchetto incartato.
  ///
  /// ⚖️ **Per questo resta senza proprietario**, mentre la chiave ce l'ha: la
  /// domanda parla del telefono, non della persona.
  Future<bool> appGiaUsataQui() async =>
      await _storage.read(key: _giaUsata) == 'si';

  /// Cancella la chiave **di questa persona**: uscita, o ripristino andato
  /// storto.
  ///
  /// ⚠️ **Non tocca `app_gia_usata`**: quel telefono la storia ce l'ha avuta lo
  /// stesso, e dimenticarlo farebbe ripartire il ripristino dal ramo sbagliato.
  Future<void> dimenticaChiave() async {
    _cache = null;

    final slot = _slot;
    if (slot == null) return;

    await _storage.delete(key: slot);
  }

  /// Solo per i test: azzera la copia in memoria senza toccare il portachiavi.
  void scordaCache() => _cache = null;
}
