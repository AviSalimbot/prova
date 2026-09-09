// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
// import 'package:google_fonts/google_fonts.dart';

// import '../../features/auth/data/auth_repository.dart';

// /// Persistent navigation shell for PROVA.
// class AppShell extends ConsumerWidget {
//   final Widget child;
//   final String currentRoute;

//   const AppShell({
//     super.key,
//     required this.child,
//     required this.currentRoute,
//   });

//   // ========================================================================
//   // MAIN NAVIGATION
//   // ========================================================================

//   static const _destinations = [
//     _NavItem('/assessments', 'Assessments'),
//     _NavItem('/configuration', 'Configuration'),
//     _NavItem('/dashboard', 'Dashboard'),
//     _NavItem('/annotation', 'Annotation'),
//     _NavItem('/labels', 'Labels'),
//     _NavItem('/adjudication', 'Adjudication'),
//     _NavItem('/evaluation', 'Evaluation'),
//     _NavItem('/item-detail', 'Item Detail'),
//     _NavItem('/runs', 'Runs'),
//     _NavItem('/models', 'Models'),
//   ];

//   /// Role string(s) that should see the "ADMIN AREA" section. Adjust here
//   /// if the underlying role identifier changes (e.g. an enum name instead
//   /// of a raw string).
//   static const _adminAreaRole = 'admin';

//   @override
//   Widget build(BuildContext context, WidgetRef ref) {
//     // Temporarily display every navigation item.
//     final visibleItems = _destinations;

//     final appUser = ref.watch(appUserProvider).value;
//     final isAdmin =
//         appUser?.role.toLowerCase() == _adminAreaRole;

//     return Scaffold(
//       body: Row(
//         children: [
//           // =================================================================
//           // SIDEBAR
//           // =================================================================

//           Container(
//             width: 258,
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               border: Border(
//                 right: BorderSide(
//                   color: Color(0xFFD9DEE3),
//                   width: 1,
//                 ),
//               ),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // ===========================================================
//                 // BRANDING
//                 // ===========================================================

//                 Padding(
//                   padding: const EdgeInsets.fromLTRB(
//                     22,
//                     27,
//                     16,
//                     16,
//                   ),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(
//                         'PROVA',
//                         style: GoogleFonts.inter(
//                           fontSize: 16,
//                           fontWeight: FontWeight.w800,
//                           color: const Color(0xFF1A2433),
//                           height: 1.1,
//                         ),
//                       ),
//                       const SizedBox(height: 2),
//                       Text(
//                         'Cognitive Error Classifier',
//                         style: GoogleFonts.inter(
//                           fontSize: 11,
//                           fontWeight: FontWeight.w400,
//                           color: const Color(0xFF8F969E),
//                           height: 1.15,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),

//                 const Divider(
//                   height: 1,
//                   thickness: 1,
//                   color: Color(0xFFD9DEE3),
//                 ),

//                 // ===========================================================
//                 // NAVIGATION
//                 // ===========================================================

//                 Expanded(
//                   child: SingleChildScrollView(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         // ---------------------------------------------------
//                         // MAIN NAVIGATION
//                         // ---------------------------------------------------

//                         Padding(
//                           padding: const EdgeInsets.fromLTRB(
//                             13,
//                             12,
//                             13,
//                             0,
//                           ),
//                           child: Column(
//                             crossAxisAlignment:
//                                 CrossAxisAlignment.start,
//                             children: [
//                               ...visibleItems.map(
//                                 (item) => Padding(
//                                   padding: const EdgeInsets.only(
//                                     bottom: 1,
//                                   ),
//                                   child: _NavigationItem(
//                                     label: item.label,
//                                     selected:
//                                         currentRoute.startsWith(
//                                       item.route,
//                                     ),
//                                     onTap: () =>
//                                         context.go(item.route),
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),

//                         // ---------------------------------------------------
//                         // ADMIN AREA
//                         // ---------------------------------------------------
//                         //
//                         // Only visible to the "admin" role. The divider
//                         // is deliberately outside the padded navigation
//                         // container so it spans the entire sidebar width,
//                         // just like the sign-out divider — but it (and the
//                         // section below it) only render at all when the
//                         // signed-in user is an admin.
//                         //

//                         if (isAdmin) ...[
//                           const SizedBox(height: 10),

//                           const Divider(
//                             height: 1,
//                             thickness: 1,
//                             color: Color(0xFFD9DEE3),
//                           ),

//                           const SizedBox(height: 10),

