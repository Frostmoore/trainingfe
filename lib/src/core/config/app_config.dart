/// Configurazione dell'ambiente — A1.2.
///
/// 🚨 **Passa da `--dart-define`, non da un file.** Un file di configurazione
/// committato finisce dentro il bundle pubblicato: chiunque scompatti l'APK
/// legge l'URL dello staging e ci punta contro. Con `--dart-define` il valore è
/// deciso al momento della compilazione, e la build di produzione non contiene
/// nemmeno la stringa dell'ambiente di collaudo.
///
/// Le tre build:
/// ```bash
/// fvm flutter run                                    # locale, default
/// fvm flutter run  --dart-define=ENV=staging
/// fvm flutter build apk --dart-define=ENV=production \
///                       --dart-define=API_BASE_URL=https://…
/// ```
library;

/// Gli ambienti in cui l'app può girare.
enum AppEnvironment {
  /// Sviluppo sulla macchina di chi programma.
  local,

  /// `training.riccardoronconi.it`.
  staging,

  /// L'app pubblicata.
  production;

  static AppEnvironment fromName(String value) => switch (value) {
    'staging' => AppEnvironment.staging,
    'production' => AppEnvironment.production,
    _ => AppEnvironment.local,
  };

  bool get isProduction => this == AppEnvironment.production;
}

/// Tutto quello che cambia fra un ambiente e l'altro, in un posto solo.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableDebugTools,
  });

  /// Costruisce la configurazione dai `--dart-define`.
  ///
  /// L'URL si può forzare (`API_BASE_URL`) perché su Android l'emulatore non
  /// vede `localhost` della macchina host: serve `10.0.2.2`, e su un telefono
  /// vero serve l'IP della rete locale. Senza questa possibilità, provare
  /// sull'hardware richiederebbe di ricompilare cambiando una costante.
  factory AppConfig.fromEnvironment() {
    const rawEnv = String.fromEnvironment('ENV', defaultValue: 'local');
    const override = String.fromEnvironment('API_BASE_URL');

    final environment = AppEnvironment.fromName(rawEnv);

    return AppConfig(
      environment: environment,
      apiBaseUrl: override.isNotEmpty ? override : _defaultBaseUrl(environment),
      // Gli strumenti di debug non esistono in produzione, e la condizione è
      // sull'ambiente e non su `kDebugMode`: una build di profilo verso
      // produzione non deve mostrarli.
      enableDebugTools: !environment.isProduction,
    );
  }

  final AppEnvironment environment;

  /// Comprende già `/api/v1`: nessun chiamante deve ricordarselo.
  final String apiBaseUrl;

  final bool enableDebugTools;

  static String _defaultBaseUrl(AppEnvironment environment) => switch (environment) {
    // 10.0.2.2 è l'host visto dall'emulatore Android. Su iOS Simulator
    // funziona `localhost`, ma questo valore va bene per entrambi solo su
    // Android: per il simulatore iOS si passa `API_BASE_URL`.
    AppEnvironment.local => 'http://10.0.2.2:8123/api/v1',
    AppEnvironment.staging => 'https://training.riccardoronconi.it/api/v1',
    AppEnvironment.production => 'https://training.riccardoronconi.it/api/v1',
  };

  @override
  String toString() => 'AppConfig(${environment.name}, $apiBaseUrl)';
}
