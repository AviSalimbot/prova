// lib/features/assessments/presentation/drive_connect.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/drive_auth_service.dart';

/// Waits on the app-wide restoreSession() attempt (kicked off once at
/// startup via driveSessionRestoreProvider) rather than starting a new
/// trySilentSignIn() race here. Only pops the interactive dialog if
/// that shared restore didn't find a usable session. Returns true once
/// a session is confirmed active.
Future<bool> ensureDriveConnected(BuildContext context, WidgetRef ref) async {
  final authService = ref.read(driveAuthServiceProvider);

  // Fast path: restore already ran (almost always true by the time any
  // screen needing Drive is reached) and found a session.
  if (authService.isSignedIn) return true;

  // Otherwise wait on the SAME restore attempt every other screen
  // shares, rather than kicking off a second one.
  final restored = await ref.read(driveSessionRestoreProvider.future);
  if (!context.mounted) return false;
  if (restored) return true;

  final connected = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => GoogleSignInDialog(authService: authService),
  );
  return connected == true;
}

/// Dialog shown when no Google session is already active. Listens to
/// [DriveAuthService.onSignInChanged] rather than awaiting a single
/// call, since on web the actual completion comes from Google's own
/// rendered button (an iframe this widget doesn't control) rather than
/// from a Future this widget starts.
class GoogleSignInDialog extends StatefulWidget {
  const GoogleSignInDialog({super.key, required this.authService});

  final DriveAuthService authService;

  @override
  State<GoogleSignInDialog> createState() => _GoogleSignInDialogState();
}

class _GoogleSignInDialogState extends State<GoogleSignInDialog> {
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.authService.onSignInChanged.listen((signedIn) {
      if (signedIn && mounted) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // White background to match the other dialogs in the app
      // (Import assessment, page preview) instead of the default
      // theme dialogBackgroundColor.
      backgroundColor: Colors.white,
      title: const Text('Connect Google Drive'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Viewing or importing scans reads your Google Drive '
              '(read-only). Sign in to continue.',
            ),
            const SizedBox(height: 20),
            Center(child: widget.authService.buildSignInButton()),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}