//                           Padding(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: 13,
//                             ),
//                             child: Column(
//                               crossAxisAlignment:
//                                   CrossAxisAlignment.start,
//                               children: [
//                                 Padding(
//                                   padding: const EdgeInsets.only(
//                                     left: 9,
//                                     bottom: 5,
//                                   ),
//                                   child: Text(
//                                     'ADMIN AREA',
//                                     style: GoogleFonts.inter(
//                                       fontSize: 9,
//                                       fontWeight: FontWeight.w800,
//                                       letterSpacing: 0.35,
//                                       color:
//                                           const Color(0xFF9AA3AD),
//                                     ),
//                                   ),
//                                 ),

//                                 _NavigationItem(
//                                   label: 'Admin',
//                                   selected: currentRoute
//                                       .startsWith(
//                                     '/administration',
//                                   ),
//                                   onTap: () => context.go(
//                                     '/administration',
//                                   ),
//                                 ),
//                               ],
//                             ),
//                           ),

//                           const SizedBox(height: 12),
//                         ],
//                       ],
//                     ),
//                   ),
//                 ),

//                 // ===========================================================
//                 // SIGN OUT
//                 // ===========================================================

//                 const Divider(
//                   height: 1,
//                   thickness: 1,
//                   color: Color(0xFFD9DEE3),
//                 ),

//                 SizedBox(
//                   height: 38,
//                   child: Align(
//                     alignment: Alignment.centerRight,
//                     child: Padding(
//                       padding: const EdgeInsets.only(
//                         right: 22,
//                       ),
//                       child: TextButton(
//                         onPressed: () {
//                           ref
//                               .read(authRepositoryProvider)
//                               .signOut();
//                         },
//                         style: TextButton.styleFrom(
//                           foregroundColor:
//                               const Color(0xFF687382),
//                           padding: EdgeInsets.zero,
//                           minimumSize: Size.zero,
//                           tapTargetSize:
//                               MaterialTapTargetSize.shrinkWrap,
//                         ),
//                         child: Text(
//                           'Sign out',
//                           style: GoogleFonts.inter(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w600,
//                             color: const Color(0xFF687382),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // =================================================================
//           // MAIN CONTENT
//           // =================================================================

//           Expanded(
//             child: child,
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ==========================================================================
// // NAVIGATION ITEM
// // ==========================================================================

// class _NavigationItem extends StatelessWidget {
//   final String label;
//   final bool selected;
//   final VoidCallback onTap;

//   const _NavigationItem({
//     required this.label,
//     required this.selected,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         borderRadius: BorderRadius.circular(8),
//         child: Container(
//           width: double.infinity,

//           // Reduced from 43px.
//           height: 38,

//           decoration: BoxDecoration(
//             color: selected
//                 ? const Color(0xFFEAF5F0)
//                 : Colors.transparent,
//             borderRadius: BorderRadius.circular(8),
//             border: selected
//                 ? const Border(
//                     left: BorderSide(
//                       color: Color(0xFF218452),
//                       width: 3,
//                     ),
//                   )
//                 : null,
//           ),

//           alignment: Alignment.centerLeft,

//           padding: const EdgeInsets.only(
//             left: 23,
//             right: 8,
//           ),

//           child: Text(
//             label,
//             style: GoogleFonts.inter(
//               // 13.5 is supported by Flutter.
//               fontSize: 13.5,
//               fontWeight: selected
//                   ? FontWeight.w700
//                   : FontWeight.w500,
//               color: selected
//                   ? const Color(0xFF218452)
//                   : const Color(0xFF1F2937),
//               height: 1.0,
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ==========================================================================
// // NAVIGATION DATA
// // ==========================================================================

// class _NavItem {
//   final String route;
//   final String label;

//   const _NavItem(
//     this.route,
//     this.label,
//   );
// }







import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/auth/data/auth_repository.dart';

/// Persistent navigation shell for PROVA.
class AppShell extends ConsumerWidget {
  final Widget child;
  final String currentRoute;

  const AppShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  // ========================================================================
  // MAIN NAVIGATION
  // ========================================================================

  static const _destinations = [
    _NavItem('/assessments', 'Assessments'),
    _NavItem('/configuration', 'Configuration'),
    _NavItem('/dashboard', 'Dashboard'),
    _NavItem('/annotation', 'Annotation'),
    _NavItem('/labels', 'Labels'),
    _NavItem('/adjudication', 'Adjudication'),
    _NavItem('/evaluation', 'Evaluation'),
    _NavItem('/item-detail', 'Item Detail'),
    _NavItem('/runs', 'Runs'),
    _NavItem('/models', 'Models'),
  ];

  /// Role string(s) that should see the "ADMIN AREA" section. Adjust here
  /// if the underlying role identifier changes (e.g. an enum name instead
  /// of a raw string).
  static const _adminAreaRole = 'admin';

