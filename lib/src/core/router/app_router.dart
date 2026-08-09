import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/ui/gym_inactive_screen.dart';
import '../../features/auth/ui/login_screen.dart';
import '../../features/auth/ui/register_screen.dart';
import '../../features/chat/ui/conversations_screen.dart';
import '../../features/diary/ui/diary_screen.dart';
import '../../features/home/ui/home_shell.dart';
import '../../features/onboarding/branding_controller.dart';
import '../../features/onboarding/ui/gym_code_screen.dart';
import '../../features/profile/ui/profile_screen.dart';
import '../../features/progress/ui/progress_screen.dart';
import '../../features/training/ui/plans_screen.dart';

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

      // La shell tiene la barra di navigazione ferma mentre cambia il
      // contenuto: senza, ogni cambio di scheda ricostruirebbe la barra e
      // l'animazione risulterebbe uno sfarfallio.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: AppRoutes.home, builder: (_, _) => const ProgressScreen())],
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
