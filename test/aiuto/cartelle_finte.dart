import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Cartelle di sistema finte, per i test che scrivono file — N9.5.
///
/// 🚨 **`path_provider` è un plugin, e in `flutter test` i plugin non ci sono**:
/// la macchina virtuale gira senza il motore che li registra, quindi
/// `getApplicationDocumentsDirectory()` lancerebbe `MissingPluginException`.
///
/// 💡 Si sostituisce l'**implementazione di piattaforma** invece di simulare il
/// canale a mano: è il punto di innesto che il pacchetto offre apposta, e non
/// si rompe quando cambia il modo in cui parla col nativo. È lo stesso spirito
/// di `test/aiuto/libsodium.dart`, che risolve lo stesso problema per la
/// crittografia.
///
/// ⚠️ Documenti e cache sono **due cartelle diverse**, e devono restarlo: metà
/// delle regole delle foto sta proprio nella differenza fra le due — quello che
/// finisce nella cache non entra in nessun backup, per costruzione.
class CartelleFinte extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  CartelleFinte(this.radice);

  /// La cartella temporanea sotto cui vivono le due finte.
  final Directory radice;

  /// Installa le cartelle finte e le smonta a fine test.
  ///
  /// @return la radice, per poterci guardare dentro.
  static Directory installa({required void Function(void Function()) aFine}) {
    final radice = Directory.systemTemp.createTempSync('cartelle-finte');
    final prima = PathProviderPlatform.instance;

    PathProviderPlatform.instance = CartelleFinte(radice);

    aFine(() {
      PathProviderPlatform.instance = prima;

      if (radice.existsSync()) radice.deleteSync(recursive: true);
    });

    return radice;
  }

  Directory _sotto(String nome) {
    final d = Directory('${radice.path}${Platform.pathSeparator}$nome');

    if (!d.existsSync()) d.createSync(recursive: true);

    return d;
  }

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      _sotto('documenti').path;

  @override
  Future<String?> getApplicationCachePath() async => _sotto('cache').path;

  @override
  Future<String?> getTemporaryPath() async => _sotto('temporanea').path;

  @override
  Future<String?> getApplicationSupportPath() async => _sotto('supporto').path;
}
