import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:sodium/sodium_sumo.dart';

/// libsodium per i test che girano sull'host — non sul telefono.
///
/// 🚨 **`sodium_libs` è un plugin Flutter, e in `flutter test` i plugin non
/// vengono registrati**: la macchina virtuale Dart gira senza il motore che
/// carica le librerie native. `SodiumInit.init()` di `sodium_libs` fallirebbe.
///
/// Senza questo aiuto **la crittografia non sarebbe testabile affatto**, e
/// resterebbe verificabile solo a mano su un telefono — cioè, in pratica, non
/// verificata. Per un pezzo di codice in cui un errore *non si vede* — un
/// messaggio cifrato male sembra esattamente come uno cifrato bene — è una
/// rinuncia che non ci si può permettere.
///
/// ⚠️ **Il binario è lo stesso che finisce nell'app**: si prende dal pacchetto
/// `sodium_libs`, risolto attraverso `package:`. Non è una seconda copia di
/// libsodium tenuta per i test, ed è il motivo per cui il percorso non è
/// scritto a mano: dipende dalla versione del pacchetto e dalla cartella della
/// cache di pub, che cambiano da macchina a macchina.
/// ⚠️ Restituisce un `SodiumSumo`, non un `Sodium`: **Argon2id (`crypto_pwhash`)
/// esiste solo nell'API sumo**, ed è la derivazione su cui poggia l'intera
/// password di recupero.
Future<SodiumSumo> libsodiumPerTest() async {
  final radice = _radiceDelPacchetto('sodium_libs');
  final binario = _binarioPerPiattaforma(radice);

  if (!File(binario.toFilePath()).existsSync()) {
    throw StateError('libsodium non trovato in ${binario.toFilePath()}');
  }

  return SodiumSumoInit.init(() => DynamicLibrary.open(binario.toFilePath()));
}

/// La cartella di un pacchetto, letta da `.dart_tool/package_config.json`.
///
/// ⚠️ **Non si usa `Isolate.resolvePackageUri`**: dentro `flutter test` lancia
/// `Unsupported operation`. Il file di configurazione invece c'è sempre — lo
/// scrive `pub get` — e la cartella di lavoro dei test è la radice del
/// progetto, quindi il percorso relativo regge.
Uri _radiceDelPacchetto(String nome) {
  final config = File('.dart_tool/package_config.json');

  if (!config.existsSync()) {
    throw StateError('Manca .dart_tool/package_config.json: lancia pub get.');
  }

  final pacchetti =
      (json.decode(config.readAsStringSync()) as Map<String, dynamic>)['packages']
          as List<dynamic>;

  for (final p in pacchetti.cast<Map<String, dynamic>>()) {
    if (p['name'] == nome) {
      // `rootUri` è relativo a `.dart_tool/`, non alla radice del progetto.
      return config.parent.uri.resolve('${p['rootUri']}/');
    }
  }

  throw StateError('Pacchetto $nome non presente fra le dipendenze.');
}

/// Dove `sodium_libs` tiene il binario, piattaforma per piattaforma.
Uri _binarioPerPiattaforma(Uri radice) {
  if (Platform.isWindows) {
    // v143 è il toolset di Visual Studio 2022, l'unico che il pacchetto
    // spedisce insieme al più vecchio v142.
    return radice.resolve('windows/lib/Release/v143/libsodium.dll');
  }

  if (Platform.isLinux) {
    return radice.resolve('linux/lib/libsodium.so');
  }

  throw UnsupportedError(
    'I test crittografici girano su Windows e Linux. '
    'Su ${Platform.operatingSystem} manca il percorso del binario.',
  );
}
