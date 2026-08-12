import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/ui/gym_inactive_screen.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/register_screen.dart';
import '../../features/auth/ui/schermata_di_blocco.dart';
import '../../features/calendar/ui/calendar_screen.dart';
import '../../features/calendar/ui/day_screen.dart';
import '../../features/chat/ui/conversations_screen.dart';
import '../../features/chiavi/ui/porta_delle_chiavi.dart';
import '../../features/dashboard/ui/dashboard_screen.dart';
import '../../features/diary/ui/diary_screen.dart';
import '../../features/health/ui/schermata_salute.dart';
import '../../features/home/ui/home_shell.dart';
import '../../features/onboarding/branding_controller.dart';
import '../../features/onboarding/ui/gym_code_screen.dart';
import '../../features/privacy/ui/schermata_consensi.dart';
import '../../features/profile/ui/credentials_screen.dart';
import '../../features/profile/ui/delete_account_screen.dart';
import '../../features/profile/ui/edit_profile_screen.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/progress/ui/progress_screen.dart';
import '../../features/sleep/ui/sleep_screen.dart';
import '../../features/training/ui/history_screen.dart';
import '../../features/training/ui/plan_editor_screen.dart';
import '../../features/training/ui/plans_screen.dart';
import '../../features/training/ui/player_screen.dart';
import '../../features/training/ui/session_summary_screen.dart';

/// Le rotte dell'app — A1.5.
///
/// 🚨 **Il `redirect` è l'unico punto che decide dove si può stare.**
/// Se ogni schermata controllasse da sé la sessione, basterebbe dimenticarlo su
/// una per lasciare una porta aperta — e in un'app le schermate si aggiungono
/// in fretta. Qui la regola è scritta una volta e vale per tutte.
///
/// L'ordine dei controlli non è casuale:
///  1. **si sta ancora leggendo il token** → splash, senza decidere niente;
///  2. **palestra sospesa** → schermata dedicata, *prima* del controllo di
///     sessione: chi è in questo stato ha le credenziali giuste, e mandarlo al
///     login lo farebbe riprovare all'infinito con la password corretta;
///  3. 🔒 **sessione bloccata** (A1) → schermata di blocco. Stessa logica del
///     punto 2: la sessione **esiste**, manca solo il permesso di usarla;
///  4. 🚨 **sbloccata ma ancora sulla schermata di blocco** → dentro. ⚠️ Serve
///     una regola sua: `/bloccata` non è pubblica, quindi il punto 7 non la
///     riconosce — e senza, l'impronta funzionava e non succedeva niente;
///  5. **nessuna palestra scelta** → codice d'invito;
///  6. **non autenticato** → accesso;
///  7. **autenticato su una schermata di accesso** → dentro.
class AppRoutes {
  const AppRoutes._();

  static const gymCode = '/benvenuto';
  static const login = '/accedi';
  static const register = '/registrati';
  static const gymInactive = '/palestra-sospesa';
  static const bloccata = '/bloccata';

  static const home = '/';
  static const diary = '/diario';
  static const training = '/allenamento';
  static const progress = '/progressi';
  static const chat = '/messaggi';
  static const profile = '/profilo';

  // ── Fase C: le schermate che prima non c'erano ─────────────────────────
  //
  // Sono tutte **sopra** la shell (`push`, non `go`): hanno un percorso
  // proprio con un pulsante «indietro», e non devono far sparire la barra di
  // navigazione dal sotto — è il comportamento che ci si aspetta da un
  // dettaglio, non da una sezione.
  static const profileEdit = '/profilo/dati';
  static const deleteAccount = '/profilo/elimina';
  static const credentials = '/profilo/credenziali';

  /// I consensi facoltativi (S9.1). 🚨 Sta nel profilo e non in un sottomenù:
  /// revocare dev'essere facile quanto concedere (art. 7(3)).
  static const consensi = '/profilo/privacy';
  static const sleep = '/sonno';

  /// Il collegamento con Health Connect e la spiegazione dell'uso dei dati.
  ///
  /// 🚨 **Google pretende che questa schermata esista e sia raggiungibile**: il
  /// manifest la aggancia a `ACTION_SHOW_PERMISSIONS_RATIONALE`, ed è quello
  /// che il sistema apre quando chiede all'app di spiegarsi (S3.4).
  static const salute = '/salute';
  static const calendar = '/calendario';
  static const history = '/allenamento/storico';
  static const planNew = '/schede/nuova';

  /// `/allenamento/:id` — il player. `/schede/:id/modifica` — l'editor.
  static String player(int sessionId) => '/allenamento/$sessionId';

