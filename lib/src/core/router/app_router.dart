import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/ui/gym_inactive_screen.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/register_screen.dart';
import '../../features/calendar/ui/calendar_screen.dart';
import '../../features/calendar/ui/day_screen.dart';
import '../../features/chat/ui/conversations_screen.dart';
import '../../features/dashboard/ui/dashboard_screen.dart';
import '../../features/diary/ui/diary_screen.dart';
import '../../features/home/ui/home_shell.dart';
import '../../features/onboarding/branding_controller.dart';
import '../../features/onboarding/ui/gym_code_screen.dart';
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
///  3. **nessuna palestra scelta** → codice d'invito;
///  4. **non autenticato** → accesso;
///  5. **autenticato su una schermata di accesso** → dentro.
class AppRoutes {
  const AppRoutes._();

  static const gymCode = '/benvenuto';
  static const login = '/accedi';
  static const register = '/registrati';
  static const gymInactive = '/palestra-sospesa';

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
  static const sleep = '/sonno';
  static const calendar = '/calendario';
  static const history = '/allenamento/storico';
  static const planNew = '/schede/nuova';

  /// `/allenamento/:id` — il player. `/schede/:id/modifica` — l'editor.
  static String player(int sessionId) => '/allenamento/$sessionId';
  static String planEdit(int planId) => '/schede/$planId/modifica';
  static String day(String date) => '/giorno/$date';

  /// Le schermate raggiungibili senza sessione.
  static const _public = {gymCode, login, register, gymInactive};

  static bool isPublic(String location) => _public.contains(location);
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
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final branding = ref.read(brandingControllerProvider);
      final location = state.matchedLocation;

      // 1. Non si sa ancora niente: si resta dove si è, lo splash è mostrato
      //    dall'app stessa. Decidere adesso significherebbe mandare al login
      //    ogni utente a ogni avvio, per la frazione di secondo che serve a
      //    leggere il Keychain — e quel salto si vede.
      if (auth.status == AuthStatus.unknown) return null;

      // 2. Palestra sospesa: prima di tutto il resto.
      if (auth.status == AuthStatus.gymInactive) {
        return location == AppRoutes.gymInactive ? null : AppRoutes.gymInactive;
      }

      // 3. Nessuna palestra scelta: l'app non sa nemmeno di che colore essere.
      if (!branding.hasGym) {
        return location == AppRoutes.gymCode ? null : AppRoutes.gymCode;
      }

      // 4. Sessione assente.
      if (!auth.isAuthenticated) {
        return AppRoutes.isPublic(location) ? null : AppRoutes.login;
      }

      // 5. Autenticato ma fermo su una schermata di accesso.
      if (AppRoutes.isPublic(location)) return AppRoutes.home;

      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.gymCode, builder: (_, _) => const GymCodeScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: AppRoutes.gymInactive, builder: (_, _) => const GymInactiveScreen()),

      // ── Fase C ────────────────────────────────────────────────────────
      GoRoute(path: AppRoutes.profileEdit, builder: (_, _) => const EditProfileScreen()),
      GoRoute(path: AppRoutes.deleteAccount, builder: (_, _) => const DeleteAccountScreen()),
      GoRoute(path: AppRoutes.credentials, builder: (_, _) => const CredentialsScreen()),
      GoRoute(path: AppRoutes.sleep, builder: (_, _) => const SleepScreen()),
      GoRoute(path: AppRoutes.calendar, builder: (_, _) => const CalendarScreen()),
      GoRoute(path: AppRoutes.progress, builder: (_, _) => const ProgressScreen()),
      GoRoute(path: AppRoutes.history, builder: (_, _) => const HistoryScreen()),
      GoRoute(path: AppRoutes.planNew, builder: (_, _) => const PlanEditorScreen()),
      GoRoute(
        path: '/schede/:id/modifica',
        builder: (_, state) =>
            PlanEditorScreen(planId: int.parse(state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/giorno/:date',
        builder: (_, state) => DayScreen(date: state.pathParameters['date']!),
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
            routes: [GoRoute(path: AppRoutes.home, builder: (_, _) => const DashboardScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.diary, builder: (_, _) => const DiaryScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.training, builder: (_, _) => const PlansScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.chat, builder: (_, _) => const ConversationsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.profile, builder: (_, _) => const ProfileScreen())],
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
