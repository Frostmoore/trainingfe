import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/branding_controller.dart';

/// La radice dell'app.
///
/// 🚨 **Il tema si ricostruisce quando cambia il branding.** È il punto in cui
/// ADR-A01 diventa vero: `watch` sul branding significa che appena arriva la
/// risposta di `/branding/lookup` tutta l'app cambia colore, senza riavviarla e
/// senza che nessuna schermata debba saperne niente.
class TrainingCompanionApp extends ConsumerWidget {
  const TrainingCompanionApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = ref.watch(brandingControllerProvider).branding;
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Training Companion',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.light(branding),
      darkTheme: AppTheme.dark(branding),
      // A3.4: si segue il tema di sistema. Forzare il chiaro su un telefono in
      // modalità scura di sera è la cosa che fa abbassare la luminosità e
      // chiudere l'app.
      themeMode: ThemeMode.system,

      // 🚨 L'italiano non è il default di Flutter: senza queste righe le date
      // del calendario e i mesi restano in inglese, e `DateFormat(…, 'it')`
      // lancia. Il fallback inglese resta per i telefoni configurati così.
      locale: const Locale('it'),
      supportedLocales: const [Locale('it'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      routerConfig: router,
    );
  }
}