  /// Il riepilogo di fine allenamento — G7.
  ///
  /// 🚨 È una **rotta di go_router**, non un `Navigator.push` imperativo.
  /// Il player la apre con `pushReplacement`: spingendola con il `Navigator`
  /// del router, go_router continuerebbe a credere che la rotta corrente sia il
  /// player, e «Fine» riporterebbe su una sessione ormai chiusa.
  static String riepilogo(int sessionId) => '/allenamento/$sessionId/riepilogo';
  static String planEdit(int planId) => '/schede/$planId/modifica';
  static String day(String date) => '/giorno/$date';

  /// Le schermate raggiungibili senza sessione.
  static const _public = {gymCode, login, register, gymInactive};

  static bool isPublic(String location) => _public.contains(location);
}

/// **Dove si può stare**, come funzione pura — l'unico punto che lo decide.
///
/// ── 🚨 Perché è una funzione e non una closure dentro `GoRouter` ──────────
///
/// Perché è il pezzo di codice **più facile da sbagliare e più difficile da
/// provare** dell'intera app: sette regole in cascata, dove l'ordine conta e
/// dove «nessuna regola si applica» significa **resta dove sei**, cioè il modo
/// più silenzioso di lasciare qualcuno in un vicolo cieco.
///
/// ⚠️ È successo davvero, il 12/08/2026: l'impronta sbloccava, e l'app restava
/// sulla pagina «App bloccata». Nessun errore, nessun log, niente da cercare.
/// Estratta di qui, quella cascata si prova in venti righe di test.
///
/// `null` = «va bene dove sei». Qualunque altra stringa è la rotta da imporre.
///
/// L'ordine dei controlli **non è casuale**:
///  1. si sta ancora leggendo il token → si resta, e l'app mostra lo splash;
///  2. palestra sospesa, prima di tutto il resto;
///  3. 🔒 sessione bloccata;
///  4. 🚨 sbloccata ma ancora sulla schermata di blocco;
///  5. nessuna palestra scelta;
///  6. sessione assente;
///  7. autenticato su una schermata d'accesso.
String? destinazione({
  required AuthStatus stato,
  required bool haPalestra,
  required String posizione,
}) {
  final autenticato = stato == AuthStatus.loggedIn;

  // 1. Non si sa ancora niente: si resta dove si è, lo splash è mostrato
  //    dall'app stessa. Decidere adesso significherebbe mandare al login
  //    ogni utente a ogni avvio, per la frazione di secondo che serve a
  //    leggere il Keychain — e quel salto si vede.
  if (stato == AuthStatus.unknown) return null;

  // 2. Palestra sospesa: prima di tutto il resto.
  if (stato == AuthStatus.gymInactive) {
    return posizione == AppRoutes.gymInactive ? null : AppRoutes.gymInactive;
  }

  /*
   * 3. 🔒 Sessione bloccata — A1.
   *
   * ⚠️ **Prima del controllo sulla palestra**, e non è un dettaglio: il
   * branding si legge dalla cache locale, quindi anche a schermo bloccato
   * l'app saprebbe di che colore essere e passerebbe oltre. Ma mostrare il
   * codice palestra o qualunque altra schermata a chi non ha ancora
   * sbloccato vorrebbe dire che il blocco non blocca niente.
   */
  if (stato == AuthStatus.locked) {
    return posizione == AppRoutes.bloccata ? null : AppRoutes.bloccata;
  }

  /*
   * 4. 🚨 **Sbloccata: si esce dalla schermata di blocco.**
   *
   * ⚠️ Senza questa riga l'impronta funzionava e **non succedeva niente**: si
   * restava sulla pagina «App bloccata». È il difetto riferito provando l'app
   * il 12/08/2026.
   *
   * Il motivo è che `/bloccata` **non è** in `_public`, quindi la regola 7 —
   * «autenticato su una schermata di accesso → dentro» — non la riconosceva, e
   * nessuna regola successiva spostava: la cascata arrivava in fondo e tornava
   * `null`, cioè «resta dove sei».
   *
   * 🚨 **E `/bloccata` NON va aggiunta a `_public` per rimediare.** Quella
   * lista significa «raggiungibile senza sessione», ed è usata anche dalla
   * regola 6: chi tocca «Entra con la password» finisce `loggedOut`, e con
   * `/bloccata` fra le pubbliche resterebbe **inchiodato lì** invece di andare
   * al login. Si sarebbe scambiato un vicolo cieco con un altro.
   *
   * 💡 Qui basta il caso autenticato: quando non lo è, ci pensa la regola 6
   * proprio perché `/bloccata` non è pubblica.
   */
  if (posizione == AppRoutes.bloccata && autenticato) return AppRoutes.home;

  // 5. Nessuna palestra scelta: l'app non sa nemmeno di che colore essere.
  if (!haPalestra) {
    return posizione == AppRoutes.gymCode ? null : AppRoutes.gymCode;
  }

  // 6. Sessione assente.
  if (!autenticato) {
    return AppRoutes.isPublic(posizione) ? null : AppRoutes.login;
  }

  // 7. Autenticato ma fermo su una schermata di accesso.
  if (AppRoutes.isPublic(posizione)) return AppRoutes.home;

  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  // `Listenable` costruito dai due controller: go_router rivaluta il
  // `redirect` quando cambia la sessione **o** quando cambia la palestra.
  // Senza, un logout lascerebbe l'utente sulla schermata in cui si trova.
  final refresh = _RouterRefresh(ref);

  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => destinazione(
      stato: ref.read(authControllerProvider).status,
      haPalestra: ref.read(brandingControllerProvider).hasGym,
      posizione: state.matchedLocation,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.gymCode,
        builder: (_, _) => const GymCodeScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.gymInactive,
        builder: (_, _) => const GymInactiveScreen(),
      ),
      GoRoute(
        path: AppRoutes.bloccata,
        builder: (_, _) => const SchermataDiBlocco(),
      ),

      // ── Fase C ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (_, _) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.credentials,
        builder: (_, _) => const CredentialsScreen(),
      ),
      GoRoute(
        path: AppRoutes.consensi,
        builder: (_, _) => const SchermataConsensi(),
      ),
      GoRoute(path: AppRoutes.sleep, builder: (_, _) => const SleepScreen()),
      GoRoute(
        path: AppRoutes.salute,
        builder: (_, _) => const SchermataSalute(),
      ),
      GoRoute(
        path: AppRoutes.calendar,
        builder: (_, _) => const CalendarScreen(),
      ),
      GoRoute(
        path: AppRoutes.progress,
        builder: (_, _) => const ProgressScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (_, _) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.planNew,
        builder: (_, _) => const PlanEditorScreen(),
      ),
      GoRoute(
        path: '/schede/:id/modifica',
        builder: (_, state) =>
            PlanEditorScreen(planId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/giorno/:date',
        builder: (_, state) => DayScreen(date: state.pathParameters['date']!),
      ),
      GoRoute(
        path: '/allenamento/:id/riepilogo',
        builder: (_, state) => SessionSummaryScreen(
          sessionId: int.parse(state.pathParameters['id']!),
        ),
      ),
      // ⚠️ Questa DOPO `/allenamento/storico`: go_router prova le rotte
      // nell'ordine, e `:id` intercetterebbe anche «storico» facendo fallire
      // `int.parse`.
      GoRoute(
        path: '/allenamento/:id',
        builder: (_, state) =>
            PlayerScreen(sessionId: int.parse(state.pathParameters['id']!)),
      ),

      // La shell tiene la barra di navigazione ferma mentre cambia il
      // contenuto: senza, ogni cambio di scheda ricostruirebbe la barra e
      // l'animazione risulterebbe uno sfarfallio.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            // D5 — la prima scheda è il riepilogo di oggi, non la galleria:
            // aprendo l'app la domanda è «come sto andando», non «che foto ho
            // fatto». I progressi restano raggiungibili dal profilo.
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.diary,
                builder: (_, _) => const DiaryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.training,
                builder: (_, _) => const PlansScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            // 🚨 La chat passa dalla porta delle chiavi (S6.7): senza chiave
            // maestra non si può né leggere né scrivere, e la porta decide se
            // chiedere di **creare** la password o di **ripristinare**.
            // ⚠️ L'ordine è la cosa facile da sbagliare — la spiegazione sta
            // per esteso in `PortaDelleChiavi`.
            routes: [
              GoRoute(
                path: AppRoutes.chat,
                builder: (_, _) =>
                    const PortaDelleChiavi(child: ConversationsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Trasforma due provider in un `Listenable` per go_router.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(this._ref) {
    _subs = [
      _ref.listen(authControllerProvider, (_, _) => notifyListeners()),
      _ref.listen(brandingControllerProvider, (_, _) => notifyListeners()),
    ];
  }

  final Ref _ref;
  late final List<ProviderSubscription<Object?>> _subs;

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.close();
    }
    super.dispose();
  }
}
