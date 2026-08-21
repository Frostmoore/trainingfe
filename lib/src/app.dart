import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/aggiornamento/aggiornamento_controller.dart';
import 'features/aggiornamento/ui/schermata_aggiorna.dart';
import 'features/onboarding/branding_controller.dart';
import 'features/profile/colore_accento.dart';

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
    final palestra = ref.watch(brandingControllerProvider).branding;

    /*
     * ══ 🆕 IL COLORE SCELTO VALE SOLO SENZA PALESTRA — 3b-O.1a.1 ══════════
     *
     * 📌 *«il colore di accento deve essere quello della palestra, se è un
     * utente free_user, questo deve poter scegliere il suo colore»*.
     *
     * 🚨 **L'ordine è questo e non l'inverso**: la palestra vince sempre. Il
     * colore è l'identità del cliente (ADR-A01), ed è il motivo per cui l'app si
     * chiama white-label — lasciarlo cambiare a un iscritto vorrebbe dire che
     * può spegnere il marchio della palestra che lo paga.
     *
     * 💡 `palestra.name` vuoto è il segno che una palestra non c'è: è lo
     * stesso controllo che l'intestazione usa per decidere quale nome scrivere.
     */
    final senzaPalestra = !(palestra.name?.isNotEmpty ?? false);

    final scelto = senzaPalestra
        ? ColoreAccento.daNome(ref.watch(accentoSceltoProvider))
        : null;

    final branding = scelto == null
        ? palestra
        : palestra.copyWith(primary: scelto);
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

      /*
       * 🆕 **Il cancello della versione sta SOPRA il router** — FASE 10.
       *
       * 🚨 Non è una rotta, ed è deliberato: una rotta si può lasciare con il
       * tasto indietro, e da questa schermata **non si deve uscire**. Il
       * `builder` avvolge qualunque cosa il router stia mostrando, compresi i
       * fogli modali aperti.
       *
       * ⚠️ E vale anche prima dell'accesso: una copia vecchia non deve poter
       * fare il login per poi sbattere una schermata alla volta.
       */
      builder: (context, figlio) {
        final daAggiornare = ref.watch(aggiornamentoProvider).serve;

        return daAggiornare
            ? const SchermataAggiorna()
            : (figlio ?? const SizedBox.shrink());
      },
    );
  }
}
