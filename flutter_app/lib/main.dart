import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/assessments/data/drive_auth_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initializes the "Firebase" box in Figure H-1 (Firestore + Storage + Admin auth).
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const ProviderScope(child: ProvaApp()));
}

class ProvaApp extends ConsumerWidget {
  const ProvaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    // Fire-and-forget: kicks off the Drive silent-session restore once,
    // as early as possible, so by the time the person navigates to
    // Assessments it's already resolved (or in flight) instead of each
    // screen racing its own attempt. This is unrelated to Firebase
    // Auth — see DriveAuthService's doc comment — so it's fine to fire
    // in parallel with the rest of app startup rather than being
    // awaited before runApp.
    ref.watch(driveSessionRestoreProvider);

    return MaterialApp.router(
      title: 'PROVA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}