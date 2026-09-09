// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';

// import '../../features/administration/presentation/administration_screen.dart';
// import '../../features/adjudication/presentation/adjudication_screen.dart';
// import '../../features/annotation/presentation/annotation_screen.dart';
// import '../../features/assessments/presentation/assessments_screen.dart';
// import '../../features/auth/data/auth_repository.dart';
// import '../../features/auth/presentation/login_screen.dart';
// import '../../features/auth/presentation/register_screen.dart';
// import '../../features/configuration/presentation/configuration_screen.dart';
// import '../../features/dashboard/presentation/dashboard_screen.dart';
// import '../../features/evaluation/presentation/evaluation_screen.dart';
// import '../../features/item_detail/presentation/item_detail_screen.dart';
// import '../../features/labels/presentation/labels_screen.dart';
// import '../../features/models/presentation/models_screen.dart';
// import '../../features/runs/presentation/runs_screen.dart';

// import '../widgets/app_shell.dart';

// /// Roles that are allowed into the app. Must match the set used in
// /// AuthRepository.signIn — kept as a separate constant here (rather than
// /// importing a shared one) to avoid coupling the router to auth_repository
// /// internals; update both together if the set of roles ever changes.
// const _activeRoles = {'admin', 'annotator', 'adjudicator'};

// final appRouterProvider = Provider<GoRouter>((ref) {
//   return GoRouter(
//     initialLocation: '/assessments',

//     redirect: (context, state) {
//       // Deliberately `ref.read`, not `ref.watch` — this provider builds
//       // the GoRouter object exactly once. Re-running the redirect logic
//       // is driven by `refreshListenable` below calling notifyListeners(),
//       // not by rebuilding this provider. If this used `ref.watch`, every
//       // auth/role change would tear down and recreate the entire
//       // GoRouter (and its Navigator) from scratch, which is what was
//       // causing a blank screen to flash before the correct destination
//       // rendered — a full router rebuild, not just a redirect check.
//       final authState = ref.read(authStateProvider);
//       final appUserState = ref.read(appUserProvider);

//       final signedIn = authState.value != null;

//       final publicRoute =
//           state.matchedLocation == '/login' ||
//           state.matchedLocation == '/register';

//       // "Approved" requires BOTH a signed-in Firebase user AND a
//       // resolved Firestore profile doc whose role is one of the active
//       // roles. This is deliberately stricter than just `signedIn`:
//       // Firebase Auth flips to "signed in" the instant
//       // signInWithEmailAndPassword/createUserWithEmailAndPassword
//       // succeeds — before the app has any chance to check the role. If
//       // we redirected on `signedIn` alone, a brand-new or still-pending
//       // account would flash into the app for a moment before being
//       // bounced back out. While appUserState is still loading (doc not
//       // fetched yet) or the role is 'pending'/missing, `approved` is
//       // false, so we simply stay on/return to the public routes instead.
//       final approved = signedIn &&
//           appUserState.hasValue &&
//           appUserState.value != null &&
//           _activeRoles.contains(appUserState.value!.role);

//       if (!approved && !publicRoute) {
//         return '/login';
//       }

//       if (approved && publicRoute) {
//         return '/assessments';
//       }

//       return null;
//     },

//     refreshListenable: GoRouterRefreshStream(ref),

//     routes: [
//       // ====================================================================
//       // PUBLIC ROUTES
//       // ====================================================================

//       GoRoute(
//         path: '/login',
//         pageBuilder: (context, state) => const NoTransitionPage(
//           child: LoginScreen(),
//         ),
//       ),

//       GoRoute(
//         path: '/register',
//         pageBuilder: (context, state) => const NoTransitionPage(
//           child: RegisterScreen(),
//         ),
//       ),

//       // ====================================================================
//       // APPLICATION ROUTES
//       // ====================================================================

//       ShellRoute(
//         pageBuilder: (context, state, child) => NoTransitionPage(
//           child: AppShell(
//             currentRoute: state.matchedLocation,
//             child: child,
//           ),
//         ),

//         routes: [
//           // ----------------------------------------------------------------
//           // ASSESSMENTS
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/assessments',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: AssessmentsScreen(),
//             ),
//           ),

