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
class Portachiavi {
  Portachiavi({FlutterSecureStorage? storage})
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

  final FlutterSecureStorage _storage;

  static const _chiaveMaestra = 'chiave_maestra';
  static const _giaUsata = 'app_gia_usata';

  Uint8List? _cache;

  /// La chiave maestra, se questo telefono ce l'ha.
  Future<Uint8List?> chiaveMaestra() async {
    if (_cache != null) return _cache;

    final salvata = await _storage.read(key: _chiaveMaestra);

    return salvata == null ? null : _cache = base64Decode(salvata);
  }

  Future<void> salvaChiaveMaestra(Uint8List chiave) async {
    _cache = chiave;
    await _storage.write(key: _chiaveMaestra, value: base64Encode(chiave));
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
  Future<bool> appGiaUsataQui() async =>
      await _storage.read(key: _giaUsata) == 'si';

  /// Cancella tutto: uscita dall'account, o ripristino andato storto.
  ///
  /// ⚠️ **Non tocca `app_gia_usata`**: quel telefono la storia ce l'ha avuta lo
  /// stesso, e dimenticarlo farebbe ripartire il ripristino dal ramo sbagliato.
  Future<void> dimenticaChiave() async {
    _cache = null;
    await _storage.delete(key: _chiaveMaestra);
  }

  /// Solo per i test: azzera la copia in memoria senza toccare il portachiavi.
  void scordaCache() => _cache = null;
}