  /// Status string that indicates the user account is active.
  static const _activeStatus = 'active';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Temporarily display every navigation item.
    final visibleItems = _destinations;

    final appUser = ref.watch(appUserProvider).value;

    // User must be "active" before we grant them admin visibility.
    final isAdmin = appUser?.status.toLowerCase() == _activeStatus &&
        appUser?.role.toLowerCase() == _adminAreaRole;

    // Prefer the Firestore profile's email, but fall back to the Firebase
    // Auth record — the profile doc can lag by a frame right after
    // sign-in, and this keeps the footer from flashing empty.
    final email = (appUser?.email.isNotEmpty ?? false)
        ? appUser!.email
        : (ref.watch(authStateProvider).value?.email ?? '');

    return Scaffold(
      body: Row(
        children: [
          // =================================================================
          // SIDEBAR
          // =================================================================

          Container(
            width: 258,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(
                  color: Color(0xFFD9DEE3),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===========================================================
                // BRANDING
                // ===========================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    22,
                    27,
                    16,
                    16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROVA',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A2433),
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Cognitive Error Classifier',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFF8F969E),
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFD9DEE3),
                ),

                // ===========================================================
                // NAVIGATION
                // ===========================================================

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---------------------------------------------------
                        // MAIN NAVIGATION
                        // ---------------------------------------------------

                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            13,
                            12,
                            13,
                            0,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              ...visibleItems.map(
                                (item) => Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 1,
                                  ),
                                  child: _NavigationItem(
                                    label: item.label,
                                    selected:
                                        currentRoute.startsWith(
                                      item.route,
                                    ),
                                    onTap: () =>
                                        context.go(item.route),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ---------------------------------------------------
                        // ADMIN AREA
                        // ---------------------------------------------------
                        //
                        // Only visible to the "admin" role. The divider
                        // is deliberately outside the padded navigation
                        // container so it spans the entire sidebar width,
                        // just like the sign-out divider — but it (and the
                        // section below it) only render at all when the
                        // signed-in user is an active admin.
                        //

                        if (isAdmin) ...[
                          const SizedBox(height: 10),

                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: Color(0xFFD9DEE3),
                          ),

                          const SizedBox(height: 10),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 9,
                                    bottom: 5,
                                  ),
                                  child: Text(
                                    'ADMIN AREA',
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.35,
                                      color:
                                          const Color(0xFF9AA3AD),
                                    ),
                                  ),
                                ),

                                _NavigationItem(
                                  label: 'Admin',
                                  selected: currentRoute
                                      .startsWith(
                                    '/administration',
                                  ),
                                  onTap: () => context.go(
                                    '/administration',
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                        ],
                      ],
                    ),
                  ),
                ),

                // ===========================================================
                // ACCOUNT FOOTER — signed-in email + sign out
                // ===========================================================
                //
                // The email sits on the left and the action on the right,
                // sharing one 38px row. The email is wrapped in Expanded
                // with ellipsis overflow so a long address truncates
                // rather than pushing "Sign out" off the sidebar or
                // overflowing the fixed 258px width.
                //

                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFD9DEE3),
                ),

                SizedBox(
                  height: 38,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 22,
                      right: 22,
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Tooltip(
                            // The full address on hover, since the
                            // visible text may be truncated.
                            message: email,
                            waitDuration:
                                const Duration(milliseconds: 500),
                            child: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1F2937),
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        TextButton(
                          onPressed: () {
                            ref
                                .read(authRepositoryProvider)
                                .signOut();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor:
                                const Color(0xFF687382),
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Sign out',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF687382),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // =================================================================
          // MAIN CONTENT
          // =================================================================

          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}

// ==========================================================================
// NAVIGATION ITEM
// ==========================================================================

class _NavigationItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,

          // Reduced from 43px.
          height: 38,

          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFEAF5F0)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? const Border(
                    left: BorderSide(
                      color: Color(0xFF218452),
                      width: 3,
                    ),
                  )
                : null,
          ),

          alignment: Alignment.centerLeft,

          padding: const EdgeInsets.only(
            left: 23,
            right: 8,
          ),

          child: Text(
            label,
            style: GoogleFonts.inter(
              // 13.5 is supported by Flutter.
              fontSize: 13.5,
              fontWeight: selected
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: selected
                  ? const Color(0xFF218452)
                  : const Color(0xFF1F2937),
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================================================
// NAVIGATION DATA
// ==========================================================================

class _NavItem {
  final String route;
  final String label;

  const _NavItem(
    this.route,
    this.label,
  );
}