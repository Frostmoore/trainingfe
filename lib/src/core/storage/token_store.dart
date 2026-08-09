import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Il token di Sanctum, nel Keychain/Keystore — A1.4.
///
/// 🚨 **Non in `shared_preferences`.** Quello è un file XML in chiaro: su un
/// telefono con root, o su un backup non cifrato, si legge. Il token di Sanctum
/// non scade da solo e vale quanto la password — anzi di più, perché non
/// richiede il secondo fattore.
///
/// L'interfaccia è volutamente minima: chi la usa non deve poter fare altro che
/// leggere, scrivere e cancellare. Una `Map` esposta diventerebbe il posto dove
/// qualcuno mette anche il resto.
class TokenStore {
  TokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // `encryptedSharedPreferences` è obbligatorio su Android: senza,
            // il pacchetto ricade su preferenze normali su alcune versioni,
            // vanificando il punto di usarlo.
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              // `first_unlock` e non `always`: dopo un riavvio il token non è
              // leggibile finché l'utente non sblocca il telefono almeno una
              // volta. Un telefono spento e rubato non lo consegna.
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'sanctum_token';

  /// Copia in memoria per non pagare una lettura dal Keychain a **ogni**
  /// richiesta HTTP: su Android quella lettura è una chiamata di piattaforma,
  /// e in una lista che carica dieci risorse si sente.
  String? _cached;

  Future<String?> read() async {
    if (_cached != null) return _cached;

    return _cached = await _storage.read(key: _tokenKey);
  }

  Future<void> write(String token) async {
    _cached = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    await _storage.delete(key: _tokenKey);
  }

  /// Solo per i test: azzera la copia in memoria senza toccare il Keychain.
  void forgetCache() => _cached = null;
}
