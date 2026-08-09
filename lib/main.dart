import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/app.dart';
import 'src/core/config/app_config.dart';
import 'src/core/providers.dart';
import 'src/core/storage/local_cache.dart';
import 'src/features/auth/auth_controller.dart';
import 'src/features/onboarding/branding_controller.dart';

/// L'avvio — A1.1.
///
/// 🚨 **Tutto quello che è asincrono succede QUI, non nel primo `build()`.**
/// Un widget che aspetta `SharedPreferences.getInstance()` mostra mezzo secondo
/// di schermata bianca a ogni apertura — ed è la prima cosa che si nota di
/// un'app. Qui invece si costruisce il necessario, si sovrascrivono i provider
/// che non possono costruirsi da soli, e l'albero parte già completo.
Future<void> main() async {
  // `runZonedGuarded` avvolge tutto: senza, un errore asincrono fuori dal ciclo
  // dei widget termina il processo senza lasciare traccia, e l'utente vede
  // l'app «che si chiude da sola».
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // I nomi dei mesi in italiano: `DateFormat(…, 'it')` lancia se questa non
      // è stata chiamata, e lo fa alla **prima data formattata**, cioè in una
      // schermata a caso e non all'avvio.
      await initializeDateFormatting('it');

      FlutterError.onError = (dettagli) {
        FlutterError.presentError(dettagli);
        _segnala(dettagli.exception, dettagli.stack);
      };

      final config = AppConfig.fromEnvironment();
      final cache = await LocalCache.open();

      final container = ProviderContainer(
        overrides: [
          appConfigProvider.overrideWithValue(config),
          localCacheProvider.overrideWithValue(cache),
        ],
      );

      // 🚨 Si fa partire il ripristino della sessione **prima** di disegnare:
      // il router resta su `AuthStatus.unknown` e non decide niente finché non
      // c'è una risposta. Senza, ogni avvio manderebbe al login per la frazione
      // di secondo che serve a leggere il Keychain — e quel salto si vede.
      unawaited(container.read(authControllerProvider.notifier).restore());

      // Il branding si riallinea in sottofondo: se fallisce, resta quello in
      // cache. I colori sbagliati sono un problema estetico, un'app che non
      // parte no.
      unawaited(container.read(brandingControllerProvider.notifier).refreshQuietly());

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const TrainingCompanionApp(),
        ),
      );
    },
    (errore, stack) => _segnala(errore, stack),
  );
}

/// Il punto unico in cui finiscono gli errori non gestiti.
///
/// Oggi scrive solo sulla console in sviluppo. È scritto così perché il giorno
/// in cui si aggiunge un servizio di crash reporting ci sia **un posto solo** da
/// toccare, invece di cercare tutti i `catch` sparsi.
void _segnala(Object errore, StackTrace? stack) {
  if (kDebugMode) {
    debugPrint('Errore non gestito: $errore\n$stack');
  }
}