//           // ----------------------------------------------------------------
//           // CONFIGURATION
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/configuration',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: ConfigurationScreen(),
//             ),
//           ),

//           // ----------------------------------------------------------------
//           // DASHBOARD
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/dashboard',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: DashboardScreen(),
//             ),
//           ),

//           // ----------------------------------------------------------------
//           // ANNOTATION
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/annotation',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: AnnotationScreen(),
//             ),
//           ),

//           // ----------------------------------------------------------------
//           // LABELS
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/labels',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: LabelsScreen(),
//             ),
//           ),

//           // ----------------------------------------------------------------
//           // ADJUDICATION
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/adjudication',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: AdjudicationScreen(),
//             ),
//           ),

//           // ----------------------------------------------------------------
//           // EVALUATION
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/evaluation',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: EvaluationScreen(),
//             ),
//           ),

//           // ----------------------------------------------------------------
//           // ITEM DETAIL
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/item-detail',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: ItemDetailScreen(),
//             ),
//           ),

//           // ----------------------------------------------------------------
//           // RUNS
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/runs',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: RunsScreen(),
//             ),
//           ),

//           // ----------------------------------------------------------------
//           // MODELS
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/models',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: ModelsScreen(),
//             ),
//           ),

//           // ----------------------------------------------------------------
//           // ADMIN
//           // ----------------------------------------------------------------

//           GoRoute(
//             path: '/administration',
//             pageBuilder: (context, state) => const NoTransitionPage(
//               child: AdministrationScreen(),
//             ),
//           ),
//         ],
//       ),
//     ],
//   );
// });

// /// Bridges Riverpod's authStateProvider AND appUserProvider streams to
// /// go_router's Listenable redirect API so navigation re-evaluates
// /// immediately on sign-in/sign-out AND on role changes (e.g. the moment
// /// a pending account's role doc first resolves, or an admin promotes
// /// someone while they're sitting on the login screen).
// class GoRouterRefreshStream extends ChangeNotifier {
//   GoRouterRefreshStream(Ref ref) {
//     ref.listen(
//       authStateProvider,
//       (_, __) => notifyListeners(),
//     );
//     ref.listen(
//       appUserProvider,
//       (_, __) => notifyListeners(),
//     );
//   }
// }






import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/administration/presentation/administration_screen.dart';
import '../../features/adjudication/presentation/adjudication_screen.dart';
import '../../features/annotation/presentation/annotation_screen.dart';
import '../../features/assessments/presentation/assessments_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/configuration/presentation/configuration_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/evaluation/presentation/evaluation_screen.dart';
import '../../features/item_detail/presentation/item_detail_screen.dart';
import '../../features/labels/presentation/labels_screen.dart';
import '../../features/models/presentation/models_screen.dart';
import '../../features/runs/presentation/runs_screen.dart';

import '../widgets/app_shell.dart';

/// Roles that are allowed into the app. Must match the set used in
/// AuthRepository.signIn — kept as a separate constant here (rather than
/// importing a shared one) to avoid coupling the router to auth_repository
/// internals; update both together if the set of roles ever changes.
const _activeRoles = {'admin', 'annotator', 'adjudicator'};

