import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/aggiornamento/aggiornamento_controller.dart';
import 'features/aggiornamento/ui/schermata_aggiorna.dart';
import 'features/auth/auth_controller.dart';
import 'features/diary/data/trasloco_del_diario.dart';
import 'features/onboarding/branding_controller.dart';
import 'features/onboarding/riferimento_dell_installazione.dart';
import 'features/profile/colore_accento.dart';
import 'features/training/data/limiti_delle_schede.dart';

/// La radice dell'app.
///
/// 🚨 **Il tema si ricostruisce quando cambia il branding.** È il punto in cui
/// ADR-A01 diventa vero: `watch` sul branding significa che appena arriva la
/// risposta di `/branding/lookup` tutta l'app cambia colore, senza riavviarla e
/// senza che nessuna schermata debba saperne niente.
class TrainingCompanionApp extends ConsumerStatefulWidget {
  const TrainingCompanionApp({super.key});

  @override
  ConsumerState<TrainingCompanionApp> createState() =>
      _TrainingCompanionAppState();
}

class _TrainingCompanionAppState extends ConsumerState<TrainingCompanionApp> {
  @override
  void initState() {
    super.initState();

    /*
     * ── 🔗 L'invito da cui viene questa installazione — 3b-V.3.3 ──────────
     *
     * Chi tocca un link d'invito senza avere l'app finisce sullo store: dopo
     * l'installazione, il Play Store ci passa il token e l'app apre l'invito
     * da sola.
     *
     * 🚨 **Dopo il primo fotogramma, e non dentro `build`.** Serve il router
     * montato per poterci navigare, e un `build` che naviga è un `build` che
     * si rifà navigando ancora.
     *
     * ⛔ **Oggi non fa niente**: funziona solo per le installazioni dal Play
     * Store, e l'app si carica a mano. È la strada per quando sarà pubblicata,
     * e il ripiego (riaprire il link) resta e funziona intanto.
     */
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _invitoDallInstallazione(),
    );

    /*
     * ══ 📦 IL DIARIO VIENE A CASA — Parte I / I3, 02/09/2026 ═══════════════
     *
     * 🚨 **Quando c'è un accesso, non al primo fotogramma.** All'avvio la
     * sessione può non esserci ancora — il token si legge dal disco, e chi apre
     * l'app da spenta passa per qualche istante di «non lo so». ⛔ Partire lì
     * vorrebbe dire un 401, il trasloco segnato come non riuscito, e un giro a
     * vuoto a ogni avvio.
     *
     * 💡 `listenManual` e non `ref.listen`: quello vive dentro `build`, e questo
     * deve sopravvivere ai ridisegni — è un gesto che si fa **una volta nella
     * vita dell'installazione**, non a ogni fotogramma.
     *
     * ⚠️ E non blocca niente: se non riesce, si riprova al prossimo accesso.
     * `Trasloco.porta()` non solleva — torna un esito, e chi lo ignora non
     * rompe niente.
     */
    ref.listenManual(authControllerProvider, (_, stato) {
      if (stato.isAuthenticated) unawaited(_portaIlDiarioACasa());
    }, fireImmediately: true);
  }

  /// 📦 Una volta sola per installazione: ci pensa `Trasloco` a ricordarselo.
  Future<void> _portaIlDiarioACasa() async {
    final esito = await ref.read(traslocoProvider).porta();

    if (esito == EsitoTrasloco.fatto) {
      debugPrint('trasloco: il diario è sul telefono');
    }
  }

  Future<void> _invitoDallInstallazione() async {
    final token = await ref
        .read(riferimentoDellInstallazioneProvider)
        .tokenDellInvito();

    if (token == null || !mounted) return;

    /*
     * ⚠️ `go` e non `push`: chi arriva così **non ha una storia** da cui
     * tornare indietro, e una freccia che riporta a una schermata mai vista
     * è peggio di nessuna freccia.
     */
    ref.read(routerProvider).go('${AppRoutes.invito}/$token');
  }

  @override
  Widget build(BuildContext context) {
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
    /*
     * 🎨 **Il colore scelto è dell'abbonato** — 3b-J.2, 27/08/2026.
     *
     * 📌 *«Chi non è abbonato ha il teal normale»*.
     *
     * 🚨 **Il controllo sta QUI, non solo nella schermata che lo sceglie.** Chi
     * ha scelto un colore da abbonato e poi ha smesso di pagare ha ancora la
     * sua preferenza salvata sul telefono: senza questa riga se la terrebbe,
     * e il gate sarebbe una porta che si chiude quando sei già dentro.
     *
     * 💡 **La preferenza non si cancella**, si smette di applicarla: chi si
     * riabbona ritrova il colore che aveva, senza doverlo ricordare.
     */
    // 🚨 `haPalestra` e non il nome: [neutral] ha un nome non vuoto, e questa
    // riga con il controllo sul nome spegneva il colore scelto. 21/08/2026.
    final puoScegliere = puoScegliereIlColore(
      haPalestra: palestra.haPalestra,
      abbonato: ref.watch(authControllerProvider).user?.abbonato,
    );

    final scelto = puoScegliere
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