/// Status that indicates the account is fully approved / active.
/// Users with any other status (pending, disabled, etc.) are not allowed in.
const _activeStatus = 'active';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/assessments',

    redirect: (context, state) {
      // Deliberately `ref.read`, not `ref.watch` — this provider builds
      // the GoRouter object exactly once. Re-running the redirect logic
      // is driven by `refreshListenable` below calling notifyListeners(),
      // not by rebuilding this provider. If this used `ref.watch`, every
      // auth/role change would tear down and recreate the entire
      // GoRouter (and its Navigator) from scratch, which is what was
      // causing a blank screen to flash before the correct destination
      // rendered — a full router rebuild, not just a redirect check.
      final authState = ref.read(authStateProvider);
      final appUserState = ref.read(appUserProvider);

      final signedIn = authState.value != null;

      final publicRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      // "Approved" requires ALL of the following:
      //  1. A signed-in Firebase user
      //  2. A resolved Firestore profile doc
      //  3. The profile's status is 'active'
      //  4. The profile's role is one of the active roles
      //
      // This is deliberately stricter than just `signedIn`:
      // Firebase Auth flips to "signed in" the instant
      // signInWithEmailAndPassword/createUserWithEmailAndPassword
      // succeeds — before the app has any chance to check the role or
      // status. If we redirected on `signedIn` alone, a brand-new or
      // still-pending account would flash into the app for a moment
      // before being bounced back out. While `appUserState` is still
      // loading (doc not fetched yet) or the status/role is not
      // approved, `approved` is false, so we simply stay on/return to
      // the public routes instead.
      final isActive = appUserState.hasValue &&
          appUserState.value != null &&
          appUserState.value!.status == _activeStatus;

      final hasActiveRole = isActive &&
          _activeRoles.contains(appUserState.value!.role);

      final approved = signedIn && hasActiveRole;

      if (!approved && !publicRoute) {
        return '/login';
      }

      if (approved && publicRoute) {
        return '/assessments';
      }

      // Admin-only route guard: if the user is approved but tries to
      // enter /administration without being an active admin, send them
      // to the default app page.
      if (approved &&
          state.matchedLocation.startsWith('/administration') &&
          appUserState.value!.role != 'admin') {
        return '/assessments';
      }

      return null;
    },

    refreshListenable: GoRouterRefreshStream(ref),

    routes: [
      // ====================================================================
      // PUBLIC ROUTES
      // ====================================================================

      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),

      GoRoute(
        path: '/register',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: RegisterScreen(),
        ),
      ),

      // ====================================================================
      // APPLICATION ROUTES
      // ====================================================================

      ShellRoute(
        pageBuilder: (context, state, child) => NoTransitionPage(
          child: AppShell(
            currentRoute: state.matchedLocation,
            child: child,
          ),
        ),

        routes: [
          // ----------------------------------------------------------------
          // ASSESSMENTS
          // ----------------------------------------------------------------

          GoRoute(
            path: '/assessments',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AssessmentsScreen(),
            ),
          ),

          // ----------------------------------------------------------------
          // CONFIGURATION
          // ----------------------------------------------------------------

          GoRoute(
            path: '/configuration',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ConfigurationScreen(),
            ),
          ),

          // ----------------------------------------------------------------
          // DASHBOARD
          // ----------------------------------------------------------------

          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DashboardScreen(),
            ),
          ),

          // ----------------------------------------------------------------
          // ANNOTATION
          // ----------------------------------------------------------------

          GoRoute(
            path: '/annotation',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AnnotationScreen(),
            ),
          ),

          // ----------------------------------------------------------------
          // LABELS
          // ----------------------------------------------------------------

          GoRoute(
            path: '/labels',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LabelsScreen(),
            ),
          ),

          // ----------------------------------------------------------------
          // ADJUDICATION
          // ----------------------------------------------------------------

          GoRoute(
            path: '/adjudication',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdjudicationScreen(),
            ),
          ),

          // ----------------------------------------------------------------
          // EVALUATION
          // ----------------------------------------------------------------

          GoRoute(
            path: '/evaluation',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: EvaluationScreen(),
            ),
          ),

          // ----------------------------------------------------------------
          // ITEM DETAIL
          // ----------------------------------------------------------------

          GoRoute(
            path: '/item-detail',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ItemDetailScreen(),
            ),
          ),

          // ----------------------------------------------------------------
          // RUNS
          // ----------------------------------------------------------------

          GoRoute(
            path: '/runs',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: RunsScreen(),
            ),
          ),

          // ----------------------------------------------------------------
          // MODELS
          // ----------------------------------------------------------------

          GoRoute(
            path: '/models',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ModelsScreen(),
            ),
          ),

          // ----------------------------------------------------------------
          // ADMIN
          // ----------------------------------------------------------------

          GoRoute(
            path: '/administration',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AdministrationScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod's authStateProvider AND appUserProvider streams to
/// go_router's Listenable redirect API so navigation re-evaluates
/// immediately on sign-in/sign-out AND on role/status changes (e.g. the
/// moment a pending account's profile doc resolves, or an admin changes
/// someone's role/status while they're sitting on the login screen).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    ref.listen(
      authStateProvider,
      (_, __) => notifyListeners(),
    );
    ref.listen(
      appUserProvider,
      (_, __) => notifyListeners(),
    );
  }
}